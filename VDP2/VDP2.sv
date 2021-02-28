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
	output      [1:0] RA0_WE,
	output            RA0_RD,
	
	output     [16:1] RA1_A,
	output     [15:0] RA1_D,
	input      [31:0] RA1_Q,
	output      [1:0] RA1_WE,
	output            RA1_RD,
	
	output     [16:1] RB0_A,
	output     [15:0] RB0_D,
	input      [31:0] RB0_Q,
	output      [1:0] RB0_WE,
	output            RB0_RD,
	
	output     [16:1] RB1_A,
	output     [15:0] RB1_D,
	input      [31:0] RB1_Q,
	output      [1:0] RB1_WE,
	output            RB1_RD,
	
	output      [7:0] R,
	output      [7:0] G,
	output      [7:0] B,
	output reg        DCLK,
	output reg        HS_N,
	output reg        VS_N,
	output reg        HBL_N,
	output reg        VBL_N,
	
	input       [4:0] SCRN_EN,
	
	output VRAMAccessState_t VA_PIPE0,
	output NVRAMAccess_t NBG_A0VA_DBG,
	output RxCHD_t CH_PIPE0,
	output RxCHD_t CH_PIPE1,
	output RxCHD_t CH_PIPE2,
	output DotData_t R0DOT_DBG,
	output DotData_t N0DOT_DBG,
	output DotData_t N1DOT_DBG,
	output DotData_t N2DOT_DBG,
	output DotData_t N3DOT_DBG,
	output ScreenDot_t DOT_FST_DBG,
	output ScreenDot_t DOT_SEC_DBG,
	output ScreenDot_t DOT_THD_DBG,
	output [18:0] N0SCX,
	output [18:0] N0SCY,
	output        CCEN_DBG,
	output [4:0]  CCRT_DBG,
	output RotTbl_t ROTA_TBL,
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
	wire VRAMA0_SEL = VRAM_SEL & (A[18:17] == 2'b00);
	wire VRAMA1_SEL = VRAM_SEL & (A[18:17] == 2'b01);
	wire VRAMB0_SEL = VRAM_SEL & (A[18:17] == 2'b10);
	wire VRAMB1_SEL = VRAM_SEL & (A[18:17] == 2'b11);
	
	bit DOT_CE,DOTH_CE;
	bit [8:0] H_CNT, V_CNT;
	bit [8:0] SCRX, SCRY;
	VRAMAccessPipeline_t VA_PIPE;
	BGPipeline_t BG_PIPE;
	PNPipe_t PN_PIPE;
	CHPipe_t CH_PIPE;
	RPNPipe_t RBG_PN_PIPE;
	RCHPipe_t RBG_CH_PIPE;
	ScrollData_t NxOFFX[4];
	ScrollData_t NxOFFY[4];
	ScrollData_t VS[2];
//	RotTbl_t ROTA_TBL;
	bit [29:0] Xsp,Ysp;
	bit [29:0] Xp,Yp;
	bit [29:0] dX,dY;
	bit [29:0] X,Y;
	CellDotsLine_t NBG_CDL[4];
	CellDotsLine_t RBG_CDL[2];
	NxCHCNT_t  NBG_CH_CNT;
	bit        NBG_CH_HF[4];
	bit  [6:0] NBG_CH_PALN[4];
	RxCHCNT_t  RBG_CH_CNT;
	bit [16:1] VRAMA0_A, VRAMA1_A, VRAMB0_A, VRAMB1_A;
	bit [15:0] VRAMA0_D, VRAMA1_D, VRAMB0_D, VRAMB1_D;
	bit [15:0] VRAMA0_Q, VRAMA1_Q, VRAMB0_Q, VRAMB1_Q;
	bit  [1:0] VRAMA0_WE, VRAMA1_WE, VRAMB0_WE, VRAMB1_WE;
	bit        VRAMA0_RD, VRAMA1_RD, VRAMB0_RD, VRAMB1_RD;
	bit        VRAMA_RW_PEND,VRAMB_RW_PEND;
	
	bit [15:0] PAL0_Q, PAL1_Q;
	bit [15:0] PAL0_DO, PAL1_DO;
	
	
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
	
	wire LAST_DOT = (H_CNT == HRES-1);
	wire PRELAST_DOT = (H_CNT == HRES-2);
	wire LAST_LINE = (V_CNT == VRES-1);
	
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
			if (LAST_DOT) begin
				H_CNT <= '0;
				V_CNT <= V_CNT + 9'd1;
				if (LAST_LINE) begin
					V_CNT <= '0;
				end
			end
			if (H_CNT == HS_START-1) begin
				HS_N <= 0;
			end else if (HS_END-1) begin
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
	bit RPA_FETCH;
	bit BACK_FETCH;
	bit LN_FETCH;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			BG_FETCH <= 0;
			SCRL_FETCH <= 0;
			RPA_FETCH <= 0;
			BACK_FETCH <= 0;
		end
		else if (DOT_CE) begin
			if (H_CNT == HRES-1 && !VBLANK) begin
				BG_FETCH <= 1;
			end else if (H_CNT == HBL_START-1) begin
				BG_FETCH <= 0;
			end
			
			if (H_CNT == 9'h197-1 && !VBLANK) begin
				SCRL_FETCH <= 1;
			end else if (H_CNT == 9'h19C) begin
				SCRL_FETCH <= 0;
			end
			
			if (H_CNT == 9'h17F-1 && !VBLANK) begin
				RPA_FETCH <= 1;
			end else if (H_CNT == 9'h196) begin
				RPA_FETCH <= 0;
			end
			
			if (H_CNT == 9'h1A0-1 && !VBLANK) begin
				BACK_FETCH <= 1;
			end else begin
				BACK_FETCH <= 0;
			end
			
			if (H_CNT == 9'h1A1-1 && !VBLANK) begin
				LN_FETCH <= 1;
			end else begin
				LN_FETCH <= 0;
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
			
		VA_PIPE[0].NxA0PN[0] = VCPA0 == VCP_N0PN & BG_FETCH & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1PN[0] = VCPA1 == VCP_N0PN & BG_FETCH & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0PN[0] = VCPB0 == VCP_N0PN & BG_FETCH & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1PN[0] = VCPB1 == VCP_N0PN & BG_FETCH & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA0PN[1] = VCPA0 == VCP_N1PN & BG_FETCH & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1PN[1] = VCPA1 == VCP_N1PN & BG_FETCH & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0PN[1] = VCPB0 == VCP_N1PN & BG_FETCH & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1PN[1] = VCPB1 == VCP_N1PN & BG_FETCH & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA0PN[2] = VCPA0 == VCP_N2PN & BG_FETCH & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1PN[2] = VCPA1 == VCP_N2PN & BG_FETCH & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0PN[2] = VCPB0 == VCP_N2PN & BG_FETCH & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1PN[2] = VCPB1 == VCP_N2PN & BG_FETCH & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA0PN[3] = VCPA0 == VCP_N3PN & BG_FETCH & REGS.BGON.N3ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1PN[3] = VCPA1 == VCP_N3PN & BG_FETCH & REGS.BGON.N3ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0PN[3] = VCPB0 == VCP_N3PN & BG_FETCH & REGS.BGON.N3ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1PN[3] = VCPB1 == VCP_N3PN & BG_FETCH & REGS.BGON.N3ON & REGS.TVMD.DISP;
		
		VA_PIPE[0].NxA0CH[0] = VCPA0 == VCP_N0CH & BG_FETCH & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1CH[0] = VCPA1 == VCP_N0CH & BG_FETCH & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0CH[0] = VCPB0 == VCP_N0CH & BG_FETCH & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1CH[0] = VCPB1 == VCP_N0CH & BG_FETCH & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA0CH[1] = VCPA0 == VCP_N1CH & BG_FETCH & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1CH[1] = VCPA1 == VCP_N1CH & BG_FETCH & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0CH[1] = VCPB0 == VCP_N1CH & BG_FETCH & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1CH[1] = VCPB1 == VCP_N1CH & BG_FETCH & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA0CH[2] = VCPA0 == VCP_N2CH & BG_FETCH & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1CH[2] = VCPA1 == VCP_N2CH & BG_FETCH & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0CH[2] = VCPB0 == VCP_N2CH & BG_FETCH & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1CH[2] = VCPB1 == VCP_N2CH & BG_FETCH & REGS.BGON.N2ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA0CH[3] = VCPA0 == VCP_N3CH & BG_FETCH & REGS.BGON.N3ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1CH[3] = VCPA1 == VCP_N3CH & BG_FETCH & REGS.BGON.N3ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0CH[3] = VCPB0 == VCP_N3CH & BG_FETCH & REGS.BGON.N3ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1CH[3] = VCPB1 == VCP_N3CH & BG_FETCH & REGS.BGON.N3ON & REGS.TVMD.DISP;
		
		VA_PIPE[0].NxA0VS[0] = VCPA0 == VCP_N0VS & BG_FETCH & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1VS[0] = VCPA1 == VCP_N0VS & BG_FETCH & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0VS[0] = VCPB0 == VCP_N0VS & BG_FETCH & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1VS[0] = VCPB1 == VCP_N0VS & BG_FETCH & REGS.BGON.N0ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA0VS[1] = VCPA0 == VCP_N1VS & BG_FETCH & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxA1VS[1] = VCPA1 == VCP_N1VS & BG_FETCH & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB0VS[1] = VCPB0 == VCP_N1VS & BG_FETCH & REGS.BGON.N1ON & REGS.TVMD.DISP;
		VA_PIPE[0].NxB1VS[1] = VCPB1 == VCP_N1VS & BG_FETCH & REGS.BGON.N1ON & REGS.TVMD.DISP;
		
		VA_PIPE[0].NxA0CPU = ((VCPA0 == VCP_CPU | VCPA0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxA1CPU = ((VCPA1 == VCP_CPU | VCPA1 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxB0CPU = ((VCPB0 == VCP_CPU | VCPB0 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		VA_PIPE[0].NxB1CPU = ((VCPB1 == VCP_CPU | VCPB1 == VCP_NA) & BG_FETCH) | VBLANK | ~REGS.TVMD.DISP;
		
		VA_PIPE[0].RxA0PN[0] = REGS.RAMCTL.RDBSA0 == 2'b10 & REGS.BGON.R0ON & BG_FETCH & ~VBLANK & REGS.TVMD.DISP;
		VA_PIPE[0].RxA1PN[0] = REGS.RAMCTL.RDBSA1 == 2'b10 & REGS.BGON.R0ON & BG_FETCH & ~VBLANK & REGS.TVMD.DISP;
		VA_PIPE[0].RxB0PN[0] = REGS.RAMCTL.RDBSB0 == 2'b10 & REGS.BGON.R0ON & BG_FETCH & ~VBLANK & REGS.TVMD.DISP;
		VA_PIPE[0].RxB1PN[0] = REGS.RAMCTL.RDBSB1 == 2'b10 & REGS.BGON.R0ON & BG_FETCH & ~VBLANK & REGS.TVMD.DISP;
		VA_PIPE[0].RxA0PN[1] = 0;
		VA_PIPE[0].RxA1PN[1] = 0;
		VA_PIPE[0].RxB0PN[1] = 0;
		VA_PIPE[0].RxB1PN[1] = 0;
		
		VA_PIPE[0].RxA0CH[0] = REGS.RAMCTL.RDBSA0 == 2'b11 & REGS.BGON.R0ON & BG_FETCH & ~VBLANK & REGS.TVMD.DISP;
		VA_PIPE[0].RxA1CH[0] = REGS.RAMCTL.RDBSA1 == 2'b11 & REGS.BGON.R0ON & BG_FETCH & ~VBLANK & REGS.TVMD.DISP;
		VA_PIPE[0].RxB0CH[0] = REGS.RAMCTL.RDBSB0 == 2'b11 & REGS.BGON.R0ON & BG_FETCH & ~VBLANK & REGS.TVMD.DISP;
		VA_PIPE[0].RxB1CH[0] = REGS.RAMCTL.RDBSB1 == 2'b11 & REGS.BGON.R0ON & BG_FETCH & ~VBLANK & REGS.TVMD.DISP;
		VA_PIPE[0].RxA0CH[1] = 0;
		VA_PIPE[0].RxA1CH[1] = 0;
		VA_PIPE[0].RxB0CH[1] = 0;
		VA_PIPE[0].RxB1CH[1] = 0;
		
		VA_PIPE[0].RxA0CO[0] = REGS.RAMCTL.RDBSA0 == 2'b01 & REGS.BGON.R0ON & BG_FETCH & ~VBLANK & REGS.TVMD.DISP;
		VA_PIPE[0].RxA1CO[0] = REGS.RAMCTL.RDBSA1 == 2'b01 & REGS.BGON.R0ON & BG_FETCH & ~VBLANK & REGS.TVMD.DISP;
		VA_PIPE[0].RxB0CO[0] = REGS.RAMCTL.RDBSB0 == 2'b01 & REGS.BGON.R0ON & BG_FETCH & ~VBLANK & REGS.TVMD.DISP;
		VA_PIPE[0].RxB1CO[0] = REGS.RAMCTL.RDBSB1 == 2'b01 & REGS.BGON.R0ON & BG_FETCH & ~VBLANK & REGS.TVMD.DISP;
		VA_PIPE[0].RxA0CO[1] = 0;
		VA_PIPE[0].RxA1CO[1] = 0;
		VA_PIPE[0].RxB0CO[1] = 0;
		VA_PIPE[0].RxB1CO[1] = 0;
		
		VA_PIPE[0].LS = SCRL_FETCH;
		VA_PIPE[0].LS_POS = LS_POS;
		VA_PIPE[0].RPA = RPA_FETCH;
		VA_PIPE[0].RPA_POS = RPA_POS;
		VA_PIPE[0].BS = BACK_FETCH;
		VA_PIPE[0].LN = LN_FETCH;
		
		VA_PIPE[0].NxX[0] <= NxOFFX[0].INT;
		VA_PIPE[0].NxX[1] <= NxOFFX[1].INT;
		VA_PIPE[0].NxX[2] <= NxOFFX[2].INT;
		VA_PIPE[0].NxX[3] <= NxOFFX[3].INT;
		VA_PIPE[0].NxY[0] <= NxOFFY[0].INT;
		VA_PIPE[0].NxY[1] <= NxOFFY[1].INT;
		VA_PIPE[0].NxY[2] <= NxOFFY[2].INT;
		VA_PIPE[0].NxY[3] <= NxOFFY[3].INT;
		VA_PIPE[0].R0X <= X[27:16];
		VA_PIPE[0].R0Y <= Y[27:16];
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
			VA_PIPE[4] <= VA_PIPE[3];
		end
	end
	
	
	assign SCRX = H_CNT;
	assign SCRY = V_CNT;
	
	VDP2NSxRegs_t NSxREG;
	VDP2RSxRegs_t RSxREG;
	
	assign NSxREG = NSxRegs(REGS);
	assign RSxREG = RSxRegs(REGS);
	
	NVRAMAccess_t NBG_A0VA;
	NVRAMAccess_t NBG_A1VA;
	NVRAMAccess_t NBG_B0VA;
	NVRAMAccess_t NBG_B1VA;
	RVRAMAccess_t RBG_A0VA;
	RVRAMAccess_t RBG_A1VA;
	RVRAMAccess_t RBG_B0VA;
	RVRAMAccess_t RBG_B1VA;
	bit       NxLSC;
	bit       RBG_RPA;
	always_comb begin
		NBG_A0VA.PN = |VA_PIPE[0].NxA0PN;
		NBG_A0VA.CH = |VA_PIPE[0].NxA0CH;
		NBG_A0VA.VS = |VA_PIPE[0].NxA0VS;
		NBG_A0VA.CPUA = VA_PIPE[0].NxA0CPU /*| (VCPA0 == VCP_NA & ~REGS.RAMCTL.VRAMD)*/;
		NBG_A0VA.CPUD = VA_PIPE[1].NxA0CPU /*| (VCPA0 == VCP_NA & ~REGS.RAMCTL.VRAMD)*/;
		NBG_A0VA.Nx = 2'd0;
		if (VA_PIPE[0].NxA0PN[0] || VA_PIPE[0].NxA0CH[0] || VA_PIPE[0].NxA0VS[0]) NBG_A0VA.Nx = 2'd0;
		if (VA_PIPE[0].NxA0PN[1] || VA_PIPE[0].NxA0CH[1] || VA_PIPE[0].NxA0VS[1]) NBG_A0VA.Nx = 2'd1;
		if (VA_PIPE[0].NxA0PN[2] || VA_PIPE[0].NxA0CH[2])                         NBG_A0VA.Nx = 2'd2;
		if (VA_PIPE[0].NxA0PN[3] || VA_PIPE[0].NxA0CH[3])                         NBG_A0VA.Nx = 2'd3;
		
		NBG_A1VA.PN = |VA_PIPE[0].NxA1PN;
		NBG_A1VA.CH = |VA_PIPE[0].NxA1CH;
		NBG_A1VA.VS = |VA_PIPE[0].NxA1VS;
		NBG_A1VA.CPUA = VA_PIPE[0].NxA0CPU /*| (VCPA0 == VCP_NA & ~REGS.RAMCTL.VRAMD)*/;//???
		NBG_A1VA.CPUD = VA_PIPE[1].NxA0CPU /*| (VCPA0 == VCP_NA & ~REGS.RAMCTL.VRAMD)*/;//???
		NBG_A1VA.Nx = 2'd0;
		if (VA_PIPE[0].NxA1PN[0] || VA_PIPE[0].NxA1CH[0] || VA_PIPE[0].NxA1VS[0]) NBG_A1VA.Nx = 2'd0;
		if (VA_PIPE[0].NxA1PN[1] || VA_PIPE[0].NxA1CH[1] || VA_PIPE[0].NxA1VS[1]) NBG_A1VA.Nx = 2'd1;
		if (VA_PIPE[0].NxA1PN[2] || VA_PIPE[0].NxA1CH[2])                         NBG_A1VA.Nx = 2'd2;
		if (VA_PIPE[0].NxA1PN[3] || VA_PIPE[0].NxA1CH[3])                         NBG_A1VA.Nx = 2'd3;
		
		NBG_B0VA.PN = |VA_PIPE[0].NxB0PN;
		NBG_B0VA.CH = |VA_PIPE[0].NxB0CH;
		NBG_B0VA.VS = |VA_PIPE[0].NxB0VS;
		NBG_B0VA.CPUA = VA_PIPE[0].NxB0CPU /*| (VCPB0 == VCP_NA & ~REGS.RAMCTL.VRBMD)*/;
		NBG_B0VA.CPUD = VA_PIPE[1].NxB0CPU /*| (VCPB0 == VCP_NA & ~REGS.RAMCTL.VRBMD)*/;
		NBG_B0VA.Nx = 2'd0;
		if (VA_PIPE[0].NxB0PN[0] || VA_PIPE[0].NxB0CH[0] || VA_PIPE[0].NxB0VS[0]) NBG_B0VA.Nx = 2'd0;
		if (VA_PIPE[0].NxB0PN[1] || VA_PIPE[0].NxB0CH[1] || VA_PIPE[0].NxB0VS[1]) NBG_B0VA.Nx = 2'd1;
		if (VA_PIPE[0].NxB0PN[2] || VA_PIPE[0].NxB0CH[2])                         NBG_B0VA.Nx = 2'd2;
		if (VA_PIPE[0].NxB0PN[3] || VA_PIPE[0].NxB0CH[3])                         NBG_B0VA.Nx = 2'd3;
		
		
		NBG_B1VA.PN = |VA_PIPE[0].NxB1PN;
		NBG_B1VA.CH = |VA_PIPE[0].NxB1CH;
		NBG_B1VA.VS = |VA_PIPE[0].NxB1VS;
		NBG_B1VA.CPUA = VA_PIPE[0].NxB0CPU /*| (VCPB0 == VCP_NA & ~REGS.RAMCTL.VRBMD)*/;//???
		NBG_B1VA.CPUD = VA_PIPE[1].NxB0CPU /*| (VCPB0 == VCP_NA & ~REGS.RAMCTL.VRBMD)*/;//???
		NBG_B1VA.Nx = 2'd0;
		if (VA_PIPE[0].NxB1PN[0] || VA_PIPE[0].NxB1CH[0] || VA_PIPE[0].NxB1VS[0]) NBG_B1VA.Nx = 2'd0;
		if (VA_PIPE[0].NxB1PN[1] || VA_PIPE[0].NxB1CH[1] || VA_PIPE[0].NxB1VS[1]) NBG_B1VA.Nx = 2'd1;
		if (VA_PIPE[0].NxB1PN[2] || VA_PIPE[0].NxB1CH[2])                         NBG_B1VA.Nx = 2'd2;
		if (VA_PIPE[0].NxB1PN[3] || VA_PIPE[0].NxB1CH[3])                         NBG_B1VA.Nx = 2'd3;
				
		RBG_A0VA.PN = |VA_PIPE[0].RxA0PN;
		RBG_A0VA.CH = |VA_PIPE[4].RxA0CH;
		RBG_A0VA.CO = |VA_PIPE[0].RxA0CO;
		RBG_A0VA.Rx = VA_PIPE[0].RxA0PN[1] | VA_PIPE[4].RxA0CH[1] | VA_PIPE[0].RxA0CO[1];
		
		RBG_A1VA.PN = |VA_PIPE[0].RxA1PN;
		RBG_A1VA.CH = |VA_PIPE[4].RxA1CH;
		RBG_A1VA.CO = |VA_PIPE[0].RxA1CO;
		RBG_A1VA.Rx = VA_PIPE[0].RxA1PN[1] | VA_PIPE[4].RxA1CH[1] | VA_PIPE[0].RxA1CO[1];
		
		RBG_B0VA.PN = |VA_PIPE[0].RxB0PN;
		RBG_B0VA.CH = |VA_PIPE[4].RxB0CH;
		RBG_B0VA.CO = |VA_PIPE[0].RxB0CO;
		RBG_B0VA.Rx = VA_PIPE[0].RxB0PN[1] | VA_PIPE[4].RxB0CH[1] | VA_PIPE[0].RxB0CO[1];
		
		RBG_B1VA.PN = |VA_PIPE[0].RxB1PN;
		RBG_B1VA.CH = |VA_PIPE[4].RxB1CH;
		RBG_B1VA.CO = |VA_PIPE[0].RxB1CO;
		RBG_B1VA.Rx = VA_PIPE[0].RxB1PN[1] | VA_PIPE[4].RxB1CH[1] | VA_PIPE[0].RxB1CO[1];
		
		RBG_RPA = VA_PIPE[1].RPA;
		
		NBG_A0VA_DBG = NBG_A0VA;
	end
	
	//Scroll data  
	ScrollData_t NSX[4];
	ScrollData_t NSY[4];
	ScrollData_t LSCX[2];
	ScrollData_t LSCY[2];
	CoordInc_t   LZMX[2];
	always @(posedge CLK or negedge RST_N) begin
		bit  [31:0] LS_WD;
		bit   [1:0] N;
		bit         RD0,RD1;
		
		N = {1'b0,VA_PIPE[1].LS_POS[2]};
		RD0 = ((VA_PIPE[1].LS_POS[5:3] & NxLSSMask(NSxREG[0].LSS)) == 3'b000);
		RD1 = ((VA_PIPE[1].LS_POS[5:3] & NxLSSMask(NSxREG[1].LSS)) == 3'b000);
		
		if (!RST_N) begin
			NSX <= '{4{'0}};
			NSY <= '{4{'0}};
			LSCX <= '{2{'0}};
			LSCY <= '{2{'0}};
			LZMX <= '{2{'0}};
		end
		else begin
			if (DOT_CE) begin
				if (BG_FETCH) begin
					NSX[0] <= NSX[0] + LZMX[0];
					NSX[1] <= NSX[1] + LZMX[1];
					NSX[2] <= NSX[2] + 19'h00100;
					NSX[3] <= NSX[3] + 19'h00100;
				end
				if (LAST_DOT) begin
//					if (!NSxREG[0].LSCX) NSX[0] <= NSxREG[0].SCX;
//					if (!NSxREG[1].LSCX) NSX[1] <= NSxREG[1].SCX;
//					                     NSX[2] <= NSxREG[2].SCX;
//					                     NSX[3] <= NSxREG[3].SCX;
					if (LAST_LINE) begin
						if (!NSxREG[0].LSCY) NSY[0] <= NSxREG[0].SCY;
						if (!NSxREG[1].LSCY) NSY[1] <= NSxREG[1].SCY;
						                     NSY[2] <= NSxREG[2].SCY;
						                     NSY[3] <= NSxREG[3].SCY;
					end
				end
				
				if (VA_PIPE[1].LS) begin
					case (LS_VRAM_BANK)
						2'b00: LS_WD = RA0_Q;
						2'b01: LS_WD = RA1_Q;
						2'b10: LS_WD = RB0_Q;
						2'b11: LS_WD = RB1_Q;
					endcase
					
					case (VA_PIPE[1].LS_POS[2:0])
						3'b000: begin
							if (!NSxREG[0].LSCX) NSX[0] <= NSxREG[0].SCX;
							else                 NSX[0] <= LS_WD[26:8];
					                           NSX[2] <= NSxREG[2].SCX;
						end
						3'b001: begin
							if (!NSxREG[0].LSCY) ;
							else if (RD0)        NSY[0] <= LS_WD[26:8];
							else                 NSY[0] <= NSY[0] + NSxREG[0].ZMY;
					                           NSY[2] <= NSY[2] + 19'h00100;
						end
						3'b010: begin
							if (!NSxREG[0].LZMX) LZMX[0] <= NSxREG[0].ZMX;
							else if (RD0)        LZMX[0] <= LS_WD[18:8];
						end
						
						3'b100: begin
							if (!NSxREG[1].LSCX) NSX[1] <= NSxREG[1].SCX;
							else                 NSX[1] <= LS_WD[26:8];
					                           NSX[3] <= NSxREG[3].SCX;
						end
						3'b101: begin
							if (!NSxREG[1].LSCY) ;
							else if (RD1)        NSY[1] <= LS_WD[26:8];
							else                 NSY[1] <= NSY[1] + NSxREG[1].ZMY;
					                           NSY[3] <= NSY[3] + 19'h00100;
						end
						3'b110: begin
							if (!NSxREG[1].LZMX) LZMX[1] <= NSxREG[1].ZMX;
							else if (RD1)        LZMX[1] <= LS_WD[18:8];
						end
					endcase

				end
			end
		end
	end
	
	//Rotation parameters
		bit [29:0]  Xst2,Yst2;
		bit [29:0]  Xsp2,Ysp2;
	always @(posedge CLK or negedge RST_N) begin
		bit [29:0]  Xst;		//00
		bit [29:0]  Yst;		//04
		bit [29:0]  Zst;		//08
		bit [29:0]  DXst;		//0C
		bit [29:0]  DYst;		//10
		bit [29:0]  DX;		//14
		bit [29:0]  DY;		//18
		bit [29:0]  A;			//1C
		bit [29:0]  B;			//20
		bit [29:0]  C;			//24
		bit [29:0]  D;			//28
		bit [29:0]  E;			//2C
		bit [29:0]  F;			//30
		bit [13:0]  PX;		//34
		bit [13:0]  PY;		//36
		bit [13:0]  PZ;		//38
		bit [13:0]  CX;		//3C
		bit [13:0]  CY;		//3E
		bit [13:0]  CZ;		//40
		bit [29:0]  MX;		//44
		bit [29:0]  MY;		//48
		bit [29:0]  KX;		//4C
		bit [29:0]  KY;		//50
		TblAddr_t   KAst;		//54
		AddrInc_t   DKAst;	//58
		AddrInc_t   DKAx;		//5C
		
		bit  [31:0] RP_WD;
		bit  CALC;
		
		if (!RST_N) begin
			ROTA_TBL <= '{32'h000000A0,32'h00000070,32'h00000000,
							32'h00000000,32'h0000FFFF,
							32'h0000FFFF,32'h00000000,
							32'h00009456,32'h3FFF2F60,32'h00000000,32'h0000D0A0,32'h00009456,32'h00000000,
							16'h00A0,16'h0070,16'h0190,16'h0000,
							16'h00A0,16'h0070,16'h0000,16'h0000,
							32'h00300000,32'h00600000,
							32'h00010000,32'h00010000,
							32'h00000000,32'h00000000,32'h00000000};
			Xsp <= '0;
			Ysp <= '0;
			Xp <= '0;
			Yp <= '0;
			dX <= '0;
			dY <= '0;
			Xst2 <= '0;
			Yst2 <= '0;
		end
		else begin
			Xst = {ROTA_TBL.Xst.INT[12],ROTA_TBL.Xst.INT,ROTA_TBL.Xst.FRAC,6'b000000};
			Yst = {ROTA_TBL.Yst.INT[12],ROTA_TBL.Yst.INT,ROTA_TBL.Yst.FRAC,6'b000000};
			Zst = {ROTA_TBL.Zst.INT[12],ROTA_TBL.Zst.INT,ROTA_TBL.Zst.FRAC,6'b000000};
			DXst = {{11{ROTA_TBL.DXst.INT[2]}},ROTA_TBL.DXst.INT,ROTA_TBL.DXst.FRAC,6'b000000};
			DYst = {{11{ROTA_TBL.DYst.INT[2]}},ROTA_TBL.DYst.INT,ROTA_TBL.DYst.FRAC,6'b000000};
			DX = {{11{ROTA_TBL.DX.INT[2]}},ROTA_TBL.DX.INT,ROTA_TBL.DX.FRAC,6'b000000};
			DY = {{11{ROTA_TBL.DY.INT[2]}},ROTA_TBL.DY.INT,ROTA_TBL.DY.FRAC,6'b000000};
			A = {{10{ROTA_TBL.A.INT[3]}},ROTA_TBL.A.INT,ROTA_TBL.A.FRAC,6'b000000};
			B = {{10{ROTA_TBL.B.INT[3]}},ROTA_TBL.B.INT,ROTA_TBL.B.FRAC,6'b000000};
			C = {{10{ROTA_TBL.C.INT[3]}},ROTA_TBL.C.INT,ROTA_TBL.C.FRAC,6'b000000};
			D = {{10{ROTA_TBL.D.INT[3]}},ROTA_TBL.D.INT,ROTA_TBL.D.FRAC,6'b000000};
			E = {{10{ROTA_TBL.E.INT[3]}},ROTA_TBL.E.INT,ROTA_TBL.E.FRAC,6'b000000};
			F = {{10{ROTA_TBL.F.INT[3]}},ROTA_TBL.F.INT,ROTA_TBL.F.FRAC,6'b000000};
			PX = ROTA_TBL.PX.INT;
			PY = ROTA_TBL.PY.INT;
			PZ = ROTA_TBL.PZ.INT;
			CX = ROTA_TBL.CX.INT;
			CY = ROTA_TBL.CY.INT;
			CZ = ROTA_TBL.CZ.INT;
			MX = {ROTA_TBL.MX.INT,ROTA_TBL.MX.FRAC,6'b000000};
			MY = {ROTA_TBL.MY.INT,ROTA_TBL.MY.FRAC,6'b000000};
			KX = {{6{ROTA_TBL.KX.INT[7]}},ROTA_TBL.KX.INT,ROTA_TBL.KX.FRAC};
			KY = {{6{ROTA_TBL.KY.INT[7]}},ROTA_TBL.KY.INT,ROTA_TBL.KY.FRAC};
			
			CALC <= 0;
			if (CALC) begin
				Xst2 <= $signed(Xst2) + $signed(DXst);
				Yst2 <= $signed(Yst2) + $signed(DYst);
				if (LAST_LINE) begin
					Xst2 <= Xst;
					Yst2 <= Yst;
				end
			end
			if (DOT_CE) begin
				Xsp2 <= $signed(Xsp2) + $signed(dX);
				Ysp2 <= $signed(Ysp2) + $signed(dY);
				if (PRELAST_DOT) begin
					Xsp <= $signed(MultFF(A,($signed(Xst2) - $signed({PX,16'h0000})))) + $signed(MultFF(B,($signed(Yst2) - $signed({PY,16'h0000})))) + $signed(MultFF(C,($signed(Zst) - $signed({PZ,16'h0000}))));
					Ysp <= $signed(MultFF(D,($signed(Xst2) - $signed({PX,16'h0000})))) + $signed(MultFF(E,($signed(Yst2) - $signed({PY,16'h0000})))) + $signed(MultFF(F,($signed(Zst) - $signed({PZ,16'h0000}))));
					Xp  <= $signed(MultFI(A,($signed(PX) - $signed(CX)))) + $signed(MultFI(B,($signed(PY) - $signed(CY)))) + $signed(MultFI(C,($signed(PZ) - $signed(CZ)))) + $signed({CX,16'h0000}) + $signed(MX);
					Yp  <= $signed(MultFI(D,($signed(PX) - $signed(CX)))) + $signed(MultFI(E,($signed(PY) - $signed(CY)))) + $signed(MultFI(F,($signed(PZ) - $signed(CZ)))) + $signed({CY,16'h0000}) + $signed(MY);
					dX  <= $signed(MultFF(A,DX)) + $signed(MultFI(B,DY));
					dY  <= $signed(MultFF(D,DX)) + $signed(MultFI(E,DY));
					Xsp2 <= Xsp;
					Ysp2 <= Ysp;
				end
				if (LAST_DOT) begin
					
				end
				X <= $signed(MultFF(KX,Xsp2)) + $signed(Xp);
				Y <= $signed(MultFF(KY,Ysp2)) + $signed(Yp);
				
				if (VA_PIPE[1].RPA) begin
					case (RxRPA_VRAM_BANK)
						2'b00: RP_WD = RA0_Q;
						2'b01: RP_WD = RA1_Q;
						2'b10: RP_WD = RB0_Q;
						2'b11: RP_WD = RB1_Q;
					endcase
					case (VA_PIPE[1].RPA_POS)
						5'd00: ROTA_TBL.Xst <= RP_WD;
						5'd01: ROTA_TBL.Yst <= RP_WD;
						5'd02: ROTA_TBL.Zst <= RP_WD;
						5'd03: ROTA_TBL.DXst <= RP_WD;
						5'd04: ROTA_TBL.DYst <= RP_WD;
						5'd05: ROTA_TBL.DX <= RP_WD;
						5'd06: ROTA_TBL.DY <= RP_WD;
						5'd07: ROTA_TBL.A <= RP_WD;
						5'd08: ROTA_TBL.B <= RP_WD;
						5'd09: ROTA_TBL.C <= RP_WD;
						5'd10: ROTA_TBL.D <= RP_WD;
						5'd11: ROTA_TBL.E <= RP_WD;
						5'd12: ROTA_TBL.F <= RP_WD;
						5'd13: {ROTA_TBL.PX,ROTA_TBL.PY} <= RP_WD;
						5'd14: ROTA_TBL.PZ <= RP_WD[31:16];
						5'd15: {ROTA_TBL.CX,ROTA_TBL.CY} <= RP_WD;
						5'd16: ROTA_TBL.CZ <= RP_WD[31:16];
						5'd17: ROTA_TBL.MX <= RP_WD;
						5'd18: ROTA_TBL.MY <= RP_WD;
						5'd19: ROTA_TBL.KX <= RP_WD;
						5'd20: ROTA_TBL.KY <= RP_WD;
						5'd21: ROTA_TBL.KAst <= RP_WD;
						5'd22: ROTA_TBL.DKAst <= RP_WD;
						5'd23: begin ROTA_TBL.DKAx <= RP_WD; CALC <= 1; end
					endcase
				end
			end
		end
	end
	
	//Back&line screen  
	Color_t BACK_COL;
	Color_t LINE_PAL;
	always @(posedge CLK or negedge RST_N) begin
		bit  [15:0] WD;
		
		if (!RST_N) begin
			BACK_COL <= C_NULL;
			LINE_PAL <= '0;
		end
		else begin
			if (DOT_CE) begin
				case (BS_VRAM_BANK)
					2'b00: WD = RA0_Q[31:16];
					2'b01: WD = RA1_Q[31:16];
					2'b10: WD = RB0_Q[31:16];
					2'b11: WD = RB1_Q[31:16];
				endcase
				
				if (VA_PIPE[1].BS) begin
					BACK_COL <= Color555To888(WD);
				end
				
				if (VA_PIPE[1].LN) begin
					LINE_PAL <= WD[10:0];
				end
			end
		end
	end
	
	ScrollData_t SCX[4];
	ScrollData_t SCY[4];
	always_comb begin
		SCX[0] = {REGS.SCXIN0.NxSCXI,REGS.SCXDN0.NxSCXD} + LSCX[0];
		SCY[0] = {REGS.SCYIN0.NxSCYI,REGS.SCYDN0.NxSCYD} + LSCY[0] + VS[0];
		SCX[1] = {REGS.SCXIN1.NxSCXI,REGS.SCXDN1.NxSCXD} + LSCX[1];
		SCY[1] = {REGS.SCYIN1.NxSCYI,REGS.SCYDN1.NxSCYD} + LSCY[1] + VS[1];
		SCX[2] = {REGS.SCXN2.NxSCX,8'h00};
		SCY[2] = {REGS.SCYN2.NxSCY,8'h00};
		SCX[3] = {REGS.SCXN3.NxSCX,8'h00};
		SCY[3] = {REGS.SCYN3.NxSCY,8'h00};
		
		NxOFFX[0] = NSX[0];
		NxOFFY[0] = NSY[0] + VS[0];
		NxOFFX[1] = NSX[1];
		NxOFFY[1] = NSY[1] + VS[1];
		NxOFFX[2] = NSX[2];
		NxOFFY[2] = NSY[2];
		NxOFFX[3] = NSX[3];
		NxOFFY[3] = NSY[3];
	end
	
//	bit NxPN_VRAMA0_A1,NxPN_VRAMA1_A1,NxPN_VRAMB0_A1,NxPN_VRAMB1_A1;
//	bit NxOFFX3[4];
	bit  [1:0] LS_VRAM_BANK;
	bit  [5:0] LS_POS;
	bit [19:2] LS_OFFS[2];
	bit  [1:0] RxRPA_VRAM_BANK;
	bit  [6:2] RPA_POS;
	bit [19:1] BS_OFFS;
	bit [19:1] LN_OFFS;
	bit  [1:0] BS_VRAM_BANK;
	always @(posedge CLK or negedge RST_N) begin
		bit   [19:1] NxPN_ADDR[4];
		bit   [19:1] RxPN_ADDR[2];
		bit   [19:1] NxCH_ADDR[4];
		bit   [19:1] RxCH_ADDR[2];
		bit   [19:1] N0VS_ADDR;
		bit   [19:1] NxLS_ADDR[2];
		bit   [19:1] RxRPA_ADDR;
		bit   [19:1] BS_ADDR;
		bit   [19:1] LN_ADDR;
		bit VRAM_RW_PEND2;
		
		if (!RST_N) begin
			VRAMA0_A <= '0;
			VRAMA1_A <= '0;
			VRAMB0_A <= '0;
			VRAMB1_A <= '0;
			VRAMA0_WE <= 0;
			VRAMA1_WE <= 0;
			VRAMB0_WE <= 0;
			VRAMB1_WE <= 0;
			VRAMA0_RD <= 0;
			VRAMA1_RD <= 0;
			VRAMB0_RD <= 0;
			VRAMB1_RD <= 0;
			NBG_CH_CNT <= '{4{'0}};
			RBG_CH_CNT <= '{2{'0}};
			RPA_POS <= '0;
			LS_POS <= '0;
		end
		else if (DOTH_CE) begin
			NxPN_ADDR[0] = NxPNAddr(NxOFFX[0].INT, NxOFFY[0].INT, NSxREG[0].MP, NSxREG[0].MPA, NSxREG[0].MPB, NSxREG[0].MPC, NSxREG[0].MPD, NSxREG[0].PLSZ, NSxREG[0].CHSZ, NSxREG[0].PNC.NxPNB);
			NxPN_ADDR[1] = NxPNAddr(NxOFFX[1].INT, NxOFFY[1].INT, NSxREG[1].MP, NSxREG[1].MPA, NSxREG[1].MPB, NSxREG[1].MPC, NSxREG[1].MPD, NSxREG[1].PLSZ, NSxREG[1].CHSZ, NSxREG[1].PNC.NxPNB);
			NxPN_ADDR[2] = NxPNAddr(NxOFFX[2].INT, NxOFFY[2].INT, NSxREG[2].MP, NSxREG[2].MPA, NSxREG[2].MPB, NSxREG[2].MPC, NSxREG[2].MPD, NSxREG[2].PLSZ, NSxREG[2].CHSZ, NSxREG[2].PNC.NxPNB);
			NxPN_ADDR[3] = NxPNAddr(NxOFFX[3].INT, NxOFFY[3].INT, NSxREG[3].MP, NSxREG[3].MPA, NSxREG[3].MPB, NSxREG[3].MPC, NSxREG[3].MPD, NSxREG[3].PLSZ, NSxREG[3].CHSZ, NSxREG[3].PNC.NxPNB);
			RxPN_ADDR[0] = RxPNAddr(X[27:16], Y[27:16], REGS.MPOFR.RAMP, REGS.MPABRA.RxMPA, REGS.MPABRA.RxMPB, REGS.MPCDRA.RxMPC, REGS.MPCDRA.RxMPD, 
			                                                  REGS.MPEFRA.RxMPE, REGS.MPEFRA.RxMPE, REGS.MPGHRA.RxMPG, REGS.MPGHRA.RxMPH, 
																			  REGS.MPIJRA.RxMPI, REGS.MPIJRA.RxMPJ, REGS.MPKLRA.RxMPK, REGS.MPKLRA.RxMPL, 
																			  REGS.MPMNRA.RxMPM, REGS.MPMNRA.RxMPN, REGS.MPOPRA.RxMPO, REGS.MPOPRA.RxMPP, 
			                        REGS.PLSZ.RAPLSZ, RSxREG[0].CHSZ, RSxREG[0].PNC.NxPNB);
			
			NxCH_ADDR[0] = !NSxREG[0].BMEN ? NxCHAddr(PN_PIPE[2][0], NBG_CH_CNT[0], VA_PIPE[4].NxX[0], VA_PIPE[4].NxY[0], NSxREG[0].CHCN, NSxREG[0].CHSZ) :
												      NxBMAddr(NSxREG[0].MP,  NBG_CH_CNT[0], VA_PIPE[4].NxX[0], VA_PIPE[4].NxY[0], NSxREG[0].CHCN, NSxREG[0].BMSZ);
			NxCH_ADDR[1] = !NSxREG[1].BMEN ? NxCHAddr(PN_PIPE[2][1], NBG_CH_CNT[1], VA_PIPE[4].NxX[1], VA_PIPE[4].NxY[1], NSxREG[1].CHCN, NSxREG[1].CHSZ) :
												      NxBMAddr(NSxREG[1].MP,  NBG_CH_CNT[1], VA_PIPE[4].NxX[1], VA_PIPE[4].NxY[1], NSxREG[1].CHCN, NSxREG[1].BMSZ);
			NxCH_ADDR[2] =                   NxCHAddr(PN_PIPE[2][2], NBG_CH_CNT[2], VA_PIPE[4].NxX[2], VA_PIPE[4].NxY[2], NSxREG[2].CHCN, NSxREG[2].CHSZ);
			NxCH_ADDR[3] =                   NxCHAddr(PN_PIPE[2][3], NBG_CH_CNT[3], VA_PIPE[4].NxX[3], VA_PIPE[4].NxY[3], NSxREG[3].CHCN, NSxREG[3].CHSZ);
			
			RxCH_ADDR[0] = !RSxREG[0].BMEN ? RxCHAddr(RBG_PN_PIPE[2][0], VA_PIPE[4].R0X, VA_PIPE[4].R0Y, RSxREG[0].CHCN, RSxREG[0].CHSZ) :
												      RxBMAddr(REGS.MPOFR.RAMP,  VA_PIPE[4].R0X[2:0], SCRX, SCRY, RSxREG[0].CHCN, RSxREG[0].BMSZ);
			
			N0VS_ADDR = {1'b0,NSxREG[0].VCSTA} + {13'h000,SCRX[8:3]};
			
			NxLS_ADDR[0] = NxLSAddr(NSxREG[0].LSTA, LS_OFFS[0]);
			NxLS_ADDR[1] = NxLSAddr(NSxREG[1].LSTA, LS_OFFS[1]);
			
			RxRPA_ADDR = ({REGS.RPTAU.RPTA,REGS.RPTAL.RPTA,1'b0} & ~19'h00080) + {RPA_POS,1'b0};
			
			BS_ADDR = {REGS.BKTAU.BKTA,REGS.BKTAL.BKTA} + BS_OFFS;
			LN_ADDR = {REGS.LCTAU.LCTA,REGS.LCTAL.LCTA} + LN_OFFS;
		
			if (!REGS.TVMD.DISP || VBLANK || (!REGS.BGON.N0ON && !REGS.BGON.N1ON && !REGS.BGON.N2ON && !REGS.BGON.N3ON && !REGS.BGON.R0ON)) begin
				VRAMA0_A <= A[16:1];
				VRAMA1_A <= A[16:1];
				VRAMB0_A <= A[16:1];
				VRAMB1_A <= A[16:1];
				VRAMA0_D <= DI;
				VRAMA1_D <= DI;
				VRAMB0_D <= DI;
				VRAMB1_D <= DI;
				VRAMA0_WE <= ~WE_N & {2{VRAMA0_SEL}};
				VRAMA1_WE <= ~WE_N & {2{VRAMA1_SEL}};
				VRAMB0_WE <= ~WE_N & {2{VRAMB0_SEL}};
				VRAMB1_WE <= ~WE_N & {2{VRAMB1_SEL}};
				VRAMA0_RD <= &WE_N & (VRAMA0_SEL|VRAMA1_SEL);
				VRAMA1_RD <= &WE_N & (VRAMA0_SEL|VRAMA1_SEL);
				VRAMB0_RD <= &WE_N & (VRAMB0_SEL|VRAMB1_SEL);
				VRAMB1_RD <= &WE_N & (VRAMB0_SEL|VRAMB1_SEL);
				VRAMA_RW_PEND <= VRAMA0_SEL|VRAMA1_SEL;
				VRAMB_RW_PEND <= VRAMB0_SEL|VRAMB1_SEL;
			end else if (BG_FETCH) begin
				VRAMA0_RD <= 0;
				VRAMA1_RD <= 0;
				if (NBG_A0VA.PN) begin
					VRAMA0_A <= NxPN_ADDR[NBG_A0VA.Nx][16:1];
					VRAMA0_RD <= 1;
				end else if (RBG_A0VA.PN) begin
					VRAMA0_A <= RxPN_ADDR[RBG_A0VA.Rx][16:1];
					VRAMA0_RD <= 1;
				end else if (NBG_A0VA.CH) begin
					VRAMA0_A <= NxCH_ADDR[NBG_A0VA.Nx][16:1];
					VRAMA0_RD <= 1;
				end else if (RBG_A0VA.CH) begin
					VRAMA0_A <= RxCH_ADDR[RBG_A0VA.Rx][16:1];
					VRAMA0_RD <= 1;
				end else	if (NBG_A0VA.VS) begin
					VRAMA0_A <= N0VS_ADDR[16:1];
					VRAMA0_RD <= 1;
				end else	if (NBG_A0VA.CPUA && (VRAMA0_SEL || VRAMA1_SEL)) begin
					VRAMA0_A <= A[16:1];
					VRAMA1_A <= A[16:1];
					VRAMA0_D <= DI;
					VRAMA1_D <= DI;
					VRAMA0_WE <= ~WE_N & {2{VRAMA0_SEL}};
					VRAMA1_WE <= ~WE_N & {2{VRAMA1_SEL}};
					VRAMA0_RD <= &WE_N;
					VRAMA1_RD <= &WE_N;
					VRAMA_RW_PEND <= VRAMA0_SEL|VRAMA1_SEL;
				end
				
				if (NBG_A1VA.PN) begin
					VRAMA1_A <= NxPN_ADDR[NBG_A1VA.Nx][16:1];
					VRAMA1_RD <= 1;
				end else if (RBG_A1VA.PN) begin
					VRAMA1_A <= RxPN_ADDR[RBG_A1VA.Rx][16:1];
					VRAMA1_RD <= 1;
				end else	if (NBG_A1VA.CH) begin
					VRAMA1_A <= NxCH_ADDR[NBG_A1VA.Nx][16:1];
					VRAMA1_RD <= 1;
				end else	if (RBG_A1VA.CH) begin
					VRAMA1_A <= RxCH_ADDR[RBG_A1VA.Rx][16:1];
					VRAMA1_RD <= 1;
				end else	if (NBG_A1VA.VS) begin
					VRAMA1_A <= N0VS_ADDR[16:1];
					VRAMA1_RD <= 1;
//				end else	if (NBG_A1VA.CPUA) begin
//					VRAMA1_A <= A[16:1];
//					VRAMA1_D <= DI;
//					VRAMA1_WE <= ~WE_N & {2{VRAMA1_SEL}};
//					VRAMA1_RD <= &WE_N & VRAMA1_SEL;
//					VRAM_RW_PEND <= VRAMA1_SEL;
				end
				
				VRAMB0_RD <= 0;
				VRAMB1_RD <= 0;
				if (NBG_B0VA.PN) begin
					VRAMB0_A <= NxPN_ADDR[NBG_B0VA.Nx][16:1];
					VRAMB0_RD <= 1;
				end else if (RBG_B0VA.PN) begin
					VRAMB0_A <= RxPN_ADDR[RBG_B0VA.Rx][16:1];
					VRAMB0_RD <= 1;
				end else	if (NBG_B0VA.CH) begin
					VRAMB0_A <= NxCH_ADDR[NBG_B0VA.Nx][16:1];
					VRAMB0_RD <= 1;
				end else	if (RBG_B0VA.CH) begin
					VRAMB0_A <= RxCH_ADDR[RBG_B0VA.Rx][16:1];
					VRAMB0_RD <= 1;
				end else	if (NBG_B0VA.VS) begin
					VRAMB0_A <= N0VS_ADDR[16:1];
					VRAMB0_RD <= 1;
				end else	if (NBG_B0VA.CPUA && (VRAMB0_SEL || VRAMB1_SEL)) begin
					VRAMB0_A <= A[16:1];
					VRAMB1_A <= A[16:1];
					VRAMA0_D <= DI;
					VRAMB1_D <= DI;
					VRAMB0_WE <= ~WE_N & {2{VRAMB0_SEL}};
					VRAMB1_WE <= ~WE_N & {2{VRAMB1_SEL}};
					VRAMB0_RD <= &WE_N;
					VRAMB1_RD <= &WE_N;
					VRAMB_RW_PEND <= VRAMB0_SEL|VRAMB1_SEL;
				end
				
				if (NBG_B1VA.PN) begin
					VRAMB1_A <= NxPN_ADDR[NBG_B1VA.Nx][16:1];
					VRAMB1_RD <= 1;
				end else if (RBG_B1VA.PN) begin
					VRAMB1_A <= RxPN_ADDR[RBG_B1VA.Rx][16:1];
					VRAMB1_RD <= 1;
				end else	if (NBG_B1VA.CH) begin
					VRAMB1_A <= NxCH_ADDR[NBG_B1VA.Nx][16:1];
					VRAMB1_RD <= 1;
				end else	if (RBG_B1VA.CH) begin
					VRAMB1_A <= RxCH_ADDR[RBG_B1VA.Rx][16:1];
					VRAMB1_RD <= 1;
				end else	if (NBG_B1VA.VS) begin
					VRAMB1_A <= N0VS_ADDR[16:1];
					VRAMB1_RD <= 1;
//				end else	if (NBG_B1VA.CPUA) begin
//					VRAMB1_A <= A[16:1];
//					VRAMB1_D <= DI;
//					VRAMB1_WE <= ~WE_N & {2{VRAMB1_SEL}};
//					VRAMB1_RD <= &WE_N & VRAMB1_SEL;
//					VRAM_RW_PEND <= VRAMB1_SEL;
				end
			end else if (SCRL_FETCH) begin
				VRAMA0_A <= NxLS_ADDR[LS_POS[2]][16:1];
				VRAMA1_A <= NxLS_ADDR[LS_POS[2]][16:1];
				VRAMB0_A <= NxLS_ADDR[LS_POS[2]][16:1];
				VRAMB1_A <= NxLS_ADDR[LS_POS[2]][16:1];
				VRAMA0_RD <= NxLS_ADDR[LS_POS[2]][18:17] == 2'b00;
				VRAMA1_RD <= NxLS_ADDR[LS_POS[2]][18:17] == 2'b01;
				VRAMB0_RD <= NxLS_ADDR[LS_POS[2]][18:17] == 2'b10;
				VRAMB1_RD <= NxLS_ADDR[LS_POS[2]][18:17] == 2'b11;
			end else if (RPA_FETCH) begin
				VRAMA0_A <= RxRPA_ADDR[16:1];
				VRAMA1_A <= RxRPA_ADDR[16:1];
				VRAMB0_A <= RxRPA_ADDR[16:1];
				VRAMB1_A <= RxRPA_ADDR[16:1];
				VRAMA0_RD <= RxRPA_ADDR[18:17] == 2'b00;
				VRAMA1_RD <= RxRPA_ADDR[18:17] == 2'b01;
				VRAMB0_RD <= RxRPA_ADDR[18:17] == 2'b10;
				VRAMB1_RD <= RxRPA_ADDR[18:17] == 2'b11;
			end else if (BACK_FETCH) begin
				VRAMA0_A <= BS_ADDR[16:1];
				VRAMA1_A <= BS_ADDR[16:1];
				VRAMB0_A <= BS_ADDR[16:1];
				VRAMB1_A <= BS_ADDR[16:1];
				VRAMA0_RD <= BS_ADDR[18:17] == 2'b00;
				VRAMA1_RD <= BS_ADDR[18:17] == 2'b01;
				VRAMB0_RD <= BS_ADDR[18:17] == 2'b10;
				VRAMB1_RD <= BS_ADDR[18:17] == 2'b11;
			end else if (LN_FETCH) begin
				VRAMA0_A <= LN_ADDR[16:1];
				VRAMA1_A <= LN_ADDR[16:1];
				VRAMB0_A <= LN_ADDR[16:1];
				VRAMB1_A <= LN_ADDR[16:1];
				VRAMA0_RD <= LN_ADDR[18:17] == 2'b00;
				VRAMA1_RD <= LN_ADDR[18:17] == 2'b01;
				VRAMB0_RD <= LN_ADDR[18:17] == 2'b10;
				VRAMB1_RD <= LN_ADDR[18:17] == 2'b11;
			end
			
			if (!REGS.TVMD.DISP || VBLANK || (!REGS.BGON.N0ON && !REGS.BGON.N1ON && !REGS.BGON.N2ON && !REGS.BGON.N3ON && !REGS.BGON.R0ON)) begin
				if (VRAMA_RW_PEND) begin
					VRAMA0_WE <= 0;
					VRAMA1_WE <= 0;
					VRAMA0_RD <= 0;
					VRAMA1_RD <= 0;
					VRAMA_RW_PEND <= 0;
					VRAM_RW_PEND2 <= 1;
				end
				if (VRAMB_RW_PEND) begin
					VRAMB0_WE <= 0;
					VRAMB1_WE <= 0;
					VRAMB0_RD <= 0;
					VRAMB1_RD <= 0;
					VRAMB_RW_PEND <= 0;
					VRAM_RW_PEND2 <= 1;
				end
			end else begin
				if (NBG_A0VA.CPUD && VRAMA_RW_PEND) begin
					VRAMA0_WE <= 0;
					VRAMA1_WE <= 0;
					VRAMA0_RD <= 0;
					VRAMA1_RD <= 0;
					VRAMA_RW_PEND <= 0;
					VRAM_RW_PEND2 <= 1;
				end
				if (NBG_B0VA.CPUD && VRAMB_RW_PEND) begin
					VRAMB0_WE <= 0;
					VRAMB1_WE <= 0;
					VRAMB0_RD <= 0;
					VRAMB1_RD <= 0;
					VRAMB_RW_PEND <= 0;
					VRAM_RW_PEND2 <= 1;
				end
			end
		end
		else if (DOT_CE) begin
			if (!REGS.TVMD.DISP || VBLANK || (!REGS.BGON.N0ON && !REGS.BGON.N1ON && !REGS.BGON.N2ON && !REGS.BGON.N3ON && !REGS.BGON.R0ON)) begin
				
			end else if (BG_FETCH) begin
				if (NBG_A0VA.PN) begin
//					NxPN_VRAMA0_A1 <= NxPN_ADDR[NBG_A0VA.Nx][1];
				end else if (NBG_A0VA.CH) begin
					NBG_CH_CNT[NBG_A0VA.Nx] <= NBG_CH_CNT[NBG_A0VA.Nx] + 3'd1;
				end else if (RBG_A0VA.CH) begin
					RBG_CH_CNT[RBG_A0VA.Rx] <= RBG_CH_CNT[RBG_A0VA.Rx] + 3'd1;
				end
				
				if (NBG_A1VA.PN) begin
//					NxPN_VRAMA1_A1 <= NxPN_ADDR[NBG_A1VA.Nx][1];
				end else	if (NBG_A1VA.CH) begin
					NBG_CH_CNT[NBG_A1VA.Nx] <= NBG_CH_CNT[NBG_A1VA.Nx] + 3'd1;
				end else if (RBG_A1VA.CH) begin
					RBG_CH_CNT[RBG_A1VA.Rx] <= RBG_CH_CNT[RBG_A1VA.Rx] + 3'd1;
				end
				
				if (NBG_B0VA.PN) begin
//					NxPN_VRAMB0_A1 <= NxPN_ADDR[NBG_B0VA.Nx][1];
				end else	if (NBG_B0VA.CH) begin
					NBG_CH_CNT[NBG_B0VA.Nx] <= NBG_CH_CNT[NBG_B0VA.Nx] + 3'd1;
				end else if (RBG_B0VA.CH) begin
					RBG_CH_CNT[RBG_B0VA.Rx] <= RBG_CH_CNT[RBG_B0VA.Rx] + 3'd1;
				end
				
				if (NBG_B1VA.PN) begin
//					NxPN_VRAMB1_A1 <= NxPN_ADDR[NBG_B1VA.Nx][1];
				end else	if (NBG_B1VA.CH) begin
					NBG_CH_CNT[NBG_B1VA.Nx] <= NBG_CH_CNT[NBG_B1VA.Nx] + 3'd1;
				end else if (RBG_B1VA.CH) begin
					RBG_CH_CNT[RBG_B1VA.Rx] <= RBG_CH_CNT[RBG_B1VA.Rx] + 3'd1;
				end
			end else if (SCRL_FETCH) begin
				LS_VRAM_BANK <= NxLS_ADDR[LS_POS[2]][18:17];
				LS_POS <= LS_POS + 6'd1;
				if (LS_POS[1:0] == 2'd2) LS_POS <= LS_POS + 6'd2;
				if ((LS_POS[5:3] & NxLSSMask(NSxREG[{1'b0,LS_POS[2]}].LSS)) == 3'b000) begin
					case (LS_POS[1:0])
						2'b00: if (NSxREG[{1'b0,LS_POS[2]}].LSCX) LS_OFFS[LS_POS[2]] <= LS_OFFS[LS_POS[2]] + 18'd1;
						2'b01: if (NSxREG[{1'b0,LS_POS[2]}].LSCY) LS_OFFS[LS_POS[2]] <= LS_OFFS[LS_POS[2]] + 18'd1;
						2'b10: if (NSxREG[{1'b0,LS_POS[2]}].LZMX) LS_OFFS[LS_POS[2]] <= LS_OFFS[LS_POS[2]] + 18'd1;
					endcase
				end
			end else if (RPA_FETCH) begin
				RPA_POS <= RPA_POS + 5'd1;
				if (RPA_POS == 5'd23) RPA_POS <= '0;
				RxRPA_VRAM_BANK <= RxRPA_ADDR[18:17];
			end else if (BACK_FETCH) begin
				BS_OFFS <= REGS.BKTAU.BKCLMD ? BS_OFFS + 19'd1 : 19'd0;
				BS_VRAM_BANK <= BS_ADDR[18:17];
			end else if (BACK_FETCH) begin
				LN_OFFS <= REGS.LCTAU.LCCLMD ? LN_OFFS + 19'd1 : 19'd0;
				BS_VRAM_BANK <= LN_ADDR[18:17];
			end
			
			if (!REGS.TVMD.DISP || VBLANK || (!REGS.BGON.N0ON && !REGS.BGON.N1ON && !REGS.BGON.N2ON && !REGS.BGON.N3ON && !REGS.BGON.R0ON)) begin
				if (VRAM_RW_PEND2) begin
					VRAMA0_Q <= !VRAMA0_A[1] ? RA0_Q[15:0] : RA0_Q[31:16];
					VRAMA1_Q <= !VRAMA1_A[1] ? RA1_Q[15:0] : RA1_Q[31:16];
					VRAMB0_Q <= !VRAMB0_A[1] ? RB0_Q[15:0] : RB0_Q[31:16];
					VRAMB1_Q <= !VRAMB1_A[1] ? RB1_Q[15:0] : RB1_Q[31:16];
					VRAM_RW_PEND2 <= 0;
				end
			end else begin
				if (NBG_A0VA.CPUD && VRAM_RW_PEND2) begin
					VRAMA0_Q <= !VRAMA0_A[1] ? RA0_Q[15:0] : RA0_Q[31:16];
					VRAMA1_Q <= !VRAMA1_A[1] ? RA1_Q[15:0] : RA1_Q[31:16];
					VRAM_RW_PEND2 <= 0;
				end
				if (NBG_B0VA.CPUD && VRAM_RW_PEND2) begin
					VRAMB0_Q <= !VRAMB0_A[1] ? RB0_Q[15:0] : RB0_Q[31:16];
					VRAMB1_Q <= !VRAMB1_A[1] ? RB1_Q[15:0] : RB1_Q[31:16];
					VRAM_RW_PEND2 <= 0;
				end
			end
			
			if (LAST_DOT && DOT_CE) begin
				NBG_CH_CNT <= '{4{'0}};
				RBG_CH_CNT <= '{2{'0}};
				if (LAST_LINE) begin
					LS_POS <= '0;
					LS_OFFS <= '{2{'0}};
					BS_OFFS <= '0;
				end
			end
		end
	end
	
	assign N0SCX = SCX[0];
	assign N0SCY = SCY[0];

	always @(posedge CLK or negedge RST_N) begin
		bit [31:0] PN_WD[4];
		bit [31:0] RPN_WD[2];
		bit        PN_A1[4];
		bit  [2:0] CNT[4];
		bit  [2:0] RCNT[2];
		bit        HF[4];
		bit        RHF[2];
		bit  [6:0] PALN[4];
		bit  [6:0] RPALN[2];
		bit [31:0] CH[4];
		bit [31:0] RCH[2];
		bit        TPON[4];
		bit        RTPON[2];
		bit [31:0] LS_WD[2];
		BGState_t  BGS0;
		
		
		if (!RST_N) begin
			NBG_CDL[0] <= '{8{'0}};
			NBG_CDL[1] <= '{8{'0}};
			NBG_CDL[2] <= '{8{'0}};
			NBG_CDL[3] <= '{8{'0}};
			VS[0] <= '0; VS[1] <= '0;
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
			
			for (int i=0; i<2; i++) begin
				BGS0.RxPN[i] = VA_PIPE[0].RxA0PN[i] | VA_PIPE[0].RxA1PN[i] | VA_PIPE[0].RxB0PN[i] | VA_PIPE[0].RxB1PN[i];
				BGS0.RxPNS[i] = VA_PIPE[0].RxA0PN[i] ? 2'd0 : 
									 VA_PIPE[0].RxA1PN[i] ? 2'd1 : 
									 VA_PIPE[0].RxB0PN[i] ? 2'd2 : 
									 2'd3;
				BGS0.RxCH[i] = BG_PIPE[3].RxPN[i];//VA_PIPE[0].RxA0CH[i] | VA_PIPE[0].RxA1CH[i] | VA_PIPE[0].RxB0CH[i] | VA_PIPE[0].RxB1CH[i];
				BGS0.RxCHS[i] = VA_PIPE[0].RxA0CH[i] ? 2'd0 : 
									 VA_PIPE[0].RxA1CH[i] ? 2'd1 : 
									 VA_PIPE[0].RxB0CH[i] ? 2'd2 : 
									 2'd3;
			end
			BGS0.RxCH_CNT = RBG_CH_CNT;
			
			for (int i=0; i<4; i++) begin
				if (BG_PIPE[1].NxPN[i]) begin
					case (BG_PIPE[1].NxPNS[i])
						2'd0: PN_WD[i] = RA0_Q;
						2'd1: PN_WD[i] = RA1_Q;
						2'd2: PN_WD[i] = RB0_Q;
						2'd3: PN_WD[i] = RB1_Q;
					endcase
					if (!NSxREG[i].PNC.NxPNB) begin
						PN_PIPE[0][i] <= PN_WD[i];
					end else begin
						PN_PIPE[0][i] <= PNOneWord(NSxREG[i].PNC, NSxREG[i].CHSZ, NSxREG[i].CHCN, PN_WD[i][31:16]);
					end
				end
				
				if (BG_PIPE[1].NxPN[i]) begin
//					PN[i] <= PNT[i];
//					NxOFFX3[i] <= NxOFFX[i].INT[3];
				end
				
				if (BG_PIPE[1].NxCH[i]) begin
					case (BG_PIPE[1].NxCHS[i])
						2'd0: CH_PIPE[0][i] <= RA0_Q;
						2'd1: CH_PIPE[0][i] <= RA1_Q;
						2'd2: CH_PIPE[0][i] <= RB0_Q;
						2'd3: CH_PIPE[0][i] <= RB1_Q;
					endcase
				end
				
				if (BG_PIPE[3].NxCH[i]) begin
					CNT[i] = BG_PIPE[3].NxCH_CNT[i];
					PALN[i] = !NSxREG[i].BMEN ? PN_PIPE[2][i].PALN : {NSxREG[i].BMP,4'b0000};
					HF[i] = PN_PIPE[2][i].HF & ~NSxREG[i].BMEN;
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
			end
			
			for (int i=0; i<2; i++) begin
				if (BGS0.NxVS[i]) begin
					VS[i].INT  <= PN_WD[i][26:16] & {11{NSxREG[i].VCSC}};
					VS[i].FRAC <= PN_WD[i][15: 8] & { 8{NSxREG[i].VCSC}};
				end
				
//				if (NxLSC) begin
//					case (NxLS_VRAM_BANK/*[i]*/)
//						2'b00: LS_WD[i] = RA0_Q;
//						2'b01: LS_WD[i] = RA1_Q;
//						2'b10: LS_WD[i] = RB0_Q;
//						2'b11: LS_WD[i] = RB1_Q;
//					endcase
//					case ()
//					LSX[i].INT  <= LS_WD[i][26:16] & {11{NSxREG[i].LSCX}};
//					LSX[i].FRAC <= LS_WD[i][15: 8] & { 8{NSxREG[i].LSCX}};
//				end
				
				if (BG_PIPE[1].RxPN[i]) begin
					case (BG_PIPE[1].RxPNS[i])
						2'd0: RPN_WD[i] = RA0_Q;
						2'd1: RPN_WD[i] = RA1_Q;
						2'd2: RPN_WD[i] = RB0_Q;
						2'd3: RPN_WD[i] = RB1_Q;
					endcase
					if (!RSxREG[i].PNC.NxPNB) begin
						RBG_PN_PIPE[0][i] <= RPN_WD[i];
					end else begin
						RBG_PN_PIPE[0][i] <= PNOneWord(RSxREG[i].PNC, RSxREG[i].CHSZ, RSxREG[i].CHCN, RPN_WD[i][31:16]);
					end
				end
				
				if (BG_PIPE[1].RxCH[i]) begin
					case (BG_PIPE[1].RxCHS[i])
						2'd0: RBG_CH_PIPE[0][i] <= RA0_Q;
						2'd1: RBG_CH_PIPE[0][i] <= RA1_Q;
						2'd2: RBG_CH_PIPE[0][i] <= RB0_Q;
						2'd3: RBG_CH_PIPE[0][i] <= RB1_Q;
					endcase
				end
				
				if (BG_PIPE[3].RxCH[i]) begin
					RCNT[i] = BG_PIPE[3].RxCH_CNT[i];
					RPALN[i] = !RSxREG[i].BMEN ? RBG_PN_PIPE[2][i].PALN : {RSxREG[i].BMP,4'b0000};
					RHF[i] = RBG_PN_PIPE[2][i].HF & ~RSxREG[i].BMEN;
					RCH[i] = RBG_CH_PIPE[1][i];
					RTPON[i] = RSxREG[i].TPON;
					case (RSxREG[i].CHCN)
						3'b000: begin				//4bits/dot, 16 colors
							case (RCNT[i])
							3'b000:RBG_CDL[i][0 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][31:28]|RTPON[i],{13'h0000,RPALN[i],RCH[i][31:28]}};
							3'b001:RBG_CDL[i][1 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][27:24]|RTPON[i],{13'h0000,RPALN[i],RCH[i][27:24]}};
							3'b010:RBG_CDL[i][2 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][23:20]|RTPON[i],{13'h0000,RPALN[i],RCH[i][23:20]}};
							3'b011:RBG_CDL[i][3 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][19:16]|RTPON[i],{13'h0000,RPALN[i],RCH[i][19:16]}};
							3'b100:RBG_CDL[i][4 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][15:12]|RTPON[i],{13'h0000,RPALN[i],RCH[i][15:12]}};
							3'b101:RBG_CDL[i][5 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][11: 8]|RTPON[i],{13'h0000,RPALN[i],RCH[i][11: 8]}};
							3'b110:RBG_CDL[i][6 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][ 7: 4]|RTPON[i],{13'h0000,RPALN[i],RCH[i][ 7: 4]}};
							3'b111:RBG_CDL[i][7 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][ 3: 0]|RTPON[i],{13'h0000,RPALN[i],RCH[i][ 3: 0]}};
							endcase
						end
						3'b001: begin				//8bits/dot, 256 colors
							case (RCNT[i])
							3'b000:RBG_CDL[i][0 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][31:24]|RTPON[i],{13'h0000,RPALN[i][6:4],RCH[i][31:24]}};
							3'b001:RBG_CDL[i][1 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][23:16]|RTPON[i],{13'h0000,RPALN[i][6:4],RCH[i][23:16]}};
							3'b010:RBG_CDL[i][2 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][15: 8]|RTPON[i],{13'h0000,RPALN[i][6:4],RCH[i][15: 8]}};
							3'b011:RBG_CDL[i][3 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][ 7: 0]|RTPON[i],{13'h0000,RPALN[i][6:4],RCH[i][ 7: 0]}};
							3'b100:RBG_CDL[i][4 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][31:24]|RTPON[i],{13'h0000,RPALN[i][6:4],RCH[i][31:24]}};
							3'b101:RBG_CDL[i][5 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][23:16]|RTPON[i],{13'h0000,RPALN[i][6:4],RCH[i][23:16]}};
							3'b110:RBG_CDL[i][6 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][15: 8]|RTPON[i],{13'h0000,RPALN[i][6:4],RCH[i][15: 8]}};
							3'b111:RBG_CDL[i][7 ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][ 7: 0]|RTPON[i],{13'h0000,RPALN[i][6:4],RCH[i][ 7: 0]}};
							endcase
						end
						3'b010: begin				//16bits/dot, 2048 colors
							case (RCNT[i][0])
							1'b0:RBG_CDL[i][{RCNT[i][1:0],1'b0} ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][26:16]|RTPON[i],{13'h0000,RCH[i][26:16]}};
							1'b1:RBG_CDL[i][{RCNT[i][1:0],1'b1} ^ {3{RHF[i]}}] <= {1'b1,|RCH[i][10: 0]|RTPON[i],{13'h0000,RCH[i][10: 0]}};
							endcase
						end
						3'b011: begin				//16bits/dot, 32768 colors
							case (RCNT[i][0])
							1'b0:RBG_CDL[i][{RCNT[i][1:0],1'b0} ^ {3{RHF[i]}}] <= {1'b0,RCH[i][31]|RTPON[i],Color555To888(RCH[i][31:16])};
							1'b1:RBG_CDL[i][{RCNT[i][1:0],1'b1} ^ {3{RHF[i]}}] <= {1'b0,RCH[i][15]|RTPON[i],Color555To888(RCH[i][15: 0])};
							endcase
						end
						3'b100: begin				//32bits/dot, 16M colors
							RBG_CDL[i][RCNT[i] ^ {3{RHF[i]}}] <= {1'b0,RCH[i][31]|RTPON[i],RCH[i][23:0]};
						end
						default:;
					endcase
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
			
			RBG_PN_PIPE[1] <= RBG_PN_PIPE[0];
			RBG_PN_PIPE[2] <= RBG_PN_PIPE[1];
			RBG_PN_PIPE[3] <= RBG_PN_PIPE[2];
			RBG_CH_PIPE[1] <= RBG_CH_PIPE[0];
			RBG_CH_PIPE[2] <= RBG_CH_PIPE[1];
			RBG_CH_PIPE[3] <= RBG_CH_PIPE[2];
		end
	end
	assign CH_PIPE0 = RBG_CH_PIPE[0];
	assign CH_PIPE1 = RBG_CH_PIPE[1];
	assign CH_PIPE2 = RBG_CH_PIPE[2];
	
	bit VRAM_RDY;
	always @(posedge CLK or negedge RST_N) begin
		bit VRAM_SEL_OLD;
		bit VRAM_PEND_OLD;
		
		if (!RST_N) begin
			VRAM_RDY <= 1;
		end
		else begin
			VRAM_SEL_OLD <= VRAM_SEL;
			VRAM_PEND_OLD <= VRAMA_RW_PEND | VRAMB_RW_PEND;
			if (VRAM_SEL && !VRAM_SEL_OLD && VRAM_RDY) 
				VRAM_RDY <= 0;
			else if (!VRAMA_RW_PEND && !VRAMB_RW_PEND && VRAM_PEND_OLD && !VRAM_RDY) 
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

	wire [15:0] VRAM_DO = VRAMA0_SEL ? VRAMA0_Q :
	                      VRAMA1_SEL ? VRAMA1_Q :
							    VRAMB0_SEL ? VRAMB0_Q :
								 VRAMB1_Q;

	DotsBuffer_t R0DB, N0DB, N1DB, N2DB, N3DB;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			R0DB <= '{16{'0}};
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
						R0DB[i] <= R0DB[i+8]; R0DB[i+8] <= RBG_CDL[0][i];
						N0DB[i] <= N0DB[i+8]; N0DB[i+8] <= NBG_CDL[0][i];
						N1DB[i] <= N1DB[i+8]; N1DB[i+8] <= NBG_CDL[1][i];
						N2DB[i] <= N2DB[i+8]; N2DB[i+8] <= NBG_CDL[2][i];
						N3DB[i] <= N3DB[i+8]; N3DB[i+8] <= NBG_CDL[3][i];
					end end
			endcase
		end
	end
	
	wire [3:0] R0DOTN = {1'b1,SCRX[2:0]};
	wire [3:0] N0DOTN = {1'b0,SCRX[2:0]} + {1'b0,SCX[0].INT[2:0]};
	wire [3:0] N1DOTN = {1'b0,SCRX[2:0]} + {1'b0,SCX[1].INT[2:0]};
	wire [3:0] N2DOTN = {1'b0,SCRX[2:0]} + {1'b0,SCX[2].INT[2:0]};
	wire [3:0] N3DOTN = {1'b0,SCRX[2:0]} + {1'b0,SCX[3].INT[2:0]};
	ScreenDot_t DOT_FST[2], DOT_SEC[2], DOT_THD[2], DOT_FTH[2];
	DotData_t R0DOT, N0DOT, N1DOT, N2DOT, N3DOT;
	always @(posedge CLK or negedge RST_N) begin
		ScreenDot_t FST, SEC, THD, FTH;
		bit  [2:0]  FST_PRI, SEC_PRI, THD_PRI, FTH_PRI;
		
		if (!RST_N) begin
			DOT_FST <= '{2{SD_NULL}};
			DOT_SEC <= '{2{SD_NULL}};
			DOT_THD <= '{2{SD_NULL}};
			DOT_FTH <= '{2{SD_NULL}};
		end
		else if (DOT_CE) begin
			R0DOT = R0DB[R0DOTN];
			N0DOT = N0DB[N0DOTN];
			N1DOT = N1DB[N1DOTN];
			N2DOT = N2DB[N2DOTN];
			N3DOT = N3DB[N3DOTN];
			
			FST = {1'b0,1'b1,BACK_COL,3'b101}; FST_PRI = 3'd0;
			SEC = {1'b0,1'b1,BACK_COL,3'b101}; SEC_PRI = 3'd0;
			THD = {1'b0,1'b1,BACK_COL,3'b101}; THD_PRI = 3'd0;
			FTH = {1'b0,1'b1,BACK_COL,3'b101}; FTH_PRI = 3'd0;
			if (REGS.TVMD.DISP) begin
				if (R0DOT.TP && RSxREG[0].PRIN && RSxREG[0].ON && SCRN_EN[4]) begin
					FST = {R0DOT,3'd4}; FST_PRI = RSxREG[0].PRIN;
				end
				
				if (N0DOT.TP && NSxREG[0].PRIN && NSxREG[0].PRIN > FST_PRI && NSxREG[0].ON && SCRN_EN[0]) begin
					FST = {N0DOT,3'd0}; FST_PRI = NSxREG[0].PRIN;
				end else if (N0DOT.TP && NSxREG[0].PRIN && NSxREG[0].PRIN > SEC_PRI && NSxREG[0].ON && SCRN_EN[0]) begin
					SEC = {N0DOT,3'd0}; SEC_PRI = NSxREG[0].PRIN;
				end
				
				if (N1DOT.TP && NSxREG[1].PRIN && NSxREG[1].PRIN > FST_PRI && NSxREG[1].ON && SCRN_EN[1]) begin
					FST = {N1DOT,3'd1}; FST_PRI = NSxREG[1].PRIN;
				end else if (N1DOT.TP && NSxREG[1].PRIN && NSxREG[1].PRIN > SEC_PRI && NSxREG[1].ON && SCRN_EN[1]) begin
					SEC = {N1DOT,3'd1}; SEC_PRI = NSxREG[1].PRIN;
				end else if (N1DOT.TP && NSxREG[1].PRIN && NSxREG[1].PRIN > THD_PRI && NSxREG[1].ON && SCRN_EN[1]) begin
					THD = {N1DOT,3'd1}; THD_PRI = NSxREG[1].PRIN;
				end
				
				if (N2DOT.TP && NSxREG[2].PRIN && NSxREG[2].PRIN > FST_PRI && NSxREG[2].ON && SCRN_EN[2]) begin
					FST = {N2DOT,3'd2}; FST_PRI = NSxREG[2].PRIN;
				end else if (N2DOT.TP && NSxREG[2].PRIN && NSxREG[2].PRIN > SEC_PRI && NSxREG[2].ON && SCRN_EN[2]) begin
					SEC = {N2DOT,3'd2}; SEC_PRI = NSxREG[2].PRIN;
				end else if (N2DOT.TP && NSxREG[2].PRIN && NSxREG[2].PRIN > THD_PRI && NSxREG[2].ON && SCRN_EN[2]) begin
					THD = {N2DOT,3'd2}; THD_PRI = NSxREG[2].PRIN;
				end else if (N2DOT.TP && NSxREG[2].PRIN && NSxREG[2].PRIN > FTH_PRI && NSxREG[2].ON && SCRN_EN[2]) begin
					FTH = {N2DOT,3'd2}; FTH_PRI = NSxREG[2].PRIN;
				end
				
				if (N3DOT.TP && NSxREG[3].PRIN && NSxREG[3].PRIN > FST_PRI && NSxREG[3].ON && SCRN_EN[3]) begin
					FST = {N3DOT,3'd3}; FST_PRI = NSxREG[3].PRIN;
				end else if (N3DOT.TP && NSxREG[3].PRIN && NSxREG[3].PRIN > SEC_PRI && NSxREG[3].ON && SCRN_EN[3]) begin
					SEC = {N3DOT,3'd3}; SEC_PRI = NSxREG[3].PRIN;
				end else if (N3DOT.TP && NSxREG[3].PRIN && NSxREG[3].PRIN > THD_PRI && NSxREG[3].ON && SCRN_EN[3]) begin
					THD = {N3DOT,3'd3}; THD_PRI = NSxREG[3].PRIN;
				end else if (N3DOT.TP && NSxREG[3].PRIN && NSxREG[3].PRIN > FTH_PRI && NSxREG[3].ON && SCRN_EN[3]) begin
					FTH = {N3DOT,3'd3}; FTH_PRI = NSxREG[3].PRIN;
				end
			end
			
			DOT_FST[0] <= FST;
			DOT_SEC[0] <= SEC;
			DOT_THD[0] <= THD;
			DOT_FTH[0] <= FTH;
			DOT_FST[1] <= DOT_FST[0];
			DOT_SEC[1] <= DOT_SEC[0];
			DOT_THD[1] <= DOT_THD[0];
			DOT_FTH[1] <= DOT_THD[0];
		end
	end
	
	assign R0DOT_DBG = R0DOT;
	assign N0DOT_DBG = N0DOT;
	assign N1DOT_DBG = N1DOT;
	assign N2DOT_DBG = N2DOT;
	assign N3DOT_DBG = N3DOT;
	assign DOT_FST_DBG = DOT_FST[0];
	assign DOT_SEC_DBG = DOT_SEC[0];
	assign DOT_THD_DBG = DOT_THD[0];
	
	
	bit [10:0] PAL_N;
	bit        COEN;
	bit        COSL;
	bit  [4:0] CCRT;
	bit        CCEN;
	always_comb begin
		case (DOTCLK_DIV[2:1])
			2'b00: PAL_N = {!DOT_FST[0].S[2] ? NSxREG[DOT_FST[0].S].CAOS : REGS.CRAOFB.R0CAOS,8'b00000000} + DOT_FST[0].D[10:0];
			2'b01: PAL_N = {!DOT_SEC[0].S[2] ? NSxREG[DOT_SEC[0].S].CAOS : REGS.CRAOFB.R0CAOS,8'b00000000} + DOT_SEC[0].D[10:0];
			2'b10: PAL_N = {!DOT_THD[0].S[2] ? NSxREG[DOT_THD[0].S].CAOS : REGS.CRAOFB.R0CAOS,8'b00000000} + DOT_THD[0].D[10:0];
			2'b11: PAL_N = {!DOT_FTH[0].S[2] ? NSxREG[DOT_FTH[0].S].CAOS : REGS.CRAOFB.R0CAOS,8'b00000000} + DOT_FTH[0].D[10:0];
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
		bit [23:0] PAL;
		Color_t PAL_COL_FST_TEMP, PAL_COL_SEC_TEMP, PAL_COL_THD_TEMP;
		
		if (!RST_N) begin
			PAL_COL_FST <= '0;
			PAL_COL_SEC <= '0;
			PAL_COL_THD <= '0;
			PAL_COL_FTH <= '0;
		end
		else begin
			case (REGS.RAMCTL.CRMD)
				2'b00: PAL = Color555To888(PAL0_Q);
				2'b01: PAL = Color555To888(!PAL_A[1] ? PAL0_Q : PAL1_Q);
				default: PAL = {PAL0_Q[7:0],PAL1_Q};
			endcase
			case (DOTCLK_DIV[2:0])
				3'd1: PAL_COL_FST_TEMP <= PAL;
				3'd3: PAL_COL_SEC_TEMP <= PAL;
				3'd5: PAL_COL_THD_TEMP <= PAL;
				3'd7: PAL_COL_FTH <= PAL;
			endcase
			if (DOT_CE) begin
				PAL_COL_FST <= PAL_COL_FST_TEMP;
				PAL_COL_SEC <= PAL_COL_SEC_TEMP;
				PAL_COL_THD <= PAL_COL_THD_TEMP;
			end
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
	
	
	
	wire        PAL_SEL = !CS_N && !DTEN_N && !AD_N && A[20:19] == 2'b10;	//100000-17FFFF
	wire [10:1] IO_PAL_A = REGS.RAMCTL.CRMD == 2'b00 ? A[10:1] : A[11:2];
	wire        IO_PAL_WE = PAL_SEL & ~&WE_N & CE_R;
	wire [10:1] PAL_A = REGS.RAMCTL.CRMD == 2'b01 ? PAL_N[10:1] : PAL_N[9:0];
	VDP2_DPRAM #(10,16," "," ") pal1
	(
		.CLK(CLK),
		
		.ADDR_A(PAL_A),
		.DATA_A(16'h0000),
		.WREN_A(1'b0),
		.Q_A(PAL0_Q),
		
		.ADDR_B(IO_PAL_A),
		.DATA_B(DI),
		.WREN_B(IO_PAL_WE & (~A[1] | ~|REGS.RAMCTL.CRMD)),
		.Q_B(PAL0_DO)
	);
	
	VDP2_DPRAM #(10,16," "," ") pal2
	(
		.CLK(CLK),
		
		.ADDR_A(PAL_A),
		.DATA_A(16'h0000),
		.WREN_A(1'b0),
		.Q_A(PAL1_Q),
		
		.ADDR_B(A[11:2]),
		.DATA_B(DI),
		.WREN_B(IO_PAL_WE & (A[1] | ~|REGS.RAMCTL.CRMD)),
		.Q_B(PAL1_DO)
	);
	
	//Registers
	wire REG_SEL = (A[20:18] == 3'b110) & ~DTEN_N & ~AD_N & ~CS_N;
	
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
			
//			REGS.CYCA0L <= 16'h7744;
//			REGS.CYCA0U <= 16'hFFFF;
//			REGS.CYCA1L <= 16'hFF30;
//			REGS.CYCA1U <= 16'hFFFF;
//			REGS.CYCB0L <= 16'h6655;
//			REGS.CYCB0U <= 16'hFFFF;
//			REGS.CYCB1L <= 16'h21FF;
//			REGS.CYCB1U <= 16'hFFFF;
//			REGS.CHCTLA <= 16'h1010;
//			REGS.CHCTLB <= 16'h0022;
//			REGS.MPOFN <= 16'h0000;
//			REGS.MPABN0 <= 16'h0808;
//			REGS.MPCDN0 <= 16'h0808;
//			REGS.MPABN1 <= 16'h1818;
//			REGS.MPCDN1 <= 16'h1818;
//			REGS.MPABN2 <= 16'h1C1C;
//			REGS.MPCDN2 <= 16'h1C1C;
//			REGS.MPABN3 <= 16'h0C0C;
//			REGS.MPCDN3 <= 16'h0C0C;
//			REGS.PNCN0 <= 16'h0000;
//			REGS.PNCN1 <= 16'h0000;
//			REGS.PNCN2 <= 16'h0000;
//			REGS.PNCN3 <= 16'h0000;
//			REGS.PRINA <= 16'h0706;
//			REGS.PRINB <= 16'h0607;
//			REGS.PLSZ <= 16'h0000;
//			{REGS.LSTA0U,REGS.LSTA0L} <= 32'h00000000;
//			REGS.SCRCTL <= 16'h0000;
//			REGS.CRAOFA <= 16'h3210;
//			{REGS.BKTAU,REGS.BKTAL} <= 32'h00000000;
//			REGS.CCCTL <= 16'h0002;
//			REGS.CCRNA <= 16'h0D00;
//			REGS.CCRNB <= 16'h0000;
//			REGS.BGON <= 16'h0803;
//			REGS.TVMD <= 16'h8000;
			
//			REGS.RAMCTL <= 16'h20B0;
//			REGS.CYCA0L <= 16'h44FF;
//			REGS.CYCA0U <= 16'hFFFF;
//			REGS.CYCA1L <= 16'hFFFF;
//			REGS.CYCA1U <= 16'hFFFF;
//			REGS.CYCB0L <= 16'hFFFF;
//			REGS.CYCB0U <= 16'hFFFF;
//			REGS.CYCB1L <= 16'hFFFF;
//			REGS.CYCB1U <= 16'hFFFF;
//			REGS.CHCTLA <= 16'h0012;
//			REGS.CHCTLB <= 16'h1000;
//			REGS.MPOFN <= 16'h0000;
//			REGS.MPABN0 <= 16'h0000;
//			REGS.MPCDN0 <= 16'h0000;
//			REGS.MPABN1 <= 16'h0000;
//			REGS.MPCDN1 <= 16'h0000;
//			REGS.MPABN2 <= 16'h0000;
//			REGS.MPCDN2 <= 16'h0000;
//			REGS.MPABN3 <= 16'h0000;
//			REGS.MPCDN3 <= 16'h0000;
//			REGS.MPABRA <= 16'h1818;
//			REGS.MPCDRA <= 16'h1818;
//			REGS.MPEFRA <= 16'h1818;
//			REGS.MPGHRA <= 16'h1818;
//			REGS.MPIJRA <= 16'h1818;
//			REGS.MPKLRA <= 16'h1818;
//			REGS.MPMNRA <= 16'h1818;
//			REGS.MPOPRA <= 16'h1818;
//			REGS.MPABRB <= 16'h1818;
//			REGS.MPCDRB <= 16'h1818;
//			REGS.MPEFRB <= 16'h1818;
//			REGS.MPGHRB <= 16'h1818;
//			REGS.MPIJRB <= 16'h1818;
//			REGS.MPKLRB <= 16'h1818;
//			REGS.MPMNRB <= 16'h1818;
//			REGS.MPOPRB <= 16'h1818;
//			REGS.PNCN0 <= 16'h0000;
//			REGS.PNCN1 <= 16'h0000;
//			REGS.PNCN2 <= 16'h0000;
//			REGS.PNCN3 <= 16'h0000;
//			REGS.PRINA <= 16'h0202;
//			REGS.PRINB <= 16'h0002;
//			REGS.PRIR <= 16'h0001;
//			REGS.PLSZ <= 16'h0000;
//			{REGS.RPTAU,REGS.RPTAL} <= 32'h00038000;
//			{REGS.LSTA0U,REGS.LSTA0L} <= 32'h00000000;
//			REGS.SCRCTL <= 16'h0000;
//			REGS.CRAOFA <= 16'h0000;
//			REGS.CRAOFB <= 16'h0001;
//			{REGS.BKTAU,REGS.BKTAL} <= 32'h00000000;
//			REGS.CCCTL <= 16'h0000;
//			REGS.CCRNA <= 16'h0000;
//			REGS.CCRNB <= 16'h0000;
//			REGS.CLOFEN <= 16'h0010;
//			REGS.BGON <= 16'h1011;
//			REGS.TVMD <= 16'h8000;

			REG_DO <= '0;
			A <= '0;
		end else if (!RES_N) begin
				
		end else begin
			if (!CS_N && DTEN_N && AD_N && CE_R) begin
				A <= {A[4:0],DI};
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
	            PAL_SEL ? !A[1] ? PAL0_DO : PAL1_DO : 
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
