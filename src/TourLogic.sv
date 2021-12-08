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
	logic [4:0] last_move [0:23];				//<< 1-D array (of size 24) to keep track of last move taken from each move index >>
	logic [4:0] poss_moves [0:23];			//<< 1-D array (of size 24) to keep track of possible moves from each move index >>
	logic [7:0] move_try;				//<< move_try ... not sure you need this.  I had this to hold move I would try next >>
	logic [4:0] move_num;				//...when you have moved 24 times you are done.  Decrement when backing up >>
	logic [2:0] xx;
	logic [2:0] yy;						//<< xx, yy couple of 3-bit vectors that represent the current x/y coordinates of the knight>
	localparam total_moves = 24;
	integer possible_move;
	integer a, b, i, j, x, xoff, yoff;
	logic update_position, init_board, start, init_move_try, making_move,  incr_move_num, shift_left, decr_move_num, back_up, update_pos;
		
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

//board ff
	always_ff@(posedge clk, negedge rst_n)
	begin 
	if(!rst_n)
		//initialise board on reset
		begin 
		for(int i=0; i<5; i++) begin
			for(int j=0; j<5; j++) begin
				board[i][j] <= 5'd0;
			end
		end
		end
	//initialise board on go assertion
	else if(init_board)
			begin
		for(int i=0; i<5; i++) begin
			for(int j=0; j<5; j++) begin
				board[i][j] <= 5'd0;
			end
		end
		end
	else if(start)
		begin
		board[x_start][y_start] <= 1;	//## mark starting position as visited with non-zero
		end
	else if(making_move)
		begin 
		board[xx + xoff][yy + yoff] <= move_num + 1;
		end
	else if(back_up)
		board[xx][yy] = 0;					//# since we are backing up we have no longer visited this square
	end 


//xx ff
	always_ff@(posedge clk, negedge rst_n)
	begin 
	if(!rst_n)
		xx<=0;
	else if(start)
		xx <= x_start;	//## initialize location as starting position
	else if(making_move)
		xx <= xx + xoff;	
	else if(back_up)
		xx = xx - off_x(move_try);
	end

//yy ff
	always_ff@(posedge clk, negedge rst_n)
	begin 
	if(!rst_n)
		yy<=0;
	else if(start)
		yy <= y_start;				//## initialize location as starting position
	else if(making_move)
		yy <= yy + yoff;
	else if(back_up)
		yy = yy - off_y(move_try);
	end

