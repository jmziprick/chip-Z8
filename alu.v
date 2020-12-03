module Alu(input wire [3:0]opcode, input wire [7:0]regA, input wire [7:0]regB, output reg [7:0]acc, output reg flag, output reg eqFlag);
    reg [8:0]overflow;
 
    always @*
	begin
		flag = 0;
        eqFlag = 0;
		acc = 0;

		case(opcode)
			4'b0000: //or
			begin
				acc = regA | regB;
			end

			4'b0001: //and
			begin
				acc = regA & regB;
			end

			4'b0010: //shl
			begin
				acc = {regA[6:0], 1'b0};
			end

			4'b0011: //shr
			begin
				acc = {1'b0, regA[7:1]};
			end

			4'b0100: //cmp
			begin
				if(regA > regB)
					flag = 1;
     
                else if(regA == regB)
                    eqFlag = 1;
			end

			4'b0101: //not
			begin
				acc = ~regA;
			end

			4'b0110: //xor
			begin
				acc = ((regA | regB) & (~regA | ~regB));
			end

			4'b0111: //add
			begin
				acc = regA + regB;
                overflow = regA + regB;
                flag = overflow[8];
			end

			4'b1000: //sub
			begin
				acc = regA - regB;
			end
   
            4'b1001: //inc
            begin
                acc = regA + 1;
                overflow = regA + 1;
                flag = overflow[8];
            end
            
            4'b1010: //dec
            begin
                acc = regA - 1;
            end

			default:
			begin
				flag = 0;
                eqFlag = 0;
				acc = 8'b0;
			end
		endcase
	end
endmodule
