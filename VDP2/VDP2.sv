import VDP2_PKG::*;
	
module VDP2 (
	input             CLK,		//~53MHz
	input             RST_N,
	input             CE_R,
	input             CE_F,
	
	input             RES_N,

	input      [15:0] DI,
	output     [15:0] DO,
	input             CS_N,
	input             AD_N,
	input             DTEN_N,
	input       [1:0] WE_N,
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
	output NxCHD_t CH_PIPE0,
	output NxCHD_t CH_PIPE1,
	output NxCHD_t CH_PIPE2,
	output DotData_t N0DOT_DBG,
	output DotData_t N1DOT_DBG,
	output DotData_t N2DOT_DBG,
	output DotData_t N3DOT_DBG,
	output ScreenDot_t DOT_FST_DBG,
	output ScreenDot_t DOT_SEC_DBG,
	output [18:0] N0SCX,
	output [18:0] N0SCY,
	output        CCEN_DBG,
	output [4:0]  CCRT_DBG,
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
	
	wire VRAM_SEL = ~A[20] & ~DTEN_N & ~AD_N & ~CS_N;	//000000-0FFFFF
	
	bit DOT_CE,DOTH_CE;
	bit [8:0] H_CNT, V_CNT;
	bit [8:0] SCRX, SCRY;
	VRAMAccessPipeline_t VA_PIPE;
	BGPipeline_t BG_PIPE;
	PNPipe_t PN_PIPE;
	CHPipe_t CH_PIPE;
	ScrollData_t VS[2];
	CellDotsLine_t NBG_CDL[4];
	NxCHCNT_t  NBG_CH_CNT;
	bit        NBG_CH_HF[4];
	bit  [6:0] NBG_CH_PALN[4];
	bit [16:1] VRAMA0_A, VRAMA1_A, VRAMB0_A, VRAMB1_A;
	bit [15:0] VRAMA0_D, VRAMA1_D, VRAMB0_D, VRAMB1_D;
	bit [15:0] VRAMA0_Q, VRAMA1_Q, VRAMB0_Q, VRAMB1_Q;
	bit        VRAMA0_WE, VRAMA1_WE, VRAMB0_WE, VRAMB1_WE;
	bit        VRAMA0_RD, VRAMA1_RD, VRAMB0_RD, VRAMB1_RD;
	bit        VRAM_RW_PEND;
	
	bit [11:1] PAL_A;
	bit [15:0] PAL_Q;
	bit [15:0] PAL_DO;
	
	
	bit [2:0] DOTCLK_DIV;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DOTCLK_DIV <= '0;
//			DOT_CE <= 0;
		end
		else begin
//			DOT_CE <= 0;
//			DOTH_CE <= 0;
			
			DOTCLK_DIV <= DOTCLK_DIV + 3'd1;
//			if (DOTCLK_DIV == 7) DOT_CE <= 1;
//			if (DOTCLK_DIV == 3) DOTH_CE <= 1;
		end
	end
	
	assign DOT_CE = (DOTCLK_DIV == 7);
	assign DOTH_CE = (DOTCLK_DIV == 3);
	
	assign DCLK = DOT_CE;
	
	bit VBLANK;
	bit HBLANK;
	bit ODD;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			H_CNT <= '0;
			V_CNT <= '0;
			HS_N <= 1;
			VS_N <= 1;
			HBLANK <= 0;
			VBLANK <= 0;
			ODD <= 0;
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
					ODD <= ~ODD;
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
			end
			if (H_CNT == HRES-1) begin
				SCRL_FETCH <= 0;
			end else if (H_CNT == HRES-3-1) begin
				SCRL_FETCH <= 1;
			end
		end
	end
	
	always_comb begin
		bit [3:0] VCPA0; 
		bit [3:0] VCPA1; 
		bit [3:0] VCPB0; 
		bit [3:0] VCPB1;
		
		case (H_CNT[2:0])
			T0: begin VCPA0 = REGS.CYCA0L[15:12]; VCPA1 = REGS.CYCA1L[15:12]; VCPB0 = REGS.CYCB0L[15:12]; VCPB1 = REGS.CYCB1L[15:12]; end
			T1: begin VCPA0 = REGS.CYCA0L[11: 8]; VCPA1 = REGS.CYCA1L[11: 8]; VCPB0 = REGS.CYCB0L[11: 8]; VCPB1 = REGS.CYCB1L[11: 8]; end
			T2: begin VCPA0 = REGS.CYCA0L[ 7: 4]; VCPA1 = REGS.CYCA1L[ 7: 4]; VCPB0 = REGS.CYCB0L[ 7: 4]; VCPB1 = REGS.CYCB1L[ 7: 4]; end
			T3: begin VCPA0 = REGS.CYCA0L[ 3: 0]; VCPA1 = REGS.CYCA1L[ 3: 0]; VCPB0 = REGS.CYCB0L[ 3: 0]; VCPB1 = REGS.CYCB1L[ 3: 0]; end
			T4: begin VCPA0 = REGS.CYCA0U[15:12]; VCPA1 = REGS.CYCA1U[15:12]; VCPB0 = REGS.CYCB0U[15:12]; VCPB1 = REGS.CYCB1U[15:12]; end
			T5: begin VCPA0 = REGS.CYCA0U[11: 8]; VCPA1 = REGS.CYCA1U[11: 8]; VCPB0 = REGS.CYCB0U[11: 8]; VCPB1 = REGS.CYCB1U[11: 8]; end
			T6: begin VCPA0 = REGS.CYCA0U[ 7: 4]; VCPA1 = REGS.CYCA1U[ 7: 4]; VCPB0 = REGS.CYCB0U[ 7: 4]; VCPB1 = REGS.CYCB1U[ 7: 4]; end
			T7: begin VCPA0 = REGS.CYCA0U[ 3: 0]; VCPA1 = REGS.CYCA1U[ 3: 0]; VCPB0 = REGS.CYCB0U[ 3: 0]; VCPB1 = REGS.CYCB1U[ 3: 0]; end
		endcase
			
		VA_PIPE[0].NxA0PN[0] = VCPA0 == VCP_N0PN & BG_FETCH & ~VBLANK & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1PN[0] = VCPA1 == VCP_N0PN & BG_FETCH & ~VBLANK & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0PN[0] = VCPB0 == VCP_N0PN & BG_FETCH & ~VBLANK & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1PN[0] = VCPB1 == VCP_N0PN & BG_FETCH & ~VBLANK & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA0PN[1] = VCPA0 == VCP_N1PN & BG_FETCH & ~VBLANK & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1PN[1] = VCPA1 == VCP_N1PN & BG_FETCH & ~VBLANK & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0PN[1] = VCPB0 == VCP_N1PN & BG_FETCH & ~VBLANK & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1PN[1] = VCPB1 == VCP_N1PN & BG_FETCH & ~VBLANK & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA0PN[2] = VCPA0 == VCP_N2PN & BG_FETCH & ~VBLANK & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1PN[2] = VCPA1 == VCP_N2PN & BG_FETCH & ~VBLANK & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0PN[2] = VCPB0 == VCP_N2PN & BG_FETCH & ~VBLANK & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1PN[2] = VCPB1 == VCP_N2PN & BG_FETCH & ~VBLANK & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA0PN[3] = VCPA0 == VCP_N3PN & BG_FETCH & ~VBLANK & REGS.BGON.N3ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1PN[3] = VCPA1 == VCP_N3PN & BG_FETCH & ~VBLANK & REGS.BGON.N3ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0PN[3] = VCPB0 == VCP_N3PN & BG_FETCH & ~VBLANK & REGS.BGON.N3ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1PN[3] = VCPB1 == VCP_N3PN & BG_FETCH & ~VBLANK & REGS.BGON.N3ON & REGS.TVMD.DISP;
		
		VA_PIPE[0].NxA0CH[0] = VCPA0 == VCP_N0CH & BG_FETCH & ~VBLANK & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1CH[0] = VCPA1 == VCP_N0CH & BG_FETCH & ~VBLANK & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0CH[0] = VCPB0 == VCP_N0CH & BG_FETCH & ~VBLANK & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1CH[0] = VCPB1 == VCP_N0CH & BG_FETCH & ~VBLANK & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA0CH[1] = VCPA0 == VCP_N1CH & BG_FETCH & ~VBLANK & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1CH[1] = VCPA1 == VCP_N1CH & BG_FETCH & ~VBLANK & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0CH[1] = VCPB0 == VCP_N1CH & BG_FETCH & ~VBLANK & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1CH[1] = VCPB1 == VCP_N1CH & BG_FETCH & ~VBLANK & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA0CH[2] = VCPA0 == VCP_N2CH & BG_FETCH & ~VBLANK & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1CH[2] = VCPA1 == VCP_N2CH & BG_FETCH & ~VBLANK & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0CH[2] = VCPB0 == VCP_N2CH & BG_FETCH & ~VBLANK & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1CH[2] = VCPB1 == VCP_N2CH & BG_FETCH & ~VBLANK & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA0CH[3] = VCPA0 == VCP_N3CH & BG_FETCH & ~VBLANK & REGS.BGON.N3ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1CH[3] = VCPA1 == VCP_N3CH & BG_FETCH & ~VBLANK & REGS.BGON.N3ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0CH[3] = VCPB0 == VCP_N3CH & BG_FETCH & ~VBLANK & REGS.BGON.N3ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1CH[3] = VCPB1 == VCP_N3CH & BG_FETCH & ~VBLANK & REGS.BGON.N3ON & REGS.TVMD.DISP;
		
		VA_PIPE[0].NxA0VS[0] = VCPA0 == VCP_N0VS & BG_FETCH & ~VBLANK & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1VS[0] = VCPA1 == VCP_N0VS & BG_FETCH & ~VBLANK & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0VS[0] = VCPB0 == VCP_N0VS & BG_FETCH & ~VBLANK & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1VS[0] = VCPB1 == VCP_N0VS & BG_FETCH & ~VBLANK & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA0VS[1] = VCPA0 == VCP_N1VS & BG_FETCH & ~VBLANK & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1VS[1] = VCPA1 == VCP_N1VS & BG_FETCH & ~VBLANK & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0VS[1] = VCPB0 == VCP_N1VS & BG_FETCH & ~VBLANK & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1VS[1] = VCPB1 == VCP_N1VS & BG_FETCH & ~VBLANK & REGS.BGON.N1ON & REGS.TVMD.DISP;
		
		VA_PIPE[0].NxA0CPU[0] = ((VCPA0 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxA1CPU[0] = ((VCPA1 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxB0CPU[0] = ((VCPB0 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxB1CPU[0] = ((VCPB1 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxA0CPU[1] = ((VCPA0 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxA1CPU[1] = ((VCPA1 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxB0CPU[1] = ((VCPB0 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxB1CPU[1] = ((VCPB1 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxA0CPU[2] = ((VCPA0 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxA1CPU[2] = ((VCPA1 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxB0CPU[2] = ((VCPB0 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxB1CPU[2] = ((VCPB1 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxA0CPU[3] = ((VCPA0 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxA1CPU[3] = ((VCPA1 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxB0CPU[3] = ((VCPB0 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxB1CPU[3] = ((VCPB1 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		
		VA_PIPE[0].LS0 = SCRL_FETCH;
		
//		VA_PIPE[0].H_CNT <= H_CNT;
//		VA_PIPE[0].V_CNT <= V_CNT;
		VA_PIPE[0].VRAMA0_A = VRAMA0_A;
		VA_PIPE[0].VRAMA1_A = VRAMA1_A;
		VA_PIPE[0].VRAMB0_A = VRAMB0_A;
		VA_PIPE[0].VRAMB1_A = VRAMB1_A;

		VA_PIPE[0].NxCH_CNT <= NBG_CH_CNT;
	end
	
	assign VA_PIPE0 = VA_PIPE[0];
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
//			VA_PIPE[1] <= '0;
//			VA_PIPE[2] <= '0;
//			VA_PIPE[3] <= '0;
		end
		else if (DOT_CE) begin
			VA_PIPE[1] <= VA_PIPE[0];
			VA_PIPE[2] <= VA_PIPE[1];
			VA_PIPE[3] <= VA_PIPE[2];
		end
	end
	
	
	assign SCRX = H_CNT;
	assign SCRY = V_CNT;
	
	VDP2NSxRegs_t NSxREG;
	assign NSxREG = NSxRegs(REGS);
	
	VRAMAccess_t A0VA;
	VRAMAccess_t A1VA;
	VRAMAccess_t B0VA;
	VRAMAccess_t B1VA;
	always_comb begin
		A0VA.PN = |VA_PIPE[0].NxA0PN;
		A0VA.CH = |VA_PIPE[0].NxA0CH;
		A0VA.VS = |VA_PIPE[0].NxA0VS;
		A0VA.CPUA = |VA_PIPE[0].NxA0CPU /*| (VCPA0 == VCP_NA & ~REGS.RAMCTL.VRAMD)*/;
		A0VA.CPUD = |VA_PIPE[1].NxA0CPU /*| (VCPA0 == VCP_NA & ~REGS.RAMCTL.VRAMD)*/;
		A0VA.Nx = 2'd0;
		if (VA_PIPE[0].NxA0PN[0] || VA_PIPE[0].NxA0CH[0] || VA_PIPE[0].NxA0VS[0]) A0VA.Nx = 2'd0;
		if (VA_PIPE[0].NxA0PN[1] || VA_PIPE[0].NxA0CH[1] || VA_PIPE[0].NxA0VS[1]) A0VA.Nx = 2'd1;
		if (VA_PIPE[0].NxA0PN[2] || VA_PIPE[0].NxA0CH[2])                         A0VA.Nx = 2'd2;
		if (VA_PIPE[0].NxA0PN[3] || VA_PIPE[0].NxA0CH[3])                         A0VA.Nx = 2'd3;
		
		A1VA.PN = |VA_PIPE[0].NxA1PN;
		A1VA.CH = |VA_PIPE[0].NxA1CH;
		A1VA.VS = |VA_PIPE[0].NxA1VS;
		A1VA.CPUA = |VA_PIPE[0].NxA0CPU /*| (VCPA0 == VCP_NA & ~REGS.RAMCTL.VRAMD)*/;//???
		A1VA.CPUD = |VA_PIPE[1].NxA0CPU /*| (VCPA0 == VCP_NA & ~REGS.RAMCTL.VRAMD)*/;//???
		A1VA.Nx = 2'd0;
		if (VA_PIPE[0].NxA1PN[0] || VA_PIPE[0].NxA1CH[0] || VA_PIPE[0].NxA1VS[0]) A1VA.Nx = 2'd0;
		if (VA_PIPE[0].NxA1PN[1] || VA_PIPE[0].NxA1CH[1] || VA_PIPE[0].NxA1VS[1]) A1VA.Nx = 2'd1;
		if (VA_PIPE[0].NxA1PN[2] || VA_PIPE[0].NxA1CH[2])                         A1VA.Nx = 2'd2;
		if (VA_PIPE[0].NxA1PN[3] || VA_PIPE[0].NxA1CH[3])                         A1VA.Nx = 2'd3;
		
		
		B0VA.PN = |VA_PIPE[0].NxB0PN;
		B0VA.CH = |VA_PIPE[0].NxB0CH;
		B0VA.VS = |VA_PIPE[0].NxB0VS;
		B0VA.CPUA = |VA_PIPE[0].NxB0CPU /*| (VCPB0 == VCP_NA & ~REGS.RAMCTL.VRBMD)*/;
		B0VA.CPUD = |VA_PIPE[1].NxB0CPU /*| (VCPB0 == VCP_NA & ~REGS.RAMCTL.VRBMD)*/;
		B0VA.Nx = 2'd0;
		if (VA_PIPE[0].NxB0PN[0] || VA_PIPE[0].NxB0CH[0] || VA_PIPE[0].NxB0VS[0]) B0VA.Nx = 2'd0;
		if (VA_PIPE[0].NxB0PN[1] || VA_PIPE[0].NxB0CH[1] || VA_PIPE[0].NxB0VS[1]) B0VA.Nx = 2'd1;
		if (VA_PIPE[0].NxB0PN[2] || VA_PIPE[0].NxB0CH[2])                         B0VA.Nx = 2'd2;
		if (VA_PIPE[0].NxB0PN[3] || VA_PIPE[0].NxB0CH[3])                         B0VA.Nx = 2'd3;
		
		
		B1VA.PN = |VA_PIPE[0].NxB1PN;
		B1VA.CH = |VA_PIPE[0].NxB1CH;
		B1VA.VS = |VA_PIPE[0].NxB1VS;
		B1VA.CPUA = |VA_PIPE[0].NxB0CPU /*| (VCPB0 == VCP_NA & ~REGS.RAMCTL.VRBMD)*/;//???
		B1VA.CPUD = |VA_PIPE[1].NxB0CPU /*| (VCPB0 == VCP_NA & ~REGS.RAMCTL.VRBMD)*/;//???
		B1VA.Nx = 2'd0;
		if (VA_PIPE[0].NxB1PN[0] || VA_PIPE[0].NxB1CH[0] || VA_PIPE[0].NxB1VS[0]) B1VA.Nx = 2'd0;
		if (VA_PIPE[0].NxB1PN[1] || VA_PIPE[0].NxB1CH[1] || VA_PIPE[0].NxB1VS[1]) B1VA.Nx = 2'd1;
		if (VA_PIPE[0].NxB1PN[2] || VA_PIPE[0].NxB1CH[2])                         B1VA.Nx = 2'd2;
		if (VA_PIPE[0].NxB1PN[3] || VA_PIPE[0].NxB1CH[3])                         B1VA.Nx = 2'd3;
	end
	
	ScrollData_t SCX[4];
	ScrollData_t SCY[4];
	ScrollData_t NxOFFX[4];
	ScrollData_t NxOFFY[4];
	always @(posedge CLK or negedge RST_N) begin
		SCX[0] = {REGS.SCXIN0.NxSCXI,REGS.SCXDN0.NxSCXD} + LSX[0];
		SCY[0] = {REGS.SCYIN0.NxSCYI,REGS.SCYDN0.NxSCYD} + LSY[0] + VS[0];
		SCX[1] = {REGS.SCXIN1.NxSCXI,REGS.SCXDN1.NxSCXD} + LSX[1];
		SCY[1] = {REGS.SCYIN1.NxSCYI,REGS.SCYDN1.NxSCYD} + LSY[1] + VS[1];
		SCX[2] = {REGS.SCXN2.NxSCX,8'h00};
		SCY[2] = {REGS.SCYN2.NxSCY,8'h00};
		SCX[3] = {REGS.SCXN3.NxSCX,8'h00};
		SCY[3] = {REGS.SCYN3.NxSCY,8'h00};
		
		NxOFFX[0] = {2'h0,SCRX,8'h00} + SCX[0];
		NxOFFY[0] = {2'h0,SCRY,8'h00} + SCY[0];
		NxOFFX[1] = {2'h0,SCRX,8'h00} + SCX[1];
		NxOFFY[1] = {2'h0,SCRY,8'h00} + SCY[1];
		NxOFFX[2] = {2'h0,SCRX,8'h00} + SCX[2];
		NxOFFY[2] = {2'h0,SCRY,8'h00} + SCY[2];
		NxOFFX[3] = {2'h0,SCRX,8'h00} + SCX[3];
		NxOFFY[3] = {2'h0,SCRY,8'h00} + SCY[3];
	end
	
	bit NxPN_VRAMA0_A1,NxPN_VRAMA1_A1,NxPN_VRAMB0_A1,NxPN_VRAMB1_A1;
	bit NxOFFX3[4];
	ScrollData_t LSX[2];
	ScrollData_t LSY[2];
	CoordInc_t CIX;
	bit [18:17] NxLS_VRAM_BANK;
	always @(posedge CLK or negedge RST_N) begin
		bit   [19:1] NxPN_ADDR[4];
		bit   [19:1] NxCH_ADDR[4];
		bit   [19:1] N0VS_ADDR;
		bit   [19:1] NxLS_ADDR[2];
		bit VRAM_RW_PEND2;
		
		if (!RST_N) begin
			VRAMA0_A <= '0;
			VRAMA1_A <= '0;
			VRAMB0_A <= '0;
			VRAMB1_A <= '0;
			NBG_CH_CNT <= '{4{'0}};
		end
		else if (DOTH_CE) begin
			NxPN_ADDR[0] = NxPNAddr(NxOFFX[0].INT, NxOFFY[0].INT, NSxREG[0].MP, NSxREG[0].MPA, NSxREG[0].MPB, NSxREG[0].MPC, NSxREG[0].MPD, NSxREG[0].PLSZ, NSxREG[0].CHSZ, NSxREG[0].PNC.NxPNB);
			NxPN_ADDR[1] = NxPNAddr(NxOFFX[1].INT, NxOFFY[1].INT, NSxREG[1].MP, NSxREG[1].MPA, NSxREG[1].MPB, NSxREG[1].MPC, NSxREG[1].MPD, NSxREG[1].PLSZ, NSxREG[1].CHSZ, NSxREG[1].PNC.NxPNB);
			NxPN_ADDR[2] = NxPNAddr(NxOFFX[2].INT, NxOFFY[2].INT, NSxREG[2].MP, NSxREG[2].MPA, NSxREG[2].MPB, NSxREG[2].MPC, NSxREG[2].MPD, NSxREG[2].PLSZ, NSxREG[2].CHSZ, NSxREG[2].PNC.NxPNB);
			NxPN_ADDR[3] = NxPNAddr(NxOFFX[3].INT, NxOFFY[3].INT, NSxREG[3].MP, NSxREG[3].MPA, NSxREG[3].MPB, NSxREG[3].MPC, NSxREG[3].MPD, NSxREG[3].PLSZ, NSxREG[3].CHSZ, NSxREG[3].PNC.NxPNB);
			
			NxCH_ADDR[0] = !NSxREG[0].BMEN ? NxCHAddr(PN_PIPE[2][0], NBG_CH_CNT[0], NxOFFX3[0], NxOFFY[0].INT, NSxREG[0].CHCN, NSxREG[0].CHSZ) :
												      NxBMAddr(NxOFFX[0].INT, NxOFFY[0].INT, NSxREG[0].MP, NSxREG[0].CHCN, NSxREG[0].BMSZ);
			NxCH_ADDR[1] = !NSxREG[1].BMEN ? NxCHAddr(PN_PIPE[2][1], NBG_CH_CNT[1], NxOFFX3[1], NxOFFY[1].INT, NSxREG[1].CHCN, NSxREG[1].CHSZ) :
												      NxBMAddr(NxOFFX[1].INT, NxOFFY[1].INT, NSxREG[1].MP, NSxREG[1].CHCN, NSxREG[1].BMSZ);
			NxCH_ADDR[2] =                   NxCHAddr(PN_PIPE[2][2], NBG_CH_CNT[2], NxOFFX3[2], NxOFFY[2].INT, NSxREG[2].CHCN, NSxREG[2].CHSZ);
			NxCH_ADDR[3] =                   NxCHAddr(PN_PIPE[2][3], NBG_CH_CNT[3], NxOFFX3[3], NxOFFY[3].INT, NSxREG[3].CHCN, NSxREG[3].CHSZ);
			
			N0VS_ADDR = {1'b0,NSxREG[0].VCSTA} + {13'h000,SCRX[8:3]};
			
			NxLS_ADDR[0] = {NSxREG[0].LSTA,1'b0} + {9'h000,SCRY,1'b0};
			NxLS_ADDR[1] = {NSxREG[1].LSTA,1'b0} + {9'h000,SCRY,1'b0};
		
			if (!REGS.TVMD.DISP) begin
				VRAMA0_A <= A[16:1];
				VRAMA1_A <= A[16:1];
				VRAMB0_A <= A[16:1];
				VRAMB1_A <= A[16:1];
				VRAMA0_D <= DI;
				VRAMA1_D <= DI;
				VRAMB0_D <= DI;
				VRAMB1_D <= DI;
				VRAMA0_WE <= VRAM_SEL & A[18:17] == 2'b00 & ~&WE_N;
				VRAMA1_WE <= VRAM_SEL & A[18:17] == 2'b01 & ~&WE_N;
				VRAMB0_WE <= VRAM_SEL & A[18:17] == 2'b10 & ~&WE_N;
				VRAMB1_WE <= VRAM_SEL & A[18:17] == 2'b11 & ~&WE_N;
				VRAMA0_RD <= VRAM_SEL & A[18:17] == 2'b00 & |WE_N;
				VRAMA1_RD <= VRAM_SEL & A[18:17] == 2'b01 & |WE_N;
				VRAMB0_RD <= VRAM_SEL & A[18:17] == 2'b10 & |WE_N;
				VRAMB1_RD <= VRAM_SEL & A[18:17] == 2'b11 & |WE_N;
				VRAM_RW_PEND <= VRAM_SEL;
			end else if (BG_FETCH) begin
				if (A0VA.PN) begin
					VRAMA0_A <= NxPN_ADDR[A0VA.Nx][16:1];
					VRAMA0_RD <= 1;
				end else if (A0VA.CH) begin
					VRAMA0_A <= NxCH_ADDR[A0VA.Nx][16:1];
					VRAMA0_RD <= 1;
				end else	if (A0VA.VS) begin
					VRAMA0_A <= N0VS_ADDR[16:1];
					VRAMA0_RD <= 1;
				end else	if (A0VA.CPUA) begin
					VRAMA0_A <= A[16:1];
					VRAMA0_D <= DI;
					VRAMA0_WE <= VRAM_SEL & A[18] == 1'b0 & ~&WE_N;
					VRAMA0_RD <= VRAM_SEL & A[18] == 1'b0 & |WE_N;
					VRAM_RW_PEND <= VRAM_SEL;
				end
				
				if (A1VA.PN) begin
					VRAMA1_A <= NxPN_ADDR[A1VA.Nx][16:1];
					VRAMA1_RD <= 1;
				end else	if (A1VA.CH) begin
					VRAMA1_A <= NxCH_ADDR[A1VA.Nx][16:1];
					VRAMA1_RD <= 1;
				end else	if (A1VA.VS) begin
					VRAMA1_A <= N0VS_ADDR[16:1];
					VRAMA1_RD <= 1;
//				end else	if (A1VA.CPUA) begin
//					VRAMA1_A <= A[16:1];
//					VRAMA1_D <= DI;
//					VRAMA1_WE <= ~WE_N & VRAM_SEL & A[18:17] == 2'b01;
//					VRAMA1_RD <= ~RD_N & VRAM_SEL & A[18:17] == 2'b01;
//					VRAM_RW_PEND <= (~WE_N | ~RD_N) & VRAM_SEL;
				end
				
				if (B0VA.PN) begin
					VRAMB0_A <= NxPN_ADDR[B0VA.Nx][16:1];
					VRAMB0_RD <= 1;
				end else	if (B0VA.CH) begin
					VRAMB0_A <= NxCH_ADDR[B0VA.Nx][16:1];
					VRAMB0_RD <= 1;
				end else	if (B0VA.VS) begin
					VRAMB0_A <= N0VS_ADDR[16:1];
					VRAMB0_RD <= 1;
				end else	if (B0VA.CPUA) begin
					VRAMB0_A <= A[16:1];
					VRAMB0_D <= DI;
					VRAMB0_WE <= VRAM_SEL & A[18] == 1'b1 & ~&WE_N;
					VRAMB0_RD <= VRAM_SEL & A[18] == 1'b1 & |WE_N;
					VRAM_RW_PEND <= VRAM_SEL;
				end
				
				if (B1VA.PN) begin
					VRAMB1_A <= NxPN_ADDR[B1VA.Nx][16:1];
					VRAMB1_RD <= 1;
				end else	if (B1VA.CH) begin
					VRAMB1_A <= NxCH_ADDR[B1VA.Nx][16:1];
					VRAMB1_RD <= 1;
				end else	if (B1VA.VS) begin
					VRAMB1_A <= N0VS_ADDR[16:1];
					VRAMB1_RD <= 1;
//				end else	if (B1VA.CPUA) begin
//					VRAMB1_A <= A[16:1];
//					VRAMB1_D <= DI;
//					VRAMB1_WE <= ~WE_N & VRAM_SEL & A[18:17] == 2'b11;
//					VRAMB1_RD <= ~RD_N & VRAM_SEL & A[18:17] == 2'b11;
//					VRAM_RW_PEND <= (~WE_N | ~RD_N) & VRAM_SEL;
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
			
			if (!REGS.TVMD.DISP) begin
				if (VRAM_RW_PEND) begin
					VRAMA0_WE <= 0;
					VRAMA1_WE <= 0;
					VRAMB0_WE <= 0;
					VRAMB1_WE <= 0;
					VRAMA0_RD <= 0;
					VRAMA1_RD <= 0;
					VRAMB0_RD <= 0;
					VRAMB1_RD <= 0;
					VRAM_RW_PEND <= 0;
					VRAM_RW_PEND2 <= 1;
				end
			end else begin
				if (A0VA.CPUD && VRAM_RW_PEND) begin
					VRAMA0_WE <= 0;
					VRAMA1_WE <= 0;
					VRAMA0_RD <= 0;
					VRAMA1_RD <= 0;
					VRAM_RW_PEND <= 0;
					VRAM_RW_PEND2 <= 1;
				end
				if (B0VA.CPUD && VRAM_RW_PEND) begin
					VRAMB0_WE <= 0;
					VRAMB1_WE <= 0;
					VRAMB0_RD <= 0;
					VRAMB1_RD <= 0;
					VRAM_RW_PEND <= 0;
					VRAM_RW_PEND2 <= 1;
				end
			end
		end
		else if (DOT_CE) begin
			if (!REGS.TVMD.DISP) begin
//				VRAM_RW_PEND <= VRAM_SEL;
			end else if (BG_FETCH) begin
				if (A0VA.PN) begin
					NxPN_VRAMA0_A1 <= NxPN_ADDR[A0VA.Nx][1];
	//				NBG_CH_CNT[A0VA.Nx] <= '0;
				end else if (A0VA.CH) begin
					NBG_CH_CNT[A0VA.Nx] <= NBG_CH_CNT[A0VA.Nx] + 3'd1;
				end
				
				if (A1VA.PN) begin
					NxPN_VRAMA1_A1 <= NxPN_ADDR[A1VA.Nx][1];
	//				NBG_CH_CNT[A1VA.Nx] <= '0;
				end else	if (A1VA.CH) begin
					NBG_CH_CNT[A1VA.Nx] <= NBG_CH_CNT[A1VA.Nx] + 3'd1;
				end
				
				if (B0VA.PN) begin
					NxPN_VRAMB0_A1 <= NxPN_ADDR[B0VA.Nx][1];
	//				NBG_CH_CNT[B0VA.Nx] <= '0;
				end else	if (B0VA.CH) begin
					NBG_CH_CNT[B0VA.Nx] <= NBG_CH_CNT[B0VA.Nx] + 3'd1;
				end
				
				if (B1VA.PN) begin
					NxPN_VRAMB1_A1 <= NxPN_ADDR[B1VA.Nx][1];
	//				NBG_CH_CNT[B1VA.Nx] <= '0;
				end else	if (B1VA.CH) begin
					NBG_CH_CNT[B1VA.Nx] <= NBG_CH_CNT[B1VA.Nx] + 3'd1;
				end
			end else if (SCRL_FETCH) begin
				NxLS_VRAM_BANK <= NxLS_ADDR[0][18:17];
			end
			
			if (!REGS.TVMD.DISP) begin
				if (VRAM_RW_PEND2) begin
					VRAMA0_Q <= VRAMA0_A[1] ? RA0_Q[15:0] : RA0_Q[31:16];
					VRAMA1_Q <= VRAMA1_A[1] ? RA1_Q[15:0] : RA1_Q[31:16];
					VRAMB0_Q <= VRAMB0_A[1] ? RB0_Q[15:0] : RB0_Q[31:16];
					VRAMB1_Q <= VRAMB1_A[1] ? RB1_Q[15:0] : RB1_Q[31:16];
					VRAM_RW_PEND2 <= 0;
				end
			end else begin
				if (A0VA.CPUD && VRAM_RW_PEND2) begin
					VRAMA0_Q <= VRAMA0_A[1] ? RA0_Q[15:0] : RA0_Q[31:16];
					VRAMA1_Q <= VRAMA1_A[1] ? RA1_Q[15:0] : RA1_Q[31:16];
					VRAM_RW_PEND2 <= 0;
				end
				if (B0VA.CPUD && VRAM_RW_PEND2) begin
					VRAMB0_Q <= VRAMB0_A[1] ? RB0_Q[15:0] : RB0_Q[31:16];
					VRAMB1_Q <= VRAMB1_A[1] ? RB1_Q[15:0] : RB1_Q[31:16];
					VRAM_RW_PEND2 <= 0;
				end
			end
		end
	end
	
	assign N0SCX = SCX[0];
	assign N0SCY = SCY[0];
	
	bit       NxLSC;
	always_comb begin
		NxLSC = VA_PIPE[1].LS0;
	end
	
	always @(posedge CLK or negedge RST_N) begin
		bit [31:0] PN_WD[4];
		bit        PN_A1[4];
		bit  [2:0] CNT[4];
		bit        HF[4];
		bit  [6:0] PALN[4];
		bit [31:0] CH[4];
		bit        TPON[4];
		bit [31:0] LS_WD[2];
		BGState_t  BGS0;
		
		
		if (!RST_N) begin
			NBG_CDL[0] <= '{8{'0}};
			NBG_CDL[1] <= '{8{'0}};
			NBG_CDL[2] <= '{8{'0}};
			NBG_CDL[3] <= '{8{'0}};
			VS[0] <= '0; VS[1] <= '0;
			LSX[0] <= '0; LSX[1]<= '0;
			LSY[0] <= '0; LSY[1]<= '0;
		end
		else if (DOT_CE) begin
			for (int i=0; i<4; i++) begin
				BGS0.NxPN[i] = VA_PIPE[0].NxA0PN[i] | VA_PIPE[0].NxA1PN[i] | VA_PIPE[0].NxB0PN[i] | VA_PIPE[0].NxB1PN[i];
				BGS0.NxPNS[i] = VA_PIPE[0].NxA0PN[i] ? 2'd0 : 
									 VA_PIPE[0].NxA1PN[i] ? 2'd1 : 
									 VA_PIPE[0].NxB0PN[i] ? 2'd2 : 
									 2'd3;
				BGS0.NxCH[i] = VA_PIPE[0].NxA0CH[i] | VA_PIPE[0].NxA1CH[i] | VA_PIPE[0].NxB0CH[i] | VA_PIPE[0].NxB1CH[i];
				if (i < 2) begin
					BGS0.NxCHS[i] = VA_PIPE[0].NxA0CH[i] /*|| VA_PIPE[0].VCPA0 == VCP_N0VS*/ ? 2'd0 : 
										 VA_PIPE[0].NxA1CH[i] /*|| VA_PIPE[0].VCPA1 == VCP_N0VS*/ ? 2'd1 : 
										 VA_PIPE[0].NxB0CH[i] /*|| VA_PIPE[0].VCPB0 == VCP_N0VS*/ ? 2'd2 : 
										 2'd3;
					BGS0.NxVS[i] = VA_PIPE[0].NxA0VS[i] | VA_PIPE[0].NxA1VS[i] | VA_PIPE[0].NxB0VS[i] | VA_PIPE[0].NxB1VS[i];			 
				end else begin
					BGS0.NxCHS[i] = VA_PIPE[0].NxA0CH[i] ? 2'd0 : 
										 VA_PIPE[0].NxA1CH[i] ? 2'd1 : 
										 VA_PIPE[0].NxB0CH[i] ? 2'd2 : 
										 2'd3;
				end
				BGS0.NxCH[i] = VA_PIPE[0].NxA0CH[i] | VA_PIPE[0].NxA1CH[i] | VA_PIPE[0].NxB0CH[i] | VA_PIPE[0].NxB1CH[i];
			end
			BGS0.NxCH_CNT = NBG_CH_CNT;
			
			for (int i=0; i<4; i++) begin
				if (BG_PIPE[1].NxCH[i]) begin
					case (BG_PIPE[1].NxCHS[i])
						2'd0: CH_PIPE[0][i] <= {RA0_Q[15:0],RA0_Q[31:16]};
						2'd1: CH_PIPE[0][i] <= {RA1_Q[15:0],RA1_Q[31:16]};
						2'd2: CH_PIPE[0][i] <= {RB0_Q[15:0],RB0_Q[31:16]};
						2'd3: CH_PIPE[0][i] <= {RB1_Q[15:0],RB1_Q[31:16]};
					endcase
				end
				
				if (BG_PIPE[3].NxCH[i]) begin
					CNT[i] = BG_PIPE[3].NxCH_CNT[i];
					PALN[i] = PN_PIPE[2][i].PALN;
					HF[i] = PN_PIPE[2][i].HF;
					CH[i] = CH_PIPE[1][i];
					TPON[i] = NSxREG[i].TPON;
					case (NSxREG[i].CHCN)
						3'b000: begin				//4bits/dot, 16 colors
							NBG_CDL[i][0 ^ {3{HF[i]}}] <= {1'b1,|CH[i][31:28]|TPON[i],{13'h0000,PALN[i],CH[i][31:28]}};
							NBG_CDL[i][1 ^ {3{HF[i]}}] <= {1'b1,|CH[i][27:24]|TPON[i],{13'h0000,PALN[i],CH[i][27:24]}};
							NBG_CDL[i][2 ^ {3{HF[i]}}] <= {1'b1,|CH[i][23:20]|TPON[i],{13'h0000,PALN[i],CH[i][23:20]}};
							NBG_CDL[i][3 ^ {3{HF[i]}}] <= {1'b1,|CH[i][19:16]|TPON[i],{13'h0000,PALN[i],CH[i][19:16]}};
							NBG_CDL[i][4 ^ {3{HF[i]}}] <= {1'b1,|CH[i][15:12]|TPON[i],{13'h0000,PALN[i],CH[i][15:12]}};
							NBG_CDL[i][5 ^ {3{HF[i]}}] <= {1'b1,|CH[i][11: 8]|TPON[i],{13'h0000,PALN[i],CH[i][11: 8]}};
							NBG_CDL[i][6 ^ {3{HF[i]}}] <= {1'b1,|CH[i][ 7: 4]|TPON[i],{13'h0000,PALN[i],CH[i][ 7: 4]}};
							NBG_CDL[i][7 ^ {3{HF[i]}}] <= {1'b1,|CH[i][ 3: 0]|TPON[i],{13'h0000,PALN[i],CH[i][ 3: 0]}};
						end
						3'b001: begin				//8bits/dot, 256 colors
							NBG_CDL[i][{CNT[i][0],2'b00} ^ {3{HF[i]}}] <= {1'b1,|CH[i][31:24]|TPON[i],{13'h0000,PALN[i][6:4],CH[i][31:24]}};
							NBG_CDL[i][{CNT[i][0],2'b01} ^ {3{HF[i]}}] <= {1'b1,|CH[i][23:16]|TPON[i],{13'h0000,PALN[i][6:4],CH[i][23:16]}};
							NBG_CDL[i][{CNT[i][0],2'b10} ^ {3{HF[i]}}] <= {1'b1,|CH[i][15: 8]|TPON[i],{13'h0000,PALN[i][6:4],CH[i][15: 8]}};
							NBG_CDL[i][{CNT[i][0],2'b11} ^ {3{HF[i]}}] <= {1'b1,|CH[i][ 7: 0]|TPON[i],{13'h0000,PALN[i][6:4],CH[i][ 7: 0]}};
						end
						3'b010: begin				//16bits/dot, 2048 colors
							NBG_CDL[i][{CNT[i][1:0],1'b0} ^ {3{HF[i]}}] <= {1'b1,|CH[i][26:16]|TPON[i],{13'h0000,CH[i][26:16]}};
							NBG_CDL[i][{CNT[i][1:0],1'b1} ^ {3{HF[i]}}] <= {1'b1,|CH[i][10: 0]|TPON[i],{13'h0000,CH[i][10: 0]}};
						end
						3'b011: begin				//16bits/dot, 32768 colors
							NBG_CDL[i][{CNT[i][1:0],1'b0} ^ {3{HF[i]}}] <= {1'b0,CH[i][31]|TPON[i],Color555To888(CH[i][31:16])};
							NBG_CDL[i][{CNT[i][1:0],1'b1} ^ {3{HF[i]}}] <= {1'b0,CH[i][15]|TPON[i],Color555To888(CH[i][15: 0])};
						end
						3'b100: begin				//32bits/dot, 16M colors
							NBG_CDL[i][CNT[i] ^ {3{HF[i]}}] <= {1'b0,CH[i][31]|TPON[i],CH[i][23:0]};
						end
						default:;
					endcase
				end
				
				if (BG_PIPE[1].NxPN[i]) begin
					case (BG_PIPE[1].NxPNS[i])
						2'd0: PN_WD[i] = {RA0_Q[15:0],RA0_Q[31:16]};
						2'd1: PN_WD[i] = {RA1_Q[15:0],RA1_Q[31:16]};
						2'd2: PN_WD[i] = {RB0_Q[15:0],RB0_Q[31:16]};
						2'd3: PN_WD[i] = {RB1_Q[15:0],RB1_Q[31:16]};
					endcase
					case (BG_PIPE[1].NxPNS[i])
						2'd0: PN_A1[i] = NxPN_VRAMA0_A1;
						2'd1: PN_A1[i] = NxPN_VRAMA1_A1;
						2'd2: PN_A1[i] = NxPN_VRAMB0_A1;
						2'd3: PN_A1[i] = NxPN_VRAMB1_A1;
					endcase
					if (!NSxREG[i].PNC.NxPNB) begin
						PN_PIPE[0][i] <= PN_WD[i];
					end else begin
						PN_PIPE[0][i] <= PNOneWord(NSxREG[i].PNC, NSxREG[i].CHSZ, NSxREG[i].CHCN, !PN_A1[i] ? PN_WD[i][31:16] : PN_WD[i][15: 0]);
					end
				end
				
				if (BG_PIPE[1].NxPN[i]) begin
//					PN[i] <= PNT[i];
					NxOFFX3[i] <= NxOFFX[i].INT[3];
				end
			end
			
			for (int i=0; i<2; i++) begin
				if (BGS0.NxVS[i]) begin
					VS[i].INT  <= PN_WD[i][26:16] & {11{NSxREG[i].VCSC}};
					VS[i].FRAC <= PN_WD[i][15: 8] & { 8{NSxREG[i].VCSC}};
				end
				
				if (NxLSC) begin
					case (NxLS_VRAM_BANK/*[i]*/)
						2'b00: LS_WD[i] = {RA0_Q[15:0],RA0_Q[31:16]};
						2'b01: LS_WD[i] = {RA1_Q[15:0],RA1_Q[31:16]};
						2'b10: LS_WD[i] = {RB0_Q[15:0],RB0_Q[31:16]};
						2'b11: LS_WD[i] = {RB1_Q[15:0],RB1_Q[31:16]};
					endcase
					LSX[i].INT  <= LS_WD[i][26:16] & {11{NSxREG[i].LSCX}};
//					LSX[i].FRAC <= LS_WD[i][15: 8] & { 8{NSxREG[i].LSCX}};
				end
			end
			
			BG_PIPE[1] <= BGS0;
			BG_PIPE[2] <= BG_PIPE[1];
			BG_PIPE[3] <= BG_PIPE[2];
			
			PN_PIPE[1] <= PN_PIPE[0];
			PN_PIPE[2] <= PN_PIPE[1];
			PN_PIPE[3] <= PN_PIPE[2];
			
			CH_PIPE[1] <= CH_PIPE[0];
			CH_PIPE[2] <= CH_PIPE[1];
			CH_PIPE[3] <= CH_PIPE[2];
		end
	end
	assign CH_PIPE0 = CH_PIPE[0];
	assign CH_PIPE1 = CH_PIPE[1];
	assign CH_PIPE2 = CH_PIPE[2];
	
	bit VRAM_RDY;
	always @(posedge CLK or negedge RST_N) begin
		bit VRAM_SEL_OLD;
		bit VRAM_PEND_OLD;
		
		if (!RST_N) begin
			VRAM_RDY <= 1;
		end
		else begin
			VRAM_SEL_OLD <= VRAM_SEL;
			VRAM_PEND_OLD <= VRAM_RW_PEND;
			if (VRAM_SEL && !VRAM_SEL_OLD && VRAM_RDY) 
				VRAM_RDY <= 0;
			else if (!VRAM_RW_PEND && VRAM_PEND_OLD && !VRAM_RDY) 
				VRAM_RDY <= 1;
		end
	end
	
	assign RA0_A = VRAMA0_A;
	assign RA0_D = VRAMA0_D;
	assign RA0_WE = VRAMA0_WE;
	assign RA0_RD = VRAMA0_RD;
	
	assign RA1_A = VRAMA1_A;
	assign RA1_D = VRAMA1_D;
	assign RA1_WE = VRAMA1_WE;
	assign RA1_RD = VRAMA1_RD;
	
	assign RB0_A = VRAMB0_A;
	assign RB0_D = VRAMB0_D;
	assign RB0_WE = VRAMB0_WE;
	assign RB0_RD = VRAMB0_RD;
	
	assign RB1_A = VRAMB1_A;
	assign RB1_D = VRAMB1_D;
	assign RB1_WE = VRAMB1_WE;
	assign RB1_RD = VRAMB1_RD;

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
				T4: begin  end
				T5: begin  end
				T6: begin  end
				T7: begin 
					for (int i=0; i<8; i++) begin
						N0DB[i] <= N0DB[i+8]; N0DB[i+8] <= NBG_CDL[0][i];
						N1DB[i] <= N1DB[i+8]; N1DB[i+8] <= NBG_CDL[1][i];
						N2DB[i] <= N2DB[i+8]; N2DB[i+8] <= NBG_CDL[2][i];
						N3DB[i] <= N3DB[i+8]; N3DB[i+8] <= NBG_CDL[3][i];
					end end
			endcase
		end
	end
	
	wire [3:0] N0DOTN = {1'b0,SCRX[2:0] /*- 3'd5*/} + {1'b0,SCX[0].INT[2:0]};
	wire [3:0] N1DOTN = {1'b0,SCRX[2:0] /*- 3'd5*/} + {1'b0,SCX[1].INT[2:0]};
	wire [3:0] N2DOTN = {1'b0,SCRX[2:0] /*- 3'd5*/} + {1'b0,SCX[2].INT[2:0]};
	wire [3:0] N3DOTN = {1'b0,SCRX[2:0] /*- 3'd5*/} + {1'b0,SCX[3].INT[2:0]};
	ScreenDot_t DOT_FST[2], DOT_SEC[2], DOT_THD[2], DOT_FTH[2];
	DotData_t N0DOT,N1DOT,N2DOT,N3DOT;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DOT_FST <= '{2{SD_NULL}};
			DOT_SEC <= '{2{SD_NULL}};
			DOT_THD <= '{2{SD_NULL}};
			DOT_FTH <= '{2{SD_NULL}};
		end
		else if (DOT_CE) begin
			N0DOT = N0DB[N0DOTN];
			N1DOT = N1DB[N1DOTN];
			N2DOT = N2DB[N2DOTN];
			N3DOT = N3DB[N3DOTN];
			
			DOT_FST[0] <= SD_NULL;
			DOT_SEC[0] <= SD_NULL;
			DOT_THD[0] <= SD_NULL;
			DOT_FTH[0] <= SD_NULL;
			if (REGS.TVMD.DISP) begin
				if (N0DOT.TP && NSxREG[0].PRIN && NSxREG[0].ON) begin
					DOT_FST[0] <= {N0DOT,2'd0};
					DOT_SEC[0] <= DOT_FST[0];
					DOT_THD[0] <= DOT_SEC[0];
					DOT_FTH[0] <= DOT_THD[0];
				end
				if (N1DOT.TP && NSxREG[1].PRIN && NSxREG[1].ON && 
					(NSxREG[1].PRIN > NSxREG[0].PRIN || !N0DOT.TP)) begin
					DOT_FST[0] <= {N1DOT,2'd1};
					DOT_SEC[0] <= DOT_FST[0];
					DOT_THD[0] <= DOT_SEC[0];
					DOT_FTH[0] <= DOT_THD[0];
				end
				if (N2DOT.TP && NSxREG[2].PRIN && NSxREG[2].ON && 
					(NSxREG[2].PRIN > NSxREG[1].PRIN || !N1DOT.TP) && 
					(NSxREG[2].PRIN > NSxREG[0].PRIN || !N0DOT.TP)) begin
					DOT_FST[0] <= {N2DOT,2'd2};
					DOT_SEC[0] <= DOT_FST[0];
					DOT_THD[0] <= DOT_SEC[0];
					DOT_FTH[0] <= DOT_THD[0];
				end
				if (N3DOT.TP && NSxREG[3].PRIN && NSxREG[3].ON && 
					(NSxREG[3].PRIN > NSxREG[2].PRIN || !N2DOT.TP) && 
					(NSxREG[3].PRIN > NSxREG[1].PRIN || !N1DOT.TP) && 
					(NSxREG[3].PRIN > NSxREG[0].PRIN || !N0DOT.TP)) begin
					DOT_FST[0] <= {N3DOT,2'd3};
					DOT_SEC[0] <= DOT_FST[0];
					DOT_THD[0] <= DOT_SEC[0];
					DOT_FTH[0] <= DOT_THD[0];
				end
			end
			
			DOT_FST[1] <= DOT_FST[0];
			DOT_SEC[1] <= DOT_SEC[0];
			DOT_THD[1] <= DOT_THD[0];
			DOT_FTH[1] <= DOT_THD[0];
		end
	end
	
	assign N0DOT_DBG = N0DOT;
	assign N1DOT_DBG = N1DOT;
	assign N2DOT_DBG = N2DOT;
	assign N3DOT_DBG = N3DOT;
	assign DOT_FST_DBG = DOT_FST[0];
	assign DOT_SEC_DBG = DOT_SEC[0];
	
	bit       COEN;
	bit       COSL;
	bit [4:0] CCRT;
	bit       CCEN;
	always_comb begin
		case (DOTCLK_DIV[2:1])
			2'b00: PAL_A = {NSxREG[DOT_FST[0].S].CAOS,8'b00000000} + DOT_FST[0].D[10:0];
			2'b01: PAL_A = {NSxREG[DOT_SEC[0].S].CAOS,8'b00000000} + DOT_SEC[0].D[10:0];
			2'b10: PAL_A = {NSxREG[DOT_THD[0].S].CAOS,8'b00000000} + DOT_THD[0].D[10:0];
			2'b11: PAL_A = {NSxREG[DOT_FTH[0].S].CAOS,8'b00000000} + DOT_FTH[0].D[10:0];
		endcase
		
		COEN = NSxREG[DOT_FST[1].S].COEN;
		COSL = NSxREG[DOT_FST[1].S].COSL;
		CCEN = NSxREG[DOT_FST[1].S].CCEN;
		CCRT = NSxREG[DOT_FST[1].S].CCRT;
	end
	assign CCEN_DBG = CCEN;
	assign CCRT_DBG = CCRT;
	
	
	Color_t PAL_COL_FST, PAL_COL_SEC, PAL_COL_THD, PAL_COL_FTH;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			PAL_COL_FST <= '0;
			PAL_COL_SEC <= '0;
			PAL_COL_THD <= '0;
			PAL_COL_FTH <= '0;
		end
		else begin
			case (DOTCLK_DIV[2:0])
				3'd1: PAL_COL_FST <= Color555To888(PAL_Q);
				3'd3: PAL_COL_SEC <= Color555To888(PAL_Q);
				3'd5: PAL_COL_THD <= Color555To888(PAL_Q);
				3'd7: PAL_COL_FTH <= Color555To888(PAL_Q);
			endcase
		end
	end
	
	DotColor_t DCOL;
	always @(posedge CLK or negedge RST_N) begin
		Color_t CF, CS, CC;
		
		if (!RST_N) begin
			DCOL <= DC_NULL;
		end
		else if (DOT_CE) begin
			CF = !DOT_FST[1].P ? DOT_FST[1].D : PAL_COL_FST;
			CS = !DOT_SEC[1].P ? DOT_SEC[1].D : PAL_COL_SEC;
			CC = ColorCalc(CF, CS, CCRT, CCEN, REGS.CCCTL.CCMD);
			DCOL.B <= ColorOffset(CC.B, REGS.COAB.COBL, REGS.COBB.COBL, COEN, COSL); 
			DCOL.G <= ColorOffset(CC.G, REGS.COAG.COGR, REGS.COBG.COGR, COEN, COSL); 
			DCOL.R <= ColorOffset(CC.R, REGS.COAR.CORD, REGS.COBR.CORD, COEN, COSL); 
			DCOL.TP <= DOT_FST[1].TP;
		end
	end

	assign R = DCOL.R;
	assign G = DCOL.G;
	assign B = DCOL.B;
	
	
	
	wire PAL_SEL = !CS_N && !DTEN_N && !AD_N && A[20:19] == 2'b10;	//100000-17FFFF
	VDP2_DPRAM #(11,16,"pal.mif","") pal 
	(
		.CLK(CLK),
		
		.ADDR_A(PAL_A),
		.DATA_A(16'h0000),
		.WREN_A(1'b0),
		.Q_A(PAL_Q),
		
		.ADDR_B(A[11:1]),
		.DATA_B(DI),
		.WREN_B(PAL_SEL & ~&WE_N & CE_R),
		.Q_B(PAL_DO)
	);
	
	//Registers
	wire REG_SEL = A[20:18] == 3'b110 && !DTEN_N && !AD_N && !CS_N;
	
	bit [20:0] A;
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
			
			REGS.CYCA0L <= 16'h7744;//16'h7744;
			REGS.CYCA0U <= 16'hFFFF;
			REGS.CYCA1L <= 16'hFF30;//16'hFF30;
			REGS.CYCA1U <= 16'hFFFF;
			REGS.CYCB0L <= 16'h6655;//16'h6655;
			REGS.CYCB0U <= 16'hFFFF;
			REGS.CYCB1L <= 16'h21FF;//16'h21FF;
			REGS.CYCB1U <= 16'hFFFF;
			REGS.CHCTLA <= 16'h1010;
			REGS.CHCTLB <= 16'h0022;
			REGS.MPOFN <= 16'h0000;
			REGS.MPABN0 <= 16'h0808;
			REGS.MPCDN0 <= 16'h0808;
			REGS.MPABN1 <= 16'h1818;
			REGS.MPCDN1 <= 16'h1818;
			REGS.MPABN2 <= 16'h1C1C;
			REGS.MPCDN2 <= 16'h1C1C;
			REGS.MPABN3 <= 16'h0C0C;
			REGS.MPCDN3 <= 16'h0C0C;
			REGS.PNCN0 <= 16'h0000;
			REGS.PNCN1 <= 16'h0000;
			REGS.PNCN2 <= 16'h0000;
			REGS.PNCN3 <= 16'h0000;
			REGS.PRINA <= 16'h0706;
			REGS.PRINB <= 16'h0607;
			REGS.PLSZ <= 16'h0000;
			{REGS.LSTA0U,REGS.LSTA0L} <= 32'h00000000;
			REGS.SCRCTL <= 16'h0000;
			REGS.CRAOFA <= 16'h3210;
			{REGS.BKTAU,REGS.BKTAL} <= 32'h00000000;
			REGS.CCCTL <= 16'h0002;
			REGS.CCRNA <= 16'h0D00;
			REGS.CCRNB <= 16'h0000;
			REGS.BGON <= 16'h0803;
			REGS.TVMD <= 16'h8000;
			
//			REGS.CYCA0L <= 16'h44FF;
//			REGS.CYCA0U <= 16'hFFFF;
//			REGS.CYCA1L <= 16'hFFFF;
//			REGS.CYCA1U <= 16'hFFFF;
//			REGS.CYCB0L <= 16'h0FFF;
//			REGS.CYCB0U <= 16'hFFFF;
//			REGS.CYCB1L <= 16'hFFFF;
//			REGS.CYCB1U <= 16'hFFFF;
//			REGS.CHCTLA <= 16'h0011;
//			REGS.MPABN0 <= 16'h0000;
//			REGS.PNCN0 <= 16'hC000;
//			REGS.PRINA <= 16'h0006;
//			{REGS.LSTA0U,REGS.LSTA0L} <= 32'h00010000;
//			REGS.SCRCTL <= 16'h0000;
//			REGS.BGON <= 16'h000C;
//			REGS.TVMD <= 16'h8000;
			// synopsys translate_off
			// synopsys translate_on
			REG_DO <= '0;
			A <= '0;
		end else if (!RES_N) begin
				
		end else begin
//			AD_N_OLD <= AD_N;
			if (!CS_N && !DTEN_N && CE_R) begin
				if (AD_N) begin
					A <= {A[4:0],DI};
				end else begin
				
				end
			end
			
			if (REG_SEL) begin
				if (!(&WE_N) && CE_R) begin
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
				end else if (WE_N && CE_F) begin
					case ({A[8:1],1'b0})
						9'h000: REG_DO <= REGS.TVMD & TVMD_MASK;
						9'h002: REG_DO <= REGS.EXTEN & EXTEN_MASK;
						9'h004: REG_DO <= {12'h000,VBLANK,HBLANK,ODD,1'b0} & TVSTAT_MASK;
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
	
	assign DO = REG_SEL ? REG_DO : 
	            PAL_SEL ? PAL_DO : 
					VRAM_DO;
	assign RDY_N = ~((VRAM_SEL & VRAM_RDY) | REG_SEL | PAL_SEL);
	
	assign VINT_N = ~VBLANK;
	assign HINT_N = ~HBLANK;
	
	assign REG_DBG = REGS.TVMD^REGS.EXTEN^REGS.VRSIZE^REGS.RAMCTL^REGS.CYCA0L^REGS.CYCA0U^REGS.CYCA1L^REGS.CYCA1U^REGS.CYCB0L^
						   REGS.CYCB0U^REGS.CYCB1L^REGS.CYCB1U^REGS.BGON^REGS.MZCTL^REGS.SFSEL^REGS.SFCODE^REGS.CHCTLA^REGS.CHCTLB^REGS.BMPNA^REGS.BMPNB^
							REGS.PNCN0^REGS.PNCN1^REGS.PNCN2^REGS.PNCN3^REGS.PNCR^REGS.PLSZ^REGS.MPOFN^REGS.MPOFR^REGS.MPABN0^REGS.MPCDN0^REGS.MPABN1^REGS.MPCDN1^REGS.MPABN2^
							REGS.MPCDN2^REGS.MPABN3^REGS.MPCDN3^REGS.MPABRA^REGS.MPCDRA^REGS.MPEFRA^REGS.MPGHRA^REGS.MPIJRA^REGS.MPKLRA^REGS.MPMNRA^REGS.MPOPRA^REGS.MPABRB^REGS.MPCDRB^
							REGS.MPEFRB^REGS.MPGHRB^REGS.MPIJRB^REGS.MPKLRB^REGS.MPMNRB^REGS.MPOPRB^REGS.SCXIN0^REGS.SCXDN0^REGS.SCYIN0^REGS.SCYDN0^REGS.ZMXIN0^REGS.ZMXDN0^REGS.ZMYIN0^
							REGS.ZMYDN0^REGS.SCXIN1^REGS.SCXDN1^REGS.SCYIN1^REGS.SCYDN1^REGS.ZMXIN1^REGS.ZMXDN1^REGS.ZMYIN1^REGS.ZMYDN1^REGS.SCXN2^REGS.SCYN2^REGS.SCXN3^REGS.SCYN3^REGS.ZMCTL^
							REGS.SCRCTL^REGS.VCSTAU^REGS.VCSTAL^REGS.LSTA0U^REGS.LSTA0L^REGS.LSTA1U^REGS.LSTA1L^REGS.LCTAU^REGS.LCTAL^REGS.BKTAU^REGS.BKTAL^REGS.RPMD^REGS.RPRCTL^
							REGS.KTCTL^REGS.KTAOF^REGS.OVPNRA^REGS.OVPNRB^REGS.RPTAU^REGS.RPTAL^REGS.WPSX0^REGS.WPSY0^REGS.WPEX0^REGS.WPEY0^REGS.WPSX1^REGS.WPSY1^REGS.WPEX1^
							REGS.WPEY1^REGS.WCTLA^REGS.WCTLB^REGS.WCTLC^REGS.WCTLD^REGS.LWTA0U^REGS.LWTA0L^REGS.LWTA1U^REGS.LWTA1L^REGS.SPCTL^REGS.SDCTL^REGS.CRAOFA^REGS.CRAOFB^REGS.LNCLEN^
							REGS.SFPRMD^REGS.CCCTL^REGS.SFCCMD^REGS.PRISA^REGS.PRISB^&REGS.PRISC^REGS.PRISD^REGS.PRINA^REGS.PRINB^REGS.PRIR^REGS.CCRSA^
							REGS.CCRSB^REGS.CCRSC^REGS.CCRSD^REGS.CCRNA^REGS.CCRNB^REGS.CCRR^REGS.CCRLB^REGS.CLOFEN^REGS.CLOFSL^REGS.COAR^REGS.COAG^REGS.COAB^REGS.COBR^REGS.COBG^REGS.COBB;
	
endmodule
