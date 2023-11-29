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
input wire [3:0]hardInterrupt,
output wire [7:0]debugStackbaf0,
output wire [7:0]debugStackbaf1,
output wire [7:0]debugStackbaf2,
output wire [7:0]debugStackbaf3
);

assign debugStackbaf0 = mem[16'h100];
assign debugStackbaf1 = mem[16'hFF];
assign debugStackbaf2 = mem[16'hFE];
assign debugStackbaf3 = mem[16'hFD];

//assign debugInstruction = dataToControl;
//assign debugStackbaf = mem[16'hbaf];
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

	reg [7:0]dataToControl;
	reg [7:0]mem[0:10000];

	integer i;
	initial begin
		for(i = 0; i < 10485; i = i + 1)
		begin
			mem[i] = 8'b0_000_0_000;
		end

		$readmemb("data.txt", mem);
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
			dataToControl = mem[pc];

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
			dataToControl = mem[addressLinesIn];
			
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
	Control control(clk, rst, pc, dataToControl, addressLinesIn, memReadWrite, dataBusIn, hardInterrupt, memException);
endmodule
