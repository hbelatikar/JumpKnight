module TourLogic(clk,rst_n,x_start,y_start,go,done,indx,move);

	input clk,rst_n;				// 50MHz clock and active low asynch reset
	input [2:0] x_start, y_start;	// starting position on 5x5 board
	input go;						// initiate calculation of solution
	input [4:0] indx;				// used to specify index of move to read out
	output logic done;			// pulses high for 1 clock when solution complete
	output [7:0] move;			// the move addressed by indx (1 of 24 moves)

	////////////////////////////////////////
	// Declare needed internal registers //
	//////////////////////////////////////

	//   << some internal registers to consider: >>
	logic [4:0] board [0:4] [0:4];	//   << 2-D array of 5-bit vectors that keep track of where on the board the knight
									//      has visited.  Will be reduced to 1-bit boolean after debug phase >>
	logic [7:0] last_move [0:23];	//   << 1-D array (of size 24) to keep track of last move taken from each move index >>
	logic [7:0] poss_move [0:23];	//   << 1-D array (of size 24) to keep track of possible moves from each move index >>
	logic [7:0] move_try;			//   << move_try ... not sure you need this.  I had this to hold move I would try next >>
	logic [4:0] move_num;			//   << move number...when you have moved 24 times you are done.  Decrement when backing up >>
	logic [2:0] xpos, ypos;			//   << xx, yy couple of 3-bit vectors that represent the current x/y coordinates of the knight>>

	//Declaring local encoded logic
	typedef enum logic [7:0] {	N2W1 = 8'b0000_0001,
								N2E1 = 8'b0000_0010,
								W2N1 = 8'b0000_0100,
								W2S1 = 8'b0000_1000,
								S2W1 = 8'b0001_0000,
								S2E1 = 8'b0010_0000,
								E2S1 = 8'b0100_0000,
								E2N1 = 8'b1000_0000 } encoded_move_t;

	//   << Your magic occurs here >>












	function [7:0] calc_poss(input [2:0] xpos,ypos);
		///////////////////////////////////////////////////
		// Consider writing a function that returns a packed byte of
		// all the possible moves (at least in bound) moves given
		// coordinates of Knight.
		/////////////////////////////////////////////////////
		logic signed [3:0] pos2_x_chk, neg2_x_chk, pos2_y_chk, neg2_y_chk;
		logic signed [3:0] pos1_x_chk, neg1_x_chk, pos1_y_chk, neg1_y_chk;
		logic N2_poss, N1_poss, W2_poss, W1_poss, S2_poss, S1_poss, E2_poss, E1_poss;

		assign pos2_x_chk = xpos + 3'b010;	//xpos+2
		assign pos1_x_chk = xpos + 3'b001;	//xpos+1
		assign pos2_y_chk = ypos + 3'b010;	//ypos+2
		assign pos1_y_chk = ypos + 3'b001;	//ypos+1
		assign neg2_x_chk = xpos + 3'b110;	//xpos-2
		assign neg1_x_chk = xpos + 3'b111;	//xpos-1
		assign neg2_y_chk = ypos + 3'b110;	//ypos-2
		assign neg1_y_chk = ypos + 3'b111;	//ypos-1

		assign N2_poss = ($signed(pos2_y_chk)<5);	//Possible for two steps north
		assign N1_poss = ($signed(pos1_y_chk)<5);	//Possible for one step  north
		
		assign W2_poss = ($signed(neg2_x_chk)>0);	//Possible for two steps west
		assign W1_poss = ($signed(neg1_x_chk)>0);	//Possible for one step  west
		
		assign S2_poss = ($signed(neg2_y_chk)>0);	//Possible for two steps south
		assign S1_poss = ($signed(neg1_y_chk)>0);	//Possible for one step  south
		
		assign E2_poss = ($signed(pos2_x_chk)<5);	//Possible for two steps east
		assign E1_poss = ($signed(pos1_x_chk)<5);	//Possible for one step  east

		always_comb begin : poss_moves_calc
			assign calc_poss[0] = (N2_poss & W1_poss);
			assign calc_poss[1] = (N2_poss & E1_poss);
			assign calc_poss[2] = (W2_poss & N1_poss);
			assign calc_poss[3] = (W2_poss & S1_poss);
			assign calc_poss[4] = (S2_poss & W1_poss);
			assign calc_poss[5] = (S2_poss & E1_poss);
			assign calc_poss[6] = (E2_poss & S1_poss);
			assign calc_poss[7] = (E2_poss & N1_poss);
		end
	endfunction

	function signed [2:0] off_x(input [7:0] try);
		///////////////////////////////////////////////////
		// Consider writing a function that returns a the x-offset
		// the Knight will move given the encoding of the move you
		// are going to try.  Can also be useful when backing up
		// by passing in last move you did try, and subtracting 
		// the resulting offset from xx
		/////////////////////////////////////////////////////
		
	endfunction

	function signed [2:0] off_y(input [7:0] try);
	///////////////////////////////////////////////////
	// Consider writing a function that returns a the y-offset
	// the Knight will move given the encoding of the move you
	// are going to try.  Can also be useful when backing up
	// by passing in last move you did try, and subtracting 
	// the resulting offset from yy
	/////////////////////////////////////////////////////
	endfunction

endmodule