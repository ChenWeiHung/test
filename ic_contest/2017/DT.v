/* ROM input data's MSB to LSB order is not same as pixel's order */
module DT(
	 input 			clk, 
	 input			reset,
	output	reg     done ,
	output	reg    sti_rd ,
    output 	[9:0]	sti_addr ,// ?output	reg 	[9:0]	sti_addr ,
	 input	[15:0]	sti_di,		// 1 bit * 16 pixel
	output	reg     res_wr ,
	output	reg     res_rd ,
	output 	[13:0]	res_addr ,// ?output	reg 	[13:0]	res_addr ,
	output	reg [7:0]	res_do,	// 8 bit * 1 pixel
	 input   [7:0]	res_di		// 8 bit * 1 pixel
	);

	parameter STATE_FORWARD    = 1'd0,
			  STATE_BACKWARD   = 1'd1;

	reg next_state,state;																	
	reg [7:0] last_128_byte [0:127];						// initialize
	reg [7:0] last_pass_pixel;      						// initialize
	reg [3:0] sti_16_bit_count;						// reset
	reg [2:0] col_8_counter;					    // reset
	reg [6:0] row_128_counter;						// reset

	assign sti_addr = 	({3'd0,row_128_counter}<<3)+{7'd0,col_8_counter};									// 0 ~ 1023   (per 16 bits)	
	assign res_addr = ((({3'd0,row_128_counter}<<3)+{7'd0,col_8_counter})<<4) + {10'd0,sti_16_bit_count};   // 0 ~ 16384  (per byte)
	wire [6:0] store_128_index;										
	assign store_128_index = ( {                     4'd0,col_8_counter }<<4) + { 3'd0,sti_16_bit_count};	// 0 ~ 127
	reg [7:0] window_min;				// combinational logic compute
	reg [7:0] window_compute_result;    // combinational logic compute

// Next State Logic
	always@(*)
	begin
		case(state)
			STATE_FORWARD:
			begin
				if((col_8_counter == 3'd7)&&(sti_16_bit_count == 4'd15)&&(row_128_counter == 7'd127))
					next_state = STATE_BACKWARD;
				else
					next_state = STATE_FORWARD;
			end

			STATE_BACKWARD:
				next_state = STATE_BACKWARD;

		endcase
	end

// State Register
	always@(posedge clk or negedge reset)
	begin
		if(!reset)
			state <= STATE_FORWARD;
		else
			state <= next_state;
	end

// Datapath
	// sequential logic
	always@(posedge clk or negedge reset)
	begin
		if(!reset)
		begin
			sti_16_bit_count <= 4'd0;	//  sti_rom:(16 bits/per addr) & res_rom(1 bit/per addr) also count up but sti_addr compute down
			col_8_counter <= 3'd0;
			row_128_counter <= 7'd0;
			sti_rd <= 1;	// read first 16384 cycles
			res_rd <= 0;	// read second 16384 cycles
			res_wr <= 1;	// write 16384 * 2 cycles ( every cycle )
			done <= 0;
		end
		else
		begin
			sti_rd <= 1;
			res_wr <= 1;
			case(state)
				STATE_FORWARD:
				begin
					last_pass_pixel <= window_compute_result;
																		/*		[ last_row= ]  [ last_row= ] [ last_row= ] 	*/  		 //compute_window
																		/*		[last_pixel<=]  [ sti_di ]                 	*/ 

					last_128_byte[store_128_index - 7'd1] <= last_pass_pixel;// first cycle don't care, last cycle store two byte
																		/* [ 0<=] [ 1<=] [ 2<=] ... [125<=] [126<=] [127<=]	*/ 

					if((row_128_counter == 7'd127)&&(col_8_counter == 3'd7)&&(sti_16_bit_count == 4'd15))
					begin
						res_rd <= 1;
						last_128_byte[store_128_index] <= window_compute_result;
					end
					else
					begin
						sti_16_bit_count <= sti_16_bit_count + 4'd1;
						if(sti_16_bit_count == 4'd15)
						begin
							col_8_counter <= col_8_counter + 3'd1;
							if(col_8_counter == 3'd7)
								row_128_counter <= row_128_counter + 7'd1;
						end
					end
				end

				STATE_BACKWARD:
				begin
					last_pass_pixel <= window_compute_result;
																		/*			           [ res_di  ] [last_pixel<=]   */		 //compute_window
																		/*		[ last_row= ] [ last_row= ] [ last_row= ]   */  
					last_128_byte[store_128_index + 7'd1] <= last_pass_pixel;
																		/* [ 0<=] [ 1<=] [ 2<=] ... [125<=] [126<=] [127<=]	*/

					if((sti_16_bit_count == 4'd0)&&(col_8_counter == 3'd0)&&(row_128_counter == 7'd0))
					begin
						done <= 1;	
						last_128_byte[store_128_index] <= window_compute_result;
					end
					else
					begin
						sti_16_bit_count <= sti_16_bit_count - 4'd1;
						if(sti_16_bit_count == 4'd0)
						begin
							col_8_counter <= col_8_counter - 3'd1;
							if(col_8_counter == 3'd0)
								row_128_counter <= row_128_counter - 7'd1;
						end
					end
				end
				
			endcase
		end
	end
	// combinational logic
	always@(*)
	begin
		case(state)
			STATE_FORWARD:
			begin
				window_min = last_128_byte[store_128_index - 7'd1];

				if(last_128_byte[store_128_index] < window_min)
					window_min = last_128_byte[store_128_index];

				if(last_128_byte[store_128_index + 7'd1] < window_min)
					window_min = last_128_byte[store_128_index + 7'd1];

				if(last_pass_pixel < window_min)
					window_min = last_pass_pixel;

				if(sti_di[4'd15 - sti_16_bit_count] == 1'b0)// filter the background pixel
					window_compute_result = 8'd0;
				else
					window_compute_result = window_min + 8'd1;
				
				res_do = window_compute_result;
			end

			STATE_BACKWARD:
			begin
				window_min = res_di;

				if((last_128_byte[store_128_index + 7'd1] + 8'd1) < window_min)
					window_min = last_128_byte[store_128_index + 7'd1] + 8'd1;

				if((last_128_byte[store_128_index] + 8'd1) < window_min)
					window_min = last_128_byte[store_128_index] + 8'd1;

				if((last_128_byte[store_128_index - 7'd1] + 8'd1) < window_min)
					window_min = last_128_byte[store_128_index - 7'd1] + 8'd1;
				
				if((last_pass_pixel + 8'd1) < window_min)
					window_min = last_pass_pixel + 8'd1;

				if(res_di == 8'd0)// filter the background pixel
					window_compute_result = 8'd0;
				else
					window_compute_result = window_min;
					
				res_do = window_compute_result;
			end

		endcase
	end


endmodule
