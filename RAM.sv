module RAM_tb
#(
	parameter addr_width = 8,
	parameter data_width = 8,
	parameter mem_sim_file = ""
)
(
	input                     CLK,
	
	input  [addr_width-1:0]   ADDR,
	input  [data_width-1:0]   DATA,
	input                     CS,
	input  [data_width/8-1:0] WREN,
	output [data_width-1:0]   Q
);

		// synopsys translate_off
	`define SIM
	// synopsys translate_on
	
`ifdef SIM
	
	reg [data_width-1:0] MEM [2**addr_width];

	initial begin
		MEM = '{2**addr_width{'0}};
		$readmemh(mem_sim_file, MEM);
	end
	
	always @(posedge CLK) begin
		bit [data_width-1:0] temp;

		if (data_width >  0) temp[ 7: 0] = WREN[0] ? DATA[ 7: 0] : Q[ 7: 0];
		if (data_width >  8) temp[15: 8] = WREN[1] ? DATA[15: 8] : Q[15: 8];
		if (data_width > 16) temp[23:16] = WREN[2] ? DATA[23:16] : Q[23:16];
		if (data_width > 24) temp[31:24] = WREN[3] ? DATA[31:24] : Q[31:24];

		if (WREN && CS) begin
			MEM[ADDR] <= temp;
		end
	end
		
	assign Q = MEM[ADDR];
	
`else
	
	
	
`endif
	
endmodule
