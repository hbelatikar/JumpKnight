module KnightsTour_tb_moveE2FF();

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

    localparam logic [2:0] IDLE = 0, G6_note = 1, C7_note = 2, E7_note_1 = 3 , G7_note_1 = 4, E7_note_2 = 5, G7_note_2 = 6;

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
    $display("TEST-4 : Move Two Square East with Fan Fare Test");

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
        begin : move_E2FF
            $display("Starting Test 4");
            $display("Sending Command..");
            send_RCOM_command (.cmd_to_snd(16'h3BF2), .cmd(cmd), .snd_cmd(send_cmd), .clk(clk));
            @(posedge cmd_sent);
            $display("Command Sent!");
            
            condition_checker (.condition((iDUT.iCMD.frwrd === 10'h000)), .true_msg("frwrd reg initialized to zero"), .test_fail(test_fail),
                                .false_msg("frwrd reg not getting initialized to zero when move command is sent!"));
            $display("resp: \t EXPECTED : 000 \t OBSERVED : %h", iDUT.iCMD.frwrd);
            
            repeat(10) @(posedge clk);
            
            error_val_to_compare = iDUT.error;
            condition_checker (.condition((iDUT.error !== 10'h000)), .true_msg("Error value updated"),
                                .false_msg("Error value did not update!"), .test_fail(test_fail));
            $display("resp: \t EXPECTED : ~000 \t OBSERVED : %h", iDUT.error);

            condition_checker (.condition(iDUT.iCMD.moving), .true_msg("moving signal is asserted succesfully"),
                                .false_msg("moving signal is not asserted!"), .test_fail(test_fail));
            $display("resp: \t EXPECTED : 1 \t OBSERVED : %h", iDUT.iCMD.moving);
            
            condition_checker (.condition($signed(iDUT.lft_spd) > $signed(iDUT.rght_spd) ), .true_msg("left speed greater than right speed!"),
                                .false_msg("left speed not greater than right speed!!"), .test_fail(test_fail));
            $display("resp: \t EXPECTED : lft>rght \t OBSERVED : lft_spd: %d \t rght_spd: %d", iDUT.lft_spd, iDUT.rght_spd);
            
            repeat(700000) @(posedge clk);
            condition_checker (.condition(($signed(iDUT.error) < $signed(error_val_to_compare)) | ($signed(iDUT.error) > $signed(error_val_to_compare)) ), 
                                .true_msg("Bot is turning properly!"),
                                .false_msg("bot isn't turning correctly!!"), .test_fail(test_fail));
            $display("error: \t EXPECTED_ABSOLUTE : %d < %d", iDUT.error, error_val_to_compare);
            
            $display("Waiting for signal to start moving forward");
            @(posedge iDUT.iCMD.inc_frwrd);
            repeat(100) @(posedge clk);
            condition_checker (.condition((iDUT.iCMD.frwrd > 10'h000)), .true_msg("Bot is moving forward!"),
                                .false_msg("bot isn't moving forward!!"), .test_fail(test_fail));
            $display("error: \t EXPECTED : %d > 0", iDUT.iCMD.frwrd);

            $display("Waiting for the first center strip");
            @(posedge iDUT.cntrIR);
            $display("first center strip edge detected");
            $display("Waiting for the second center strip");
            @(posedge iDUT.cntrIR);
            $display("Second center strip edge detected");
            condition_checker (.condition((iDUT.iCMD.frwrd === 10'h300)), .true_msg("Bot at Max speed"),
                                .false_msg("bot did not reach max speed yet!"), .test_fail(test_fail));
            $display("error: \t EXPECTED : 0x300 \t OBSERVED : %h", iDUT.iCMD.frwrd);
            $display("Waiting for the first center strip");

            @(posedge iDUT.cntrIR);
            $display("first center strip edge detected");
            $display("Waiting for the second center strip");
            @(posedge iDUT.cntrIR);
            $display("Second center strip edge detected");
            
            repeat(3000) @(posedge clk);
            condition_checker (.condition((iDUT.iCMD.frwrd < 10'h300)), .true_msg("Bot speed decreasing"),
                                .false_msg("bot speed not decreasing!"), .test_fail(test_fail));
            $display("error: \t EXPECTED : 0x300 \t OBSERVED : %h", iDUT.iCMD.frwrd);
            
            if(!iDUT.fanfare_go)
                @(posedge iDUT.fanfare_go);
            $display("Fanfare go succesfully asserted!");

            if(!piezo)
                @(posedge piezo);
            $display("Fan Fare playing succesfully!");

            disable move_E2FF_timeout;
        end

        begin : move_E2FF_timeout
            check_timeout(.clk(clk), .cycles_to_wait(10000000), .test_error("move east 2 square with fanfare did not complete"));
            test_fail = 1'b1;
            disable move_E2FF;
        end
    join

    fork
        begin : charge_chk
            condition_checker (.condition((iDUT.iCHRG.state === G6_note)), .true_msg("Reached first note"),
                                .false_msg("did not reach first note!"), .test_fail(test_fail));
            $display("error: \t EXPECTED : 1 (IDLE) \t OBSERVED : %h", iDUT.iCHRG.state);
            repeat(35000) @(posedge clk);

            condition_checker (.condition((iDUT.iCHRG.state === C7_note)), .true_msg("Reached second note"),
                                .false_msg("did not reach next note!"), .test_fail(test_fail));
            $display("error: \t EXPECTED : 2 (IDLE) \t OBSERVED : %h", iDUT.iCHRG.state);
            
            disable charge_chk_timeout;
        end

        begin : charge_chk_timeout
            check_timeout(.clk(clk), .cycles_to_wait(3650000), .test_error("Charge should have finished by now."));
            test_fail = 1'b1;
            disable charge_chk;
        end
    join
    
    happy_msg_printer(.test_fail(test_fail), .test_name("TEST 4 - Move East 2 Square with Fan Fare"), .test_file(output_file), .stop_test(1'b1));

    end

    always
    #5 clk = ~clk;

endmodule