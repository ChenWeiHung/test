module S2(clk,
	  rst,
	  S2_done,
	  RB2_RW,
	  RB2_A,
	  RB2_D,
	  RB2_Q,
	  sen,
	  sd);

	input clk, rst;
	input [17:0] RB2_Q;			//X
	input sen, sd;
	output S2_done, RB2_RW;
	output [2:0] RB2_A;
	output [17:0] RB2_D;

	parameter STATE_LOAD_ENV = 1'd0,
			  STATE_OUT_RB2  = 1'd1;

	reg next_state,state;
	reg [17:0] RB2_D;							// initialize
	reg [4:0] env_data_bit_count;// 17 ~ 0 				// reset  
	reg [2:0] RB2_A;							// initialize
	reg [1:0] rb2_addr_bit_count;// 3 ~ 1 				// reset
	reg RB2_RW;											// reset
	reg S2_done;										// reset
	
	always@(*)
	begin
		case(state)
			STATE_LOAD_ENV:
			begin
				if(env_data_bit_count == 5'd0)
					next_state = STATE_OUT_RB2;
				else
					next_state = STATE_LOAD_ENV;
			end

			STATE_OUT_RB2:
				next_state = STATE_LOAD_ENV;

		endcase
	end

	always@(posedge clk or posedge rst)
	begin
		if(rst)
			state <= STATE_LOAD_ENV;
		else
			state <= next_state;
	end

	always@(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			RB2_RW <= 1;
			env_data_bit_count <= 5'd17;
			rb2_addr_bit_count <= 2'd3;
			S2_done <= 0;
		end
		else
		begin
			case(state)
				STATE_LOAD_ENV:
				begin
					if(sen == 0)
					begin
						if(rb2_addr_bit_count > 2'd0)
						begin
							RB2_A[rb2_addr_bit_count - 2'd1] <= sd;
							rb2_addr_bit_count <= rb2_addr_bit_count - 2'd1;
						end
						else
						begin
							RB2_D[env_data_bit_count] <= sd;
							env_data_bit_count <= env_data_bit_count - 5'd1;
							if(env_data_bit_count == 5'd0)
								RB2_RW <= 0;
						end
					end
				end

				STATE_OUT_RB2:
				begin
					RB2_RW <= 1;
					env_data_bit_count <= 5'd17;
					rb2_addr_bit_count <= 2'd3;
					if(RB2_A == 3'b111)
						S2_done <= 1;
				end

			endcase
		end
	end

endmodule
