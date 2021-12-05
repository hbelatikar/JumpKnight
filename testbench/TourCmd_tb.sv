module TourCmd_tb ();
	
	logic	clk, rst_n;
	
	logic	start_tour, send_resp, cmd_rdy,
			clr_cmd_rdy, cmd_rdy_UART;
			
	logic [15:0] cmd_UART, cmd;
	logic [7:0]  resp;
	logic [4:0] mv_indx;
	
	logic test_fail; //To keep track of the test status
	
	typedef enum logic [7:0] {	N2W1 = 8'b0000_0001,
								N2E1 = 8'b0000_0010,
								W2N1 = 8'b0000_0100,
								W2S1 = 8'b0000_1000,
								S2W1 = 8'b0001_0000,
								S2E1 = 8'b0010_0000,
								E2S1 = 8'b0100_0000,
								E2N1 = 8'b1000_0000 } encoded_move_t;

	encoded_move_t move_b2 [0:7] = {N2W1, N2E1, W2N1, W2S1, S2W1, S2E1, E2S1, E2N1};
	encoded_move_t move;

	//Instatiate Module
	TourCmd iDUT (	.clk(clk), .rst_n(rst_n), .start_tour(start_tour), .move(move), .mv_indx(mv_indx),
					.cmd_UART(cmd_UART/*16'h0000*/), .cmd(cmd), .cmd_rdy_UART(/*1'b0*/cmd_rdy_UART), 
					.cmd_rdy(cmd_rdy), .clr_cmd_rdy(clr_cmd_rdy), .send_resp(send_resp), .resp(resp));
					
					
	always #5 clk = ~clk;
	
	logic [7:0] move_bank [0:4] = {
									{8'b0000_0001},
									{8'b0000_0010},
									{8'b0000_0100},
									{8'b0000_1000},
									{8'b0001_0000}
									};

	always_comb begin
		move = move_b2[mv_indx];
	end
	initial begin
		clk = 1'b0;
		rst_n = 1'b0;
		start_tour = 1'b0;
		send_resp = 1'b0;
		clr_cmd_rdy = 1'b0;
		test_fail = 1'b0;
		cmd_rdy_UART = 1'b0;
		cmd_UART = 16'h0000;

		repeat(2) @(negedge clk);
		rst_n = 1'b1;
		@(posedge clk);
		start_tour = 1'b1;
		@(posedge clk);
		start_tour = 1'b0;
		
		fork
            begin: timeout_seq                  //Testbench timeout for any unexpected errors
                repeat(5000) @(posedge clk);
				$display("ERROR: Testbench timed out!");
                test_fail = 1'b1;
				disable test_cases;
            end //timeout_seq 

            begin: test_cases
				
				decomposed_cmd_chk (16'h2002, 16'h33F1);	//N2W1
				decomposed_cmd_chk (16'h2002, 16'h3BF1);	//N2E1
				decomposed_cmd_chk (16'h2001, 16'h33F2);	//W2N1
				decomposed_cmd_chk (16'h27F1, 16'h33F2);	//W2S1
				decomposed_cmd_chk (16'h27F2, 16'h33F1);	//S2W1

				// decomposed_cmd_chk (16'h27F2, 16'h33F1);	//S2E1
				// decomposed_cmd_chk (16'h27F2, 16'h33F1);	//E2S1
				// decomposed_cmd_chk (16'h27F2, 16'h33F1);	//E2N1

                disable timeout_seq;    
            end //test_cases
        join

		//If the test did not fail, print the happy message!
        if (!test_fail) begin   
            $display("Your DUT passed the test! :D ");
        end
        $stop();
	end

	task decomposed_cmd_chk( input [15:0] Y_move,input [15:0] X_move );
		@(posedge cmd_rdy);
		if (cmd !== Y_move) begin
			$display("ERROR!: Non Matching Decomposed Command @%t EXPEC:%h OBSERV:%h", $time, Y_move, cmd);
			test_fail = 1'b1;
		end
		repeat(5) @(posedge clk);
		clr_cmd_rdy = 1'b1;
		repeat(1) @(posedge clk);
		clr_cmd_rdy = 1'b0;

		repeat(5) @(posedge clk);
		if (cmd !== Y_move) begin
			$display("ERROR!: Non-Matching Decomposed Command @%t EXPEC:%h OBSERV:%h", $time, X_move, cmd);
			test_fail = 1'b1;
		end 
		repeat(5) @(posedge clk);
			send_resp = 1'b1;
		repeat(1) @(posedge clk);
			send_resp = 1'b0;
		
		@(posedge cmd_rdy);
		if (cmd !== X_move) begin
			$display("ERROR!: Non Matching Decomposed Command @%t EXPEC:%h OBSERV:%h", $time, Y_move, cmd);
			test_fail = 1'b1;
		end
		repeat(5) @(posedge clk);
		clr_cmd_rdy = 1'b1;
		repeat(1) @(posedge clk);
		clr_cmd_rdy = 1'b0;
		
		repeat(5) @(posedge clk);
		if (cmd !== X_move) begin
			$display("ERROR!: Non-Matching Decomposed Command @%t EXPEC:%h OBSERV:%h", $time, X_move, cmd);
			test_fail = 1'b1;
		end
		repeat(5) @(posedge clk);
			send_resp = 1'b1;
		repeat(1) @(posedge clk);
			send_resp = 1'b0;
		
	endtask

endmodule