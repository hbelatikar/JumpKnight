
module UART_rx (
	input clk, rst_n, clr_rdy, RX,
	output [7:0] rx_data,
	output logic rdy
	);
	
	//Local Param definitions
	localparam BAUD_LIMIT = 12'hA2C;	//Baud Limit = 2604 cycles
	localparam MID_BAUD_LIMIT = 12'h516;//Half Baud limit = 2604/2 = 1302
	// localparam BAUD_LIMIT = 12'hA2;		//for testing
	// localparam MID_BAUD_LIMIT = 12'h51;	//for testing
	
	//Internal logic definitions
	logic shift, start, receiving, set_rdy, RX_dff, RX_mstable;
	logic [3:0]  bit_cnt;
	logic [8:0]  rx_shift_reg;
	logic [11:0] baud_cnt;
	
	//Defining states
	typedef enum logic {IDLE, RECV} t_state;
	t_state state, n_state;
	
	//Double flopping RX to remove metastability
	always_ff@(posedge clk, negedge rst_n)
	begin
		if (!rst_n) begin
			RX_dff <= 1'b1;
			RX_mstable <= 1'b1;
		end else begin
			RX_dff <= RX;
			RX_mstable <= RX_dff;	
		end
	end
	
	//Assign bits of shift register which contain data to rx_data
	assign rx_data = rx_shift_reg[7:0];
	
	//If baud count is 2604 then set shift bit as high so
	//that we move onto sending the next in the shift register
	assign shift = (baud_cnt == 0) ? 1'b1 : 1'b0;
	
	//Flopping logic to transmit the receive through the RX line
	always_ff@(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			//Preset all the bits to 1's for idle condition 
			rx_shift_reg <= 9'h1FF;	
		else
			//Shift in the bits if 'shift' is high
			if(shift) rx_shift_reg <= {RX_mstable,rx_shift_reg[8:1]};
	end
	
	//Timer logic to count down the cycles to read the data on the RX line,
	//Should count down from 1302(mid of baud cycle) to 0
	//19200 baud with 50Mhz -> 2604 bauds. [i.e. (50 * 10^6)/(19200) = 2604]
	//Middle of baud is 2604/2 = 1302 clocks. Each subsequent count down should
	//be 2604.
	always_ff@(posedge clk, negedge rst_n) 
	begin
		if(!rst_n) 
			baud_cnt <= MID_BAUD_LIMIT;	//Reset the counter to mid baud limit
		else begin
			case ({start|shift, receiving}) inside 
				//When start signal is sent OR the timer reached 0 counts, presetreset the counter 
				//to the appropriate value depending if the start bit is high
				2'b1? : baud_cnt <= (start) ? MID_BAUD_LIMIT : BAUD_LIMIT;	
				//Increment the counter when transmitting is HIGH
				2'b01 : baud_cnt <= baud_cnt - 1'b1;	
			endcase;
		end		
	end
	
	//Bit counter logic
	//Count how many bits have been received. 
	//Helps the state machine in deciding if all the data has been received
	always_ff@(posedge clk, negedge rst_n) 
	begin
		if(!rst_n) 
			bit_cnt <= 4'b0;	//Reset the counter
		else begin
			case ({start,shift}) inside 
				//When start signal is sent reset the bit counter for receiving in the data
				2'b1? : bit_cnt <= 4'b0;	
				//Increment the counter when a bit has been shifted in (shift bit is HIGH)
				2'b01 : bit_cnt <= bit_cnt + 1'b1;	
			endcase;
		end
	end
	
	//S-R Reg for rdy flag
	always_ff@(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			rdy <= 1'b0;
		else if(start|clr_rdy)
			rdy <= 1'b0;
		else if (set_rdy) 
			rdy <= 1'b1;
	end
	
	//FSM logic to control transmission
	always_ff@(posedge clk, negedge rst_n) 
	begin
		if(!rst_n)
			state <= IDLE;
		else
			state <= n_state;
	end
	
	always_comb 
	begin
		n_state = state;
		set_rdy = 1'b0;
		start = 1'b0;
		receiving = 1'b0;
		
		case (state)
			IDLE: begin
				if(~RX_mstable) begin
					start = 1'b1;
					receiving = 1'b1;
					n_state = RECV;
				end
			end
			
			RECV: begin
				receiving = 1'b1;
				if(bit_cnt == 4'hA) begin
					receiving = 1'b0;
					set_rdy = 1'b1;
					n_state = IDLE;
				end
			end
		endcase
	end
endmodule