
module MtrDrv (
	input clk, rst_n,
	input signed [10:0] lft_spd, rght_spd,
	output lftPWM1, lftPWM2, rghtPWM1, rghtPWM2
	);
	
	logic signed [10:0] Lduty, Rduty;
	
	//Instantiate the PWM drivers for both the Left and right motors
	PWM11 LModulator (.clk(clk), .rst_n(rst_n), .duty(Lduty), .PWM_sig(lftPWM1), .PWM_sig_n(lftPWM2));
	PWM11 RModulator (.clk(clk), .rst_n(rst_n), .duty(Rduty), .PWM_sig(rghtPWM1), .PWM_sig_n(rghtPWM2));
	
	//Add the offset to set duty cycle in center
	assign Lduty = $signed(lft_spd)  + 11'h400;
	assign Rduty = $signed(rght_spd) + 11'h400;
	
endmodule