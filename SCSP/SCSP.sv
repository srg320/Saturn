// synopsys translate_off
`define SIM
// synopsys translate_on

module SCSP (
	input             CLK,
	input             RST_N,
	input             CE,
	
	input             RES_N,
	
	input             CE_R,
	input             CE_F,
	input      [15:0] DI,
	output     [15:0] DO,
	input             CS_N,
	input             AD_N,
	input             DTEN_N,
	input             REQ_N,
	output            RDY_N,
	output            INT_N,
	
	output            SCCE_R,
	output            SCCE_F,
	input      [23:1] SCA,
	input      [15:0] SCDI,
	output     [15:0] SCDO,
	input             SCRW_N,
	input             SCAS_N,
	input             SCLDS_N,
	input             SCUDS_N,
	output reg        SCDTACK_N,
	input       [2:0] SCFC,
	output            SCAVEC_N,
	output      [2:0] SCIPL_N,

	output     [18:1] RAM_A,
	output     [15:0] RAM_D,
	input      [15:0] RAM_Q,
	output      [1:0] RAM_WE,
	output            RAM_RD,
	output            RAM_CS,
	output            RAM_RFS,
	input             RAM_RDY,
	
	input      [15:0] ESL,
	input      [15:0] ESR,
	
	output     [15:0] SOUND_L,
	output     [15:0] SOUND_R,
	
	input       [1:0] SND_EN
`ifdef DEBUG
                     ,
	output reg        DBG_68K_ERR,
	output reg        DBG_SCU_HOOK,
	output reg  [7:0] DBG_SCU_710,
	output            SLOT_EN_DBG,
	output     [23:0] SCA_DBG,
	output     [15:0] EVOL_DBG,
	output SCR0_t     SCR0_DBG_,
	output SCR0_t     SCR0_DBG,
	output SA_t       SA_DBG,
	output LSA_t      LSA_DBG,
	output LEA_t      LEA_DBG,
	output     [15:0] NEW_SA_INT_DBG,
	output SCR1_t     SCR1_DBG,
	output SCR2_t     SCR2_DBG,
	output SCR3_t     SCR3_DBG,
	output SCR4_t     SCR4_DBG,
	output SCR5_t     SCR5_DBG,
	output SCR6_t     SCR6_DBG,
	output SCR7_t     SCR7_DBG,
	output SCR8_t     SCR8_DBG,
	output     [19:0] ADP_DBG,
	output signed [15:0] LVL_DBG,
	output signed [15:0] PAN_L_DBG,
	output signed [15:0] PAN_R_DBG,
	output            DIR_ACC_L_OF,
	output            DIR_ACC_R_OF,
	output            EFF_ACC_L_OF,
	output            EFF_ACC_R_OF
`endif
);
	import SCSP_PKG::*;
	
	SCR_t      SCR[32];
	CR0_t      CR0;
	CR1_t      CR1;
	CR2_t      CR2;
	CR3_t      CR3;
	CR4_t      CR4;
	CR5_t      CR5;
	CR6_t      CR6;
	CR7_t      CR7;
	CR8_t      CR8;
	CR9_t      CR9;
	CR10_t     CR10;
	CR11_t     CR11;
	CR12_t     CR12;
	CR13_t     CR13;
	CR14_t     CR14;
	CR15_t     CR15;
	CR16_t     CR16;
	CR17_t     CR17;
	CR18_t     CR18;
	CR19_t     CR19;
	SCR0_t     SCR0_;
	SCR0_t     SCR0;
	SA_t       SA;
	LSA_t      LSA;
	LEA_t      LEA;
	SCR1_t     SCR1;
	SCR2_t     SCR2;
	SCR3_t     SCR3;
	SCR4_t     SCR4;
	SCR5_t     SCR5;
	SCR6_t     SCR6;
	SCR7_t     SCR7;
	SCR8_t     SCR8;
//	STACK_t    STACK0;
//	STACK_t    STACK1;
	MIXSS_t    DSP_MIXS;
//	EFREGS_t   EFREGS;
	
	MPRO_t     DSP_MPRO_Q;
	TEMP_t     DSP_TEMP_Q;
	MEMS_t     DSP_MEMS_Q;
	COEF_t     DSP_COEF_Q;
	MADRS_t    DSP_MADRS_Q;
	bit [15:0] DSP_EXTS[2];
	EFREG_t    DSP_EFREG_Q;
	
	bit  [3:0] CR4_CA;
	
	bit [19:0] ADP;
	bit        WD_READ;
	bit [15:0] MEM_WD;

	
	typedef enum bit [5:0] {
		MS_IDLE     = 6'b000001,  
		MS_WD_WAIT  = 6'b000010, 
		MS_DMA_WAIT = 6'b000100, 
		MS_SCU_WAIT = 6'b001000, 
		MS_SCPU_WAIT= 6'b010000,
		MS_END      = 6'b100000
	} MemState_t;
	MemState_t MEM_ST;
	MemState_t REG_ST;
	
	bit [18:1] MEM_A;
	bit [15:0] MEM_D;
	bit [15:0] MEM_Q;
	bit  [1:0] MEM_WE;
	bit        MEM_RD;
	bit        MEM_CS;
	bit        MEM_RFS;
	
	bit [11:1] REG_A;
	bit [15:0] REG_D;
	bit [15:0] REG_Q;
	bit  [1:0] REG_WE;
	bit        REG_RD;
	bit        REG_CS;
	bit        REG_RDY;
	
	bit [19:1] DMA_MA;
	bit [11:1] DMA_RA;
	bit [10:0] DMA_LEN;
	bit [15:0] DMA_DAT;
	bit        DMA_WR;
	bit        DMA_EXEC;
	
	bit  [1:0] CLK_CNT;
	always @(posedge CLK) if (CE) CLK_CNT <= CLK_CNT + 2'd1;
	assign SCCE_R =  CLK_CNT[0] & CE;
	assign SCCE_F = ~CLK_CNT[0] & CE;
	
	wire CYCLE_CE_F = CLK_CNT == 2'b01 & CE;
	wire CYCLE_CE = CLK_CNT == 2'b11 & CE;
	
	bit  [1:0] CYCLE_NUM;
	always @(posedge CLK) if (CYCLE_CE) CYCLE_NUM <= CYCLE_NUM + 2'd1;
	wire DSP1_EN = CYCLE_NUM == 2'b00;
	wire SLOT_EN = CYCLE_NUM == 2'b01;
	wire DSP2_EN = CYCLE_NUM == 2'b10;
	wire OUT_EN = CYCLE_NUM == 2'b11;
	
	wire DSP_CE = (DSP1_EN | DSP2_EN) & CYCLE_CE;
	wire SLOT_CE = SLOT_EN & CYCLE_CE;
	wire OUT_CE = OUT_EN & CYCLE_CE;
	
	bit        SAMPLE_CE;
	
	OPPipe_t    OP2_PIPE;
	OPPipe_t    OP3_PIPE;
	OPPipe_t    OP4_PIPE;
	OPPipe_t    OP5_PIPE;
	OPPipe_t    OP6_PIPE;
	OPPipe_t    OP7_PIPE;
	
	assign SCR0_ = SCR[OP2_PIPE.SLOT].SCR0;
	assign SCR0 = SCR_SCR0_Q;
	assign SA   = SCR_SA_Q;
	assign LSA  = SCR_LSA_Q;
	assign LEA  = SCR_LEA_Q;
	assign SCR1 = SCR_SCR1_Q;
	assign SCR2 = SCR_SCR2_Q;
	assign SCR3 = SCR_SCR3_Q;
	assign SCR4 = SCR_SCR4_Q;
	assign SCR5 = SCR_SCR5_Q;
	assign SCR6 = SCR_SCR6_Q;
	assign SCR7 = SCR_SCR7_Q;
	assign SCR8 = SCR_SCR8_Q;
	assign DSP_MPRO_Q = MPRO_RAM_Q;
	assign DSP_TEMP_Q = TEMP_RAM_Q[23:0];
	assign DSP_MEMS_Q = MEMS_RAM_Q[23:0];
	assign DSP_COEF_Q = COEF_RAM_Q;
	assign DSP_COEF_Q = COEF_RAM_Q;
	assign DSP_MADRS_Q = MADRS_RAM_Q;
	assign DSP_EFREG_Q = EFREG_RAM_Q;
	

	//Operation 1: PG, KEY ON/OFF
	wire KYONEX_SET = REG_CS & (REG_A[11:10] == 2'b00) & (REG_A[4:1] == 4'b0000) & REG_D[12] & REG_WE[1];
	bit        KEYON[32];
	bit  [4:0] SLOT;
	bit [25:0] PHASE;
	bit  [7:0] LFOP[32];//LFO position
	always @(posedge CLK or negedge RST_N) begin
		bit       KYONEX;
		bit       KEYON_OLD[32];
		
		if (!RST_N) begin
			KEYON <= '{32{0}};
			KEYON_OLD <= '{32{0}};
			KYONEX <= 0;
			SLOT <= '0;
			OP2_PIPE <= OP_PIPE_RESET;
		end
		else begin
			if (!KYONEX && KYONEX_SET) begin
				KYONEX <= 1;
			end else if (KYONEX && SLOT == 5'd31 && SLOT_CE) begin
				for (int i=0; i<32; i++) begin
					KEYON[i] <= SCR[i].SCR0.KB;
				end
				KYONEX <= 0;
			end
			
			if (SLOT_CE) begin
				PHASE <= PhaseCalc(SCR5);
				
//				OP2_PLFO <= LFOWave(LFOP[SLOT],8'h00,SCR6.PLFOWS) ^ 8'h80;
				
				KEYON_OLD[SLOT] <= KEYON[SLOT];
				OP2_PIPE.SLOT <= SLOT;
				OP2_PIPE.KON <= KEYON[SLOT] & ~KEYON_OLD[SLOT];
				OP2_PIPE.KOFF <= ~KEYON[SLOT] & KEYON_OLD[SLOT];
				SLOT <= SLOT + 5'd1;
			end
		end
	end
	
	//Operation 2: MD read, ADP
//	bit [ 7:0] OP2_PLFO;	//Pitch LFO data
	bit [25:0] NEW_SAO;	//New sample address offset
	bit        NEW_SADIR;	//New sample address direction
	always @(posedge CLK or negedge RST_N) begin
		bit [ 4:0] S;
		bit [15:0] LL;
		bit [15:0] MD;
		bit [25:0] SAO;
		bit        SADIR;
		bit [15:0] NEW_SA_INT;
		bit [ 9:0] NEW_SA_FRAC;
		
		if (!RST_N) begin
			WD_READ <= 0;
			OP3_SAOI <= '0;
			OP3_SAOF <= '0;
			OP3_SADIR <= 0;
			OP3_PIPE <= OP_PIPE_RESET;
		end
		else begin
			S = OP2_PIPE.SLOT;
			
			{SADIR,SAO} = SAO_RAM_Q;
			
			MD <= MDCalc2(STACK0X_Q, STACK0Y_Q, SCR4.MDL);
			{NEW_SA_INT,NEW_SA_FRAC} = !SADIR ? SAO + (PHASE + {MD,10'h000}) : SAO - (PHASE + {MD,10'h000});
			
			LL = LEA - LSA;
			if (SLOT_CE) begin
				NEW_SAO = {NEW_SA_INT,NEW_SA_FRAC};
				NEW_SADIR = SADIR;
				
				WD_READ <= 0;
				if (!EVOL_LOW[S]) begin
					case (SCR0_.LPCTL)
					2'b00:
						if (NEW_SA_INT < LEA) begin
							NEW_SAO = {NEW_SA_INT,NEW_SA_FRAC};
						end else begin
//							EVOL[S] <= 10'h3FF;
							NEW_SAO = SAO;
						end
					2'b01:
						if (NEW_SA_INT < LEA) begin
							NEW_SAO = {NEW_SA_INT,NEW_SA_FRAC};
						end else begin
							NEW_SAO = {NEW_SA_INT - LL,NEW_SA_FRAC};//{LSA,10'h000};
						end
					2'b10:
						if (!SADIR) begin
							if (NEW_SA_INT < LEA) begin
								NEW_SAO = {NEW_SA_INT,NEW_SA_FRAC};
							end else begin
								NEW_SAO = {LEA,10'h000};
								NEW_SADIR = 1;
							end
						end else begin
							if (NEW_SA_INT > LSA) begin
								NEW_SAO = {NEW_SA_INT,NEW_SA_FRAC};
							end else begin
								NEW_SAO = {LEA,10'h000};
								NEW_SADIR = 1;
							end
						end
					2'b11: NEW_SAO = {NEW_SA_INT,NEW_SA_FRAC};
					endcase
					
					WD_READ <= 1;
				end
				{OP3_SADIR,OP3_SAOI,OP3_SAOF} <= {NEW_SADIR,NEW_SAO};
				
				if (OP2_PIPE.KON) begin
					{OP3_SADIR,OP3_SAOI,OP3_SAOF} <= '0;
				end
				
				OP3_PIPE <= OP2_PIPE;
			end
`ifdef DEBUG
			NEW_SA_INT_DBG = NEW_SA_INT;
