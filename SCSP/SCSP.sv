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
	input       [1:0] WE_N,
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
	input             RAM_RDY,
	
	output     [15:0] SOUND_L,
	output     [15:0] SOUND_R,
	
	output     [23:0] SCA_DBG,
	output      [9:0] EVOL_DBG
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
	STACK_t    STACK0;
	STACK_t    STACK1;
	
	bit [19:0] ADP;
	bit        WD_READ;
	bit [15:0] MEM_WD;

	
	typedef enum bit [6:0] {
		MS_IDLE     = 7'b0000001,  
		MS_WD_WAIT  = 7'b0000010, 
		MS_DMA_WAIT = 7'b0000100, 
		MS_SCU_WAIT = 7'b0001000, 
		MS_SCPU_WAIT= 7'b0010000,
		MS_SCPU_END = 7'b0100000,
		MS_END      = 7'b1000000
	} MemState_t;
	MemState_t MEM_ST;
	
	bit [20:1] MEM_A;
	bit [15:0] MEM_D;
	bit [15:0] MEM_Q;
	bit  [1:0] MEM_WE;
	bit        MEM_RD;
	bit        MEM_CS;
	
	bit        REG_CS;
	bit [15:0] REG_Q;
	bit        REG_RDY;
	
	bit [19:1] DMA_MA;
	bit [11:1] DMA_RA;
	bit [10:0] DMA_LEN;
	bit [15:0] DMA_DAT;
	bit        DMA_WR;
	bit        DMA_EXEC;
	
	bit [20:0] SCU_A;
	
	bit  [1:0] CLK_CNT;
	always @(posedge CLK) if (CE) CLK_CNT <= CLK_CNT + 2'd1;
	assign SCCE_R =  CLK_CNT[0] & CE;
	assign SCCE_F = ~CLK_CNT[0] & CE;
	
	bit        CYCLE_CE;
	bit        SLOT_CE;
	bit        SAMPLE_CE;
	
	assign CYCLE_CE = &CLK_CNT & CE;
	
	bit  [6:0] CYCLE_NUM;
	always @(posedge CLK) if (CYCLE_CE) CYCLE_NUM <= CYCLE_NUM + 7'd1;
	
	assign SLOT_CE = (CYCLE_NUM[1:0] == 2'b00) & CYCLE_CE;
	
	
	OPPipe_t    OP2_PIPE;
	OPPipe_t    OP3_PIPE;
	OPPipe_t    OP4_PIPE;
	OPPipe_t    OP5_PIPE;
	OPPipe_t    OP6_PIPE;
	OPPipe_t    OP7_PIPE;
	
	//Operation 1: PG, KEY ON/OFF
	wire KYONEX_SET = REG_CS & (MEM_A[11:10] == 2'b00) & (MEM_A[4:1] == 4'b0000) & MEM_D[12] & MEM_WE[1];
	bit        KEYON[32];
	bit [25:0] PHASE;
	always @(posedge CLK or negedge RST_N) begin
		bit       KYONEX;
		bit       KEYON_OLD[32];
		bit [4:0] SLOT;
		
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
			end else if (KYONEX && SLOT_CE) begin
				for (int i=0; i<32; i++) begin
					KEYON[i] <= SCR[i].SCR0.KB;
				end
				KYONEX <= 0;
			end
			
			if (SLOT_CE) begin
				PHASE <= PhaseCalc(SCR[SLOT].SCR5);
				
				KEYON_OLD[SLOT] <= KEYON[SLOT];
				SLOT <= SLOT + 5'd1;
				
				OP2_PIPE.SLOT <= SLOT;
				OP2_PIPE.KON <= KEYON[SLOT] & ~KEYON_OLD[SLOT];
				OP2_PIPE.KOFF <= ~KEYON[SLOT] & KEYON_OLD[SLOT];
			end
		end
	end
	
	//Operation 2: MD read, ADP
	OP2State_t OP2_STATE[32];
	bit [15:0] SA[32];//Sample address offset integer
	bit  [9:0] SAF[32];//Sample address offset fractional
//	bit [17:0] PHASE_ACC[32];
	always @(posedge CLK or negedge RST_N) begin
		bit [ 4:0] S;
		bit [17:0] NEW_PHASE_FRAC;
		bit [15:0] NEW_PHASE_INT;
		bit [15:0] NEW_SA_INT;
		bit  [9:0] NEW_SA_FRAC;
		bit [15:0] LL;
		
		if (!RST_N) begin
			WD_READ <= 0;
			SA <= '{32{'0}};
			SAF <= '{32{'0}};
			OP3_PIPE <= OP_PIPE_RESET;
		end
		else begin
			S = OP2_PIPE.SLOT;
			
