`timescale 1ns/1ps

module Test;
	reg clk;
	reg reset;

	Control uut(clk, reset);
	initial begin
		forever
		begin
			clk = 0;
			#1;

			clk = 1;
			#1;
		end
	end

	initial begin
	$dumpfile("controlTest.vcd");
	$dumpvars(0, Test);
		reset = 1;
		#10;

		reset = 0;
		#100;
	$finish;
	end
endmodule
