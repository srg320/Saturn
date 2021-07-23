module YGR019 (
	input             CLK,
	input             RST_N,
	
	input             RES_N,
	
	input             CE_R,
	input             CE_F,
	input      [14:1] AA,
	input      [15:0] ADI,
	output     [15:0] ADO,
	input       [1:0] AFC,
	input             ACS2_N,
	input             ARD_N,
	input             AWRL_N,
	input             AWRU_N,
	input             ATIM0_N,
	input             ATIM2_N,
	output            AWAIT_N,
	output            ARQT_N,
	
	input             SHCE_R,
	input             SHCE_F,
	input      [21:1] SA,
	input      [15:0] SDI,
	input      [15:0] BDI,
	output     [15:0] SDO,
	input             SWRL_N,
	input             SWRH_N,
	input             SRD_N,
	input             SCS2_N,
	input             SCS6_N,
	input             DACK0,
	input             DACK1,
	output            DREQ0_N,
	output            DREQ1_N,
	output reg        SIRQL_N,
	output reg        SIRQH_N,

	input      [15:0] CD_D,
	input             CD_CK,
	
	output     [15:0] CR0,
	output     [31:0] DBG_HEADER,
	output     [7:0] DBG_CNT,
	output     [7:0] FIFO_CNT_DBG,
	output     [7:0] ABUS_WAIT_CNT_DBG
);
	import YGR019_PKG::*;

	CR_t       CR[4];
	CR_t       RR[4];
	bit [15:0]/*HIRQREQ_t*/  HIRQ;
	bit [15:0]/*HIRQMSK_t*/  HMASK;
	bit [15:0] DTR;
	bit [15:0] TRCTL;
	bit [15:0] MBX;
	bit [15:0] CDIRQ;
	bit [15:0] CDMASK;
	bit [15:0] REG08;
	bit [15:0] REG1A;
	//bit [15:0] REG1C;
	
	bit [15:0] FIFO_BUF[8];
	bit  [2:0] FIFO_WR_POS;
	bit  [2:0] FIFO_RD_POS;
	bit  [2:0] FIFO_AMOUNT;
//	bit        FIFO_FULL;
	bit        FIFO_EMPTY;
	bit        FIFO_DREQ;
	bit  [1:0] CDD_DREQ;
	
	bit        CDFIFO_RD;
	bit        CDFIFO_WR;
	bit [15:0] CDFIFO_Q;
	bit        CDFIFO_EMPTY;
	bit        CDFIFO_FULL;
	bit        CD_CK_OLD;
	bit [15:0] CDD_DATA;
	
	wire CDD_CE;
	CEGen CDD_CEGen
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.IN_CLK(53693175),
		.OUT_CLK(44100*2*2),
		.CE(CDD_CE)
	);

	always @(posedge CLK) CD_CK_OLD <= CD_CK;
	assign CDFIFO_WR = CD_CK & ~CD_CK_OLD;
	
	CDFIFO fifo 
	(
		.clock(CLK),
		.data(CD_D),
		.wrreq(CDFIFO_WR),
		.rdreq(CDFIFO_RD),
		.q(CDFIFO_Q),
		.empty(CDFIFO_EMPTY),
		.full(CDFIFO_FULL)
	);
	
	wire SCU_REG_SEL = (AA[14:12] == 3'b000) & ~ACS2_N;
	wire SH_REG_SEL = (SA[21:20] == 2'b00) & ~SCS2_N;
	wire SCU_DATA_WAIT = SCU_REG_SEL && AA[5:2] == 4'b0000 && FIFO_EMPTY;
	bit [15:0] SCU_REG_DO;
	bit        ABUS_WAIT;
	bit [15:0] SH_REG_DO;
	always @(posedge CLK or negedge RST_N) begin
//		bit        AWR_N_OLD;
		bit        ARD_N_OLD;
		bit        SCU_REG_SEL_OLD;
		bit        SWR_N_OLD;
		bit        SRD_N_OLD;
		bit        DACK0_OLD;
		bit        DACK1_OLD;
		bit        FIFO_INC_AMOUNT;
		bit        FIFO_DEC_AMOUNT;
		bit        FIFO_DREQ_PEND;
		bit        CDD_SYNCED;
		bit [11:0] CDD_CNT;
		bit        CDD_PEND;

		if (!RST_N) begin
			CR <= '{4{'0}};
			RR <= '{4{'0}};
			HIRQ <= '0;
			HMASK <= '0;

			REG08 <= '0;
			REG1A <= '0;
			//REG1C <= '0;
			
			CDIRQ <= '0;
			CDMASK <= '0;
			
			SH_REG_DO <= '0;
			ABUS_WAIT <= 0;
			
			FIFO_BUF <= '{8{'0}};
			FIFO_WR_POS <= '0;
			FIFO_RD_POS <= '0;
			FIFO_AMOUNT <= '0;
