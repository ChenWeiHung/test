module HCU(
    input               clk,
    input               rst,
    input               mode,
    input               enable,
    input   [3:0]       gridX,
    input   [3:0]       gridY,
    output  reg         lbp_ren,
    output  reg [11:0]  lbp_addr,
    input       [7:0]   lbp_rdata,

    output  reg         hist_wen_train,
    output  reg [7:0]   hist_wdata_train,
    output  reg [20:0]  hist_addr_train,
    output  reg         hist_ren_train,
    input   [7:0]       hist_rdata_train,

    output  reg         hist_wen_predict,
    output  reg [7:0]   hist_wdata_predict,
    output  reg [13:0]  hist_addr_predict,
    output  reg         hist_ren_predict,
    input   [7:0]       hist_rdata_predict,

    output  reg         done
    );

    // put your design here
	
endmodule