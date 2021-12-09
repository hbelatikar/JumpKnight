module KnightsTour_tb_PWM_NEMO_check();

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
        output_file = $fopen("output_file.txt", "w"); 
        if (output_file)
            $display("Writing output to %d", output_file);
        else begin
            $display("OUTPUT FILE NOT FOUND");
            $finish();
        end
    end

    initial begin
    init_and_rst( .clk(clk), .rst_n(RST_n));
    $display("TEST-1 : Performing PWM Value Check and Verifying NEMO setup.");

    fork
        begin : PWM_val_check
            $display("TEST-1.1 : Performing PWM Value Check.");
            @(negedge clk);
            $display("Motor 1 \t lftPWM1 Value:  %d \t lftPWM2 Value:  %d", iDUT.iMTR.lftPWM1,  iDUT.iMTR.lftPWM2);
            $display("Motor 2 \t rghtPWM1 Value: %d \t rghtPWM2 Value: %d", iDUT.iMTR.rghtPWM1, iDUT.iMTR.rghtPWM2);
            $display("Motor 1 \t Duty Value: %d \t Motor 2 \t Duty Value: %d", iDUT.iMTR.Lduty, iDUT.iMTR.Rduty);
            
            if(     (~iDUT.iMTR.lftPWM1 & iDUT.iMTR.lftPWM2) & 
                    (~iDUT.iMTR.rghtPWM1 & iDUT.iMTR.rghtPWM2) &
                    ( iDUT.iMTR.Lduty === 11'h400) &
                    ( iDUT.iMTR.Rduty === 11'h400)) begin
                $display("PWM Values are correct!");
            end else begin
                $display("PWM Values are incorrect!");
                test_fail = 1'b1;
            end
            disable PWM_timeout;
        end

        begin : PWM_timeout
            check_timeout(.clk(clk), .cycles_to_wait(100), .test_error("PWM Values are not correct"));
            test_fail = 1'b1;
            disable PWM_val_check;
        end
    join

    fork
        begin : NEMO_setup	
            $display("TEST-1.2 : Verifying NEMO is set up.");
            @(posedge iPHYS.iNEMO.NEMO_setup);	
            $display("NEMO Setup DONE.");
            disable timeout_nemo;
        end
        
        begin : timeout_nemo
            check_timeout(.clk(clk), .cycles_to_wait(500000), .test_error("NEMO did not set up"));
            test_fail = 1'b1;
        end
    join

    happy_msg_printer(.test_fail(test_fail), .test_name("TEST 1.1 - PWM Values Check"), .test_file(output_file), .stop_test(1'b0));
    happy_msg_printer(.test_fail(test_fail), .test_name("TEST 1.2 - NEMO Setup"), .test_file(output_file), .stop_test(1'b1));

    end

    always
    #5 clk = ~clk;

endmodule