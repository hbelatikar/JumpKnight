`default_nettype none
module charge #(
    parameter  FAST_SIM = 1) 
    ( clk, rst_n, go, piezo, piezo_n);
    input logic clk;
    input logic rst_n;
    input logic go;

    output logic piezo;
    output logic piezo_n;
    
    
    //Note_freq:- G6 = 1568, C7 = 2093, E7 = 2637, G7 = 3136
	//Duty cycle is 50Mhz/Freq
    localparam G6 = 31888, C7 = 23900, E7 = 18961, G7 = 15944;	//Note counter is 50Mhz/Freq 
	localparam G6_half = 15944, C7_half = 11950, E7_half = 9480, G7_half = 7972; //Half of the above counter
	localparam  clk_2_22 = 32'h40_0000,		//Number of clock cycles to wait when 2^22
                clk_2_23 = 32'h80_0000,		//Number of clock cycles to wait when 2^23
				clk_2_22_23 = 32'hC0_0000,	//Number of clock cycles to wait when 2^22 + 2^23
                clk_2_24 = 32'h100_0000;	//Number of clock cycles to wait when 2^24

	//State declarations
	typedef enum logic [2:0] {IDLE, G6_note, C7_note, E7_note_1, G7_note_1, E7_note_2, G7_note_2} t_state;
	t_state state, n_state;
	
	//Logic declarations
    logic clk_cntr_clr, freq_cntr_clr;
    logic [31:0] freq_cnt, clk_cntr, duty;
    
	//LVDS pair for speaker
    assign piezo_n = ~piezo;

	//Counter logic for durations of note
    generate
        if (FAST_SIM) begin
            always_ff @(posedge clk, negedge rst_n) begin
                if(!rst_n)
                    clk_cntr <= 0;
                else if(clk_cntr_clr)
                    clk_cntr <= 0;
                else
                    clk_cntr <= clk_cntr + 16'h000F;	//Increase counter by 16 for simulations
            end
        end else begin
            always_ff @(posedge clk, negedge rst_n) begin
                if(!rst_n)
                    clk_cntr <= 0;
                else if(clk_cntr_clr)					//Reset counter when clk_cntr_clr is high
                    clk_cntr <= 0;
                else
                    clk_cntr <= clk_cntr + 16'h0001;	//Increase counter by 1 for implementation
            end
        end
    endgenerate

	//Counter logic for frequency note durations
    generate
        if (FAST_SIM) 
            always_ff @(posedge clk, negedge rst_n)	
				if(!rst_n) 
					freq_cnt <= 16'h0000;			
				else if(freq_cntr_clr)	
					freq_cnt <= 16'h0000;			//Clear frequency counter if freq_cntr_clr is high
				else
					freq_cnt <= freq_cnt + 16'h000F;//Increase counter by 16 for simulations
        else 
			always_ff @(posedge clk, negedge rst_n)
				if(!rst_n) 
					freq_cnt <= 16'h0000;
				else if(freq_cntr_clr)
					freq_cnt <= 16'h0000;
				else
					freq_cnt <= freq_cnt + 16'h0001;//Increase counter by 1 for implementation
    endgenerate
	
	//Piezo logic driver
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) 					//Async Low Reset
			piezo <= 1'b0;
		else begin		
			if (freq_cnt < duty)	//Output high until count less than duty
				piezo <= 1'b1;
			else					//Output low when count exceeds duty
				piezo <= 1'b0;
		end
	end

	//State registers
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			state <= IDLE;
		else	
			state <= n_state;
	
	//State Transition and output logic
	always_comb begin
		
		//Default outputs
		n_state = state;
		clk_cntr_clr = 1'b0;
		freq_cntr_clr = 1'b0;
		duty = 0;
		
		case(state) 
			
			/////* DEFAULT: IDLE Case */////
			default: begin
				clk_cntr_clr = 1'b1;	//Do not increment count when in IDLE state
				freq_cntr_clr = 1'b1;
				if(go) begin
					n_state = G6_note;	//When go is detected, start the G6 note
				end
			end
			
			G6_note: begin
				duty = G6_half;
				if (clk_cntr >= clk_2_23) begin
					n_state = C7_note;		
					clk_cntr_clr = 1'b1;	//Clear the clk counter since we are now moving to nxt note
					freq_cntr_clr = 1'b1;	//Clear the freq counter also
				end	
				else if (freq_cnt >= G6) 
					freq_cntr_clr = 1'b1;	//Only clear freq counter since we still need to wait the clk cycles
				
			end
			
			//All the next states have same logic and duty cycle and clk counter values change as per the note
			C7_note: begin
				duty = C7_half;
				if (clk_cntr >= clk_2_23) begin
					n_state = E7_note_1;
					clk_cntr_clr = 1'b1;
					freq_cntr_clr = 1'b1;
				end	
				else if (freq_cnt >= C7)
					freq_cntr_clr = 1'b1;
			end
			
			E7_note_1: begin
				duty = E7_half;
				if (clk_cntr >= clk_2_23) begin
					n_state = G7_note_1;
					clk_cntr_clr = 1'b1;
					freq_cntr_clr = 1'b1;
				end	
				else if (freq_cnt >= E7)
					freq_cntr_clr = 1'b1;
			end
			
			G7_note_1: begin
				duty = G7_half;
				if (clk_cntr >= clk_2_22_23) begin
					n_state = E7_note_2;
					clk_cntr_clr = 1'b1;
					freq_cntr_clr = 1'b1;
				end	
				else if (freq_cnt >= G7)
					freq_cntr_clr = 1'b1;
			end
			
			E7_note_2: begin
				duty = E7_half;
				if (clk_cntr >= clk_2_22) begin
					n_state = G7_note_2;
					clk_cntr_clr = 1'b1;
					freq_cntr_clr = 1'b1;
				end	
				else if (freq_cnt >= E7)
					freq_cntr_clr = 1'b1;
			end
			
			G7_note_2: begin
				duty = G7_half;
				if (clk_cntr >= clk_2_22_23) begin
					n_state = IDLE;				//After the final note has been played go back to IDLE state.
					clk_cntr_clr = 1'b1;
					freq_cntr_clr = 1'b1;
				end	
				else if (freq_cnt >= G7)
					freq_cntr_clr = 1'b1;
			end
		endcase
	end	
endmodule
