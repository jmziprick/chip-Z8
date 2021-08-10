module Control(input wire clk, input wire rst, input wire [15:0]dBusIn, output reg [7:0]dBusOut, output reg rWMem, output wire [15:0]pcAddrBus, output wire [15:0]dataAddrBus, output reg [15:0]storeAddrBus);
    //dBusIn (data bus in) fetch data from RAM
    //dBusOut (data bus out) computed data sent out to RAM
    //addrBus (address bus) controls in and out data from the RAM
    //rWMem (read/write memory) rWMem=1 -> read, rWMem=0 -> write
    //reg storeAddrBus, address to store data to (stb)

    assign pcAddrBus = pc;    //fetch next instruction
    assign dataAddrBus = addressLine; //get data at address
    
    reg disablePc; //disables pc for multi cycle instructions
    reg [1:0]disablePcCounter; //counter for number of cycles to wait for instruction to finish
    reg [15:0]pc; //instruction pointer (program counter)
    reg [15:0]stackPtr; //current stack pointer position
    reg [15:0]addressLine; //get data @ RAM locaton
    
    reg eqFlagLatch;
    reg flagLatch;
    
    wire [7:0]r1DataOut;
    wire [7:0]r2DataOut;
    wire [7:0]r3DataOut;
    wire [7:0]r4DataOut; //reg line
    
    reg [7:0]tmpRegIn; //reg buffer in
    reg [7:0]tmpRegOut; //reg buffer out
    reg r1En, r2En, r3En, r4En; //write to reg
    
    wire flag; //alu flag
    wire eqFlag; //alu eq flag
    wire [7:0]acc; //acc reg (buffer to later send to r1 which is the actual acc)
    
    Alu alu(dBusIn[3:0], r1DataOut, tmpRegOut, acc, flag, eqFlag);
    Register r1(tmpRegIn, r1DataOut, r1En);
    Register r2(tmpRegIn, r2DataOut, r2En);
    Register r3(tmpRegIn, r3DataOut, r3En);
    Register r4(tmpRegIn, r4DataOut, r4En);

    always @(posedge rst, posedge clk)
    begin
        if(rst)
        begin
            pc <= 0;
            stackPtr <= 16'hFFFF; //point to top of memory
            disablePc <= 0;
            disablePcCounter <= 0;
            rWMem <= 0;
            
            eqFlagLatch <= 0;
            flagLatch <= 0;
            
            r1En <= 1;
            r2En <= 1;
            r3En <= 1;
            r4En <= 1;
            tmpRegIn = 8'h00;
        end
    
        else
        begin
            rWMem <= 0;
            r1En <= 0;
            r2En <= 0;
            r3En <= 0;
            r4En <= 0;
        
            if(dBusIn[7] == 0)
            begin
                if(dBusIn[3:0] == 4'b1111) //extended special opcodes
                begin
                    if(dBusIn[4] == 0) //Push
                    begin
                        if(disablePc)
                        begin
                            pc <= pc + 1;
                            disablePc <= 0;
                            stackPtr <= stackPtr - 1;
                            
                            storeAddrBus <= stackPtr;
                            case(dBusIn[6:5]) //reg to push 0_xx_#1_111     xx = r1, r2, r3, r4
                                2'b00:
                                    dBusOut <= r1DataOut;
                                2'b01:
                                    dBusOut <= r2DataOut;
                                2'b10:
                                    dBusOut <= r3DataOut;
                                2'b11:
                                    dBusOut <= r4DataOut;
                            endcase
                        end //of disablePc
                        
                        disablePcCounter <= disablePcCounter + 1;
                        disablePc <= 1;

                        rWMem <= 1;
                    end //of Push
                    
                    else if(dBusIn[4] == 1) //Pop
                    begin
                        if(disablePc)
                        begin
                            pc <= pc + 1;
                            disablePc <= 0;
                            stackPtr <= stackPtr + 1;
                            //addressLine <= stackPtr; //get data off of stack
                            
                            case(dBusIn[6:5]) //reg to pop in
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
                            
                        tmpRegIn <= dBusIn[15:8];
                        disablePc <= 1;
                        disablePcCounter <= disablePcCounter + 1;
                        
                    end //of Pop
                end //of if extended special opcodes
                    
                else if(dBusIn[3:0] == 4'b0111 && dBusIn[6] == 1) //other extended
                begin
                    if(dBusIn[4] == 0) //lodbmem
                    begin
                        if(disablePc)
                        begin
                            pc <= pc + 1;
                            disablePc <= 0;
                            
                                case(dBusIn[5]) //reg to load to
                                1'b0:
                                    r1En <= 1;
                                1'b1:
                                    r2En <= 1;
                            endcase
                        end
                        
                        disablePc <= 1;
                        disablePcCounter <= disablePcCounter + 1;
                        tmpRegIn <= dBusIn[15:8];
                    end
                    
                    //else(dBusIn[4] == 1)
                    //begin
                    
                    //end
                end
                    
                    //int, runs when int line high or soft int activated
                    //hardware int read int line input bits for type of int
                    //software int read byte stored in r1
                    //push all reg, including pc
                    //goto int routine
                    //restore and pop pc and regs off stack
                    //resume task
                    
                    //3'b110: //far jmp, 2 cpu cycles
                    //begin
                    //    disablePc <= 1;
                    //    disablePcCounter <= disablePcCounter + 1;
                        
                        //get high and low byte for jmp
                        
                    //    if(disablePcCounter > 1)
                    //    begin
                    //        disablePc <= 0;
                    //        disablePcCounter <= 0;
                            //pc <= {highDBusIn + lowDBusIn}
                    //    end
                    //end
                //endcase
                
                
                
                
            
                else //regular opcodes
                begin
                    case(dBusIn[2:0])
                        3'b000: //nop, 1 cpu cycle
                        begin
                            pc <= pc + 1;
                        end
                        
                        3'b001: //mov, 1 cpu cycle
                        begin
                            //from
                            case(dBusIn[4:3])
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
                            case(dBusIn[6:5])
                                2'b00:
                                    r1En <= 1;
                                2'b01:
                                    r2En <= 1;
                                2'b10:
                                    r3En <= 1;
                                2'b11:
                                    r4En <= 1;
                            endcase
                        
                            pc <= pc + 1;
                        end
                        
                        3'b010: //jmp to address, 2 cpu cycls (jmp)
                        begin
                            //add two's compl. of how far to jmp back or forward
                            //pc + - goto = new PC location
                            if(disablePc == 0)
                            begin
                                pc <= pc + {{8'hFF}, {dBusIn[15:8]}}; //sign extend 2's comp. 8-bit jmp
                                disablePc <= 0;
                            end
                            
                            disablePc <= 1;
                            disablePcCounter <= disablePcCounter + 1;
                            //addressLine <= pc + 1;
                        end
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                        
                        //ADD CHOICE OF REGISTER TO LOAD IMM. VALUES INTO FOR LODB
                        //LIKE LODBMEM
                        
                        3'b011: //lodb, 2 cpu cycles (lodb $)
                        begin
                            if(disablePc)
                            begin
                                pc <= pc + 2;
                                disablePc <= 0;
                            end
                            
                                case(dBusIn[4:3])
                                    2'b00:
                                        r1En <= 1;
                                    2'b01:
                                        r2En <= 1;
                                    2'b10:
                                        r3En <= 1;
                                    2'b11:
                                        r4En <= 1;
                                endcase
                                
                            disablePc <= 1;
                            disablePcCounter <= disablePcCounter + 1;
                            addressLine <= pc + 1; //get data @ next address
                            tmpRegIn <= dBusIn[15:8];
                        end
                        
                        
                        
                        
                        
                        
                        
                        //--------------------------
                        //add a lodb and stb to address 16 bit locations
                        //by adding a r1+r2 => 16 bit addr
                        //--------------------------
                        
                        3'b100: //stb, 2 cpu cycles (stb regAddr, regData)
                        begin
                            if(disablePc)
                            begin
                                pc <= pc + 1;
                                disablePc <= 0;
                                
                                case(dBusIn[6:5]) //address to store
                                    2'b00:
                                        storeAddrBus <= r1DataOut;
                                    2'b01:
                                        storeAddrBus <= r2DataOut;
                                    2'b10:
                                        storeAddrBus <= r3DataOut;
                                    2'b11:
                                        storeAddrBus <= r4DataOut;
                                endcase
                                
                                case(dBusIn[4:3]) //data to store
                                    2'b00:
                                        dBusOut <= r1DataOut;
                                    2'b01:
                                        dBusOut <= r2DataOut;
                                    2'b10:
                                        dBusOut <= r3DataOut;
                                    2'b11:
                                        dBusOut <= r4DataOut;
                                endcase
                            end //of disablePc
                            
                            disablePcCounter <= disablePcCounter + 1;
                            disablePc <= 1;

                            rWMem <= 1;
                            //pc <= pc + 1;
                        end //of stb
                        
                        3'b101: //bne, 2 cpu cycles
                        begin
                            if(eqFlagLatch == 0)
                            begin
                                if(disablePcCounter >= 1)
                                begin
                                    disablePc <= 0;
                                    pc <= dBusIn[15:8];
                                    eqFlagLatch <= 0;
                                end
                                
                                disablePc <= 1;
                                disablePcCounter <= disablePcCounter + 1;
                                addressLine <= pc + 1;
                            end
                            
                            else //if they are equal then go to next opcode, which is 2 bytes
                                pc <= pc + 2;
                        end //of bne
                        
                        3'b110: //beq, 2 cpu cycles
                        begin
                            if(eqFlagLatch)
                            begin
                                if(disablePcCounter >= 1)
                                begin
                                    disablePc <= 0;
                                    pc <= dBusIn[15:8];
                                    eqFlagLatch <= 0;
                                end
                                
                                disablePc <= 1;
                                disablePcCounter <= disablePcCounter + 1;
                                addressLine <= pc + 1;
                            end
                            
                            else
                                pc <= pc + 2; //if they aren't equal go to next opcode, which is 2 bytes (see previous)
                        end //of beq
                        
                        
                        3'b111: //bgr, 2 cpu cycles (branch on r1 greater than
                        begin
                            if(flagLatch)
                            begin
                                if(disablePcCounter >= 1)
                                begin
                                    disablePc <= 0;
                                    pc <= dBusIn[15:8];
                                    flagLatch <= 0;
                                end
                                
                                disablePc <= 1;
                                disablePcCounter <= disablePcCounter + 1;
                                addressLine <= pc + 1;
                            end
                            
                            else
                                pc <= pc + 2; //if they aren't equal go to next opcode, which is 2 bytes (see previous)
                        end //of bgr
                    endcase //of case opcodes
                end //of else if regular opcodes
            end //of dBusIn[7] == 0
            
            else if(dBusIn[7] == 1) //alu  ??????? IS ALU 2 INSTRUCTION CYCLES????????
            begin
                pc <= pc + 1;
                tmpRegIn <= acc;
                
                if(dBusIn[3:0] == 4'b0100) //cmp instruction, so don't copy data into r1
                begin
                    r1En <= 0;
                end
                
                else
                begin
                    r1En <= 1;
                end
                
                
                
                //if(disablePc)
                //begin
                  //  disablePcCounter <= 0;
                   // pc <= pc + 1;
                //end
                
                //disablePc <= 1;
                //disablePcCounter <= disablePcCounter + 1;
                
                
            end //of dBusIn[7] == 1
            
            
        end
    end
    
    always @*
    begin
        if(eqFlag)
            eqFlagLatch = 1;
            
        if(flag)
            flagLatch = 1;
    
        //if(dBusIn[7] == 0 && dBusIn[2:0] == 3'b100) //stb
        //begin
          //  if(disablePcCounter > 1)
           // begin
             //   case(dBusIn[6:5])
               //     2'b00:
                 //       addressLine = {{8'h00}, r1DataOut};
                  //  2'b01:
                    //    addressLine = {{8'h00}, r2DataOut};
                   // 2'b10:
                     //   addressLine = {{8'h00}, r3DataOut};
                    //2'b11:
                      //  addressLine = {{8'h00}, r4DataOut};
                //endcase
            //end
        //end
            
        //else
        
        if(dBusIn[4:0] == 5'b1_1111) //pop opcode (special case)
            addressLine <= stackPtr + 1; //get data off of stack
        else if(dBusIn[4:0] == 5'b0_0111 && dBusIn[6] == 1) //lodbmem (special case))
            addressLine <= {r1DataOut, r2DataOut}; //get data @ next address
        else
            addressLine <= pc + 1; //otherwise fetch data at next address (general opcodes)
        
        if(disablePcCounter >= 2)
        begin
            disablePcCounter = 0;
            disablePc = 0;
        end
        
        if(dBusIn[7] == 1) //alu, connects registers to ALU input to be selectable
        begin

            
            case(dBusIn[6:5])
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
