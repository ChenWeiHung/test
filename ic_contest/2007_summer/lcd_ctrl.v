module lcd_ctrl(clk, reset, datain, cmd, cmd_valid, dataout, output_valid, busy);
    input           clk;
    input           reset;
    input   [7:0]   datain;
    input   [2:0]   cmd;
    input           cmd_valid;
    output  [7:0]   dataout;
    output          output_valid;
    output          busy;

    parameter STATE_WAIT   = 2'd0,
              STATE_LOAD   = 2'd1,
              STATE_SHIFT  = 2'd2,
              STATE_OUTPUT = 2'd3;

    reg [1:0] state,next_state;
    reg [2:0] cmd_buffer;
    reg [5:0] load_output_counter;  //load:0~35, output:0~8             //reset
    reg [1:0] coor_x,coor_y;        //0~3                               //reset
     reg [5:0] image_origin,output_index;         //(y*6 + x) + (0~14) -->0~35
    reg [7:0] image_buffer [0:35];                                      //initialize
    reg output_valid;                                                   //reset
    reg busy;                                                           //reset
    reg [7:0] dataout;                                                  //initialize


// Next State Logic
    always@(*)
    begin
        case(state)
            STATE_WAIT:
            begin
                if(cmd_valid)
                begin
                    case(cmd)
                        3'd0:  next_state = STATE_OUTPUT;
                        3'd1:  next_state = STATE_LOAD;
                        3'd2,3'd3,3'd4,3'd5:    next_state = STATE_SHIFT;
                        default:    next_state = STATE_WAIT;
                    endcase
                end
                else
                    next_state = STATE_WAIT;
            end

            STATE_LOAD:
            begin
                if(load_output_counter == 6'd35)
                    next_state = STATE_OUTPUT;
                else
                    next_state = STATE_LOAD;
            end

            STATE_SHIFT:
                next_state = STATE_OUTPUT;
            
            STATE_OUTPUT:
            begin
                if(load_output_counter == 6'd8)
                    next_state = STATE_WAIT;
                else
                    next_state = STATE_OUTPUT;
            end
        endcase
    end

// State Register
    always@(posedge clk or posedge reset)
    begin
        if(reset)
            state <= STATE_WAIT;
        else
            state <= next_state;
    end

// Datapath
    // sequential circuit
    always@(posedge clk or posedge reset)
    begin
        if(reset)
        begin
            load_output_counter <= 6'd0;
            coor_x <= 2'd2;
            coor_y <= 2'd2;
            output_valid <= 0;
            busy <= 0;
        end
        else
        begin
            case(state)
                STATE_WAIT:
                begin
                    output_valid <= 0;
                    if(cmd_valid)
                        busy <= 1;
                    cmd_buffer <= cmd;
                end

                STATE_LOAD:
                begin
                    image_buffer[load_output_counter] <= datain;
                    coor_x <= 2'd2;
                    coor_y <= 2'd2;
                    if(load_output_counter == 6'd35)
                        load_output_counter <= 6'd0;
                    else
                        load_output_counter <= load_output_counter + 6'd1;
                end

                STATE_SHIFT:
                begin
                    case(cmd_buffer)
                        3'd2:  if(coor_x < 2'd3)   coor_x <= coor_x + 2'd1;    // right

                        3'd3:  if(coor_x > 2'd0)   coor_x <= coor_x - 2'd1;    // left

                        3'd4:  if(coor_y > 2'd0)   coor_y <= coor_y - 2'd1;    // up
                        
                        3'd5:  if(coor_y < 2'd3)   coor_y <= coor_y + 2'd1;    // down

                    endcase
                end
                
                STATE_OUTPUT:
                begin
                    dataout <= image_buffer[output_index];
                    output_valid <= 1;
                    if(load_output_counter == 6'd8)
                    begin
                        load_output_counter <= 6'd0;
                        busy <= 0;
                    end
                    else
                        load_output_counter <= load_output_counter + 6'd1;
                end
                
            endcase
        end
    end
    // combinational circuit
    always@(*)
    begin
        image_origin = (({4'd0,coor_y}<<2)+({4'd0,coor_y}<<1)) + {4'd0,coor_x};
        case(load_output_counter)
            0:  output_index = image_origin + 6'd0;
            1:  output_index = image_origin + 6'd1;
            2:  output_index = image_origin + 6'd2;
            3:  output_index = image_origin + 6'd6;
            4:  output_index = image_origin + 6'd7;
            5:  output_index = image_origin + 6'd8;
            6:  output_index = image_origin + 6'd12;
            7:  output_index = image_origin + 6'd13;
            8:  output_index = image_origin + 6'd14;
            // default:   
            //     output_index = 0;
        endcase
    end
                                                                                     
endmodule

