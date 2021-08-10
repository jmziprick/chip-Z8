all:
	iverilog test.v control.v alu.v register.v iointegratedMem.v
	#iverilog testControl.v control.v alu.v register.v
	vvp a.out
