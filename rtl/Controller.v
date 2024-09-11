module Controller(
    input               clk,
    input               rst,
    input               mode,
    input               enable,
    input               valid,
    input   [4:0]       id,

    // ID RAM 
    output  reg [7:0]   id_addr,
    output  reg [4:0]   id_wdata,
    output  reg         id_wen,

    // CLBP I/O
	output	reg			lbp_enable,
	input   			lbp_finish,
	output  reg			ram_clbp,
	
    // HCU I/O
    input   [3:0]       gridX_i,     
    input   [3:0]       gridY_i,        
    output  reg         hcu_enable,
    output  reg [3:0]   gridX_o,
    output  reg [3:0]   gridY_o,  
    input               hcu_finish,      
    // Comparator I/O
    input               comparator_finish,
    output  reg         comparator_enable,
    output  reg         ram_comp
);

   // put your design here

endmodule