module TourLogic (clk,rst_n,x_start,y_start,go,done,indx,move);

	input clk,rst_n;				// 50MHz clock and active low asynch reset
	input [2:0] x_start, y_start;	// starting position on 5x5 board
	input go;						// initiate calculation of solution
	input [4:0] indx;				// used to specify index of move to read out
	output logic done;				// pulses high for 1 clock when solution complete
	output [7:0] move;				// the move addressed by indx (1 of 24 moves)

	////////////////////////////////////////
	// Declare needed internal registers //
	//////////////////////////////////////
	
	logic [4:0] board [0:4] [0:4];		//<< 2-D array of 5-bit vectors that keep track of where on the board the knight has visited. Will be reduced to 1-bit boolean after debug phase >>
	logic last_move [0:23];				//<< 1-D array (of size 24) to keep track of last move taken from each move index >>
	logic poss_moves [0:23];			//<< 1-D array (of size 24) to keep track of possible moves from each move index >>
	logic [7:0] move_try;				//<< move_try ... not sure you need this.  I had this to hold move I would try next >>
	logic [4:0] move_num;				//...when you have moved 24 times you are done.  Decrement when backing up >>
	logic [2:0] xx;
	logic [2:0] yy;						//<< xx, yy couple of 3-bit vectors that represent the current x/y coordinates of the knight>>
	logic update_position;
	localparam total_moves = 24;
	integer possible_move;
	integer a, b, i, j, x, xoff, yoff;

	// Defining offsets for every possible move
	always_comb begin
		
		case (move_try)
			8'b0000_0001: begin
				xoff = -1;
				yoff = 2;
			end
			8'b0000_0010: begin
				xoff = 1;
				yoff = 2;
			end
			8'b0000_0100: begin
				xoff = -2;
				yoff = 1;
			end
			8'b0000_1000: begin
				xoff = -2;
				yoff = -1;
			end
			8'b0001_0000: begin
				xoff = -1;
				yoff = -2;
			end
			8'b0010_0000: begin
				xoff = 1;
				yoff = -2;
			end
			8'b0100_0000: begin
				xoff = 2;
				yoff = 1;
			end
			8'b1000_0000: begin
				xoff = 2;
				yoff = -1;
			end
		endcase
	end
	
	///////////////////////////////////////
	// Create enumerated type for state //
	/////////////////////////////////////
	typedef enum logic [2:0] {IDLE, INIT, POSSIBLE, MAKE_MOVE, BACKUP} fsm_state;
	fsm_state state, nxt_state;

	// Infer State Machine Flip Flop Logic
	always_ff @(posedge clk, negedge rst_n)
		if (!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;

	// State Machine Transition Logic 
	always_comb begin 
		
		nxt_state = state;
		move_num = 5'd0;				//## we have made no moves yet.
		done = 1'b0;
		update_position = 1'b0;

		case (state)

			IDLE:	
			//go = 1;
				if (go) begin
					//## zero out board array & move_num ##
					for(i=0; i<5; i++) begin
						for(int j=0; j<5; j++) begin
							board[i][j] = 5'd0;
						end
					end
					$strobe("Board index value: ", board[i][j]);
					nxt_state = INIT;		    //## Initialize first board position
				end

			INIT: begin
				board[x_start][y_start] = 1;	//## mark starting position as visited with non-zero
				xx = x_start;					//## initialize location as starting position
				yy = y_start;
				nxt_state = POSSIBLE;
			end
				
			//# POSSIBLE State (discover all possible moves from this new position) #
			POSSIBLE: begin
				poss_moves[move_num] = calc_poss(xx, yy); // # determine all possible moves from this square
				move_try = 8'b0000_0001;				//## always start with LSB move
				nxt_state = MAKE_MOVE;
			end

			MAKE_MOVE:
				if ((poss_moves[move_num] & move_try) && (board[xx + xoff][yy + yoff] == 0)) begin //## move possible
					board[xx + xoff][yy + yoff] = move_num + 1;
					xx = xx + xoff;
					yy = yy + yoff;
					update_position = 1'b1;
					last_move[move_num] = move_try;
					if (move_num == 23) begin //# we are done!
						done = 1'b1;
						nxt_state = IDLE;
					end
					else 
						nxt_state = POSSIBLE;
					move_num ++;
				end
				else if (move_try != 8'b1000_0000) begin // ## move was not possible, is there another we could try?
					move_try = (move_try << 1);	//# advance to see if next move is possible
					nxt_state = MAKE_MOVE;
				end
				else		//## no moves possible...we need to backup
					nxt_state = BACKUP;
				
			BACKUP: begin
				board[xx][yy] = 0;					//# since we are backing up we have no longer visited this square
				xx = xx - off_x(move_try);
				yy = yy - off_y(move_try);
				move_try = (last_move[move_num-1] << 1);		//# next move to try is last one advanced 
				if (last_move[move_num-1] != 8'b1000_0000) 		//# after backing up we have some moves to try
					nxt_state = MAKE_MOVE;
				move_num --;	
			end
			default:
				nxt_state = IDLE;

		endcase 
	end

	assign move = move_try;
	
	function [7:0] calc_poss(input [2:0] xpos,ypos);
		///////////////////////////////////////////////////
		// Consider writing a function that returns a packed byte of
		// all the possible moves (at least in bound) moves given
		// coordinates of Knight.
		/////////////////////////////////////////////////////
		possible_move = 1'b0;
		move_try = 8'b0000_0001;										//## Start with LSB
		for (x=0; x<8; x++) begin
			if ((xx + xoff >= 0) && (xx + xoff < 5) && (yy + yoff >= 0) && (yy + yoff < 5)) begin
				//## if location tried is in bounds
				if (board[xx + xoff][yy + yoff] == 0) begin  //## if has not been visited
					possible_move = possible_move + 1'b1;				//## add it as a possible move
				end
			end
			move_try = (move_try << 1);
		end
		return possible_move;
	endfunction
	
	function signed [2:0] off_x(input [7:0] try);
		///////////////////////////////////////////////////
		// Consider writing a function that returns a the x-offset
		// the Knight will move given the encoding of the move you
		// are going to try.  Can also be useful when backing up
		// by passing in last move you did try, and subtracting 
		// the resulting offset from xx
		/////////////////////////////////////////////////////
		integer x_offset;
		x_offset = 0;

		// Defining x offsets for every possible move
		
		case (try)
			8'b0000_0001: begin
				x_offset = -1;
			end
			8'b0000_0010: begin
				x_offset = 1;
			end
			8'b0000_0100: begin
				x_offset = -2;
			end
			8'b0000_1000: begin
				x_offset = -2;
			end
			8'b0001_0000: begin
				x_offset = -1;
			end
			8'b0010_0000: begin
				x_offset = 1;
			end
			8'b0100_0000: begin
				x_offset = 2;
			end
			8'b1000_0000: begin
				x_offset = 2;
			end
		endcase
		return x_offset;
	endfunction
	
	function signed [2:0] off_y(input [7:0] try);
		///////////////////////////////////////////////////
		// Consider writing a function that returns a the y-offset
		// the Knight will move given the encoding of the move you
		// are going to try.  Can also be useful when backing up
		// by passing in last move you did try, and subtracting 
		// the resulting offset from yy
		/////////////////////////////////////////////////////
		integer y_offset;
		y_offset = 0;
		// Defining y offsets for every possible move
		case (try)
			8'b0000_0001: begin
				y_offset = 2;
			end
			8'b0000_0010: begin
				y_offset = 2;
			end
			8'b0000_0100: begin
				y_offset = 1;
			end
			8'b0000_1000: begin
				y_offset = -1;
			end
			8'b0001_0000: begin
				y_offset = -2;
			end
			8'b0010_0000: begin
				y_offset = -2;
			end
			8'b0100_0000: begin
				y_offset = 1;
			end
			8'b1000_0000: begin
				y_offset = -1;
			end
		endcase
		return y_offset;
	endfunction
  
endmodule