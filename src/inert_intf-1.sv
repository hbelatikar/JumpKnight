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

logic [15:0] timer;
logic [15:0] cmd;
logic [15:0] hld_reg;
logic [15:0] inert_data;
logic [15:0] yaw_rt;
logic count, wrt, CYH, CYL, vld, INT_ff1, INT_ff2, asrt_vld;

  
  //////////////////////////////////////////////
  // Declare outputs of SM are of type logic //
  ////////////////////////////////////////////

  
  
  ///////////////////////////////////////
  // Create enumerated type for state //
  /////////////////////////////////////

typedef enum logic [2:0]{start, idle, write1, write2, write3, yawL, yawH} state_intf;

state_intf state, nxt_state;
 
  
  ////////////////////////////////////////////////////////////
  // Instantiate SPI monarch for Inertial Sensor interface //
  //////////////////////////////////////////////////////////
  SPI_mnrch iSPI(.clk(clk),.rst_n(rst_n),.SS_n(SS_n),.SCLK(SCLK),
                 .MISO(MISO),.MOSI(MOSI),.wrt(wrt),.done(done),
				 .rd_data(inert_data),.wrt_data(cmd));
				  
  ////////////////////////////////////////////////////////////////////
  // Instantiate Angle Engine that takes in angular rate readings  //
  // and acceleration info and produces a heading reading         //
  /////////////////////////////////////////////////////////////////
  inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),.vld(vld),
                           .rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),.lftIR(lftIR),
                           .rghtIR(rghtIR),.heading(heading));


//State transition logic
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= start;
	else
		state <= nxt_state;

//Logic for counting 16 bit timer for first command
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		timer <= 0;
	else if(count)
		timer <= timer + 1;

assign timer_done = &timer;	//Check for counting done

//Double flopping INT signal - Metastability
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n) begin
		INT_ff1 <= 0;
		INT_ff2 <= 0;
	end
	else begin
		INT_ff1 <= INT;
		INT_ff2 <= INT_ff1;
	end

//State Machine codeing
always_comb begin
//Defaulting outputs and state
count = 0;
wrt = 0;
CYH = 0;
CYL = 0;
asrt_vld = 0;
nxt_state = state;

case(state)
	start: begin				//Start writing initialization commands as soon as reset deasserted, otherwise, wait for reset deassert
		if(rst_n)begin
			nxt_state = write1;
			count = 1;		//Start the 12 bit counter
			
		end
		else begin
			nxt_state = start;	//Wait for new cycle
			asrt_vld = 1;
			end
	end
	
	write1: begin				//Write 16'h0D02 after 16 bit timer is done counting
		cmd = 16'h0D02;
		if(!timer_done) begin		//Wait for timer done
			count = 1;
			nxt_state = write1;
		end
		else begin			//Timer done, write 0D02 and move to writing next command
			nxt_state = write2;
			wrt = 1;
		end
	end

	write2: begin
		cmd = 16'h1160;
		if(!done) begin			//Wait for done signal from SPI
			nxt_state = write2;
		end
		else begin			//Done sending 1160 move to next write state
			wrt = 1;
			nxt_state = write3;
		end
	end

	write3: begin
		cmd = 16'h1440;
		if(!done) begin			//Wait for done signal from SPI
			nxt_state = write3;	
		end
		else begin			//Done writing 1440, initialization cycle done, move to idle and wait for heading
			wrt = 1;
			nxt_state = idle;
		end
	end

	idle: begin
		if(INT_ff2) begin		//If reading ready with inertial sensor, start reading data
			cmd = 16'hA600;		//Read yaw high byte, write A6
			CYH = 1;
			nxt_state = yawH;
			wrt = 1;
		end
		else				//Wait for INT from inertial sensor
			nxt_state = idle;
	end
	
	yawH: begin
		if(!done) begin			//Reading high byte and wait for done signal
			nxt_state = yawH;
			wrt = 0;
			CYH = 1;
		end
		else begin			//Reading high byte done, start reading low byte
			cmd = 16'hA700;		//Read yaw high byte, write A7
			CYL = 1;
			wrt = 1;
			nxt_state = yawL;
		end

	end
	
	yawL: begin
		if(!done) begin			//Reading low byte wait for done signal
			nxt_state = yawL;
			wrt = 0;
			CYL = 1;
		end
		else begin			//Reading low byte done, go to idle and wait for new readings
			nxt_state = idle;
			asrt_vld = 1;		//Assert data valid
		end

	end
	default: nxt_state = idle;		//Default the state to idle

endcase 
end

//Logic for delaying vld signal (VERY CRITICAL!) by 1 clock so that readings get updated in registers
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		vld <= 0;
	else
		vld <= asrt_vld;

//Hold low byte data when CYH
assign hld_reg[15:8] = CYL ? inert_data[7:0] : hld_reg[15:8];

//Hold high byte data when CYH
assign hld_reg[7:0] = CYH ? inert_data[7:0] : hld_reg[7:0];

//Assign data from hld registed to next stage
assign yaw_rt = hld_reg;
 
endmodule
	  