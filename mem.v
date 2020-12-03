module Mem(input wire [7:0]addr, input wire [7:0]addr1, input wire [7:0]storeAddr, input wire write, input wire [7:0]dataIn, output wire [7:0]dataOut, output wire [7:0]dataOut1, output reg [7:0]dataAtAddr);

    reg [7:0]data[0:256];

    assign dataOut = data[addr];
    assign dataOut1 = data[addr + 1]; //for immediate mov instructions

    //fill memory
	integer i;
	initial begin
        data[0] = 8'b0_00_00_101; //immediate mov
        data[1] = 8'hAA;
        
        data[2] = 8'b0_01_00_001; //mov r1 to r2
        
        data[3] = 8'b0_00_00_101; //immediate mov
        data[4] = 30;
        
        data[5] = 8'b0000_0100;
        data[6] = 8'b0000_0000;
        
        data[7] = 8'b0000_0000;
        data[8] = 8'b0000_0000;
        
        data[9] = 8'b0_00_00_101; //imm mov
        data[10] = 30;
        
        data[11] = 8'b0_00_00_011; //load
        data[12] = 8'b0000_0000;
        data[13] = 8'b0000_0000;
        data[14] = 8'b0000_0000;
        
        data[15] = 8'b0000_0000; //nop
        
        data[16] = 8'b0_00_00_101; //immediate mov (20 in r1)
        data[17] = 8'b000_10100; //20
        
        data[18] = 8'b0_00_00_011; //load mem[20]
        data[19] = 8'b0_00_00_000; //nop
        data[20] = 8'hBA;
        
        data[21] = 8'b1_00_00110; //xor r1,r1
        data[22] = 8'b0_0000_010; //jmp to r1
        
        data[23] = 8'b1111_1111;
        
        data[24] = 8'b0_01_00_001; //mov
        data[25] = 8'b0_00_00_000; //nop
        data[26] = 8'b1_01_00_100;
        
        for(i = 27; i < 200; i = i + 1)
        begin
            data[i] = 8'b0_00_00_000; //nop
        end
	end

    always @*
	begin
		if(write)
		begin
			data[storeAddr] = dataIn;
		end
  
        dataAtAddr = data[addr1];
  end
endmodule