`endif
		end
	end
	bit [26:0] SAO_RAM_Q;
	SCSP_SAO_RAM SAO_RAM(CLK, OP3_PIPE.SLOT, {OP3_SADIR,OP3_SAOI,OP3_SAOF}, SLOT_CE, OP2_PIPE.SLOT, SAO_RAM_Q);
		
	//Operation 3:  
	bit [15:0] OP3_SAOI;	//Sample address offset integer
	bit [ 9:0] OP3_SAOF;	//Sample address offset fractional
	bit        OP3_SADIR;//Sample address direction
	assign ADP = {SCR0.SAH,SA} + (!SCR0.PCM8B ? {3'b000,OP3_SAOI,1'b0} : {4'b0000,OP3_SAOI});
	
	always @(posedge CLK or negedge RST_N) begin
//		bit [ 4:0] S;
		
		if (!RST_N) begin
			OP4_PIPE <= OP_PIPE_RESET;
			// synopsys translate_off
			OP4_WD <= 0;
			// synopsys translate_on
		end
		else begin
//			S = OP3_PIPE.SLOT;
			
			if (SLOT_CE) begin
				OP4_WD <= !SCR0.PCM8B ? MEM_WD : !ADP[0] ? {MEM_WD[15:8],8'h00} : {MEM_WD[7:0],8'h00};
				OP4_PIPE <= OP3_PIPE;
			end
		end
	end
	
	//Operation 4: EG
	EGState_t    EGST[32]; //Envelope state
	bit          EVOL_LOW[32]; //Envelope low level
	bit signed [15:0] OP4_WD; //Wave form data
	always @(posedge CLK or negedge RST_N) begin
		bit  [10: 0] VOL_NEXT;
		bit  [ 9: 0] NEW_EVOL;
		bit  [ 4: 0] S;
		
		if (!RST_N) begin
			OP5_PIPE <= OP_PIPE_RESET;
			// synopsys translate_off
			OP5_WD <= 0;
			// synopsys translate_on
			EGST <= '{32{EGS_RELEASE}};
			EVOL_LOW <= '{32{1}};
		end
		else begin
			S = OP4_PIPE.SLOT;
			if (SLOT_CE) begin
				NEW_EVOL = EVOL_RAM_Q;
				case (EGST[S])
					EGS_ATTACK: begin
						VOL_NEXT = {1'b0,EVOL_RAM_Q} - {1'b0,SCR2.AR,5'b11111} + 11'd1;
						if (!VOL_NEXT[10]) begin
							NEW_EVOL = VOL_NEXT[9:0];
						end else begin
							NEW_EVOL = 10'h000;
							EGST[S] <= EGS_DECAY1;
						end
						if (OP4_PIPE.KOFF) EGST[S] <= EGS_RELEASE;
					end
					
					EGS_DECAY1: begin
						VOL_NEXT = {1'b0,EVOL_RAM_Q} + {1'b0,SCR2.D1R,5'b00000};
						if (VOL_NEXT[9:5] < SCR1.DL) begin
							NEW_EVOL = VOL_NEXT[9:0];
						end else begin
							NEW_EVOL = VOL_NEXT[9:0];//{SCR[S].SCR1.DL,5'b00000};
							EGST[S] <= EGS_DECAY2;
						end
						if (OP4_PIPE.KOFF) EGST[S] <= EGS_RELEASE;
					end
					
					EGS_DECAY2: begin
						VOL_NEXT = {1'b0,EVOL_RAM_Q} + {1'b0,SCR2.D2R,5'b00000};
						if (!VOL_NEXT[10]) begin
							NEW_EVOL = VOL_NEXT[9:0];
						end else begin
							NEW_EVOL = 10'h3FF;
						end
						if (OP4_PIPE.KOFF) EGST[S] <= EGS_RELEASE;
					end
					
					EGS_RELEASE: begin
						VOL_NEXT = {1'b0,EVOL_RAM_Q} + {1'b0,SCR1.RR,5'b00000};
						if (!VOL_NEXT[10]) begin
							NEW_EVOL = VOL_NEXT[9:0];
						end else begin
							NEW_EVOL = 10'h3FF;
						end
						if (OP4_PIPE.KON) begin
							//NEW_EVOL = 10'h3FF;
							EGST[S] <= EGS_ATTACK;
						end
					end
				endcase
				OP5_EVOL <= NEW_EVOL;
				EVOL_LOW[S] <= &NEW_EVOL;
				
				OP5_WD <= OP4_WD;
				OP5_PIPE <= OP4_PIPE;
			end
		end
	end
	bit [9:0] EVOL_RAM_Q;
	SCSP_EVOL_RAM EVOL_RAM(CLK, OP5_PIPE.SLOT, OP5_EVOL, SLOT_CE, OP4_PIPE.SLOT, EVOL_RAM_Q);
	
	//Operation 5: Level calculation
	bit signed [15:0] OP5_WD; //Wave form data
	bit [ 9:0] OP5_EVOL;
	always @(posedge CLK or negedge RST_N) begin
//		bit [ 4:0] S;
		bit [ 7:0] TL;
		bit signed [15:0] TEMP;
		
		if (!RST_N) begin
			OP6_PIPE <= OP_PIPE_RESET;
			// synopsys translate_off
			OP6_SD <= '0;
			OP6_EVOL <= '0;
			OP6_SDIR <= 0;
			// synopsys translate_on
		end
		else begin
//			S = OP5_PIPE.SLOT;
			TL = SCR3.TL;
			if (SLOT_CE) begin
				TEMP = SCR3.SDIR ? OP5_WD : VolCalc(OP5_WD, TL);
				OP6_SD <= OP5_EVOL != 10'h3FF ? TEMP : '0;
				OP6_EVOL <= OP5_EVOL;
				OP6_SDIR <= SCR3.SDIR;
				OP6_PIPE <= OP5_PIPE;
			end
			
`ifdef DEBUG
			EVOL_DBG <= TEMP;
`endif
		end
	end
	
	//Operation 6: Level calculation
	bit signed [15:0] OP6_SD;	//Slot out data
	bit [ 9:0] OP6_EVOL;
	bit        OP6_SDIR;
	always @(posedge CLK or negedge RST_N) begin
//		bit [ 4:0] S;
//		bit [25:0] TEMP;
		
		if (!RST_N) begin
			OP7_PIPE <= OP_PIPE_RESET;
		end
		else begin
//			S = OP6_PIPE.SLOT;
			if (SLOT_CE) begin
//				TEMP = $signed(OP6_SD) * (10'h3FF - OP6_EVOL);
				OP7_SD <= OP6_SDIR ? OP6_SD : VolCalc(OP6_SD, OP6_EVOL[9:2]);//TEMP[25:10];
				OP7_PIPE <= OP6_PIPE;
			end
		end
	end
	
	//Operation 7: Stack save
	//Direct out
	bit signed [15:0] OP7_SD;
	bit [19:0] DIR_ACC_L,DIR_ACC_R;
	always @(posedge CLK or negedge RST_N) begin
		bit [ 4:0] S;
		bit signed [15:0] TEMP;
		bit signed [15:0] PAN_L,PAN_R;
		
		if (!RST_N) begin
			// synopsys translate_off
			DIR_ACC_L <= 0;
			DIR_ACC_R <= 0;
			// synopsys translate_on
		end
		else begin
			S = OP7_PIPE.SLOT;
			
			if (SLOT_CE) begin
				TEMP = LevelCalc(OP7_SD,SCR8.DISDL);
				PAN_L = PanLCalc(TEMP,SCR8.DIPAN);
				PAN_R = PanRCalc(TEMP,SCR8.DIPAN);
				if (S == 5'd0) begin
					DIR_ACC_L <= {{4{PAN_L[15]}},PAN_L};
					DIR_ACC_R <= {{4{PAN_R[15]}},PAN_R};
				end else begin
					DIR_ACC_L <= DIR_ACC_L + {{4{PAN_L[15]}},PAN_L};
					DIR_ACC_R <= DIR_ACC_R + {{4{PAN_R[15]}},PAN_R};
				end
`ifdef DEBUG
				LVL_DBG <= TEMP;
				PAN_L_DBG <= PAN_L;
				PAN_R_DBG <= PAN_R;
`endif
			end
		end
	end
`ifdef DEBUG
	assign DIR_ACC_L_OF = ^DIR_ACC_L[19:18];
	assign DIR_ACC_R_OF = ^DIR_ACC_R[19:18];
