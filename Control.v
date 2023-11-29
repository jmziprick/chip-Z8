`default_nettype none

module Control(input wire clk, 
input wire rstIn, 
output wire [23:0]pcOut, 
input wire [7:0]dataIn, 
output reg [23:0]addressLinesOut, 
output reg [1:0]memReadWrite, 
output reg [7:0]toDataBus, 
input wire [3:0]hardInterrupt, 
input wire memException);

//stack
localparam DEFAULT_STACK_TOP_ADDRESS = 16'd3000; //after port out space
	
//memory modes
localparam [1:0]
	ADDR_MODE_RD = 2'b00,  //00 reads address lines (reading 'random' locations)
	ADDR_MODE_PC = 2'b01,  //01 reads address at pc
	ADDR_MODE_WRT = 2'b10; //10 writes to address lines

//states
reg [3:0]cycleCount;
reg [3:0]state;
localparam[3:0]
    I_IDLE = 4'b0000,
    I_FETCH = 4'b0001,
    I_DECODE = 4'b0010,
    I_ACCESS_MEM_READ = 4'b0011,
    I_ACCESS_MEM_WRITE = 4'b0100,
    I_ACCESS_ALU = 4'b0101,
    I_ACCESS_REG_READ = 4'b0110,
    I_ACCESS_REG_WRITE = 4'b0111,
    I_INT_HNDL = 4'b1000,
    I_PC_NEXT = 4'b1001;

//opcodes
localparam[7:0]
    NOP = 8'h00,
    MOV = 8'h01,
    LODSB = 8'h02,
    LOD = 8'h03,
    STB = 8'h04,
    BNE = 8'h05,
    BEQ = 8'h06,
    BGR = 8'h07,
    PUSH = 8'h0F,
    POP = 8'h1F,
    LDM = 8'h47,
    S_INT = 8'h08,
    IRET = 8'h78,
    PUSHA = 8'h10,
    POPA = 8'h11,
    CLI = 8'h3E,
    STI = 8'h7E,
    HALT = 8'h18,
    CALL = 8'h28,
    RTS = 8'h38,
    BRA = 8'h48,
    NSB = 8'h40,
    BRZ = 8'h60,
    SPIR = 8'h70,
    RST = 8'h71,
    SBP = 8'h72,
    STOSB = 8'h32,
    SPDR = 8'h33,
    XCHG = 8'h73,
    H_INT = 8'h7F,

    OR = 8'h80,
    AND = 8'h81,
    SHL = 8'h82,
    SHR = 8'h83,
    CMP = 8'h84,
    NOT = 8'h85,
    XOR = 8'h86,
    ADD = 8'h87,
    SUB = 8'h88,
    INC = 8'h89,
    DEC = 8'h8A,
    ROL = 8'h8B,
    ROR = 8'h8C;


Register r1(.clk(clk), .rst(rstIn), .dataIn(tmpReg), .dataOut(r1Out), .en(r1En));
Register r2(.clk(clk), .rst(rstIn), .dataIn(tmpReg), .dataOut(r2Out), .en(r2En));
Register r3(.clk(clk), .rst(rstIn), .dataIn(tmpReg), .dataOut(r3Out), .en(r3En));
Register r4(.clk(clk), .rst(rstIn), .dataIn(tmpReg), .dataOut(r4Out), .en(r4En));

reg [23:0]si;
reg [23:0]di;
reg [23:0]stackTop;
reg [23:0]stackPointer;

Alu alu(.opcode(instruction[3:0]), 
.regA(r1Out), .regB(tmpReg), .accumulator(accumOut), 
.greaterFlag(greaterFlagBus), .zeroFlag(zeroFlagBus), .eqFlag(eqFlagBus), .overflowFlag(overflowFlagBus), 
.divZero(divZeroBus));

assign pcOut = pc;

//-------------STATE REGISTERS------------

//FETCH
reg [7:0]instruction;

//DECODE
reg rst;

//MEM ACCESS READ
reg [7:0]aluRegSel;
reg [7:0]pushPopRegSel;
wire [7:0]accumOut;
reg [23:0]retAddr;

//MEM ACCESS WRITE
reg [23:0]addressLinesOutBuff;

//ALU ACCESS
reg greaterFlag;
reg zeroFlag; 
reg eqFlag;
reg overflowFlag;
reg divZero;

wire greaterFlagBus;
wire zeroFlagBus; 
wire eqFlagBus;
wire overflowFlagBus;
wire divZeroBus;

//REG READ
wire [7:0]r1Out;
wire [7:0]r2Out;
wire [7:0]r3Out;
wire [7:0]r4Out;
reg [7:0]tmpReg;

//REG WRITE
reg r1En, r2En, r3En, r4En; //enables writing data to registers
reg swapReg; //for xchg instruction

//INT HANDLE
reg [7:0]intNum;

//PC_NEXT
reg [23:0]pc;

//----------------------------------------

always @(posedge clk, posedge rstIn)
begin
    if(rstIn || rst)
    begin
        rst <= 0;
        pc <= 0;
        addressLinesOut <= 0;
        tmpReg <= 0;
        r1En <= 0;
        r2En <= 0;
        r3En <= 0;
        r4En <= 0;
        si <= 0;
        di <= 0;
        stackTop <= 0;
        stackPointer <= 0;
        cycleCount <= 0;
        state <= I_FETCH;
        memReadWrite <= ADDR_MODE_PC;
        greaterFlag <= 0;
        zeroFlag <= 0;
        eqFlag <= 0;
        overflowFlag <= 0;
        divZero <= 0;
    end

    else
    begin
        case(state)
            I_IDLE:
            begin
                
            end

            I_FETCH:
            begin
                if(hardInterrupt)
                begin
                    //push pc
                    instruction <= H_INT;
                    state <= I_DECODE;
                end

                else
                begin
                    instruction <= dataIn;
                    state <= I_DECODE;
                end
            end

            I_DECODE:
            begin
                //next state dependant on instruction type
                case(instruction)
                    NOP:
                    begin
                        state <= I_PC_NEXT;
                    end

                    MOV:
                    begin
                        state <= I_ACCESS_MEM_READ;
                    end

                    LODSB:
                    begin
                        state <= I_ACCESS_MEM_READ;
                    end

                    LOD:
                    begin
                        state <= I_ACCESS_MEM_READ;
                    end

                    STB:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        cycleCount <= 2;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    BNE:
                    begin
                        if(eqFlag == 0)
                            state <= I_ACCESS_MEM_READ;

                        else
                            state <= I_PC_NEXT;

                        retAddr <= pc + 4;
                        cycleCount <= 2;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    BEQ:
                    begin
                        if(eqFlag)
                            state <= I_ACCESS_MEM_READ;

                        else
                            state <= I_PC_NEXT;

                        retAddr <= pc + 4;
                        cycleCount <= 2;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    BGR:
                    begin
                        if(greaterFlag)
                            state <= I_ACCESS_MEM_READ;

                        else
                            state <= I_PC_NEXT;

                        retAddr <= pc + 4;
                        cycleCount <= 2;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    PUSH:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    POP:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        addressLinesOut <= pc + 1;
                        stackPointer <= stackPointer + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    LDM:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        cycleCount <= 3;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    S_INT:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    IRET:
                    begin
                        //state <= I_ACCESS_MEM_READ;
                        //cycleCount <= 3;
                        //stackPointer <= stackPointer + 1;
                        //memReadWrite <= ADDR_MODE_RD;
                    end

                    PUSHA:
                    begin
                        state <= I_ACCESS_MEM_WRITE;
                        cycleCount <= 3;
                    end

                    POPA:
                    begin
                        memReadWrite <= ADDR_MODE_RD;
                        stackPointer <= stackPointer + 1;
                        addressLinesOut <= stackPointer + 1;
                        state <= I_ACCESS_MEM_READ;
                        cycleCount <= 3;
                    end

                    CLI:
                    begin

                    end

                    STI:
                    begin

                    end

                    HALT:
                    begin
                        state <= I_IDLE;
                    end

                    CALL:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        retAddr <= pc + 4;
                        cycleCount <= 2;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    RTS:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        cycleCount <= 3;
                        stackPointer <= stackPointer + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    BRA:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        retAddr <= pc + 4;
                        cycleCount <= 2;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    NSB:
                    begin
                        stackPointer <= stackTop;
                        state <= I_PC_NEXT;
                    end

                    BRZ:
                    begin
                        if(zeroFlag)
                            state <= I_ACCESS_MEM_READ;

                        else
                            state <= I_PC_NEXT;

                        retAddr <= pc + 4;
                        cycleCount <= 2;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    SPIR:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        cycleCount <= 3;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    RST:
                    begin
                        rst <= 1;
                    end

                    SBP:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        cycleCount <= 3;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;    
                    end

                    STOSB:
                    begin
                        state <= I_ACCESS_REG_READ;
                        addressLinesOut <= di;
                    end

                    SPDR:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        cycleCount <= 3;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    XCHG:
                    begin
                        state <= I_ACCESS_MEM_READ;
                    end

                    H_INT:
                    begin
                        state <= I_ACCESS_MEM_WRITE;
                        retAddr <= pc;
                        cycleCount <= 2;
                        memReadWrite <= ADDR_MODE_WRT;
                    end

                    //ALU
                    OR:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    AND:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    SHL:
                    begin
                        state <= I_ACCESS_ALU;
                    end

                    SHR:
                    begin
                        state <= I_ACCESS_ALU;
                    end

                    CMP:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        cycleCount <= 1;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    NOT:
                    begin
                        state <= I_ACCESS_ALU;
                    end

                    XOR:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    ADD:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    SUB:
                    begin
                        state <= I_ACCESS_MEM_READ;
                        addressLinesOut <= pc + 1;
                        memReadWrite <= ADDR_MODE_RD;
                    end

                    INC:
                    begin
                        state <= I_ACCESS_ALU;
                    end

                    DEC:
                    begin
                        state <= I_ACCESS_ALU;
                    end

                    ROL:
                    begin
                        state <= I_ACCESS_ALU;
                    end

                    ROR:
                    begin
                        state <= I_ACCESS_ALU;
                    end
                endcase
            end

            I_ACCESS_MEM_READ:
            begin
                if(instruction == MOV) 
                begin
                    memReadWrite <= ADDR_MODE_RD;
                    addressLinesOut <= pc + 1;
                    state <= I_ACCESS_REG_READ;
                end

                else if(instruction == LODSB)
                begin
                    memReadWrite <= ADDR_MODE_RD;
                    addressLinesOut <= si;
                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == LOD)
                begin
                        memReadWrite <= ADDR_MODE_RD;
                        addressLinesOut <= pc + 1;
                        state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == STB)
                begin
                    if(cycleCount == 2)
                    begin
                        addressLinesOut <= pc + 2;
                        addressLinesOutBuff[7:0] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        addressLinesOut <= pc + 3;
                        addressLinesOutBuff[15:8] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else
                    begin
                        addressLinesOutBuff[23:16] <= dataIn;
                        state <= I_ACCESS_MEM_WRITE;
                    end 
                end

                else if(instruction == PUSH)
                begin
                    case(pushPopRegSel[1:0])
                        2'b00:
                            tmpReg <= r1Out;
                            
                        2'b01:
                            tmpReg <= r2Out;
                            
                        2'b10:
                            tmpReg <= r3Out;
                            
                        2'b11:
                            tmpReg <= r4Out;
                    endcase

                    state <= I_ACCESS_MEM_WRITE;
                end

                else if(instruction == BNE)
                begin
                    if(cycleCount == 2)
                    begin        
                        addressLinesOut <= pc + 2;
                        addressLinesOutBuff[7:0] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        addressLinesOut <= pc + 3;
                        addressLinesOutBuff[15:8] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else
                    begin
                        addressLinesOutBuff[23:16] <= dataIn;
                        state <= I_PC_NEXT;
                        cycleCount <= 2;
                    end 
                end

                else if(instruction == BEQ)
                begin
                    if(cycleCount == 2)
                    begin        
                        addressLinesOut <= pc + 2;
                        addressLinesOutBuff[7:0] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        addressLinesOut <= pc + 3;
                        addressLinesOutBuff[15:8] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else
                    begin
                        addressLinesOutBuff[23:16] <= dataIn;
                        state <= I_PC_NEXT;
                        cycleCount <= 2;
                    end 
                end

                else if(instruction == BGR)
                begin
                    if(cycleCount == 2)
                    begin        
                        addressLinesOut <= pc + 2;
                        addressLinesOutBuff[7:0] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        addressLinesOut <= pc + 3;
                        addressLinesOutBuff[15:8] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else
                    begin
                        addressLinesOutBuff[23:16] <= dataIn;
                        state <= I_PC_NEXT;
                        cycleCount <= 2;
                    end 
                end

                else if(instruction == PUSH)
                begin
                    pushPopRegSel <= dataIn;
                    state <= I_ACCESS_MEM_READ;
                end

                else if(instruction == POP)
                begin
                    pushPopRegSel <= dataIn;
                    addressLinesOut <= stackPointer;
                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == LDM)
                begin
                    if(cycleCount == 3)
                    begin
                        addressLinesOut <= pc + 2;
                        addressLinesOutBuff[7:0] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 2)
                    begin
                        addressLinesOut <= pc + 3;
                        addressLinesOutBuff[15:8] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        addressLinesOutBuff[23:16] <= dataIn;
                        memReadWrite <= ADDR_MODE_RD;
                        cycleCount <= cycleCount - 1;
                    end

                    else
                    begin
                        addressLinesOut <= addressLinesOutBuff;
                        state <= I_ACCESS_REG_WRITE;
                        cycleCount <= 1;
                    end
                end

                else if(instruction == S_INT)
                begin
                    intNum <= dataIn;
                    state <= I_INT_HNDL;
                end

                else if(instruction == POPA)
                begin
                    if(cycleCount == 3)
                    begin
                        tmpReg <= dataIn;
                        r4En <= 1;
                        stackPointer <= stackPointer + 1;
                        addressLinesOut <= stackPointer + 1;
                        cycleCount <= cycleCount - 1;  
                    end

                    else if(cycleCount == 2)
                    begin
                        tmpReg <= dataIn;
                        r4En <= 0;
                        r3En <= 1;  
                        stackPointer <= stackPointer + 1;
                        addressLinesOut <= stackPointer + 1;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        tmpReg <= dataIn;
                        r3En <= 0;
                        r2En <= 1;  
                        stackPointer <= stackPointer + 1;
                        addressLinesOut <= stackPointer + 1;
                        cycleCount <= cycleCount - 1;
                    end

                    else
                    begin
                        tmpReg <= dataIn;
                        r2En <= 0;
                        r1En <= 1;  
                        cycleCount <= cycleCount - 1;
                        state <= I_PC_NEXT;
                    end
                end

                else if(instruction == RTS)
                begin
                    if(cycleCount == 3)
                    begin          
                        addressLinesOut <= stackPointer;
                        stackPointer <= stackPointer + 1;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 2)
                    begin
                        retAddr[23:16] <= dataIn;
                        addressLinesOut <= stackPointer;
                        stackPointer <= stackPointer + 1;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        retAddr[15:8] <= dataIn;  
                        addressLinesOut <= stackPointer;
                        cycleCount <= cycleCount - 1;
                    end

                    else
                    begin
                        retAddr[7:0] <= dataIn;
                        state <= I_PC_NEXT;
                    end
                end

                else if(instruction == CALL)
                begin
                    if(cycleCount == 2)
                    begin        
                        addressLinesOut <= pc + 2;
                        addressLinesOutBuff[7:0] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        addressLinesOut <= pc + 3;
                        addressLinesOutBuff[15:8] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else
                    begin
                        addressLinesOutBuff[23:16] <= dataIn;
                        state <= I_ACCESS_MEM_WRITE;
                        cycleCount <= 2;
                    end
                end

                else if(instruction == BRA)
                begin
                    if(cycleCount == 2)
                    begin        
                        addressLinesOut <= pc + 2;
                        addressLinesOutBuff[7:0] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        addressLinesOut <= pc + 3;
                        addressLinesOutBuff[15:8] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else
                    begin
                        addressLinesOutBuff[23:16] <= dataIn;
                        state <= I_PC_NEXT;
                        cycleCount <= 2;
                    end 
                end

                else if(instruction == BRZ)
                begin
                    if(cycleCount == 2)
                    begin        
                        addressLinesOut <= pc + 2;
                        addressLinesOutBuff[7:0] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        addressLinesOut <= pc + 3;
                        addressLinesOutBuff[15:8] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else
                    begin
                        addressLinesOutBuff[23:16] <= dataIn;
                        state <= I_PC_NEXT;
                        cycleCount <= 2;
                    end 
                end

                else if(instruction == SPIR)
                begin
                    if(cycleCount == 3)
                    begin
                        addressLinesOut <= pc + 2;
                        addressLinesOutBuff[7:0] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 2)
                    begin
                        addressLinesOut <= pc + 3;
                        addressLinesOutBuff[15:8] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        addressLinesOutBuff[23:16] <= dataIn;
                        memReadWrite <= ADDR_MODE_RD;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 0)
                    begin
                        si <= addressLinesOutBuff;
                        state <= I_PC_NEXT;
                    end
                end

                else if(instruction == SBP)
                begin
                    if(cycleCount == 3)
                    begin
                        addressLinesOut <= pc + 2;
                        stackTop[7:0] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 2)
                    begin
                        addressLinesOut <= pc + 3;
                        stackTop[15:8] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        stackTop[23:16] <= dataIn;
                        memReadWrite <= ADDR_MODE_RD;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 0)
                    begin
                        state <= I_PC_NEXT;
                    end  
                end

                else if(instruction == SPDR)
                begin
                    if(cycleCount == 3)
                    begin
                        addressLinesOut <= pc + 2;
                        addressLinesOutBuff[7:0] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 2)
                    begin
                        addressLinesOut <= pc + 3;
                        addressLinesOutBuff[15:8] <= dataIn;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        addressLinesOutBuff[23:16] <= dataIn;
                        memReadWrite <= ADDR_MODE_RD;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 0)
                    begin
                        di <= addressLinesOutBuff;
                        state <= I_PC_NEXT;
                    end
                end 

                else if(instruction == XCHG) 
                begin
                    memReadWrite <= ADDR_MODE_RD;
                    addressLinesOut <= pc + 1;
                    state <= I_ACCESS_REG_READ;
                end

                else if(instruction == OR)
                begin
                    aluRegSel <= dataIn;
                    state <= I_ACCESS_ALU;
                end

                else if(instruction == AND)
                begin
                    aluRegSel <= dataIn;
                    state <= I_ACCESS_ALU;
                end

                else if(instruction == CMP)
                begin
                    aluRegSel <= dataIn;
                    state <= I_ACCESS_ALU;
                end

                else if(instruction == XOR)
                begin
                    aluRegSel <= dataIn;
                    state <= I_ACCESS_ALU;
                end

                else if(instruction == ADD)
                begin
                    aluRegSel <= dataIn;
                    state <= I_ACCESS_ALU;
                end

                else if(instruction == SUB)
                begin
                    aluRegSel <= dataIn;
                    state <= I_ACCESS_ALU;
                end
            end

            I_ACCESS_MEM_WRITE:
            begin
                if(instruction == STB)
                begin
                    toDataBus <= r1Out;
                    addressLinesOut <= addressLinesOutBuff;
                    memReadWrite <= ADDR_MODE_WRT;
                    state <= I_PC_NEXT;
                end

                else if(instruction == PUSH)
                begin
                    toDataBus <= tmpReg;
                    addressLinesOut <= stackPointer;
                    stackPointer <= stackPointer - 1;
                    memReadWrite <= ADDR_MODE_WRT;
                    state <= I_PC_NEXT;
                end

                else if(instruction == PUSHA)
                begin
                    if(cycleCount == 3)
                    begin
                        toDataBus <= r1Out;
                        addressLinesOut <= stackPointer;
                        stackPointer <= stackPointer - 1;
                        memReadWrite <= ADDR_MODE_WRT;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 2)
                    begin
                        toDataBus <= r2Out;
                        addressLinesOut <= stackPointer;
                        stackPointer <= stackPointer - 1;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        toDataBus <= r3Out;
                        addressLinesOut <= stackPointer;
                        stackPointer <= stackPointer - 1;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 0)
                    begin
                        toDataBus <= r4Out;
                        addressLinesOut <= stackPointer;
                        stackPointer <= stackPointer - 1;
                        state <= I_PC_NEXT;
                    end
                end

                else if(instruction == CALL)
                begin
                    if(cycleCount == 2)
                    begin
                        toDataBus <= retAddr[7:0];
                        stackPointer <= stackPointer - 1;
                        addressLinesOut <= stackPointer;
                        memReadWrite <= ADDR_MODE_WRT;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        toDataBus <= retAddr[15:8];
                        stackPointer <= stackPointer - 1;
                        addressLinesOut <= stackPointer;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 0)
                    begin
                        toDataBus <= retAddr[23:16];
                        stackPointer <= stackPointer - 1;
                        addressLinesOut <= stackPointer;
                        state <= I_PC_NEXT;
                    end
                end
                
                else if(instruction == STOSB)
                begin
                    di <= di + 1;
                    state <= I_PC_NEXT;
                end

                else if(instruction == H_INT)
                begin
                    //push return address to stack
                    if(cycleCount == 2)
                    begin
                        toDataBus <= retAddr[7:0];
                        stackPointer <= stackPointer - 1;
                        addressLinesOut <= stackPointer;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 1)
                    begin
                        toDataBus <= retAddr[15:8];
                        stackPointer <= stackPointer - 1;
                        addressLinesOut <= stackPointer;
                        cycleCount <= cycleCount - 1;
                    end

                    else if(cycleCount == 0)
                    begin
                        toDataBus <= retAddr[23:16];
                        stackPointer <= stackPointer - 1;
                        addressLinesOut <= stackPointer;

                        state <= I_INT_HNDL;
                    end

                    //push flags

                    //push registers
                end

                else if(instruction == S_INT)
                begin
                    if(cycleCount == )
                    begin

                    end

                    //push return address
                    else if(cycleCount == )
                    begin

                    end

                    //push flags
                    else if(cycleCount == )
                    begin
                        toDataBus <= {4'b0000, greaterFlagBus, zeroFlagBus, eqFlagBus, overflowFlagBus};
                    end

                    //push registers
                    else if(cycleCount == )
                    begin
                        
                    end
                end
            end

            I_ACCESS_ALU:
            begin
                if(instruction == OR)
                begin
                    if(aluRegSel[1:0] == 2'b00)
                        tmpReg <= r1Out;

                    else if(aluRegSel[1:0] == 2'b01)
                        tmpReg <= r2Out;

                    else if(aluRegSel[1:0] == 2'b10)
                        tmpReg <= r3Out;

                    else if(aluRegSel[1:0] == 2'b11)
                        tmpReg <= r4Out;

                    zeroFlag <= zeroFlagBus;
                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == AND)
                begin
                    if(aluRegSel[1:0] == 2'b00)
                        tmpReg <= r1Out;

                    else if(aluRegSel[1:0] == 2'b01)
                        tmpReg <= r2Out;

                    else if(aluRegSel[1:0] == 2'b10)
                        tmpReg <= r3Out;

                    else if(aluRegSel[1:0] == 2'b11)
                        tmpReg <= r4Out;

                    zeroFlag <= zeroFlagBus;
                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == SHL)
                begin
                    tmpReg <= r1Out;
                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == SHR)
                begin
                    tmpReg <= r1Out;
                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == CMP)
                begin
                    if(aluRegSel[1:0] == 2'b00)
                        tmpReg <= r1Out;

                    else if(aluRegSel[1:0] == 2'b01)
                        tmpReg <= r2Out;

                    else if(aluRegSel[1:0] == 2'b10)
                        tmpReg <= r3Out;

                    else if(aluRegSel[1:0] == 2'b11)
                        tmpReg <= r4Out;

                    if(cycleCount == 1)
                        cycleCount <= cycleCount - 1;

                    else if(cycleCount == 0)
                    begin
                        state <= I_PC_NEXT;

                        greaterFlag <= greaterFlagBus;
                        zeroFlag <= zeroFlagBus;
                        eqFlag <= eqFlagBus;
                        overflowFlag <= overflowFlagBus;
                        divZero <= divZeroBus;
                    end
                end

                else if(instruction == NOT)
                begin
                    tmpReg <= 8'hZZ;
                    zeroFlag <= zeroFlagBus;
                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == XOR)
                begin
                    if(aluRegSel[1:0] == 2'b00)
                        tmpReg <= r1Out;

                    else if(aluRegSel[1:0] == 2'b01)
                        tmpReg <= r2Out;

                    else if(aluRegSel[1:0] == 2'b10)
                        tmpReg <= r3Out;

                    else if(aluRegSel[1:0] == 2'b11)
                        tmpReg <= r4Out;

                    zeroFlag <= zeroFlagBus;
                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == ADD)
                begin
                    if(aluRegSel[1:0] == 2'b00)
                        tmpReg <= r1Out;

                    else if(aluRegSel[1:0] == 2'b01)
                        tmpReg <= r2Out;

                    else if(aluRegSel[1:0] == 2'b10)
                        tmpReg <= r3Out;

                    else if(aluRegSel[1:0] == 2'b11)
                        tmpReg <= r4Out;

                    overflowFlag <= overflowFlagBus;
                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == SUB)
                begin
                    if(aluRegSel[1:0] == 2'b00)
                        tmpReg <= r1Out;

                    else if(aluRegSel[1:0] == 2'b01)
                        tmpReg <= r2Out;

                    else if(aluRegSel[1:0] == 2'b10)
                        tmpReg <= r3Out;

                    else if(aluRegSel[1:0] == 2'b11)
                        tmpReg <= r4Out;

                    zeroFlag <= zeroFlagBus;
                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == INC)
                begin
                    overflowFlag <= overflowFlagBus;
                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == DEC)
                begin
                    zeroFlag <= zeroFlagBus;
                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == ROL)
                begin
                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == ROR)
                begin
                    state <= I_ACCESS_REG_WRITE;
                end
            end

            I_ACCESS_REG_READ:
            begin
                if(instruction == MOV)
                begin                    
                    case(dataIn[1:0])
                        2'b00:
                            tmpReg <= r1Out;
                            
                        2'b01:
                            tmpReg <= r2Out;
                            
                        2'b10:
                            tmpReg <= r3Out;
                            
                        2'b11:
                            tmpReg <= r4Out;
                    endcase

                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == XCHG)
                begin                    
                    case(dataIn[1:0])
                        2'b00:
                            tmpReg <= r1Out;
                            
                        2'b01:
                            tmpReg <= r2Out;
                            
                        2'b10:
                            tmpReg <= r3Out;
                            
                        2'b11:
                            tmpReg <= r4Out;
                    endcase

                    cycleCount <= 1;
                    state <= I_ACCESS_REG_WRITE;
                end

                else if(instruction == STOSB)
                begin
                    toDataBus <= r1Out;
                    memReadWrite <= ADDR_MODE_WRT;
                    state <= I_ACCESS_MEM_WRITE;
                end
            end

            I_ACCESS_REG_WRITE:
            begin
                if(instruction == MOV)
                begin
                    case(dataIn[3:2])			
                        2'b00:
                            r1En <= 1;
                            
                        2'b01:
                            r2En <= 1;
                            
                        2'b10:
                            r3En <= 1;
                            
                        2'b11:
                            r4En <= 1;
                    endcase

                    state <= I_PC_NEXT;
                end

                else if(instruction == XCHG)
                begin
                    if(cycleCount == 1)
                    begin
                        swapReg <= r1Out;
                        r1En <= 1;
                        r2En <= 0;
                        r3En <= 0;
                        r4En <= 0;
                        cycleCount <= cycleCount - 1;
                    end

                    else
                    begin
                        r1En <= 0;
                        r2En <= 0;
                        r3En <= 0;
                        r4En <= 0;
                        tmpReg <= swapReg;

                        case(dataIn[1:0])
                            2'b00:
                                r1En <= 1;
                                
                            2'b01:
                                r2En <= 1;   

                            2'b10:
                                r3En <= 1;
                                
                            2'b11:
                                r4En <= 1;
                        endcase

                        state <= I_PC_NEXT;
                    end
                end

                else if(instruction == LODSB)
                begin
                    si <= si + 1;
                    tmpReg <= dataIn;
                    r1En <= 1;
                    state <= I_PC_NEXT;
                end

                else if(instruction == LOD)
                begin
                    r1En <= 1;
                    tmpReg <= dataIn;
                    state <= I_PC_NEXT;
                end

                else if(instruction == LDM)
                begin
                    if(cycleCount == 1)
                    begin
                        cycleCount <= cycleCount - 1;
                        tmpReg <= dataIn;
                        r1En <= 1;
                    end

                    else
                    begin
                        state <= I_PC_NEXT;
                    end    
                end

                else if(instruction == POP)
                begin
                    tmpReg <= dataIn;

                    case(pushPopRegSel[1:0])			
                        2'b00:
                            r1En <= 1;
                            
                        2'b01:
                            r2En <= 1;
                            
                        2'b10:
                            r3En <= 1;
                            
                        2'b11:
                            r4En <= 1;
                    endcase

                    state <= I_PC_NEXT;
                end

                else if(instruction == OR)
                begin
                    tmpReg <= accumOut;
                    r1En <= 1;
                    state <= I_PC_NEXT;
                end

                else if(instruction == AND)
                begin
                    tmpReg <= accumOut;
                    r1En <= 1;
                    state <= I_PC_NEXT;
                end

                else if(instruction == SHL)
                begin
                    tmpReg <= accumOut;
                    r1En <= 1;
                    state <= I_PC_NEXT;
                end

                else if(instruction == SHR)
                begin
                    tmpReg <= accumOut;
                    r1En <= 1;
                    state <= I_PC_NEXT;
                end

                else if(instruction == NOT)
                begin
                    tmpReg <= accumOut;
                    r1En <= 1;
                    state <= I_PC_NEXT;  
                end

                else if(instruction == XOR)
                begin
                    tmpReg <= accumOut;
                    r1En <= 1;
                    state <= I_PC_NEXT; 
                end

                else if(instruction == ADD)
                begin
                    tmpReg <= accumOut;
                    r1En <= 1;
                    state <= I_PC_NEXT; 
                end

                else if(instruction == SUB)
                begin
                    tmpReg <= accumOut;
                    r1En <= 1;
                    state <= I_PC_NEXT; 
                end

                else if(instruction == INC)
                begin
                    tmpReg <= accumOut;
                    r1En <= 1;
                    state <= I_PC_NEXT;
                end

                else if(instruction == DEC)
                begin
                    tmpReg <= accumOut;
                    r1En <= 1;
                    state <= I_PC_NEXT;
                end

                else if(instruction == ROL)
                begin
                    tmpReg <= accumOut;
                    r1En <= 1;
                    state <= I_PC_NEXT;
                end

                else if(instruction == ROR)
                begin
                    tmpReg <= accumOut;
                    r1En <= 1;
                    state <= I_PC_NEXT;
                end 
            end

            I_INT_HNDL:
            begin
                if(instruction == S_INT)
                begin
                    
                end
            end       

            I_PC_NEXT:
            begin
                memReadWrite <= ADDR_MODE_PC;
                state <= I_FETCH;
                r1En <= 0;    
                r2En <= 0;
                r3En <= 0;
                r4En <= 0;
                cycleCount <= 0;

                case(instruction)
                    NOP:
                    begin
                        pc <= pc + 1;
                    end

                    MOV:
                    begin
                        pc <= pc + 2;
                    end

                    LODSB:
                    begin
                        pc <= pc + 1;
                    end

                    LOD:
                    begin
                        pc <= pc + 2;
                    end

                    STB:
                    begin
                        pc <= pc + 4;
                    end

                    BNE:
                    begin
                        if(eqFlag == 0)
                            pc <= addressLinesOutBuff;

                        else
                            pc <= pc + 4;
                    end

                    BEQ:
                    begin
                        if(eqFlag)
                            pc <= addressLinesOutBuff;

                        else
                            pc <= pc + 4;
                    end

                    BGR:
                    begin
                        if(greaterFlag)
                            pc <= addressLinesOutBuff;

                        else
                            pc <= pc + 4;
                    end

                    PUSH:
                    begin
                        pc <= pc + 2;
                    end

                    POP:
                    begin
                        pc <= pc + 2;
                    end

                    LDM:
                    begin
                        pc <= pc + 4;
                    end

                    S_INT:
                    begin

                    end

                    IRET:
                    begin

                    end

                    PUSHA:
                    begin
                        pc <= pc + 1;
                    end

                    POPA:
                    begin
                        pc <= pc + 1;
                    end

                    CLI:
                    begin

                    end

                    STI:
                    begin

                    end

                    HALT:
                    begin

                    end

                    CALL:
                    begin
                        pc <= addressLinesOutBuff;
                    end

                    RTS:
                    begin
                        pc <= retAddr;
                    end

                    BRA:
                    begin
                        pc <= addressLinesOutBuff;
                    end

                    NSB:
                    begin
                        pc <= pc + 1;
                    end

                    BRZ:
                    begin
                        if(zeroFlag)
                            pc <= addressLinesOutBuff;

                        else
                            pc <= pc + 4;
                    end

                    SPIR:
                    begin
                        pc <= pc + 4;
                    end

                    RST:
                    begin

                    end

                    SBP:
                    begin
                        pc <= pc + 4;
                    end

                    STOSB:
                    begin
                        pc <= pc + 1;
                    end

                    SPDR:
                    begin
                        pc <= pc + 4;
                    end

                    XCHG:
                    begin
                        pc <= pc + 2;
                    end

                    //ALU
                    OR:
                    begin
                        pc <= pc + 2;
                    end

                    AND:
                    begin
                        pc <= pc + 2;
                    end

                    SHL:
                    begin
                        pc <= pc + 1;
                    end

                    SHR:
                    begin
                        pc <= pc + 1;
                    end

                    CMP:
                    begin
                        pc <= pc + 2;
                    end

                    NOT:
                    begin
                        pc <= pc + 1;
                    end

                    XOR:
                    begin
                        pc <= pc + 2;
                    end

                    H_INT:
                    begin

                    end

                    ADD:
                    begin
                        pc <= pc + 2;
                    end

                    SUB:
                    begin
                        pc <= pc + 2;
                    end

                    INC:
                    begin
                        pc <= pc + 1;
                    end

                    DEC:
                    begin
                        pc <= pc + 1;
                    end

                    ROL:
                    begin
                        pc <= pc + 1;
                    end

                    ROR:
                    begin
                        pc <= pc + 1;
                    end
                endcase     
            end   
        endcase
    end
end

endmodule