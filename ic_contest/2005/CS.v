`timescale 1ns/10ps
/*
 * IC Contest Computational System (CS)
*/
module CS(Y, X, reset, clk);

	input clk, reset; 
	input [7:0] X;
	output reg [9:0] Y;
	
	reg [7:0] X_input [0:8];
	reg [9:0] X_avg,X_appr;
	integer i;

	always@(posedge clk or posedge reset)
	begin
		if(reset)
		begin
	//Reset
			for(i = 0;i < 9;i = i + 1)
				X_input[i] <= 8'd0;
			X_appr <= 0;
		end
		else
		begin
	//Shift & Input new X 
			for(i = 0;i < 8;i = i + 1)
				X_input[i] <= X_input[i+1];
			X_input[8] <= X;
			X_appr <= 0;
		end
	end
	

	always@(*)
	begin
	//computation of average
		X_avg = (X_input[0] + X_input[1] + X_input[2] + X_input[3] + X_input[4] + X_input[5] + X_input[6] + X_input[7] + X_input[8])/9;
	//computation of appr
		for(i = 0;i < 9;i = i + 1)
		begin
			if( (X_input[i] <= X_avg) && (X_appr <= X_input[i]) ) 
					X_appr = X_input[i];
		end
	//computation of Y
		Y = (X_input[0] + X_input[1] + X_input[2] + X_input[3] + X_input[4] + X_input[5] + X_input[6] + X_input[7] + X_input[8] + X_appr*9)/8;
	end
 
endmodule

