/*verilog test bench code for command process module*/

module cmd_proc_tb();

	import test_package::*;	//Importing package to streamline testing;

	logic clk, rst_n;
	logic [15:0]cmd_UART_PROC, cmd_TB_RCOM;
	logic snd_cmd_TB_RCOM;
	logic [7:0] resp_PROC_UART, resp_RCOM_TB;
	logic resp_rdy_RCOM_TB;
	logic lftIR, cntrIR, rghtIR;
	logic fanfare_go;
	logic [9:0] frwrd;
	logic [11:0] error;
	logic moving;
	logic heading_rdy_INERT_PROC;
	logic strt_cal,cal_done;
	logic cmd_rdy_UART_PROC	,clr_cmd_rdy_PROC_UART;
	logic [11:0] heading;
	logic tour_go;
	logic SS_n,SCLK,MISO,MOSI,INT;

	// logic [7:0] LED;
	logic UART_TX_RCOM_RX;
	logic UART_RX_RCOM_TX;

	logic test_fail;

	/* instantiation of DUT*/
	cmd_proc iDUT(	.clk(clk),.rst_n(rst_n),.cmd(cmd_UART_PROC),.cmd_rdy(cmd_rdy_UART_PROC),
					.clr_cmd_rdy(clr_cmd_rdy_PROC_UART),.send_resp(send_resp),.strt_cal(strt_cal), 
					.cal_done(cal_done),.heading(heading),.heading_rdy(heading_rdy_INERT_PROC),
					.lftIR(lftIR),.cntrIR(cntrIR),.rghtIR(rghtIR),.error(error),.frwrd(frwrd),
					.moving(moving),.tour_go(tour_go),.fanfare_go(fanfare_go));

	/*Instantiation of UART wrapper*/
	UART_wrapper iWRAP(
					.clk(clk), .rst_n(rst_n), .RX(UART_RX_RCOM_TX), .trmt(send_resp), .clr_cmd_rdy(clr_cmd_rdy_PROC_UART),
					.resp(resp_PROC_UART /*0xA5*/), .TX(UART_TX_RCOM_RX), .tx_done(tx_done), .cmd(cmd_UART_PROC), .cmd_rdy(cmd_rdy_UART_PROC));

	/*Instantiation of inert_intf*/
	inert_intf iINERT(
					.clk(clk),.rst_n(rst_n),.strt_cal(strt_cal),.cal_done(cal_done),.heading(heading),
					.rdy(heading_rdy_INERT_PROC),.lftIR(1'b0/*lftIR*/),.rghtIR(1'b0/*rghtIR*/),.SS_n(SS_n),.SCLK(SCLK),.MOSI(MOSI),
					.MISO(MISO),.INT(INT),.moving(moving));

	/*Instantiation of RemoteCommm*/
	RemoteComm iREMOTE(
					.clk(clk), .rst_n(rst_n), .RX(UART_TX_RCOM_RX), .TX(UART_RX_RCOM_TX), .cmd(cmd_TB_RCOM), .snd_cmd(snd_cmd_TB_RCOM),
					.cmd_snt(cmd_sent), .resp_rdy(resp_rdy_RCOM_TB), .resp(resp_RCOM_TB));

	/*Instantiation of SPI_Nemo*/
	SPI_iNEMO3 iSPI(.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI),.INT(INT));


	//Clock generation
	always #5 clk = ~clk;

	//Start Stimuli
	initial begin
		
		lftIR	= 1'b0;
		rghtIR	= 1'b0;
		cntrIR	= 1'b0;

		test_fail = 1'b0;
		resp_PROC_UART	= 8'hA5;
		cmd_TB_RCOM 	= 16'h0000;
		snd_cmd_TB_RCOM	= 1'b0;
		
		init_and_rst(clk, rst_n);

		fork
			begin : NEMO_setup	
				@(posedge iSPI.NEMO_setup);	
				$display("NEMO Setup DONE.");
				disable timeout_nemo;
			end
			
			begin : timeout_nemo
				check_timeout(.clk(clk), .cycles_to_wait(500000), .test_error("NEMO did not set up"));
				test_fail = 1'b1;
				$stop();
			end
		join

		fork
			begin : calibration_test
				$display("Starting calibration test.");
				send_RCOM_command (.cmd_to_snd(16'h0000), .cmd(cmd_TB_RCOM), .snd_cmd(snd_cmd_TB_RCOM), .clk(clk));
				
				@(posedge cal_done);
				$display("Calibration is done!, waiting for response from RCOM...");

				@(posedge resp_RCOM_TB);
				if(resp_RCOM_TB === 8'hA5)
					$display("Calibration response recieved!");
				else
					$display("ERROR: Wrong Response Code for Calibration Command!");
				disable calibration_timeout;
			end

			begin : calibration_timeout
				check_timeout(.clk(clk), .cycles_to_wait(500000), .test_error("calibration did not complete"));
				test_fail = 1'b1;
			end
		join

		fork
			begin : move_sound
				$display("Starting Move without fanfare test..");
				send_RCOM_command (.cmd_to_snd(16'h3001), .cmd(cmd_TB_RCOM), .snd_cmd(snd_cmd_TB_RCOM), .clk(clk));

				@(posedge cmd_sent);
				condition_checker (.condition((frwrd === 10'h000)), .true_msg("frwrd reg initialized to zero"), .test_fail(test_fail),
								   .false_msg("frwrd reg not getting initialized to zero when move command is sent!"));
				
				repeat(10) @(posedge heading_rdy_INERT_PROC);
				condition_checker (.condition((frwrd === 10'h120)), .true_msg("frwrd reg incremented to proper value"),
								   .false_msg("frwrd reg did not increment!"), .test_fail(test_fail));
				
				condition_checker (.condition(moving), .true_msg("moving signal is asserted succesfully"),
								   .false_msg("moving signal is not asserted!"), .test_fail(test_fail));
				
				repeat(20) @(posedge heading_rdy_INERT_PROC);
				condition_checker (.condition((frwrd ===10'h300)), .true_msg("frwrd reg saturated successfully"),
								   .false_msg("frwrd reg did not saturate!"), .test_fail(test_fail));
				
				$display("Sending first cntrIR pulse.");
				cntrIR = 1'b1;
				repeat(200) @(posedge clk);
				cntrIR = 1'b0;
				repeat(2000) @(posedge clk);
				condition_checker (.condition((frwrd === 10'h300)), .true_msg("frwrd reg is still saturated successfully"),
								   .false_msg("frwrd reg reduced	!"), .test_fail(test_fail));
				
				$display("Sending second cntrIR pulse.");
				cntrIR = 1'b1;
				repeat(200) @(posedge clk);
				cntrIR = 1'b0;
				@(posedge heading_rdy_INERT_PROC);
				repeat(200) @(posedge clk);
				condition_checker (.condition((frwrd < 10'h300)), .true_msg("frwrd reg reduced successfully"),
								   .false_msg("frwrd reg did not reduce!"), .test_fail(test_fail));
				
				@(posedge fanfare_go);
				$display("Fanfare go succesfully asserted!");

				@(posedge resp_rdy_RCOM_TB);
				condition_checker (.condition((frwrd == 10'h000)), .true_msg("frwrd reg reduced successfully to 0"),
								   .false_msg("frwrd reg did not reduce to 0!"), .test_fail(test_fail));
				
				disable move_sound_timeout;
			end

			begin : move_sound_timeout
				check_timeout(.clk(clk), .cycles_to_wait(10000000), .test_error("move with fanfare did not complete"));
				test_fail = 1'b1;
				disable move_sound;
			end
		join

		fork
			begin : move_lftIR_hit
				$display("Starting Move lftIR hit...");
				send_RCOM_command (.cmd_to_snd(16'h2001), .cmd(cmd_TB_RCOM), .snd_cmd(snd_cmd_TB_RCOM), .clk(clk));
				repeat(100000) @(posedge clk);
				lftIR = 1'b1;
				repeat(900000) @(posedge clk);
				lftIR = 1'b0;

				repeat(5000000) @(posedge clk);
				disable move_lftIR_hit_timeout;
			end

			begin : move_lftIR_hit_timeout
				check_timeout(.clk(clk), .cycles_to_wait(10000000), .test_error("move with lftIR hit did not complete"));
				test_fail = 1'b1;
				disable move_lftIR_hit;
			end
		join

		happy_msg_printer(.test_fail(test_fail));

	end




	/*
	initial begin 
	//Initialize values
		clk		= 1'b0;
		rst_n	= 1'b0;
		cal_done= 1'b0;
		strt_cal= 1'b0;

		lftIR	= 1'b0;
		rghtIR	= 1'b0;
		cntrIR	= 1'b0;	
		resp_s	= 8'hA5;
		
		cmd_s	= 16'h0000;	//Start cal
		snd_cmd	= 1'b0;

		@(negedge clk);
		rst_n	= 1'b1;	//deasseting reset

		fork
			begin : wait_for_nemo	
				@(posedge iSPI.NEMO_setup);	
				disable timeout_nemo;
			end
			
			begin : timeout_nemo
				repeat (100000) @(posedge clk);
				$display("error waiting for NEMO");
				$stop();
			end
		join

		@(negedge clk);
		cmd_s	= 16'h0000;	//Send Calibrate command 
		
		@(negedge clk);		//Pulse snd_cmd
		snd_cmd	= 1'b1;
		@(negedge clk);
		snd_cmd = 1'b0;

	//Wait for cal_done or timeout if it does not occur
	fork begin: wait_for_caldone
			repeat(50000)@(posedge clk);
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
	*/
endmodule