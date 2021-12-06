module cmd_proc(clr_cmd_rdy, send_resp, tour_go, strt_cal, moving, fanfare_go,
		frwrd, error, cmd, cmd_rdy, heading, heading_rdy, cal_done, lftIR, cntrIR, rghtIR, clk, rst_n);

parameter FAST_SIM = 1;	//Default fast sim to 1

input clk, rst_n;

output logic clr_cmd_rdy, send_resp, tour_go, strt_cal, moving, fanfare_go;
output logic [9:0] frwrd;
output signed [11:0] error;

input [15:0] cmd;
input signed [11:0] heading;
input cmd_rdy, heading_rdy, cal_done, lftIR, cntrIR, rghtIR;

logic move_cmd, ff_move, inc_frwrd, dec_frwrd, move_done, flag;

logic count_en;

logic [3:0] sq_count, sq_cmd;

//State instantiation
// typedef enum logic [2:0] {Cal, Move, Ramp_up, Ramp_down, Tour, Idle} state_cmd_proc;
typedef enum logic [2:0] {CAL, MOVE, RAMP_UP, RAMP_DOWN, TOUR, IDLE} state_cmd_proc;
state_cmd_proc state, nxt_state;

//State transition logic
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;

//State machine coding.............
always_comb begin

	nxt_state 	= state;
	clr_cmd_rdy = 0;
	strt_cal 	= 0;
	moving 		= 0;
	move_cmd 	= 0;
	inc_frwrd 	= 0;
	dec_frwrd 	= 0;
	send_resp 	= 0;
	// ff_move 	= 0; 
	fanfare_go  = 0;

	case(state)

		////// DEFAULT STATE = IDLE //////
		default: begin
			if(cmd_rdy) begin		//When the cmd is ready, check for opcode and go to respective state
				clr_cmd_rdy = 1;

				case(cmd[15:12])		//Check the OP_code

					4'b0000 : begin 		//Calibration Opcode
						nxt_state = CAL; 
						strt_cal = 1; 
					end

					4'b0010 : begin 		//Move w/o fanfare opcode
						nxt_state = MOVE;
						ff_move = 0; 
					end

					4'b0011 : begin 		//Move with fanfare opcode
						nxt_state = MOVE; 
						ff_move = 1; 
					end
					4'b0100 : 				//Start Knight toru opcode
						nxt_state = TOUR;

					default :				//Illegal opcode
						nxt_state = IDLE;
						
				endcase
			end 
		end


		CAL: begin		//Calibration state
			if (cal_done) begin			//After cal done, go back to idle and wait for next cmd
				nxt_state = IDLE;
				send_resp = 1'b1;
			end
		end

		MOVE: begin		//Heading correction state
			moving = 1;
			if(heading - {cmd[11:4],4'hF} < 12'h030 | {cmd[11:4],4'hF} - heading < 12'h030) begin	//Direction corrected - Go to RAMP_UP
				nxt_state = RAMP_UP;
				move_cmd = 1;
			end
		end

		RAMP_UP: begin		//Ramp up frwrd to max here and count squares
			moving = 1;
			inc_frwrd = 1;
			move_cmd = 0;
			if(move_done)	//All squares covered (move_done), move to rampdown before stopping
				nxt_state = RAMP_DOWN;
		end

		RAMP_DOWN: begin	//State for ramp down and stop
			moving = 1;
			dec_frwrd = 1;
			if(frwrd == 0) begin	//Bot stopped, cycle done
				moving = 0;
				send_resp = 1;
				if(ff_move)	//Assert go fanfare if move with fanfare was commanded
					fanfare_go = 1;
				nxt_state = IDLE;
			end
		end

		TOUR: begin			//Assert tour_go if tour is commanded
			tour_go = 1;
			nxt_state = IDLE;
		end
	endcase
end


//Logic for generating flag to detect rising edge of cntrIR
always_comb begin
	if(!cntrIR)
		flag = 1'b1;
	else if(cntrIR && flag) begin
		count_en = 1'b1;
		flag = 1'b0;
	end
end


//Logic for counting squares
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		sq_count <= 4'b0;
	else if(move_cmd)
		sq_count <= 4'b0;
	else if(count_en)
		sq_count <= sq_count + 1'b1;


//Register commanded squares
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		sq_cmd <= 4'b0;
	else if(move_cmd)
		sq_cmd <= cmd[3:0];


assign move_done = (sq_count == sq_cmd);


// Forward Register
	
	logic clr_frwrd, zero, max_spd;
	logic [9:0] inc_amount, dec_amount, frwrd_sum;
	
	// Enable if heading is ready
	// assign en = (heading_rdy) ? (1'b1) : (1'b0);	//JUST use heading_rdy signal as the enable!
	
	//Increment or decrement amount as per FAST_SIM param
	generate 
		if (FAST_SIM) begin
			assign inc_amount = (10'h020);
			assign dec_amount = (10'h040);
		end else begin
			assign inc_amount = (10'h004);
			assign dec_amount = (10'h008);
		end
	endgenerate

	// Ramp up to max speed when 2 MSBs of frwrd are 1;
	assign max_spd = &frwrd[9:8];
	
	// Zero Speed Check
	assign zero = ~|frwrd; //(frwrd == 10'h000);
	
	// Summation of forward register

	assign frwrd_sum =	dec_frwrd	?	(frwrd - dec_amount) : 
						max_spd		?	frwrd				 :
						inc_frwrd	?	(frwrd + inc_amount) :
										frwrd 				 ;
	
	// Forward Register Flip Flop
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			frwrd <= 10'h000;
		else if (clr_frwrd)
			frwrd <= 10'h000;
		else if (heading_rdy)
			frwrd <= frwrd_sum;
			
	// PID Interface
	
	logic en_desired_heading;
	logic signed [11:0] desired_heading, cmd_heading;
	logic signed [11:0] err_nudge;

	//Assign the nudge erro as per the FAST_SIM

	generate
		if (FAST_SIM) begin
			assign err_nudge = 	lftIR 	? 	12'h1FF :
								rghtIR 	? 	12'hE00 : 
											12'h000 ;	
		end else begin
			assign err_nudge = 	lftIR	? 	12'h05F : 
								rghtIR	? 	12'hFA1 : 	
											12'h000 ;	
		end
	endgenerate
	
	// Desired Heading Register Flip Flop
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			desired_heading <= 12'h000;
		else if (move_cmd) begin				// If we need to change heading
			if (|cmd[11:4])								// and if heading is not zero
				desired_heading <= {cmd[11:4],4'hF};	// promote 4-bits and append 4’hF
			else
				desired_heading <= 12'h000;				//Else keep it as it is
		end

	assign error = heading - desired_heading + err_nudge;

endmodule