module LCD_CTRL(clk, reset, IROM_Q, cmd, cmd_valid, IROM_EN, IROM_A, IRB_RW, IRB_D, IRB_A, busy, done);
	input clk;
	input reset;
	input [7:0] IROM_Q;
	input [2:0] cmd;	// main control
	input cmd_valid;	//
	output IROM_EN;
	output [5:0] IROM_A;

	output IRB_RW;
	output [7:0] IRB_D;
	output [5:0] IRB_A;
	output busy;       // main control switch
	output done;

	parameter STATE_READY_LOAD = 8,
			  STATE_LOAD  		= 9,
			  STATE_UP    		= 1,
			  STATE_DOWN  		= 2,
			  STATE_LEFT  		= 3,
			  STATE_RIGHT 		= 4,
			  STATE_AVG   		= 5,
			  STATE_M_X   		= 6,
			  STATE_M_Y   		= 7,
			  STATE_READY_WRITE= 0,
			  STATE_WRITE 		= 10,
			  STATE_D = 11;
	
	reg [3:0] state,next_state;
	reg [7:0] image_data [0:63];
	reg [2:0] compute_coor_X,compute_coor_Y;
	wire [5:0] compute_point;
	assign compute_point = ({3'b000,compute_coor_Y}<<3) + {3'b000,compute_coor_X};
	wire [7:0] average_data;
	assign average_data = ((image_data[compute_point - 6'd0] + image_data[compute_point - 6'd1] + image_data[compute_point - 6'd8] + image_data[compute_point - 6'd9])>>2);
	
	reg IROM_EN;
	reg [5:0] IROM_A;		// just like load_counter
	reg IRB_RW;
	reg [7:0] IRB_D;
	reg [5:0] IRB_A;		// just like out_counter
	reg busy;       // main control switch
	reg done;

// Next State Logic
	always@(*)
	begin
		case(state)
			STATE_READY_LOAD:
				next_state = STATE_LOAD;
			STATE_LOAD:
			begin
				if(IROM_A == 6'd0)
					next_state = STATE_D;
				else
					next_state = STATE_LOAD;
			end

			STATE_UP,STATE_DOWN,STATE_LEFT,STATE_RIGHT,STATE_AVG,STATE_M_X,STATE_M_Y,STATE_D:
			begin
				if(cmd_valid)
					next_state = cmd;
				else
					next_state = STATE_D;
			end
			
			STATE_READY_WRITE:
				next_state = STATE_WRITE;
			STATE_WRITE:
			begin
				if(IRB_A == 6'd63)
					next_state = STATE_D;
				else
					next_state = STATE_WRITE;
			end

			default:
				next_state = STATE_D;

		endcase
	end

// State Register 
	always@(posedge clk)
	begin
		if(reset)
			state <= STATE_READY_LOAD;
		else
			state <= next_state;
	end

// Datapath
	always@(posedge clk)
	begin
		if(reset)
		begin
			IROM_A <= 6'd0;
			// IRB_A <= 6'd0;
			compute_coor_X <= 3'd4;
			compute_coor_Y <= 3'd4;

			IROM_EN <= 0;
			IRB_RW <= 1;
			busy <= 1;
			done <= 0;
		end
		else
		begin
			case(state)		
				STATE_READY_LOAD:
					IROM_A <= IROM_A + 6'd1;		//let testbench eat the IROM address 0

				STATE_LOAD:
				begin//同一個IROM_A會用到兩個cycle
					image_data[IROM_A - 6'd1] <= IROM_Q;	// 將上一個cycle輸出位址的值儲存
													// let testbench eat the IROM_A，其對應的值再下一個cycle出現
					IROM_A <= IROM_A + 6'd1;

					if(IROM_A == 6'd0)
					begin
						busy <= 0;
						IROM_EN <= 1;
					end					
				end

				STATE_UP:
				begin
					if(compute_coor_Y == 3'd0)
						compute_coor_Y <= 3'd0;
					else
						compute_coor_Y <= compute_coor_Y - 3'd1;
				end
				STATE_DOWN:
				begin
					if(compute_coor_Y == 3'd7)
						compute_coor_Y <= 3'd7;
					else
						compute_coor_Y <= compute_coor_Y + 3'd1;
				end
				STATE_LEFT:
				begin
					if(compute_coor_X == 0)
						compute_coor_X <= 3'd0;
					else
						compute_coor_X <= compute_coor_X - 3'd1;
				end
				STATE_RIGHT:
				begin
					if(compute_coor_X == 7)
						compute_coor_X <= 3'd7;
					else
						compute_coor_X <= compute_coor_X + 3'd1;
				end

				STATE_M_X:
				begin
					image_data[compute_point - 6'd0] <= image_data[compute_point - 6'd8];
					image_data[compute_point - 6'd1] <= image_data[compute_point - 6'd9];
					image_data[compute_point - 6'd8] <= image_data[compute_point - 6'd0];
					image_data[compute_point - 6'd9] <= image_data[compute_point - 6'd1];
				end
				STATE_M_Y:
				begin
					image_data[compute_point - 6'd0] <= image_data[compute_point - 6'd1];
					image_data[compute_point - 6'd1] <= image_data[compute_point - 6'd0];
					image_data[compute_point - 6'd8] <= image_data[compute_point - 6'd9];
					image_data[compute_point - 6'd9] <= image_data[compute_point - 6'd8];
				end
				STATE_AVG:
				begin
					image_data[compute_point - 6'd0] <= average_data;
					image_data[compute_point - 6'd1] <= average_data;
					image_data[compute_point - 6'd8] <= average_data;
					image_data[compute_point - 6'd9] <= average_data;
				end

				STATE_READY_WRITE:
				begin
					IRB_RW <= 0;		// one more cycle
					IRB_D <= image_data[0];
					IRB_A <= 6'd0;
				end

				STATE_WRITE:
				begin
					IRB_D <= image_data[IRB_A + 6'd1];		//做x+1的同時輸出x+1的值，就會同步
					IRB_A <= IRB_A + 6'd1;					//because IRB_A also need to be read

					if(IRB_A == 6'd63)
					begin
						busy <= 0;
						done <= 1;
					end
				end
			endcase
		end
		
	end

endmodule


