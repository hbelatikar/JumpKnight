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

	//Localparam for opcodes
	localparam 	CAL_OPCODE 		= 4'b0000,
				MOVE_OPCODE 	= 4'b0010,
				MOVE_FAN_OPCODE = 4'b0011,
				TOUR_OPCODE		= 4'b0100;

	/////////////////////////////
	//    DECODING COMMAND    //
	///////////////////////////

	logic [3:0]	op_code ;
	logic [7:0]	raw_heading ;
	logic [3:0]	squares_to_move;

	assign	op_code 		= cmd[15:12];
	assign	raw_heading 	= cmd[11:4];
	assign	squares_to_move = cmd[3:0];
	
	/////////////////////////////
	//    COUNTING SQUARES    //
	///////////////////////////

	//Rising edge detector for cntrIR
	logic cntrIR_delayed, cntrIR_rised;
	always_ff @( posedge clk, negedge rst_n )
		if(!rst_n)
			cntrIR_delayed <= 1'b0;
		else
			cntrIR_delayed <= cntrIR;
	//Old value was low and current value is high so there was a rising edge
	assign cntrIR_rised = cntrIR & ~cntrIR_delayed;	

	//Square counter
	always_ff @( posedge clk, negedge rst_n ) 
		if(!rst_n)
			sq_count <= 4'b0;
		else if (move_cmd)		//Reset since its a new move command
			sq_count <= 4'b0;
		else if (cntrIR_rised)	//Detected a rising edge so increment counter
			sq_count <= sq_count + 1'b1;

	//Number of squares to move logger
	always_ff @( posedge clk, negedge rst_n )
		if (!rst_n) 
			sq_cmd <= 4'b0;
		else if (move_cmd) 		//New move command so log the new value
			sq_cmd <= (squares_to_move<<1);	//Shift by 1 to double the cntrIR rising edges

	//Moving is done since number of squares moved are same
	assign move_done = (sq_cmd == sq_count);	

	/////////////////////////////////////
	//    FORWARD VALUE GENERATION    //
	///////////////////////////////////

		logic clr_frwrd;
		logic [9:0] inc_amount, dec_amount;
		
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
		
		// Forward Register Flip Flop
		always_ff @(posedge clk, negedge rst_n)
			if(!rst_n)
				frwrd <= 10'h000;
			else if (clr_frwrd)
				frwrd <= 10'h000;
			else if (heading_rdy) 
				if (inc_frwrd & ~(&frwrd[9:8]))		//Keep on incrementing until it reaches max speed
					frwrd <= frwrd + inc_amount;
				else if (dec_frwrd & (|frwrd))		//Keep on decrementing until it reaches zero
					frwrd <= frwrd - dec_amount;

	//////////////////////////
	//    PID INTERFACE    //
	////////////////////////

		logic signed [11:0] desired_heading;
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
			else if (move_cmd)								// If we need to change heading
				if (|cmd[11:4])								// and if heading is not zero
					desired_heading <= {raw_heading,4'hF};	// promote 4-bits and append 4'hF
				else
					desired_heading <= {raw_heading,4'h0};	//Else don't append anything
			

		assign error = $signed(heading) - $signed(desired_heading) + $signed(err_nudge);

	///////////////////////////////////
	//    CMD_PROC STATE MACHINE    //
	/////////////////////////////////

	//State instantiation
	typedef enum logic [2:0] {CAL, MOVE, RAMP_UP, RAMP_DOWN, TOUR, IDLE} state_cmd_proc;
	state_cmd_proc state, nxt_state;

	//State transition logic
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;

	//State machine output and next state generation
	always_comb begin

		nxt_state 	= state;
		clr_cmd_rdy = 1'b0;
		strt_cal 	= 1'b0;
		moving 		= 1'b0;
		move_cmd 	= 1'b0;
		inc_frwrd 	= 1'b0;
		dec_frwrd 	= 1'b0;
		send_resp 	= 1'b0;
		fanfare_go  = 1'b0;
		tour_go		= 1'b0;
		clr_frwrd	= 1'b0;
		
		case(state)

			////// DEFAULT STATE = IDLE //////
			default: begin
				if(cmd_rdy) begin		//When the cmd is ready, check for opcode and go to respective state
					clr_cmd_rdy = 1;	//Acknowledge UART wrapper that command has been accepted

					case(op_code)			//Match the op_code 
						CAL_OPCODE : begin 			//Calibration Opcode
							nxt_state = CAL; 
							strt_cal = 1; 
						end

						MOVE_OPCODE : begin 		//Move w/o fanfare opcode
							nxt_state = MOVE;
							clr_frwrd = 1'b1;
							move_cmd = 1;
						end

						MOVE_FAN_OPCODE : begin 	//Move with fanfare opcode
							nxt_state = MOVE;
							clr_frwrd = 1'b1;
							move_cmd = 1;
						end

						TOUR_OPCODE : 				//Start Knight tour opcode
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
				moving = 1'b1;
				if(($signed(error) > -48) && ($signed(error) < 48)) begin	//Direction corrected - Go to RAMP_UP
					nxt_state = RAMP_UP;
					move_cmd = 1'b1;
					inc_frwrd = 1'b1;
				end
			end

			RAMP_UP: begin		//Ramp up frwrd to max here and count squares
				moving = 1'b1;
				inc_frwrd = 1'b1;
				if(move_done) begin //All squares covered (move_done), move to rampdown before stopping
					nxt_state = RAMP_DOWN;
					dec_frwrd = 1'b1;
				end
			end	

			RAMP_DOWN: begin	//State for ramp down and stop
				moving = 1;
				dec_frwrd = 1;
				if(~|frwrd) begin	//When forward reches zero, bot has completely stopped
					moving = 0;
					send_resp = 1;
					fanfare_go = cmd[12];	//Assert fanfare if Command was move with fanfare 
					nxt_state = IDLE;
				end
			end

			TOUR: begin			//Assert tour_go if tour is commanded
				tour_go = 1;
				clr_cmd_rdy = 1;
				nxt_state = IDLE;
			end
		endcase
	end

endmodule