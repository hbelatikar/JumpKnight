
module PWM11 (
	input clk, rst_n,
	input [10:0] duty,
	output logic PWM_sig, PWM_sig_n
	);
	
	//localparam SYS_CLK = 500000000;
	
	logic [10:0] cnt = 11'h0;
	
	assign PWM_sig_n = ~PWM_sig;
	
	//Counter logic
	always_ff @(posedge clk, negedge rst_n)
	begin
		if(!rst_n) 
			cnt <= 11'h0;
		else
			cnt <= cnt + 1'b1;
	end
	
/* 	//Duty cycle On/Off logic
	@always_comb begin
		if (cnt < duty) 
			PWM_sig_pre_flop = 1'b1;
		else 
			PWM_sig_pre_flop = 1'b0;
	end */
	
	//PWM Signal flopping logic
	always_ff @(posedge clk, negedge rst_n)
	begin
		if(!rst_n) 
			PWM_sig <= 1'b0;
		else begin
			if (cnt < duty)
				PWM_sig <= 1'b1;
			else
				PWM_sig <= 1'b0;
		end
	end
endmodule
	