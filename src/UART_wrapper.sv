
module UART_wrapper (
	input clk,rst_n,		// clock and active low reset
	input RX,				// Input recieving data
	input trmt,
	
	input clr_cmd_rdy,		// Clears the cmd_rdy flag
	input [7:0] resp,		// byte to transmit

	output [15:0] cmd,
	output logic cmd_rdy,
	output TX,
	output tx_done			// tx_done asserted when tranmission complete
);

	logic clr_rx_rdy, rx_rdy;	// rx_rdy can be cleared by this or new start bit
	logic cmd_high_en;
	logic set_cmd_rdy;
	logic [7:0] rx_data;
	logic [7:0] cmd_data_high;
	
	//Instantitate the UART
	UART iU_UWRP	(.clk(clk),.rst_n(rst_n),.RX(RX),.TX(TX),
				 .rx_rdy(rx_rdy),.clr_rx_rdy(clr_rx_rdy),
				 .rx_data(rx_data),.trmt(trmt),.tx_data(resp),
				 .tx_done(tx_done));

	//State enumerators
	typedef enum logic {MSB, LSB} t_state;
	t_state state, n_state;
	
	//Concatenate the low and high bits received and set as the cmd
	assign cmd = {cmd_data_high,rx_data};
	
	//Clear the high cmd register if reset or else take in the new data
	always_ff @ (posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			cmd_data_high <= 8'b0;
		else if (cmd_high_en)
			cmd_data_high <= rx_data;
	end
	
	//RS flip flop for the cmd_rdy flag
	always_ff @ (posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			cmd_rdy <= 1'b0;
		else if (clr_cmd_rdy | rx_rdy)
			cmd_rdy <= 1'b0;
		else if (set_cmd_rdy)
			cmd_rdy <= 1'b1;
	end
	
	//State registers w.r.t clk
	always_ff @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			state <= MSB;
		else
			state <= n_state;
	end
	
	//Combinational logic to provide output and state transitions
	always_comb begin
		//Set Defaults
		set_cmd_rdy = 1'b0;
		clr_rx_rdy = 1'b0;
		cmd_high_en = 1'b0;
		n_state = state;
		
		case(state)
			MSB: 
				if(rx_rdy) begin		//If MSB receiving is done:
					n_state = LSB;		///Go to LSB in next clock cycle
					cmd_high_en = 1'b1;	///Set the cmd high enable
					clr_rx_rdy = 1'b1;	///Clear the rdy flag of UART
				end
			
			LSB:
				if (rx_rdy) begin		//If LSB receiving is done:
					n_state = MSB;		///Go back to MSB
					set_cmd_rdy = 1'b1;	///Inficate that command is ready
					clr_rx_rdy = 1'b1;	///Clear the ready sig of UART again
				end
		endcase
	end
endmodule
	