`endif
	
	//DSP input
	always @(posedge CLK or negedge RST_N) begin
		bit [ 4:0] S;
		bit signed [15:0] TEMP;
		bit signed [15:0] PAN_L,PAN_R;
		
		if (!RST_N) begin
			// synopsys translate_off
			DSP_MIXS <= '{16{'0}};
			DSP_EXTS <= '{2{'0}};
			// synopsys translate_on
		end
		else begin
			S = OP7_PIPE.SLOT;
			
			if (SLOT_CE) begin
				if (S == 5'd0) begin
					DSP_MIXS <= '{16{'0}};
				end
				TEMP = LevelCalc(OP7_SD,SCR7.IMXL);
				DSP_MIXS[SCR7.ISEL] <= DSP_MIXS[SCR7.ISEL] + {{4{TEMP[15]}},TEMP};
			end
			DSP_EXTS[0] <= ESL;
			DSP_EXTS[1] <= ESR;
		end
	end
	
	//DSP execute
	bit  [ 6: 0] DSP_MPRO_STEP;
	bit  [ 6: 0] DSP_TEMP_RA;
	bit  [ 6: 0] DSP_TEMP_WA;
	TEMP_t       DSP_TEMP_D;
	bit          DSP_TEMP_WE;
	bit  [ 4: 0] DSP_MEMS_RA;
	bit  [ 4: 0] DSP_MEMS_WA;
	MEMS_t       DSP_MEMS_D;
	bit          DSP_MEMS_WE;
	bit  [ 5: 0] DSP_COEF_RA;
	bit  [ 4: 0] DSP_MADRS_RA;
	bit  [ 3: 0] DSP_EFREG_RA;
	bit  [ 3: 0] DSP_EFREG_WA;
	bit          DSP_EFREG_WE;
	EFREG_t      DSP_EFREG_D;
	bit  [15: 0] MDEC_CT;
	bit  [25: 0] SFT_REG;
	bit  [19: 1] DSP_MEMA_REG;
	bit  [15: 0] DSP_INP_REG;
	bit  [15: 0] DSP_OUT_REG;
	bit          DSP_READ;
	bit          DSP_WRITE;
	
	wire [23: 0] SHFT_OUT = DSPShifter(SFT_REG, DSP_MPRO_Q.SHFT);
	
	always @(posedge CLK or negedge RST_N) begin
		bit  [23: 0] INPUTS;
		bit  [23: 0] X;
		bit  [12: 0] Y;
		bit  [25: 0] B;
		bit  [23: 0] Y_REG;
		bit  [12: 0] FRC_REG;
		bit  [11: 0] ADRS_REG;
		bit  [25: 0] MUL;
		bit  [16: 1] ADDR;
		
		if (!RST_N) begin
			DSP_MPRO_STEP <= '0;
			MDEC_CT <= '0;
			DSP_READ <= 0;
			DSP_WRITE <= 0;
			// synopsys translate_off
			EFREGS <= '{16{'0}};
			Y_REG <= '0;
			FRC_REG <= '0;
			ADRS_REG <= '0;
			DSP_MEMA_REG <= '0;
			DSP_INP_REG <= '0;
			DSP_OUT_REG <= '0;
			// synopsys translate_on
		end
		else begin
			if (CYCLE_CE) begin
				DSP_MPRO_STEP <= DSP_MPRO_STEP + 7'd1;
				
				if (DSP_MPRO_STEP == 7'd127)
					MDEC_CT <= MDEC_CT - 16'd1;
				
				if (!DSP_MPRO_Q.IRA[5])
					INPUTS = DSP_MEMS_Q;
				else if (!DSP_MPRO_Q.IRA[4])
					INPUTS = {DSP_MIXS[DSP_MPRO_Q.IRA[3:0]],4'h0};
				else if (!DSP_MPRO_Q.IRA[3:1])
					INPUTS = {DSP_EXTS[DSP_MPRO_Q.IRA[0]],8'h00};
				
				case (DSP_MPRO_Q.XSEL)
					1'b0: X = DSP_TEMP_Q;
					1'b1: X = INPUTS;
				endcase
				case (DSP_MPRO_Q.YSEL)
					2'b00: Y = FRC_REG;
					2'b01: Y = DSP_COEF_Q.COEF;
					2'b10: Y = Y_REG[23:12];
					2'b11: Y = {1'b0,Y_REG[15:4]};
				endcase
				
				B = DSP_MPRO_Q.ZERO ? '0 : !DSP_MPRO_Q.BSEL ? {DSP_TEMP_Q,2'b00} : SFT_REG;
				MUL = DSPMulti(X, Y);
				SFT_REG <= MUL + (!DSP_MPRO_Q.NEGB ? B : 26'd0 - B);

				if (DSP_MPRO_Q.YRL)
					Y_REG <= INPUTS;
				
				if (DSP_MPRO_Q.FRCL) begin
					if (DSP_MPRO_Q.SHFT == 2'b11)
						FRC_REG <= {1'b0,SHFT_OUT[11:0]};
					else
						FRC_REG <= SHFT_OUT[23:11];
				end
				
				if (DSP_MPRO_Q.ADRL) begin
					if (DSP_MPRO_Q.SHFT == 2'b11)
						ADRS_REG <= SHFT_OUT[23:12];
					else
						ADRS_REG <= {4'h0,INPUTS[23:16]};///////
				end
				
				ADDR = DSP_MADRS_Q + (!DSP_MPRO_Q.TABLE ? MDEC_CT : 16'h0000) + (DSP_MPRO_Q.ADREB ? ADRS_REG : 16'h0000) + (DSP_MPRO_Q.NXADR ? 16'h0001 : 16'h0000);
				DSP_MEMA_REG <= {CR1.RBP,12'h000} + ADDR;//TODO CR1.RBL
				DSP_OUT_REG <= SHFT_OUT[23:8];//TODO NOFL
				DSP_READ <= DSP_MPRO_Q.MRD;
				DSP_WRITE <= DSP_MPRO_Q.MWT;
			end
		end
	end
	assign DSP_TEMP_RA = DSP_MPRO_Q.TRA + MDEC_CT[6:0];
	assign DSP_TEMP_WA = DSP_MPRO_Q.TWA + MDEC_CT[6:0];
	assign DSP_TEMP_WE = DSP_MPRO_Q.TWT;
	assign DSP_TEMP_D = SHFT_OUT;
	
	assign DSP_MEMS_RA = DSP_MPRO_Q.IRA[4:0];
	assign DSP_MEMS_WA = DSP_MPRO_Q.IWA;
	assign DSP_MEMS_WE = DSP_MPRO_Q.IWT;
	assign DSP_MEMS_D = {DSP_INP_REG,8'h00};//TODO NOFL
	
	assign DSP_COEF_RA = DSP_MPRO_Q.COEF;
	assign DSP_MADRS_RA = DSP_MPRO_Q.MASA;
	
	assign DSP_EFREG_RA = OP7_PIPE.SLOT[3:0];
	assign DSP_EFREG_WA = DSP_MPRO_Q.EWA;
	assign DSP_EFREG_WE = DSP_MPRO_Q.EWT;
	assign DSP_EFREG_D = SHFT_OUT[23:8];
	
	
	
	//Effect out
	bit signed [19:0] EFF_ACC_L,EFF_ACC_R;
	always @(posedge CLK or negedge RST_N) begin
		bit [ 4:0] S;
		bit signed [15:0] TEMP;
		bit signed [15:0] PAN_L,PAN_R;
		
		if (!RST_N) begin
			// synopsys translate_off
			EFF_ACC_L <= '0;
			EFF_ACC_R <= '0;
			// synopsys translate_on
		end
		else begin
			S = OP7_PIPE.SLOT;
			
			if (OUT_CE) begin
				TEMP = '0;
				PAN_L = '0;
				PAN_R = '0;
				if (S <= 5'd15) begin
					TEMP = LevelCalc(DSP_EFREG_Q,SCR8.EFSDL);//LevelCalc(DSP_MIXS[S[3:0]][19:4],SCR8.EFSDL);
					PAN_L = PanLCalc(TEMP,SCR8.EFPAN);
					PAN_R = PanRCalc(TEMP,SCR8.EFPAN);
				end else if (S == 5'd16) begin
					TEMP = LevelCalc(ESL,3'h7/*SCR8.EFSDL*/);
					PAN_L = PanLCalc(TEMP,5'h1F/*SCR8.EFPAN*/);
				end else if (S == 5'd17) begin
					TEMP = LevelCalc(ESR,3'h7/*SCR8.EFSDL*/);
					PAN_R = PanRCalc(TEMP,5'h0F/*SCR8.EFPAN*/);
				end
//				PAN_L = PanLCalc(TEMP,SCR8.EFPAN);
//				PAN_R = PanRCalc(TEMP,SCR8.EFPAN);
				
				if (S == 5'd0) begin
					EFF_ACC_L <= {{4{PAN_L[15]}},PAN_L};
					EFF_ACC_R <= {{4{PAN_R[15]}},PAN_R};
				end else begin
					EFF_ACC_L <= EFF_ACC_L + {{4{PAN_L[15]}},PAN_L};
					EFF_ACC_R <= EFF_ACC_R + {{4{PAN_R[15]}},PAN_R};
				end
			end
		end
	end
`ifdef DEBUG
	assign EFF_ACC_L_OF = ^EFF_ACC_L[19:18];
	assign EFF_ACC_R_OF = ^EFF_ACC_R[19:18];
