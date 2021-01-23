import VDP2_PKG::*;
	
module VDP2 (
	input             CLK,		//~53MHz
	input             RST_N,
	input             CE_R,
	input             CE_F,
	
	input             RES_N,
	
	input      [20:1] A,
	input      [15:0] DI,
	output     [15:0] DO,
	input             CS_N,
	input             WE_N,
	input             RD_N,
	output            RDY_N,
	
	output            VINT_N,
	output            HINT_N,
	
	output     [16:1] RA0_A,
	output     [15:0] RA0_D,
	input      [31:0] RA0_Q,
	output            RA0_WE,
	output            RA0_RD,
	
	output     [16:1] RA1_A,
	output     [15:0] RA1_D,
	input      [31:0] RA1_Q,
	output            RA1_WE,
	output            RA1_RD,
	
	output     [16:1] RB0_A,
	output     [15:0] RB0_D,
	input      [31:0] RB0_Q,
	output            RB0_WE,
	output            RB0_RD,
	
	output     [16:1] RB1_A,
	output     [15:0] RB1_D,
	input      [31:0] RB1_Q,
	output            RB1_WE,
	output            RB1_RD,
	
	output      [7:0] R,
	output      [7:0] G,
	output      [7:0] B,
	output reg        DCLK,
	output reg        HS_N,
	output reg        VS_N,
	output reg        HBL_N,
	output reg        VBL_N,
	
	output VRAMAccessState_t VA_PIPE0,
	output DotData_t N0DOT_DBG,
	output DotData_t N1DOT_DBG,
	output DotData_t DOT_DBG,
	output ScrollData_t N0OFFX,
	output ScrollData_t N0OFFY,
	output [15:0] REG_DBG
);
	
	
	//H 427/455
	//V 263/313
	parameter HRES      = 9'd427;
	parameter HS_START  = 9'd369;
	parameter HS_END    = HS_START + 9'd32;
	parameter HBL_START = 9'd320;
	parameter VRES      = 9'd263;
	parameter VS_START  = 9'd235;
	parameter VS_END    = VS_START + 9'd3;
	parameter VBL_START = 9'd224;
	
	VDP2Regs_t REGS;
	
	wire VRAM_SEL = ~A[20];	//000000-0FFFFF
	
	bit DOT_CE,DOTH_CE;
	bit [8:0] H_CNT, V_CNT;
	bit [8:0] SCRX, SCRY;
	VRAMAccessPipeline_t VA_PIPE;
	PatternName_t PNT[4];
	PatternName_t PN[4];
	ScrollData_t VS[2];
	CellDotsLine_t NBG_CDL[4];
	bit  [2:0] NBG_CH_CNT[4];
	bit        NBG_CH_HF[4];
	bit  [6:0] NBG_CH_PALN[4];
	bit [16:1] VRAMA0_A, VRAMA1_A, VRAMB0_A, VRAMB1_A;
	bit [15:0] VRAMA0_D, VRAMA1_D, VRAMB0_D, VRAMB1_D;
	bit [15:0] VRAMA0_Q, VRAMA1_Q, VRAMB0_Q, VRAMB1_Q;
	bit        VRAMA0_WE, VRAMA1_WE, VRAMB0_WE, VRAMB1_WE;
	bit        VRAMA0_RD, VRAMA1_RD, VRAMB0_RD, VRAMB1_RD;
	
	bit [10:0] PAL_A;
	bit [15:0] PAL_Q;
	bit [15:0] PAL_DO;
	
	
	bit [2:0] DOTCLK_DIV;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DOTCLK_DIV <= '0;
			DOT_CE <= 0;
		end
		else begin
			DOT_CE <= 0;
			DOTH_CE <= 0;
			
			DOTCLK_DIV <= DOTCLK_DIV + 3'd1;
			if (DOTCLK_DIV == 7) DOT_CE <= 1;
			if (DOTCLK_DIV == 3) DOTH_CE <= 1;
		end
	end
	
	assign DCLK = DOT_CE;
	
	bit VBLANK;
	bit HBLANK;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			H_CNT <= '0;
			V_CNT <= '0;
			HS_N <= 1;
			VS_N <= 1;
		end
		else if (DOT_CE) begin
			H_CNT <= H_CNT + 9'd1;
			if (H_CNT == HRES-1) begin
				H_CNT <= '0;
				V_CNT <= V_CNT + 9'd1;
				if (V_CNT == VRES-1) begin
					V_CNT <= '0;
				end
			end
			if (H_CNT == HS_START-1) begin
				HS_N <= 0;
			end else if (H_CNT == HS_END-1) begin
				HS_N <= 1;
			end
			if (H_CNT == HBL_START-1+20) begin
				HBLANK <= 1;
				if (V_CNT == VS_START-1) begin
					VS_N <= 0;
				end else if (V_CNT == VS_END-1) begin
					VS_N <= 1;
				end
				if (V_CNT == VBL_START-1) begin
					VBLANK <= 1;
				end else if (V_CNT == VRES-1) begin
					VBLANK <= 0;
				end
			end else if (H_CNT == 20-1) begin
				HBLANK <= 0;
			end
		end
	end
	assign VBL_N = ~VBLANK;
	assign HBL_N = ~HBLANK;
	
	
	bit BG_FETCH;
	bit SCRL_FETCH;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			BG_FETCH <= 0;
			SCRL_FETCH <= 0;
		end
		else if (DOT_CE) begin
			if (H_CNT == HRES-1) begin
				BG_FETCH <= 1;
			end else if (H_CNT == HBL_START-1) begin
				BG_FETCH <= 0;
				SCRL_FETCH <= 1;
			end else if (H_CNT == HBL_START+3-1) begin
				SCRL_FETCH <= 0;
			end
		end
	end
	
	always_comb begin
		VA_PIPE[0].H_CNT <= H_CNT;
		VA_PIPE[0].V_CNT <= V_CNT;
		if (VBLANK) begin
			VA_PIPE[0].VCPA0 <= VCP_CPU; 
			VA_PIPE[0].VCPA1 <= VCP_CPU; 
			VA_PIPE[0].VCPB0 <= VCP_CPU; 
			VA_PIPE[0].VCPB1 <= VCP_CPU;
		end else if (BG_FETCH) begin
			case (H_CNT[2:0])
				T0: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0L[15:12]; VA_PIPE[0].VCPA1 <= REGS.CYCA1L[15:12]; VA_PIPE[0].VCPB0 <= REGS.CYCB0L[15:12]; VA_PIPE[0].VCPB1 <= REGS.CYCB1L[15:12]; end
				T1: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0L[11: 8]; VA_PIPE[0].VCPA1 <= REGS.CYCA1L[11: 8]; VA_PIPE[0].VCPB0 <= REGS.CYCB0L[11: 8]; VA_PIPE[0].VCPB1 <= REGS.CYCB1L[11: 8]; end
				T2: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0L[ 7: 4]; VA_PIPE[0].VCPA1 <= REGS.CYCA1L[ 7: 4]; VA_PIPE[0].VCPB0 <= REGS.CYCB0L[ 7: 4]; VA_PIPE[0].VCPB1 <= REGS.CYCB1L[ 7: 4]; end
				T3: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0L[ 3: 0]; VA_PIPE[0].VCPA1 <= REGS.CYCA1L[ 3: 0]; VA_PIPE[0].VCPB0 <= REGS.CYCB0L[ 3: 0]; VA_PIPE[0].VCPB1 <= REGS.CYCB1L[ 3: 0]; end
				T4: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0U[15:12]; VA_PIPE[0].VCPA1 <= REGS.CYCA1U[15:12]; VA_PIPE[0].VCPB0 <= REGS.CYCB0U[15:12]; VA_PIPE[0].VCPB1 <= REGS.CYCB1U[15:12]; end
				T5: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0U[11: 8]; VA_PIPE[0].VCPA1 <= REGS.CYCA1U[11: 8]; VA_PIPE[0].VCPB0 <= REGS.CYCB0U[11: 8]; VA_PIPE[0].VCPB1 <= REGS.CYCB1U[11: 8]; end
				T6: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0U[ 7: 4]; VA_PIPE[0].VCPA1 <= REGS.CYCA1U[ 7: 4]; VA_PIPE[0].VCPB0 <= REGS.CYCB0U[ 7: 4]; VA_PIPE[0].VCPB1 <= REGS.CYCB1U[ 7: 4]; end
				T7: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0U[ 3: 0]; VA_PIPE[0].VCPA1 <= REGS.CYCA1U[ 3: 0]; VA_PIPE[0].VCPB0 <= REGS.CYCB0U[ 3: 0]; VA_PIPE[0].VCPB1 <= REGS.CYCB1U[ 3: 0]; end
			endcase
