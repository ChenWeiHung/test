// gray_ready??
`timescale 1ns/10ps
module LBP ( clk, reset, gray_addr, gray_req, gray_ready, gray_data, lbp_addr, lbp_valid, lbp_data, finish);
    input   	clk;
    input   	reset;
    output  [13:0] 	gray_addr;
    output         	gray_req;
    input   	gray_ready;
    input   [7:0] 	gray_data;
    output  [13:0] 	lbp_addr;
    output  	lbp_valid;
    output  [7:0] 	lbp_data;
    output  	finish;

    parameter STATE_INITIAL_ROW = 2'd0,
              STATE_INITIAL_COL = 2'd1,
              STATE_LOAD      = 2'd2,
              STATE_OUTPUT    = 2'd3;

    reg [1:0] next_state,state;
    reg [7:0] encode_compute_buffer [0:7];                          // initialize
    reg [7:0] last_row_buffer [0:5];                                // initialize
    reg [2:0] load_counter;//0~5,0~1                // reset
    reg [6:0] row_counter;//1~126                   // reset
    reg [6:0] col_counter;//1~126                   // reset
    
    wire [13:0] buffer_center;
    assign buffer_center = ({7'd0,row_counter}<<7) + {7'd0,col_counter};
     reg [13:0] gray_addr;
     reg [7:0] lbp_compute;

    reg gray_req;                                   // reset
    reg lbp_valid;                                  // reset
    reg [13:0] lbp_addr;                                            // initialize
    reg [7:0] lbp_data;                                             // initialize
    reg finish;                                     // reset 

// Next State Logic
    always@(*)
    begin
        case(state)
            STATE_INITIAL_ROW:
            begin
                if(load_counter == 3'd5)    next_state = STATE_INITIAL_COL;
                else    next_state = STATE_INITIAL_ROW;
            end

            STATE_INITIAL_COL:
            begin
                if(load_counter == 3'd1)    next_state = STATE_OUTPUT;
                else    next_state = STATE_INITIAL_COL;
            end

            STATE_LOAD:
            begin
                if(load_counter == 3'd1)    next_state = STATE_OUTPUT;
                else    next_state = STATE_LOAD;
            end

            STATE_OUTPUT:
            begin
                if(col_counter == 7'd126)    next_state = STATE_INITIAL_COL;
                else/*col_counter == 1~125*/    next_state = STATE_LOAD;
            end

        endcase
    end

// State Register
    always@(posedge clk or posedge reset)
    begin
        if(reset)
            state <= STATE_INITIAL_ROW;
        else
            state <= next_state;
    end

// Datapath
    // sequential circuit
    always@(posedge clk or posedge reset)
    begin
        if(reset)
        begin
            row_counter <= 7'd1;
            col_counter <= 7'd1;
            load_counter <= 3'd0;

            gray_req <= 1;
            lbp_valid <= 0;
            finish <= 0;
        end
        else
        begin
            case(state)
                STATE_INITIAL_ROW:
                begin
                    // 6 cycles
                    if(load_counter == 3'd5)
                        load_counter <= 3'd0;
                    else
                        load_counter <= load_counter + 3'd1;

                    // fill 6 last_row_buffer data 
                    last_row_buffer[load_counter] <= gray_data;

                    lbp_valid <= 1'b0;
                end

                STATE_INITIAL_COL:
                begin
                    // 2 cycles
                    load_counter <= load_counter + 3'd1;

                    // take last_row_buffer data ,load the last two data(row) [6] [7]
                    encode_compute_buffer[0] <= last_row_buffer[0];
                    encode_compute_buffer[1] <= last_row_buffer[1];
                    encode_compute_buffer[2] <= last_row_buffer[2];
                    encode_compute_buffer[3] <= last_row_buffer[3];
                    encode_compute_buffer[4] <= last_row_buffer[4];
                    encode_compute_buffer[5] <= last_row_buffer[5];
                    encode_compute_buffer[load_counter + 3'd6] <= gray_data;//[6] [7]

                    lbp_valid <= 1'b0;
                    if((col_counter == 7'd1)&&(row_counter == 7'd127))
                        finish <= 1;
                end

                STATE_LOAD:
                begin
                    // 2 cycles
                    load_counter <= load_counter + 3'd1;

                    // load the last two data(column) [2] [5]
                    encode_compute_buffer[3'd2 + (load_counter<<1)+load_counter] <= gray_data;//[2] [5]

                    lbp_valid <= 1'b0;
                end

                STATE_OUTPUT:
                begin
                    // reset load_counter, count column & row
                    load_counter <= 3'd0;
                    if(col_counter == 7'd126)
                    begin
                        row_counter <= row_counter + 7'd1;
                        col_counter <= 7'd1;
                    end
                    else
                        col_counter <= col_counter + 7'd1;

                    // buffer shift left
                    encode_compute_buffer[0] <= encode_compute_buffer[1];
                    encode_compute_buffer[3] <= encode_compute_buffer[4];
                    encode_compute_buffer[6] <= encode_compute_buffer[7];
                    encode_compute_buffer[1] <= encode_compute_buffer[2];
                    encode_compute_buffer[4] <= encode_compute_buffer[5];
                    encode_compute_buffer[7] <= gray_data;
                    // If it's first column, reset last_row_buffer.
                    if(col_counter == 7'd1)
                    begin
                        last_row_buffer[0] <= encode_compute_buffer[3];
                        last_row_buffer[1] <= encode_compute_buffer[4];
                        last_row_buffer[2] <= encode_compute_buffer[5];
                        last_row_buffer[3] <= encode_compute_buffer[6];
                        last_row_buffer[4] <= encode_compute_buffer[7];
                        last_row_buffer[5] <= gray_data;
                    end

                    if(finish)
                        lbp_valid <= 0;
                    else
                        lbp_valid <= 1;
                    lbp_addr <= buffer_center;
                    lbp_data <= lbp_compute;
                end

            endcase
        end
    end
    // combinational circuit
    always@(*)
    begin
        case(state)
            STATE_INITIAL_ROW:
            begin
                case(load_counter)
                    0,1,2:  gray_addr = buffer_center - 14'd129 + {10'd0,load_counter};
                    3,4,5:  gray_addr = buffer_center - 14'd1 + {10'd0,load_counter - 3'd3};
						  default:	gray_addr = 14'd0;
                endcase
            end    
            STATE_INITIAL_COL:    gray_addr = buffer_center + 14'd127 + {10'd0,load_counter};
            STATE_LOAD:           gray_addr = buffer_center - 14'd127 + ({10'd0,load_counter}<<7);
            STATE_OUTPUT:         gray_addr = buffer_center + 14'd129;
        endcase

        lbp_compute = 0;
        if(encode_compute_buffer[0] >= encode_compute_buffer[4])    lbp_compute = lbp_compute + 8'd1;
        if(encode_compute_buffer[1] >= encode_compute_buffer[4])    lbp_compute = lbp_compute + 8'd2;
        if(encode_compute_buffer[2] >= encode_compute_buffer[4])    lbp_compute = lbp_compute + 8'd4;
        if(encode_compute_buffer[3] >= encode_compute_buffer[4])    lbp_compute = lbp_compute + 8'd8;
        if(encode_compute_buffer[5] >= encode_compute_buffer[4])    lbp_compute = lbp_compute + 8'd16;
        if(encode_compute_buffer[6] >= encode_compute_buffer[4])    lbp_compute = lbp_compute + 8'd32;
        if(encode_compute_buffer[7] >= encode_compute_buffer[4])    lbp_compute = lbp_compute + 8'd64;
        if(gray_data >= encode_compute_buffer[4])                   lbp_compute = lbp_compute + 8'd128;
    end
endmodule
