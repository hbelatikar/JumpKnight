//`default_nettype none
module PID (clk, rst_n, moving, err_vld, error, frwrd, lft_spd, rght_spd);
	
	//////////////////////////////////
	// Declaring input and outputs //
	////////////////////////////////
	input  logic 				clk, rst_n;
	input  logic 				moving;
	input  logic 				err_vld;
	input  logic signed [11:0]	error;
	input  logic 		[9:0]	frwrd;
	output logic 		[10:0]	lft_spd, rght_spd;
	
	////////////////////////////
	// Generating the P-term //
	//////////////////////////
	
	logic signed [13:0] P_term;
	
	logic signed [9:0] err_sat;

	localparam signed P_COEFF = 5'h8;
	
	//If even one bit in the range [10:9] of error is one we might 
	//need to positively saturate the error
	
	//If all bits in the range [10:9] of error is zero we might 
	//need to negatively saturate the error

	//Error gets saturated to the most negative value when the MSB of error 
	//is 1 and all the bits in the range [10:9] are zero.
	//The error gets saturated to the most positive value when the MSB of 
	//error is 0 and there is atleast one bit which is high in the range [10:9]
	//ELSE there is no need to saturate the error.

	assign err_sat = 	error[11]  & !(&error[10:9]) ? 10'b10_0000_0000 : 
						!error[11] & (|error[10:9]) ? 10'b01_1111_1111:
						error[9:0];
						
	/////////////////////////////////
	// Pipelining Flop for err_sat //
	/////////////////////////////////

	logic signed [9:0] err_sat_p;

	always @(posedge clk, negedge rst_n)
		if(!rst_n)
			err_sat_p <= 10'b000;
		else
			err_sat_p <= err_sat;

	assign P_term = $signed(err_sat_p) *  $signed(P_COEFF);
	
	////////////////////////////
	// Generating the I-term //
	//////////////////////////
	
	logic I_overflow;
	logic [14:0]  I_sum, integrator, sign_ex_err_sat, sampled;
	logic signed [8:0] I_term;
	
	assign sign_ex_err_sat = {{5{err_sat_p[9]}},err_sat_p};	
	
	assign I_sum = sign_ex_err_sat + integrator;

	///////////////////////////////////
	// Pipelining Flop for err_valid //
	///////////////////////////////////

	logic err_vld_p;

	always @(posedge clk, negedge rst_n)
		if(!rst_n)
			err_vld_p <= 1'b0;
		else
			err_vld_p <= err_vld;
	
	//New sample is valid only when err_vld & ~overflow = 1
	assign sampled = (err_vld_p & ~I_overflow) ? I_sum : integrator; 
	
	assign I_term = integrator [14:6];
	
	//If the sat_error sign and integrator sign are not equal, then there is no overflow
	//If they are equal and sum sign is not equal to them, then there is an overflow
	
	assign I_overflow = (sign_ex_err_sat[14] != integrator[14]) ? 1'b0 : 	
						(I_sum[14] == sign_ex_err_sat[14]) ? 1'b0 : 1'b1;

	////////////////////////////////
	// Pipelining Flop for moving //
	////////////////////////////////

	logic moving_p;

	always @(posedge clk, negedge rst_n)
		if(!rst_n)
			moving_p <= 1'b0;
		else
			moving_p <= moving;
	
	//Update intergrator register only when move is high, or else put it as a zero
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n) 
			integrator <= 15'h0000;		
		else
			if(moving_p)
				integrator <= sampled;	
			else
				integrator <= 15'h0000;
				
	////////////////////////////
	// Generating the D-term //
	//////////////////////////
	
	//Defining internal logic
	logic signed [12:0] D_term;
	logic signed [9:0] D_err_dff, D_prev_err, D_diff;
	logic signed [6:0] D_diff_sat;		
	
	//Defining local params
	localparam signed [5:0] D_COEFF = 6'h0B;

	always@(posedge clk, negedge rst_n)
	begin
		if (!rst_n) begin
			D_err_dff  <= 10'b0;	//Async low resets the delayed error
			D_prev_err <= 10'b0;	//values stored in the flip flops.
		end 
		else if (err_vld_p) begin
			D_err_dff <= err_sat_p;	//Delaying the input error by 2 clock
			D_prev_err <= D_err_dff;//cycles, acts as the error[t-delta(t)]
		end
	end

	//////////////////////////////////
	// Pipelining Flop for prev_err //
	//////////////////////////////////

	logic signed [9:0] D_prev_err_p;

	always @(posedge clk, negedge rst_n)
		if(!rst_n)
			D_prev_err_p <= 10'b000;
		else
			D_prev_err_p <= D_prev_err;

	//Obtaining the error value of error[t] - error[t-delta(t)]
	assign D_diff = $signed(err_sat_p) - $signed(D_prev_err_p);
	
	//Saturating the D_diff depending on the MSBs of D_diff
	assign D_diff_sat =  D_diff[9] & !(&D_diff[8:6]) ? 7'b100_0000 :
						!D_diff[9] &   |D_diff[8:6]  ? 7'b011_1111 :
						D_diff[6:0];

	//Final D_term value
	assign D_term = $signed(D_diff_sat) *  $signed(D_COEFF);
	
	////////////////////////////////////
	// Signed extending I and D term //
	//////////////////////////////////
	logic [13:0] I_term_sign_ex , D_term_sign_ex;
	
	assign I_term_sign_ex = {{5{I_term[8]}},I_term};
	assign D_term_sign_ex = {D_term[12],D_term};
	
	//////////////////////////////
	// Generating the PID term //
	////////////////////////////
	logic signed [13:0] PID_term;

	///////////////////////////////////////////
	// Pipelining Flops for P, I and D Terms //
	///////////////////////////////////////////
	
	logic signed [13:0] P_term_p;
	logic signed [13:0] I_term_p;
	logic signed [13:0] D_term_p;

	always @(posedge clk, negedge rst_n)
		if(!rst_n) begin
			P_term_p <= 14'b000;
			I_term_p <= 14'b000;
			D_term_p <= 14'b000;
		end
		else begin
			P_term_p <= P_term;
			I_term_p <= I_term_sign_ex;
			D_term_p <= D_term_sign_ex;
		end

	//assign PID_term = $signed(P_term) + $signed(I_term_sign_ex) + $signed(D_term_sign_ex);
	assign PID_term = $signed(P_term_p) + $signed(I_term_p) + $signed(D_term_p);

	//////////////////////////////////
	// Zero Extending frwrd signal //
	////////////////////////////////
	logic [10:0] frwrd_z_ex;
	
	assign frwrd_z_ex = {1'b0, frwrd};
	
	////////////////////////////////////
	// Generating lft_spd & rght_spd //
	//////////////////////////////////
	
	logic signed [10:0] lft_spd_raw, rght_spd_raw;
	logic signed [10:0] lft_spd_sat, rght_spd_sat;
	
	//Add the forward motion with the PID term for left speed
	assign lft_spd_raw = $signed(frwrd_z_ex) + $signed(PID_term[13:3]);
	
	//Saturate the left speed if my PID term was positive but my left speed is negative
	assign lft_spd_sat = ((~PID_term[13]) & lft_spd_raw[10]) ? 11'h3FF : lft_spd_raw;
	
	//Subtract the PID term from the forward motion for right speed
	assign rght_spd_raw = $signed(frwrd_z_ex) - $signed(PID_term[13:3]);

	//Saturate the right speed if my PID term was negative but my left speed is also negative
	assign rght_spd_sat = (PID_term[13] & rght_spd_raw[10]) ? 11'h3FF : rght_spd_raw;
	
	/////////////////////////////
	// Set spd only if moving //
	///////////////////////////
	
	assign lft_spd = moving_p ? lft_spd_sat : 11'h000;
	assign rght_spd = moving_p ? rght_spd_sat : 11'h000;
	
endmodule