//			{NEW_PHASE_INT,NEW_PHASE_FRAC} = {16'h0000,PHASE_ACC[S]} + PHASE;
			
			LL = SCR[S].LEA - SCR[S].LSA;
			
			{NEW_SA_INT,NEW_SA_FRAC} = {SA[S],SAF[S]} + PHASE + {OP3_MD,10'h000};
			
			WD_READ <= 0;
			if (SLOT_CE) begin
				if (EVOL[S] != 10'h3FF) begin
//					PHASE_ACC[S] <= NEW_PHASE_FRAC;
					
					if (NEW_SA_INT >= SCR[S].LEA) begin
						{SA[S],SAF[S]} <= {NEW_SA_INT - LL,NEW_SA_FRAC};//{SCR[S].LSA,10'h000};
					end else begin
						{SA[S],SAF[S]} <= {NEW_SA_INT,NEW_SA_FRAC};
					end
					WD_READ <= 1;
				end
				if (OP2_PIPE.KON) begin
					{SA[S],SAF[S]} <= '0;
				end
				
				OP3_MD <= '0;//MDCalc(STACK0, SCR[S].SCR4);
				OP3_PIPE <= OP2_PIPE;
			end
		end
	end
	
	//Operation 3:  
	bit [15:0] OP3_MD;	//Modulation data
	always @(posedge CLK or negedge RST_N) begin
//		bit [ 4:0] S;
		
		if (!RST_N) begin
			OP4_PIPE <= OP_PIPE_RESET;
			OP4_WD <= '0;
		end
		else begin
//			S = OP3_PIPE.SLOT;
			
			if (SLOT_CE) begin
				OP4_WD <= MEM_WD;
				OP4_PIPE <= OP3_PIPE;
			end
		end
	end
	assign ADP = {SCR[OP3_PIPE.SLOT].SCR0.SAH,SCR[OP3_PIPE.SLOT].SA} + {3'b000,SA[OP3_PIPE.SLOT],1'b0};
	
	//Operation 4: EG
	bit  [9:0] EVOL[32]; //Envelope level
	EGState_t  EGST[32]; //Envelope state
	bit [15:0] OP4_WD; //Wave form data
	always @(posedge CLK or negedge RST_N) begin
		bit [10:0] VOL_NEXT;
		bit [ 4:0] S;
		
		if (!RST_N) begin
			OP5_PIPE <= OP_PIPE_RESET;
			EVOL <= '{32{'1}};
			EGST <= '{32{EGS_RELEASE}};
		end
		else begin
			S = OP4_PIPE.SLOT;
			if (SLOT_CE) begin
				case (EGST[S])
					EGS_ATTACK: begin
						VOL_NEXT = EVOL[S] - {SCR[S].SCR2.AR,5'b11111} + 11'd1;
						if (!VOL_NEXT[10]) begin
							EVOL[S] <= VOL_NEXT[9:0];
						end else begin
							EVOL[S] <= 10'h000;
							EGST[S] <= EGS_DECAY1;
						end
						if (OP4_PIPE.KOFF) EGST[S] <= EGS_RELEASE;
					end
					
					EGS_DECAY1: begin
						VOL_NEXT = EVOL[S] + {SCR[S].SCR2.D1R,5'b00000};
						if (VOL_NEXT[9:5] < SCR[S].SCR1.DL) begin
							EVOL[S] <= VOL_NEXT[9:0];
						end else begin
							EVOL[S] <= VOL_NEXT[9:0];//{SCR[S].SCR1.DL,5'b00000};
							EGST[S] <= EGS_DECAY2;
						end
						if (OP4_PIPE.KOFF) EGST[S] <= EGS_RELEASE;
					end
					
					EGS_DECAY2: begin
						VOL_NEXT = EVOL[S] + {SCR[S].SCR2.D2R,5'b00000};
						if (!VOL_NEXT[10]) begin
							EVOL[S] <= VOL_NEXT[9:0];
						end else begin
							EVOL[S] <= 10'h3FF;
						end
						if (OP4_PIPE.KOFF) EGST[S] <= EGS_RELEASE;
					end
					
					EGS_RELEASE: begin
						VOL_NEXT = EVOL[S] + {SCR[S].SCR1.RR,5'b00000};
						if (!VOL_NEXT[10]) begin
							EVOL[S] <= VOL_NEXT[9:0];
						end else begin
							EVOL[S] <= 10'h3FF;
						end
						if (OP4_PIPE.KON) begin
							EVOL[S] <= 10'h3FF;
							EGST[S] <= EGS_ATTACK;
						end
					end
				endcase
				
				OP5_WD <= OP4_WD;
				OP5_PIPE <= OP4_PIPE;
			end
		end
	end
	
	//Operation 5: Level calculation
	bit [15:0] OP5_WD; //Wave form data
	always @(posedge CLK or negedge RST_N) begin
		bit [ 4:0] S;
		bit [ 7:0] TL;
		bit [15:0] TEMP;
		
		if (!RST_N) begin
			OP6_PIPE <= OP_PIPE_RESET;
			OP6_SD <= '0;
		end
		else begin
			S = OP5_PIPE.SLOT;
			TL = SCR[S].SCR3.TL;
			if (SLOT_CE) begin
				TEMP = VolCalc(OP5_WD, TL);
				OP6_SD <= EVOL[S] != 10'h3FF ? TEMP : '0;
				OP6_PIPE <= OP5_PIPE;
			end
//			EVOL_DBG <= TEMP;
		end
	end
	
	//Operation 6: Level calculation
	bit [15:0] OP6_SD;	//Slot out data
	always @(posedge CLK or negedge RST_N) begin
		bit [ 4:0] S;
		bit [25:0] TEMP;
		
		if (!RST_N) begin
			OP7_PIPE <= OP_PIPE_RESET;
		end
		else begin
			S = OP6_PIPE.SLOT;
			if (SLOT_CE) begin
				TEMP = $signed(OP6_SD) * (10'h3FF-EVOL[S]);
				OP7_SD <= TEMP[25:10];
				OP7_PIPE <= OP6_PIPE;
			end
		end
	end
	
	//Operation 7: Stack save
	bit [15:0] OP7_SD;
	bit [15:0] DIR_ACC_L,DIR_ACC_R;
	bit        DIR_OUT;
	always @(posedge CLK or negedge RST_N) begin
		bit [ 4:0] S;
		
		if (!RST_N) begin
//			DIR_OUT <= 0;
		end
		else begin
			S = OP7_PIPE.SLOT;
			
			if (SLOT_CE) begin
				if (S == 5'd0) begin
					DIR_ACC_L <= {{2{OP7_SD[15]}},OP7_SD[15:2]};
					DIR_ACC_R <= {{2{OP7_SD[15]}},OP7_SD[15:2]};
				end else begin
					DIR_ACC_L <= DIR_ACC_L + {{2{OP7_SD[15]}},OP7_SD[15:2]};
					DIR_ACC_R <= DIR_ACC_R + {{2{OP7_SD[15]}},OP7_SD[15:2]};
				end
			end
		end
	end
	assign SAMPLE_CE = (OP7_PIPE.SLOT == 5'd0) & SLOT_CE;
	
	//Direct out
	bit [15:0] DIR_L,DIR_R;
	always @(posedge CLK or negedge RST_N) begin
		
		
		if (!RST_N) begin
			DIR_L <= '0;
			DIR_R <= '0;
		end
		else begin
			if (SAMPLE_CE) begin
				DIR_L <= DIR_ACC_L;
				DIR_R <= DIR_ACC_R;
			end
		end
	end
	assign SOUND_L = DIR_L;
	assign SOUND_R = DIR_R;
	
	
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
				if (MEM_ST == MS_END) begin
					DMA_WR <= ~DMA_WR;
					if (!DMA_WR) begin
						DMA_MA <= DMA_MA + 19'd1;
						DMA_DAT <= MEM_Q;
					end else begin
						DMA_RA <= DMA_RA + 11'd1;
						DMA_LEN <= DMA_LEN - 11'd1;
						if (!DMA_LEN) DMA_EXEC <= 0;
					end
				end
			end
		end
	end
	
	//RAM access
	wire SCU_SEL = ~DTEN_N & ~AD_N & ~CS_N;	//25A00000-25BFFFFF
	bit SCU_PEND;
	bit WD_PEND;
	always @(posedge CLK or negedge RST_N) begin
		bit SCU_SEL_OLD;
		bit WD_READ_OLD;
		
		if (!RST_N) begin
			MEM_ST <= MS_IDLE;
			MEM_A <= '0;
			MEM_D <= '0;
			MEM_WE <= '0;
			MEM_RD <= 0;
			SCU_A <= '0;
			SCDTACK_N <= 1;
			SCU_PEND <= 0;
			WD_PEND <= 0;
		end
		else begin
			if (!CS_N && DTEN_N && AD_N && CE_R) begin
				SCU_A <= {SCU_A[4:0],DI};
			end
			
			SCU_SEL_OLD <= SCU_SEL;
			if (SCU_SEL && !SCU_SEL_OLD && !SCU_PEND && CE_F) SCU_PEND <= 1;
			
			WD_READ_OLD <= WD_READ;
			if (WD_READ && !WD_READ_OLD && !WD_PEND) WD_PEND <= 1;
			
			case (MEM_ST)
				MS_IDLE: begin
					if (WD_PEND) begin
						MEM_A <= {2'b00,ADP[18:1]};
						MEM_D <= '0;
						MEM_WE <= '0;
						MEM_RD <= 1;
						MEM_CS <= 1;
						REG_CS <= 0;
						MEM_ST <= MS_WD_WAIT;
					end else if (DMA_EXEC) begin
						if (DMA_WR) begin
							MEM_A <= {2'b00,DMA_MA[18:1]};
							MEM_D <= '0;
							MEM_WE <= '0;
							MEM_RD <= 1;
							MEM_CS <= 1;
							REG_CS <= 0;
						end else begin
							MEM_A <= {9'b100000000,DMA_RA};
							MEM_D <= DMA_DAT;
							MEM_WE <= '1;
							MEM_RD <= 0;
							MEM_CS <= 0;
							REG_CS <= 1;
						end
						MEM_ST <= MS_DMA_WAIT;
					end else if (SCU_PEND) begin
						MEM_A <= SCU_A[20:1];
						MEM_D <= DI;
						MEM_WE <= ~WE_N;
						MEM_RD <= &WE_N;
						MEM_CS <= ~SCU_A[20];
						REG_CS <= SCU_A[20];
						MEM_ST <= MS_SCU_WAIT;
					end else if (!SCAS_N && (!SCLDS_N || !SCUDS_N) && SCDTACK_N /*&& SCCE_F*/) begin
						MEM_A <= SCA[20:1];
						MEM_D <= SCDI;
						MEM_WE <= {~SCRW_N&~SCUDS_N,~SCRW_N&~SCLDS_N};
						MEM_RD <= SCRW_N;
						MEM_CS <= ~SCA[20];
						REG_CS <= SCA[20];
						MEM_ST <= MS_SCPU_WAIT;
					end
				end
				
				MS_WD_WAIT: begin
					if (MEM_CS && RAM_RDY) begin
						WD_PEND <= 0;
						MEM_WD <= RAM_Q;
						MEM_WE <= '0;
						MEM_RD <= 0;
						MEM_CS <= 0;
						MEM_ST <= MS_END;
					end
				end
				
				MS_DMA_WAIT: begin
					if (MEM_CS && RAM_RDY) begin
						MEM_Q <= RAM_Q;
						MEM_WE <= '0;
						MEM_RD <= 0;
						MEM_CS <= 0;
						MEM_ST <= MS_END;
					end else if (REG_CS && REG_RDY) begin
						MEM_Q <= REG_Q;
						MEM_WE <= '0;
						MEM_RD <= 0;
						REG_CS <= 0;
						MEM_ST <= MS_END;
					end
				end
				
				MS_SCPU_WAIT: begin
					if (MEM_CS && RAM_RDY) begin
						SCDTACK_N <= 0;
						MEM_Q <= RAM_Q;
						MEM_WE <= '0;
						MEM_RD <= 0;
						MEM_CS <= 0;
						MEM_ST <= MS_SCPU_END;
					end else if (REG_CS && REG_RDY) begin
						SCDTACK_N <= 0;
						MEM_Q <= REG_Q;
						MEM_WE <= '0;
						MEM_RD <= 0;
						REG_CS <= 0;
						MEM_ST <= MS_SCPU_END;
					end
				end
				
				MS_SCPU_END: begin
					if (SCAS_N) begin
						SCDTACK_N <= 1;
						MEM_ST <= MS_IDLE;
					end
				end
				
				MS_SCU_WAIT: begin
					if (MEM_CS && RAM_RDY) begin
						MEM_Q <= RAM_Q;
						MEM_WE <= '0;
						MEM_RD <= 0;
						MEM_CS <= 0;
						SCU_PEND <= 0;
						MEM_ST <= MS_END;
//						if (MEM_A == 20'h00700>>1) MEM_Q[15:8] <= '0;
					end else if (REG_CS && REG_RDY) begin
						MEM_Q <= REG_Q;
						MEM_WE <= '0;
						MEM_RD <= 0;
						REG_CS <= 0;
						SCU_PEND <= 0;
						MEM_ST <= MS_END;
					end
				end
				
				MS_END: begin
					if (CYCLE_CE) MEM_ST <= MS_IDLE;
				end
				
				default:;
			endcase
			
		end
	end
	
	assign RAM_A = MEM_A[18:1];
	assign RAM_D = MEM_D;
	assign RAM_WE = MEM_WE;
	assign RAM_RD = MEM_RD;
	assign RAM_CS = MEM_CS;
	
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
//			STACK0 <= '{32{'0}};
//			STACK1 <= '{32{'0}};
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
//				STACK0 <= '{32{'0}};
//				STACK1 <= '{32{'0}};
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
				if (MEM_WE && REG_CS) begin
					if (MEM_A[11:10] == 2'b00) begin
						for (int i=0; i<32; i++) begin
							if (MEM_A[9:5] == i) begin
								case ({MEM_A[4:1],1'b0})
									5'h00: begin
										if (MEM_WE[0]) SCR[i].SCR0[ 7:0] <= MEM_D[ 7:0] & SCR0_MASK[ 7:0];
										if (MEM_WE[1]) SCR[i].SCR0[15:8] <= MEM_D[15:8] & SCR0_MASK[15:8];
									end
									5'h02: begin
										if (MEM_WE[0]) SCR[i].SA[ 7:0] <= MEM_D[ 7:0] & SA_MASK[ 7:0];
										if (MEM_WE[1]) SCR[i].SA[15:8] <= MEM_D[15:8] & SA_MASK[15:8];
									end
									5'h04: begin
										if (MEM_WE[0]) SCR[i].LSA[ 7:0] <= MEM_D[ 7:0] & LSA_MASK[ 7:0];
										if (MEM_WE[1]) SCR[i].LSA[15:8] <= MEM_D[15:8] & LSA_MASK[15:8];
									end
									5'h06: begin
										if (MEM_WE[0]) SCR[i].LEA[ 7:0] <= MEM_D[ 7:0] & LEA_MASK[ 7:0];
										if (MEM_WE[1]) SCR[i].LEA[15:8] <= MEM_D[15:8] & LEA_MASK[15:8];
									end
									5'h08: begin
										if (MEM_WE[0]) SCR[i].SCR1[ 7:0] <= MEM_D[ 7:0] & SCR1_MASK[ 7:0];
										if (MEM_WE[1]) SCR[i].SCR1[15:8] <= MEM_D[15:8] & SCR1_MASK[15:8];
									end
									5'h0A: begin
										if (MEM_WE[0]) SCR[i].SCR2[ 7:0] <= MEM_D[ 7:0] & SCR2_MASK[ 7:0];
										if (MEM_WE[1]) SCR[i].SCR2[15:8] <= MEM_D[15:8] & SCR2_MASK[15:8];
									end
									5'h0C: begin
										if (MEM_WE[0]) SCR[i].SCR3[ 7:0] <= MEM_D[ 7:0] & SCR3_MASK[ 7:0];
										if (MEM_WE[1]) SCR[i].SCR3[15:8] <= MEM_D[15:8] & SCR3_MASK[15:8];
									end
									5'h0E: begin
										if (MEM_WE[0]) SCR[i].SCR4[ 7:0] <= MEM_D[ 7:0] & SCR4_MASK[ 7:0];
										if (MEM_WE[1]) SCR[i].SCR4[15:8] <= MEM_D[15:8] & SCR4_MASK[15:8];
									end
									5'h10: begin
										if (MEM_WE[0]) SCR[i].SCR5[ 7:0] <= MEM_D[ 7:0] & SCR5_MASK[ 7:0];
										if (MEM_WE[1]) SCR[i].SCR5[15:8] <= MEM_D[15:8] & SCR5_MASK[15:8];
									end
									5'h12: begin
										if (MEM_WE[0]) SCR[i].SCR6[ 7:0] <= MEM_D[ 7:0] & SCR6_MASK[ 7:0];
										if (MEM_WE[1]) SCR[i].SCR6[15:8] <= MEM_D[15:8] & SCR6_MASK[15:8];
									end
									5'h14: begin
										if (MEM_WE[0]) SCR[i].SCR7[ 7:0] <= MEM_D[ 7:0] & SCR7_MASK[ 7:0];
										if (MEM_WE[1]) SCR[i].SCR7[15:8] <= MEM_D[15:8] & SCR7_MASK[15:8];
									end
									5'h16: begin
										if (MEM_WE[0]) SCR[i].SCR8[ 7:0] <= MEM_D[ 7:0] & SCR8_MASK[ 7:0];
										if (MEM_WE[1]) SCR[i].SCR8[15:8] <= MEM_D[15:8] & SCR8_MASK[15:8];
									end
									default:;
								endcase
							end
						end
					end else if (MEM_A[11:9] == 3'b010) begin
						case ({MEM_A[5:1],1'b0})
							6'h00: begin
								if (MEM_WE[0]) CR0[ 7:0] <= MEM_D[ 7:0] & CR0_MASK[ 7:0];
								if (MEM_WE[1]) CR0[15:8] <= MEM_D[15:8] & CR0_MASK[15:8];
							end
							6'h02: begin
								if (MEM_WE[0]) CR1[ 7:0] <= MEM_D[ 7:0] & CR1_MASK[ 7:0];
								if (MEM_WE[1]) CR1[15:8] <= MEM_D[15:8] & CR1_MASK[15:8];
							end
							6'h04: begin
								if (MEM_WE[0]) CR2[ 7:0] <= MEM_D[ 7:0] & CR2_MASK[ 7:0];
								if (MEM_WE[1]) CR2[15:8] <= MEM_D[15:8] & CR2_MASK[15:8];
							end
							6'h06: begin
								if (MEM_WE[0]) CR3[ 7:0] <= MEM_D[ 7:0] & CR3_MASK[ 7:0];
								if (MEM_WE[1]) CR3[15:8] <= MEM_D[15:8] & CR3_MASK[15:8];
							end
							6'h08: begin
								//if (MEM_WE[0]) CR4[ 7:0] <= MEM_D[ 7:0] & CR4_MASK[ 7:0];
								//if (MEM_WE[1]) CR4[15:8] <= MEM_D[15:8] & CR4_MASK[15:8];
								if (MEM_WE[1]) CR4[15:11] <= MEM_D[15:11];
							end
							6'h12: begin
								if (MEM_WE[0]) CR5[ 7:0] <= MEM_D[ 7:0] & CR5_MASK[ 7:0];
								if (MEM_WE[1]) CR5[15:8] <= MEM_D[15:8] & CR5_MASK[15:8];
							end
							6'h14: begin
								if (MEM_WE[0]) CR6[ 7:0] <= MEM_D[ 7:0] & CR6_MASK[ 7:0];
								if (MEM_WE[1]) CR6[15:8] <= MEM_D[15:8] & CR6_MASK[15:8];
							end
							6'h16: begin
								if (MEM_WE[0]) CR7[ 7:0] <= MEM_D[ 7:0] & CR7_MASK[ 7:0];
								if (MEM_WE[1]) CR7[15:8] <= MEM_D[15:8] & CR7_MASK[15:8];
							end
							6'h18: begin
								if (MEM_WE[0]) CR8[ 7:0] <= MEM_D[ 7:0] & CR8_MASK[ 7:0];
								if (MEM_WE[1]) CR8[15:8] <= MEM_D[15:8] & CR8_MASK[15:8];
							end
							6'h1A: begin
								if (MEM_WE[0]) CR9[ 7:0] <= MEM_D[ 7:0] & CR9_MASK[ 7:0];
								if (MEM_WE[1]) CR9[15:8] <= MEM_D[15:8] & CR9_MASK[15:8];
							end
							6'h1C: begin
								if (MEM_WE[0]) CR10[ 7:0] <= MEM_D[ 7:0] & CR10_MASK[ 7:0];
								if (MEM_WE[1]) CR10[15:8] <= MEM_D[15:8] & CR10_MASK[15:8];
							end
							6'h1E: begin
								if (MEM_WE[0]) CR11[ 7:0] <= MEM_D[ 7:0] & CR11_MASK[ 7:0];
								if (MEM_WE[1]) CR11[15:8] <= MEM_D[15:8] & CR11_MASK[15:8];
							end
							6'h20: begin
								if (MEM_WE[0]) CR12[5] <= MEM_D[5];
							end
							6'h22: begin
								if (MEM_WE[0]) CR13[ 7:0] <= MEM_D[ 7:0] & CR13_MASK[ 7:0];
								if (MEM_WE[1]) CR13[15:8] <= MEM_D[15:8] & CR13_MASK[15:8];
								if (MEM_WE[0]) CR12.SCIPD[ 7:0] <= CR12.SCIPD[ 7:0] & ~MEM_D[ 7:0];
								if (MEM_WE[1]) CR12.SCIPD[10:8] <= CR12.SCIPD[10:8] & ~MEM_D[10:8];
							end
							6'h24: begin
								if (MEM_WE[0]) CR14[ 7:0] <= MEM_D[ 7:0] & CR14_MASK[ 7:0];
								if (MEM_WE[1]) CR14[15:8] <= MEM_D[15:8] & CR14_MASK[15:8];
							end
							6'h26: begin
								if (MEM_WE[0]) CR15[ 7:0] <= MEM_D[ 7:0] & CR15_MASK[ 7:0];
								if (MEM_WE[1]) CR15[15:8] <= MEM_D[15:8] & CR15_MASK[15:8];
							end
							6'h28: begin
								if (MEM_WE[0]) CR16[ 7:0] <= MEM_D[ 7:0] & CR16_MASK[ 7:0];
								if (MEM_WE[1]) CR16[15:8] <= MEM_D[15:8] & CR16_MASK[15:8];
							end
							6'h2A: begin
								if (MEM_WE[0]) CR17[ 7:0] <= MEM_D[ 7:0] & CR17_MASK[ 7:0];
								if (MEM_WE[1]) CR17[15:8] <= MEM_D[15:8] & CR17_MASK[15:8];
							end
							6'h2C: begin
								if (MEM_WE[0]) CR18[5] <= MEM_D[5];
							end
							6'h2E: begin
								if (MEM_WE[0]) CR19[ 7:0] <= MEM_D[ 7:0] & CR19_MASK[ 7:0];
								if (MEM_WE[1]) CR19[15:8] <= MEM_D[15:8] & CR19_MASK[15:8];
								if (MEM_WE[0]) CR18.MCIPD[ 7:0] <= CR18.MCIPD[ 7:0] & ~MEM_D[ 7:0];
								if (MEM_WE[1]) CR18.MCIPD[10:8] <= CR18.MCIPD[10:8] & ~MEM_D[10:8];
							end
							default:;
						endcase
	//				end else if (REG_A[11:9] == 3'b011) begin
	//					if (MEM_WE[0]) STACK[REG_A[7:1]][ 7:0] <= MEM_D[ 7:0];
	//					if (MEM_WE[1]) STACK[REG_A[7:1]][15:8] <= MEM_D[15:8];
					end
					REG_RDY <= 1;
				end else if (MEM_RD && REG_CS) begin
					if (MEM_A[11:10] == 2'b00) begin
						for (int i=0; i<32; i++) begin
							if (MEM_A[9:5] == i) begin
								case ({MEM_A[4:1],1'b0})
									5'h00: REG_Q <= SCR[i].SCR0 & SCR0_MASK;
									5'h02: REG_Q <= SCR[i].SA & SA_MASK;
									5'h04: REG_Q <= SCR[i].LSA & LSA_MASK;
									5'h06: REG_Q <= SCR[i].LEA & LEA_MASK;
									5'h08: REG_Q <= SCR[i].SCR1 & SCR1_MASK;
									5'h0A: REG_Q <= SCR[i].SCR2 & SCR2_MASK;
									5'h0C: REG_Q <= SCR[i].SCR3 & SCR3_MASK;
									5'h0E: REG_Q <= SCR[i].SCR4 & SCR4_MASK;
									5'h10: REG_Q <= SCR[i].SCR5 & SCR5_MASK;
									5'h12: REG_Q <= SCR[i].SCR6 & SCR6_MASK;
									5'h14: REG_Q <= SCR[i].SCR7 & SCR7_MASK;
									5'h16: REG_Q <= SCR[i].SCR8 & SCR8_MASK;
									default:;
								endcase
							end
						end
					end else if (MEM_A[11:9] == 3'b010) begin
						case ({MEM_A[5:1],1'b0})
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
	//				end else if (MEM_A[11:9] == 3'b011) begin
	//					REG_Q <= STACK[MEM_A[7:1]];
					end else begin
						REG_Q <= '0;
					end
					REG_RDY <= 1;
				end
				
				if (OP2_PIPE.SLOT == CR4.MSLC && SLOT_CE) begin
					CR4.CA <= SA[OP2_PIPE.SLOT][15:12];
				end
				
				if (SLOT_CE) begin
//					STACK0[OP7_PIPE.SLOT] <= STACK1[OP7_PIPE.SLOT];
//					STACK1[OP7_PIPE.SLOT] <= OP7_SD;
				end
			end
		end
	end
	
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
	
	assign DO = MEM_Q;
	assign RDY_N = ~(SCU_SEL & ~SCU_PEND);
	assign INT_N = ~|(CR18.MCIPD & CR17.MCIEB);
	
	assign SCIPL_N = ~ILV;
	assign SCDO = MEM_Q;
	assign SCAVEC_N = ~&SCFC;
	
	assign SCA_DBG = {SCA,1'b0};
	
endmodule
