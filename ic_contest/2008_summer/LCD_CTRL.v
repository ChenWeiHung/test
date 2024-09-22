module LCD_CTRL(
	input clk,
	input reset,
	input [7:0] datain, 
	input [2:0] cmd,
	input cmd_valid,
	output reg [7:0] dataout,
	output reg output_valid,
	output reg busy
);

	parameter STATE_WAIT_OR_SHIFT = 2'd0,
		      STATE_LOAD		  = 2'd1,
			  STATE_ZOOM_IN 	  = 2'd2,
			  STATE_ZOOM_FIT 	  = 2'd3;

	reg [1:0] state,next_state;
	reg [7:0] image_buffer [0:107];		// initialize
	reg [6:0] load_out_counter;//0~107	// initialize
	reg [3:0] coor_L;//0~8				// initialize
	reg [2:0] coor_W;//0~5				// initialize
	reg after_zoom_in_mode_check;		// initialize

	wire [6:0] output_origin;//0~69 + ...
	assign output_origin = ({4'd0,coor_W}<<3)+({4'd0,coor_W}<<2) + {3'd0,coor_L};// coor_W*9 + coor_L
	reg [6:0] output_index;
	
// Next State Logic
	always@(*)
	begin
		case(state)
			STATE_WAIT_OR_SHIFT:
			begin
				if(cmd_valid)
				begin
					case(cmd)
						3'd0:	next_state = STATE_LOAD;				// load data and (L,W) <= (6,5) 
						3'd1:	next_state = STATE_ZOOM_IN;				// zoom in output and (L,W) <= (6,5)
						3'd2:	next_state = STATE_ZOOM_FIT;			// zoom fit output
						3'd3,3'd4,3'd5,3'd6:	
						begin
							if(after_zoom_in_mode_check)
								next_state = STATE_ZOOM_IN;		// zoom in output and shift 
							else
								next_state = STATE_ZOOM_FIT;	// zoom fit output( because not in zoom in mode)
						end 
						default:
							next_state = STATE_WAIT_OR_SHIFT;
					endcase
				end
				else
					next_state = STATE_WAIT_OR_SHIFT;
			end

			STATE_LOAD:
			begin
				if(load_out_counter == 7'd107)
					next_state = STATE_ZOOM_FIT;
				else
					next_state = STATE_LOAD;
			end

			STATE_ZOOM_FIT:
			begin
				if(load_out_counter == 7'd15)
					next_state = STATE_WAIT_OR_SHIFT;
				else
					next_state = STATE_ZOOM_FIT;
			end

			STATE_ZOOM_IN:
			begin
				if(load_out_counter == 7'd15)
					next_state = STATE_WAIT_OR_SHIFT;
				else
					next_state = STATE_ZOOM_IN;
			end

		endcase
	end

// State Register 
	always@(posedge clk or posedge reset)
	begin
		if(reset)
			state <= STATE_WAIT_OR_SHIFT;
		else
			state <= next_state;
	end

// Datapath
	// sequential circuit
	always@(posedge clk or posedge reset)
	begin
		if(reset)
		begin	
			busy <= 0;
		end
		else
		begin
			case(state)
				STATE_WAIT_OR_SHIFT:
				begin
					output_valid <= 0;
					busy <= 1;
					load_out_counter <= 7'd0;	
					case(cmd)
						3'd0:// load
						begin
							coor_L <= 3'd6 - 3'd2;	//reset orign
							coor_W <= 3'd5 - 3'd2;
						end

						3'd1:// zoom_in
						begin
							if(after_zoom_in_mode_check == 0)// after zoom_fit mode to zoom_in mode should reset orign 
							begin
								coor_L <= 3'd6 - 3'd2;
								coor_W <= 3'd5 - 3'd2;
								after_zoom_in_mode_check <= 1;
							end
						end

						3'd3:	if((coor_L < 4'd8)&&(after_zoom_in_mode_check)) coor_L <= coor_L + 4'd1; // if it's in the zoom_in mode, just zoom_fit output
						3'd4:	if((coor_L > 4'd0)&&(after_zoom_in_mode_check)) coor_L <= coor_L - 4'd1;
						3'd5:	if((coor_W > 3'd0)&&(after_zoom_in_mode_check)) coor_W <= coor_W - 3'd1;
						3'd6:	if((coor_W < 3'd5)&&(after_zoom_in_mode_check)) coor_W <= coor_W + 3'd1;
			
					endcase
				end

				STATE_LOAD:
				begin
					if(load_out_counter == 7'd107)
						load_out_counter <= 7'd0;
					else
						load_out_counter <= load_out_counter + 7'd1;
						
					image_buffer[load_out_counter] <= datain;
				end

				STATE_ZOOM_IN,STATE_ZOOM_FIT:
				begin
					load_out_counter <= load_out_counter + 7'd1;

					if(load_out_counter == 7'd15)
						busy <= 0;
					output_valid <= 1;
					dataout <= image_buffer[output_index];
					
					if(state[0] == 1)	after_zoom_in_mode_check <= 0;
				end

			endcase
		end
	end
	// combinational circuit
	always@(*)
	begin
		case(state[0])
			0://STATE_ZOOM_IN
			begin
				case(load_out_counter)
					0:	output_index = output_origin + 7'd0;
					1:	output_index = output_origin + 7'd1;
					2:	output_index = output_origin + 7'd2;
					3:	output_index = output_origin + 7'd3;
					4:	output_index = output_origin + 7'd12;
					5:	output_index = output_origin + 7'd13;
					6:	output_index = output_origin + 7'd14;
					7:	output_index = output_origin + 7'd15;
					8:	output_index = output_origin + 7'd24;
					9:	output_index = output_origin + 7'd25;
					10:	output_index = output_origin + 7'd26;
					11:	output_index = output_origin + 7'd27;
					12:	output_index = output_origin + 7'd36;
					13:	output_index = output_origin + 7'd37;
					14:	output_index = output_origin + 7'd38;
					15:	output_index = output_origin + 7'd39;
					default:
						output_index = 0;
				endcase
			end

			1://STATE_ZOOM_FIT
			begin
				case(load_out_counter)
					0:	output_index = 7'd13;
					1:	output_index = 7'd16;
					2:	output_index = 7'd19;
					3:	output_index = 7'd22;
					4:	output_index = 7'd37;
					5:	output_index = 7'd40;
					6:	output_index = 7'd43;
					7:	output_index = 7'd46;
					8:	output_index = 7'd61;
					9:	output_index = 7'd64;
					10:	output_index = 7'd67;
					11:	output_index = 7'd70;
					12:	output_index = 7'd85;
					13:	output_index = 7'd88;
					14:	output_index = 7'd91;
					15:	output_index = 7'd94;		
					default:
						output_index = 0;
				endcase
			end
			
		endcase
	end
endmodule