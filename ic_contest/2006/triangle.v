module triangle (clk, reset, nt, xi, yi, busy, po, xo, yo);
  input clk, reset, nt;
  input [2:0] xi, yi;
  output busy, po;
  output [2:0] xo, yo;

  reg state,next_state;
  reg nt_store;                                      // for input state                    /* nt signal only at high in one cycle */ 
  reg [1:0] ready_store_index;                       // compute index for store vertex
  reg [2:0] vertex_coor_x [0:2],vertex_coor_y [0:2]; // store vertex                       /* initialize when state_input */
  reg [2:0] ready_output_x,ready_output_y;           // compute output point               /* initialize when state_input */
  reg busy, po;                                      // control input vertex data          /* if store two data , busy should be high when the third vertex input */
  reg [2:0] xo, yo;


  wire [5:0] x1,x2,x3,y1,y2,y3,x,y;                                                        /* easy for recognize RTL code */
  assign x1 = vertex_coor_x[0];
  assign x2 = vertex_coor_x[1];
  assign x3 = vertex_coor_x[2];
  assign y1 = vertex_coor_y[0];
  assign y2 = vertex_coor_y[1];
  assign y3 = vertex_coor_y[2];
  assign x = ready_output_x;
  assign y = ready_output_y;

  wire [2:0] ready_output_x_initial,ready_output_x_end;                                   // for case x2>x1 or case x1>x2
  assign ready_output_x_initial = (x2 > x1)?x1:x2;
  assign ready_output_x_end     = (x2 > x1)?x2:x1;

  reg inside;                                       // inside = 1 if the point is inside the triangle 
  // assign inside = ( ((y-y2)*(x2-x3)) <= ((y3-y2)*(x2-x)) )?1:0;

  

  parameter STATE_INPUT  = 0,
            STATE_OUTPUT = 1;
  

// Next State Logic
  always@(*)
  begin
    case(state)
      STATE_INPUT:  // 3 cycles
      begin
        if(ready_store_index == 2'd2)
          next_state = STATE_OUTPUT;
        else 
          next_state = STATE_INPUT;
      end
      
      STATE_OUTPUT:
      begin
        if((ready_output_x == ready_output_x_end)&&(ready_output_y == y3))
          next_state = STATE_INPUT;
        else  
          next_state = STATE_OUTPUT;
      end

    endcase
  end
  
// State Register
  always@(posedge clk or posedge reset)
  begin
    if(reset)
      state <= STATE_INPUT;
    else
      state <= next_state;
  end

// Datapath & Output Logic
  always@(posedge clk or posedge reset)
  begin
    if(reset)
    begin
      nt_store <= 0;
      ready_store_index <= 2'd0;
      busy <= 0;
      po <= 0;
    end
    else
    begin
      case(state)
        STATE_INPUT: 
        begin
          /* store input vertex */
          vertex_coor_x[ready_store_index] <= xi;
          vertex_coor_y[ready_store_index] <= yi;
          /* store cycle (1) nt  -> (2) nt_store  -> (3) busy (change to output state) */
          if(nt)
          begin
            ready_store_index <= ready_store_index + 2'd1;
            nt_store <= 1;
          end
          else if(nt_store)
          begin
            ready_store_index <= ready_store_index + 2'd1; 
            busy <= 1;
          end
          /* prepare the first output */              
          ready_output_x <= ready_output_x_initial;
          ready_output_y <= y1[2:0];
        end

        STATE_OUTPUT:
        begin
            /* output computing point */
            xo <= ready_output_x;
            yo <= ready_output_y;
            /* if point is inside, po is high */
            if(inside)
              po <= 1;
            else
              po <= 0;
            /* ready output compute the point that x from x_i~x_f & y from y1~y3, so that we only need to check the slope condition */
            if(ready_output_x == ready_output_x_end)
            begin
              if(ready_output_y == y3[2:0])
              begin
                ready_store_index <= 0;
                nt_store <= 0;
                busy <= 0;
                po <= 0;
              end
              else  
              begin
                ready_output_y <= ready_output_y + 1;
                ready_output_x <= ready_output_x_initial;
              end
            end
            else
              ready_output_x <= ready_output_x + 2'd1;
        end

      endcase
    end
  end

  // combinational datapath
  
  always@(*)
  begin
    if(x2 > x1)       // for I don't know whether x2 may smaller than x1
    begin
        if( ((y-y2)*(x2-x3)) <= ((y3-y2)*(x2-x)) )                  
            inside = 1;
        else
            inside = 0;
    end
    else
    begin
        if( ((x3-x2)*(y-y2)) <= ((x-x2)*(y3-y2)) )
            inside = 1;
        else  
            inside = 0;
    end
  end
endmodule
