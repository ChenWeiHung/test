module Comparator(
    input                   clk,
    input                   rst,
    input                   enable,
    input   [7:0]           histcount,
    input                   dcu_valid,
    input   [17:0]          distance,
    input   [4:0]           id,

    output  reg             id_ren,
    output  reg [7:0]       id_counter,
    output  reg             dcu_enable,
    output  reg [4:0]       label,
    output  reg [17:0]      minDistance,
    output  reg [20:0]      hist_addr_offset,
    output  reg             done
);

	// put your design here
endmodule