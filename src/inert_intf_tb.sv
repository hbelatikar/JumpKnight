module inert_intf_tb();

logic clk, rst_n, strt_cal, cal_done, rdy, lftIR, rghtIR, SS_n, SCLK, MOSI, MISO, INT, moving;

logic [11:0] heading;

//Instantiate intert_intf block
inert_intf iDUT_inert(.clk(clk),.rst_n(rst_n),.strt_cal(strt_cal),.cal_done(cal_done),.heading(heading),.rdy(rdy),.lftIR(lftIR),
                  .rghtIR(rghtIR),.SS_n(SS_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO),.INT(INT),.moving(moving));

//Intantiate SPI comm block
SPI_iNEMO2 iDUT_NEMO(.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI),.INT(INT));

//Begin
initial begin
	rst_n = 0;		//assert reset
	clk = 0;
//Keep moving lftIR and rghtIR as it is - not testing here!
	moving = 1;		
	lftIR = 0;
	rghtIR = 0;

	repeat(2) @(negedge clk) rst_n = 1;	//deassert reset

	@(posedge iDUT_NEMO.NEMO_setup)		//wait for NEMO to setup and get ready to accept commands

	strt_cal = 1;				//Start inert sensor calibration

	repeat(1) @(posedge clk) strt_cal = 0;	//Deassert start cal signal

	@(posedge cal_done)			//Wait for calibration done from sensor

	repeat(8000000) @(posedge clk);		//Wait for 8 Million cycles and keep reading heading data

	$stop();

end

always
	#5 clk = ~clk;


endmodule
