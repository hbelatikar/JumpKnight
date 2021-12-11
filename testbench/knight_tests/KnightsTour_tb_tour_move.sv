module KnightsTour_tb_tour_move();

    // << import or include tasks?>>
    import test_package::*;

    /////////////////////////////
    // Stimulus of type reg //
    /////////////////////////
    reg clk, RST_n;
    reg [15:0] cmd;
    reg send_cmd;
    logic test_fail = 1'b0;
    ///////////////////////////////////
    // Declare any internal signals //
    /////////////////////////////////
    wire SS_n,SCLK,MOSI,MISO,INT;
    wire lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
    wire TX_RX, RX_TX;
    logic cmd_sent;
    logic resp_rdy;
    logic [7:0] resp;
    wire IR_en;
    wire lftIR_n,rghtIR_n,cntrIR_n;

    int output_file;
    int error_val_to_compare;

    //////////////////////
    // Instantiate DUT //
    ////////////////////
    KnightsTour iDUT(.clk(clk), .RST_n(RST_n), .SS_n(SS_n), .SCLK(SCLK),
                    .MOSI(MOSI), .MISO(MISO), .INT(INT), .lftPWM1(lftPWM1),
                    .lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
                    .RX(TX_RX), .TX(RX_TX), .piezo(piezo), .piezo_n(piezo_n),
                    .IR_en(IR_en), .lftIR_n(lftIR_n), .rghtIR_n(rghtIR_n),
                    .cntrIR_n(cntrIR_n));
                    
    /////////////////////////////////////////////////////
    // Instantiate RemoteComm to send commands to DUT //
    ///////////////////////////////////////////////////

    RemoteComm iRMT(.clk(clk), .rst_n(RST_n), .RX(RX_TX), .TX(TX_RX), .cmd(cmd),
                .snd_cmd(send_cmd), .cmd_snt(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));

    //////////////////////////////////////////////////////
    // Instantiate model of Knight Physics (and board) //
    ////////////////////////////////////////////////////
    KnightPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
                        .MOSI(MOSI),.INT(INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
                        .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.IR_en(IR_en),
                        .lftIR_n(lftIR_n),.rghtIR_n(rghtIR_n),.cntrIR_n(cntrIR_n)); 


    initial begin
        // opening the file
        output_file = $fopen("output_file.txt", "a"); 
        if (output_file)
            $display("Writing output to %d", output_file);
        else begin
            $display("OUTPUT FILE NOT FOUND");
            $finish();
        end
    end

    initial begin
    
    init_and_rst( .clk(clk), .rst_n(RST_n));
    $display("TEST-6 : Check if tour actually happens");

    fork
        begin : NEMO_setup	
            $display("Verifying NEMO is set up.");
            @(posedge iPHYS.iNEMO.NEMO_setup);	
            $display("NEMO Setup DONE.");
            disable timeout_nemo;
        end
        
        begin : timeout_nemo
            check_timeout(.clk(clk), .cycles_to_wait(500000), .test_error("NEMO did not set up"));
            test_fail = 1'b1;
            disable NEMO_setup;
        end
    join

    fork
        begin : calibration_test
            $display("Starting calibration test.");
            send_RCOM_command (.cmd_to_snd(16'h0000), .cmd(cmd), .snd_cmd(send_cmd), .clk(clk));
            
            @(posedge iDUT.iNEMO.cal_done);
            $display("Calibration is done!, waiting for response from RCOM...");

            @(posedge resp_rdy);
            condition_checker (.condition(resp === 8'hA5), .true_msg("Calibration response recieved!"), .test_fail(test_fail),
								   .false_msg("Wrong Response Code for Calibration Command!"));
            $display("resp: \t EXPECTED : a5 \t OBSERVED : %h", resp);
            disable calibration_timeout;
        end

        begin : calibration_timeout
            check_timeout(.clk(clk), .cycles_to_wait(500000), .test_error("calibration did not complete properly"));
            test_fail = 1'b1;
            disable calibration_test;
        end
    join

    fork
        begin : move_tour_start
            $display("Starting Test 6.1 - Assertion of Tour go");
            $display("Sending Command..");
            send_RCOM_command (.cmd_to_snd(16'h4022), .cmd(cmd), .snd_cmd(send_cmd), .clk(clk));
            if(~iDUT.tour_go)
                @(posedge iDUT.iCMD.tour_go);
            condition_checker (.condition((iDUT.tour_go)), .true_msg("tour_go asserted"), .test_fail(test_fail),
                                .false_msg("tour_go did not assert!"));
            $display("resp: \t EXPECTED : 1 \t OBSERVED : %h", iDUT.tour_go);
            
            disable move_tour_timeout;
        end

        begin : move_tour_timeout
            check_timeout(.clk(clk), .cycles_to_wait(1000000), .test_error("tour_go did not assert"));
            test_fail = 1'b1;
            disable move_tour_start;
        end
    join

    fork
        begin : move_tour_calc_done
            $display("Starting Test 6.2 - Completion of tour moves calculation");
            if(~iDUT.start_tour)
                @(posedge iDUT.start_tour);
            condition_checker (.condition((iDUT.move !== 8'h00)), .true_msg("calculations done and move produced"), .test_fail(test_fail),
                                .false_msg("calculations done but move did not produced!"));
            $display("First move: \t OBSERVED : %b", iDUT.move);
            
            disable move_tour_calc_done_timeout;
        end

        begin : move_tour_calc_done_timeout
            check_timeout(.clk(clk), .cycles_to_wait(1000000), .test_error("start_tour did not assert"));
            test_fail = 1'b1;
            disable move_tour_calc_done;
        end
    join

    fork
        begin : robot_moves_check
            $display("Starting 6.3 - Robot moves Check");
            
            repeat(10) @(posedge clk);
            $display("Is usurp asserted?"); 
            condition_checker (.condition((iDUT.iTC.usurp)), .true_msg("Usurp succesfully asserted"), .test_fail(test_fail),
                                .false_msg("Usurp not asserted!"));
            
            $display("Response defaulted to 0x5A?"); 
            condition_checker (.condition((iDUT.iTC.resp === 8'h5A)), .true_msg("Reponse succesfully defaulted"), .test_fail(test_fail),
                                .false_msg("Response not defaulted!"));
            
            $display("Command changed to Y direction movement?"); 
            condition_checker (.condition((iDUT.iTC.cmd[11:4] === 8'h00) | (iDUT.iTC.cmd[11:4] === 8'h7F)), .true_msg("Move is in Y axis"), .test_fail(test_fail),
                                .false_msg("Move is not in Y axis!"));
            
            $display("Is the robot actually moving?");
            condition_checker (.condition(iDUT.iCMD.moving), .true_msg("Moving signal asserted"), .test_fail(test_fail),
                                .false_msg("Moving signal not asserted"));
            
            $display("Waiting for Y axis move to complete...");

            @(posedge iDUT.iTC.send_resp);
            $display("Move completed!");

            repeat(10) @(posedge clk);
            
            $display("Is horizontal command asserted?");
            condition_checker (.condition((iDUT.iTC.mv_vert_or_horiz)), .true_msg("horizontal selector asserted"), .test_fail(test_fail),
                                .false_msg("horizontal selector not asserted!"));

            $display("Is the new command horizontal?");
            condition_checker (.condition((iDUT.iTC.cmd[11:4] === 8'h3F) | (iDUT.iTC.cmd[11:4] === 8'hBF)), .true_msg("horizontal command asserted"), .test_fail(test_fail),
                                .false_msg("horizontal command not asserted!"));

            $display("Is the robot actually moving?");
            condition_checker (.condition(iDUT.iCMD.moving), .true_msg("Moving signal asserted"), .test_fail(test_fail),
                                .false_msg("Moving signal not asserted"));
            
            if(!iDUT.fanfare_go)
                @(posedge iDUT.fanfare_go);
            $display("X Move completed with fanfare!");
            $display("Send_resp  EXPECTED : 1  \t OBSERVED : %h", iDUT.iTC.send_resp);
            $display("Mv_ind     EXPECTED : 1  \t OBSERVED : %h", iDUT.iTC.mv_indx);
            $display("inc_mv     EXPECTED : 1  \t OBSERVED : %h", iDUT.iTC.inc_mv);
            
            disable robot_moves_check_timeout;
        end

        begin : robot_moves_check_timeout
            check_timeout(.clk(clk), .cycles_to_wait(10000000), .test_error("robot did not start moving"));
            test_fail = 1'b1;
            disable robot_moves_check;
        end
    join

    
    happy_msg_printer(.test_fail(test_fail), .test_name("TEST 6 - Actual Tour Movement"), .test_file(output_file), .stop_test(1'b1));

    end

    always
    #5 clk = ~clk;

endmodule