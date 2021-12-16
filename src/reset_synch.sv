module reset_synch (RST_n, clk, rst_n);

	input RST_n, clk;
	
	output rst_n;
	
	logic FF1;
	logic FF2;
	
	//Double flop the reset to 1 to allow synchronisation across reset pins
	always @(posedge clk, negedge RST_n)
		if(!RST_n) begin
			FF1 <= 0;
			FF2 <= 0;
		end
		else begin
			FF1 <= 1'b1;
			FF2 <= FF1;
		end
			
	assign rst_n = FF2;

endmodule
