module SET ( clk , rst, en, central, radius, mode, busy, valid, candidate );

    input clk, rst;
    input en;
    input [23:0] central;
    input [11:0] radius;
    input [1:0] mode;
    output busy;
    output valid;
    output [7:0] candidate;

    parameter STATE_NEW_EN        = 2'd0,
              STATE_CHECK_POINT   = 2'd1,
              STATE_OUTPUT_RESULT = 2'd2,
              STATE_CLEAR_BUSY    = 2'd3;
    
    reg [1:0] state,next_state;
    reg [3:0] x_A, y_A, x_B, y_B;           //initialize
    reg [3:0] r_A,r_B;                      //initialize
    reg [1:0] mode_store;                   //initialize
    reg [3:0] check_x,check_y;              //initialize
    reg [7:0] inside_point_number;   //reset & initialize(no more reset signal in testbench)
    reg busy;                        //reset
    reg valid;                       //reset
    reg [7:0] candidate;                    //initialize

    wire [7:0] delta_x_A,delta_y_A,delta_x_B,delta_y_B,extension_r_A,extension_r_B;
    assign delta_x_A[3:0] = (check_x > x_A)?(check_x - x_A):(x_A - check_x);
    assign delta_x_A[7:4] = 4'd0;
    assign delta_y_A[3:0] = (check_y > y_A)?(check_y - y_A):(y_A - check_y);
    assign delta_y_A[7:4] = 4'd0;
    assign delta_x_B[3:0] = (check_x > x_B)?(check_x - x_B):(x_B - check_x);
    assign delta_x_B[7:4] = 4'd0;
    assign delta_y_B[3:0] = (check_y > y_B)?(check_y - y_B):(y_B - check_y);
    assign delta_y_B[7:4] = 4'd0;
    assign extension_r_A = {4'd0,r_A};
    assign extension_r_B = {4'd0,r_B};
    wire inside_A, inside_B;
    assign inside_A = (extension_r_A*extension_r_A >= delta_x_A*delta_x_A + delta_y_A*delta_y_A)?1:0;
    assign inside_B = (extension_r_B*extension_r_B >= delta_x_B*delta_x_B + delta_y_B*delta_y_B)?1:0;
    reg inside_count;


// Next State Logic
    always@(*)
    begin
        case(state)
            STATE_NEW_EN:
            begin
                if(en)
                    next_state = STATE_CHECK_POINT;
                else
                    next_state = STATE_NEW_EN;
            end

            STATE_CHECK_POINT:
            begin
                if((check_x == 4'd8)&&(check_y == 4'd8))
                    next_state = STATE_OUTPUT_RESULT;
                else
                    next_state = STATE_CHECK_POINT;
            end

            STATE_OUTPUT_RESULT:
                next_state = STATE_CLEAR_BUSY;
            
            STATE_CLEAR_BUSY:      
                next_state = STATE_NEW_EN;
            
        endcase
    end

// State Register
    always@(posedge clk or posedge rst)
    begin
        if(rst)
            state <= STATE_NEW_EN;
        else
            state <= next_state;
    end

// Datapath
    // sequential
    always@(posedge clk or posedge rst)
    begin
        if(rst)
        begin
            inside_point_number <= 8'd0;
            busy <= 0;
            valid <= 0;
        end
        else
        begin
            case(state)
                STATE_NEW_EN:                   // �ˬd�O�_�bAB��Ӷꤺ�A�� 64 cycles�A��64��cycle�p�⧹�i�JOUTPUT_RESULT���A
                begin
                    x_A <= central[23:20];
                    y_A <= central[19:16];
                    x_B <= central[15:12];
                    y_B <= central[11:8];
                    r_A <= radius[11:8];
                    r_B <= radius[7:4];
                    mode_store <= mode;
                    check_x <= 4'd1;
                    check_y <= 4'd1;

                    busy <= 1;
                end

                STATE_CHECK_POINT:              // �ˬd�O�_�bAB��Ӷꤺ�A�� 64 cycles�A��64��cycle�p�⧹�i�JOUTPUT_RESULT���A
                begin
                    if(check_x == 4'd8)
                    begin
                        check_x <= 4'd1;
                        check_y <= check_y + 4'd1;
                    end
                    else
                    begin
                        check_x <= check_x + 4'd1;
                    end

                    if(inside_count)
                        inside_point_number <= inside_point_number + 8'd1;
                end
                
                STATE_OUTPUT_RESULT:            // ��X���G�A�öi�JCLEAR_BUSY���A(��cycle�ݭn�Nvalid<= 1)
                begin
                    candidate <= inside_point_number;
                    inside_point_number <= 8'd0;
                    valid <= 1;
                end

                STATE_CLEAR_BUSY:              // ��Xvalid <= 0�Mbusy <= 0 �A�öi�J�^NEW_EN���A(��cycle�i��OUTPUT_RESULT���A�p�⵲�G)
                begin
                    busy <= 0;
                    valid <= 0;
                end

            endcase
        end
    end
    // combinational
    always@(*)/* inside_count */
    begin
        inside_count = 0;
        case(mode_store)
            2'b00:
            begin
                if(inside_A)
                    inside_count = 1;
            end

            2'b01:
            begin
                if(inside_A && inside_B)
                    inside_count = 1;
            end

            2'b10:
            begin
                if(inside_A ^ inside_B)
                    inside_count = 1;
            end
				
            default:
                inside_count = 0;
        endcase
    end


endmodule
