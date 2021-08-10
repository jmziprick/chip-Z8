`timescale 1ns/1ps

module Test;
    reg clk, rst;
    reg [7:0]dBusIn;
    wire [7:0]dBusOut;
    wire rWMem;
    wire [15:0]addrBus;
    wire [15:0]pcOutTest;
    
    initial begin
        forever
        begin
            clk = 0;
            #1;
            
            clk = 1;
            #1;
        end
    end
    
    Control uut(clk, rst, dBusIn, dBusOut, rWMem, addrBus, pcOutTest);
    initial begin
    $dumpfile("test.vcd");
    $dumpvars(0, Test);
        rst = 1;
        dBusIn = 8'h00;
        #1;
        
        rst = 0;
        #10;
        
        dBusIn = 8'b0_00_00_011; //load
        #5;
        
        dBusIn = 8'h00;
        #10
    $finish;
    end
endmodule

