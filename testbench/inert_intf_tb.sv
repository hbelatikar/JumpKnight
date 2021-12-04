
module inert_intf_tb ();
	logic clk, rst_n, MISO, cal_done, INT, strt_cal, moving, lftIR, rghtIR;
	logic [11:0] heading;
	logic rdy, SS_n, SCLK, MOSI;
	
	
	inert_intf iDUT	(.clk(clk), .rst_n(rst_n), .MISO(MISO), .cal_done(cal_done), .INT(INT), .strt_cal(strt_cal), .moving(moving), 
					 .lftIR(lftIR), .rghtIR(rghtIR), .heading(heading), .rdy(rdy), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI));
	
	SPI_iNEMO2 iSIM(.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI),.INT(INT));
	
	always #5 clk = ~clk;	
	
	initial begin
		clk = 1'b0;
		rst_n = 1'b0;
		moving = 1'b1;
		lftIR = 1'b0;
		rghtIR = 1'b0;
		strt_cal = 1'b0;
		
		@(negedge clk);
		rst_n = 1'b1;
		
		fork
			begin: setup_timeout
				repeat(200000) @(posedge clk);
				$display("ERROR: SPI Setup testbench timed out!");
				$stop();
				//disable INT_setupsetup_timeout;
			end
			
			begin: INT_setup
				@(posedge iSIM.NEMO_setup);
				$display("Senor Initialization Complete!");
				disable setup_timeout;
			end
		join
		
		fork
			begin: tb_timeout
				repeat(20000000) @(posedge clk);
				$display("ERROR: Testbench timed out!");
				disable inert_intf_tests;
			end
			
			begin: inert_intf_tests
				@(negedge clk);
				strt_cal = 1'b1;
				@(negedge clk);
				strt_cal = 1'b0;
				
				repeat(8000000) @(posedge clk);
				disable tb_timeout;
			end
		join
		$stop();
	end
endmodule