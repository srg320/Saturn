module SCSP (
	input             CLK,
	input             RST_N,
	input             CE,
	
	input             RES_N,
	
	input             CE_R,
	input             CE_F,
	input      [20:0] A,
	input      [15:0] DI,
	output     [15:0] DO,
	input             CS_N,
	input       [1:0] WE_N,
	input             RD_N,
	output            RDY_N,
	
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
	input             SCAVEC_N,
	output      [2:0] SCIPL_N,

	output     [18:1] RAM_A,
	output     [15:0] RAM_D,
	input      [15:0] RAM_Q,
	output      [1:0] RAM_WE
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
	STACK_t    STACK;
	
	bit [19:0] ADP;
	
	bit        WD_READ;
	bit        DMA_ACCESS;
	bit [18:1] DMA_A;
	bit [15:0] DMA_DAT;
	bit        DMA_WR;
	
	typedef enum bit [4:0] {
		MS_IDLE = 5'b00001,  
		MS_ACCESS = 5'b00010, 
		MS_END  = 5'b00100,
		MS_WAIT = 5'b01000
	} MemState_t;
	MemState_t MEM_ST;
	
	bit [18:1] MEM_A;
	bit [15:0] MEM_D;
	bit [15:0] MEM_Q;
	bit  [1:0] MEM_WE;
	
	bit [11:1] REG_A;
	bit [15:0] REG_D;
	bit [15:0] REG_Q;
	bit  [1:0] REG_WE;
	bit        REG_RD;
	
	bit  [3:0] CLK_CNT;
	always @(posedge CLK) if (CE) CLK_CNT <= CLK_CNT + 4'd1;
	
	assign SCCE_R =  CLK_CNT[0] & CE;
	assign SCCE_F = ~CLK_CNT[0] & CE;
	
	wire CYCLE_CE = &CLK_CNT & CE;
	
	bit  [6:0] CYCLE_NUM;
	always @(posedge CLK) if (CYCLE_CE) CYCLE_NUM <= CYCLE_NUM + 7'd1;
	
	wire DMA_REG_SEL = 0;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DMA_A = '0;
			DMA_DAT <= '0;
			DMA_WR <= '0;
			REG_RD <= 0;
			DMA_ACCESS <= 0;
		end
		else if (CE) begin
			DMA_A = '0;
			DMA_DAT <= '0;
			DMA_WR <= '0;
			REG_RD <= 0;
			DMA_ACCESS <= 0;
		end
	end
	
	wire SCU_REG_SEL = A[20] & ~CS_N;	//25B00000-25BFFFFF
	wire M68K_REG_SEL = SCA[23:20] == 4'h1 & !SCAS_N && (!SCLDS_N || !SCUDS_N);	//100000-1FFFFF
	always_comb begin
		REG_A = '0;
		REG_D <= '0;
		REG_WE <= '0;
		REG_RD <= 0;
		if (DMA_REG_SEL) begin
			REG_A = DMA_A[11:1];
			REG_D <= DMA_DAT;
			REG_WE <= {2{DMA_WR}};
			REG_RD <= ~DMA_WR;
		end else if (SCU_REG_SEL) begin
			REG_A = A[11:1];
			REG_D <= DI;
			REG_WE <= ~WE_N;
			REG_RD <= ~|WE_N;
		end else if (M68K_REG_SEL) begin
			REG_A <= SCA[11:1];
			REG_D <= SCDI;
			REG_WE <= {~SCRW_N&~SCUDS_N,~SCRW_N&~SCLDS_N};
			REG_RD <= SCRW_N;
		end
	end
	wire REG_SEL = DMA_REG_SEL | SCU_REG_SEL | M68K_REG_SEL;

	
	OPPipe_t    OP2_PIPE;
	OPPipe_t    OP3_PIPE;
	OPPipe_t    OP4_PIPE;
	OPPipe_t    OP5_PIPE;
	OPPipe_t    OP6_PIPE;
	OPPipe_t    OP7_PIPE;
	
	//Operation 1: PG
	//KEY ON/OFF
	wire KYONEX_SET = REG_SEL & REG_A ==? 11'b00?????0000 & REG_D[12] & REG_WE[0];
	bit KEYON[32], KEYOFF[32];
	bit [14: 0] PHASE;
	always @(posedge CLK or negedge RST_N) begin
		bit       KYONEX;
		bit [4:0] SLOT;
		
		if (!RST_N) begin
			KEYON <= '{32{0}};
			KEYOFF <= '{32{0}};
			KYONEX <= '0;
			SLOT <= '0;
			OP2_PIPE <= OP_PIPE_RESET;
		end
		else begin
			if (!KYONEX && KYONEX_SET) begin
				KYONEX <= 1;
			end else if (KYONEX && CYCLE_CE) begin
				for (int i=0; i<32; i++) begin
					if (SCR[i].SCR0.KB) KEYON[i] <= 1;
					if (SCR[i].SCR0.KB) KEYOFF[i] <= 1;
				end
				KYONEX <= 0;
			end
			
			if (CYCLE_CE) begin
				PHASE <= PhaseCalc(SCR[SLOT].SCR5);
				OP2_PIPE.SLOT <= SLOT;
				OP2_PIPE.KON <= KEYON[SLOT];
				OP2_PIPE.KOFF <= KEYOFF[SLOT];
				if (KEYOFF[SLOT]) KEYOFF[SLOT] <= 0;
				if (KEYON[SLOT]) KEYON[SLOT] <= 0;
				SLOT <= SLOT + 5'd1;
			end
		end
	end
	
	//Operation 2: MD read, ADP
	OP2State_t OP2_STATE[32];
	bit [15:0] LA;
	always @(posedge CLK or negedge RST_N) begin
		bit [15:0] MD;
		bit [15:0] TEMP;
		bit [15:0] LL;
		bit [ 4:0] S;
		
		if (!RST_N) begin
			ADP <= '0;
			WD_READ <= 0;
			LA <= '0;
			OP3_PIPE <= OP_PIPE_RESET;
		end
		else begin
			S = OP2_PIPE.SLOT;
			MD = MDCalc(STACK, SCR[S].SCR4);
			TEMP = {1'b0,PHASE} + $signed(MD);
			
			WD_READ <= 0;
			if (CYCLE_CE) begin
				LL = SCR[S].LEA - SCR[S].LSA;
				if (OP2_PIPE.KON) begin
					ADP <= {SCR[S].SCR0.SAH,SCR[S].SA};
					LA <= '0;
				end else if (LA >= SCR[S].LEA) begin
					ADP <= ADP - {4'h0,LL};
					LA <= LA - LL;
				end else begin
					ADP <= ADP + TEMP;
					LA <= LA + TEMP;
				end
				WD_READ <= 1;
				
				OP3_PIPE <= OP2_PIPE;
			end
		end
	end
	
	//Operation 3: 
	bit [15:0] WD;	//Wave form data
	always @(posedge CLK or negedge RST_N) begin
		bit [ 4:0] S;
		
		if (!RST_N) begin
			WD <= '0;
			OP4_PIPE <= OP_PIPE_RESET;
		end
		else begin
			S = OP3_PIPE.SLOT;
			
			if (CYCLE_CE) begin
				WD <= MEM_Q;
				OP4_PIPE <= OP3_PIPE;
			end
		end
	end
	
	//Operation 4: EG
	OP4State_t OP4_STATE[32];
	bit [15:0] OP4_WD;
	always @(posedge CLK or negedge RST_N) begin
		bit [10:0] VOL_NEXT;
		bit [ 4:0] S;
		
		if (!RST_N) begin
			OP4_STATE[0] <= '{'0, EGS_IDLE};
			OP5_PIPE <= OP_PIPE_RESET;
		end
		else begin
			S = OP4_PIPE.SLOT;
			if (/*CYCLE_NUM == 7'd0 && */CYCLE_CE) begin
				case (OP4_STATE[S].ST)
					EGS_IDLE: begin
						if (OP4_PIPE.KON) begin
							OP4_STATE[S].ST <= EGS_ATTACK;
						end
					end
					
					EGS_ATTACK: begin
						VOL_NEXT = OP4_STATE[S].EVOL + {SCR[S].SCR2.AR,5'b11111};
						if (!VOL_NEXT[10]) begin
							OP4_STATE[S].EVOL <= VOL_NEXT[9:0];
						end else begin
							OP4_STATE[S].EVOL <= 10'h3FF;
							OP4_STATE[S].ST <= EGS_DECAY1;
						end
						if (OP4_PIPE.KOFF) OP4_STATE[S].ST <= EGS_RELEASE;
					end
					
					EGS_DECAY1: begin
						VOL_NEXT = OP4_STATE[S].EVOL - {SCR[S].SCR2.D1R,5'b00000};
						if (VOL_NEXT[9:5] > SCR[S].SCR1.DL) begin
							OP4_STATE[S].EVOL <= VOL_NEXT[9:0];
						end else begin
							OP4_STATE[S].EVOL <= {SCR[S].SCR1.DL,5'b00000};
							OP4_STATE[S].ST <= EGS_DECAY2;
						end
						if (OP4_PIPE.KOFF) OP4_STATE[S].ST <= EGS_RELEASE;
					end
					
					EGS_DECAY2: begin
						VOL_NEXT = OP4_STATE[S].EVOL - {SCR[S].SCR2.D2R,5'b00000};
						if (!VOL_NEXT[10]) begin
							OP4_STATE[S].EVOL <= VOL_NEXT[9:0];
						end else begin
							OP4_STATE[S].EVOL <= 10'h000;
						end
						if (OP4_PIPE.KOFF) OP4_STATE[S].ST <= EGS_RELEASE;
					end
					
					EGS_RELEASE: begin
						VOL_NEXT = OP4_STATE[S].EVOL - {SCR[S].SCR1.RR,5'b00000};
						if (!VOL_NEXT[10]) begin
							OP4_STATE[S].EVOL <= VOL_NEXT[9:0];
						end else begin
							OP4_STATE[S].EVOL <= 10'h000;
							OP4_STATE[S].ST <= EGS_IDLE;
						end
					end
				endcase
				OP4_WD <= WD;
				OP5_PIPE <= OP4_PIPE;
			end
		end
	end
	
	//Operation 5: Level calculation
	bit [15:0] SD;	//Slot out data
	always @(posedge CLK or negedge RST_N) begin
		bit [ 4:0] S;
		bit [ 7:0] TL;
		bit [ 9:0] TEMP;
		
		if (!RST_N) begin
			OP6_PIPE <= OP_PIPE_RESET;
			SD <= '0;
		end
		else begin
			S = OP4_PIPE.SLOT;
			TL = SCR[S].SCR3.TL;
			if (CYCLE_CE) begin
				TEMP = EnvVolCalc(OP4_STATE[S].EVOL, TL);
				SD <= ($signed(OP4_WD) * TEMP) >> 10;
				OP6_PIPE <= OP5_PIPE;
			end
		end
	end
	
	//Operation 6: Level calculation
	bit [15:0] OP6_SD;
	always @(posedge CLK or negedge RST_N) begin
		bit [10:0] VOL_NEXT;
		bit [ 4:0] S;
		
		if (!RST_N) begin
			//OP4_STATE[0] <= '{'0, EGS_IDLE};
			OP7_PIPE <= OP_PIPE_RESET;
		end
		else begin
			S = OP4_PIPE.SLOT;
			if (CYCLE_CE) begin
				
				OP6_SD <= SD;
				OP7_PIPE <= OP6_PIPE;
			end
		end
	end
	
	
	//RAM access
	wire SCU_RAM_SEL = ~CS_N & ~A[20];	//25A00000-25AFFFFF
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			MEM_ST <= MS_IDLE;
			MEM_A <= '0;
			MEM_D <= '0;
			MEM_WE <= '0;
			SCDTACK_N <= 1;
		end
		else begin
			case (MEM_ST)
				MS_IDLE: begin
					if (WD_READ) begin
						MEM_A <= ADP[18:1];
						MEM_D <= '0;
						MEM_WE <= '0;
						MEM_ST <= MS_ACCESS;
					end else if (DMA_ACCESS) begin
						MEM_A <= DMA_A;
						MEM_D <= DMA_DAT;
						MEM_WE <= {2{DMA_WR}};
						MEM_ST <= MS_ACCESS;
					end else if (SCU_RAM_SEL) begin
						MEM_A <= A[18:1];
						MEM_D <= DI;
						MEM_WE <= ~WE_N;
						MEM_ST <= MS_ACCESS;
					end else if (SCA[20] & !SCAS_N && (!SCLDS_N || !SCUDS_N) && SCDTACK_N) begin
						MEM_A <= SCA[18:1];
						MEM_D <= SCDI;
						MEM_WE <= {~SCRW_N&~SCUDS_N,~SCRW_N&~SCLDS_N};
						MEM_ST <= MS_ACCESS;
					end
				end
				
				MS_ACCESS: begin
					MEM_Q <= RAM_Q;
					MEM_WE <= '0;
					MEM_ST <= MS_IDLE;
				end
				
				default:;
			endcase
			SCDTACK_N <= 1;////////////
		end
	end
	
	assign RAM_A = MEM_A;
	assign RAM_D = MEM_D;
	assign RAM_WE = MEM_WE;
	
	//Registers
	bit [15:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
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
			STACK <= '{64{'0}};
			REG_DO <= '0;
		end
		else begin
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
				STACK <= '{64{'0}};
			end else begin
				if (REG_SEL) begin
					if (REG_WE) begin
						if (REG_A[11:10] == 2'b00) begin
							case ({REG_A[4:1],1'b0})
								5'h00: begin
									if (REG_WE[0]) SCR[REG_A[9:5]].SCR0[ 7:0] <= REG_D[ 7:0] & SCR0_MASK[ 7:0];
									if (REG_WE[1]) SCR[REG_A[9:5]].SCR0[15:8] <= REG_D[15:8] & SCR0_MASK[15:8];
								end
								5'h02: begin
									if (REG_WE[0]) SCR[REG_A[9:5]].SA[ 7:0] <= REG_D[ 7:0] & SA_MASK[ 7:0];
									if (REG_WE[1]) SCR[REG_A[9:5]].SA[15:8] <= REG_D[15:8] & SA_MASK[15:8];
								end
								5'h04: begin
									if (REG_WE[0]) SCR[REG_A[9:5]].LSA[ 7:0] <= REG_D[ 7:0] & LSA_MASK[ 7:0];
									if (REG_WE[1]) SCR[REG_A[9:5]].LSA[15:8] <= REG_D[15:8] & LSA_MASK[15:8];
								end
								5'h06: begin
									if (REG_WE[0]) SCR[REG_A[9:5]].LEA[ 7:0] <= REG_D[ 7:0] & LEA_MASK[ 7:0];
									if (REG_WE[1]) SCR[REG_A[9:5]].LEA[15:8] <= REG_D[15:8] & LEA_MASK[15:8];
								end
								5'h08: begin
									if (REG_WE[0]) SCR[REG_A[9:5]].SCR1[ 7:0] <= REG_D[ 7:0] & SCR1_MASK[ 7:0];
									if (REG_WE[1]) SCR[REG_A[9:5]].SCR1[15:8] <= REG_D[15:8] & SCR1_MASK[15:8];
								end
								5'h0A: begin
									if (REG_WE[0]) SCR[REG_A[9:5]].SCR2[ 7:0] <= REG_D[ 7:0] & SCR2_MASK[ 7:0];
									if (REG_WE[1]) SCR[REG_A[9:5]].SCR2[15:8] <= REG_D[15:8] & SCR2_MASK[15:8];
								end
								5'h0C: begin
									if (REG_WE[0]) SCR[REG_A[9:5]].SCR3[ 7:0] <= REG_D[ 7:0] & SCR3_MASK[ 7:0];
									if (REG_WE[1]) SCR[REG_A[9:5]].SCR3[15:8] <= REG_D[15:8] & SCR3_MASK[15:8];
								end
								5'h0E: begin
									if (REG_WE[0]) SCR[REG_A[9:5]].SCR4[ 7:0] <= REG_D[ 7:0] & SCR4_MASK[ 7:0];
									if (REG_WE[1]) SCR[REG_A[9:5]].SCR4[15:8] <= REG_D[15:8] & SCR4_MASK[15:8];
								end
								5'h10: begin
									if (REG_WE[0]) SCR[REG_A[9:5]].SCR5[ 7:0] <= REG_D[ 7:0] & SCR5_MASK[ 7:0];
									if (REG_WE[1]) SCR[REG_A[9:5]].SCR5[15:8] <= REG_D[15:8] & SCR5_MASK[15:8];
								end
								5'h12: begin
									if (REG_WE[0]) SCR[REG_A[9:5]].SCR6[ 7:0] <= REG_D[ 7:0] & SCR6_MASK[ 7:0];
									if (REG_WE[1]) SCR[REG_A[9:5]].SCR6[15:8] <= REG_D[15:8] & SCR6_MASK[15:8];
								end
								5'h14: begin
									if (REG_WE[0]) SCR[REG_A[9:5]].SCR7[ 7:0] <= REG_D[ 7:0] & SCR7_MASK[ 7:0];
									if (REG_WE[1]) SCR[REG_A[9:5]].SCR7[15:8] <= REG_D[15:8] & SCR7_MASK[15:8];
								end
								5'h16: begin
									if (REG_WE[0]) SCR[REG_A[9:5]].SCR8[ 7:0] <= REG_D[ 7:0] & SCR8_MASK[ 7:0];
									if (REG_WE[1]) SCR[REG_A[9:5]].SCR8[15:8] <= REG_D[15:8] & SCR8_MASK[15:8];
								end
								default:;
							endcase
						end else if (REG_A[11:9] == 3'b010) begin
							case ({REG_A[8:1],1'b0})
								9'h000: begin
									if (REG_WE[0]) CR0[ 7:0] <= REG_D[ 7:0] & CR0_MASK[ 7:0];
									if (REG_WE[1]) CR0[15:8] <= REG_D[15:8] & CR0_MASK[15:8];
								end
								9'h002: begin
									if (REG_WE[0]) CR1[ 7:0] <= REG_D[ 7:0] & CR1_MASK[ 7:0];
									if (REG_WE[1]) CR1[15:8] <= REG_D[15:8] & CR1_MASK[15:8];
								end
								9'h004: begin
									if (REG_WE[0]) CR2[ 7:0] <= REG_D[ 7:0] & CR2_MASK[ 7:0];
									if (REG_WE[1]) CR2[15:8] <= REG_D[15:8] & CR2_MASK[15:8];
								end
								9'h006: begin
									if (REG_WE[0]) CR3[ 7:0] <= REG_D[ 7:0] & CR3_MASK[ 7:0];
									if (REG_WE[1]) CR3[15:8] <= REG_D[15:8] & CR3_MASK[15:8];
								end
								9'h008: begin
									if (REG_WE[0]) CR4[ 7:0] <= REG_D[ 7:0] & CR4_MASK[ 7:0];
									if (REG_WE[1]) CR4[15:8] <= REG_D[15:8] & CR4_MASK[15:8];
								end
								9'h012: begin
									if (REG_WE[0]) CR5[ 7:0] <= REG_D[ 7:0] & CR5_MASK[ 7:0];
									if (REG_WE[1]) CR5[15:8] <= REG_D[15:8] & CR5_MASK[15:8];
								end
								9'h014: begin
									if (REG_WE[0]) CR6[ 7:0] <= REG_D[ 7:0] & CR6_MASK[ 7:0];
									if (REG_WE[1]) CR6[15:8] <= REG_D[15:8] & CR6_MASK[15:8];
								end
								9'h016: begin
									if (REG_WE[0]) CR7[ 7:0] <= REG_D[ 7:0] & CR7_MASK[ 7:0];
									if (REG_WE[1]) CR7[15:8] <= REG_D[15:8] & CR7_MASK[15:8];
								end
								9'h018: begin
									if (REG_WE[0]) CR8[ 7:0] <= REG_D[ 7:0] & CR8_MASK[ 7:0];
									if (REG_WE[1]) CR8[15:8] <= REG_D[15:8] & CR8_MASK[15:8];
								end
								9'h01A: begin
									if (REG_WE[0]) CR9[ 7:0] <= REG_D[ 7:0] & CR9_MASK[ 7:0];
									if (REG_WE[1]) CR9[15:8] <= REG_D[15:8] & CR9_MASK[15:8];
								end
								9'h01C: begin
									if (REG_WE[0]) CR10[ 7:0] <= REG_D[ 7:0] & CR10_MASK[ 7:0];
									if (REG_WE[1]) CR10[15:8] <= REG_D[15:8] & CR10_MASK[15:8];
								end
								9'h01E: begin
									if (REG_WE[0]) CR11[ 7:0] <= REG_D[ 7:0] & CR11_MASK[ 7:0];
									if (REG_WE[1]) CR11[15:8] <= REG_D[15:8] & CR11_MASK[15:8];
								end
								9'h020: begin
									if (REG_WE[0]) CR12[ 7:0] <= REG_D[ 7:0] & CR12_MASK[ 7:0];
									if (REG_WE[1]) CR12[15:8] <= REG_D[15:8] & CR12_MASK[15:8];
								end
								9'h022: begin
									if (REG_WE[0]) CR13[ 7:0] <= REG_D[ 7:0] & CR13_MASK[ 7:0];
									if (REG_WE[1]) CR13[15:8] <= REG_D[15:8] & CR13_MASK[15:8];
								end
								9'h024: begin
									if (REG_WE[0]) CR14[ 7:0] <= REG_D[ 7:0] & CR14_MASK[ 7:0];
									if (REG_WE[1]) CR14[15:8] <= REG_D[15:8] & CR14_MASK[15:8];
								end
								9'h026: begin
									if (REG_WE[0]) CR15[ 7:0] <= REG_D[ 7:0] & CR15_MASK[ 7:0];
									if (REG_WE[1]) CR15[15:8] <= REG_D[15:8] & CR15_MASK[15:8];
								end
								9'h028: begin
									if (REG_WE[0]) CR16[ 7:0] <= REG_D[ 7:0] & CR16_MASK[ 7:0];
									if (REG_WE[1]) CR16[15:8] <= REG_D[15:8] & CR16_MASK[15:8];
								end
								9'h02A: begin
									if (REG_WE[0]) CR17[ 7:0] <= REG_D[ 7:0] & CR17_MASK[ 7:0];
									if (REG_WE[1]) CR17[15:8] <= REG_D[15:8] & CR17_MASK[15:8];
								end
								9'h02C: begin
									if (REG_WE[0]) CR18[ 7:0] <= REG_D[ 7:0] & CR18_MASK[ 7:0];
									if (REG_WE[1]) CR18[15:8] <= REG_D[15:8] & CR18_MASK[15:8];
								end
								9'h02E: begin
									if (REG_WE[0]) CR19[ 7:0] <= REG_D[ 7:0] & CR19_MASK[ 7:0];
									if (REG_WE[1]) CR19[15:8] <= REG_D[15:8] & CR19_MASK[15:8];
								end
								default:;
							endcase
						end else if (REG_A[11:9] == 3'b011) begin
							if (REG_WE[0]) STACK[REG_A[7:1]][ 7:0] <= REG_D[ 7:0];
							if (REG_WE[1]) STACK[REG_A[7:1]][15:8] <= REG_D[15:8];
						end
					end else begin
						if (REG_A[11:10] == 2'b00) begin
							case ({REG_A[4:1],1'b0})
								5'h00: REG_Q <= SCR[REG_A[9:5]].SCR0 & SCR0_MASK;
								5'h02: REG_Q <= SCR[REG_A[9:5]].SA & SA_MASK;
								5'h04: REG_Q <= SCR[REG_A[9:5]].LSA & LSA_MASK;
								5'h06: REG_Q <= SCR[REG_A[9:5]].LEA & LEA_MASK;
								5'h08: REG_Q <= SCR[REG_A[9:5]].SCR1 & SCR1_MASK;
								5'h0A: REG_Q <= SCR[REG_A[9:5]].SCR2 & SCR2_MASK;
								5'h0C: REG_Q <= SCR[REG_A[9:5]].SCR3 & SCR3_MASK;
								5'h0E: REG_Q <= SCR[REG_A[9:5]].SCR4 & SCR4_MASK;
								5'h10: REG_Q <= SCR[REG_A[9:5]].SCR5 & SCR5_MASK;
								5'h12: REG_Q <= SCR[REG_A[9:5]].SCR6 & SCR6_MASK;
								5'h14: REG_Q <= SCR[REG_A[9:5]].SCR7 & SCR7_MASK;
								5'h16: REG_Q <= SCR[REG_A[9:5]].SCR8 & SCR8_MASK;
								default:;
							endcase
						end else if (REG_A[11:9] == 3'b010) begin
							case ({REG_A[9:1],1'b0})
								9'h000: REG_Q <= CR0 & CR0_MASK;
								9'h002: REG_Q <= CR1 & CR1_MASK;
								9'h004: REG_Q <= CR2 & CR2_MASK;
								9'h006: REG_Q <= CR3 & CR3_MASK;
								9'h008: REG_Q <= CR4 & CR4_MASK;
								9'h012: REG_Q <= CR5 & CR5_MASK;
								9'h014: REG_Q <= CR6 & CR6_MASK;
								9'h016: REG_Q <= CR7 & CR7_MASK;
								9'h018: REG_Q <= CR8 & CR8_MASK;
								9'h01A: REG_Q <= CR9 & CR9_MASK;
								9'h01C: REG_Q <= CR10 & CR10_MASK;
								9'h01E: REG_Q <= CR11 & CR11_MASK;
								9'h020: REG_Q <= CR12 & CR12_MASK;
								9'h022: REG_Q <= CR13 & CR13_MASK;
								9'h024: REG_Q <= CR14 & CR14_MASK;
								9'h026: REG_Q <= CR15 & CR15_MASK;
								9'h028: REG_Q <= CR16 & CR16_MASK;
								9'h02A: REG_Q <= CR17 & CR17_MASK;
								9'h02C: REG_Q <= CR18 & CR18_MASK;
								9'h02E: REG_Q <= CR19 & CR19_MASK;
								default: REG_Q <= '0;
							endcase
						end else if (REG_A[11:9] == 3'b011) begin
							REG_Q <= STACK[REG_A[7:1]];
						end else begin
							REG_Q <= '0;
						end
					end
				end
			end
		end
	end
	
	assign DO = SCU_REG_SEL ? REG_Q : MEM_Q;
	assign RDY_N = 0;
	
	assign SCIPL_N = '1;
	assign SCDO = MEM_Q;
	
endmodule
