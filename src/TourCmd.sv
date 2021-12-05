
module TourCmd(clk,rst_n,start_tour,move,mv_indx,
               cmd_UART,cmd,cmd_rdy_UART,cmd_rdy,
			   clr_cmd_rdy,send_resp,resp);

  input clk,rst_n;			// 50MHz clock and asynch active low reset
  input start_tour;			// from done signal from TourLogic
  input [7:0] move;			// encoded 1-hot move to perform
  output reg [4:0] mv_indx;	// "address" to access next move
  input [15:0] cmd_UART;	// cmd from UART_wrapper
  input cmd_rdy_UART;		// cmd_rdy from UART_wrapper
  output [15:0] cmd;		// multiplexed cmd to cmd_proc
  output cmd_rdy;			// cmd_rdy signal to cmd_proc
  input clr_cmd_rdy;		// from cmd_proc (goes to UART_wrapper too)
  input send_resp;			// lets us know cmd_proc is done with command
  output [7:0] resp;		// either 0xA5 (done) or 0x5A (in progress)

	//Defining Local Params & Typedefs
	//Logic for storing decomposed movement commands
	logic [15:0] Y_cmd, X_cmd, cmd_TOUR;
	
	//Decomposed movement directions commands
	localparam	NORTH = 8'h00,
				EAST  = 8'hBF,
				SOUTH = 8'h7F,
				WEST  = 8'h3F;
	
	//Total Moves Required for completion
	localparam LAST_MOVE_INDX = 5'd23;

	//One hot encoded movement command from TourLogic
	typedef enum logic [7:0] {	N2W1 = 8'b0000_0001,
								N2E1 = 8'b0000_0010,
								W2N1 = 8'b0000_0100,
								W2S1 = 8'b0000_1000,
								S2W1 = 8'b0001_0000,
								S2E1 = 8'b0010_0000,
								E2S1 = 8'b0100_0000,
								E2N1 = 8'b1000_0000 } encoded_move_t;
	encoded_move_t encoded_move;
	
	assign encoded_move = encoded_move_t'(move);
	localparam	MOVE 	 = 4'b0010,	//Opcode to move knight 
				MOVE_FAN = 4'b0011; //Opcode to move knight with fan fare
				
	//Number of squares to move
	localparam	TWO_SQUARE = 4'b0010, 
				ONE_SQUARE = 4'b0001; 
				
	//Defining internal logic
	logic 	usurp, cmd_rdy_TOUR,
			mv_vert_or_horiz,		// Vertical=>0 Horizontal => 1
			inc_mv, clr_mv_indx;
	
	//Generating the move index counter
	always_ff @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			mv_indx = 5'b0;
		else if (clr_mv_indx)
			mv_indx = 5'b0;
		else if (inc_mv)
			mv_indx = mv_indx + 1'b1;
	end
	
	//Generating the resp to UART logic
	//// If my knights tour has ended (24 moves are done) and 
	//// if my usurp control was enabled at that time,
	//// send resp as 0xA5 or else keep sending 0x5A
	assign resp = (usurp & (mv_indx == LAST_MOVE_INDX)) ? 8'hA5 : 8'h5A;
	
	//Generating logic for move decomposition
	always_comb begin
		case(encoded_move)
			N2W1 : begin
				Y_cmd = {MOVE	  , NORTH , TWO_SQUARE};	//
				X_cmd = {MOVE_FAN , WEST  , ONE_SQUARE};
			end
			
			N2E1 : begin
				Y_cmd = {MOVE	  , NORTH , TWO_SQUARE};
				X_cmd = {MOVE_FAN , EAST  , ONE_SQUARE};
			end
			
			W2N1 : begin
				Y_cmd = {MOVE	  , NORTH , ONE_SQUARE};
				X_cmd = {MOVE_FAN , WEST  , TWO_SQUARE};
			end
			
			W2S1 : begin
				Y_cmd = {MOVE	  , SOUTH , ONE_SQUARE};
				X_cmd = {MOVE_FAN , WEST  , TWO_SQUARE};
			end
			
			S2W1 : begin
				Y_cmd = {MOVE	  , SOUTH , TWO_SQUARE};
				X_cmd = {MOVE_FAN , WEST  , ONE_SQUARE};
			end
			
			S2E1 : begin
				Y_cmd = {MOVE	  , SOUTH , TWO_SQUARE};
				X_cmd = {MOVE_FAN , EAST  , ONE_SQUARE};
			end
			
			E2S1 : begin
				Y_cmd = {MOVE	  , SOUTH , ONE_SQUARE};
				X_cmd = {MOVE_FAN , EAST  , TWO_SQUARE};
			end
			
			E2N1 : begin
				Y_cmd = {MOVE	  , NORTH , ONE_SQUARE};
				X_cmd = {MOVE_FAN , EAST  , TWO_SQUARE};
			end

			default : begin
				Y_cmd = 16'h0000;
				X_cmd = 16'h0000;
			end
		endcase
	end 

	//Select between the generated vertical or horizontal move 
	assign cmd_TOUR = mv_vert_or_horiz ? X_cmd : Y_cmd;
	//If usurp is high send out tour commands
	assign cmd = usurp ? cmd_TOUR : cmd_UART;
	//If usurp is high cmd_rdy is set by TourCmd
	assign cmd_rdy = usurp ? cmd_rdy_TOUR : cmd_rdy_UART;
	
	//Defining States
	typedef enum logic [2:0] {IDLE, Y_MOVE, Y_HOLD, X_MOVE, X_HOLD} t_state;
	t_state state, n_state;
	
	//State register
	always_ff @ (posedge clk, negedge rst_n)
		if(!rst_n)
			state <= IDLE;
		else
			state <= n_state;
	
	//Next state and output logic
	always_comb begin
		//Defaulting outputs
		n_state = state;
		usurp = 1'b0;
		clr_mv_indx = 1'b0;
		inc_mv = 1'b0;
		cmd_rdy_TOUR = 1'b0;
		mv_vert_or_horiz = 1'b0;
		
		case(state)
			///DEFAULT CASE => IDLE///
			default: begin
				if (start_tour) begin
					usurp = 1'b1;
					n_state = Y_MOVE;
					clr_mv_indx = 1'b1;
				end
			end
			
			Y_MOVE : begin
				usurp = 1'b1;
				cmd_rdy_TOUR = 1'b1;
				if(clr_cmd_rdy) begin
					n_state = Y_HOLD;
				end
			end
			
			Y_HOLD : begin
				usurp = 1'b1;
				if(send_resp) begin
					n_state = X_MOVE;
					mv_vert_or_horiz = 1'b1;
				end
			end
			
			X_MOVE : begin
				usurp = 1'b1;
				mv_vert_or_horiz = 1'b1;
				cmd_rdy_TOUR = 1'b1;
				if(clr_cmd_rdy) begin
					n_state = X_HOLD;
				end
			end
			
			X_HOLD : begin
				usurp = 1'b1;
				mv_vert_or_horiz = 1'b1;
				if(send_resp & (mv_indx == LAST_MOVE_INDX)) 
					n_state = IDLE;
				else if(send_resp & (mv_indx < LAST_MOVE_INDX)) begin
					inc_mv = 1'b1;
					n_state = Y_MOVE;
				end
			end
		endcase
	end
endmodule