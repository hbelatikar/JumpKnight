
module UART_tx (
	input clk, rst_n, trmt,
	input [7:0] tx_data,
	output TX, 
	output logic tx_done
	);
	
	//Local Param definitions
	localparam BAUD_LIMIT = 12'hA2C;
	// localparam BAUD_LIMIT = 12'hA2;	//for testing
	
	//Internal logic definitions
	logic shift, init, transmitting, set_done;
	logic [3:0]  bit_cnt;
	logic [8:0]  tx_shift_reg;
	logic [11:0] baud_cnt;
	
	//Defining states
	typedef enum logic {IDLE, TRANSMIT} t_state;
	t_state state, n_state;
	
	//Send out the LSB of tx_shift_reg over the TX wire
	assign TX = tx_shift_reg[0];
	
	//If baud count is 2604 then set shift bit as high so
	//that we move onto sending the next in the shift register
	assign shift = (baud_cnt == BAUD_LIMIT) ? 1'b1 : 1'b0;
	
	//Flopping logic to transmit the data through the TX line
	always_ff@(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			//Set all the bits to 1's since idle condition is transmit high
			tx_shift_reg <= 9'h1FF;	
		else begin
			case ({init,shift}) inside 
				//For transmission set data as tx_data and start bit (1'b0)
				2'b1? : tx_shift_reg <= {tx_data,1'b0};	
				//Shift out the transmitted bit and append high bits
				2'b01 : tx_shift_reg <= {1'b1,tx_shift_reg[8:1]};	
			endcase;
		end
	end
	
	//Timer logic to count the cycles to keep the data on the TX line,
	//Should count to the baud value i.e., 2604.
	//19200 baud with 50Mhz -> 2604 bauds. [i.e. (50 * 10^6)/(19200) = 2604]
	always_ff@(posedge clk, negedge rst_n) 
	begin
		if(!rst_n) 
			baud_cnt <= 12'b0;	//Reset the counter
		else begin
			case ({init|shift,transmitting}) inside 
				//When init signal is sent OR the timer reached 2604 counts, reset the counter 
				2'b1? : baud_cnt <= 12'b0;	
				//Increment the counter when transmitting is HIGH
				2'b01 : baud_cnt <= baud_cnt + 1'b1;	
			endcase;
		end		
	end
	
	//Bit counter logic
	//Count how many bits have been sent out. 
	//Helps the state machine in deciding if all the data has been sent
	always_ff@(posedge clk, negedge rst_n) 
	begin
		if(!rst_n) 
			bit_cnt <= 4'b0;	//Reset the counter
		else begin
			case ({init,shift}) inside 
				//When init signal is sent reset the counter for sending out the data
				2'b1? : bit_cnt <= 4'b0;	
				//Increment the counter when a bit has been shifted out (shift bit is HIGH)
				2'b01 : bit_cnt <= bit_cnt + 1'b1;	
			endcase;
		end		
	end
	
	//S-R Reg for rdy flag
	always_ff@(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			tx_done <= 1'b0;
		else if (init)
			tx_done <= 1'b0;
		else if (set_done) 
			tx_done <= 1'b1;
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
		set_done = 1'b0;
		init = 1'b0;
		transmitting = 1'b0;
		
		case (state)
			IDLE: 
				if(trmt) begin
					init = 1'b1;
					n_state = TRANSMIT;
				end
			
			TRANSMIT:
				if(bit_cnt == 4'hA) begin
					set_done = 1'b1;
					n_state = IDLE;
				end else begin
					transmitting = 1'b1;
				end
		endcase;
	end
endmodule