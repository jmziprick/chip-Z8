# chip-Z8
Basic 8-bit cpu design
This is a basic 8-bit CPU implmentation in Verilog. 

ALU always outputs to acc.
Acc is permanently tied to r1, this makes it impossible to increment r2 register.
The only way to perform an increment on r2 or others would be to first move it to r1 and then increment on it there and move back if necessary.

Immediate mov and store load instruction have an extra byte followed by the opcode for the necessary data.

Registers:
R1 (ACC), R2, R3, R4, PC, FLG

ALU opperation 1___xx___xxxxx
              alu reg   command
              
OR - 0000
AND - 0001
SHL - 0010
SHR - 0011
CMP - 0100
NOT - 0101
XOR - 0110
ADD - 0111
SUB - 1000
INC - 1001
              
Non ALU opperation 0__xx__xx___xxx
                      reg reg  command

MOV - 001
JMP - 101
LODB - 011
STB - 100
NOP - 000
