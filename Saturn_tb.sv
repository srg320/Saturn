`timescale 1 ns / 1 ns

module Saturn_tb;

	import SCU_PKG::*;
	
	bit        CLK;
	bit        RST_N;
	
	bit [24:0] MEM_A;
	bit [31:0] MEM_DO;
	bit [31:0] MEM_DI;
	bit  [3:0] MEM_DQM_N;
	bit        MEM_RD_N;
	bit        ROM_CS_N;
	bit        RAML_CS_N;
	bit        RAMH_CS_N;
	
	bit [18:1] SCSP_RAM_A;
	bit [15:0] SCSP_RAM_D;
	bit  [1:0] SCSP_RAM_WE;
	bit [15:0] SCSP_RAM_Q;
	 
	//clock generation
	always #5 CLK = ~CLK;
	 
	//reset generation
	initial begin
	  RST_N = 0;
	  #12 RST_N = 1;
	end
	
	Saturn Saturn
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE(1'b1),
		
		.MEM_A(MEM_A),
		.MEM_DI(MEM_DI),
		.MEM_DO(MEM_DO),
		.MEM_DQM_N(MEM_DQM_N),
		.MEM_RD_N(MEM_RD_N),
		.MEM_WAIT_N(1),
		
		.ROM_CS_N(ROM_CS_N),
		.RAML_CS_N(RAML_CS_N),
		.RAMH_CS_N(RAMH_CS_N),
		
		.SCSP_RAM_A(SCSP_RAM_A),
		.SCSP_RAM_D(SCSP_RAM_D),
		.SCSP_RAM_WE(SCSP_RAM_WE),
		.SCSP_RAM_Q(SCSP_RAM_Q)
	);
	
	bit [15:0] BIOS_Q;
	RAM_tb #(18,16,"bios.txt") bios(CLK, MEM_A[18:1], MEM_DO[15:0], ~ROM_CS_N, 2'b00, BIOS_Q);
	
	bit [15:0] RAML_Q;
	RAM_tb #(19,16,"") raml(CLK, MEM_A[19:1], MEM_DO[15:0], ~RAML_CS_N, ~MEM_DQM_N[1:0], RAML_Q);
	
	bit [31:0] RAMH_Q;
	RAM_tb #(18,32,"") ramh(CLK, MEM_A[19:2], MEM_DO, ~RAMH_CS_N, ~MEM_DQM_N, RAMH_Q);
	
	assign MEM_DI = !ROM_CS_N ? {16'h0000,BIOS_Q} :
	                !RAML_CS_N ? {16'h0000,RAML_Q} :
						 !RAMH_CS_N ? RAMH_Q :
						 32'hDEEDDEED;

	
	RAM_tb #(18,16,"") sndram(CLK, SCSP_RAM_A, SCSP_RAM_D, 1'b1, SCSP_RAM_WE, SCSP_RAM_Q);

endmodule
