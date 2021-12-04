
module SPI_mnrch (
	input   				clk, 
	input   				rst_n,
	input   				wrt,
	input   				MISO,
	input  			[15:0]	wt_data,
	
	output  				SCLK, 
	output  				MOSI,
	output  logic 			SS_n,
	output  logic 			done,
	output  		[15:0]	rd_data
	);
	
	logic MISO_smpl, fall_imminent, rise_imminent, ld_SCLK;
	logic init, shift, set_done, smpl;
	logic [3:0] bit_cntr;
	logic [4:0] SCLK_div;
	logic [15:0] shft_reg;
	
	typedef enum logic [2:0] {IDLE, FRNT_PRCH, MISO_PULL, MOSI_PUSH, BACK_PRCH} state_t;
	state_t state, n_state;
	
	//Bit counter: To count the number of bits which have been sent/recvd
	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			bit_cntr <= 4'b0;
		else if(init) 
			bit_cntr <= 4'b0;
		else if(shift)
			bit_cntr <= bit_cntr + 1'b1;
	end
	
	//Set done15 flag when all 16 bits have been exchanged
	assign done15 = &bit_cntr;	
	
	//SCLK Generator: Generates the SCLK based on 1/32 of clk freq
	always_ff@(posedge clk, negedge rst_n) 
		if(!rst_n)
			SCLK_div <= 5'b10111;
		else if (ld_SCLK)
			SCLK_div <= 5'b10111;
		else
			SCLK_div <= SCLK_div + 1'b1;
	
	//Set the SCLK to be clk/32 freq
	assign SCLK = SCLK_div[4];

	//Set the fall/rise imminent bits to indicate FSM on the next logical state
	assign rise_imminent = (SCLK_div == 5'b01111) ? 1'b1 : 1'b0;
	assign fall_imminent = (SCLK_div == 5'b11111) ? 1'b1 : 1'b0;
	
	//MISO Sampler: Sample the MISO as per the appropriate SCLK rising edge only
	always_ff@(posedge clk)
		if(smpl)
			MISO_smpl <= MISO;
	
	//Transfer Data Container: Generate the shift register to push/pull data 
	//from the SPI lines.
	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			shft_reg <= 16'b0;
		else if(init)
			shft_reg <= wt_data;
		else if(shift)
				shft_reg <= {shft_reg[14:0], MISO_smpl};
	end
	//Set the MSB of shift register as the MOSI output
	assign MOSI = shft_reg[15];
	//Set the Read Data output as the shift register values
	assign rd_data = shft_reg;

	//S-R Registers for the SS_n and done bit
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			done <= 1'b0;	//Reset done bit
			SS_n <= 1'b1;	//Preset the SS_n
		end
		else if(set_done) begin
			done <= 1'b1;
			SS_n <= 1'b1;
		end
		else if (init) begin
			done <= 1'b0;
			SS_n <= 1'b0;
		end
	end

	//FSM State registers
	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			state <= IDLE;
		else	
			state <= n_state;
	end

	//FSM state outputs and transitions
	always_comb begin
		n_state = state;
		set_done = 1'b0;
		init = 1'b0;
		ld_SCLK = 1'b0;
		shift = 1'b0;
		smpl = 1'b0;
				
		case(state)
			FRNT_PRCH:  //Start the SCLK counter and wait for the falling edge to complete the front proch			
				if(fall_imminent) 
					n_state = MISO_PULL;

			MISO_PULL: //Sample the MISO when the SCLK is just about to rise
				if(rise_imminent) begin
					smpl = 1'b1;
					n_state = MOSI_PUSH;
				end
			
			MOSI_PUSH: begin//Shift the new data to MOSI just when the SCLK is about to fall
				if (done15) begin	//If the bit count has reached 15 already jump to assert the back porch
					shift = 1'b1;					
					n_state = BACK_PRCH;
				end
				else if(fall_imminent) begin
					shift = 1'b1;					
					n_state = MISO_PULL;
				end
			end
			BACK_PRCH: begin
			//Keep the SS low until the SCLK is just about to fall
			//But instead of flipping the SCLK, keep it constant high and go back to IDLE
				if(fall_imminent) begin
					ld_SCLK = 1'b1;
					set_done = 1'b1;
					n_state = IDLE;
				end
			end
			////// DEFAULT STATE := IDLE ///////	
			default: begin
				ld_SCLK = 1'b1;
				if(wrt) begin
					init = 1'b1;
					ld_SCLK = 1'b0;
					n_state = FRNT_PRCH;
				end
			end
		endcase
	end
endmodule