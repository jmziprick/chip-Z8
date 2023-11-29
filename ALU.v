`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    20:11:55 05/17/2022 
// Design Name: 
// Module Name:    ALU 
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
module Alu(input wire [3:0]opcode, 
input wire [7:0]regA, 
input wire [7:0]regB, 
output reg [7:0]accumulator, 
output reg greaterFlag, 
output reg zeroFlag, 
output reg eqFlag,
output reg overflowFlag,
output reg divZero);
	reg [8:0]overflow;
	
	always @*
	begin
		greaterFlag = 0;
		zeroFlag = 0;
        eqFlag = 0;
		overflowFlag = 0;
		accumulator = 0;
		divZero = 0;
		overflow = 0;

		case(opcode)
			4'b0000: //or
			begin
				accumulator = regA | regB;
				
				if(accumulator == 0)
					zeroFlag = 1;
			end

			4'b0001: //and
			begin
				accumulator = regA & regB;
				
				if(accumulator == 0)
					zeroFlag = 1;
			end

			4'b0010: //shl
			begin
				accumulator = {regA[6:0], 1'b0};
			end

			4'b0011: //shr
			begin
				accumulator = {1'b0, regA[7:1]};
			end

			4'b0100: //cmp
			begin
				accumulator = regA;
				if(regA > regB)
					greaterFlag = 1;
      
            	else if(regA == regB)
					eqFlag = 1;

				if(regA == 0)
					zeroFlag = 1;
			end

			4'b0101: //not
			begin
				accumulator = ~regA;
				
				if(accumulator == 0)
					zeroFlag = 1;
			end

			4'b0110: //xor
			begin
				accumulator = ((regA | regB) & (~regA | ~regB));
				
				if(accumulator == 0)
						zeroFlag = 1;	
			end

			4'b0111: //add
			begin
				accumulator = regA + regB;
                overflow = regA + regB;
                overflowFlag = overflow[8];
			end

			4'b1000: //sub
			begin
				accumulator = regA - regB;
				
				if(accumulator == 0)
					zeroFlag = 1;
			end
   
            4'b1001: //inc
            begin
                accumulator = regA + 1'b1;
                overflow = regA + 1;
                overflowFlag = overflow[8];
            end
            
            4'b1010: //dec
            begin
                accumulator = regA - 1'b1;

				if(regA == 0)
					zeroFlag = 1;
            end

			4'b1011: //ROL
			begin
				accumulator = {regA[6:0], regA[7]};
			end

			4'b1100: //ROR
			begin
				accumulator = {regA[0], regA[7:1]};
			end

			default:
			begin
				zeroFlag = 0;
				overflowFlag = 0;
                eqFlag = 0;
				accumulator = 8'b0;
			end
		endcase
	end
endmodule