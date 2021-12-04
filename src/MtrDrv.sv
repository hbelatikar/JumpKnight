
module MtrDrv (
	input clk, rst_n,
	input signed [10:0] lft_spd, rght_spd,
	output lftPWM1, lftPWM2, rghtPWM1, rghtPWM2
	);
	
	logic signed [10:0] Lduty, Rduty;
	
	PWM11 LModulator (.clk(clk), .rst_n(rst_n), .duty(Lduty), .PWM_sig(lftPWM2), .PWM_sig_n(lftPWM1));
	PWM11 RModulator (.clk(clk), .rst_n(rst_n), .duty(Rduty), .PWM_sig(rghtPWM2), .PWM_sig_n(rghtPWM1));
	
	assign Lduty = $signed(lft_spd)  + 11'h400;
	assign Rduty = $signed(rght_spd) + 11'h400;
	
endmodule