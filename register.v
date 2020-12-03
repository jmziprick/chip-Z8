module Register(input wire [7:0]dataIn, output reg [7:0]dataOut, input wire en);

    reg [7:0]data;
    
	always @*
	begin
		begin
			if(en)
				data <= dataIn;
    
            dataOut <= data;
		end
	end
endmodule
