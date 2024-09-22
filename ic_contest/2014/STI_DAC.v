module STI_DAC(clk ,reset, load, pi_data, pi_length, pi_fill, pi_msb, pi_low, pi_end,
	       so_data, so_valid,
	       pixel_finish, pixel_dataout, pixel_addr,
	       pixel_wr);

	input		clk, reset;
	input		load, pi_msb, pi_low, pi_end; 
	input	[15:0]	pi_data;
	input	[1:0]	pi_length;
	input		pi_fill;
	output		so_data, so_valid;

	output  pixel_finish, pixel_wr;
	output [7:0] pixel_addr;
	output [7:0] pixel_dataout;



	parameter STATE_READY_LOAD   = 1'b0,
			  STATE_SO_PIXEL_OUT = 1'b1;

	reg state,next_state;
	reg so_valid;
	reg so_data;
	reg [4:0] so_output_counter;
	reg [2:0] pixel_output_counter;
	reg ready_pixel; 
	reg [7:0] pixel_addr;
	reg [7:0] pixel_dataout;
	reg pixel_finish;
	
	reg [31:0] pi_store;
	reg [4:0] msb_bit;
	wire [4:0] out_index;
	assign out_index = (pi_msb)?(msb_bit - so_output_counter):(so_output_counter);
	reg pixel_wr;

// Next State Logic : 
	always@(*)	 
	begin
		case(state)
			STATE_READY_LOAD:
			begin
				if(pi_end)
					next_state = STATE_READY_LOAD;
				else
				begin
					if(load)
						next_state = STATE_SO_PIXEL_OUT;
					else
						next_state = STATE_READY_LOAD;
				end
			end

			STATE_SO_PIXEL_OUT:
			begin
				if((so_output_counter == msb_bit)&&(ready_pixel == 1))
					next_state = STATE_READY_LOAD;
				else
					next_state = STATE_SO_PIXEL_OUT;
			end

		endcase
	end

// State Register 
	always@(posedge clk or posedge reset)
	begin
		if(reset)
			state <= STATE_READY_LOAD;
		else
			state <= next_state;
	end

// Datapath
	always@(posedge clk or posedge reset)
	begin
		if(reset)
		begin
			so_valid <= 0;
			so_output_counter <= 5'd0;
			pixel_output_counter <= 3'd7;
			ready_pixel <= 0 ; 
			pixel_addr <= 8'd0;
			pixel_finish <= 0;
		end
		else
		begin
			case(state)
				STATE_READY_LOAD:// wait load fro one cycle
				begin
					pixel_output_counter <= 3'd7;

					if(pi_end)
					begin
						pixel_addr <= pixel_addr + 8'd1;
						pixel_dataout <= 8'd0;
						if(pixel_addr == 255)
							pixel_finish <= 1;
					end
				end

				STATE_SO_PIXEL_OUT:
				begin
					
					if((so_output_counter == msb_bit)&&(ready_pixel == 1))
					begin
						so_valid <= 0;
						so_output_counter <= 0;
					end
					else 
					begin
						so_valid <= 1;
						so_data <= pi_store[out_index];
						if(so_output_counter < msb_bit)
							so_output_counter <= so_output_counter + 5'd1;// it is current index +1
					end

					if((so_output_counter == msb_bit)&&(ready_pixel == 1))
						pixel_dataout <= 8'd0;
					else
						pixel_dataout[pixel_output_counter] <= pi_store[out_index];

					if(pixel_output_counter == 3'd0)
					begin
						ready_pixel <= 1;
						pixel_output_counter <= 3'd7;
					end
					else
					begin
						ready_pixel <= 0;
						pixel_output_counter <= pixel_output_counter - 3'd1;
					end

					if(ready_pixel)
						pixel_addr <= pixel_addr + 8'd1;
				end

			endcase
		end
	end

	// combinational circuit
	always@(*)
	begin
		pi_store = 32'd0;
		case(pi_length)
			2'b00:
			begin
				if(pi_low)
					pi_store[7:0] = pi_data[15:8];
				else
					pi_store[7:0] = pi_data[7:0];
				msb_bit = 5'd7;
			end

			2'b01:
			begin
				pi_store[15:0] = pi_data;
				msb_bit = 5'd15;
			end

			2'b10:
			begin
				if(pi_fill)
					pi_store[23:8] = pi_data;
				else
					pi_store[15:0] = pi_data;
				msb_bit = 5'd23;
			end

			2'b11:
			begin
				if(pi_fill)
					pi_store[31:16] = pi_data;
				else
					pi_store[15:0] = pi_data;
				msb_bit = 5'd31;
			end
			
		endcase
	end
	always@(*)
	begin
		case(state)
			STATE_READY_LOAD:
			begin
				if(pi_end)
					pixel_wr = clk;
				else
					pixel_wr = 1'b1;
			end

			STATE_SO_PIXEL_OUT:
			begin
				if(ready_pixel)
					pixel_wr = clk;
				else
					pixel_wr = 1'b1;
			end

		endcase
	end
endmodule
