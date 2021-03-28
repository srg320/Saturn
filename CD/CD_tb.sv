`timescale 1 ns / 1 ns

module CD_tb;

//	import SCU_PKG::*;
	
	bit        CLK;
	bit        RST_N;
	bit        RES_N;
	
	bit [18:1] RAM_A;
	bit [15:0] RAM_D;
	bit [15:0] RAM_Q;
	bit  [1:0] RAM_WE;
	bit        RAM_RD;
	bit        RAM_CS;

	 
	//clock generation
	always #5 CLK = ~CLK;
	 
	//reset generation
	initial begin
	  RST_N = 0;
	  #12 RST_N = 1;
	  
	  RES_N = 0;
	  #5 RES_N = 1;
	end
	
	CD #("sh7034.txt") cd
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE(1'b1),
		
		.RES_N(RES_N),
		
		.CE_R(1'b0),
		.CE_F(1'b0),
		.AA('0),
		.ADI('0),
		.ADO(),
		.AFC('0),
		.ACS2_N(1'b1),
		.ARD_N(1'b1),
		.AWRL_N(1'b1),
		.AWRU_N(1'b1),
		.ATIM0_N(1'b1),
		.ATIM2_N(1'b1),
		.AWAIT_N(),
		.ARQT_N(),
		
		.CDATA(1'b1),
		.HDATA(),
		.COMCLK(),
		.COMREQ_N(1'b1),
		.COMSYNC_N(1'b1),
		
		.RAM_A(RAM_A),
		.RAM_D(RAM_D),
		.RAM_Q(RAM_Q),
		.RAM_CS(RAM_CS),
		.RAM_WE(RAM_WE),
		.RAM_RD(RAM_RD),
		
		.CD_D('0),
		.CD_CK(0)
	);
	
	RAM_tb #(18,16,"") dram(CLK, RAM_A, RAM_D, RAM_CS, RAM_WE, RAM_Q);
	

endmodule