//			VA_PIPE[0].N0VA.PN = 
		end else if (SCRL_FETCH) begin
			VA_PIPE[0].VCPA0 <= VCP_NA; 
			VA_PIPE[0].VCPA1 <= VCP_NA; 
			VA_PIPE[0].VCPB0 <= VCP_NA; 
			VA_PIPE[0].VCPB1 <= VCP_NA;
		end else begin
			VA_PIPE[0].VCPA0 <= VCP_CPU; 
			VA_PIPE[0].VCPA1 <= VCP_CPU; 
			VA_PIPE[0].VCPB0 <= VCP_CPU; 
			VA_PIPE[0].VCPB1 <= VCP_CPU;
		end
		VA_PIPE[0].N0CH_CNT <= NBG_CH_CNT[0];
		VA_PIPE[0].N1CH_CNT <= NBG_CH_CNT[1];
		VA_PIPE[0].N2CH_CNT <= NBG_CH_CNT[2];
		VA_PIPE[0].N3CH_CNT <= NBG_CH_CNT[3];
		VA_PIPE[0].LSC0 = SCRL_FETCH;
	end
	
	assign VA_PIPE0 = VA_PIPE[0];
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			VA_PIPE[1] <= '0;
			VA_PIPE[2] <= '0;
			VA_PIPE[3] <= '0;
		end
		else if (DOT_CE) begin
			VA_PIPE[1] <= VA_PIPE[0];
			VA_PIPE[2] <= VA_PIPE[1];
			VA_PIPE[3] <= VA_PIPE[2];
		end
	end
	
	assign SCRX = H_CNT;
	assign SCRY = V_CNT;
	
	bit [2:0] NxCHCN[4];
	bit       NxCHSZ[4];
	bit [1:0] NxPLSZ[4];
	PNCNx_t   NxPNC[4];
	LSTAxL_t  NxLSTAL[2];
	LSTAxU_t  NxLSTAU[2];
	bit       NxLSCX[2];
	bit       NxLSCY[2];
	always_comb begin
		NxCHCN[0] = REGS.CHCTLA.N0CHCN;
		NxCHCN[1] = {1'b0,REGS.CHCTLA.N1CHCN};
		NxCHCN[2] = {2'b00,REGS.CHCTLB.N2CHCN};
		NxCHCN[3] = {2'b00,REGS.CHCTLB.N3CHCN};
		
		NxCHSZ[0] = REGS.CHCTLA.N0CHSZ;
		NxCHSZ[1] = REGS.CHCTLA.N1CHSZ;
		NxCHSZ[2] = REGS.CHCTLB.N2CHSZ;
		NxCHSZ[3] = REGS.CHCTLB.N3CHSZ;
		
		NxPLSZ[0] = REGS.PLSZ.N0PLSZ;
		NxPLSZ[1] = REGS.PLSZ.N1PLSZ;
		NxPLSZ[2] = REGS.PLSZ.N2PLSZ;
		NxPLSZ[3] = REGS.PLSZ.N3PLSZ;
		
		NxPNC[0] = REGS.PNCN0;
		NxPNC[1] = REGS.PNCN1;
		NxPNC[2] = REGS.PNCN2;
		NxPNC[3] = REGS.PNCN3;
		
		NxLSTAL[0] = REGS.LSTA0L;
		NxLSTAL[1] = REGS.LSTA1L;
		
		NxLSTAU[0] = REGS.LSTA0U;
		NxLSTAU[1] = REGS.LSTA1U;
		
		NxLSCX[0] = REGS.SCRCTL.N0LSCX;
		NxLSCX[1] = REGS.SCRCTL.N1LSCX;
		
		NxLSCY[0] = REGS.SCRCTL.N0LSCY;
		NxLSCY[1] = REGS.SCRCTL.N1LSCY;
	end
	
	bit       A0PN_SET,  A1PN_SET,  B0PN_SET,  B1PN_SET;
	bit       A0CH_SET,  A1CH_SET,  B0CH_SET,  B1CH_SET;
	bit       A0VS_SET,  A1VS_SET,  B0VS_SET,  B1VS_SET;
	bit       A0CPU_SET, A1CPU_SET, B0CPU_SET, B1CPU_SET;
	bit [1:0] A0Nx_SEL,  A1Nx_SEL,  B0Nx_SEL,  B1Nx_SEL;
	always_comb begin
		A0PN_SET = VA_PIPE[0].VCPA0 == VCP_N0PN | VA_PIPE[0].VCPA0 == VCP_N1PN | VA_PIPE[0].VCPA0 == VCP_N2PN | VA_PIPE[0].VCPA0 == VCP_N3PN;
		A0CH_SET = VA_PIPE[0].VCPA0 == VCP_N0CH | VA_PIPE[0].VCPA0 == VCP_N1CH | VA_PIPE[0].VCPA0 == VCP_N2CH | VA_PIPE[0].VCPA0 == VCP_N3CH;
		A0VS_SET = VA_PIPE[0].VCPA0 == VCP_N0VS | VA_PIPE[0].VCPA0 == VCP_N1VS;
		A0CPU_SET = VA_PIPE[0].VCPA0 == VCP_CPU;
		A0Nx_SEL = 2'd0;
		if (VA_PIPE[0].VCPA0 == VCP_N0PN || VA_PIPE[0].VCPA0 == VCP_N0CH || VA_PIPE[0].VCPA0 == VCP_N0VS) A0Nx_SEL = 2'd0;
		if (VA_PIPE[0].VCPA0 == VCP_N1PN || VA_PIPE[0].VCPA0 == VCP_N1CH || VA_PIPE[0].VCPA0 == VCP_N1VS) A0Nx_SEL = 2'd1;
		if (VA_PIPE[0].VCPA0 == VCP_N2PN || VA_PIPE[0].VCPA0 == VCP_N2CH)                                 A0Nx_SEL = 2'd2;
		if (VA_PIPE[0].VCPA0 == VCP_N3PN || VA_PIPE[0].VCPA0 == VCP_N3CH)                                 A0Nx_SEL = 2'd3;
		
		A1PN_SET = VA_PIPE[0].VCPA1 == VCP_N0PN | VA_PIPE[0].VCPA1 == VCP_N1PN | VA_PIPE[0].VCPA1 == VCP_N2PN | VA_PIPE[0].VCPA1 == VCP_N3PN;
		A1CH_SET = VA_PIPE[0].VCPA1 == VCP_N0CH | VA_PIPE[0].VCPA1 == VCP_N1CH | VA_PIPE[0].VCPA1 == VCP_N2CH | VA_PIPE[0].VCPA1 == VCP_N3CH;
		A1VS_SET = VA_PIPE[0].VCPA1 == VCP_N0VS | VA_PIPE[0].VCPA1 == VCP_N1VS;
		A1CPU_SET = VA_PIPE[0].VCPA1 == VCP_CPU;
		A1Nx_SEL = 2'd0;
		if (VA_PIPE[0].VCPA1 == VCP_N0PN || VA_PIPE[0].VCPA1 == VCP_N0CH || VA_PIPE[0].VCPA1 == VCP_N0VS) A1Nx_SEL = 2'd0;
		if (VA_PIPE[0].VCPA1 == VCP_N1PN || VA_PIPE[0].VCPA1 == VCP_N1CH || VA_PIPE[0].VCPA1 == VCP_N1VS) A1Nx_SEL = 2'd1;
		if (VA_PIPE[0].VCPA1 == VCP_N2PN || VA_PIPE[0].VCPA1 == VCP_N2CH)                                 A1Nx_SEL = 2'd2;
		if (VA_PIPE[0].VCPA1 == VCP_N3PN || VA_PIPE[0].VCPA1 == VCP_N3CH)                                 A1Nx_SEL = 2'd3;
		
		B0PN_SET = VA_PIPE[0].VCPB0 == VCP_N0PN | VA_PIPE[0].VCPB0 == VCP_N1PN | VA_PIPE[0].VCPB0 == VCP_N2PN | VA_PIPE[0].VCPB0 == VCP_N3PN;
		B0CH_SET = VA_PIPE[0].VCPB0 == VCP_N0CH | VA_PIPE[0].VCPB0 == VCP_N1CH | VA_PIPE[0].VCPB0 == VCP_N2CH | VA_PIPE[0].VCPB0 == VCP_N3CH;
		B0VS_SET = VA_PIPE[0].VCPB0 == VCP_N0VS | VA_PIPE[0].VCPB0 == VCP_N1VS;
		B0CPU_SET = VA_PIPE[0].VCPB0 == VCP_CPU;
		B0Nx_SEL = 2'd0;
		if (VA_PIPE[0].VCPB0 == VCP_N0PN || VA_PIPE[0].VCPB0 == VCP_N0CH || VA_PIPE[0].VCPB0 == VCP_N0VS) B0Nx_SEL = 2'd0;
		if (VA_PIPE[0].VCPB0 == VCP_N1PN || VA_PIPE[0].VCPB0 == VCP_N1CH || VA_PIPE[0].VCPB0 == VCP_N1VS) B0Nx_SEL = 2'd1;
		if (VA_PIPE[0].VCPB0 == VCP_N2PN || VA_PIPE[0].VCPB0 == VCP_N2CH)                                 B0Nx_SEL = 2'd2;
		if (VA_PIPE[0].VCPB0 == VCP_N3PN || VA_PIPE[0].VCPB0 == VCP_N3CH)                                 B0Nx_SEL = 2'd3;
		
		B1PN_SET = VA_PIPE[0].VCPB1 == VCP_N0PN | VA_PIPE[0].VCPB1 == VCP_N1PN | VA_PIPE[0].VCPB1 == VCP_N2PN | VA_PIPE[0].VCPB1 == VCP_N3PN;
		B1CH_SET = VA_PIPE[0].VCPB1 == VCP_N0CH | VA_PIPE[0].VCPB1 == VCP_N1CH | VA_PIPE[0].VCPB1 == VCP_N2CH | VA_PIPE[0].VCPB1 == VCP_N3CH;
		B1VS_SET = VA_PIPE[0].VCPB1 == VCP_N0VS | VA_PIPE[0].VCPB1 == VCP_N1VS;
		B1CPU_SET = VA_PIPE[0].VCPB1 == VCP_CPU;
		B1Nx_SEL = 2'd0;
		if (VA_PIPE[0].VCPB1 == VCP_N0PN || VA_PIPE[0].VCPB1 == VCP_N0CH || VA_PIPE[0].VCPB1 == VCP_N0VS) B1Nx_SEL = 2'd0;
		if (VA_PIPE[0].VCPB1 == VCP_N1PN || VA_PIPE[0].VCPB1 == VCP_N1CH || VA_PIPE[0].VCPB1 == VCP_N1VS) B1Nx_SEL = 2'd1;
		if (VA_PIPE[0].VCPB1 == VCP_N2PN || VA_PIPE[0].VCPB1 == VCP_N2CH)                                 B1Nx_SEL = 2'd2;
		if (VA_PIPE[0].VCPB1 == VCP_N3PN || VA_PIPE[0].VCPB1 == VCP_N3CH)                                 B1Nx_SEL = 2'd3;
	end
	
	ScrollData_t NxOFFX[4];
	ScrollData_t NxOFFY[4];
	bit NxPN_VRAMA0_A0,NxPN_VRAMA1_A0,NxPN_VRAMB0_A0,NxPN_VRAMB1_A0;
	bit NxOFFX3[4];
	ScrollData_t LSX[2];
	ScrollData_t LSY[2];
	CoordInc_t CIX;
	bit [18:17] NxLS_VRAM_BANK;
	always @(posedge CLK or negedge RST_N) begin
//		ScrollData_t NxOFFX[4];
//		ScrollData_t NxOFFY[4];
		bit   [19:1] NxPN_ADDR[4];
		bit   [19:1] NxCH_ADDR[4];
		bit   [19:1] N0VS_ADDR;
		bit   [19:1] NxLS_ADDR[2];
		
		NxOFFX[0] = {2'h0,SCRX,8'h00} + {REGS.SCXIN0.NxSCXI,REGS.SCXDN0.NxSCXD} + LSX[0];
		NxOFFY[0] = {2'h0,SCRY,8'h00} + {REGS.SCYIN0.NxSCYI,REGS.SCYDN0.NxSCYD} + LSY[0] + VS[0];
		NxOFFX[1] = {2'h0,SCRX,8'h00} + {REGS.SCXIN1.NxSCXI,REGS.SCXDN1.NxSCXD} + LSX[1];
		NxOFFY[1] = {2'h0,SCRY,8'h00} + {REGS.SCYIN1.NxSCYI,REGS.SCYDN1.NxSCYD} + LSY[1] + VS[1];
		NxOFFX[2] = {2'h0,SCRX,8'h00} + {REGS.SCXN2.NxSCX,8'h00};
		NxOFFY[2] = {2'h0,SCRY,8'h00} + {REGS.SCYN2.NxSCY,8'h00};
		NxOFFX[3] = {2'h0,SCRX,8'h00} + {REGS.SCXN3.NxSCX,8'h00};
		NxOFFY[3] = {2'h0,SCRY,8'h00} + {REGS.SCYN3.NxSCY,8'h00};

		NxPN_ADDR[0] = NxPNAddr(NxOFFX[0].INT, NxOFFY[0].INT, {REGS.MPOFN.N0MP,REGS.MPABN0.NxMPA}, NxPLSZ[0], NxCHSZ[0]);
		NxPN_ADDR[1] = NxPNAddr(NxOFFX[1].INT, NxOFFY[1].INT, {REGS.MPOFN.N1MP,REGS.MPABN1.NxMPA}, NxPLSZ[1], NxCHSZ[1]);
		NxPN_ADDR[2] = NxPNAddr(NxOFFX[2].INT, NxOFFY[2].INT, {REGS.MPOFN.N2MP,REGS.MPABN2.NxMPA}, NxPLSZ[2], NxCHSZ[2]);
		NxPN_ADDR[3] = NxPNAddr(NxOFFX[3].INT, NxOFFY[3].INT, {REGS.MPOFN.N3MP,REGS.MPABN3.NxMPA}, NxPLSZ[3], NxCHSZ[3]);
		
		NxCH_ADDR[0] = NxCHAddr(PN[0], NBG_CH_CNT[0], NxOFFX3[0], NxOFFY[0].INT, NxCHCN[0], NxCHSZ[0]);
		NxCH_ADDR[1] = NxCHAddr(PN[1], NBG_CH_CNT[1], NxOFFX3[1], NxOFFY[1].INT, NxCHCN[1], NxCHSZ[1]);
		NxCH_ADDR[2] = NxCHAddr(PN[2], NBG_CH_CNT[2], NxOFFX3[2], NxOFFY[2].INT, NxCHCN[2], NxCHSZ[2]);
		NxCH_ADDR[3] = NxCHAddr(PN[3], NBG_CH_CNT[3], NxOFFX3[3], NxOFFY[3].INT, NxCHCN[3], NxCHSZ[3]);
		
		N0VS_ADDR = {1'b0,REGS.VCSTAU.VCSTA,REGS.VCSTAL.VCSTA} + {13'h000,SCRX[8:3]};
		
		NxLS_ADDR[0] = {NxLSTAU[0].NxLSTA,NxLSTAL[0].NxLSTA,1'b0} + {9'h000,SCRY,1'b0};
		NxLS_ADDR[1] = {NxLSTAU[1].NxLSTA,NxLSTAL[1].NxLSTA,1'b0} + {9'h000,SCRY,1'b0};
		
		if (!RST_N) begin
			VRAMA0_A <= '0;
			VRAMA1_A <= '0;
			VRAMB0_A <= '0;
			VRAMB1_A <= '0;
			NBG_CH_CNT <= '{4{'0}};
		end
		else if (DOTH_CE) begin
			if (BG_FETCH) begin
				if (A0PN_SET) begin
					VRAMA0_A <= NxPN_ADDR[A0Nx_SEL][16:1];
					VRAMA0_RD <= 1;
				end else if (A0CH_SET) begin
					VRAMA0_A <= NxCH_ADDR[A0Nx_SEL][16:1];
					VRAMA0_RD <= 1;
				end else	if (A0VS_SET) begin
					VRAMA0_A <= N0VS_ADDR[16:1];
					VRAMA0_RD <= 1;
				end else	if (A0CPU_SET) begin
					VRAMA0_A <= A[16:1];
					VRAMA0_D <= DI;
					VRAMA0_WE <= ~WE_N & VRAM_SEL & A[18:17] == 2'b00;
					VRAMA0_RD <= 1;
				end
				
				if (A1PN_SET) begin
					VRAMA1_A <= NxPN_ADDR[A1Nx_SEL][16:1];
					VRAMA1_RD <= 1;
				end else	if (A1CH_SET) begin
					VRAMA1_A <= NxCH_ADDR[A1Nx_SEL][16:1];
					VRAMA1_RD <= 1;
				end else	if (A1VS_SET) begin
					VRAMA1_A <= N0VS_ADDR[16:1];
					VRAMA1_RD <= 1;
				end else	if (A1CPU_SET) begin
					VRAMA1_A <= A[16:1];
					VRAMA1_D <= DI;
					VRAMA1_WE <= ~WE_N & VRAM_SEL & A[18:17] == 2'b01;
					VRAMA1_RD <= 1;
				end
				
				if (B0PN_SET) begin
					VRAMB0_A <= NxPN_ADDR[B0Nx_SEL][16:1];
					VRAMB0_RD <= 1;
				end else	if (B0CH_SET) begin
					VRAMB0_A <= NxCH_ADDR[B0Nx_SEL][16:1];
					VRAMB0_RD <= 1;
				end else	if (B0VS_SET) begin
					VRAMB0_A <= N0VS_ADDR[16:1];
					VRAMB0_RD <= 1;
				end else	if (B0CPU_SET) begin
					VRAMB0_A <= A[16:1];
					VRAMB0_D <= DI;
					VRAMB0_WE <= ~WE_N & VRAM_SEL & A[18:17] == 2'b10;
					VRAMB0_RD <= 1;
				end
				
				if (B1PN_SET) begin
					VRAMB1_A <= NxPN_ADDR[B1Nx_SEL][16:1];
					VRAMB1_RD <= 1;
				end else	if (B1CH_SET) begin
					VRAMB1_A <= NxCH_ADDR[B1Nx_SEL][16:1];
					VRAMB1_RD <= 1;
				end else	if (B1VS_SET) begin
					VRAMB1_A <= N0VS_ADDR[16:1];
					VRAMB1_RD <= 1;
				end else	if (B1CPU_SET) begin
					VRAMB1_A <= A[16:1];
					VRAMB1_D <= DI;
					VRAMB1_WE <= ~WE_N & VRAM_SEL & A[18:17] == 2'b11;
					VRAMB1_RD <= 1;
				end
			end else if (SCRL_FETCH) begin
				VRAMA0_A <= NxLS_ADDR[0][16:1];
				VRAMA1_A <= NxLS_ADDR[0][16:1];
				VRAMB0_A <= NxLS_ADDR[0][16:1];
				VRAMB1_A <= NxLS_ADDR[0][16:1];
				case (NxLS_ADDR[0][18:17])
					2'b00: VRAMA0_RD <= 1;
					2'b01: VRAMA1_RD <= 1;
					2'b10: VRAMB0_RD <= 1;
					2'b11: VRAMB1_RD <= 1;
				endcase
			end
		end
		else if (DOT_CE) begin
			if (BG_FETCH) begin
				if (A0PN_SET) begin
					NxPN_VRAMA0_A0 <= NxPN_ADDR[A0Nx_SEL][1];
	//				NBG_CH_CNT[A0Nx_SEL] <= '0;
				end else if (A0CH_SET) begin
					NBG_CH_HF[A0Nx_SEL] <= PN[A0Nx_SEL].HF;
					NBG_CH_PALN[A0Nx_SEL] <= PN[A0Nx_SEL].PALN;
					NBG_CH_CNT[A0Nx_SEL] <= NBG_CH_CNT[A0Nx_SEL] + 3'd1;
				end
				
				if (A1PN_SET) begin
					NxPN_VRAMA1_A0 <= NxPN_ADDR[A1Nx_SEL][1];
	//				NBG_CH_CNT[A1Nx_SEL] <= '0;
				end else	if (A1CH_SET) begin
					NBG_CH_HF[A1Nx_SEL] <= PN[A1Nx_SEL].HF;
					NBG_CH_PALN[A1Nx_SEL] <= PN[A1Nx_SEL].PALN;
					NBG_CH_CNT[A1Nx_SEL] <= NBG_CH_CNT[A1Nx_SEL] + 3'd1;
				end
				
				if (B0PN_SET) begin
					NxPN_VRAMB0_A0 <= NxPN_ADDR[B0Nx_SEL][1];
	//				NBG_CH_CNT[B0Nx_SEL] <= '0;
				end else	if (B0CH_SET) begin
					NBG_CH_HF[B0Nx_SEL] <= PN[B0Nx_SEL].HF;
					NBG_CH_PALN[B0Nx_SEL] <= PN[B0Nx_SEL].PALN;
					NBG_CH_CNT[B0Nx_SEL] <= NBG_CH_CNT[B0Nx_SEL] + 3'd1;
				end
				
				if (B1PN_SET) begin
					NxPN_VRAMB1_A0 <= NxPN_ADDR[B1Nx_SEL][1];
	//				NBG_CH_CNT[B1Nx_SEL] <= '0;
				end else	if (B1CH_SET) begin
					NBG_CH_HF[B1Nx_SEL] <= PN[B1Nx_SEL].HF;
					NBG_CH_PALN[B1Nx_SEL] <= PN[B1Nx_SEL].PALN;
					NBG_CH_CNT[B1Nx_SEL] <= NBG_CH_CNT[B1Nx_SEL] + 3'd1;
				end
			end else if (SCRL_FETCH) begin
				NxLS_VRAM_BANK <= NxLS_ADDR[0][18:17];
			end
		end
	end
	
	assign N0OFFX = NxOFFX[0];
	assign N0OFFY = NxOFFY[0];
	
	bit       NxPNT_SET[4];
	bit [1:0] NxPNT_RAM[4];
	bit       NxPN_SET[4];
	bit       NxCDL_SET[4];
	bit [1:0] NxCDL_RAM[4];
	bit       NxVS_SET[4];
	bit       NxVCSC[2];
	bit       NxLSC;
	always_comb begin
		NxPNT_SET[0] = VA_PIPE[1].VCPA0 == VCP_N0PN | VA_PIPE[1].VCPA1 == VCP_N0PN | VA_PIPE[1].VCPB0 == VCP_N0PN | VA_PIPE[1].VCPB1 == VCP_N0PN;
		NxPNT_SET[1] = VA_PIPE[1].VCPA0 == VCP_N1PN | VA_PIPE[1].VCPA1 == VCP_N1PN | VA_PIPE[1].VCPB0 == VCP_N1PN | VA_PIPE[1].VCPB1 == VCP_N1PN;
		NxPNT_SET[2] = VA_PIPE[1].VCPA0 == VCP_N2PN | VA_PIPE[1].VCPA1 == VCP_N2PN | VA_PIPE[1].VCPB0 == VCP_N2PN | VA_PIPE[1].VCPB1 == VCP_N2PN;
		NxPNT_SET[3] = VA_PIPE[1].VCPA0 == VCP_N3PN | VA_PIPE[1].VCPA1 == VCP_N3PN | VA_PIPE[1].VCPB0 == VCP_N3PN | VA_PIPE[1].VCPB1 == VCP_N3PN;
		
		NxPNT_RAM[0] = VA_PIPE[1].VCPA0 == VCP_N0PN ? 2'd0 : 
							VA_PIPE[1].VCPA1 == VCP_N0PN ? 2'd1 : 
							VA_PIPE[1].VCPB0 == VCP_N0PN ? 2'd2 : 
							2'd3;
		NxPNT_RAM[1] = VA_PIPE[1].VCPA0 == VCP_N1PN ? 2'd0 : 
							VA_PIPE[1].VCPA1 == VCP_N1PN ? 2'd1 : 
							VA_PIPE[1].VCPB0 == VCP_N1PN ? 2'd2 : 
							2'd3;
		NxPNT_RAM[2] = VA_PIPE[1].VCPA0 == VCP_N2PN ? 2'd0 : 
							VA_PIPE[1].VCPA1 == VCP_N2PN ? 2'd1 : 
							VA_PIPE[1].VCPB0 == VCP_N2PN ? 2'd2 : 
							2'd3;
		NxPNT_RAM[3] = VA_PIPE[1].VCPA0 == VCP_N3PN ? 2'd0 : 
							VA_PIPE[1].VCPA1 == VCP_N3PN ? 2'd1 : 
							VA_PIPE[1].VCPB0 == VCP_N3PN ? 2'd2 : 
							2'd3;
							
		NxPN_SET[0] = VA_PIPE[2].VCPA0 == VCP_N0PN | VA_PIPE[2].VCPA1 == VCP_N0PN | VA_PIPE[2].VCPB0 == VCP_N0PN | VA_PIPE[2].VCPB1 == VCP_N0PN;
		NxPN_SET[1] = VA_PIPE[2].VCPA0 == VCP_N1PN | VA_PIPE[2].VCPA1 == VCP_N1PN | VA_PIPE[2].VCPB0 == VCP_N1PN | VA_PIPE[2].VCPB1 == VCP_N1PN;
		NxPN_SET[2] = VA_PIPE[2].VCPA0 == VCP_N2PN | VA_PIPE[2].VCPA1 == VCP_N2PN | VA_PIPE[2].VCPB0 == VCP_N2PN | VA_PIPE[2].VCPB1 == VCP_N2PN;
		NxPN_SET[3] = VA_PIPE[2].VCPA0 == VCP_N3PN | VA_PIPE[2].VCPA1 == VCP_N3PN | VA_PIPE[2].VCPB0 == VCP_N3PN | VA_PIPE[2].VCPB1 == VCP_N3PN;
		
		NxCDL_SET[0] = VA_PIPE[1].VCPA0 == VCP_N0CH | VA_PIPE[1].VCPA1 == VCP_N0CH | VA_PIPE[1].VCPB0 == VCP_N0CH | VA_PIPE[1].VCPB1 == VCP_N0CH;
		NxCDL_SET[1] = VA_PIPE[1].VCPA0 == VCP_N1CH | VA_PIPE[1].VCPA1 == VCP_N1CH | VA_PIPE[1].VCPB0 == VCP_N1CH | VA_PIPE[1].VCPB1 == VCP_N1CH;
		NxCDL_SET[2] = VA_PIPE[1].VCPA0 == VCP_N2CH | VA_PIPE[1].VCPA1 == VCP_N2CH | VA_PIPE[1].VCPB0 == VCP_N2CH | VA_PIPE[1].VCPB1 == VCP_N2CH;
		NxCDL_SET[3] = VA_PIPE[1].VCPA0 == VCP_N3CH | VA_PIPE[1].VCPA1 == VCP_N3CH | VA_PIPE[1].VCPB0 == VCP_N3CH | VA_PIPE[1].VCPB1 == VCP_N3CH;
		
		NxCDL_RAM[0] = VA_PIPE[1].VCPA0 == VCP_N0CH /*|| VA_PIPE[1].VCPA0 == VCP_N0VS*/ ? 2'd0 : 
							VA_PIPE[1].VCPA1 == VCP_N0CH /*|| VA_PIPE[1].VCPA1 == VCP_N0VS*/ ? 2'd1 : 
							VA_PIPE[1].VCPB0 == VCP_N0CH /*|| VA_PIPE[1].VCPB0 == VCP_N0VS*/ ? 2'd2 : 
							2'd3;
		NxCDL_RAM[1] = VA_PIPE[1].VCPA0 == VCP_N1CH /*|| VA_PIPE[1].VCPA0 == VCP_N1VS*/ ? 2'd0 : 
							VA_PIPE[1].VCPA1 == VCP_N1CH /*|| VA_PIPE[1].VCPA1 == VCP_N1VS*/ ? 2'd1 : 
							VA_PIPE[1].VCPB0 == VCP_N1CH /*|| VA_PIPE[1].VCPB0 == VCP_N1VS*/ ? 2'd2 : 
							2'd3;
		NxCDL_RAM[2] = VA_PIPE[1].VCPA0 == VCP_N2CH ? 2'd0 : 
							VA_PIPE[1].VCPA1 == VCP_N2CH ? 2'd1 : 
							VA_PIPE[1].VCPB0 == VCP_N2CH ? 2'd2 : 
							2'd3;
		NxCDL_RAM[3] = VA_PIPE[1].VCPA0 == VCP_N3CH ? 2'd0 : 
							VA_PIPE[1].VCPA1 == VCP_N3CH ? 2'd1 : 
							VA_PIPE[1].VCPB0 == VCP_N3CH ? 2'd2 : 
							2'd3;
		
		NxVS_SET[0] = VA_PIPE[1].VCPA0 == VCP_N0VS | VA_PIPE[1].VCPA1 == VCP_N0VS | VA_PIPE[1].VCPB0 == VCP_N0VS | VA_PIPE[1].VCPB1 == VCP_N0VS;
		NxVS_SET[1] = VA_PIPE[1].VCPA0 == VCP_N1VS | VA_PIPE[1].VCPA1 == VCP_N1VS | VA_PIPE[1].VCPB0 == VCP_N1VS | VA_PIPE[1].VCPB1 == VCP_N1VS;
		NxVS_SET[2] = 0;
		NxVS_SET[3] = 0;
		
		NxVCSC[0] = REGS.SCRCTL.N0VCSC;
		NxVCSC[1] = REGS.SCRCTL.N1VCSC;
		
		NxLSC = VA_PIPE[1].LSC0;
	end
	
	always @(posedge CLK or negedge RST_N) begin
		bit [31:0] PN_WD[4];
		bit        PN_A0[4];
		bit [31:0] CH_WD[4];
		bit  [2:0] CNT[4];
		bit        HF[4];
		bit  [6:0] PALN[4];
		bit [31:0] LS_WD[2];
		
		if (!RST_N) begin
			NBG_CDL[0] <= '{8{'0}};
			NBG_CDL[1] <= '{8{'0}};
			NBG_CDL[2] <= '{8{'0}};
			NBG_CDL[3] <= '{8{'0}};
			PNT[0] <= '0;
			PNT[1] <= '0;
			PNT[2] <= '0;
			PNT[3] <= '0;
			PN[0] <= '0;
			PN[1] <= '0;
			PN[2] <= '0;
			PN[3] <= '0;
			VS[0] <= '0; VS[1] <= '0;
			LSX[0] <= '0; LSX[1]<= '0;
			LSY[0] <= '0; LSY[1]<= '0;
		end
		else if (DOT_CE) begin
			CNT[0] = VA_PIPE[1].N0CH_CNT;
			CNT[1] = VA_PIPE[1].N1CH_CNT;
			CNT[2] = VA_PIPE[1].N2CH_CNT;
			CNT[3] = VA_PIPE[1].N3CH_CNT;
			for (int i=0; i<4; i++) begin
				if (NxCDL_SET[i]) begin
					case (NxCDL_RAM[i])
						2'd0: CH_WD[i] = {RA0_Q[15:0],RA0_Q[31:16]};
						2'd1: CH_WD[i] = {RA1_Q[15:0],RA1_Q[31:16]};
						2'd2: CH_WD[i] = {RB0_Q[15:0],RB0_Q[31:16]};
						2'd3: CH_WD[i] = {RB1_Q[15:0],RB1_Q[31:16]};
					endcase
					HF[i] = NBG_CH_HF[i];
					PALN[i] = NBG_CH_PALN[i];
					case (NxCHCN[i])
						3'b000: begin				//4bits/dot, 16 colors
							NBG_CDL[i][0 ^ {3{HF[i]}}] <= {1'b1,|CH_WD[i][31:28],{13'h0000,PALN[i],CH_WD[i][31:28]}};
							NBG_CDL[i][1 ^ {3{HF[i]}}] <= {1'b1,|CH_WD[i][27:24],{13'h0000,PALN[i],CH_WD[i][27:24]}};
							NBG_CDL[i][2 ^ {3{HF[i]}}] <= {1'b1,|CH_WD[i][23:20],{13'h0000,PALN[i],CH_WD[i][23:20]}};
							NBG_CDL[i][3 ^ {3{HF[i]}}] <= {1'b1,|CH_WD[i][19:16],{13'h0000,PALN[i],CH_WD[i][19:16]}};
							NBG_CDL[i][4 ^ {3{HF[i]}}] <= {1'b1,|CH_WD[i][15:12],{13'h0000,PALN[i],CH_WD[i][15:12]}};
							NBG_CDL[i][5 ^ {3{HF[i]}}] <= {1'b1,|CH_WD[i][11: 8],{13'h0000,PALN[i],CH_WD[i][11: 8]}};
							NBG_CDL[i][6 ^ {3{HF[i]}}] <= {1'b1,|CH_WD[i][ 7: 4],{13'h0000,PALN[i],CH_WD[i][ 7: 4]}};
							NBG_CDL[i][7 ^ {3{HF[i]}}] <= {1'b1,|CH_WD[i][ 3: 0],{13'h0000,PALN[i],CH_WD[i][ 3: 0]}};
						end
						3'b001: begin				//8bits/dot, 256 colors
							NBG_CDL[i][{CNT[i][0],2'b00} ^ {3{HF[i]}}] <= {1'b1,|CH_WD[i][31:24],{13'h0000,PALN[i][6:4],CH_WD[i][31:24]}};
							NBG_CDL[i][{CNT[i][0],2'b01} ^ {3{HF[i]}}] <= {1'b1,|CH_WD[i][23:16],{13'h0000,PALN[i][6:4],CH_WD[i][23:16]}};
							NBG_CDL[i][{CNT[i][0],2'b10} ^ {3{HF[i]}}] <= {1'b1,|CH_WD[i][15: 8],{13'h0000,PALN[i][6:4],CH_WD[i][15: 8]}};
							NBG_CDL[i][{CNT[i][0],2'b11} ^ {3{HF[i]}}] <= {1'b1,|CH_WD[i][ 7: 0],{13'h0000,PALN[i][6:4],CH_WD[i][ 7: 0]}};
						end
						3'b010: begin				//16bits/dot, 2048 colors
							NBG_CDL[i][{CNT[i][1:0],1'b0} ^ {3{HF[i]}}] <= {1'b1,|CH_WD[i][26:16],{13'h0000,CH_WD[i][26:16]}};
							NBG_CDL[i][{CNT[i][1:0],1'b1} ^ {3{HF[i]}}] <= {1'b1,|CH_WD[i][10: 0],{13'h0000,CH_WD[i][10: 0]}};
						end
						3'b011: begin				//16bits/dot, 32768 colors
							NBG_CDL[i][{CNT[i][1:0],1'b0} ^ {3{HF[i]}}] <= {1'b0,CH_WD[i][31],Color555To888(CH_WD[i][31:16])};
							NBG_CDL[i][{CNT[i][1:0],1'b1} ^ {3{HF[i]}}] <= {1'b0,CH_WD[i][15],Color555To888(CH_WD[i][15: 0])};
						end
						3'b100: begin				//32bits/dot, 16M colors
							NBG_CDL[i][CNT[i] ^ {3{HF[i]}}] <= {1'b0,CH_WD[i][31],CH_WD[i][23:0]};
						end
						default:;
					endcase
				end
				
				if (NxPNT_SET[i]) begin
					case (NxPNT_RAM[i])
						2'd0: PN_WD[i] = {RA0_Q[15:0],RA0_Q[31:16]};
						2'd1: PN_WD[i] = {RA1_Q[15:0],RA1_Q[31:16]};
						2'd2: PN_WD[i] = {RB0_Q[15:0],RB0_Q[31:16]};
						2'd3: PN_WD[i] = {RB1_Q[15:0],RB1_Q[31:16]};
					endcase
					case (NxPNT_RAM[i])
						2'd0: PN_A0[i] = NxPN_VRAMA0_A0;
						2'd1: PN_A0[i] = NxPN_VRAMA1_A0;
						2'd2: PN_A0[i] = NxPN_VRAMB0_A0;
						2'd3: PN_A0[i] = NxPN_VRAMB1_A0;
					endcase
					if (!NxPNC[i].NxPNB) begin
						PNT[i] <= PN_WD[i];
					end else begin
						PNT[i] <= PNOneWord(NxPNC[i], NxCHSZ[i], NxCHCN[i], !PN_A0[i] ? PN_WD[i][31:16] : PN_WD[i][15: 0]);
					end
				end
				
				if (NxPN_SET[i]) begin
					PN[i] <= PNT[i];
					NxOFFX3[i] <= NxOFFX[i].INT[3];
				end
			end
			
			for (int i=0; i<2; i++) begin
				if (NxVS_SET[i]) begin
					VS[i].INT  <= PN_WD[i][26:16] & {11{NxVCSC[i]}};
					VS[i].FRAC <= PN_WD[i][15: 8] & { 8{NxVCSC[i]}};
				end
				
				if (NxLSC) begin
					case (NxLS_VRAM_BANK/*[i]*/)
						2'b00: LS_WD[i] = {RA0_Q[15:0],RA0_Q[31:16]};
						2'b01: LS_WD[i] = {RA1_Q[15:0],RA1_Q[31:16]};
						2'b10: LS_WD[i] = {RB0_Q[15:0],RB0_Q[31:16]};
						2'b11: LS_WD[i] = {RB1_Q[15:0],RB1_Q[31:16]};
					endcase
					LSX[i].INT  <= LS_WD[i][26:16] & {11{NxLSCX[i]}};
//					LSX[i].FRAC <= LS_WD[i][15: 8] & { 8{NxLSCX[i]}};
				end
			end
		end
	end
		
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			
		end
		else if (DOT_CE) begin
			case (VA_PIPE[1].VCPA0)
				VCP_CPU: begin
					VRAMA0_Q <= VRAMA0_A[1] ? RA0_Q[15:0] : RA0_Q[31:16];
				end

				default:;
			endcase
			
			case (VA_PIPE[1].VCPA1)
				VCP_CPU: begin
					VRAMA1_Q <= VRAMA1_A[1] ? RA1_Q[15:0] : RA1_Q[31:16];
				end
				
				default:;
			endcase
			
			case (VA_PIPE[1].VCPB0)
				VCP_CPU: begin
					VRAMB0_Q <= VRAMB0_A[1] ? RB0_Q[15:0] : RB0_Q[31:16];
				end

				default:;
			endcase
			
			case (VA_PIPE[1].VCPB1)
				VCP_CPU: begin
					VRAMB1_Q <= VRAMB1_A[1] ? RB1_Q[15:0] : RB1_Q[31:16];
				end
				
				default:;
			endcase
		end
	end
	
	assign RA0_A = VRAMA0_A;
	assign RA0_D = VRAMA0_D;
	assign RA0_WE = VRAMA0_WE;
	assign RA0_RD = VRAMA0_RD;//VA_PIPE[0].VCPA0 != VCP_NA /*& VRAM_SEL*/;
	
	assign RA1_A = VRAMA1_A;
	assign RA1_D = VRAMA1_D;
	assign RA1_WE = VRAMA1_WE;
	assign RA1_RD = VRAMA1_RD;//VA_PIPE[0].VCPA1 != VCP_NA /*& VRAM_SEL*/;
	
	assign RB0_A = VRAMB0_A;
	assign RB0_D = VRAMB0_D;
	assign RB0_WE = VRAMB0_WE;
	assign RB0_RD = VRAMB0_RD;//VA_PIPE[0].VCPB0 != VCP_NA /*& VRAM_SEL*/;
	
	assign RB1_A = VRAMB1_A;
	assign RB1_D = VRAMB1_D;
	assign RB1_WE = VRAMB1_WE;
	assign RB1_RD = VRAMB1_RD;//VA_PIPE[0].VCPB1 != VCP_NA /*& VRAM_SEL*/;

	wire [15:0] VRAM_DO = A[18:17] == 2'b00 ? VRAMA0_Q :
	                      A[18:17] == 2'b01 ? VRAMA1_Q :
							    A[18:17] == 2'b10 ? VRAMB0_Q :
								 VRAMB1_Q;

	DotsBuffer_t N0DB, N1DB, N2DB, N3DB;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			N0DB <= '{16{'0}};
			N1DB <= '{16{'0}};
			N2DB <= '{16{'0}};
			N2DB <= '{16{'0}};
		end
		else if (DOT_CE) begin
			case (SCRX[2:0])
				T0: begin  end
				T1: begin  end
				T2: begin  end
				T3: begin  end
				T4: begin
					for (int i=0; i<8; i++) begin
						N0DB[i] <= N0DB[i+8]; N0DB[i+8] <= NBG_CDL[0][i];
						N1DB[i] <= N1DB[i+8]; N1DB[i+8] <= NBG_CDL[1][i];
						N2DB[i] <= N2DB[i+8]; N2DB[i+8] <= NBG_CDL[2][i];
						N3DB[i] <= N3DB[i+8]; N3DB[i+8] <= NBG_CDL[3][i];
					end
				end
				T5: begin  end
				T6: begin  end
				T7: begin  end
			endcase
		end
	end
	
	wire [3:0] N0DOTN = {1'b0,SCRX[2:0] - 3'd5} + {1'b0,REGS.SCXIN0.NxSCXI[2:0] + LSX[0].INT[2:0]};
	wire [3:0] N1DOTN = {1'b0,SCRX[2:0] - 3'd5} + {1'b0,REGS.SCXIN1.NxSCXI[2:0]};
	wire [3:0] N2DOTN = {1'b0,SCRX[2:0] - 3'd5} + {1'b0,REGS.SCXN2.NxSCX[2:0]};
	wire [3:0] N3DOTN = {1'b0,SCRX[2:0] - 3'd5} + {1'b0,REGS.SCXN3.NxSCX[2:0]};
	DotData_t DOT;
	DotData_t N0DOT,N1DOT,N2DOT,N3DOT;
	always_comb begin
		
		
		N0DOT = N0DB[N0DOTN];
		N1DOT = N1DB[N1DOTN];
		N2DOT = N2DB[N2DOTN];
		N3DOT = N3DB[N3DOTN];
		
		DOT = DD_NULL;
		if (N0DOT.TP) begin
			DOT = N0DOT;
		end
		if (N1DOT.TP && (REGS.PRINA.N1PRIN > REGS.PRINA.N0PRIN || !N0DOT.TP)) begin
			DOT = N1DOT;
		end
		if (N2DOT.TP && (REGS.PRINB.N2PRIN > REGS.PRINA.N1PRIN || !N1DOT.TP) && 
		                (REGS.PRINB.N2PRIN > REGS.PRINA.N0PRIN || !N0DOT.TP)) begin
			DOT = N2DOT;
		end
		if (N3DOT.TP && (REGS.PRINB.N3PRIN > REGS.PRINB.N2PRIN || !N2DOT.TP) && 
		                (REGS.PRINB.N3PRIN > REGS.PRINA.N1PRIN || !N1DOT.TP) && 
		                (REGS.PRINB.N3PRIN > REGS.PRINA.N0PRIN || !N0DOT.TP)) begin
			DOT = N3DOT;
		end
	end
	
	assign N0DOT_DBG = N0DOT;
	assign N1DOT_DBG = N1DOT;
	assign DOT_DBG = DOT;
	
	DotColor_t DCOL;
	always_comb begin
		if (DOT.P) begin
			DCOL <= {DOT.TP,Color555To888(PAL_Q)};
		end else begin
			DCOL <= {DOT.TP,DOT.D};
		end
	end

	assign R = DCOL.R;
	assign G = DCOL.G;
	assign B = DCOL.B;
	
	assign PAL_A = DOT.D[10:0];
	
	wire PAL_SEL = A[20:19] == 2'b10;	//100000-17FFFF
	VDP2_DPRAM #(11,16,"scroll/pal.mif","") pal 
	(
		.CLK(CLK),
		
		.ADDR_A(PAL_A),
		.DATA_A(16'h0000),
		.WREN_A(1'b0),
		.Q_A(PAL_Q),
		
		.ADDR_B(A[11:1]),
		.DATA_B(DI),
		.WREN_B(PAL_SEL & ~CS_N & ~WE_N & CE_F),
		.Q_B(PAL_DO)
	);
	
	//Registers
	wire REG_SEL = A[20:18] == 3'b110;	//180000-1BFFFF
	
	bit [15:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		
		if (!RST_N) begin
			REGS.TVMD <= '0;
			REGS.EXTEN <= '0;
			REGS.TVSTAT <= '0;
			REGS.VRSIZE <= '0;
			REGS.HCNT <= '0;
			REGS.VCNT <= '0;
			REGS.RSRV0 <= '0;
			REGS.RAMCTL <= '0;
			REGS.CYCA0L <= '0;
			REGS.CYCA0U <= '0;
			REGS.CYCA1L <= '0;
			REGS.CYCA1U <= '0;
			REGS.CYCB0L <= '0;
			REGS.CYCB0U <= '0;
			REGS.CYCB1L <= '0;
			REGS.CYCB1U <= '0;
			REGS.BGON <= '0;
			REGS.MZCTL <= '0;
			REGS.SFSEL <= '0;
			REGS.SFCODE <= '0;
			REGS.CHCTLA <= '0;
			REGS.CHCTLB <= '0;
			REGS.BMPNA <= '0;
			REGS.BMPNB <= '0;
			REGS.PNCN0 <= '0;
			REGS.PNCN1 <= '0;
			REGS.PNCN2 <= '0;
			REGS.PNCN3 <= '0;
			REGS.PNCR <= '0;
			REGS.PLSZ <= '0;
			REGS.MPOFN <= '0;
			REGS.MPOFR <= '0;
			REGS.MPABN0 <= '0;
			REGS.MPCDN0 <= '0;
			REGS.MPABN1 <= '0;
			REGS.MPCDN1 <= '0;
			REGS.MPABN2 <= '0;
			REGS.MPCDN2 <= '0;
			REGS.MPABN3 <= '0;
			REGS.MPCDN3 <= '0;
			REGS.MPABRA <= '0;
			REGS.MPCDRA <= '0;
			REGS.MPEFRA <= '0;
			REGS.MPGHRA <= '0;
			REGS.MPIJRA <= '0;
			REGS.MPKLRA <= '0;
			REGS.MPMNRA <= '0;
			REGS.MPOPRA <= '0;
			REGS.MPABRB <= '0;
			REGS.MPCDRB <= '0;
			REGS.MPEFRB <= '0;
			REGS.MPGHRB <= '0;
			REGS.MPIJRB <= '0;
			REGS.MPKLRB <= '0;
			REGS.MPMNRB <= '0;
			REGS.MPOPRB <= '0;
			REGS.SCXIN0 <= '0;
			REGS.SCXDN0 <= '0;
			REGS.SCYIN0 <= '0;
			REGS.SCYDN0 <= '0;
			REGS.ZMXIN0 <= '0;
			REGS.ZMXDN0 <= '0;
			REGS.ZMYIN0 <= '0;
			REGS.ZMYDN0 <= '0;
			REGS.SCXIN1 <= '0;
			REGS.SCXDN1 <= '0;
			REGS.SCYIN1 <= '0;
			REGS.SCYDN1 <= '0;
			REGS.ZMXIN1 <= '0;
			REGS.ZMXDN1 <= '0;
			REGS.ZMYIN1 <= '0;
			REGS.ZMYDN1 <= '0;
			REGS.SCXN2 <= '0;
			REGS.SCYN2 <= '0;
			REGS.SCXN3 <= '0;
			REGS.SCYN3 <= '0;
			REGS.ZMCTL <= '0;
			REGS.SCRCTL <= '0;
			REGS.VCSTAU <= '0;
			REGS.VCSTAL <= '0;
			REGS.LSTA0U <= '0;
			REGS.LSTA0L <= '0;
			REGS.LSTA1U <= '0;
			REGS.LSTA1L <= '0;
			REGS.LCTAU <= '0;
			REGS.LCTAL <= '0;
			REGS.BKTAU <= '0;
			REGS.BKTAL <= '0;
			REGS.RPMD <= '0;
			REGS.RPRCTL <= '0;
			REGS.KTCTL <= '0;
			REGS.KTAOF <= '0;
			REGS.OVPNRA <= '0;
			REGS.OVPNRB <= '0;
			REGS.RPTAU <= '0;
			REGS.RPTAL <= '0;
			REGS.WPSX0 <= '0;
			REGS.WPSY0 <= '0;
			REGS.WPEX0 <= '0;
			REGS.WPEY0 <= '0;
			REGS.WPSX1 <= '0;
			REGS.WPSY1 <= '0;
			REGS.WPEX1 <= '0;
			REGS.WPEY1 <= '0;
			REGS.WCTLA <= '0;
			REGS.WCTLB <= '0;
			REGS.WCTLC <= '0;
			REGS.WCTLD <= '0;
			REGS.LWTA0U <= '0;
			REGS.LWTA0L <= '0;
			REGS.LWTA1U <= '0;
			REGS.LWTA1L <= '0;
			REGS.SPCTL <= '0;
			REGS.SDCTL <= '0;
			REGS.CRAOFA <= '0;
			REGS.CRAOFB <= '0;
			REGS.LNCLEN <= '0;
			REGS.SFPRMD <= '0;
			REGS.CCCTL <= '0;
			REGS.SFCCMD <= '0;
			REGS.PRISA <= '0;
			REGS.PRISB <= '0;
			REGS.PRISC <= '0;
			REGS.PRISD <= '0;
			REGS.PRINA <= '0;
			REGS.PRINB <= '0;
			REGS.PRIR <= '0;
			REGS.RSRV1 <= '0;
			REGS.CCRSA <= '0;
			REGS.CCRSB <= '0;
			REGS.CCRSC <= '0;
			REGS.CCRSD <= '0;
			REGS.CCRNA <= '0;
			REGS.CCRNB <= '0;
			REGS.CCRR <= '0;
			REGS.CCRLB <= '0;
			REGS.CLOFEN <= '0;
			REGS.CLOFSL <= '0;
			REGS.COAR <= '0;
			REGS.COAG <= '0;
			REGS.COAB <= '0;
			REGS.COBR <= '0;
			REGS.COBG <= '0;
			REGS.COBB <= '0;
			
//			REGS.CYCA0L <= 16'h0551;
//			REGS.CYCA0U <= 16'h4444;
//			REGS.CYCA1L <= 16'h0551;
//			REGS.CYCA1U <= 16'h4444;
//			REGS.CYCB0L <= 16'hFFFF;
//			REGS.CYCB0U <= 16'hFFFF;
//			REGS.CYCB1L <= 16'hFFFF;
//			REGS.CYCB1U <= 16'hFFFF;
//			REGS.CHCTLA <= 16'h1030;
//			REGS.MPOFN <= 16'h0000;		//
//			REGS.MPABN0 <= 16'h0001;	//N0 - 02000H
//			REGS.MPABN1 <= 16'h0002;	//N1 - 04000H
//			REGS.SCXIN0 <= 16'h0000;
//			REGS.PRINA <= 16'h0506;
			
			REGS.CYCA0L <= 16'h44FF;
			REGS.CYCA0U <= 16'hFFFF;
			REGS.CYCA1L <= 16'hFFFF;
			REGS.CYCA1U <= 16'hFFFF;
			REGS.CYCB0L <= 16'h0FFF;
			REGS.CYCB0U <= 16'hFFFF;
			REGS.CYCB1L <= 16'hFFFF;
			REGS.CYCB1U <= 16'hFFFF;
			REGS.CHCTLA <= 16'h0011;
			REGS.MPABN0 <= 16'h0000;
			REGS.PNCN0 <= 16'hC000;
			REGS.PRINA <= 16'h0006;
			{REGS.LSTA0U,REGS.LSTA0L} <= 32'h00010000;
			REGS.SCRCTL <= 16'h0002;
			// synopsys translate_off
			// synopsys translate_on
			REG_DO <= '0;
		end
		else begin
			if (!RES_N) begin
				
			end else begin
				if (REG_SEL) begin
					if (!CS_N && !WE_N && CE_F) begin
						case ({A[8:1],1'b0})
							9'h000: REGS.TVMD <= DI & TVMD_MASK;
							9'h002: REGS.EXTEN <= DI & EXTEN_MASK;
							9'h006: REGS.VRSIZE <= DI & VRSIZE_MASK;
							9'h00C: REGS.RSRV0 <= DI & RSRV_MASK;
							9'h00E: REGS.RAMCTL <= DI & RAMCTL_MASK;
							9'h010: REGS.CYCA0L <= DI & CYCx0L_MASK;
							9'h012: REGS.CYCA0U <= DI & CYCx0U_MASK;
							9'h014: REGS.CYCA1L <= DI & CYCx1L_MASK;
							9'h016: REGS.CYCA1U <= DI & CYCx1U_MASK;
							9'h018: REGS.CYCB0L <= DI & CYCx0L_MASK;
							9'h01A: REGS.CYCB0U <= DI & CYCx0U_MASK;
							9'h01C: REGS.CYCB1L <= DI & CYCx1L_MASK;
							9'h01E: REGS.CYCB1U <= DI & CYCx1U_MASK;
							9'h020: REGS.BGON <= DI & BGON_MASK;
							9'h022: REGS.MZCTL <= DI & MZCTL_MASK;
							9'h024: REGS.SFSEL <= DI & SFSEL_MASK;
							9'h026: REGS.SFCODE <= DI & SFCODE_MASK;
							9'h028: REGS.CHCTLA <= DI & CHCTLA_MASK;
							9'h02A: REGS.CHCTLB <= DI & CHCTLB_MASK;
							9'h02C: REGS.BMPNA <= DI & BMPNA_MASK;
							9'h02E: REGS.BMPNB <= DI & BMPNB_MASK;
							9'h030: REGS.PNCN0 <= DI & PNCNx_MASK;
							9'h032: REGS.PNCN1 <= DI & PNCNx_MASK;
							9'h034: REGS.PNCN2 <= DI & PNCNx_MASK;
							9'h036: REGS.PNCN3 <= DI & PNCNx_MASK;
							9'h038: REGS.PNCR <= DI & PNCR_MASK;
							9'h03A: REGS.PLSZ <= DI & PLSZ_MASK;
							9'h03C: REGS.MPOFN <= DI & MPOFN_MASK;
							9'h03E: REGS.MPOFR <= DI & MPOFR_MASK;
							9'h040: REGS.MPABN0 <= DI & MPABNx_MASK;
							9'h042: REGS.MPCDN0 <= DI & MPCDNx_MASK;
							9'h044: REGS.MPABN1 <= DI & MPABNx_MASK;
							9'h046: REGS.MPCDN1 <= DI & MPCDNx_MASK;
							9'h048: REGS.MPABN2 <= DI & MPABNx_MASK;
							9'h04A: REGS.MPCDN2 <= DI & MPCDNx_MASK;
							9'h04C: REGS.MPABN3 <= DI & MPABNx_MASK;
							9'h04E: REGS.MPCDN3 <= DI & MPCDNx_MASK;
							9'h050: REGS.MPABRA <= DI & MPABRx_MASK;
							9'h052: REGS.MPCDRA <= DI & MPCDRx_MASK;
							9'h054: REGS.MPEFRA <= DI & MPEFRx_MASK;
							9'h056: REGS.MPGHRA <= DI & MPGHRx_MASK;
							9'h058: REGS.MPIJRA <= DI & MPIJRx_MASK;
							9'h05A: REGS.MPKLRA <= DI & MPKLRx_MASK;
							9'h05C: REGS.MPMNRA <= DI & MPMNRx_MASK;
							9'h05E: REGS.MPOPRA <= DI & MPOPRx_MASK;
							9'h060: REGS.MPABRB <= DI & MPABRx_MASK;
							9'h062: REGS.MPCDRB <= DI & MPCDRx_MASK;
							9'h064: REGS.MPEFRB <= DI & MPEFRx_MASK;
							9'h066: REGS.MPGHRB <= DI & MPGHRx_MASK;
							9'h068: REGS.MPIJRB <= DI & MPIJRx_MASK;
							9'h06A: REGS.MPKLRB <= DI & MPKLRx_MASK;
							9'h06C: REGS.MPMNRB <= DI & MPMNRx_MASK;
							9'h06E: REGS.MPOPRB <= DI & MPOPRx_MASK;
							9'h070: REGS.SCXIN0 <= DI & SCXINx_MASK;
							9'h072: REGS.SCXDN0 <= DI & SCXDNx_MASK;
							9'h074: REGS.SCYIN0 <= DI & SCYINx_MASK;
							9'h076: REGS.SCYDN0 <= DI & SCYDNx_MASK;
							9'h078: REGS.ZMXIN0 <= DI & ZMXINx_MASK;
							9'h07A: REGS.ZMXDN0 <= DI & ZMXDNx_MASK;
							9'h07C: REGS.ZMYIN0 <= DI & ZMYINx_MASK;
							9'h07E: REGS.ZMYDN0 <= DI & ZMYDNx_MASK;
							9'h080: REGS.SCXIN1 <= DI & SCXINx_MASK;
							9'h082: REGS.SCXDN1 <= DI & SCXDNx_MASK;
							9'h084: REGS.SCYIN1 <= DI & SCYINx_MASK;
							9'h086: REGS.SCYDN1 <= DI & SCYDNx_MASK;
							9'h088: REGS.ZMXIN1 <= DI & ZMXINx_MASK;
							9'h08A: REGS.ZMXDN1 <= DI & ZMXDNx_MASK;
							9'h08C: REGS.ZMYIN1 <= DI & ZMYINx_MASK;
							9'h08E: REGS.ZMYDN1 <= DI & ZMYDNx_MASK;
							9'h090: REGS.SCXN2 <= DI & SCXNx_MASK;
							9'h092: REGS.SCYN2 <= DI & SCYNx_MASK;
							9'h094: REGS.SCXN3 <= DI & SCXNx_MASK;
							9'h096: REGS.SCYN3 <= DI & SCYNx_MASK;
							9'h098: REGS.ZMCTL <= DI & ZMCTL_MASK;
							9'h09A: REGS.SCRCTL <= DI & SCRCTL_MASK;
							9'h09C: REGS.VCSTAU <= DI & VCSTAU_MASK;
							9'h09E: REGS.VCSTAL <= DI & VCSTAL_MASK;
							9'h0A0: REGS.LSTA0U <= DI & LSTAxU_MASK;
							9'h0A2: REGS.LSTA0L <= DI & LSTAxL_MASK;
							9'h0A4: REGS.LSTA1U <= DI & LSTAxU_MASK;
							9'h0A6: REGS.LSTA1L <= DI & LSTAxL_MASK;
							9'h0A8: REGS.LCTAU <= DI & LCTAU_MASK;
							9'h0AA: REGS.LCTAL <= DI & LCTAL_MASK;
							9'h0AC: REGS.BKTAU <= DI & BKTAU_MASK;
							9'h0AE: REGS.BKTAL <= DI & BKTAL_MASK;
							9'h0B0: REGS.RPMD <= DI & RPMD_MASK;
							9'h0B2: REGS.RPRCTL <= DI & RPRCTL_MASK;
							9'h0B4: REGS.KTCTL <= DI & KTCTL_MASK;
							9'h0B6: REGS.KTAOF <= DI & KTAOF_MASK;
							9'h0B8: REGS.OVPNRA <= DI & OVPNRx_MASK;
							9'h0BA: REGS.OVPNRB <= DI & OVPNRx_MASK;
							9'h0BC: REGS.RPTAU <= DI & RPTAU_MASK;
							9'h0BE: REGS.RPTAL <= DI & RPTAL_MASK;
							9'h0C0: REGS.WPSX0 <= DI & WPSXx_MASK;
							9'h0C2: REGS.WPSY0 <= DI & WPSYx_MASK;
							9'h0C4: REGS.WPEX0 <= DI & WPEXx_MASK;
							9'h0C6: REGS.WPEY0 <= DI & WPEYx_MASK;
							9'h0C8: REGS.WPSX1 <= DI & WPSXx_MASK;
							9'h0CA: REGS.WPSY1 <= DI & WPSYx_MASK;
							9'h0CC: REGS.WPEX1 <= DI & WPEXx_MASK;
							9'h0CE: REGS.WPEY1 <= DI & WPEYx_MASK;
							9'h0D0: REGS.WCTLA <= DI & WCTLA_MASK;
							9'h0D2: REGS.WCTLB <= DI & WCTLB_MASK;
							9'h0D4: REGS.WCTLC <= DI & WCTLC_MASK;
							9'h0D6: REGS.WCTLD <= DI & WCTLD_MASK;
							9'h0D8: REGS.LWTA0U <= DI & LWTAxU_MASK;
							9'h0DA: REGS.LWTA0L <= DI & LWTAxL_MASK;
							9'h0DC: REGS.LWTA1U <= DI & LWTAxU_MASK;
							9'h0DE: REGS.LWTA1L <= DI & LWTAxL_MASK;
							9'h0E0: REGS.SPCTL <= DI & SPCTL_MASK;
							9'h0E2: REGS.SDCTL <= DI & SDCTL_MASK;
							9'h0E4: REGS.CRAOFA <= DI & CRAOFA_MASK;
							9'h0E6: REGS.CRAOFB <= DI & CRAOFB_MASK;
							9'h0E8: REGS.LNCLEN <= DI & LNCLEN_MASK;
							9'h0EA: REGS.SFPRMD <= DI & SFPRMD_MASK;
							9'h0EC: REGS.CCCTL <= DI & CCCTL_MASK;
							9'h0EE: REGS.SFCCMD <= DI & SFCCMD_MASK;
							9'h0F0: REGS.PRISA <= DI & PRISA_MASK;
							9'h0F2: REGS.PRISB <= DI & PRISB_MASK;
							9'h0F4: REGS.PRISC <= DI & PRISC_MASK;
							9'h0F6: REGS.PRISD <= DI & PRISD_MASK;
							9'h0F8: REGS.PRINA <= DI & PRINA_MASK;
							9'h0FA: REGS.PRINB <= DI & PRINB_MASK;
							9'h0FC: REGS.PRIR <= DI & PRIR_MASK;
							9'h0FE: REGS.RSRV1 <= DI & RSRV_MASK;
							9'h100: REGS.CCRSA <= DI & CCRSA_MASK;
							9'h102: REGS.CCRSB <= DI & CCRSB_MASK;
							9'h104: REGS.CCRSC <= DI & CCRSC_MASK;
							9'h106: REGS.CCRSD <= DI & CCRSD_MASK;
							9'h108: REGS.CCRNA <= DI & CCRNA_MASK;
							9'h10A: REGS.CCRNB <= DI & CCRNA_MASK;
							9'h10C: REGS.CCRR <= DI & CCRR_MASK;
							9'h10E: REGS.CCRLB <= DI & CCRLB_MASK;
							9'h110: REGS.CLOFEN <= DI & CLOFEN_MASK;
							9'h112: REGS.CLOFSL <= DI & CLOFSL_MASK;
							9'h114: REGS.COAR <= DI & COxR_MASK;
							9'h116: REGS.COAG <= DI & COxG_MASK;
							9'h118: REGS.COAB <= DI & COxB_MASK;
							9'h11A: REGS.COBR <= DI & COxR_MASK;
							9'h11C: REGS.COBG <= DI & COxG_MASK;
							9'h11E: REGS.COBB <= DI & COxB_MASK;
							default:;
						endcase
					end else if (!CS_N && !RD_N && CE_R) begin
						case ({A[8:1],1'b0})
							9'h000: REG_DO <= REGS.TVMD & TVMD_MASK;
							9'h002: REG_DO <= REGS.EXTEN & EXTEN_MASK;
							9'h004: REG_DO <= REGS.TVSTAT & TVSTAT_MASK;
							9'h006: REG_DO <= REGS.VRSIZE & VRSIZE_MASK;
							9'h008: REG_DO <= REGS.HCNT & HCNT_MASK;
							9'h00A: REG_DO <= REGS.VCNT & VCNT_MASK;
							9'h00E: REG_DO <= REGS.RAMCTL & RAMCTL_MASK;
							default: REG_DO <= '0;
						endcase
					end
				end
			end
		end
	end
	
	assign DO = REG_SEL ? REG_DO : 
	            PAL_SEL ? PAL_DO : 
					VRAM_DO;
	assign RDY_N = 1;
	
	assign VINT_N = ~VBLANK;
	assign HINT_N = ~HBLANK;
	
//	assign REG_DBG = REGS.TVMD^REGS.EXTEN^REGS.VRSIZE^REGS.RAMCTL^REGS.CYCA0L^REGS.CYCA0U^REGS.CYCA1L^REGS.CYCA1U^REGS.CYCB0L^
//						   REGS.CYCB0U^REGS.CYCB1L^REGS.CYCB1U^REGS.BGON^REGS.MZCTL^REGS.SFSEL^REGS.SFCODE^REGS.CHCTLA^REGS.CHCTLB^REGS.BMPNA^REGS.BMPNB^
//							REGS.PNCN0^REGS.PNCN1^REGS.PNCN2^REGS.PNCN3^REGS.PNCR^REGS.PLSZ^REGS.MPOFN^REGS.MPOFR^REGS.MPABN0^REGS.MPCDN0^REGS.MPABN1^REGS.MPCDN1^REGS.MPABN2^
//							REGS.MPCDN2^REGS.MPABN3^REGS.MPCDN3^REGS.MPABRA^REGS.MPCDRA^REGS.MPEFRA^REGS.MPGHRA^REGS.MPIJRA^REGS.MPKLRA^REGS.MPMNRA^REGS.MPOPRA^REGS.MPABRB^REGS.MPCDRB^
//							REGS.MPEFRB^REGS.MPGHRB^REGS.MPIJRB^REGS.MPKLRB^REGS.MPMNRB^REGS.MPOPRB^REGS.SCXIN0^REGS.SCXDN0^REGS.SCYIN0^REGS.SCYDN0^REGS.ZMXIN0^REGS.ZMXDN0^REGS.ZMYIN0^
//							REGS.ZMYDN0^REGS.SCXIN1^REGS.SCXDN1^REGS.SCYIN1^REGS.SCYDN1^REGS.ZMXIN1^REGS.ZMXDN1^REGS.ZMYIN1^REGS.ZMYDN1^REGS.SCXN2^REGS.SCYN2^REGS.SCXN3^REGS.SCYN3^REGS.ZMCTL^
//							REGS.SCRCTL^REGS.VCSTAU^REGS.VCSTAL^REGS.LSTA0U^REGS.LSTA0L^REGS.LSTA1U^REGS.LSTA1L^REGS.LCTAU^REGS.LCTAL^REGS.BKTAU^REGS.BKTAL^REGS.RPMD^REGS.RPRCTL^
//							REGS.KTCTL^REGS.KTAOF^REGS.OVPNRA^REGS.OVPNRB^REGS.RPTAU^REGS.RPTAL^REGS.WPSX0^REGS.WPSY0^REGS.WPEX0^REGS.WPEY0^REGS.WPSX1^REGS.WPSY1^REGS.WPEX1^
//							REGS.WPEY1^REGS.WCTLA^REGS.WCTLB^REGS.WCTLC^REGS.WCTLD^REGS.LWTA0U^REGS.LWTA0L^REGS.LWTA1U^REGS.LWTA1L^REGS.SPCTL^REGS.SDCTL^REGS.CRAOFA^REGS.CRAOFB^REGS.LNCLEN^
//							REGS.SFPRMD^REGS.CCCTL^REGS.SFCCMD^REGS.PRISA^REGS.PRISB^&REGS.PRISC^REGS.PRISD^REGS.PRINA^REGS.PRINB^REGS.PRIR^REGS.CCRSA^
//							REGS.CCRSB^REGS.CCRSC^REGS.CCRSD^REGS.CCRNA^REGS.CCRNB^REGS.CCRR^REGS.CCRLB^REGS.CLOFEN^REGS.CLOFSL^REGS.COAR^REGS.COAG^REGS.COAB^REGS.COBR^REGS.COBG^REGS.COBB;
	
endmodule
