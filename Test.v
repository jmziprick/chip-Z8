`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   15:44:13 08/17/2022
// Design Name:   IO
// Module Name:   C:/Users/jmzip/OneDrive/Coding-Projects/Verilog/CPU/Test.v
// Project Name:  CPU
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: IO
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module Test;
	// Inputs
	reg clk;
	reg rst;
	wire beeper;
	reg [3:0]hardInterrupt;
	wire [7:0]debugStackbaf0;
	wire [7:0]debugStackbaf1;
	wire [7:0]debugStackbaf2;
	wire [7:0]debugStackbaf3;

	initial begin
		forever
		begin
			clk = 0;
			#1;
			
			clk = 1;
			#1;
		end
	end

	// Instantiate the Unit Under Test (UUT)
	IO uut (
		.clk(clk), 
		.rstIn(rst),
		.beeper(beeper),
		.hardInterrupt(hardInterrupt),
		.debugStackbaf0(debugStackbaf0),
		.debugStackbaf1(debugStackbaf1),
		.debugStackbaf2(debugStackbaf2),
		.debugStackbaf3(debugStackbaf3)
		);
	
	// Inputs
/*	reg clk;
	reg rst;

	wire [7:0]instructionOut;
	wire [19:0]addressLinesOut;
	wire [7:0]r1DebugOut;
	wire [7:0]r2DebugOut;
	wire [7:0]r3DebugOut;
	wire [7:0]r4DebugOut;
	wire [19:0]pcDebug;
	wire [7:0]memDebug;
	wire [7:0]memDebug1;
	wire [7:0]memDebug2;
	wire [19:0]iRetDebugOut;
	reg [3:0]hardInterrupt;
	wire [19:0]spDebug;
	wire beeper;

	initial begin
		forever
		begin
			clk = 0;
			#1;
			
			clk = 1;
			#1;
		end
	end

	// Instantiate the Unit Under Test (UUT)
	IO uut (
		.clk(clk), 
		.rst(rst),
		.instructionOut(instructionOut),
		.addressLinesOut(addressLinesOut),
		.r1DebugOut(r1DebugOut),
		.r2DebugOut(r2DebugOut),
		.r3DebugOut(r3DebugOut),
		.r4DebugOut(r4DebugOut),
		.pcDebug(pcDebug),
		.memDebug(memDebug),
		.memDebug1(memDebug1),
		.memDebug2(memDebug2),
		.hardInterrupt(hardInterrupt),
		.iRetDebugOut(iRetDebugOut),
		.spDebug(spDebug),
		.beeper(beeper)
	);*/

	initial begin
	$dumpfile("test.vcd");
	$dumpvars(0, Test);
		// Initialize Inputs
		clk = 0;
		rst = 0;
		hardInterrupt = 0;

		// Add stimulus here
		rst = 0;
		#10;
		
		rst = 1;
		#1;
		
		//hardInterrupt = 1;
		#100;
		//hardInterrupt = 0;
		#20;
		//hardInterrupt = 1;
		#20;
		//hardInterrupt = 0;

		#10000;
	$finish;
	end
      
endmodule

