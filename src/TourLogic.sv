module TourLogic(clk,rst_n,x_start,y_start,go,done,indx,move);

  input clk,rst_n;				// 50MHz clock and active low asynch reset
  input [2:0] x_start, y_start;	// starting position on 5x5 board
  input go;						// initiate calculation of solution
  input [4:0] indx;				// used to specify index of move to read out
  output logic done;			// pulses high for 1 clock when solution complete
  output [7:0] move;			// the move addressed by indx (1 of 24 moves)
  typedef enum logic [2:0] {IDLE,INIT,POSSIBLE,MAKE_MOVE,BACKUP} state_t;
	state_t state, nxt_state;
  ////////////////////////////////////////
  // Declare needed internal registers //
  //////////////////////////////////////
  
  logic [4:0] board[0:4][0:4];			//<< 2-D array of 5-bit vectors that keep track of where on the board the knight
										//has visited.  Will be reduced to 1-bit boolean after debug phase >>
  logic last_move[0:23];				//<< 1-D array (of size 24) to keep track of last move taken from each move index >>
  logic poss_moves[0:23];				//<< 1-D array (of size 24) to keep track of possible moves from each move index >>
  logic [7:0] move_try;						//<< move_try ... not sure you need this.  I had this to hold move I would try next >>
  logic [4:0] move_num;					//...when you have moved 24 times you are done.  Decrement when backing up >>
  logic [2:0] xx;
  logic [2:0] yy;						//<< xx, yy couple of 3-bit vectors that represent the current x/y coordinates of the knight>>
  localparam total_moves=24;
  integer possible_move;
  integer try;
  integer i,j, x;
  
  
  always_comb
  begin 
  move_num = 0;				//## we have made no moves yet.
  state=nxt_state;
  case(state)
 IDLE:	
//go = 1;
	begin
	if (go) 
		begin
		//## zero out board array & move_num ##
        for(i=0;i<5;i++)
			begin 
				for(j=0;j<5;j++)
					begin
					board[x][y] = 0;
					end 
			end		          
        
		nxt_state = INIT;		    //## Initialize first board position
		end
	end
  INIT:
	begin
		board[x_start][y_start] = 1;	//## mark starting position as visited with non-zero
		xx = x_start;					//## initialize location as starting position
		yy = y_start;
		nxt_statestate = POSSIBLE;
	end
  
    //# POSSIBLE State (discover all possible moves from this new position) #
    POSSIBLE: 
		begin
			poss_moves[move_num] = calc_poss(xx, yy); // # determine all possible moves from this square
			move_try = 8'b00000001;				//## always start with LSB move
			nxt_state = MAKE_MOVE;
		end
  MAKE_MOVE:
	begin 
	if ((poss_moves[move_num] & move_try) &&   //## move possible
	    (board[xx+xoff{move_try}][yy+yoff{move_try}]==0)) 
			begin
				board[xx+xoff{move_try}][yy+yoff{move_try}] = move_num + 1;
				xx = xx+xoff{move_try};
				yy = yy+yoff{move_try};
				last_move[move_num] = move_try;
					if (move_num==23)  //# we are done!
					begin
						go = 0;
						nxt_state = IDLE;
					end
		
					else 
						nxt_state = POSSIBLE;
   
      move_num++;
	end
	else if (move_try!=8'b10000000) // ## move was not possible, is there another we could try?
		begin 
			move_try = (move_try<<1);	//# advance to see if next move is possible
			nxt_state = MAKE_MOVE;
		end
    
	else 					//## no moves possible...we need to backup
			nxt_state = BACKUP;
	end
  
   BACKUP:
   begin
		board[xx][yy] = 0;					//# since we are backing up we have no longer visited this square
		xx = xx - off_x(move_try);
		yy = yy - off_y(move_try);
		move_try = (last_move[move_num-1]<<1);		//# next move to try is last one advanced 
		if (last_move[move_num-1]!=8'b10000000) 		//# after backing up we have some moves to try
			state = MAKE_MOVE;
		move_num--;	
	end
  
  endcase 
  end

  //defining offsets for one hot 
localparam xoff{1} = -1;
localparam yoff{1} = 2;
localparam xoff{2} = 1; 
localparam yoff{2} = 2;
localparam xoff{4} = -2; 
localparam yoff{4} = 1;
localparam xoff{8} = -2; 
localparam yoff{8} = -1;
localparam xoff{16} = -1;
localparam yoff{16} = -2;
localparam xoff{32} = 1;
localparam yoff{32} = -2;
localparam xoff{64} = 2;
localparam yoff{64} = 1;
localparam xoff{128} = 2;
localparam yoff{128} = -1;

//intialise the starting position to the centre of the board which is a black square
initial begin 
x_start=3'b0;
y_start=3'b0;
end

//state machine 
  
  function [7:0] calc_poss(input [2:0] xpos,ypos);
    ///////////////////////////////////////////////////
	// Consider writing a function that returns a packed byte of
	// all the possible moves (at least in bound) moves given
	// coordinates of Knight.
	/////////////////////////////////////////////////////
	possible_move = 1'b0;
    try = 1'b1;										//## Start with LSB
  for (x=0; x<8; x++) {
    if ((xx+xoff{try}>=0) && (xx+xoff{try}<5) &&(yy+yoff{try}>=0) && (yy+yoff{try}<5)) {
	//## if location tried is in bounds
 	    if (board[xx+xoff{try}][yy+yoff{try}]==0) {  //## if has not been visited
		possible_move = possible_move+1'b1;				//## add it as a possible move
	  }
	}
    try = try<<1;
  }
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
	x_offset=0;
	x_offset=xoff{last_move[move_num-1]};
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
	y_offset=0;
	y_offset=yoff{last_move[move_num-1]};
	return y_offset;
	
  endfunction
  
endmodule
	  
      
  