`endif
	
	//Out
	assign SAMPLE_CE = (OP7_PIPE.SLOT == 5'd31) && CYCLE_NUM == 2'b11 && CYCLE_CE;
	bit signed [15:0] DIR_L,DIR_R;
	bit signed [15:0] EFF_L,EFF_R;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			// synopsys translate_off
			DIR_L <= '0;
			DIR_R <= '0;
			// synopsys translate_on
		end else begin
			if (SAMPLE_CE) begin
				DIR_L <= SND_EN[0] ? $signed(DIR_ACC_L[19:4]) : 16'sh0000;
				DIR_R <= SND_EN[0] ? $signed(DIR_ACC_R[19:4]) : 16'sh0000;
				EFF_L <= SND_EN[1] ? $signed(EFF_ACC_L[19:4]) : 16'sh0000;
				EFF_R <= SND_EN[1] ? $signed(EFF_ACC_R[19:4]) : 16'sh0000;
			end
		end
	end
	assign SOUND_L = MVolCalc(DIR_L + EFF_L,CR0.MVOL);
	assign SOUND_R = MVolCalc(DIR_R + EFF_R,CR0.MVOL);
	
	
	//Timers
	bit [7:0] TMR_CE;
	always @(posedge CLK or negedge RST_N) begin
		bit [6:0] CNT;
	
		if (!RST_N) begin
			CNT <= '0;
			TMR_CE <= '0;
		end else begin
			TMR_CE <= '0;
			if (SAMPLE_CE) begin
				CNT <= CNT + 7'd1;
				TMR_CE[0] <= 1;
				TMR_CE[1] <= &CNT[0:0];
				TMR_CE[2] <= &CNT[1:0];
				TMR_CE[3] <= &CNT[2:0];
				TMR_CE[4] <= &CNT[3:0];
				TMR_CE[5] <= &CNT[4:0];
				TMR_CE[6] <= &CNT[5:0];
				TMR_CE[7] <= &CNT[6:0];
			end
		end
	end
	wire TMRA_CE = TMR_CE[CR8.TACTL];
	wire TMRB_CE = TMR_CE[CR9.TBCTL];
	wire TMRC_CE = TMR_CE[CR10.TCCTL];
	
	//DMA
	always @(posedge CLK or negedge RST_N) begin
		bit DEXE_OLD;
	
		if (!RST_N) begin
			DMA_MA <= '0;
			DMA_RA <= '0;
			DMA_LEN <= '0;
			DMA_WR <= 0;
			DMA_EXEC <= 0;
			DEXE_OLD <= 0;
		end else begin
			DEXE_OLD <= CR7.DEXE;
			if (CR7.DEXE && !DEXE_OLD) begin
				DMA_MA <= {CR6.DMEAH,CR5.DMEAL};
				DMA_RA <= CR6.DRGA;
				DMA_LEN <= CR7.DTLG;
				DMA_WR <= 0;
				DMA_EXEC <= 1;
			end
			
			if (DMA_EXEC) begin
				if (!DMA_WR && MEM_ST == MS_DMA_WAIT && RAM_RDY) begin
					DMA_MA <= DMA_MA + 19'd1;
					DMA_WR <= 1;
				end else if (DMA_WR && REG_ST == MS_DMA_WAIT && REG_RDY) begin
					DMA_RA <= DMA_RA + 11'd1;
					DMA_LEN <= DMA_LEN - 11'd1;
					if (!DMA_LEN) DMA_EXEC <= 0;
					DMA_WR <= 0;
				end
			end
		end
	end
	
	//RAM access
	bit [20:1] A;
	bit        WE_N;
	bit  [1:0] DQM;
	bit        BURST;
	
	wire SCU_REQ = ~AD_N & ~CS_N & ~REQ_N;	//25A00000-25BFFFFF
	bit [20:1] SCU_RA;
	bit        SCU_RPEND;
	bit        SCU_RRDY;
	bit [20:1] SCU_WA;
	bit [15:0] SCU_D;
	bit  [1:0] SCU_WE;
	bit        SCU_WPEND;
	bit        SCU_WRDY;
	bit [20:1] SAVE_WA;
	bit [15:0] SAVE_D;
	bit  [1:0] SAVE_WE;
	bit        SCPU_PEND;
	always @(posedge CLK or negedge RST_N) begin
		bit CYCLE_START;
		
		if (!RST_N) begin
			MEM_ST <= MS_IDLE;
			MEM_A <= '0;
			MEM_D <= '0;
			MEM_WE <= '0;
			MEM_RD <= 0;
			REG_ST <= MS_IDLE;
			REG_A <= '0;
			REG_D <= '0;
			REG_WE <= '0;
			REG_RD <= 0;
			A <= '0;
			WE_N <= 1;
			DQM <= '1;
			BURST <= 0;
			SCPU_PEND <= 0;
			SCDTACK_N <= 1;
			SCU_RPEND <= 0;
			SCU_RRDY <= 1;
			SCU_WPEND <= 0;
			SCU_WRDY <= 1;
		end
		else begin
			if (!CS_N && DTEN_N && AD_N && CE_R) begin
				if (!DI[15]) begin
					A[20:9] <= DI[11:0];
					WE_N <= DI[14];
					BURST <= DI[13];
				end else begin
					A[8:1] <= DI[7:0];
					DQM <= DI[13:12];
				end
			end
			
			if (SCU_REQ && WE_N) begin
				SCU_RA <= A;
				SCU_RPEND <= 1;
				SCU_RRDY <= 0;
				A <= A + 20'd1;
			end
			
			if (SCU_REQ && !WE_N && !DTEN_N) begin
				if (!SCU_WPEND) begin
					SCU_WA <= A;
					SCU_D <= DI;
					SCU_WE <= ~{2{WE_N}} & ~DQM;
					SCU_WPEND <= 1;
				end else begin
					SAVE_WA <= A;
					SAVE_D <= DI;
					SAVE_WE <= ~{2{WE_N}} & ~DQM;
					SCU_WRDY <= 0;
				end
				A <= A + 20'd1;
			end
			if (!SCU_WRDY && !SCU_WPEND) begin
				SCU_WA <= SAVE_WA;
				SCU_D <= SAVE_D;
				SCU_WE <= SAVE_WE;
				SCU_WPEND <= 1;
				SCU_WRDY <= 1;
			end
			
			if ((MEM_ST == MS_SCU_WAIT && MEM_RD && RAM_RDY) || (REG_ST == MS_SCU_WAIT && REG_RD && REG_RDY)) begin
				SCU_RRDY <= 1;
				SCU_RPEND <= 0;
			end
			
			if (!SCAS_N && (!SCLDS_N || !SCUDS_N) && SCDTACK_N && SCFC != 3'b111 && !SCPU_PEND) SCPU_PEND <= 1;
			if ((MEM_ST == MS_SCPU_WAIT && RAM_RDY) || (REG_ST == MS_SCPU_WAIT && REG_RDY)) SCPU_PEND <= 0;
			
			CYCLE_START <= CYCLE_CE;
			
			MEM_RFS <= 0;
			case (MEM_ST)
				MS_IDLE: if (CYCLE_START) begin
					if (WD_READ && SLOT_EN) begin
						MEM_A <= ADP[18:1];
						MEM_D <= '0;
						MEM_WE <= '0;
						MEM_RD <= 1;
						MEM_CS <= 1;
						MEM_ST <= MS_WD_WAIT;
					end else if (DMA_EXEC && !DMA_WR) begin
						MEM_A <= DMA_MA[18:1];
						MEM_D <= '0;
						MEM_WE <= '0;
						MEM_RD <= 1;
						MEM_CS <= 1;
						MEM_ST <= MS_DMA_WAIT;
//					end else if (!SCA[20] && !SCAS_N && (!SCLDS_N || !SCUDS_N) && SCDTACK_N) begin
					end else if (!SCA[20] && SCPU_PEND) begin
						MEM_A <= SCA[18:1];
						MEM_D <= SCDI;
						MEM_WE <= {~SCRW_N&~SCUDS_N,~SCRW_N&~SCLDS_N};
						MEM_RD <= SCRW_N;
						MEM_CS <= 1;
						MEM_ST <= MS_SCPU_WAIT;
`ifdef DEBUG
//						DBG_68K_ERR <= ({SCA[20:1],1'b0} == 21'h001682) || ({SCA[20:1],1'b0} == 21'h00168C) || ({SCA[20:1],1'b0} == 21'h001696);
						DBG_68K_ERR <= ({SCA[20:1],1'b0} == 21'h0015F2) || ({SCA[20:1],1'b0} == 21'h0015FC) || ({SCA[20:1],1'b0} == 21'h001606);
						if ({SCA[19:1],1'b0} == 20'h004E0 && !SCUDS_N && !SCRW_N) DBG_SCU_HOOK <= SCDI[15];
						if ({SCA[19:1],1'b0} == 20'h00710 && !SCUDS_N && !SCRW_N) DBG_SCU_710 <= SCDI[15:8];
`endif
					end else if (!SCU_WA[20] && SCU_WPEND) begin
						SCU_WPEND <= 0;
						MEM_A <= SCU_WA[18:1];
						MEM_D <= SCU_D;
						MEM_WE <= SCU_WE;
						MEM_RD <= 0;
						MEM_CS <= ~SCU_WA[19];
						MEM_ST <= MS_SCU_WAIT;
`ifdef DEBUG
						if ({SCU_WA[19:1],1'b0} == 20'h004E0 && SCU_WE == 2'b10) DBG_SCU_HOOK <= SCU_D[15];
						if ({SCU_WA[19:1],1'b0} == 20'h00710 && SCU_WE[1]) DBG_SCU_710 <= SCU_D[15:8];
`endif
					end else if (!SCU_RA[20] && SCU_RPEND) begin
						MEM_A <= SCU_RA[18:1];
						MEM_WE <= 2'b00;
						MEM_RD <= 1;
						MEM_CS <= ~SCU_RA[19];
						MEM_ST <= MS_SCU_WAIT;
					end else begin
						MEM_RFS <= 1;
					end
				end
				
				MS_WD_WAIT: begin
					if (RAM_RDY) begin
						MEM_WD <= RAM_Q;
						MEM_WE <= '0;
						MEM_RD <= 0;
						MEM_CS <= 0;
						MEM_ST <= MS_IDLE;
					end
				end
				
				MS_DMA_WAIT: begin
					if (RAM_RDY) begin
						DMA_DAT <= RAM_Q;
						MEM_WE <= '0;
						MEM_RD <= 0;
						MEM_CS <= 0;
						MEM_ST <= MS_IDLE;
					end
				end
				
				MS_SCU_WAIT: begin
					if (RAM_RDY) begin
						DO <= RAM_Q;
						MEM_WE <= '0;
						MEM_RD <= 0;
						MEM_CS <= 0;
						MEM_ST <= MS_IDLE;
					end
				end
				
				MS_SCPU_WAIT: begin
					if (RAM_RDY) begin
						SCDTACK_N <= 0;
						SCDO <= RAM_Q;
						MEM_WE <= '0;
						MEM_RD <= 0;
						MEM_CS <= 0;
						MEM_ST <= MS_IDLE;
					end
				end
				
				MS_END: begin
					/*if (CYCLE_CE || !SLOT_EN)*/ MEM_ST <= MS_IDLE;
				end
				
				default:;
			endcase
			
			case (REG_ST)
				MS_IDLE: if (CYCLE_START && !SLOT_EN) begin
					if (DMA_EXEC && DMA_WR) begin
						REG_A <= DMA_RA;
						REG_D <= DMA_DAT;
						REG_WE <= '1;
						REG_RD <= 0;
						REG_CS <= 1;
						REG_ST <= MS_DMA_WAIT;
					end else if (SCA[20] && SCPU_PEND) begin
						REG_A <= SCA[11:1];
						REG_D <= SCDI;
						REG_WE <= {~SCRW_N&~SCUDS_N,~SCRW_N&~SCLDS_N};
						REG_RD <= SCRW_N;
						REG_CS <= 1;
						REG_ST <= MS_SCPU_WAIT;
					end else if (SCU_WA[20] && SCU_WPEND) begin
						SCU_WPEND <= 0;
						REG_A <= SCU_WA[11:1];
						REG_D <= SCU_D;
						REG_WE <= SCU_WE;
						REG_RD <= 0;
						REG_CS <= 1;
						REG_ST <= MS_SCU_WAIT;
					end else if (SCU_RA[20] && SCU_RPEND) begin
						REG_A <= SCU_RA[11:1];
						REG_WE <= 2'b00;
						REG_RD <= 1;
						REG_CS <= 1;
						REG_ST <= MS_SCU_WAIT;
					end
				end
				
				MS_WD_WAIT:;
				
				MS_DMA_WAIT: begin
					if (REG_RDY) begin
						REG_WE <= '0;
						REG_RD <= 0;
						REG_CS <= 0;
						REG_ST <= MS_IDLE;
					end
				end
				
				MS_SCU_WAIT: begin
					if (REG_RDY) begin
						DO <= REG_Q;
						REG_WE <= '0;
						REG_RD <= 0;
						REG_CS <= 0;
//						SCU_PEND <= 0;
						REG_ST <= MS_IDLE;
					end
				end
				
				MS_SCPU_WAIT: begin
					if (REG_RDY) begin
						SCDTACK_N <= 0;
						SCDO <= REG_Q;
						REG_WE <= '0;
						REG_RD <= 0;
						REG_CS <= 0;
						REG_ST <= MS_IDLE;
					end
				end
								
				MS_END: begin
					/*if (CYCLE_CE || !SLOT_EN)*/ REG_ST <= MS_IDLE;
				end
				
				default:;
			endcase
			
			if (SCAS_N && !SCDTACK_N) begin
				SCDTACK_N <= 1;
			end
		end
	end
	
	assign RAM_A = MEM_A;
	assign RAM_D = MEM_D;
	assign RAM_WE = MEM_WE;
	assign RAM_RD = MEM_RD;
	assign RAM_CS = MEM_CS;
	assign RAM_RFS = MEM_RFS;
	
	//Registers
	always @(posedge CLK or negedge RST_N) begin
		bit DMA_EXEC_OLD;
		
		if (!RST_N) begin
			SCR <= '{32{'0}};
			CR0 <= '0;
			CR1 <= '0;
			CR2 <= '0;
			CR3 <= '0;
			CR4 <= '0;
			CR5 <= '0;
			CR6 <= '0;
			CR7 <= '0;
			CR8 <= '0;
			CR9 <= '0;
			CR10 <= '0;
			CR11 <= '0;
			CR12 <= '0;
			CR13 <= '0;
			CR14 <= '0;
			CR15 <= '0;
			CR16 <= '0;
			CR17 <= '0;
			CR18 <= '0;
			CR19 <= '0;
			REG_Q <= '0;
			REG_RDY <= 0;
		end else begin
			if (!RES_N) begin
				SCR <= '{32{'0}};
				CR0 <= '0;
				CR1 <= '0;
				CR2 <= '0;
				CR3 <= '0;
				CR4 <= '0;
				CR5 <= '0;
				CR6 <= '0;
				CR7 <= '0;
				CR8 <= '0;
				CR9 <= '0;
				CR10 <= '0;
				CR11 <= '0;
				CR12 <= '0;
				CR13 <= '0;
				CR14 <= '0;
				CR15 <= '0;
				CR16 <= '0;
				CR17 <= '0;
				CR18 <= '0;
				CR19 <= '0;
			end else begin
				DMA_EXEC_OLD <= DMA_EXEC;
				if (!DMA_EXEC && DMA_EXEC_OLD) begin
					{CR12.SCIPD[4],CR18.MCIPD[4]} <= '1;
				end
				if (TMRA_CE) begin
					CR8.TIMA  <= CR8.TIMA  + 8'd1;
					if (CR8.TIMA == 8'hFF) {CR12.SCIPD[6],CR18.MCIPD[6]} <= '1;
				end
				if (TMRB_CE) begin
					CR9.TIMB  <= CR9.TIMB  + 8'd1;
					if (CR9.TIMB == 8'hFF) {CR12.SCIPD[7],CR18.MCIPD[7]} <= '1;
				end
				if (TMRC_CE) begin
					CR10.TIMC <= CR10.TIMC + 8'd1;
					if (CR10.TIMC == 8'hFF) {CR12.SCIPD[8],CR18.MCIPD[8]} <= '1;
				end
				if (SAMPLE_CE) begin
					{CR12.SCIPD[10],CR18.MCIPD[10]} <= '1;
				end

				REG_RDY <= 0;
				if (REG_WE && REG_CS) begin
					if (REG_A[11:10] == 2'b00) begin
						for (int i=0; i<32; i++) begin
							if (REG_A[9:5] == i) begin
								case ({REG_A[4:1],1'b0})
									5'h00: begin
										if (REG_WE[0]) SCR[i].SCR0[ 7:0] <= REG_D[ 7:0] & SCR0_MASK[ 7:0];
										if (REG_WE[1]) SCR[i].SCR0[15:8] <= REG_D[15:8] & SCR0_MASK[15:8];
									end
									default:;
								endcase
							end
						end
					end else if (REG_A[11:9] == 3'b010) begin
						case ({REG_A[5:1],1'b0})
							6'h00: begin
								if (REG_WE[0]) CR0[ 7:0] <= REG_D[ 7:0] & CR0_MASK[ 7:0];
								if (REG_WE[1]) CR0[15:8] <= REG_D[15:8] & CR0_MASK[15:8];
							end
							6'h02: begin
								if (REG_WE[0]) CR1[ 7:0] <= REG_D[ 7:0] & CR1_MASK[ 7:0];
								if (REG_WE[1]) CR1[15:8] <= REG_D[15:8] & CR1_MASK[15:8];
							end
							6'h04: begin
								if (REG_WE[0]) CR2[ 7:0] <= REG_D[ 7:0] & CR2_MASK[ 7:0];
								if (REG_WE[1]) CR2[15:8] <= REG_D[15:8] & CR2_MASK[15:8];
							end
							6'h06: begin
								if (REG_WE[0]) CR3[ 7:0] <= REG_D[ 7:0] & CR3_MASK[ 7:0];
								if (REG_WE[1]) CR3[15:8] <= REG_D[15:8] & CR3_MASK[15:8];
							end
							6'h08: begin
								//if (MEM_WE[0]) CR4[ 7:0] <= MEM_D[ 7:0] & CR4_MASK[ 7:0];
								//if (MEM_WE[1]) CR4[15:8] <= MEM_D[15:8] & CR4_MASK[15:8];
								if (REG_WE[1]) CR4[15:11] <= REG_D[15:11];
							end
							6'h12: begin
								if (REG_WE[0]) CR5[ 7:0] <= REG_D[ 7:0] & CR5_MASK[ 7:0];
								if (REG_WE[1]) CR5[15:8] <= REG_D[15:8] & CR5_MASK[15:8];
							end
							6'h14: begin
								if (REG_WE[0]) CR6[ 7:0] <= REG_D[ 7:0] & CR6_MASK[ 7:0];
								if (REG_WE[1]) CR6[15:8] <= REG_D[15:8] & CR6_MASK[15:8];
							end
							6'h16: begin
								if (REG_WE[0]) CR7[ 7:0] <= REG_D[ 7:0] & CR7_MASK[ 7:0];
								if (REG_WE[1]) CR7[15:8] <= REG_D[15:8] & CR7_MASK[15:8];
							end
							6'h18: begin
								if (REG_WE[0]) CR8[ 7:0] <= REG_D[ 7:0] & CR8_MASK[ 7:0];
								if (REG_WE[1]) CR8[15:8] <= REG_D[15:8] & CR8_MASK[15:8];
							end
							6'h1A: begin
								if (REG_WE[0]) CR9[ 7:0] <= REG_D[ 7:0] & CR9_MASK[ 7:0];
								if (REG_WE[1]) CR9[15:8] <= REG_D[15:8] & CR9_MASK[15:8];
							end
							6'h1C: begin
								if (REG_WE[0]) CR10[ 7:0] <= REG_D[ 7:0] & CR10_MASK[ 7:0];
								if (REG_WE[1]) CR10[15:8] <= REG_D[15:8] & CR10_MASK[15:8];
							end
							6'h1E: begin
								if (REG_WE[0]) CR11[ 7:0] <= REG_D[ 7:0] & CR11_MASK[ 7:0];
								if (REG_WE[1]) CR11[15:8] <= REG_D[15:8] & CR11_MASK[15:8];
							end
							6'h20: begin
								if (REG_WE[0]) CR12[5] <= REG_D[5];
							end
							6'h22: begin
								if (REG_WE[0]) CR13[ 7:0] <= REG_D[ 7:0] & CR13_MASK[ 7:0];
								if (REG_WE[1]) CR13[15:8] <= REG_D[15:8] & CR13_MASK[15:8];
								if (REG_WE[0]) CR12.SCIPD[ 7:0] <= CR12.SCIPD[ 7:0] & ~REG_D[ 7:0];
								if (REG_WE[1]) CR12.SCIPD[10:8] <= CR12.SCIPD[10:8] & ~REG_D[10:8];
							end
							6'h24: begin
								if (REG_WE[0]) CR14[ 7:0] <= REG_D[ 7:0] & CR14_MASK[ 7:0];
								if (REG_WE[1]) CR14[15:8] <= REG_D[15:8] & CR14_MASK[15:8];
							end
							6'h26: begin
								if (REG_WE[0]) CR15[ 7:0] <= REG_D[ 7:0] & CR15_MASK[ 7:0];
								if (REG_WE[1]) CR15[15:8] <= REG_D[15:8] & CR15_MASK[15:8];
							end
							6'h28: begin
								if (REG_WE[0]) CR16[ 7:0] <= REG_D[ 7:0] & CR16_MASK[ 7:0];
								if (REG_WE[1]) CR16[15:8] <= REG_D[15:8] & CR16_MASK[15:8];
							end
							6'h2A: begin
								if (REG_WE[0]) CR17[ 7:0] <= REG_D[ 7:0] & CR17_MASK[ 7:0];
								if (REG_WE[1]) CR17[15:8] <= REG_D[15:8] & CR17_MASK[15:8];
							end
							6'h2C: begin
								if (REG_WE[0]) CR18[5] <= REG_D[5];
							end
							6'h2E: begin
								if (REG_WE[0]) CR19[ 7:0] <= REG_D[ 7:0] & CR19_MASK[ 7:0];
								if (REG_WE[1]) CR19[15:8] <= REG_D[15:8] & CR19_MASK[15:8];
								if (REG_WE[0]) CR18.MCIPD[ 7:0] <= CR18.MCIPD[ 7:0] & ~REG_D[ 7:0];
								if (REG_WE[1]) CR18.MCIPD[10:8] <= CR18.MCIPD[10:8] & ~REG_D[10:8];
							end
							default:;
						endcase
	//				end else if (REG_A[11:9] == 3'b011) begin
	//					if (MEM_WE[0]) STACK[REG_A[7:1]][ 7:0] <= MEM_D[ 7:0];
	//					if (MEM_WE[1]) STACK[REG_A[7:1]][15:8] <= MEM_D[15:8];
					end
					REG_RDY <= 1;
				end else if (REG_RD && REG_CS) begin
					if (REG_A[11:10] == 2'b00) begin
						for (int i=0; i<32; i++) begin
							if (REG_A[9:5] == i) begin
								case ({REG_A[4:1],1'b0})
									5'h00: REG_Q <= SCR_SCR0_Q & SCR0_MASK;
									5'h02: REG_Q <= SCR_SA_Q & SA_MASK;
									5'h04: REG_Q <= SCR_LSA_Q & LSA_MASK;
									5'h06: REG_Q <= SCR_LEA_Q & LEA_MASK;
									5'h08: REG_Q <= SCR_SCR1_Q & SCR1_MASK;
									5'h0A: REG_Q <= SCR_SCR2_Q & SCR2_MASK;
									5'h0C: REG_Q <= SCR_SCR3_Q & SCR3_MASK;
									5'h0E: REG_Q <= SCR_SCR4_Q & SCR4_MASK;
									5'h10: REG_Q <= SCR_SCR5_Q & SCR5_MASK;
									5'h12: REG_Q <= SCR_SCR6_Q & SCR6_MASK;
									5'h14: REG_Q <= SCR_SCR7_Q & SCR7_MASK;
									5'h16: REG_Q <= SCR_SCR8_Q & SCR8_MASK;
									default:REG_Q <= '0;
								endcase
							end
						end
					end else if (REG_A[11:9] == 3'b010) begin
						case ({REG_A[5:1],1'b0})
							6'h00: REG_Q <= CR0 & CR0_MASK;
							6'h02: REG_Q <= CR1 & CR1_MASK;
							6'h04: REG_Q <= CR2 & CR2_MASK;
							6'h06: REG_Q <= CR3 & CR3_MASK;
							6'h08: REG_Q <= CR4 & CR4_MASK;
							6'h12: REG_Q <= CR5 & CR5_MASK;
							6'h14: REG_Q <= CR6 & CR6_MASK;
							6'h16: REG_Q <= CR7 & CR7_MASK;
							6'h18: REG_Q <= CR8 & CR8_MASK;
							6'h1A: REG_Q <= CR9 & CR9_MASK;
							6'h1C: REG_Q <= CR10 & CR10_MASK;
							6'h1E: REG_Q <= CR11 & CR11_MASK;
							6'h20: REG_Q <= CR12 & CR12_MASK;
							6'h22: REG_Q <= CR13 & CR13_MASK;
							6'h24: REG_Q <= CR14 & CR14_MASK;
							6'h26: REG_Q <= CR15 & CR15_MASK;
							6'h28: REG_Q <= CR16 & CR16_MASK;
							6'h2A: REG_Q <= CR17 & CR17_MASK;
							6'h2C: REG_Q <= CR18 & CR18_MASK;
							6'h2E: REG_Q <= CR19 & CR19_MASK;
							default: REG_Q <= '0;
						endcase
					end else if (SOUS_SEL) begin
						REG_Q <= STACK1_Q;
					end else if (COEF_SEL) begin
						REG_Q <= COEF_RAM_Q & COEF_MASK;
					end else if (MADRS_SEL) begin
						REG_Q <= MADRS_RAM_Q & MADRS_MASK;
					end else if (MPRO_SEL) begin
						case (REG_A[2:1])
							2'b00: REG_Q <= MPRO_RAM_Q[63:48] & MPRO_MASK[63:48];
							2'b01: REG_Q <= MPRO_RAM_Q[47:32] & MPRO_MASK[47:32];
							2'b10: REG_Q <= MPRO_RAM_Q[31:16] & MPRO_MASK[31:16];
							2'b11: REG_Q <= MPRO_RAM_Q[15: 0] & MPRO_MASK[15: 0];
						endcase
					end else if (TEMP_SEL) begin
						case (REG_A[1])
							1'b0: REG_Q <= TEMP_RAM_Q[15: 0] & TEMP_MASK[15: 0];
							1'b1: REG_Q <= TEMP_RAM_Q[31:16] & TEMP_MASK[31:16];
						endcase
					end else if (MEMS_SEL) begin
						case (REG_A[1])
							1'b0: REG_Q <= MEMS_RAM_Q[15: 0] & MEMS_MASK[15: 0];
							1'b1: REG_Q <= MEMS_RAM_Q[31:16] & MEMS_MASK[31:16];
						endcase
					end else if (EFREG_SEL) begin
						REG_Q <= EFREG_RAM_Q & EFREG_MASK;
					end else begin
						REG_Q <= '0;
					end
					REG_RDY <= 1;
				end
				
				if (OP3_PIPE.SLOT == CR4.MSLC && SLOT_CE) begin
					CR4.CA <= OP3_SAOI[15:12];
//					case (EGST[CR4.MSLC])
//						EGS_ATTACK: CR4.SGC <= 2'b00;
//						EGS_DECAY1: CR4.SGC <= 2'b01;
//						EGS_DECAY2: CR4.SGC <= 2'b10;
//						EGS_RELEASE: CR4.SGC <= 2'b11;
//					endcase
//					CR4.EG <= EVOL[CR4.MSLC][9:5];
				end
			end
		end
	end
	
	
	wire       SCR_SEL = REG_A[11:10] == 2'b00;
	wire       REG_RDEN = REG_CS;//~(SLOT_EN | DSP_EN);
	wire       REG_WREN = REG_CS;//~(SLOT_EN | DSP_EN);
	
	wire       SCR_SCR0_SEL  = SCR_SEL & (REG_A[4:1] == 5'h00>>1) & REG_CS;
	bit [15:0] SCR_SCR0_Q;
	SCSP_SPRAM SCR_SCR0(CLK, REG_A[9:5], REG_D & SCR0_MASK , (REG_WE & {2{SCR_SCR0_SEL}}), (REG_RDEN ? REG_A[9:5] : OP3_PIPE.SLOT), SCR_SCR0_Q);
	
	wire       SCR_SA_SEL   = SCR_SEL & (REG_A[4:1] == 5'h02>>1) & REG_CS;
	bit [15:0] SCR_SA_Q;
	SCSP_SPRAM SCR_SA  (CLK, REG_A[9:5], REG_D & SA_MASK  , (REG_WE & {2{SCR_SA_SEL}})  , (REG_RDEN ? REG_A[9:5] : OP3_PIPE.SLOT), SCR_SA_Q);
	
	wire       SCR_LSA_SEL  = SCR_SEL & (REG_A[4:1] == 5'h04>>1) & REG_CS;
	bit [15:0] SCR_LSA_Q;
	SCSP_SPRAM SCR_LSA (CLK, REG_A[9:5], REG_D & LSA_MASK , (REG_WE & {2{SCR_LSA_SEL}}) , (REG_RDEN ? REG_A[9:5] : OP2_PIPE.SLOT), SCR_LSA_Q);
	
	wire       SCR_LEA_SEL  = SCR_SEL & (REG_A[4:1] == 5'h06>>1) & REG_CS;
	bit [15:0] SCR_LEA_Q;
	SCSP_SPRAM SCR_LEA (CLK, REG_A[9:5], REG_D & LEA_MASK , (REG_WE & {2{SCR_LEA_SEL}}) , (REG_RDEN ? REG_A[9:5] : OP2_PIPE.SLOT), SCR_LEA_Q);
	
	wire       SCR_SCR1_SEL = SCR_SEL & (REG_A[4:1] == 5'h08>>1) & REG_CS;
	bit [15:0] SCR_SCR1_Q;
	SCSP_SPRAM SCR_SCR1(CLK, REG_A[9:5], REG_D & SCR1_MASK, (REG_WE & {2{SCR_SCR1_SEL}}), (REG_RDEN ? REG_A[9:5] : OP4_PIPE.SLOT), SCR_SCR1_Q);
	
	wire       SCR_SCR2_SEL = SCR_SEL & (REG_A[4:1] == 5'h0A>>1) & REG_CS;
	bit [15:0] SCR_SCR2_Q;
	SCSP_SPRAM SCR_SCR2(CLK, REG_A[9:5], REG_D & SCR2_MASK, (REG_WE & {2{SCR_SCR2_SEL}}), (REG_RDEN ? REG_A[9:5] : OP4_PIPE.SLOT), SCR_SCR2_Q);
	
	wire       SCR_SCR3_SEL = SCR_SEL & (REG_A[4:1] == 5'h0C>>1) & REG_CS;
	bit [15:0] SCR_SCR3_Q;
	SCSP_SPRAM SCR_SCR3(CLK, REG_A[9:5], REG_D & SCR3_MASK, (REG_WE & {2{SCR_SCR3_SEL}}), (REG_RDEN ? REG_A[9:5] : OP5_PIPE.SLOT), SCR_SCR3_Q);
	
	wire       SCR_SCR4_SEL = SCR_SEL & (REG_A[4:1] == 5'h0E>>1) & REG_CS;
	bit [15:0] SCR_SCR4_Q;
	SCSP_SPRAM SCR_SCR4(CLK, REG_A[9:5], REG_D & SCR4_MASK, (REG_WE & {2{SCR_SCR4_SEL}}), (REG_RDEN ? REG_A[9:5] : OP2_PIPE.SLOT), SCR_SCR4_Q);
	
	wire       SCR_SCR5_SEL = SCR_SEL & (REG_A[4:1] == 5'h10>>1) & REG_CS;
	bit [15:0] SCR_SCR5_Q;
	SCSP_SPRAM SCR_SCR5(CLK, REG_A[9:5], REG_D & SCR5_MASK, (REG_WE & {2{SCR_SCR5_SEL}}), (REG_RDEN ? REG_A[9:5] :          SLOT), SCR_SCR5_Q);
	
	wire       SCR_SCR6_SEL = SCR_SEL & (REG_A[4:1] == 5'h12>>1) & REG_CS;
	bit [15:0] SCR_SCR6_Q;
	SCSP_SPRAM SCR_SCR6(CLK, REG_A[9:5], REG_D & SCR6_MASK, (REG_WE & {2{SCR_SCR6_SEL}}), (REG_RDEN ? REG_A[9:5] :          SLOT), SCR_SCR6_Q);
	
	wire       SCR_SCR7_SEL = SCR_SEL & (REG_A[4:1] == 5'h14>>1) & REG_CS;
	bit [15:0] SCR_SCR7_Q;
	SCSP_SPRAM SCR_SCR7(CLK, REG_A[9:5], REG_D & SCR7_MASK, (REG_WE & {2{SCR_SCR7_SEL}}), (REG_RDEN ? REG_A[9:5] :          SLOT), SCR_SCR7_Q);
	
	wire       SCR_SCR8_SEL = SCR_SEL & (REG_A[4:1] == 5'h16>>1) & REG_CS;
	bit [15:0] SCR_SCR8_Q;
	SCSP_SPRAM SCR_SCR8(CLK, REG_A[9:5], REG_D & SCR8_MASK, (REG_WE & {2{SCR_SCR8_SEL}}), (REG_RDEN ? REG_A[9:5] : OP7_PIPE.SLOT), SCR_SCR8_Q);
	
	//STACK,100600-10067F
	wire       SOUS_SEL = REG_A[11:7] == 5'b01100 & REG_CS;
	bit [15:0] STACK0X_Q,STACK0Y_Q,STACK1_Q;
	SCSP_SPRAM STACK1 (CLK, OP7_PIPE.SLOT, OP7_SD,   {2{SLOT_CE}}, OP7_PIPE.SLOT             , STACK1_Q);
	SCSP_SPRAM STACK0X(CLK, OP7_PIPE.SLOT, STACK1_Q, {2{SLOT_CE}}, OP2_PIPE.SLOT + SCR4.MDXSL, STACK0X_Q);
	SCSP_SPRAM STACK0Y(CLK, OP7_PIPE.SLOT, STACK1_Q, {2{SLOT_CE}}, OP2_PIPE.SLOT + SCR4.MDYSL, STACK0Y_Q);
	
	//COEF,100700-10077F
	wire       COEF_SEL = REG_A[11:7] == 5'b01110 & REG_CS;
	bit [15:0] COEF_RAM_Q;
//	SCSP_RAM_8X2 #(6) COEF_RAM (CLK, REG_A[6:1], REG_D & COEF_MASK, (REG_WE & {2{COEF_SEL}}), (REG_RDEN ? REG_A[6:1] : DSP_COEF_RA), COEF_RAM_Q);
	SCSP_COEF_RAM COEF_RAM (CLK, REG_A[6:1], REG_D & COEF_MASK, (REG_WE & {2{COEF_SEL}}), (REG_RDEN ? REG_A[6:1] : DSP_COEF_RA), COEF_RAM_Q);
	
	//MADRS,100780-1007BF
	wire       MADRS_SEL = REG_A[11:6] == 6'b011110 & REG_CS;
	bit [15:0] MADRS_RAM_Q;
//	SCSP_RAM_8X2 #(5) MADRS_RAM (CLK, REG_A[5:1], REG_D & MADRS_MASK, (REG_WE & {2{MADRS_SEL}}), (REG_RDEN ? REG_A[5:1] : DSP_MADRS_RA), MADRS_RAM_Q);
	SCSP_ADRS_RAM MADRS_RAM (CLK, REG_A[5:1], REG_D & MADRS_MASK, (REG_WE & {2{MADRS_SEL}}), (REG_RDEN ? REG_A[5:1] : DSP_MADRS_RA), MADRS_RAM_Q);
	
	//MPRO,100800-100BFF
	wire       MPRO_SEL = REG_A[11:10] == 2'b10;
	wire       MPRO0_SEL = MPRO_SEL & (REG_A[2:1] == 3'h0>>1) & REG_CS;
	wire       MPRO1_SEL = MPRO_SEL & (REG_A[2:1] == 3'h2>>1) & REG_CS;
	wire       MPRO2_SEL = MPRO_SEL & (REG_A[2:1] == 3'h4>>1) & REG_CS;
	wire       MPRO3_SEL = MPRO_SEL & (REG_A[2:1] == 3'h6>>1) & REG_CS;
	bit [63:0] MPRO_RAM_Q;
//	SCSP_BRAM_8X2 #(7) MPRO0_RAM (CLK, REG_A[9:3], REG_D & MPRO_MASK[63:48], (REG_WE & {2{MPRO0_SEL}}), (REG_RDEN ? REG_A[9:3] : DSP_MPRO_STEP), MPRO_RAM_Q[63:48]);
//	SCSP_BRAM_8X2 #(7) MPRO1_RAM (CLK, REG_A[9:3], REG_D & MPRO_MASK[47:32], (REG_WE & {2{MPRO1_SEL}}), (REG_RDEN ? REG_A[9:3] : DSP_MPRO_STEP), MPRO_RAM_Q[47:32]);
//	SCSP_BRAM_8X2 #(7) MPRO2_RAM (CLK, REG_A[9:3], REG_D & MPRO_MASK[31:16], (REG_WE & {2{MPRO2_SEL}}), (REG_RDEN ? REG_A[9:3] : DSP_MPRO_STEP), MPRO_RAM_Q[31:16]);
//	SCSP_BRAM_8X2 #(7) MPRO3_RAM (CLK, REG_A[9:3], REG_D & MPRO_MASK[15: 0], (REG_WE & {2{MPRO3_SEL}}), (REG_RDEN ? REG_A[9:3] : DSP_MPRO_STEP), MPRO_RAM_Q[15: 0]);
	SCSP_MPRO_RAM MPRO_RAM (CLK, REG_A[9:3], {4{REG_D}} & MPRO_MASK, ({4{REG_WE}} & {{2{MPRO0_SEL}},{2{MPRO1_SEL}},{2{MPRO2_SEL}},{2{MPRO3_SEL}}}), (REG_RDEN ? REG_A[9:3] : DSP_MPRO_STEP), MPRO_RAM_Q);
	
	//TEMP,100C00-100DFF
	wire       TEMP_SEL = REG_A[11:9] == 3'b110;
	wire       TEMP0_SEL = TEMP_SEL & (REG_A[1:1] == 2'h0>>1) & REG_CS;
	wire       TEMP1_SEL = TEMP_SEL & (REG_A[1:1] == 2'h2>>1) & REG_CS;
	bit [31:0] TEMP_RAM_Q;
//	SCSP_RAM_8X2 #(7) TEMP1_RAM (CLK, (REG_WREN ? REG_A[6:2] : DSP_TEMP_WA), (REG_WREN ? REG_D & TEMP_MASK[31:16] : DSP_TEMP_D), (REG_WE & {2{TEMP0_SEL}}) | {2{DSP_TEMP_WE&DSP_CE}}, (REG_RDEN ? REG_A[6:2] : DSP_TEMP_RA), TEMP_RAM_Q[31:16]);
//	SCSP_RAM_8X2 #(7) TEMP0_RAM (CLK, (REG_WREN ? REG_A[6:2] : DSP_TEMP_WA), (REG_WREN ? REG_D & TEMP_MASK[15: 0] : DSP_TEMP_D), (REG_WE & {2{TEMP1_SEL}}) | {2{DSP_TEMP_WE&DSP_CE}}, (REG_RDEN ? REG_A[6:2] : DSP_TEMP_RA), TEMP_RAM_Q[15: 0]);
	SCSP_TEMP_RAM TEMP_RAM (CLK, (REG_WREN ? REG_A[6:2] : DSP_TEMP_WA), (REG_WREN ? {2{REG_D}} & TEMP_MASK : {8'h00,DSP_TEMP_D}), ({2{REG_WE}} & {{2{TEMP0_SEL}},{2{TEMP1_SEL}}}) | {4{DSP_TEMP_WE&DSP_CE}}, (REG_RDEN ? REG_A[6:2] : DSP_TEMP_RA), TEMP_RAM_Q);
	
	//MEMS,100E00-100E7F
	wire       MEMS_SEL = REG_A[11:7] == 5'b11100;
	wire       MEMS0_SEL = MEMS_SEL & (REG_A[1:1] == 2'h0>>1) & REG_CS;
	wire       MEMS1_SEL = MEMS_SEL & (REG_A[1:1] == 2'h2>>1) & REG_CS;
	bit [31:0] MEMS_RAM_Q;
//	SCSP_RAM_8X2 #(5) MEMS1_RAM (CLK, (REG_WREN ? REG_A[6:2] : DSP_MEMS_WA), (REG_WREN ? REG_D & MEMS_MASK[31:16] : DSP_MEMS_D), (REG_WE & {2{MEMS0_SEL}}) | {2{DSP_MEMS_WE&DSP_CE}}, (REG_RDEN ? REG_A[6:2] : DSP_MEMS_RA), MEMS_RAM_Q[31:16]);
//	SCSP_RAM_8X2 #(5) MEMS0_RAM (CLK, (REG_WREN ? REG_A[6:2] : DSP_MEMS_WA), (REG_WREN ? REG_D & MEMS_MASK[15: 0] : DSP_MEMS_D), (REG_WE & {2{MEMS1_SEL}}) | {2{DSP_MEMS_WE&DSP_CE}}, (REG_RDEN ? REG_A[6:2] : DSP_MEMS_RA), MEMS_RAM_Q[15: 0]);
	SCSP_MEMS_RAM MEMS_RAM (CLK, (REG_WREN ? REG_A[6:2] : DSP_MEMS_WA), (REG_WREN ? {2{REG_D}} & MEMS_MASK : {8'h00,DSP_MEMS_D}), (REG_WE & {{2{MEMS0_SEL}},{2{MEMS1_SEL}}}) | {4{DSP_MEMS_WE&DSP_CE}}, (REG_RDEN ? REG_A[6:2] : DSP_MEMS_RA), MEMS_RAM_Q);
	
	//EFREG,100EC0-100EDF
	wire       EFREG_SEL = REG_A[11:5] == 7'b1110110 & REG_CS;
	bit [15:0] EFREG_RAM_Q;
	SCSP_RAM_8X2 #(4) EFREG_RAM (CLK, (REG_WREN ? REG_A[4:1] : DSP_EFREG_WA), (REG_WREN ? REG_D & EFREG_MASK : DSP_EFREG_D), (REG_WE & {2{EFREG_SEL}}) | {2{DSP_EFREG_WE&DSP_CE}}, (REG_RDEN ? REG_A[4:1] : DSP_EFREG_RA), EFREG_RAM_Q);
	
	
	
	
	bit [2:0] ILV;
	always_comb begin
		if      (CR12.SCIPD[10] & CR11.SCIEB[10]) ILV = {CR16.SCILV2[7],CR15.SCILV1[7],CR14.SCILV0[7]};
		else if (CR12.SCIPD[ 8] & CR11.SCIEB[ 8]) ILV = {CR16.SCILV2[7],CR15.SCILV1[7],CR14.SCILV0[7]};
		else if (CR12.SCIPD[ 7] & CR11.SCIEB[ 7]) ILV = {CR16.SCILV2[7],CR15.SCILV1[7],CR14.SCILV0[7]};
		else if (CR12.SCIPD[ 6] & CR11.SCIEB[ 6]) ILV = {CR16.SCILV2[6],CR15.SCILV1[6],CR14.SCILV0[6]};
		else if (CR12.SCIPD[ 5] & CR11.SCIEB[ 5]) ILV = {CR16.SCILV2[5],CR15.SCILV1[5],CR14.SCILV0[5]};
		else if (CR12.SCIPD[ 4] & CR11.SCIEB[ 4]) ILV = {CR16.SCILV2[4],CR15.SCILV1[4],CR14.SCILV0[4]};
		else                                      ILV = 3'b000;
	end
	
//	assign DO = MEM_Q;
	assign RDY_N = ~(SCU_RRDY & SCU_WRDY);
	assign INT_N = ~|(CR18.MCIPD & CR17.MCIEB);
	
	assign SCIPL_N = ~ILV;
//	assign SCDO = MEM_Q;
	assign SCAVEC_N = ~&SCFC;
	
`ifdef DEBUG
	assign SLOT_EN_DBG = SLOT_EN;
	assign SCA_DBG = {SCA,1'b0};
	assign SCR0_DBG_ = SCR0_;
	assign SCR0_DBG = SCR0;
	assign SA_DBG   = SA;
	assign LSA_DBG  = LSA;
	assign LEA_DBG  = LEA;
	assign SCR1_DBG = SCR1;
	assign SCR2_DBG = SCR2;
	assign SCR3_DBG = SCR3;
	assign SCR4_DBG = SCR4;
	assign SCR5_DBG = SCR5;
	assign SCR6_DBG = SCR6;
	assign SCR7_DBG = SCR7;
	assign SCR8_DBG = SCR8;
	assign ADP_DBG = ADP;
`endif
	
endmodule

module SCSP_SAO_RAM (
	input	         CLK,
	input	 [ 4: 0] WRADDR,
	input	 [26: 0] DATA,
	input	         WREN,
	input	 [ 4: 0] RDADDR,
	output [26: 0] Q);

	wire [26:0] sub_wire0;

	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RDADDR),
				.wraddress (WRADDR),
				.wren (WREN),
				.q (sub_wire0),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
				//.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.power_up_uninitialized = "TRUE",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 27,
		altdpram_component.widthad = 5,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
		
	assign Q = sub_wire0;

endmodule

module SCSP_EVOL_RAM (
	input	         CLK,
	input	 [ 4: 0] WRADDR,
	input	 [ 9: 0] DATA,
	input	         WREN,
	input	 [ 4: 0] RDADDR,
	output [ 9: 0] Q);

	wire [9:0] sub_wire0;

	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RDADDR),
				.wraddress (WRADDR),
				.wren (WREN),
				.q (sub_wire0),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
				//.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.power_up_uninitialized = "TRUE",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 10,
		altdpram_component.widthad = 5,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
		
	assign Q = sub_wire0;

endmodule

module SCSP_SPRAM
(
	input         CLK,
	
	input   [4:0] WADDR,
	input  [15:0] DATA,
	input   [1:0] WREN,
	input   [4:0] RADDR,
	output [15:0] Q
);

`ifdef SIM
	
	reg [15:0] MEM [32];
	
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WADDR] <= DATA;
		end
	end
		
	assign Q = MEM[RADDR];
	
`else

	wire [15:0] sub_wire0;
	
	altdpram	altdpram_component_l (
				.data (DATA[7:0]),
				.inclock (CLK),
				.rdaddress (RADDR),
				.wraddress (WADDR),
				.wren (WREN[0]),
				.q (sub_wire0[7:0]),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component_l.indata_aclr = "OFF",
		altdpram_component_l.indata_reg = "INCLOCK",
		altdpram_component_l.intended_device_family = "Cyclone V",
		altdpram_component_l.lpm_type = "altdpram",
		altdpram_component_l.outdata_aclr = "OFF",
		altdpram_component_l.outdata_reg = "UNREGISTERED",
		altdpram_component_l.ram_block_type = "MLAB",
		altdpram_component_l.rdaddress_aclr = "OFF",
		altdpram_component_l.rdaddress_reg = "UNREGISTERED",
		altdpram_component_l.rdcontrol_aclr = "OFF",
		altdpram_component_l.rdcontrol_reg = "UNREGISTERED",
		altdpram_component_l.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component_l.width = 8,
		altdpram_component_l.widthad = 5,
		altdpram_component_l.width_byteena = 1,
		altdpram_component_l.wraddress_aclr = "OFF",
		altdpram_component_l.wraddress_reg = "INCLOCK",
		altdpram_component_l.wrcontrol_aclr = "OFF",
		altdpram_component_l.wrcontrol_reg = "INCLOCK";
		
	altdpram	altdpram_component_h (
				.data (DATA[15:8]),
				.inclock (CLK),
				.rdaddress (RADDR),
				.wraddress (WADDR),
				.wren (WREN[1]),
				.q (sub_wire0[15:8]),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component_h.indata_aclr = "OFF",
		altdpram_component_h.indata_reg = "INCLOCK",
		altdpram_component_h.intended_device_family = "Cyclone V",
		altdpram_component_h.lpm_type = "altdpram",
		altdpram_component_h.outdata_aclr = "OFF",
		altdpram_component_h.outdata_reg = "UNREGISTERED",
		altdpram_component_h.ram_block_type = "MLAB",
		altdpram_component_h.rdaddress_aclr = "OFF",
		altdpram_component_h.rdaddress_reg = "UNREGISTERED",
		altdpram_component_h.rdcontrol_aclr = "OFF",
		altdpram_component_h.rdcontrol_reg = "UNREGISTERED",
		altdpram_component_h.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component_h.width = 8,
		altdpram_component_h.widthad = 5,
		altdpram_component_h.width_byteena = 1,
		altdpram_component_h.wraddress_aclr = "OFF",
		altdpram_component_h.wraddress_reg = "INCLOCK",
		altdpram_component_h.wrcontrol_aclr = "OFF",
		altdpram_component_h.wrcontrol_reg = "INCLOCK";
	
	assign Q = sub_wire0;
	
`endif
	
endmodule

module SCSP_RAM_8X2
#(
	parameter addr_width = 5
)
(
	input         CLK,
	
	input  [addr_width-1:0] WADDR,
	input            [15:0] DATA,
	input             [1:0] WREN,
	input  [addr_width-1:0] RADDR,
	output           [15:0] Q
);

`ifdef SIM
	
	reg [15:0] MEM [1**addr_width];
	
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WADDR] <= DATA;
		end
	end
		
	assign Q = MEM[RADDR];
	
`else

	wire [15:0] sub_wire0;
	
	altdpram	altdpram_component_l (
				.data (DATA[7:0]),
				.inclock (CLK),
				.rdaddress (RADDR),
				.wraddress (WADDR),
				.wren (WREN[0]),
				.q (sub_wire0[7:0]),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component_l.indata_aclr = "OFF",
		altdpram_component_l.indata_reg = "INCLOCK",
		altdpram_component_l.intended_device_family = "Cyclone V",
		altdpram_component_l.lpm_type = "altdpram",
		altdpram_component_l.outdata_aclr = "OFF",
		altdpram_component_l.outdata_reg = "UNREGISTERED",
		altdpram_component_l.ram_block_type = "MLAB",
		altdpram_component_l.rdaddress_aclr = "OFF",
		altdpram_component_l.rdaddress_reg = "UNREGISTERED",
		altdpram_component_l.rdcontrol_aclr = "OFF",
		altdpram_component_l.rdcontrol_reg = "UNREGISTERED",
		altdpram_component_l.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component_l.width = 8,
		altdpram_component_l.widthad = addr_width,
		altdpram_component_l.width_byteena = 1,
		altdpram_component_l.wraddress_aclr = "OFF",
		altdpram_component_l.wraddress_reg = "INCLOCK",
		altdpram_component_l.wrcontrol_aclr = "OFF",
		altdpram_component_l.wrcontrol_reg = "INCLOCK";
		
	altdpram	altdpram_component_h (
				.data (DATA[15:8]),
				.inclock (CLK),
				.rdaddress (RADDR),
				.wraddress (WADDR),
				.wren (WREN[1]),
				.q (sub_wire0[15:8]),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component_h.indata_aclr = "OFF",
		altdpram_component_h.indata_reg = "INCLOCK",
		altdpram_component_h.intended_device_family = "Cyclone V",
		altdpram_component_h.lpm_type = "altdpram",
		altdpram_component_h.outdata_aclr = "OFF",
		altdpram_component_h.outdata_reg = "UNREGISTERED",
		altdpram_component_h.ram_block_type = "MLAB",
		altdpram_component_h.rdaddress_aclr = "OFF",
		altdpram_component_h.rdaddress_reg = "UNREGISTERED",
		altdpram_component_h.rdcontrol_aclr = "OFF",
		altdpram_component_h.rdcontrol_reg = "UNREGISTERED",
		altdpram_component_h.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component_h.width = 8,
		altdpram_component_h.widthad = addr_width,
		altdpram_component_h.width_byteena = 1,
		altdpram_component_h.wraddress_aclr = "OFF",
		altdpram_component_h.wraddress_reg = "INCLOCK",
		altdpram_component_h.wrcontrol_aclr = "OFF",
		altdpram_component_h.wrcontrol_reg = "INCLOCK";
	
	assign Q = sub_wire0;
	
`endif
	
endmodule

module SCSP_COEF_RAM
(
	input          CLK,
	
	input  [ 5: 0] WADDR,
	input  [15: 0] DATA,
	input  [ 1: 0] WREN,
	input  [ 5: 0] RADDR,
	output [15: 0] Q
);

`ifdef SIM
	
	reg [15:0] MEM [64];
	
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WADDR] <= DATA;
		end
	end
		
	assign Q = MEM[RADDR];
	
`else

	wire [15:0] sub_wire0;
	
	altsyncram	altsyncram_component (
				.address_a (WADDR),
				.byteena_a (WREN),
				.clock0 (CLK),
				.data_a (DATA),
				.wren_a (|WREN),
				.address_b (RADDR),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({16{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 64,
		altsyncram_component.numwords_b = 64,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = 6,
		altsyncram_component.widthad_b = 6,
		altsyncram_component.width_a = 16,
		altsyncram_component.width_b = 16,
		altsyncram_component.width_byteena_a = 2;
	
	assign Q = sub_wire0;
	
`endif
	
endmodule

module SCSP_ADRS_RAM
(
	input          CLK,
	
	input  [ 4: 0] WADDR,
	input  [15: 0] DATA,
	input  [ 1: 0] WREN,
	input  [ 4: 0] RADDR,
	output [15: 0] Q
);

`ifdef SIM
	
	reg [15:0] MEM [32];
	
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WADDR] <= DATA;
		end
	end
		
	assign Q = MEM[RADDR];
	
`else

	wire [15:0] sub_wire0;
	
	altsyncram	altsyncram_component (
				.address_a (WADDR),
				.byteena_a (WREN),
				.clock0 (CLK),
				.data_a (DATA),
				.wren_a (|WREN),
				.address_b (RADDR),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({16{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 32,
		altsyncram_component.numwords_b = 32,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = 5,
		altsyncram_component.widthad_b = 5,
		altsyncram_component.width_a = 16,
		altsyncram_component.width_b = 16,
		altsyncram_component.width_byteena_a = 2;
	
	assign Q = sub_wire0;
	
`endif
	
endmodule

module SCSP_TEMP_RAM
(
	input          CLK,
	
	input  [ 6: 0] WADDR,
	input  [31: 0] DATA,
	input  [ 3: 0] WREN,
	input  [ 6: 0] RADDR,
	output [31: 0] Q
);

`ifdef SIM
	
	reg [31:0] MEM [128];
	
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WADDR] <= DATA;
		end
	end
		
	assign Q = MEM[RADDR];
	
`else

	wire [31:0] sub_wire0;
	
	altsyncram	altsyncram_component (
				.address_a (WADDR),
				.byteena_a (WREN),
				.clock0 (CLK),
				.data_a (DATA),
				.wren_a (|WREN),
				.address_b (RADDR),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({32{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 128,
		altsyncram_component.numwords_b = 128,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = 7,
		altsyncram_component.widthad_b = 7,
		altsyncram_component.width_a = 32,
		altsyncram_component.width_b = 32,
		altsyncram_component.width_byteena_a = 4;
	
	assign Q = sub_wire0;
	
`endif
	
endmodule

module SCSP_MEMS_RAM
(
	input          CLK,
	
	input  [ 4: 0] WADDR,
	input  [31: 0] DATA,
	input  [ 3: 0] WREN,
	input  [ 4: 0] RADDR,
	output [31: 0] Q
);

`ifdef SIM
	
	reg [31:0] MEM [32];
	
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WADDR] <= DATA;
		end
	end
		
	assign Q = MEM[RADDR];
	
`else

	wire [31:0] sub_wire0;
	
	altsyncram	altsyncram_component (
				.address_a (WADDR),
				.byteena_a (WREN),
				.clock0 (CLK),
				.data_a (DATA),
				.wren_a (|WREN),
				.address_b (RADDR),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({32{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 32,
		altsyncram_component.numwords_b = 32,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = 5,
		altsyncram_component.widthad_b = 5,
		altsyncram_component.width_a = 32,
		altsyncram_component.width_b = 32,
		altsyncram_component.width_byteena_a = 4;
	
	assign Q = sub_wire0;
	
`endif
	
endmodule


module SCSP_MPRO_RAM
(
	input         CLK,
	
	input  [6:0] WADDR,
	input            [63:0] DATA,
	input             [7:0] WREN,
	input  [6:0] RADDR,
	output           [63:0] Q
);

`ifdef SIM
	
	reg [63:0] MEM [128];
	
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WADDR] <= DATA;
		end
	end
		
	assign Q = MEM[RADDR];
	
`else

	wire [63:0] sub_wire0;
	
	altsyncram	altsyncram_component (
				.address_a (WADDR),
				.byteena_a (WREN),
				.clock0 (CLK),
				.data_a (DATA),
				.wren_a (|WREN),
				.address_b (RADDR),
				.q_b (sub_wire0),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({64{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.address_aclr_b = "NONE",
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 128,
		altsyncram_component.numwords_b = 128,
		altsyncram_component.operation_mode = "DUAL_PORT",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.ram_block_type = "M10K",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.widthad_a = 7,
		altsyncram_component.widthad_b = 7,
		altsyncram_component.width_a = 64,
		altsyncram_component.width_b = 64,
		altsyncram_component.width_byteena_a = 8;
	
	assign Q = sub_wire0;
	
`endif
	
endmodule
