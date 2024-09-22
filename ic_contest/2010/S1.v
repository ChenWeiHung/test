module S1(clk,
	  rst,
	  RB1_RW,
	  RB1_A,
	  RB1_D,
	  RB1_Q,
	  sen,
	  sd);

  input clk, rst;
  input [7:0] RB1_Q;  // data path for RB1: output port			//postivite read 
  output RB1_RW;      // control signal for RB1: Read/Write     // 1: read 		, 0: write
  output [4:0] RB1_A; // control signal for RB1: address
  output [7:0] RB1_D; // data path for RB1: input port			//X?
  output sen, sd;
	
	parameter STATE_RESET        = 3'd0,
			  STATE_LOAD_RB1     = 3'd1,
			  STATE_OUTPUT_TO_S2 = 3'd2,
			  STATE_WAIT_CYCLE   = 2'd3;

	reg [1:0] state,next_state;
	reg [4:0] RB1_A;					// count RB1_data for input : 0 ~ 17    (count up or down is not the point)						// reset
	reg [7:0] rb1_data [0:17];			// store RB1_data 8*18([3'd7 - envelope_number] rb1_data [env_data_index])																	    	// initialize
	reg [4:0] env_data_index;			// count for RB1_data[env_data_index][7-0] 18 bit for output  : 17 ~ 0							                // initialize
	reg [2:0] envelope_number;			// store envelope number for output                           : 000 ~ 111 (according RB1_data [7]~[0])			// initialize
	reg [1:0] env_num_index;		    // count for envelope_number[env_num_index] 3 bit for output  : 3 ~ 1     (output env_num_index - 2'd1)			// initialize
	reg sen;					             // 0: valid        , 1: X
	reg sd;
	assign RB1_RW = 1;		// ready only    // 1: read 		, 0: write
	assign RB1_D = 0;     	// ready only
	

// Next State Register
	always@(*)
	begin
		case(state)
			STATE_RESET:
				next_state = STATE_LOAD_RB1;

			STATE_LOAD_RB1:
			begin
				if(RB1_A == 5'd18)
					next_state = STATE_OUTPUT_TO_S2;
				else
					next_state = STATE_LOAD_RB1;
			end

			STATE_OUTPUT_TO_S2:
			begin
				if(env_data_index == 5'd0)
					next_state = STATE_WAIT_CYCLE;
				else
					next_state = STATE_OUTPUT_TO_S2;
			end

			STATE_WAIT_CYCLE:
				next_state = STATE_OUTPUT_TO_S2;

		endcase
	end
// State Register
	always@(posedge clk or posedge rst)
	begin
		if(rst)
			state <= STATE_RESET;
		else
			state <= next_state;
	end
// Datapath
	always@(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			RB1_A <= 5'd0;
			sen <= 1;		// 1: not valid
			/*
			RB1_A <= 5'd0;
			rb1_data[0] <= RB1_Q;
			*/
		end
		else
		begin
			case(state)
				STATE_RESET:
				begin
					RB1_A <= RB1_A + 5'd1;
					/* RB1_A read from RB1 when posedge clk */				//Actually, Reset signal will give the zero_RB1_A data;
				end

				STATE_LOAD_RB1:
				begin
					RB1_A <= RB1_A + 5'd1;
					/* RB1_A read from RB1 when posedge clk */
					rb1_data[RB1_A - 5'd1] <= RB1_Q;
					if(RB1_A == 5'd18)
					begin
						// sen <= 0;
						envelope_number <= 3'b000;
						env_num_index <= 2'd3;
						env_data_index <= 5'd17;
					end
				end

				STATE_OUTPUT_TO_S2:
				begin
					sen <= 0;
					if(env_num_index > 2'd0)
					begin
						sd <= envelope_number[env_num_index - 2'd1]; 
						env_num_index <= env_num_index - 2'd1;
					end
					else
					begin
						sd <= rb1_data [env_data_index][3'd7 - envelope_number];//[][]?
						env_data_index <= env_data_index - 5'd1;
					end
				end

				STATE_WAIT_CYCLE:
				begin
					envelope_number <= envelope_number + 3'b001;
					env_data_index <= 5'd17;
					env_num_index <= 2'd3;
					sen <= 1;
				end

			endcase
		end
	end
  

endmodule
