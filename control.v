module Control(input wire clk, input wire reset);

    //read dataOut line from memory for pc instruction(opcode) or for data to act on
    wire [7:0]opcodeIn;
    wire [7:0]dataIn;
    
    reg [7:0]tmpRegIn;
    reg [7:0]tmpRegOut;
   
    wire flag;
    wire eqFlag;
    wire [7:0]acc;
   
    wire [7:0]r1DataOut;
    wire [7:0]r2DataOut;
    wire [7:0]r3DataOut;
    wire [7:0]r4DataOut;
   
    reg r1En;
    reg r2En;
    reg r3En;
    reg r4En;
   
    reg [7:0]pc;
    wire [7:0]memAddrIn;
   
    reg writeMem;
    reg [7:0]memDataInBuffer;
    reg [7:0]memDataOut;
    wire [7:0]dataAtAddr;
    
    reg skipData;
   
    //opperations are performed on r1, and selected opcode reg
    Alu alu(opcodeIn[3:0], r1DataOut, tmpRegOut, acc, flag, eqFlag);
   
    Register r1(tmpRegIn, r1DataOut, r1En);
    Register r2(tmpRegIn, r2DataOut, r2En);
    Register r3(tmpRegIn, r3DataOut, r3En);
    Register r4(tmpRegIn, r4DataOut, r4En);
    
    Mem mem(pc, r1DataOut, r1DataOut, writeMem, memDataInBuffer, opcodeIn, dataIn, dataAtAddr);
   
    always @(posedge reset, posedge clk)
    begin
        if(reset)
        begin
            pc <= 0;
            tmpRegIn <= 0;
            tmpRegOut <= 0;
            r1En <= 1;
            r2En <= 1;
            r3En <= 1;
            r4En <= 1;
            skipData <= 0;
       end

        else if(skipData)
        begin
            pc <= pc + 1;
            skipData <= 0;
        end

        else
        begin
            r1En <= 0;
            r2En <= 0;
            r3En <= 0;
            r4En <= 0;
            writeMem <= 0;
            
            //else jmp
            if(opcodeIn[7] == 0)
            begin
                case(opcodeIn[2:0])
                    3'b000: //nop
                    begin
                        pc <= pc + 1;
                    end
                    
                    3'b001: //mov
                    begin
                        pc <= pc + 1;
                        
                        //from
                        case(opcodeIn[4:3])
                            2'b00:
                                tmpRegIn <= r1DataOut;
                            2'b01:
                                tmpRegIn <= r2DataOut;
                            2'b10:
                                tmpRegIn <= r3DataOut;
                            2'b11:
                                tmpRegIn <= r4DataOut;
                        endcase
                        
                        //to
                        case(opcodeIn[6:5])
                            2'b00:
                                r1En <= 1;
                            2'b01:
                                r2En <= 1;
                            2'b10:
                                r3En <= 1;
                            2'b11:
                                r4En <= 1;
                        endcase
                    end
                        
                    3'b011: //lodsb, read r1 address and load value in (to r1)
                    begin
                        r1En <= 1;
                        tmpRegIn <= dataAtAddr;
                        pc <= pc + 1;
                    end
                    
                    3'b100: //stb (store contents of r2 in mem @ r1 addr)
                    begin
                        pc <= pc + 1;
                        
                        writeMem <= 1;
                        memDataInBuffer <= r2DataOut;
                        
                        skipData <= 1;
                    end
                    
                    3'b101: //mov immediate
                    begin
                        pc <= pc + 1;
                        
                        r1En <= 1;
                        tmpRegIn <= dataIn;
                        
                        skipData <= 1;
                    end
                    
                    default:
                        pc <= pc + 1;
                    
                endcase
            end
            
            else if(opcodeIn[7] == 1)//alu
            begin
                pc <= pc + 1;
                
                tmpRegIn <= acc;
                r1En <= 1;
            end
            
            //finish loading in memory value to R1
        end
    end
    
    always @*
    begin
        if(opcodeIn[7] == 1) //alu
        begin
            case(opcodeIn[6:5])
                2'b00:
                    tmpRegOut = r1DataOut;
                    
                2'b01:
                    tmpRegOut = r2DataOut;
                
                2'b10:
                    tmpRegOut = r3DataOut;
                    
                2'b11:
                    tmpRegOut = r4DataOut;
            endcase
        end
    end
    
endmodule
