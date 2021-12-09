module TourLogic_tb ();

    logic clk, rst_n, go, done;
    logic [7:0] move;
    logic [4:0] indx;
    logic [2:0] x_start, y_start;

    TourLogic iDUT (.clk(clk), .rst_n(rst_n), .x_start(x_start), .y_start(y_start), .go(go), .done(done), .indx(indx), .move(move));

    initial begin
        
        clk = 1'b0;
        rst_n = 1'b0;
        go = 1'b0;
        indx = 5'b00000;
        x_start = 3'b010;
        y_start = 3'b010;

        // Deassert Reset
		@(negedge clk);
		rst_n = 1'b1;

        @(negedge clk);
        go = 1'b1;
        @(negedge clk);
        go = 1'b0;

        // Wait for done or timeout if it does not occur
		fork begin: wait_for_done
				repeat(10000000)@(posedge clk);
				$display("Error: Waiting for done");
				$stop();
			end

			begin: done_set
				@(posedge done);
				$display("done is asserted \n");
				disable wait_for_done;
                $stop();
			end
		join
    end

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Look inside DUT for position to update. When it does print out state of board. This is very helpful in debug. //
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    always @(negedge iDUT.update_position) begin : Display
        
        integer x, y;
        for (y = 4; y >= 0; y--) begin
            $display("%2d  %2d  %2d  %2d  %2d\n", iDUT.board[0][y], iDUT.board[1][y], iDUT.board[2][y], iDUT.board[3][y], iDUT.board[3][y]);
        end
        $display("--------------------\n");
    end

    always
        
        #5 clk = ~ clk;

endmodule
