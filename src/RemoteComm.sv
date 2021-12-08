
module RemoteComm (
	input clk,rst_n,
	input snd_cmd,			//Starts the command sending process
	input [15:0] cmd,		//Input command to send
	input RX,
	output TX, resp_rdy,	
	output [7:0] resp,
	output logic cmd_snt	//Asserts high if the command was sent properly
	);
	
	//Declaring internal logics
	logic sel_high, tx_done, set_cmd_snt, trmt;
	logic [7:0] tx_data, cmd_low;
	
	//State enumerators
	typedef enum logic [1:0] {IDLE, MSB, LSB} state_t;
	state_t state, n_state;
	
	//Instantiating the UART tranceiver
	UART iU_RCOM (.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), 
			 	 .rx_rdy(resp_rdy), .clr_rx_rdy(clr_rx_rdy),
			 	 .rx_data(resp), .trmt(trmt), .tx_data(tx_data),
			 	 .tx_done(tx_done));

	//Latching the lower bits of cmd only when the snd_cmd signal is high
	always_ff@(posedge clk)
		if(snd_cmd) cmd_low <= cmd[7:0];
	
	//Assigning the input of the UART_wrapper to a 8 bit command
	//depending on LSB's/MSB's selector 'sel_high' from FSM
	assign tx_data = sel_high ? cmd[15:8] : cmd_low;
	
	//RS Flip flop for cmd_snt flag
	always_ff @ (posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			cmd_snt <= 1'b0;
		else if (snd_cmd)
			cmd_snt <= 1'b0;
		else if (set_cmd_snt)
			cmd_snt <= 1'b1;
	end
	
	//Logic to clear resp_rdy
	assign clr_rx_rdy = resp_rdy & (resp == 8'hA5);

	//FSM State change registers
	always_ff@(posedge clk, negedge rst_n)
		if(!rst_n)
			state <= IDLE;
		else
			state <= n_state;

	//Combinational FSM for state outputs and transitions
	always_comb 
	begin
		//Setting default outputs
		n_state = state;
		sel_high = 1'b1;
		trmt = 1'b0;
		set_cmd_snt = 1'b0;

		case(state)
			//MSB state where the MSB is transmitted
			MSB:
				if(tx_done) begin	//if transmission is done
					sel_high = 1'b0;//Select the low bits now
					trmt = 1'b1;	//Tell the UART to send the low bits	
					n_state = LSB;	
				end
				
			LSB: begin
				sel_high = 1'b0;
				if(tx_done) begin	//If transmission is done for low bits
					set_cmd_snt = 1'b1;	//Set the cmd_snt flag as high
					n_state = IDLE;	//Go back to IDLE
				end
			end
			////// DEFAULT STATE = IDLE ////////
			default: 
				if(snd_cmd) begin	//Wait for the snd_cmd to begin transmission
					trmt = 1'b1;
					n_state = MSB;
				end
		endcase
	end
endmodule