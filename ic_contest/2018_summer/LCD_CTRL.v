module LCD_CTRL(clk, reset, cmd, cmd_valid, IROM_Q, IROM_rd, IROM_A, IRAM_valid, IRAM_D, IRAM_A, busy, done);
    input clk;
    input reset;
    input [3:0] cmd;
    input cmd_valid;
    input [7:0] IROM_Q;
    output IROM_rd;
    output [5:0] IROM_A;
    output IRAM_valid;
    output [7:0] IRAM_D;
    output [5:0] IRAM_A;
    output busy;
    output done;

    parameter STATE_RESET = 2'd0, // IROM_A will count every posedge clk, but i don't know whether the first negedge clk read the IROM_A or not.
              STATE_LOAD  = 2'd1,
              STATE_WAIT  = 2'd2,
              STATE_WRITE = 2'd3;

    reg [1:0] state,next_state;
    reg [7:0] image_buffer [0:63];
    reg [2:0] coor_x,coor_y;

    wire [5:0] orign;
    assign orign = ({3'd0,coor_y}<<3) + {3'd0,coor_x};
    reg [7:0] maximum,minimum;
    reg [9:0] ext_average_10_bit;
    reg [7:0] replace_l_up,replace_r_up,replace_l_down,replace_r_down;

    reg IROM_rd;
    reg [5:0] IROM_A;
    reg IRAM_valid;
    reg [5:0] IRAM_A;
    reg [7:0] IRAM_D;
	 reg busy;
    reg done;
	 

// Next State Logic
    always@(*)
    begin
        case(state)
            STATE_RESET:
            begin
                if(!reset)
                    next_state = STATE_LOAD;
                else
                    next_state = STATE_RESET;
            end
            STATE_LOAD:
            begin
                if(IROM_A == 6'd63)
                    next_state = STATE_WAIT;
                else
                    next_state = STATE_LOAD;
            end

            STATE_WAIT:
            begin
                if((cmd == 4'd0)&&(cmd_valid))
                    next_state = STATE_WRITE;
                else
                    next_state = STATE_WAIT;
            end

            STATE_WRITE:
                next_state = STATE_WRITE;

        endcase
    end
// State Register
    always@(posedge clk or posedge reset)
    begin
        if(reset)
            state <= STATE_RESET;
        else
            state <= next_state;
    end
// Datapath
    // sequential circuit
    always@(posedge clk or posedge reset)
    begin
        if(reset)
        begin
            IROM_rd <= 0;
        end
        else
        begin
            case(state)
                STATE_RESET:
                begin
                    IROM_rd <= 1;
                    IROM_A <= 6'd0;
                    busy <= 1;
                    coor_x <= 3'd4;
                    coor_y <= 3'd4;
                end

                STATE_LOAD:
                begin
                    IROM_A <= IROM_A + 6'd1;
                    image_buffer[IROM_A] <= IROM_Q;
                    if(IROM_A == 6'd63)
                    begin
                        IROM_rd <= 0;
                        busy <= 0;
                    end
                end

                STATE_WAIT:
                begin
                    case(cmd)
                        0:  // write
                        begin
                            IRAM_valid <= 1;
                            IRAM_A <= 6'd0;
                            IRAM_D <= image_buffer[6'd0];
                            busy <= 1;
                        end
                            // shift
                        1:  if(coor_y > 3'd1) coor_y <= coor_y - 3'd1;
                        2:  if(coor_y < 3'd7) coor_y <= coor_y + 3'd1;
                        3:  if(coor_x > 3'd1) coor_x <= coor_x - 3'd1;
                        4:  if(coor_x < 3'd7) coor_x <= coor_x + 3'd1;
                            // replce compute
                        5,6,7,8,9,10,11:  
                        begin
                            image_buffer[orign - 6'd9] <= replace_l_up;
                            image_buffer[orign - 6'd8] <= replace_r_up;
                            image_buffer[orign - 6'd1] <= replace_l_down;
                            image_buffer[orign - 6'd0] <= replace_r_down;
                        end
                        
                    endcase
                end

                STATE_WRITE:
                begin
                    IRAM_A <= IRAM_A + 6'd1;
                    IRAM_D <= image_buffer[IRAM_A + 6'd1];
                    if(IRAM_A == 6'd63)
                        done <= 1;
                end

            endcase
        end
    end
    // combinational circuit
    always@(*)
    begin
        minimum = image_buffer[orign - 6'd9];
        if(image_buffer[orign - 6'd8] < minimum) minimum = image_buffer[orign - 6'd8];
        if(image_buffer[orign - 6'd1] < minimum) minimum = image_buffer[orign - 6'd1];
        if(image_buffer[orign - 6'd0] < minimum) minimum = image_buffer[orign - 6'd0];
    end
    always@(*)
    begin
        maximum = image_buffer[orign - 6'd9];
        if(image_buffer[orign - 6'd8] > maximum) maximum = image_buffer[orign - 6'd8];
        if(image_buffer[orign - 6'd1] > maximum) maximum = image_buffer[orign - 6'd1];
        if(image_buffer[orign - 6'd0] > maximum) maximum = image_buffer[orign - 6'd0];
    end
    always@(*)
    begin
        ext_average_10_bit = (({2'd0,image_buffer[orign - 6'd9]} + {2'd0,image_buffer[orign - 6'd8]} + {2'd0,image_buffer[orign - 6'd1]} + {2'd0,image_buffer[orign - 6'd0]})>>2);
    end
    always@(*)
    begin
        /*
            [-9] [-8]
            [-1] [-0]
        */
        case(cmd)
            5:// Max
            begin
                replace_l_up = maximum;
                replace_r_up = maximum;
                replace_l_down = maximum;
                replace_r_down = maximum;
            end
            6:// Min
            begin
                replace_l_up = minimum;
                replace_r_up = minimum;
                replace_l_down = minimum;
                replace_r_down = minimum;
            end
            7:// Avg
            begin
                replace_l_up = ext_average_10_bit[7:0];
                replace_r_up = ext_average_10_bit[7:0];
                replace_l_down = ext_average_10_bit[7:0];
                replace_r_down = ext_average_10_bit[7:0];
            end
            8:// counter clockwise
            begin
                replace_l_up = image_buffer[orign - 6'd8];
                replace_r_up = image_buffer[orign - 6'd0];
                replace_l_down = image_buffer[orign - 6'd9];
                replace_r_down = image_buffer[orign - 6'd1];
            end
            9:// clockwise
            begin
                replace_l_up = image_buffer[orign - 6'd1];
                replace_r_up = image_buffer[orign - 6'd9];
                replace_l_down = image_buffer[orign - 6'd0];
                replace_r_down = image_buffer[orign - 6'd8];
            end
            10:// Mirror X
            begin
                replace_l_up = image_buffer[orign - 6'd1];
                replace_r_up = image_buffer[orign - 6'd0];
                replace_l_down = image_buffer[orign - 6'd9];
                replace_r_down = image_buffer[orign - 6'd8];
            end
            11:// Mirror Y
            begin
                replace_l_up = image_buffer[orign - 6'd8];
                replace_r_up = image_buffer[orign - 6'd9];
                replace_l_down = image_buffer[orign - 6'd0];
                replace_r_down = image_buffer[orign - 6'd1];
            end

            default:
            begin
                replace_l_up = 0;
                replace_r_up = 0;
                replace_l_down = 0;
                replace_r_down = 0;
            end
        endcase
    end

endmodule



