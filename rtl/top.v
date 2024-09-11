`include "../rtl/CLBP.v"
`include "../rtl/HCU.v"
`include "../rtl/DCU.v"
`include "../rtl/Comparator.v"
`include "../rtl/Controller.v"

module top(
    input           clk,
    input           rst,
    input           enable,
    input           mode,
    input           valid, 
    input   [4:0]   id,
    input   [3:0]   gridX,
    input   [3:0]   gridY,

    // CLBP I/O & LBP RAM
	output 	[11:0]	gray_addr,
	output			gray_ren,
	input	[7:0]	gray_rdata,
    output  [11:0]  lbp_addr,
    output          lbp_wen,
	output			lbp_ren,
    input   [7:0]   lbp_rdata,
	output	[7:0] 	lbp_wdata,
	output	[24:0]	theta,
	output			theta_valid,
	input	[24:0]	cos_data,
	input			cos_valid,
	input	[24:0]	sin_data,
	input			sin_valid,
	output			lbp_finish,
	
    // ID RAM I/O
    output  [7:0]   id_addr,
    output  [4:0]   id_wdata,
    output          id_wen,
    output          id_ren,
    input   [4:0]   id_rdata,

    // HIST TRAIN RAM I/O
    output  [20:0]  hist_addr_train,
    output  [7:0]   hist_wdata_train,
    output          hist_wen_train,
    output          hist_ren_train,
    input   [7:0]   hist_rdata_train,

    // HIST PREDICT RAM I/O
    output  [13:0]  hist_addr_predict,
    output  [7:0]   hist_wdata_predict,
    output          hist_wen_predict,
    output          hist_ren_predict,
    input   [7:0]   hist_rdata_predict,  

    output          hcu_finish,
    output          done,
    output  [4:0]   label,
    output  [17:0]  minDistance
);

    // put your design here
    


endmodule