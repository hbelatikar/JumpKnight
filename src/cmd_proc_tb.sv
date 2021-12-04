/*verilog test bench code for command process module*/

module cmd_proc_tb();

logic clk, rst_n;
logic [15:0]cmd_s, cmd_r;
logic snd_cmd;
logic [7:0] resp_s, resp_r;
logic resp_rdy;
logic lftIR, cntrIR, rghtIR;
logic fanfare_go;
logic [9:0] frwrd;
logic [11:0] error;
logic moving;
logic heading_rdy;
logic strt_cal,cal_done;
logic cmd_rdy,clr_cmd_rdy;
logic [11:0] heading;
logic tour_go;
logic SS_n,SCLK,MISO,MOSI,INT;
logic rdy;
logic [7:0] LED;
logic RX;
logic TX;
logic cmd_sent;
logic trmt;
/* instantiation of DUT*/
cmd_proc iDUT(.clk(clk),.rst_n(rst_n),.cmd(cmd_r),.cmd_rdy(cmd_rdy),.clr_cmd_rdy(clr_cmd_rdy),.send_resp(send_resp),.strt_cal(strt_cal), 
	.cal_done(cal_done),.heading(heading),.heading_rdy(heading_rdy),.lftIR(lftIR),.cntrIR(cntrIR),.rghtIR(rghtIR),.error(error),.frwrd(frwrd),.moving(moving),.tour_go(tour_go),.fanfare_go(fanfare_go));

/*Instantiation of UART wrapper*/
UART_wrapper iWRAP(.clk(clk), .rst_n(rst_n), .RX(TX), .trmt(send_resp), .clr_cmd_rdy(clr_cmd_rdy), .resp(resp_s), .TX(RX), .tx_done(tx_done), .cmd(cmd_r), .cmd_rdy(cmd_rdy));

/*Instantiation of inert_intf*/
inert_intf iINERT(.clk(clk),.rst_n(rst_n),.strt_cal(strt_cal),.cal_done(cal_done),.heading(heading),.rdy(heading_rdy),.lftIR(1'b0),.rghtIR(1'b0),.SS_n(SS_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO),.INT(INT)
		,.moving(moving));

/*Instantiation of RemoteCommm*/
RemoteComm iREMOTE(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .cmd(cmd_s), .snd_cmd(snd_cmd), .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp_r));

/*Instantiation of SPI_Nemo*/
SPI_iNEMO3 iSPI(.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI),.INT(INT));

initial begin 
//Initialize values
	clk=1'b0;
	rst_n=1'b0;
	cal_done=1'b0;
	strt_cal=1'b0;

	lftIR = 1'b0;
	rghtIR = 1'b0;
	cntrIR = 1'b0;	
	resp_s = 8'hA5;
	
	cmd_s=16'h0000;	//Start cal
	snd_cmd=1'b0;

	@(negedge clk);
	rst_n=1'b1;	//deasseting reset
	@(posedge iSPI.NEMO_setup);
	@(negedge clk);
	cmd_s=16'h0000;	//Send Calibrate command 
	@(negedge clk);
	snd_cmd=1'b1;
	@(negedge clk);
	snd_cmd=1'b0;

//Wait for cal_done or timeout if it does not occur
fork begin: wait_for_caldone
		repeat(1000000)@(posedge clk);
		$display("error waiting for cal_done");
		$stop();
	end

	begin: cal_donee
		@(posedge cal_done);
		$display("cal_done is set \n");
		disable wait_for_caldone;
	end
join

//Wait for resp_rdy or timeout if it does not occur

fork begin: wait_for_resp_rdy
		repeat(1000000)@(posedge clk);
		$display("error waiting for resp_rdy");
		$stop();
	end

	begin: resp_rdyy
		@(posedge resp_rdy);
		$display("resp_rdy is set\n");
		disable wait_for_resp_rdy;
	end
join

	cmd_s=16'h2001;	//Send command to move ?north? 1 square (0x2001)
	@(negedge clk);
	snd_cmd=1'b1;
	@(negedge clk);
	snd_cmd=1'b0;

	//@(posedge cmd_sent)

	if(frwrd==10'h000)
	$display("got correct frwrd value");
	else 
	$display("error in frwrd value");

//Wait for 10 positive edges of heading_rdy
	repeat(10) @(posedge heading_rdy)

	$display("frwrd=%h \n",frwrd);

	if(moving===1'b1)
	$display("moving is asserted correctly");
	else 
	$display("error in moving asserted");

//Wait for 10 positive edges of heading_rdy
	repeat(25) @(posedge heading_rdy)

	$display("frwrd=%h \n",frwrd);
	
//pulse on cntrIR (like it crossed a line)
	@(posedge clk);
	cntrIR=1'b1;
	@(posedge clk);
	cntrIR=1'b0;

	repeat(10)@(posedge clk);
	
	$display("frwrd=%h \n",frwrd);

//2nd pulse on cntrIR (it crossed a 2nd line) 
	@(posedge clk);
	cntrIR=1'b1;
	@(posedge clk);
	cntrIR=1'b0;
	$display("frwrd=%h \n",frwrd);

//Wait for resp_rdy or timeout if it does not occur

fork begin: wait_for_resp_rdyy
		repeat(1000000)@(posedge clk);
		$display("error waiting for resp_rdy after nudging");
		$stop();
	end

	begin: resp_rdyyy
		@(posedge resp_rdy);
		$display("resp_rdy is set\n");
		disable wait_for_resp_rdyy;
	end
join

$display("Checking if stopped or not, frwrd=%h \n",frwrd);

//sending another move north command to test rght or left IR stimulus (nudge)

	cmd_s=16'h2001;	//Send command to move ?north? 1 square (0x2001)
	@(negedge clk);
	snd_cmd=1'b1;
	@(negedge clk);
	snd_cmd=1'b0;
	repeat(30)@(posedge clk);	// Wait for it to be up to speed
	lftIR=1'b1;
	@(posedge clk);
	$display("Check for spike in error error=%h \n",error);
	lftIR=1'b0;
	repeat(1000)@(posedge clk);	//Wait to see transitions
	repeat(1000)@(posedge clk);
	$stop();
end

//Clock generation
always
	#5 clk = ~clk;
endmodule



























