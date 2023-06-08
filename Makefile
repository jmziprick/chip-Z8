all:
	iverilog Test.v ALU.v io.v Control.v Register.v
	vvp a.out