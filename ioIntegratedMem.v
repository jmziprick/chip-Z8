module Io(input wire clk, input wire rst);

    wire rWMem;
    wire [15:0]pcAddrBus;
    wire [15:0]dataAddrBus;
    wire [15:0]dBusIn; //high byte data in, low byte opcode in
    wire [7:0]dBusOut;
    //wire [15:0]addrBus;
    wire [15:0]pc;
    wire [15:0]storeAddrBus;
    
    
    
    
    
    
    
    
    wire [7:0]test;
    assign test = mem[16'hFFFF];
    
    
    
    
    
    
    
    
    
    
    
    
    
    assign dBusIn[7:0] = mem[pcAddrBus]; //load value to dBusIn
    assign dBusIn[15:8] = mem[dataAddrBus]; //load value to dBusIn

    //Mem mem(dBusIn, dBusOut, addrBus);
    reg [7:0]mem[0:65536]; //64k 0xFFFF
    
    always @*
    begin
        if(rWMem)
            mem[storeAddrBus] = dBusOut; //store value to mem
    end
    
    integer i;
    initial begin
        for(i = 0; i < 65536; i = i + 1)
        begin
            mem[i] = 8'b0_00_00_000; //nop
        end
        
        mem[0] = 8'b0_10_00_011; //lodb r1
        mem[1] = 8'h03; //#$3
        mem[2] = 8'b0_10_00_001; //mov r1 to r3
        mem[3] = 8'b0_10_00_011; //lodb r1
        mem[4] = 8'h00; //#$0
        
        //mem[2] = 8'b0_00_00_100; //stb, store contents of r1 at address of r1
        
        mem[5] = 8'b1_10_01001; //inc r3
        mem[6] = 8'b1_10_00100; //cmp r3, r1
        mem[7] = 8'b0_00_00_111; //bgr
        mem[8] = 8'b0000_1011; //goto $11
        
        mem[9] = 8'b0_00_00_010; //jmp back 5
        mem[10] = 8'b1111_1011; //2's cmpl. 5
        
        mem[11] = 8'b0_00_00_011; //lodb r1
        mem[12] = 8'hBA;
        
        mem[13] = 8'b0_00_00_100; //stb, r1 to r1 address
        mem[14] = 8'b0_00_01_111; //push r1
        //mem[15] = 8'b0_01_11_111; //pop r2
        //mem[16] = 8'b0_10_11_111; //pop r3
        
        mem[15] = 8'b0_00_00_011; //lodb r1
        mem[16] = 8'h0C;
        mem[17] = 8'b0_01_00_001; //mov r1 to r2
        mem[18] = 8'b0_00_00_011; //lodb r1
        mem[19] = 8'h00;
        mem[20] = 8'b0_10_0_0111; //lodmem to r1 (can only do r1 or r2)
        mem[21] = 8'b0_00_11_011;
        mem[22] = 8'hB2;
        
      //  mem[3] = 8'b0_00_00_011; //lodb
      //  mem[4] = 8'h10;
      //  mem[5] = 8'b1_00_00101; //not r1
      //  mem[6] = 8'b0_01_00_001; //mov r1 to r2
      //  mem[7] = 8'b1_00_01001; //inc r1
      //  mem[8] = 8'b1_01_00001; //r1 & r2
      //  mem[9] = 8'b0_00_00_100; //stb
        //mem[10] = 8'b0_00_00_010; //jmp
        //mem[11] = 8'b1111_1100; //goback 4
        //mem[10] = 8'h0D; //address to stb
        
        
        //mem[9] = 8'b0_00_00_010; //jmp to r1
    end

    Control control(clk, rst, dBusIn, dBusOut, rWMem, pcAddrBus, dataAddrBus, storeAddrBus); //8-bit dataIn, 8-bit dataOut, 16-bit addr.
    
endmodule
