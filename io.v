`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:17:27 07/24/2022 
// Design Name: 
// Module Name:    IO 
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

module IO(input wire clk, 
input wire rstIn, 
output wire beeper,
input wire [3:0]hardInterrupt
);

wire [7:0]debugStackbaf;
//wire [7:0]debugStackbb0;
//wire [7:0]debugStackbb1;
//wire [7:0]debugStackbb2;

assign debugStackbaf = mem[16'hbaf];
//assign debugStackbb0 = mem[16'hbb0];
//assign debugStackbb1 = mem[16'hbb1];
//assign debugStackbb2 = mem[16'hbb2];


	reg [23:0]addressOut;
	reg wrt;
	reg [2:0]peripheralSel;
	reg [1:0]device;
	inout wire [7:0]portA;
	inout wire [7:0]portB;

	//ports/data lines
	//assign instruction = wrt ? 8'bz : dataBusIn;
	assign portA = portRdA ? 8'bz : portOutA;
	assign portB = portRdB ? 8'bz : portOutB;
	
	reg portRdA;
	reg portRdB;
	reg [7:0]portOutA;
	reg [7:0]portOutB;
	
	always @(posedge clk)
	begin
		if(memReadWrite == ADDR_MODE_WRT)
			begin		
			 //write to ports
			if(addressLinesIn == 16'hFFFF)			
				portOutA <= dataBusIn;
			
			else if(addressLinesIn == 16'hFFFE)
				portOutB <= dataBusIn;

			else if(addressLinesIn == 16'hFFFD)
			begin
				peripheralSel <= dataBusIn[2:0];
			end
		end
	end

	reg [7:0]instruction;
	reg [7:0]mem[0:3000];

	integer i;
	initial begin
		for(i = 0; i < 10485; i = i + 1)
		begin
			mem[i] = 8'b0_000_0_000;
		end
		mem[0] = 8'b0000_0011;
		mem[1] = 8'hBA;

		mem[2] = 8'b0000_0011;
		mem[3] = 8'hf8;

		mem[4] = 8'b0000_0011;
		mem[5] = 8'h8d;

		mem[6] = 8'b0000_0011;
		mem[7] = 8'hdb;

		mem[8] = 8'b0000_0001;
		mem[9] = 8'b0000_0100;

		mem[10] = 8'b0000_0100;
		mem[11] = 8'haf;
		mem[12] = 8'hb;
		mem[13] = 8'h0;
		
		mem[14] = 8'b0000_1111;
		mem[15] = 8'b0000_0000;
		mem[16] = 8'b0001_1111;
		mem[17] = 8'b0000_0011;
		
		mem[18] = 8'b0100_0111;
		mem[19] = 8'hc4;
		mem[20] = 8'h9;
		mem[21] = 0;

		//mem[22] = 8'b1000_0100; //cmp

		mem[22] = 8'b0000_1000; //int
		mem[23] = 1; //int num

		//mem[25] = 8'b0010_1000; //call
		//mem[26] = 8'd100;
		//mem[27] = 8'h00;
		//mem[28] = 8'h00;

		//mem[23] = 8'b0000_0011; //lod
		//mem[24] = 8'h0;
		//mem[23] = 8'b1000_0110; //xor r2
		//mem[24] = 8'b0000_001;

		//mem[25] = 8'b1000_0010; //SHL


		mem[29] = 8'b1000_0100; //cmp
		mem[30] = 8'b0000_0010;

		mem[31] = 8'b0000_1010; //pusha
		mem[32] = 8'b0000_1011; //popa

		mem[33] = 8'b0100_1000; //bra, 0

		//called function
		mem[100] = 8'h00; //nop
		mem[101] = 8'b0000_0011;
		mem[102] = 8'hb8;
		mem[103] = 8'b0010_0110; //rts

		//irq vec. table addr
		mem[2000] = 8'h8c; //lsb
		mem[2001] = 8'ha;
		mem[2002] = 0; //msb
		mem[2003] = 8'h9; //int priority
		//////////////

		//int vec.
		mem[2240] = 8'hf0;
		mem[2241] = 8'ha;
		mem[2242] = 0;
		mem[2243] = 8'h5;

		//irq 1
		mem[2700] = 8'b0000_1010; //pusha

		mem[2701] = 8'b0000_0011; //lod
		mem[2702] = 8'h7c;

		mem[2703] = 8'h73;
		mem[2704] = 8'b0000_0001;

		mem[2705] = 8'b0000_0011; //lod
		mem[2706] = 8'h0;

		mem[2707] = 8'h73;
		mem[2708] = 8'b0000_0010;

		mem[2709] = 8'b0000_0011; //lod
		mem[2710] = 8'h0;

		mem[2711] = 8'h73;
		mem[2712] = 8'b0000_0011;

		mem[2713] = 8'b0000_1011; //popa
		mem[2714] = 8'b0111_1000; //iret

		//int 16
		mem[2800] = 8'b0000_1010; //pusha
		mem[2801] = 8'b0000_1011; //popa
		mem[2802] = 8'b0111_1000; //iret

		mem[2500] = 8'hf8;
		//mem[8] = 8'b0000_0101;


		//$readmemb("data.txt", mem);
	end


	always @*
	begin
		wrt = 1; //read mode
		device = 2'b10;
		memException = 0;
		portRdA = 0; //output by default
		portRdB = 0;
    
		if(memReadWrite == ADDR_MODE_PC)
		begin
			addressOut = pc;
			instruction = mem[pc];

			if(addressLinesIn < 8192) //ROM
			begin
				device[0] = 0;
				device[1] = 1;
			end
			
			else //RAM
			begin
				device[0] = 1;
				device[1] = 0;
			end
		end

		else if(memReadWrite == ADDR_MODE_RD)
		begin
			instruction = mem[addressLinesIn];
			
			if(addressLinesIn < 8192) //ROM
			begin
				device[0] = 0;
				device[1] = 1;
			end
			
			else //RAM
			begin
				device[0] = 1;
				device[1] = 0;
			end
		
			//read ports
			if(addressLinesIn == 16'hFFFF)
				portRdA = 1;
		
			else if(addressLinesIn == 16'hFFFE) 
			begin
				portRdB = 1;
			end

			else if(addressLinesIn == 16'hFFFD)
			begin
			end
			
			else
				 addressOut = addressLinesIn;
		end

		else if(memReadWrite == ADDR_MODE_WRT)
		begin		
			mem[addressLinesIn] = dataBusIn;

				//write to ports
			if(addressLinesIn == 16'hFFFF)
			begin
				//disable ROM & RAM
				device[0] = 1;
				device[1] = 1;
			end
			
			else if(addressLinesIn == 16'hFFFE)
			begin
				//disable ROM & RAM
				device[0] = 1;
				device[1] = 1;
			end
			//Ports////////////////////////////
			
			else
			begin
				wrt = 0; //enable write to RAM
				
				//disable ROM, enable RAM
				device[0] = 1;
				device[1] = 0;
				
				//if(addressLinesIn < 8192) //can't write to ROM
				//	memException = 1;
					
				addressOut = addressLinesIn;			
			end		
		end	
	end

	wire rst;
	assign rst = ~rstIn; //rstIn active low
	
	localparam [1:0]
		ADDR_MODE_RD = 2'b00,  //00 reads address lines (reading 'random' locations)
		ADDR_MODE_PC = 2'b01,  //01 reads address at pc
		ADDR_MODE_WRT = 2'b10; //10 writes to address lines

	//localparam [1:0]
	//	ADDR_MODE_PC = 3'b000,	//000 reads address lines at pc
	//	ADDR_MODE_RD = 3'b001,  //001 reads address lines (reading 'random' locations)
	//	PC1_MODE_RD = 3'b010,   //010 reads pc + 1
	//	PC2_MODE_RD = 3'b011,   //011 reads pc + 2
	//	ADDR_MODE_WRT = 3'b100; //100 writes to address lines

	wire [23:0]pc;

	wire [23:0]addressLinesIn;
	wire [7:0]dataBusIn;
	wire [1:0]memReadWrite;
	reg memException;

	//for sim
	Control control(clk, rst, pc, instruction, addressLinesIn, memReadWrite, dataBusIn, hardInterrupt, memException);
endmodule
