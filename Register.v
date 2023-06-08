`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    11:50:40 07/10/2022 
// Design Name: 
// Module Name:    Register 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Register(input wire clk, input wire rst, input wire [7:0]dataIn, output reg [7:0]dataOut, input wire en);
	reg [7:0]data;
	
	always @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			data <= 0;
		end
		
		else
		begin
			if(en)
				data <= dataIn;
				
			dataOut <= data;
		end
	end
endmodule
