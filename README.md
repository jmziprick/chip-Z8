Z8 CPU DESIGN DOCUMENT
Basic 8-bit cpu design
This is a basic 8-bit CPU implmentation in Verilog. 

ALU always outputs to acc.
Acc is permanently tied to r1, this makes it impossible to increment r2 register.
The only way to perform an increment on r2 or others would be to first move it to r1 and then increment on it there and move back if necessary.

8-bit CPU (Little endian) with a 24-bit address bus


ROM
	Size = 2k
	Range = 0x0-0x1FFF

RAM
	Size = 62k
	Range = 0x2000-0xFFFC

		Stack (default) – Top starting at 0xFFFC
			Size = 512 bytes
			Range = FFFC-FDFC
			
		Video –40x25 (8-bit) ~8k test (color) 
80x25 (8-bit) ~16k text (color)
80x50 (8-bit) 32k graphics (color)
160x100 (2-bit) 32k graphics (monochrome)
			Size = 32k
			Range = 0x80FB-FDFB

		General purpose
			Size = ~25k (24,826)
			Range = 0x2000-0x80FA

Output ports:
	Port A = 0xFFFF
	Port B = 0xFFFE

	Port multiplexing shared (3-bit) [2:0] at address 0xFFFD

Index pointer:
	Used with the LODSB instruction, set with SPIR

Destination pointer:
	Used with the STOSB instruction, set with SPDR


Interrupts
If two interrupts occur simultaneously, the CPU will process the interrupt with the higher priority first. If a new interrupt occurs while an ISR is still executing, the current interrupt will finish if they are the same priority or the new one is less. If the new interrupt is higher the current interrupt will pause, and execution will jump to the new IRQ. After finishing the new IRQ execution will jump back to finish the previous.

