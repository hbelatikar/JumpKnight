`timescale 1ns/1ps
module KnightsTour_tb_cal_check();

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
    int output_file;
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
    $display("TEST-2 : Calibration Test");

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

            repeat(1000) @(posedge clk);
            disable calibration_timeout;
        end

        begin : calibration_timeout
            check_timeout(.clk(clk), .cycles_to_wait(500000), .test_error("calibration did not complete properly"));
            test_fail = 1'b1;
            disable calibration_test;
        end
    join

    happy_msg_printer(.test_fail(test_fail), .test_name("TEST 2 - Calibration"), .test_file(output_file), .stop_test(1'b1));

    end

    always
    #5 clk = ~clk;

endmodule