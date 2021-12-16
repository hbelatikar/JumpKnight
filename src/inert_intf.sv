//////////////////////////////////////////////////////
// Interfaces with ST 6-axis inertial sensor.  In  //
// this application we only use Z-axis gyro for   //
// heading of robot.  Fusion correction comes    //
// from "gaurdrail" signals lftIR/rghtIR.       //
/////////////////////////////////////////////////
module inert_intf(clk,rst_n,strt_cal,cal_done,heading,rdy,lftIR,
                  rghtIR,SS_n,SCLK,MOSI,MISO,INT,moving);

  parameter FAST_SIM = 1;	// used to speed up simulation
  
  input clk, rst_n;
  input MISO;					// SPI input from inertial sensor
  input INT;					// goes high when measurement ready
  input strt_cal;				// initiate claibration of yaw readings
  input moving;					// Only integrate yaw when going
  input lftIR,rghtIR;			// gaurdrail sensors
  
  output cal_done;				// pulses high for 1 clock when calibration done
  output signed [11:0] heading;	// heading of robot.  000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW
  output rdy;					// goes high for 1 clock when new outputs ready (from inertial_integrator)
  output SS_n,SCLK,MOSI;		// SPI outputs
 

  ////////////////////////////////////////////
  // Declare any needed internal registers //
  //////////////////////////////////////////
	logic [15:0]	start_up_timer,
					yaw_rt;
	logic [7:0] 	YawH, YawL;
	logic [15:0] 	inert_data;
  
  //////////////////////////////////////////////
  // Declare outputs of SM are of type logic //
  ////////////////////////////////////////////
	logic [15:0] cmd;
	logic wrt, done, vld;
	logic C_Y_H, C_Y_L, INT_temp, INT_FF;
	
  ///////////////////////////////////////
  // Create enumerated type for state //
  /////////////////////////////////////
	typedef enum logic [2:0] {INIT1, INIT2, INIT3, GET_YL, GET_YH, ASRT_VLD, WAIT_INT} t_state;
	t_state state, n_state;
  
  ////////////////////////////////////////////////////////////
  // Instantiate SPI monarch for Inertial Sensor interface //
  //////////////////////////////////////////////////////////
	SPI_mnrch iSPI(.clk(clk),.rst_n(rst_n),.SS_n(SS_n),.SCLK(SCLK),
				 .MISO(MISO),.MOSI(MOSI),.wrt(wrt),.done(done),
				 .rd_data(inert_data),.wt_data(cmd));
	
  ////////////////////////////////////////////////////////////////////
  // Instantiate Angle Engine that takes in angular rate readings  //
  // and acceleration info and produces a heading reading         //
  /////////////////////////////////////////////////////////////////
	inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),.vld(vld),
						   .rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),.lftIR(lftIR),
						   .rghtIR(rghtIR),.heading(heading));


	//Double flopping the INT pin for sync use
	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			INT_temp <= 1'b0;
			INT_FF	<= 1'b0;
		end else begin
			INT_temp <= INT;
			INT_FF	<= INT_temp;
		end
	end
  
	//Timer for SPI start-up time exhaustion
	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n) 
			start_up_timer = 16'h0000;
		else	
			start_up_timer = start_up_timer + 1;
	end
  
	//Holding registers for Yaw High
  	always_ff@(posedge clk, negedge rst_n) 
		if(!rst_n)
			YawH <= 8'b0;
		else if(C_Y_H) 
			YawH <= inert_data;
			
	//Holding registers for Yaw Low 		
	always_ff@(posedge clk, negedge rst_n) 
		if(!rst_n)
			YawL <= 8'b0;
		else if(C_Y_L) 
			YawL <= inert_data;
	
	//Concatenating the YawH & YawL to form Yaw
	assign yaw_rt = {YawH, YawL};
	
  ////////////////////////////////
  // State Machine Description //
  //////////////////////////////
	
	//Declare next state transistions
	always_ff@(posedge clk, negedge rst_n)
		if(!rst_n)
			state <= INIT1;
		else	
			state <= n_state;
	
	//Describing the state transistions and outputs
	always_comb begin
		n_state = state;
		vld = 1'b0;
		C_Y_H = 1'b0;
		C_Y_L = 1'b0;
		wrt = 1'b0;
		cmd = 16'h0;
		
		case(state)
			INIT1: begin
				cmd = 16'h0D02;
				if (&start_up_timer) begin	//Wait for the start up timer to be full
					wrt = 1'b1;
					n_state = INIT2;
				end
			end
			
			INIT2: begin
				cmd = 16'h1160;
				if(done) begin	//If SPI is done sending the data
					wrt = 1'b1;
					n_state = INIT3;
				end				
			end
			
			INIT3: begin
				cmd = 16'h1440;
				if(done) begin	//If SPI is done sending the data
					wrt = 1'b1;
					n_state = WAIT_INT;
				end			
			end
			
			WAIT_INT: begin
				cmd = 16'hA600;	//Set the command to read Yaw Low when INT goes high
				if (INT_FF) begin
					n_state = GET_YL;
					wrt = 1'b1;
				end
			end
			
			GET_YL: begin
				cmd = 16'hA700;	//Set the cmd to read Yaw High now
				if(done) begin
					C_Y_L = 1'b1;	//Store the value when recving is done
					wrt = 1'b1;
					n_state = GET_YH;
				end
			end
			
			GET_YH: begin	//Get the associated Yaw High value when after reading Yaw low
				if (done) begin
					C_Y_H = 1'b1;	//Store the value
					n_state = ASRT_VLD;
				end	
			end
			
			ASRT_VLD: begin	//Assert the valid signal when all the data is ready
				vld = 1'b1;
				n_state = WAIT_INT;
			end
		endcase
	end
endmodule