//			FIFO_FULL <= 0;
			FIFO_EMPTY <= 0;
			FIFO_DREQ_PEND <= 0;
			FIFO_DREQ <= 0;
			
			CDD_DREQ <= '0;
			CDD_SYNCED <= 0;
			CDD_CNT <= 4'd0;
			CDD_PEND <= 0;
			
			SIRQL_N <= 1;
		end else begin
			if (!RES_N) begin
				
			end else begin
				FIFO_INC_AMOUNT = 0;
				FIFO_DEC_AMOUNT = 0;

				if (/*!SCU_DATA_WAIT &&*/ CE_R) begin
//					AWR_N_OLD <= AWRL_N & AWRU_N;
					ARD_N_OLD <= ARD_N;
				end
				
				if (CE_F) begin
					SCU_REG_SEL_OLD <= SCU_REG_SEL;
				end
				
				if (ABUS_WAIT_CNT_DBG < 8'h80 && CE_R) ABUS_WAIT_CNT_DBG <= ABUS_WAIT_CNT_DBG + 8'd1;
				
				if (SCU_REG_SEL) begin
					if ((!AWRL_N || !AWRU_N) /*&& AWR_N_OLD*/ && !SCU_DATA_WAIT && CE_R) begin
						case ({AA[5:2],2'b00})
//							6'h00: DTR <= ADI;
							6'h08: HIRQ <= HIRQ & ADI;
							6'h0C: HMASK <= ADI;
							6'h18: begin CR[0] <= ADI; CR0 <= CR[0]; end
							6'h1C: CR[1] <= ADI;
							6'h20: CR[2] <= ADI;
							6'h24: begin CR[3] <= ADI; SIRQL_N <= 0; end
							default:;
						endcase
					end else if (!ARD_N && ARD_N_OLD /*&& !SCU_DATA_WAIT*/ && CE_F) begin
						case ({AA[5:2],2'b00})
							6'h00: begin
								ABUS_WAIT <= 1;
								ABUS_WAIT_CNT_DBG <= '0;
							end
//							6'h24: begin MBX[1] <= 1; end
							default: ;
						endcase
					end
				end else if (SCU_REG_SEL_OLD && ARD_N && !ARD_N_OLD && CE_F) begin
					case ({AA[5:2],2'b00})
						6'h00: begin
							FIFO_RD_POS <= FIFO_RD_POS + 3'd1;
							FIFO_DEC_AMOUNT = 1;
//							if (FIFO_RD_POS[1:0] == 2'd3) begin
							if (FIFO_AMOUNT == 7'd1) begin
								FIFO_DREQ_PEND <= 1;
							end
						end
						6'h24: begin MBX[1] <= 1; end
						default:;
					endcase
				end
				
				if (CE_F) begin
					if (ABUS_WAIT && !FIFO_EMPTY) begin
						ABUS_WAIT <= 0;
						ABUS_WAIT_CNT_DBG <= 8'hFF;
					end
				end
				
				if (SHCE_R) begin
					SWR_N_OLD <= SWRL_N & SWRH_N;
					SRD_N_OLD <= SRD_N;
					if (SH_REG_SEL) begin
						if ((!SWRL_N || !SWRH_N) && SWR_N_OLD) begin
							case ({SA[4:1],1'b0})
								5'h00:  begin 
									if (TRCTL[2]) begin
										FIFO_BUF[FIFO_WR_POS] <= SDI;
										FIFO_WR_POS <= FIFO_WR_POS + 3'd1;
										FIFO_INC_AMOUNT = 1;
									end
								end
								5'h02: begin 
									TRCTL <= SDI; 
									FIFO_DREQ_PEND <= SDI[2]; 
									if (SDI[1]) begin
										FIFO_WR_POS <= '0;
										FIFO_RD_POS <= '0;
										FIFO_AMOUNT <= '0;
//										FIFO_FULL <= 0;
										FIFO_EMPTY <= 1;
										FIFO_DREQ <= 0;
									end
								end
								5'h04: MBX <= SDI;
								5'h06: CDIRQ <= CDIRQ & SDI;
								5'h08: REG08 <= SDI;
								5'h0A: CDMASK <= SDI;
								5'h10: RR[0] <= SDI;
								5'h12: RR[1] <= SDI;
								5'h14: RR[2] <= SDI;
								5'h16: RR[3] <= SDI;
								5'h1A: REG1A <= SDI;
		//						5'h1C: REG1C <= SDI;
								5'h1E: HIRQ <= HIRQ | SDI;
								default:;
							endcase
						end else if (!SRD_N && SRD_N_OLD) begin
							case ({SA[4:1],1'b0})
								5'h00: begin
									SH_REG_DO <= FIFO_BUF[FIFO_RD_POS]; 
									FIFO_RD_POS <= FIFO_RD_POS + 3'd1;
									FIFO_DEC_AMOUNT = 1;
									if (FIFO_RD_POS[1:0] == 2'd3) begin
										FIFO_DREQ_PEND <= 1;
									end
								end
								5'h02: SH_REG_DO <= TRCTL;
								5'h04: SH_REG_DO <= MBX;
								5'h06: SH_REG_DO <= CDIRQ;
								5'h08: SH_REG_DO <= REG08;
								5'h0A: SH_REG_DO <= CDMASK;
								5'h10: SH_REG_DO <= CR[0];
								5'h12: SH_REG_DO <= CR[1];
								5'h14: SH_REG_DO <= CR[2];
								5'h16: begin SH_REG_DO <= CR[3]; SIRQL_N <= 1; end
								5'h1A: SH_REG_DO <= REG1A;
								5'h1C: SH_REG_DO <= 16'h0016;//REG1C;
								default: SH_REG_DO <= '0;
							endcase
						end
					end
				end
				
				//DREQ1
				if (SHCE_R) begin
					if (FIFO_CNT_DBG < 8'h80) FIFO_CNT_DBG <= FIFO_CNT_DBG + 8'd1;
					
					if (FIFO_DREQ_PEND) begin
						FIFO_DREQ_PEND <= 0;
						FIFO_DREQ <= 1;
						FIFO_CNT_DBG <= '0;
					end

					DACK1_OLD <= DACK1;
					if (TRCTL[2] && DACK1 && !DACK1_OLD) begin
						FIFO_BUF[FIFO_WR_POS] <= BDI;
						FIFO_WR_POS <= FIFO_WR_POS + 3'd1;
						FIFO_INC_AMOUNT = 1;
						if (FIFO_AMOUNT > 7'd2 && FIFO_DREQ) begin
							FIFO_DREQ <= 0;
							FIFO_CNT_DBG <= 8'hFF;
						end
					end
				end
				
				if (FIFO_INC_AMOUNT && !FIFO_DEC_AMOUNT) begin
					FIFO_AMOUNT <= FIFO_AMOUNT + 3'd1;
					if (FIFO_AMOUNT == 3'd7) FIFO_AMOUNT <= 3'd7;
//					if (FIFO_AMOUNT == 3'd6) FIFO_FULL <= 1;
					FIFO_EMPTY <= 0;
				end else if (!FIFO_INC_AMOUNT && FIFO_DEC_AMOUNT) begin
					FIFO_AMOUNT <= FIFO_AMOUNT - 3'd1;
					if (FIFO_AMOUNT == 3'd0) FIFO_AMOUNT <= 3'd0;
					if (FIFO_AMOUNT == 3'd1) FIFO_EMPTY <= 1;
//					FIFO_FULL <= 0;
				end
				
				//DREQ0
				CDFIFO_RD <= 0;
				if (CDD_CE) begin
					if (!CDFIFO_EMPTY) begin
						CDFIFO_RD <= 1;
						CDD_CNT <= CDD_CNT + 12'd2;
						if (!CDD_SYNCED) begin
							if (CDD_CNT == 12'd10) begin
								CDD_SYNCED <= 1; 
								REG1A[7] <= 1; 
							end
						end else if (CDD_CNT == 12'd12) begin
							DBG_HEADER[31:16] <= CDFIFO_Q;
						end else if (CDD_CNT == 12'd14) begin
							CDIRQ[4] <= 1;
							DBG_HEADER[15:0] <= CDFIFO_Q;
						end else if (CDD_CNT == 12'd2352-2) begin
							CDD_SYNCED <= 0;
							CDD_CNT <= 12'd0;
						end
						CDD_DATA <= CDFIFO_Q;
						CDD_PEND <= CDD_SYNCED;
					end
				end
				
				if (SHCE_R) begin
					if (DBG_CNT < 8'h80) DBG_CNT <= DBG_CNT + 8'd1;
					
					if (CDD_PEND) begin
						CDD_DREQ[0] <= REG1A[7];
						CDD_PEND <= 0;
						if (REG1A[7]) DBG_CNT <= '0;
					end else if (CDD_DREQ[0]) begin
						CDD_DREQ[0] <= 0;
					end
					CDD_DREQ[1] <= CDD_DREQ[0];
					
					DACK0_OLD <= DACK0;
					if (DACK0 && !DACK0_OLD) begin
						DBG_CNT <= 8'hFF;
					end
				end
			end
		end
	end
	
	always_comb begin
		case ({AA[5:2],2'b00})
			6'h00: SCU_REG_DO = FIFO_BUF[FIFO_RD_POS]; 
			6'h08: SCU_REG_DO = HIRQ;
			6'h0C: SCU_REG_DO = HMASK;
			6'h18: SCU_REG_DO = RR[0];
			6'h1C: SCU_REG_DO = RR[1];
			6'h20: SCU_REG_DO = RR[2];
			6'h24: SCU_REG_DO = RR[3];
			default: SCU_REG_DO = '0;
		endcase
	end

	assign ADO = SCU_REG_DO;
	assign AWAIT_N = ~ABUS_WAIT;
	assign ARQT_N = 1;
	
	assign SDO = !DACK0 && REG1A[7] ? CDD_DATA : SH_REG_SEL ? SH_REG_DO : SDI;
	assign SIRQH_N = ~|(CDIRQ & CDMASK);
	assign DREQ0_N = ~|CDD_DREQ;
	assign DREQ1_N = ~FIFO_DREQ;
	
	
endmodule
