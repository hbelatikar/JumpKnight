package test_package;
    
    task automatic init_and_rst(ref clk, rst_n);
        clk 	= 1'b0;
		rst_n 	= 1'b0;
		
		repeat(2)@(negedge clk);
		rst_n	= 1'b1;
		repeat(2) @(negedge clk);

    endtask 

    task automatic send_RCOM_command(
        input [15:0] cmd_to_snd,
        ref [15:0] cmd, 
        ref snd_cmd,
        ref clk);
        
        @(negedge clk);
        cmd = cmd_to_snd;
        
        snd_cmd = 1'b1;
        @(negedge clk);
        snd_cmd = 1'b0;
    endtask
    
    task automatic check_timeout(ref clk, input int cycles_to_wait, string test_error);
        repeat (cycles_to_wait) @(posedge clk);
        $display("ERROR: Timed out due to %s!", test_error);
    endtask

    task automatic condition_checker(ref test_fail, input logic condition, string true_msg, string false_msg );
        if (condition) 
            $display("%s", true_msg);
        else begin
            $display("ERROR: %s", false_msg);
            test_fail = 1'b1;
        end
				
    endtask //automatic

    task automatic happy_msg_printer(ref test_fail, int test_file, input stop_test, string test_name);
        if(test_file) begin
            if (!test_fail) begin
                $fdisplay(test_file, "Your DUT PASSED the %s test! :D ", test_name);
                $display("Your DUT PASSED the %s test! :D ", test_name);
            end else begin
                $fdisplay(test_file, "Your DUT FAILED the %s test! :( ", test_name);
                $display("Your DUT FAILED the %s test! :( ", test_name);
            end
        end else begin
            if (!test_fail) begin
                $display("Your DUT PASSED the %s test! :D ", test_name);
            end else begin
                $display("Your DUT FAILED the %s test! :( ", test_name);
            end 
        end
        if(stop_test) begin
            $fclose(test_file);
            $stop();
        end
    endtask //automatic

endpackage