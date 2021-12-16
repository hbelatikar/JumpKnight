module charge_tb ();
	
	logic clk, rst_n, go, piezo_n, piezo;
	
	//Instantiate DUT
	charge iDUT (.clk(clk), .rst_n(rst_n), .go(go), .piezo(piezo), .piezo_n(piezo_n));
	
	//Generate clock
	always #5 clk = ~clk;
	
	initial begin
		clk = 1'b0;
		rst_n = 1'b0;
		go = 1'b0;
		
		repeat(3) @(negedge clk);
			rst_n = 1'b1;
			go = 1'b1;	//Generate go pulse
		@(negedge clk);
			go = 1'b0;
		
		//Wait 3600000 clock cycles and observe state changes in waveform
		repeat (3600000) @(posedge clk);
		$stop();
	end
endmodule
