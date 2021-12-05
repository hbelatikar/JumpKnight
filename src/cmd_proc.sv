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
typedef enum logic [2:0] {Cal, Move, Ramp_up, Ramp_down, Tour, Idle} state_cmd_proc;
state_cmd_proc state, nxt_state;


//State transition logic
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= Idle;
	else
		state <= nxt_state;

//State machine coding.............
always_comb begin

clr_cmd_rdy = 0;
strt_cal = 0;
moving = 0;
move_cmd = 0;
inc_frwrd = 0;
dec_frwrd = 0;
nxt_state = state;
send_resp = 0;

case(state)
Idle: begin
	if(cmd_rdy) begin		//When the cmd is ready, check for opcode and go to respective state
		case(cmd[15:12])		
			4'b0000 : begin nxt_state = Cal; strt_cal = 1; end
			4'b0010 : begin nxt_state = Move; ff_move = 0; end
			4'b0011 : begin nxt_state = Move; ff_move = 1; end
			4'b0100 : nxt_state = Tour;
			default :nxt_state = Idle;
		endcase
		clr_cmd_rdy = 1;
	end
	else begin		//Wait for cmd_rdy
		fanfare_go = 0;
		nxt_state = Idle;
	end
end


Cal: begin		//Calibration state
	if(!cal_done) begin		//Wait for cal done
		nxt_state = Cal;
	end
	else begin			//After cal done, go back to idle and wait for next cmd
		nxt_state = Idle;
		send_resp = 1;
	end
end

Move: begin		//Heading correction state
	moving = 1;
	if(heading - {cmd[11:4],4'hF} < 12'h030 | {cmd[11:4],4'hF} - heading < 12'h030) begin	//Direction corrected - Go to ramp_up
		nxt_state = Ramp_up;
		move_cmd = 1;
	end
	else		//Move until error inside +-12'h030
		nxt_state = Move;
end

Ramp_up: begin		//Ramp up frwrd to max here and count squares
	moving = 1;
	inc_frwrd = 1;
	move_cmd = 0;
	if(!move_done)	//Move done, move to rampdown and stop
		nxt_state = Ramp_up;

	else		//Move until commanded squares are covered
		nxt_state = Ramp_down;

end

Ramp_down: begin	//State for ramp down and stop
	moving = 1;
	dec_frwrd = 1;
	if(frwrd == 0) begin	//Bot stopped, cycle done
		moving = 0;
		send_resp = 1;
		if(ff_move)	//Assert go fanfare if move with fanfare was commanded
			fanfare_go = 1;
		nxt_state = Idle;
	end
	else			//Keep ramping down to zero
		nxt_state = Ramp_down;	

end

Tour: begin			//Assert tour_go if tour is commanded
	tour_go = 1;
	nxt_state = Idle;
end

default: nxt_state = Idle;	//default state to idle

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
		sq_count <= 1'b0;
	else if(move_cmd)
		sq_count <= 1'b0;
	else if(count_en)
		sq_count <= sq_count + 1'b1;


//Register commanded squares
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		sq_cmd <= 4'b0;
	else if(move_cmd)
		sq_cmd <= cmd[3:0];


assign move_done = (sq_count == sq_cmd) ? 1'b1 : 1'b0;


// Forward Register
	
	logic en, clr_frwrd, zero, max_spd;
	logic [9:0] inc_amount, dec_amount, frwrd_sum;
	
	// Enable if heading is ready
	assign en = (heading_rdy) ? (1'b1) : (1'b0);
	
	// Increment amount logic based on FAST_SIM
	assign inc_amount = (FAST_SIM) ? (10'h020) : (10'h004);
	
	// Increment amount logic based on FAST_SIM
	assign dec_amount = (FAST_SIM) ? (10'h040) : (10'h008);
	
	// Ramp up to max speed when 2 MSBs of frwrd are 1;
	assign max_spd = &frwrd[9:8];
	
	// Zero Speed Check
	assign zero = (frwrd == 10'h000) ? (1'b1) : (1'b0);
	
	// Summation of forward register

	assign frwrd_sum = dec_frwrd ? (frwrd - dec_amount) : max_spd ? frwrd : inc_frwrd ? (frwrd + inc_amount) : frwrd ;
	
	// Forward Register Flip Flop
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			frwrd <= 10'h000;
		else if (en)
			frwrd <= frwrd_sum;
		else if (clr_frwrd)
			frwrd <= 10'h000;
			
	// PID Interface
	
	logic en_desired_heading;
	logic signed [11:0] desired_heading, cmd_heading;
	logic signed [11:0] err_nudge;

	assign err_nudge = FAST_SIM & lftIR ? 12'h1FF : lftIR ? 12'h05F : FAST_SIM & rghtIR ? 12'hE00 : rghtIR ? 12'hFA1 : 12'h0000;

	assign cmd_heading = 	(cmd[11:4] == 8'h00) ? (12'h000) : ({cmd[11:4],4'hF});
	
	// Desired Heading Register Flip Flop
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			desired_heading <= 12'h000;
		else if (en_desired_heading)
			desired_heading <= cmd_heading;
			
	assign error = heading - desired_heading + err_nudge;
			

endmodule