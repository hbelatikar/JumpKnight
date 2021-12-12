`timescale 1ns/1ps
module KnightsTour_tb_moveW1();

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
    $display("TEST-3 : Move One Square West Test");

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

            @(posedge clk);
            @(negedge clk);
            condition_checker (.condition(resp_rdy === 1'b0), .true_msg("resp_rdy correctly fell!"), .test_fail(test_fail),
								   .false_msg("resp_rdy is still high after a clock cycle!"));
            $display("resp: \t EXPECTED : 0 \t OBSERVED : %h", resp_rdy);
            disable calibration_timeout;
        end

        begin : calibration_timeout
            check_timeout(.clk(clk), .cycles_to_wait(500000), .test_error("calibration did not complete properly"));
            test_fail = 1'b1;
            disable calibration_test;
        end
    join

    fork
        begin : move_W1
            $display("Starting Move West without fanfare test.");
            $display("Sending Command..");
            send_RCOM_command (.cmd_to_snd(16'h23F1), .cmd(cmd), .snd_cmd(send_cmd), .clk(clk));
            @(posedge cmd_sent);
            $display("Command Sent!");
            
            condition_checker (.condition((iDUT.iCMD.frwrd === 10'h000)), .true_msg("frwrd reg initialized to zero"), .test_fail(test_fail),
                                .false_msg("frwrd reg not getting initialized to zero when move command is sent!"));
            $display("frwrd: \t EXPECTED : 000 \t OBSERVED : %h", iDUT.iCMD.frwrd);
            
            repeat(10) @(posedge clk);
            
            error_val_to_compare = iDUT.error;
            condition_checker (.condition((iDUT.error !== 10'h000)), .true_msg("Error value updated"),
                                .false_msg("Error value did not update!"), .test_fail(test_fail));
            $display("error_val: \t EXPECTED : ~000 \t OBSERVED : %h", iDUT.error);

            condition_checker (.condition(iDUT.iCMD.moving), .true_msg("moving signal is asserted succesfully"),
                                .false_msg("moving signal is not asserted!"), .test_fail(test_fail));
            $display("moving: \t EXPECTED : 1 \t OBSERVED : %h", iDUT.iCMD.moving);
            
            condition_checker (.condition($signed(iDUT.lft_spd) < $signed(iDUT.rght_spd) ), .true_msg("right speed greater than left speed!"),
                                .false_msg("right speed not greater than left speed!!"), .test_fail(test_fail));
            $display("speed: \t EXPECTED : lft<rght \t OBSERVED : lft_spd: %d \t rght_spd: %d", iDUT.lft_spd, iDUT.rght_spd);
            
            repeat(700000) @(posedge clk);
            condition_checker (.condition(($signed(iDUT.error) < $signed(error_val_to_compare)) | ($signed(iDUT.error) > $signed(error_val_to_compare)) ), 
                                .true_msg("Bot is turning properly!"),
                                .false_msg("bot isn't turning correctly!!"), .test_fail(test_fail));
            $display("error_val: \t EXPECTED_ABSOLUTE : %d < %d", iDUT.error, error_val_to_compare);
            
            $display("Waiting for signal to start moving forward");
            @(posedge iDUT.iCMD.inc_frwrd);
            repeat(100) @(posedge clk);
            condition_checker (.condition((iDUT.iCMD.frwrd > 10'h000)), .true_msg("Bot is moving forward!"),
                                .false_msg("bot isn't moving forward!!"), .test_fail(test_fail));
            $display("frwrd: \t EXPECTED : %d > 0", iDUT.iCMD.frwrd);

            $display("Waiting for the first center strip");
            @(posedge iDUT.cntrIR);
            $display("first center strip edge detected");
            @(posedge iDUT.cntrIR);
            $display("Second center strip edge detected");
            condition_checker (.condition((iDUT.iCMD.frwrd === 10'h300)), .true_msg("Bot at Max speed"),
                                .false_msg("bot did not reach max speed yet!"), .test_fail(test_fail));
            $display("frwrd: \t EXPECTED : 0x300 \t OBSERVED : %h", iDUT.iCMD.frwrd);

            repeat(3000) @(posedge clk);
            condition_checker (.condition((iDUT.iCMD.frwrd < 10'h300)), .true_msg("Bot speed decreasing"),
                                .false_msg("bot speed not decreasing!"), .test_fail(test_fail));
            $display("frwrd: \t EXPECTED : 0x300 \t OBSERVED : %h", iDUT.iCMD.frwrd);
            
            // @(posedge fanfare_go);
            // $display("Fanfare go succesfully asserted!");

            @(posedge resp_rdy);
            condition_checker (.condition((iDUT.iCMD.frwrd == 10'h000)), .true_msg("Bot has completed move"),
                                .false_msg("Bot has not completed his move!"), .test_fail(test_fail));
            
            disable move_W1_timeout;
        end

        begin : move_W1_timeout
            check_timeout(.clk(clk), .cycles_to_wait(10000000), .test_error("move west 1 square did not complete"));
            test_fail = 1'b1;
            disable move_W1;
        end
    join
    
    happy_msg_printer(.test_fail(test_fail), .test_name("TEST 3 - Move West 1 Square"), .test_file(output_file), .stop_test(1'b1));

    end

    always
    #5 clk = ~clk;

endmodule