`timescale 1 ns / 1 ns

module SCSP_tb;

	bit        CLK;
	bit        RST_N, RES_N;

	always #5 CLK = ~CLK;

	initial begin
	  RST_N = 0;
	  RES_N = 0;
	  #100 RST_N = 1;
	   RES_N = 1;
	end
	
	bit [18:1] RAM_A;
	bit [15:0] RAM_D;
	bit [15:0] RAM_Q;
	bit  [1:0] RAM_WE;
	bit        RAM_RD;
	bit        RAM_CS;
	
	bit         SCCE_R;
	bit         SCCE_F;
	bit  [23:1] SCA;
	bit  [15:0] SCDI;
	bit  [15:0] SCDO;
	bit         SCRW_N;
	bit         SCAS_N;
	bit         SCLDS_N;
	bit         SCUDS_N;
	bit         SCDTACK_N;
	bit   [2:0] SCFC;
	bit         SCAVEC_N;
	bit   [2:0] SCIPL_N;
	
	bit  [23:0] SCA_DBG;
	
	SCSP SCSP
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE(1'b1),
		
		.RES_N(RES_N),
		
		
		.CE_R(1'b0),
		.CE_F(1'b0),
		.DI('0),
		.DO(),
		.CS_N(1'b1),
		.AD_N(1'b1),
		.DTEN_N(1'b1),
		.WE_N(2'b11),
		.RDY_N(),
		
		.SCCE_R(SCCE_R),
		.SCCE_F(SCCE_F),
		.SCA(SCA),
		.SCDI(SCDI),
		.SCDO(SCDO),
		.SCRW_N(SCRW_N),
		.SCAS_N(SCAS_N),
		.SCLDS_N(SCLDS_N),
		.SCUDS_N(SCUDS_N),
		.SCDTACK_N(SCDTACK_N),
		.SCFC(SCFC),
		.SCAVEC_N(SCAVEC_N),
		.SCIPL_N(SCIPL_N),
		
		.RAM_A(RAM_A),
		.RAM_D(RAM_D),
		.RAM_WE(RAM_WE),
		.RAM_RD(RAM_RD),
		.RAM_Q(RAM_Q),
		.RAM_CS(RAM_CS),
		.RAM_RDY(1'b1)
	);
	
	fx68k M68K
	(
		.clk(CLK),
		.extReset(~RES_N),
		.pwrUp(~RST_N),
		.enPhi1(SCCE_R),
		.enPhi2(SCCE_F),

		.eab(SCA),
		.iEdb(SCDO),
		.oEdb(SCDI),
		.eRWn(SCRW_N),
		.ASn(SCAS_N),
		.LDSn(SCLDS_N),
		.UDSn(SCUDS_N),
		.DTACKn(SCDTACK_N),

		.IPL0n(SCIPL_N[0]),
		.IPL1n(SCIPL_N[1]),
		.IPL2n(SCIPL_N[2]),

		.VPAn(SCAVEC_N),
		
		.FC0(SCFC[0]),
		.FC1(SCFC[1]),
		.FC2(SCFC[2]),

		.BGn(),
		.BRn(1'b1),
		.BGACKn(1'b1),

		.BERRn(1'b1),
		.HALTn(1'b1)
	);
	
	assign SCA_DBG = {SCA,1'b0};
	
	RAM_tb #(18,16,"sndram.txt") RAM(CLK, RAM_A, RAM_D, RAM_CS, RAM_WE, RAM_Q);

	

endmodule

