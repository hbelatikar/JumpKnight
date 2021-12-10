module TourLogic_hsb(clk,rst_n,x_start,y_start,go,done,indx,move);

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
	logic [7:0] poss_moves [0:23];	//   << 1-D array (of size 24) to keep track of possible moves from each move index >>
	logic [7:0] move_try;			//   << move_try ... not sure you need this.  I had this to hold move I would try next >>
	logic [4:0] move_num;			//   << move number...when you have moved 24 times you are done.  Decrement when backing up >>
	logic [2:0] xpos, ypos;			//   << xx, yy couple of 3-bit vectors that represent the current x/y coordinates of the knight>>
	
	logic [7:0] encoded_poss_moves, curr_mask, curr_move;
	logic [4:0]	mv_indx;
	logic clr_board, init_tour, update_pos, back_up, clr_mv_indx, inc_mv_indx, dec_mv_indx,
			get_moves, flash_mask;
	localparam logic [7:0]	N2W1 = 8'b0000_0001,
							N2E1 = 8'b0000_0010,
							W2N1 = 8'b0000_0100,
							W2S1 = 8'b0000_1000,
							S2W1 = 8'b0001_0000,
							S2E1 = 8'b0010_0000,
							E2S1 = 8'b0100_0000,
							E2N1 = 8'b1000_0000;

	typedef enum logic [3:0] { IDLE, START, POSSIBLE, MOVE, BACKUP, SELECT_MOVE } state_t;
	state_t state, n_state;

	//Registers to hold values where knight moved to 
	always_ff @( posedge clk, negedge rst_n ) begin : board_flops
		if(!rst_n)
			board <= '{default: 5'b0};
		else if (clr_board) 
			board <= '{default: 5'b0};
		else if (init_tour)
			board[x_start][y_start] <= 5'h01;
		else if (update_pos)
			board[xpos][ypos] <= mv_indx + 1'b1;
		else if (back_up)
			board[xpos][ypos] <= 5'b0;
	end

	//Registers to hold current position of knight
	always_ff @( posedge clk, negedge rst_n ) begin : position_regs
		if(!rst_n) begin
			xpos <= 3'b0;
			ypos <= 3'b0;
		end else if (init_tour) begin
			xpos <= x_start;
			ypos <= y_start;
		end else if (update_pos) begin
			xpos <= xpos + $signed(off_x(curr_move));
			ypos <= ypos + $signed(off_y(curr_move));
		end else if (back_up) begin
			xpos <= xpos - $signed(off_x(curr_move));
			ypos <= ypos - $signed(off_y(curr_move));
		end
	end

	//Up/down Counter for mv_ind register
	always_ff @( posedge clk, negedge rst_n ) begin : mv_indx_reg
		if(!rst_n) 
			mv_indx <= 5'b0;
		else if (clr_mv_indx)
			mv_indx <= 5'b0;
		else if (inc_mv_indx)
			mv_indx <= mv_indx + 1'b1;
		else if (dec_mv_indx)
			mv_indx <= mv_indx - 1'b1;
	end

	//Possible Moves Register Bank
	always_ff @( posedge clk, negedge rst_n ) begin : poss_moves_bank
		if(!rst_n)	begin
			poss_moves <= '{default : 8'b0};
			curr_move  <= 8'b0;
		end
		else if (init_tour) begin
			poss_moves <= '{default : 8'b0};
			curr_move  <= 8'b0;
		end
		else if (get_moves)
			poss_moves[mv_indx] <= calc_poss(xpos, ypos);	
		else if (flash_mask) begin
			poss_moves[mv_indx] <= poss_moves[mv_indx] & ~curr_mask;
			curr_move  <= poss_moves[mv_indx] & curr_mask;
		end
	end

	///////////////////////
	//	STATE MACHINE	//
	/////////////////////

	//State registers
	always_ff @( posedge clk, negedge rst_n ) begin : state_regs
		if(!rst_n)
			state <= IDLE;
		else
			state <= n_state;
	end

	//State outputs and transitions
	always_comb begin : SM_out_trans
		
		n_state		= state;
		curr_mask	= 8'h00;
		done		= 1'b0;
		clr_mv_indx	= 1'b0;
		clr_board	= 1'b0;	
		init_tour	= 1'b0;
		flash_mask	= 1'b0;
		back_up		= 1'b0;
		inc_mv_indx	= 1'b0;
		dec_mv_indx	= 1'b0;
		get_moves	= 1'b0;

		case(state)

			////	DEFAULT = IDLE	//////
			default: begin
				if(go) begin
					n_state		= START;
					clr_board	= 1'b1;	
					clr_mv_indx = 1'b1;
				end	
			end

			START: begin
				init_tour	= 1'b1;
				n_state		= POSSIBLE;
			end
			
			POSSIBLE: begin
				get_moves	= 1'b1;
				n_state		= SELECT_MOVE;
			end

			SELECT_MOVE: begin
				if (poss_moves[mv_indx][0]) begin
					curr_mask	= 8'h01;
				end else if (poss_moves[mv_indx][1]) begin
					curr_mask	= 8'h02;
				end else if (poss_moves[mv_indx][2]) begin
					curr_mask	= 8'h04;
				end else if (poss_moves[mv_indx][3]) begin
					curr_mask	= 8'h08;
				end else if (poss_moves[mv_indx][4]) begin
					curr_mask	= 8'h10;
				end else if (poss_moves[mv_indx][5]) begin
					curr_mask	= 8'h20;
				end else if (poss_moves[mv_indx][6]) begin
					curr_mask	= 8'h40;
				end else if (poss_moves[mv_indx][7]) begin
					curr_mask	= 8'h80;
				end else
					curr_mask	= 8'h00;
				flash_mask	= 1'b1;	
				n_state = MOVE;
			end

			MOVE: begin
				update_pos	= 1'b1;
				inc_mv_indx	= 1'b1;
				if((mv_indx == 5'd23) && (curr_move == 8'h00)) begin
					done = 1'b1;
					n_state = IDLE;
				end else if ((mv_indx != 5'd23) && (curr_move != 8'h00))
					n_state = POSSIBLE;
				else if ((mv_indx != 5'd23) && (curr_move == 8'h00))
					n_state = BACKUP;
			end

			BACKUP:begin
				back_up = 1'b1;
				dec_mv_indx = 1'b1;	
				n_state = POSSIBLE;
			end
		endcase
	end

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

		// // always_comb begin : poss_moves_calc
		// 	assign calc_poss[0] = (N2_poss & W1_poss) && (board [neg1_x_chk] [pos2_y_chk] == 0);
		// 	assign calc_poss[1] = (N2_poss & E1_poss) && (board [pos1_x_chk] [pos2_y_chk] == 0);
		// 	assign calc_poss[2] = (W2_poss & N1_poss) && (board [neg2_x_chk] [pos1_y_chk] == 0);
		// 	assign calc_poss[3] = (W2_poss & S1_poss) && (board [neg2_x_chk] [neg1_y_chk] == 0);
		// 	assign calc_poss[4] = (S2_poss & W1_poss) && (board [neg1_x_chk] [neg2_y_chk] == 0);
		// 	assign calc_poss[5] = (S2_poss & E1_poss) && (board [pos1_x_chk] [neg2_y_chk] == 0);
		// 	assign calc_poss[6] = (E2_poss & S1_poss) && (board [pos2_x_chk] [neg1_y_chk] == 0);
		// 	assign calc_poss[7] = (E2_poss & N1_poss) && (board [pos2_x_chk] [pos1_y_chk] == 0);
			assign calc_poss[0] = (N2_poss & W1_poss) && (board [neg1_x_chk] [pos2_y_chk] == 0);
			assign calc_poss[1] = (N2_poss & E1_poss) && (board [pos1_x_chk] [pos2_y_chk] == 0);
			assign calc_poss[2] = (W2_poss & N1_poss) && (board [neg2_x_chk] [pos1_y_chk] == 0);
			assign calc_poss[3] = (W2_poss & S1_poss) && (board [neg2_x_chk] [neg1_y_chk] == 0);
			assign calc_poss[4] = (S2_poss & W1_poss) && (board [neg1_x_chk] [neg2_y_chk] == 0);
			assign calc_poss[5] = (S2_poss & E1_poss) && (board [pos1_x_chk] [neg2_y_chk] == 0);
			assign calc_poss[6] = (E2_poss & S1_poss) && (board [pos2_x_chk] [neg1_y_chk] == 0);
			assign calc_poss[7] = (E2_poss & N1_poss) && (board [pos2_x_chk] [pos1_y_chk] == 0);
		// end
	endfunction

	function signed [2:0] off_x(input [7:0] try);
		///////////////////////////////////////////////////
		// Consider writing a function that returns a the x-offset
		// the Knight will move given the encoding of the move you
		// are going to try.  Can also be useful when backing up
		// by passing in last move you did try, and subtracting 
		// the resulting offset from xx
		/////////////////////////////////////////////////////
		
		case (try)
			N2W1 : off_x = -3'h1;
			N2E1 : off_x = 3'h1;
			W2N1 : off_x = -3'h2;
			W2S1 : off_x = -3'h2;
			S2W1 : off_x = -3'h1;
			S2E1 : off_x = 3'h1;
			E2S1 : off_x = 3'h2;
			E2N1 : off_x = 3'h2;
			default : off_x = 3'h0;
		endcase
	endfunction

	function signed [2:0] off_y(input [7:0] try);
	///////////////////////////////////////////////////
	// Consider writing a function that returns a the y-offset
	// the Knight will move given the encoding of the move you
	// are going to try.  Can also be useful when backing up
	// by passing in last move you did try, and subtracting 
	// the resulting offset from yy
	/////////////////////////////////////////////////////
	
		case (try)
			N2W1 : off_x = 3'h2;
			N2E1 : off_x = 3'h2;
			W2N1 : off_x = 3'h1;
			W2S1 : off_x = -3'h1;
			S2W1 : off_x = -3'h2;
			S2E1 : off_x = -3'h2;
			E2S1 : off_x = -3'h1;
			E2N1 : off_x = 3'h1;
			default : off_x = 3'h0;
		endcase
	endfunction

endmodule