`default_nettype none

module Control(input wire clk, 
input wire rstIn, 
output wire [23:0]pcOut, 
input wire [7:0]instruction, 
output wire [23:0]addressLinesOut, 
output reg [1:0]memReadWrite, 
output reg [7:0]toDataBus, 
input wire [3:0]hardInterrupt, 
input wire memException);

	localparam DEFAULT_STACK_TOP_ADDRESS = 16'd3000; //after port out space
	
	localparam [1:0]
		ADDR_MODE_RD = 2'b00,  //00 reads address lines (reading 'random' locations)
		ADDR_MODE_PC = 2'b01,  //01 reads address at pc
		ADDR_MODE_WRT = 2'b10; //10 writes to address lines

	reg [7:0]instructionBuffer;
	
	assign pcOut = pc;
	reg halt;
	reg [24:0]nextPcBuffer; //hold the next pc address to go to, allows holding of pc value for multiple cycle instructions
	reg [24:0]addressOutBuffer; //hold an address position to access, same as above allows multi cycle instructions to build buffer

	reg disablePc; //stops PC when an instruction is not finished
	reg [3:0]holdPcCnt; //cycles to hold PC

	//-------------------------------MEMORY----------------------------------
	reg [23:0]addressLines;
	assign addressLinesOut = addressLines;

	//reg memWrite;
	//assign memWriteOut;
	//-----------------------------------------------------------------------

	//-------------------------------INTERRUPTS-------------------------------
    //0 no interrupt
    //1 non valid instruction
    //2 div by 0
    //3 general system fault
    //4 memory exception

	reg [23:0]iRetAddress;
	wire activeIrq;
	assign activeIrq = (hardInterrupt | interrupt) ? 1'b1 : 1'b0;
	reg [3:0]interrupt; //internal hard int (e.g. illegal instructions, div by zero etc)
	reg interruptRunning;
	reg [23:0]interruptBufferQueue; //saves int type, and number
	reg [23:0]currentInterruptVecAddr;
	reg [24:0]intNextPcBuffer;
	reg disableInt;
	
	//int. vec. table - copied into ram
    //byte 0-3 address, byte 4 priority, byte 5 reserved, byte 6 reserved, byte 7 reserved (8 bytes total)
	reg [7:0] interruptPriorityBuffer; //holds priority level
	reg [7:0] currentIntPriority; //holds active int priority

	//external hardware int pointers
	parameter IRQ_1_ADDR = 24'd2000;
	parameter IRQ_2_ADDR = 24'd2008;
	parameter IRQ_3_ADDR = 24'd2016;
	parameter IRQ_4_ADDR = 24'd2024;
	parameter IRQ_5_ADDR = 24'd2032;
	parameter IRQ_6_ADDR = 24'd2040;
	parameter IRQ_7_ADDR = 24'd2048;
	parameter IRQ_8_ADDR = 24'd2056;
	parameter IRQ_9_ADDR = 24'd2064;
	parameter IRQ_10_ADDR = 24'd2072;
	parameter IRQ_11_ADDR = 24'd2080;
	parameter IRQ_12_ADDR = 24'd2088;
	parameter IRQ_13_ADDR = 24'd2096;
	parameter IRQ_14_ADDR = 24'd2104;
	parameter IRQ_15_ADDR = 24'd2112;

	//internal exception int pointers
	parameter INT_1_ADDR = 24'd2120;
	parameter INT_2_ADDR = 24'd2128;
	parameter INT_3_ADDR = 24'd2136;
	parameter INT_4_ADDR = 24'd2144;
	parameter INT_5_ADDR = 24'd2152;
	parameter INT_6_ADDR = 24'd2160;
	parameter INT_7_ADDR = 24'd2168;
	parameter INT_8_ADDR = 24'd2176;
	parameter INT_9_ADDR = 24'd2184;
	parameter INT_10_ADDR = 24'd2192;
	parameter INT_11_ADDR = 24'd2200;
	parameter INT_12_ADDR = 24'd2208;
	parameter INT_13_ADDR = 24'd2216;
	parameter INT_14_ADDR = 24'd2224;
	parameter INT_15_ADDR = 24'd2232;
	
	//software int call pointers
	parameter SOFT_INT_16_ADDR = 24'd2240;
	parameter SOFT_INT_17_ADDR = 24'd2248;
	parameter SOFT_INT_18_ADDR = 24'd2256;
	parameter SOFT_INT_19_ADDR = 24'd2264;
	parameter SOFT_INT_20_ADDR = 24'd2272;
	parameter SOFT_INT_21_ADDR = 24'd2280;
	parameter SOFT_INT_22_ADDR = 24'd2288;

	//parameter EXCEPTION_HNDLR = 24'd2112;
	//-----------------------------------------------------------------------

	//-------------------------------REGISTERS-------------------------------
	reg r1En, r2En, r3En, r4En; //enables writing data to registers
	//reg spEn;
	reg flag; //flag for alu zero and cmp reg1 >
	reg eqFlag; //flag for alu equal
	reg [7:0]flagBuffer; //holds flags after restoring state of CPU after a call or int.
	
	reg [23:0]pc;
	
	//bus connecting data into registers
	reg [7:0]regDataBusIn;
	reg [7:0]spDataBusIn;
	wire eqFlagBus;
	wire flagBus;
	wire divZero;
	
	//bus connecting data out of registers
	wire [7:0]r1DataBusOut;
	wire [7:0]r2DataBusOut;
	wire [7:0]r3DataBusOut;
	wire [7:0]r4DataBusOut;
	
	reg [7:0]regSwapBuffer;
	
	//declare registers
	Register r1(.clk(clk), .rst(rst), .dataIn(regDataBusIn), .dataOut(r1DataBusOut), .en(r1En));
	Register r2(.clk(clk), .rst(rst), .dataIn(regDataBusIn), .dataOut(r2DataBusOut), .en(r2En));
	Register r3(.clk(clk), .rst(rst), .dataIn(regDataBusIn), .dataOut(r3DataBusOut), .en(r3En));
	Register r4(.clk(clk), .rst(rst), .dataIn(regDataBusIn), .dataOut(r4DataBusOut), .en(r4En));
	
	reg [23:0]indexRegister;
	reg [23:0]destinationRegister;
	
	reg [23:0]stackTopReg;
	reg [23:0]stackPointer;

	wire [7:0]aluToAccum;
	reg [7:0]aluReg;
	reg [7:0]aluOpcode;
	//-----------------------------------------------------------------------

	//			opcode				r1->ALU			r2->ALU		 ALU->accumulator		flag	flag
	Alu alu(aluOpcode[3:0], r1DataBusOut, aluReg, aluToAccum, flagBus, eqFlagBus, divZero);
	//IO io(.pc(pc), .instruction(instruction), .addressLinesIn(addressLines), .memWrite(memWrite), .dataBusIn(toDataBus), .dataBusOut(fromDataBus));
	
	reg rstInstruction;
	wire rst;
	assign rst = rstIn | rstInstruction;

	always @(posedge clk)
	begin
		if(rst)
		begin
			rstInstruction <= 0;
			r1En <= 0;
			r2En <= 0;
			r3En <= 0;
			r4En <= 0;
			
			stackTopReg <= DEFAULT_STACK_TOP_ADDRESS;

			aluOpcode <= 0;
			aluReg <= 0;
			eqFlag <= 0;
			flag <= 0;
			//aluTmpReg <= 0;
			
			destinationRegister <= 0;
			indexRegister <= 0;
			stackPointer <= DEFAULT_STACK_TOP_ADDRESS;
			memReadWrite <= ADDR_MODE_RD; //default mode read next PC pointer
			addressLines <= 0;

			instructionBuffer <= 0;
			halt <= 0;
			pc <= 0;
			disablePc <= 0;
			holdPcCnt <= 0;
			nextPcBuffer <= 0;
			toDataBus <= 0;
			
			currentIntPriority <= 0;
			interruptBufferQueue <= 0;
			interruptRunning <= 0;
			interrupt <= 0;
			disableInt <= 0;
			iRetAddress <= 0;
		end
	
		else //clock edge
		begin
			if(halt == 1'b0)
			begin
				/*By setting disablePc adds an extra clock cycle to instructions,
				*adding to holdPcCnt adds additional cycles to an instruction
				*/
				if(disablePc == 1) //PC disabled
				begin
					if(holdPcCnt > 0)
						holdPcCnt <= holdPcCnt - 1;
				
					else
					begin
						disablePc <= 0;
						pc <= nextPcBuffer;
                        memReadWrite <= ADDR_MODE_PC;
                        addressLines <= nextPcBuffer;
					end
					
					//Handle multi-cycle instructions
					if(instructionBuffer[7] == 1'b1) //ALU
					begin
						eqFlag <= eqFlagBus;
						flag <= flagBus;
					
						//if(holdPcCnt)
						//begin

						//end

						if(holdPcCnt == 0)
						begin
							r1En <= 0;
						end

						if(instructionBuffer == 8'b1000_0000  //OR
						|| instructionBuffer == 8'b1000_0001  //AND
						|| instructionBuffer == 8'b1000_0100  //CMP
						|| instructionBuffer == 8'b1000_0110  //XOR
						|| instructionBuffer == 8'b1000_0111  //ADD
						|| instructionBuffer == 8'b1000_1000) //SUB
						begin
							if(holdPcCnt == 1)
							begin
								case(instruction[1:0])			
									2'b00:
										aluReg <= r1DataBusOut;
										
									2'b01:
										aluReg <= r2DataBusOut;
										
									2'b10:
										aluReg <= r3DataBusOut;
										
									2'b11:
										aluReg <= r4DataBusOut;
								endcase

								regDataBusIn <= aluToAccum;
								r1En <= 1;
							end
						end

						else if(instructionBuffer == 8'b1000_0010  //SHL
							 || instructionBuffer == 8'b1000_0011  //SHR
							 || instructionBuffer == 8'b1000_0101  //NOT
							 || instructionBuffer == 8'b1000_1001  //INC
							 || instructionBuffer == 8'b1000_1010  //DEC
							 || instructionBuffer == 8'b1000_1011  //ROL
							 || instructionBuffer == 8'b1000_1100) //ROR
						begin
							regDataBusIn <= aluToAccum;
							r1En <= 1;
						end
					end

					else if(instructionBuffer[7:0] == 8'b0000_0001) //MOV
					begin
                        if(holdPcCnt == 2)
                        begin
								//data being stored into
								case(instruction[3:2])			
									2'b00:
										r1En <= 1;
										
									2'b01:
										r2En <= 1;
										
									2'b10:
										r3En <= 1;
										
									2'b11:
										r4En <= 1;
								endcase
								
								//data coming from
								case(instruction[1:0])
									2'b00:
										regDataBusIn <= r1DataBusOut;
										
									2'b01:
										regDataBusIn <= r2DataBusOut;
										
									2'b10:
										regDataBusIn <= r3DataBusOut;
										
									2'b11:
										regDataBusIn <= r4DataBusOut;
								endcase
                        end

                        else if(holdPcCnt == 0)
                        begin
                            r1En <= 0;
                            r2En <= 0;
                            r3En <= 0;
                            r4En <= 0;
                        end
					end

					else if(instructionBuffer[7:0] == 8'b0000_0010) //LODSB
					begin					
						if(holdPcCnt == 2)
						begin
							r1En <= 1;
							regDataBusIn <= instruction;
						end

						else if(holdPcCnt == 0)
						begin
							r1En <= 0;
							indexRegister <= indexRegister + 1;
						end
					end

					else if(instructionBuffer[7:0] == 8'b0000_0011) //LOD (immediate values)		
					begin										
						if(holdPcCnt == 2)
						begin
							regDataBusIn <= instruction;
							case(instructionBuffer[4:3])
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
						
						else if(holdPcCnt == 0)
						begin
							r1En <= 0;
							r2En <= 0;
							r3En <= 0;
							r4En <= 0;			
						end
					end

                    else if(instructionBuffer[7:0] == 8'b0000_0100) //STB
                    begin
						if(holdPcCnt == 4) //LSB
						begin
                            addressLines <= pc + 2;
                            addressOutBuffer <= {16'h0000, instruction};
						end
						
						else if(holdPcCnt == 3)
						begin
                            addressLines <= pc + 3;
                            addressOutBuffer <= {8'h00, instruction, addressOutBuffer[7:0]};
						end

						else if(holdPcCnt == 2)
						begin
                            addressOutBuffer <= {instruction, addressOutBuffer[15:0]};
						end

                        else if(holdPcCnt == 1)
                        begin
                            addressLines <= addressOutBuffer;
                            memReadWrite <= ADDR_MODE_WRT;
							toDataBus <= r1DataBusOut;
                        end
                    end

					else if(instructionBuffer[7:0] == 8'b0000_0101) //BNE
					begin									
						if(holdPcCnt == 3)
						begin
							addressLines <= pc + 2;
							addressOutBuffer <= {16'h0000, instruction};
						end
					
						else if(holdPcCnt == 2)
						begin
							addressLines <= pc + 3;
							addressOutBuffer <= {8'h00, instruction, addressOutBuffer[7:0]};
						end

						else if(holdPcCnt == 1)
						begin
							addressOutBuffer <= {instruction, addressOutBuffer[15:0]};
							nextPcBuffer <= {instruction, addressOutBuffer[15:0]};
						end
					end

					else if(instructionBuffer[7:0] == 8'b0000_0110) //BEQ
					begin									
						if(holdPcCnt == 3)
						begin
							addressLines <= pc + 2;
							addressOutBuffer <= {16'h0000, instruction};
						end
					
						else if(holdPcCnt == 2)
						begin
							addressLines <= pc + 3;
							addressOutBuffer <= {8'h00, instruction, addressOutBuffer[7:0]};
						end

						else if(holdPcCnt == 1)
						begin
							addressOutBuffer <= {instruction, addressOutBuffer[15:0]};
							nextPcBuffer <= {instruction, addressOutBuffer[15:0]};
						end
					end

					else if(instructionBuffer[7:0] == 8'b0000_0111) //BGR
					begin									
						if(holdPcCnt == 3)
						begin
							addressLines <= pc + 2;
							addressOutBuffer <= {16'h0000, instruction};
						end
					
						else if(holdPcCnt == 2)
						begin
							addressLines <= pc + 3;
							addressOutBuffer <= {8'h00, instruction, addressOutBuffer[7:0]};
						end

						else if(holdPcCnt == 1)
						begin
							addressOutBuffer <= {instruction, addressOutBuffer[15:0]};
							nextPcBuffer <= {instruction, addressOutBuffer[15:0]};
						end
					end

					else if(instructionBuffer[7:0] == 8'b0000_1111) //PUSH
					begin
						if(holdPcCnt == 1)
						begin
								addressLines <= stackPointer;
								memReadWrite <= ADDR_MODE_WRT;

								if(instruction[1:0] == 2'b00)
									toDataBus <= r1DataBusOut;

								else if(instruction[1:0] == 2'b01)
									toDataBus <= r2DataBusOut;

								else if(instruction[1:0] == 2'b10)
									toDataBus <= r3DataBusOut;

								else if(instruction[1:0] == 2'b11)
									toDataBus <= r4DataBusOut;	
						end

						else if(holdPcCnt == 0)
						begin
							stackPointer <= stackPointer - 1;
						end
					end

					else if(instructionBuffer[7:0] == 8'b0001_1111) //POP
					begin
						if(holdPcCnt == 2)
						begin
							addressLines <= stackPointer;

							if(instruction[1:0] == 2'b00)
								r1En <= 1;

							else if(instruction[1:0] == 2'b01)
								r2En <= 1;

							else if(instruction[1:0] == 2'b10)
								r3En <= 1;

							else if(instruction[1:0] == 2'b11)
								r4En <= 1;
						end
							
						else if(holdPcCnt == 1)
						begin
							regDataBusIn <= instruction;
						end
					end

					else if(instructionBuffer[7:0] == 8'b0100_0111) //LDM
					begin
						if(holdPcCnt == 5)
						begin
							addressLines <= pc + 2;
							addressOutBuffer <= {16'h0000, instruction};
						end
					
						else if(holdPcCnt == 4)
						begin
							addressLines <= pc + 3;
							addressOutBuffer <= {8'h00, instruction, addressOutBuffer[7:0]};
						end

						else if(holdPcCnt == 3)
						begin
							addressOutBuffer <= {instruction, addressOutBuffer[15:0]};
						end

						else if(holdPcCnt == 2)
						begin
							addressLines <= addressOutBuffer;
						end
						
						else if(holdPcCnt == 1)
						begin
							regDataBusIn <= instruction;
							r1En <= 1;
						end

						else if(holdPcCnt == 0)
						begin
						end
					end

					else if(instructionBuffer[7:0] == 8'b0000_1000) //SOFTWARE INT
					begin
						if(holdPcCnt == 11)
						begin
							case(instruction)
								8'h00:
									addressLines <= SOFT_INT_16_ADDR - 8;

								8'h01:
									addressLines <= SOFT_INT_17_ADDR - 8;
									
								8'b010:
									addressLines <= SOFT_INT_18_ADDR - 8;
									
								8'b011:
									addressLines <= SOFT_INT_19_ADDR - 8;	
									
								8'b100:
									addressLines <= SOFT_INT_20_ADDR - 8;
									
								8'b101:
									addressLines <= SOFT_INT_21_ADDR - 8;
									
								8'b110:
									addressLines <= SOFT_INT_22_ADDR - 8;		
							endcase
						end

						else if(holdPcCnt == 10)
						begin
							addressLines <= addressLines + 1;
							nextPcBuffer <= {16'h0000, instruction};
						end

						else if(holdPcCnt == 9)
						begin
							addressLines <= addressLines + 1;
							nextPcBuffer <= {8'h00, instruction, nextPcBuffer[7:0]};
						end
					
						else if(holdPcCnt == 8)
						begin
							addressLines <= addressLines + 1;
							nextPcBuffer <= {instruction, nextPcBuffer[15:0]};
						end

						else if(holdPcCnt == 7)
						begin
							interruptPriorityBuffer <= instruction; //save priority
						end

                        else if(holdPcCnt == 6)
                        begin
                            flagBuffer <= {{6'b000000}, flag, eqFlag}; //save current flag state
                            memReadWrite <= ADDR_MODE_WRT;
                            addressLines <= stackPointer;
                        end

						                        //push flag states to stack
                        else if(holdPcCnt == 5)
                        begin
                            toDataBus <= flagBuffer;
                            stackPointer <= stackPointer - 1;
                        end
							//push flag states to stack
						//	addressLines <= stackPointer;
						//	memReadWrite <= ADDR_MODE_WRT;
						//	stackPointer <= stackPointer - 1;
						//	toDataBus <= flagBuffer;
						//end

                        //push int priority level to stack
                        else if(holdPcCnt == 4)
                        begin
                            toDataBus <= interruptPriorityBuffer;
                            stackPointer <= stackPointer - 1;
                            intNextPcBuffer <= iRetAddress; //save current running int. PC (if there is one running)
                        end

                        //push iret to stack
                        else if(holdPcCnt == 3)
                        begin
                            addressLines <= stackPointer;
                            stackPointer <= stackPointer - 1;
                            toDataBus <= iRetAddress[23:16];
                        end

                        else if(holdPcCnt == 2)
                        begin
                            addressLines <= stackPointer;
                            stackPointer <= stackPointer - 1;
                            toDataBus <= iRetAddress[15:8];
                        end

                        else if(holdPcCnt == 1)
                        begin
                            addressLines <= stackPointer;
                            stackPointer <= stackPointer - 1;
                            toDataBus <= iRetAddress[7:0];

                            //no active int
                            if(currentIntPriority == 0)
                            begin
                                interruptBufferQueue <= 0;
                                currentIntPriority <= interruptPriorityBuffer;
                            end

                            else
                            begin
                                if(interruptPriorityBuffer > currentIntPriority)
                                begin
                                    currentIntPriority <= interruptPriorityBuffer;
                                end
                                
                                else //this new int. has a lower or equal priority so save it for later
                                begin
                                    stackPointer <= stackPointer + 4;
                                    interruptBufferQueue <= currentInterruptVecAddr; //save this int. execution to buffer
                                    nextPcBuffer <= intNextPcBuffer; //set pc back to previous running int.
                                end
                            end
						end

						else if(holdPcCnt == 0)
						begin
						end
					end
	
					else if(instructionBuffer[7:0] == 8'b0111_1000) //IRET
					begin
						//pop address
						if(holdPcCnt == 5)
						begin
							addressLines <= stackPointer;
							stackPointer <= stackPointer + 1;
						end

						if(holdPcCnt == 4)
						begin
							addressLines <= stackPointer;
							stackPointer <= stackPointer + 1;
							nextPcBuffer <= {16'h0000, instruction};
						end

						else if(holdPcCnt == 3)
						begin
							addressLines <= stackPointer;
							stackPointer <= stackPointer + 1;
							nextPcBuffer <= {8'h00, instruction, nextPcBuffer[7:0]};
						end
					
						else if(holdPcCnt == 2)
						begin
							nextPcBuffer <= {instruction, nextPcBuffer[15:0]};
							stackPointer <= stackPointer + 1; //pop int priority from stack
						end

						else if(holdPcCnt == 1)
						begin
							addressLines <= stackPointer;
						end

						else if(holdPcCnt == 0)
						begin
							//recover flags
							flag <= instruction[1];
							eqFlag <= instruction[0];
							interruptRunning <= 0;
							currentIntPriority <= 0;
						end
					end

					else if(instructionBuffer[7:0] == 8'b0000_1010) //PUSHA
					begin
						if(holdPcCnt == 7)
						begin
							toDataBus <= r1DataBusOut;
						end

						else if(holdPcCnt == 6)
						begin
							stackPointer <= stackPointer - 1;
						end

						else if(holdPcCnt == 5)
						begin
							addressLines <= stackPointer;
							toDataBus <= r2DataBusOut;
						end

						else if(holdPcCnt == 4)
						begin
							stackPointer <= stackPointer - 1;
						end

						else if(holdPcCnt == 3)
						begin
							addressLines <= stackPointer;
							toDataBus <= r3DataBusOut;
						end

						else if(holdPcCnt == 2)
						begin
							stackPointer <= stackPointer - 1;
						end

						else if(holdPcCnt == 1)
						begin
							addressLines <= stackPointer;
							toDataBus <= r4DataBusOut;
						end

						else if(holdPcCnt == 0)
						begin
							stackPointer <= stackPointer - 1;
						end
					end

					else if(instructionBuffer[7:0] == 8'b0000_1011) //POPA
					begin
						if(holdPcCnt == 8)
						begin
							addressLines <= stackPointer;
						end

						else if(holdPcCnt == 7)
						begin
							regDataBusIn <= instruction;
							r4En <= 1;
							stackPointer <= stackPointer + 1;
						end

						else if(holdPcCnt == 6)
						begin
							r4En <= 0;
							addressLines <= stackPointer;
						end

						else if(holdPcCnt == 5)
						begin
							regDataBusIn <= instruction;
							r3En <= 1;
							stackPointer <= stackPointer + 1;
						end

						else if(holdPcCnt == 4)
						begin
							r3En <= 0;
							addressLines <= stackPointer;
						end

						else if(holdPcCnt == 3)
						begin
							regDataBusIn <= instruction;
							r2En <= 1;
							stackPointer <= stackPointer + 1;
						end

						else if(holdPcCnt == 2)
						begin
							r2En <= 0;
							addressLines <= stackPointer;
						end

						else if(holdPcCnt == 1)
						begin
							regDataBusIn <= instruction;
							r1En <= 1;
						end

						else if(holdPcCnt == 0) //r1 disabled by default at holdPcCnt 0
						begin
						end
					end

					else if(instructionBuffer == 8'b0010_1000) //CALL
					begin
						if(holdPcCnt == 6)
						begin
							addressLines <= pc + 2;
							nextPcBuffer <= {16'h00, instruction};
						end
					
						else if(holdPcCnt == 5)
						begin
							addressLines <= pc + 3;
							nextPcBuffer <= {8'h00, instruction, nextPcBuffer[7:0]}; //call jump to address
						end

						else if(holdPcCnt == 4)
						begin
							nextPcBuffer <= {instruction, nextPcBuffer[15:0]};
							addressLines <= stackPointer;
							memReadWrite <= ADDR_MODE_WRT;
						end

 						//push return address
						else if(holdPcCnt == 3)
						begin
							//addressLines <= stackPointer;
							stackPointer <= stackPointer - 1;
							toDataBus <= iRetAddress[23:16];
						end

						else if(holdPcCnt == 2)
						begin
							addressLines <= stackPointer;
							stackPointer <= stackPointer - 1;
							toDataBus <= iRetAddress[15:8];
						end

						else if(holdPcCnt == 1)
						begin
							addressLines <= stackPointer;
							stackPointer <= stackPointer - 1;
							toDataBus <= iRetAddress[7:0];
						end

						else if(holdPcCnt == 0)
						begin
						end
					end

					else if(instructionBuffer == 8'b0010_0110) //RTS
					begin
						if(holdPcCnt == 6)
						begin						
							addressLines <= stackPointer;
						end

						else if(holdPcCnt == 5)
						begin
							stackPointer <= stackPointer + 1;	
							nextPcBuffer <= {16'h00, instruction};
						end
						
						else if(holdPcCnt == 4)
						begin
							addressLines <= stackPointer;
						end
						
						else if(holdPcCnt == 3)
						begin
							nextPcBuffer <= {8'h00, instruction, nextPcBuffer[7:0]};
							stackPointer <= stackPointer + 1;
						end
					
						if(holdPcCnt == 2)
						begin
							addressLines <= stackPointer;
						end

						else if(holdPcCnt == 1)
						begin
							nextPcBuffer <= {instruction, nextPcBuffer[15:0]};
							addressLines <= stackPointer;
						end

						else if(holdPcCnt == 0)
						begin
						end
					end

					else if(instructionBuffer == 8'b0100_1000) //BRA
					begin
						if(holdPcCnt == 3)
						begin
							addressLines <= pc + 2;
							addressOutBuffer <= {16'h0000, instruction};
						end
					
						else if(holdPcCnt == 2)
						begin
							addressLines <= pc + 3;
							addressOutBuffer <= {8'h00, instruction, addressOutBuffer[7:0]};
						end

						else if(holdPcCnt == 1)
						begin
							addressOutBuffer <= {instruction, addressOutBuffer[15:0]};
							nextPcBuffer <= {instruction, addressOutBuffer[15:0]};
						end
					end

					else if(instructionBuffer == 8'b0110_0000) //BRZ
					begin									
						if(holdPcCnt == 3)
						begin
							addressLines <= pc + 2;
							addressOutBuffer <= {16'h0000, instruction};
						end
					
						else if(holdPcCnt == 2)
						begin
							addressLines <= pc + 3;
							addressOutBuffer <= {8'h00, instruction, addressOutBuffer[7:0]};
						end

						else if(holdPcCnt == 1)
						begin
							addressOutBuffer <= {instruction, addressOutBuffer[15:0]};
							nextPcBuffer <= {instruction, addressOutBuffer[15:0]};
						end
					end

					else if(instructionBuffer == 8'b0111_0000) //SPIR (set pointer index)
					begin
						if(holdPcCnt == 3)
						begin
							indexRegister <= {16'h00, instruction};
                            addressLines <= pc + 2;
						end
						
						else if(holdPcCnt == 2)
						begin
							indexRegister <= {8'h00, instruction, indexRegister[7:0]};
							addressLines <= pc + 3;
						end

						else if(holdPcCnt == 1)
						begin
							indexRegister <= {instruction, indexRegister[15:0]};
						end						
					end

					else if(instructionBuffer == 8'b0111_0010) //SBP
					begin
						if(holdPcCnt == 2)
						begin
							addressLines <= pc + 2;
							stackTopReg <= {16'h00, instruction};
						end
						
						else if(holdPcCnt == 1)
						begin
							addressLines <= pc + 3;
							stackTopReg <= {8'h00, instruction, stackTopReg[7:0]};
						end

						else if(holdPcCnt == 0)
						begin
							stackTopReg <= {instruction, stackTopReg[15:0]};
						end
					end

					else if(instructionBuffer == 8'b0011_0010) //STOSB
					begin 
						if(holdPcCnt == 2)
						begin
							addressLines <= destinationRegister;
							toDataBus <= r1DataBusOut;
							memReadWrite <= ADDR_MODE_WRT;
						end

						else if(holdPcCnt == 0)
						begin
							destinationRegister <= destinationRegister + 1;
						end
					end

					else if(instructionBuffer == 8'b0011_0011) //SPDR
					begin
						if(holdPcCnt == 3)
						begin
							destinationRegister <= {16'h00, instruction};
							addressLines <= pc + 2;
						end

						else if(holdPcCnt == 2)
						begin
							destinationRegister <= {8'h00, instruction, destinationRegister[7:0]};
							addressLines <= pc + 3;
						end

						else if(holdPcCnt == 1)
						begin
							destinationRegister <= {instruction, destinationRegister[15:0]};
						end

						else if(holdPcCnt == 0)
						begin
						end
					end

					else if(instructionBuffer == 8'b0111_0011)//XCHG
					begin
						if(holdPcCnt == 4)
						begin
							case(instruction[1:0])
							2'b00:
								regSwapBuffer <= r1DataBusOut;
								
							2'b01:
								regSwapBuffer <= r2DataBusOut;
								
							2'b10:
								regSwapBuffer <= r3DataBusOut;

							2'b11:
								regSwapBuffer <= r4DataBusOut;										
							endcase
						end

						else if(holdPcCnt == 3)
						begin
							regDataBusIn <= r1DataBusOut;
							case(instruction[1:0])
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

						else if(holdPcCnt == 2)
						begin
							 r1En <= 0;
							 r2En <= 0;
							 r3En <= 0;
							 r4En <= 0;
						end

						else if(holdPcCnt == 1) //copy other reg to r1
						begin
							 regDataBusIn <= regSwapBuffer;
							 r1En <= 1;
						end
					end

                    else if(instructionBuffer == 8'b0111_1111) //HARDWARE INT
                    begin
						//set jump to address
						if(holdPcCnt == 10)
						begin
							addressLines <= addressLines + 1;
							nextPcBuffer <= {16'h0000, instruction};
						end

						else if(holdPcCnt == 9)
						begin
							addressLines <= addressLines + 1;
							nextPcBuffer <= {8'h00, instruction, nextPcBuffer[7:0]};
						end

						else if(holdPcCnt == 8)
						begin
							addressLines <= addressLines + 1;
							nextPcBuffer <= {instruction, nextPcBuffer[15:0]};
						end

						else if(holdPcCnt == 7)
						begin
							interruptPriorityBuffer <= instruction; 
						end

						else if(holdPcCnt == 6)
						begin
							flagBuffer <= {{6'b000000}, flag, eqFlag}; //save current flag state
							memReadWrite <= ADDR_MODE_WRT;
							addressLines <= stackPointer;
						end

						//push flag states to stack
						else if(holdPcCnt == 5)
						begin		
							toDataBus <= flagBuffer;
							stackPointer <= stackPointer - 1;
						end

						//push int priority level to stack
						else if(holdPcCnt == 4)
						begin
							toDataBus <= interruptPriorityBuffer;
							stackPointer <= stackPointer - 1;
							intNextPcBuffer <= iRetAddress; //save current running int. PC (if there is one running)
						end

                        //push iret to stack
						else if(holdPcCnt == 3)
						begin
							addressLines <= stackPointer;
							stackPointer <= stackPointer - 1;
							toDataBus <= iRetAddress[23:16];
						end

						else if(holdPcCnt == 2)
						begin
							addressLines <= stackPointer;
							stackPointer <= stackPointer - 1;
							toDataBus <= iRetAddress[15:8];
						end

						else if(holdPcCnt == 1)
						begin
							addressLines <= stackPointer;
							stackPointer <= stackPointer - 1;
							toDataBus <= iRetAddress[7:0];

							//no active int
							if(currentIntPriority == 0)
							begin
								interruptBufferQueue <= 0;
								currentIntPriority <= interruptPriorityBuffer;
							end

							else
							begin
								if(interruptPriorityBuffer > currentIntPriority)
								begin
									currentIntPriority <= interruptPriorityBuffer;
								end
								
								else //this new int. has a lower or equal priority so save it for later
								begin
									stackPointer <= stackPointer + 4;
									interruptBufferQueue <= currentInterruptVecAddr; //save this int. execution to buffer
									nextPcBuffer <= intNextPcBuffer; //set pc back to previous running int.
								end
							end
						end

						else if(holdPcCnt == 0)
						begin
						end
                    end
                end //end of disable PC
				///////////////////////////////////
				//END OF MULTI-CYCLE INSTRUCTIONS//
				///////////////////////////////////

				else //PC not disabled
				begin
					//interrupts/exceptions
					if(interruptBufferQueue != 0 && interruptRunning == 0)
					begin
						currentInterruptVecAddr <= INT_1_ADDR + (interrupt * 8) - 8;
						interruptRunning <= 1;
						instructionBuffer <= 8'b0111_1111;
						memReadWrite <= ADDR_MODE_RD;
						addressLines <= interruptBufferQueue;
						iRetAddress = nextPcBuffer;
						disablePc <= 1;
						holdPcCnt <= 10;
					end

					//should always trigger on exception interrupts (can't be blocked)
					else if(interrupt == 8'd1 || interrupt == 8'd2 || interrupt == 8'd3 ||
					interrupt == 8'd4)
					begin
						currentInterruptVecAddr <= INT_1_ADDR + (interrupt * 8) - 8;
						interruptRunning <= 1;
						instructionBuffer <= 8'b0111_1111;
						memReadWrite <= ADDR_MODE_RD;
						addressLines <= INT_1_ADDR + (interrupt * 8) - 8;
						iRetAddress = nextPcBuffer;
						disablePc <= 1;
						holdPcCnt <= 10;
					end

					else if(activeIrq && disableInt == 1'b0 && interruptRunning == 0) //external interrupt pins
					begin
						currentInterruptVecAddr <= IRQ_1_ADDR + (hardInterrupt * 8) - 8;
						interruptRunning <= 1;
						instructionBuffer <= 8'b0111_1111;
						memReadWrite <= ADDR_MODE_RD;
						addressLines <= IRQ_1_ADDR + (hardInterrupt * 8) - 8;
						iRetAddress = nextPcBuffer;
						disablePc <= 1;
						holdPcCnt <= 10;
					end

					//alu
					else
					begin
						r1En <= 0;
						r2En <= 0;
						r3En <= 0;
						r4En <= 0;
						regDataBusIn <= 0;
						pc <= nextPcBuffer;
						instructionBuffer <= instruction;
					
						//alu instructions
						if(instruction[7] == 1'b1)
						begin
							aluOpcode <= instruction; //hold alu opcode so instruction line can be used for new opperations

							if(divZero == 1'b1)
								interrupt <= 2; //exception 2

							nextPcBuffer <= pc + 1;
							disablePc <= 1;
							holdPcCnt <= 3;

							if(instruction == 8'b1000_0000  //OR
							|| instruction == 8'b1000_0001  //AND
							|| instruction == 8'b1000_0100  //CMP
							|| instruction == 8'b1000_0110  //XOR
							|| instruction == 8'b1000_0111  //ADD
							|| instruction == 8'b1000_1000) //SUB
							begin
								nextPcBuffer <= pc + 2;
								disablePc <= 1;
								holdPcCnt <= 1;

								memReadWrite <= ADDR_MODE_RD;
								addressLines <= pc + 1;
							end

							else if(instruction == 8'b1000_0010  //SHL
									|| instruction == 8'b1000_0011  //SHR
									|| instruction == 8'b1000_0101  //NOT
									|| instruction == 8'b1000_1001  //INC
									|| instruction == 8'b1000_1010  //DEC
									|| instruction == 8'b1000_1011  //ROL
									|| instruction == 8'b1000_1100) //ROR
							begin
								nextPcBuffer <= pc + 1;
								disablePc <= 1;
								holdPcCnt <= 0;
							end						
						end
						
						//all non-alu instructions
						else
						begin
							if(instruction[7:0] == 8'b0000_0000) //NOP
							begin
								nextPcBuffer <= pc + 1;
							end

							else if(instruction[7:0] == 8'b0000_0001) //MOV
							begin
								nextPcBuffer <= pc + 2;
								disablePc <= 1;
								holdPcCnt <= 2;

								memReadWrite <= ADDR_MODE_RD;
								addressLines <= pc + 1;
							end

							else if(instruction[7:0] == 8'b0000_0010) //LODSB
							begin
								nextPcBuffer <= pc + 1;
								disablePc <= 1;
								holdPcCnt <= 2;
								
								memReadWrite <= ADDR_MODE_RD;
								addressLines <= indexRegister;
							end
							
							else if(instruction[7:0] == 8'b0000_0011) //LOD (immediate values)
							begin
								nextPcBuffer <= pc + 2;
								disablePc <= 1;
								holdPcCnt <= 2;

								memReadWrite <= ADDR_MODE_RD;
								addressLines <= pc + 1;
							end

							else if(instruction[7:0] == 8'b0000_0100) //STB
							begin
								nextPcBuffer <= pc + 4;
								disablePc <= 1;
								holdPcCnt <= 4;
								
								memReadWrite <= ADDR_MODE_RD;
								addressLines <= pc + 1;
							end

							else if(instruction[7:0] == 8'b0000_0101) //BNE
							begin                                
								if(eqFlag == 0)
								begin
									disablePc <= 1;
									holdPcCnt <= 3;
									memReadWrite <= ADDR_MODE_RD;
									addressLines <= pc + 1;
								end
									
								else
									nextPcBuffer <= pc + 4;
							end

							else if(instruction[7:0] == 8'b0000_0110) //BEQ
							begin
								if(eqFlag)
								begin
									disablePc <= 1;
									holdPcCnt <= 3;
									memReadWrite <= ADDR_MODE_RD;
									addressLines <= pc + 1;
								end

								else
									nextPcBuffer <= pc + 4;
							end

							else if(instruction[7:0] == 8'b0000_0111) //BGR
							begin                    
								if(flag) //r1 > r2
								begin
									disablePc <= 1;
									holdPcCnt <= 3;
									memReadWrite <= ADDR_MODE_RD;
									addressLines <= pc + 1;
								end

								else
									nextPcBuffer <= pc + 4;
							end

							else if(instruction[7:0] == 8'b0000_1111) //PUSH
							begin
								nextPcBuffer <= pc + 2;
								disablePc <= 1;
								holdPcCnt <= 2;
								memReadWrite <= ADDR_MODE_RD;
								addressLines <= pc + 1;			
							end
							
							else if(instruction[7:0] == 8'b0001_1111) //POP
							begin
								nextPcBuffer <= pc + 2;
								disablePc <= 1;
								holdPcCnt <= 2;
								memReadWrite <= ADDR_MODE_RD;
								addressLines <= pc + 1;
								stackPointer <= stackPointer + 1;
							end
									
							else if(instruction[7:0] == 8'b0100_0111) //LDM
							begin
								nextPcBuffer <= pc + 4;
								disablePc <= 1;
								holdPcCnt <= 5;
								memReadWrite <= ADDR_MODE_RD;
								addressLines <= pc + 1;		
							end

							else if(instruction[7:0] == 8'b0000_1000) //INT
							begin
								interruptRunning <= 1;
								flagBuffer <= {{6'b000000}, flag, eqFlag}; //save current flag state
								disablePc <= 1;
								holdPcCnt <= 11;
								memReadWrite <= ADDR_MODE_RD;
								addressLines <= pc + 1;	
								iRetAddress <= pc + 2;
							end

							else if(instruction[7:0] == 8'b0111_1000) //IRET
							begin
								nextPcBuffer <= pc + 1;
								disablePc <= 1;
								holdPcCnt <= 5;
								memReadWrite <= ADDR_MODE_RD;
								stackPointer <= stackPointer + 1;
							end

							else if(instruction[7:0] == 8'b0000_1010) //PUSHA
							begin
								nextPcBuffer <= pc + 1;
								disablePc <= 1;
								holdPcCnt <= 7;
								memReadWrite <= ADDR_MODE_WRT;
								addressLines <= stackPointer;
							end

							else if(instruction[7:0] == 8'b0000_1011) //POPA
							begin
								nextPcBuffer <= pc + 1;
								disablePc <= 1;
								holdPcCnt <= 8;
								memReadWrite <= ADDR_MODE_RD;
								stackPointer <= stackPointer + 1;
							end

							else if(instruction[7:0] == 8'b0011_1110) //CLI
							begin
								nextPcBuffer <= pc + 1;
								disableInt <= 1'b1;
							end

							else if(instruction[7:0] == 8'b0111_1110) //STI
							begin
								nextPcBuffer <= pc + 1;
								disableInt <= 1'b0;
							end

							else if(instruction == 8'b0001_1000) //HALT
							begin
								halt <= 1;
							end

							else if(instruction == 8'b0010_1000) //CALL
							begin
								disablePc <= 1;
								holdPcCnt <= 6;
								
								iRetAddress <= pc + 3;
								memReadWrite <= ADDR_MODE_RD;
								addressLines <= pc + 1;		
							end

							else if(instruction == 8'b0010_0110) //RTS
							begin
								disablePc <= 1;
								holdPcCnt <= 6;
											
								stackPointer <= stackPointer + 1;
								memReadWrite <= ADDR_MODE_RD;						
							end

							else if(instruction == 8'b0100_1000) //BRA
							begin
								disablePc <= 1;
								holdPcCnt <= 3;
								memReadWrite <= ADDR_MODE_RD;
								addressLines <= pc + 1;
							end

							else if(instruction == 8'b0100_0000) //NSB (new stack base)
							begin
								nextPcBuffer <= pc + 1;
								stackPointer <= stackTopReg;		
							end

							else if(instruction == 8'b0110_0000) //BRZ
							begin
								if(flag)
								begin
									disablePc <= 1;
									holdPcCnt <= 3;
									memReadWrite <= ADDR_MODE_RD;
									addressLines <= pc + 1;
								end
									
								else
									nextPcBuffer <= pc + 4;
							end

							else if(instruction == 8'b0111_0000) //SPIR (set pointer index)
							begin
								nextPcBuffer <= pc + 4;
								disablePc <= 1;
								holdPcCnt <= 3;
								memReadWrite <= ADDR_MODE_RD;
								addressLines <= pc + 1;
							end

							else if(instruction == 8'b0111_0001) //RST (resets CPU)
							begin
								rstInstruction <= 1;
							end

							else if(instruction == 8'b0111_0010) //SBP
							begin
								nextPcBuffer <= pc + 3;
								disablePc <= 1;
								holdPcCnt <= 2;
								memReadWrite <= ADDR_MODE_RD;
								addressLines <= pc + 1;
							end

							else if(instruction == 8'b0011_0010) //STOSB
							begin
								disablePc <= 1;
								holdPcCnt <= 2;
								nextPcBuffer <= pc + 1;
							end

							else if(instruction == 8'b0011_0011) //SPDR
							begin
								nextPcBuffer <= pc + 3;
								disablePc <= 1;
								holdPcCnt <= 3;
								memReadWrite <= ADDR_MODE_RD;
								addressLines <= pc + 1;
							end

							else if(instruction == 8'b0111_0011)//XCHG
							begin
								nextPcBuffer <= pc + 2;
								disablePc <= 1;
								holdPcCnt <= 4;
								memReadWrite <= ADDR_MODE_RD;
								addressLines <= pc + 1;
							end

							else //exception, not an instruction
							begin
								interrupt <= 1; //exception 1
							end
						end
				end //end of pc not disabled
            end //end of not halt
        end //end of clk edge
    end //end of always block
end
endmodule