//move_try shift register
always_ff@(posedge clk, negedge rst_n)
	begin 
	if(!rst_n)
		move_try<=8'b00000000;
	else if(init_move_try)
		move_try<=8'b00000001;
	else if(shift_left)
		move_try<={move_try[6:0],1'b0};
	else if(back_up)
		move_try <= {last_move[move_num-1],1'b0};		//# next move to try is last one advanced 
	end
//update pos ff
always_ff@(posedge clk, negedge rst_n)
	begin 
	if(!rst_n)
	update_position<=1'b0;
	else if(update_pos)
	update_position<=1'b1;
	else 
	update_position<=1'b0;
	end

//move number pos ff
always_ff@(posedge clk, negedge rst_n)
	begin 
	if(!rst_n)
		move_num<=5'b0;
	else if(incr_move_num)
		move_num<=move_num+1;
	else if(decr_move_num)
		move_num<=move_num-1;
	end
	//Defining States
	typedef enum logic [2:0] {IDLE, INIT, POSSIBLE, MAKE_MOVE, BACKUP} state_t;
	state_t state, nxt_state;
	
	//State register
	always_ff @ (posedge clk, negedge rst_n)
		if(!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;


	// State Machine Transition Logic 
	always_comb begin 
		
		nxt_state = state;
		done = 1'b0;
		init_board=1'b0;
		start=1'b0;
		init_move_try=1'b0;
		making_move=1'b0;
		incr_move_num=1'b0;
		shift_left=1'b0;
		decr_move_num=1'b0;
		back_up=1'b0;
		update_pos=1'b0;

		case (state)

			IDLE:	
				if (go) begin
					//## zero out board array & move_num ##
					init_board=1'b1;
					nxt_state = INIT;		    //## Initialize first board position
				end

			INIT: begin
				start=1'b1;
				nxt_state = POSSIBLE;
				end
				
			//# POSSIBLE State (discover all possible moves from this new position) #
			POSSIBLE: begin
				init_move_try = 1'b1;				//## always start with LSB move
				//$display("possible", move_try);
				//$display("possible", move_num);
				poss_moves[move_num] = calc_poss(xx, yy); // # determine all possible moves from this square
				//$display("hello",poss_moves[move_num]);
				//$display("possible 1", calc_poss(xx, yy));
				nxt_state = MAKE_MOVE;
			end

			MAKE_MOVE:
				begin
				//$display("making move", move_num);
				//$display("making move 1", move_try);
				//$display("zzzzzzzzzzzzzzzzzzzzzzzzzzzzz", (poss_moves[move_num] & move_try) && (board[xx + xoff][yy + yoff] == 0));
				if ((|poss_moves[move_num] & (|move_try)) && (board[$signed (xx) +$signed(xoff)][$signed(yy) + $signed(yoff)] == 0)) begin //## move possible
				
					making_move=1'b1;	
					update_pos = 1'b1;
					last_move[move_num] = move_try;
					if (move_num == 23) begin //# we are done!
						done = 1'b1;
						nxt_state = IDLE;
					end
					else 
						begin
						nxt_state = POSSIBLE;
						end
					incr_move_num=1'b1;
				end
				else if (move_try != 8'b1000_0000) begin // ## move was not possible, is there another we could try?
					shift_left=1'b1;		//# advance to see if next move is possible
					nxt_state = MAKE_MOVE;
				end
				else		//## no moves possible...we need to backup
					begin
					nxt_state = BACKUP;
				
					end
				end
			BACKUP: begin
				back_up=1;
				if (last_move[move_num-1] != 8'b1000_0000) 		//# after backing up we have some moves to try
					begin
					nxt_state = MAKE_MOVE;
					end
				decr_move_num=1'b1;	
			end
			default:
				nxt_state = IDLE;

		endcase 
	end

	assign move = move_try;
	logic [7:0] try;
logic [4:0] possible_move_local;
	function [7:0] calc_poss(input [2:0] xpos,ypos);
		///////////////////////////////////////////////////
		// Consider writing a function that returns a packed byte of
		// all the possible moves (at least in bound) moves given
		// coordinates of Knight.
		/////////////////////////////////////////////////////
		possible_move_local = 5'b0;
		
		assign try = 8'b0000_0001;	//## Start with LSB
		for (x=0; x<8; x++) begin
//$display("I am inside for loop");
$display("xx:", xpos ,"xoff:", off_x(try) , "yy", ypos ,"yoff", off_y(try) , try);
//$display("A",(xpos + off_x(try) >= 0));
//$display("B",(xpos + off_x(try) < 5) );
//$display("C",(ypos + off_y(try) >= 0));
//$display("D",(ypos + off_y(try) < 5));
$display("result", (($signed(xpos) + $signed(off_x(try)) >= 0) && ($signed (xpos) + $signed (off_x(try)) < 5) && ($signed(ypos) + $signed(off_y(try)) >= 0) && (ypos + off_y(try) < 5)));
			if (($signed(xpos) + $signed(off_x(try)) >= 0) && ($signed (xpos) + $signed (off_x(try)) < 5) && ($signed(ypos) + $signed(off_y(try)) >= 0) && ($signed (ypos) + $signed(off_y(try)) < 5)) begin
				//## if location tried is in bounds
				$display("I am inside if");
				if (board[(xpos) + (off_x(try))][(ypos) +(off_y(try))] == 0) begin  //## if has not been visited
					possible_move_local = possible_move_local + 1'b1;				//## add it as a possible move
					$display("inside ", possible_move_local);
				end
			end
			try = {try[6:0],1'b0};
		end

		$display("possible moves ", possible_move_local);
		return possible_move_local;
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