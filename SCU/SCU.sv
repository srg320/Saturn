module SCU (
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	
	input             RES_N,
	
	input      [24:0] CA,
	input      [31:0] CDI,
	output     [31:0] CDO,
	input             CCS1_N,
	input             CCS2_N,
	input             CCS3_N,
	input             CRD_WR_N,
	input       [3:0] CDQM_N,
	input             CRD_N,
	output            CWAIT_N,
	input             CIVECF_N,
	output reg  [3:0] CIRL_N,
	output            CBREQ_N,
	input             CBACK_N,
	
	output     [24:0] ECA,
	input      [31:0] ECDI,
	output     [31:0] ECDO,
	output      [3:0] ECDQM_N,
	output            ECRD_WR_N,
	output            ECCS3_N,
	output            ECRD_N,	//not present in original
	input             ECWAIT_N,//not present in original
	
	output reg [25:0] AA,
	input      [15:0] ADI,
	output reg [15:0] ADO,
	output reg  [1:0] AFC,
	output reg        AAS_N,
	output reg        ACS0_N,
	output reg        ACS1_N,
	output reg        ACS2_N,
	input             AWAIT_N,
	input             AIRQ_N,
	output reg        ARD_N,
	output reg        AWRL_N,
	output reg        AWRU_N,
	output reg        ATIM0_N,
	output reg        ATIM1_N,
	output reg        ATIM2_N,
	
	input      [15:0] BDI,
	output reg [15:0] BDO,
	output reg        BADDT_N,
	output reg        BDTEN_N,
	output reg        BREQ_N,
	output reg        BCS1_N,
	input             BRDY1_N,
	input             IRQ1_N,
	output reg        BCS2_N,
	input             BRDY2_N,
	input             IRQV_N,
	input             IRQH_N,
	input             IRQL_N,
	output reg        BCSS_N,
	input             BRDYS_N,
	input             IRQS_N,
	
	input             MIREQ_N,
	
	output     [31:0] DBG_ASR,
	output     [15:0] DBG_WAIT_CNT,
	output reg        ADDR_ERR_DBG,
	output  [26:0] DBG_DMA_RADDR,
	output  [26:0] DBG_DMA_WADDR
);
	import SCU_PKG::*;
	
	DxR_t      DR[3];
	DxW_t      DW[3];
	DxC_t      DC[3];
	DxAD_t     DAD[3];
	DxEN_t     DEN[3];
	DxMD_t     DMD[3];
	DSTP_t     DSTP;
	DSTA_t     DSTA;
	T0C_t      T0C;
	T1S_t      T1S;
	T1MD_t     T1MD;
	IMS_t      IMS;
	ASR0_t     ASR0;
	ASR1_t     ASR1;
	RSEL_t     RSEL;
	
	bit CDQM_N_OLD;
	bit CRD_N_OLD;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			CDQM_N_OLD <= 0;
			CRD_N_OLD <= 0; 
		end else if (CE_R) begin
			CDQM_N_OLD <= &CDQM_N;
		end else if (CE_F) begin
			CRD_N_OLD <= CRD_N;
		end
	end
	wire CWE = ~&CDQM_N & CDQM_N_OLD & CE_R;
	wire CRE = ~CRD_N && CRD_N_OLD & CE_F;
	
	wire REG_SEL = ~CCS2_N & CA[24:0] >= 25'h1FE0000 & CA[24:0] <= 25'h1FE00CF;	//25FE0000-25FE00CF
	wire REG_WR = REG_SEL & CWE;
	wire REG_RD = REG_SEL & CRE;
	wire VECT_RD = ~CIVECF_N & CRE;

	bit        VBIN_INT;
	bit        VBOUT_INT;
	bit        HBIN_INT;
	bit        TM0_INT;
	bit        TM1_INT;
	bit        DSP_INT;
	bit        SCSP_INT;
	bit        SM_INT;
	bit        PAD_INT;
	bit  [3:0] DMA_INT;
	bit        DMAIL_INT;
	bit        VDP1_INT;
	bit [15:0] EXT_INT;
	
	bit [26:0] ABUS_A;
	bit        CPU_ABUS_REQ;
	bit        ABUS_RDY;
	typedef enum bit [4:0] {
		AS_IDLE  = 5'b00001,  
		AS_ADDR  = 5'b00010, 
		AS_ACCESS= 5'b00100,
		AS_END   = 5'b10000
	} ABusState_t;
	ABusState_t ABUS_ST;
	
	bit [22:0] BBUS_A;
	bit        CPU_BBUS_REQ;
	typedef enum bit [6:0] {
		BBS_IDLE  = 7'b0000001,  
		BBS_ADDRL = 7'b0000010, 
		BBS_ADDRH = 7'b0000100,
		BBS_WAIT  = 7'b0001000,
		BBS_BURST = 7'b0010000,
		BBS_CONT  = 7'b0100000,
		BBS_END   = 7'b1000000
	} BBusState_t;
	BBusState_t BBUS_ST;
	
	bit [26:0] CBUS_A;
	bit [31:0] CBUS_D;
	bit        CBUS_RD;
	bit  [3:0] CBUS_WR;
	bit        CBUS_CS;
	bit        CBUS_REQ;
	bit        CBUS_REL;
	bit        CBUS_RDY;
	typedef enum bit [5:0] {
		CS_IDLE   = 6'b000001,  
		CS_BUSREQ = 6'b000010, 
		CS_ADDR   = 6'b000100,
		CS_READ   = 6'b001000,
		CS_WRITE  = 6'b010000,
		CS_END    = 6'b100000
	} CBusState_t;
	CBusState_t CBUS_ST;
	
	//DSP
	bit [26:2] DSP_DMA_A;
	bit [31:0] DSP_DMA_DO;
	bit [31:0] DSP_DMA_DI;
	bit        DSP_DMA_WE;
	bit        DSP_DMA_REQ;
	bit        DSP_DMA_ACK;
	bit        DSP_IRQ;
	
	//DMA
	bit [26:0] DMA_IA[3];
	bit [26:0] DMA_RA[3];
	bit [26:0] DMA_WA[3];
	bit [19:0] DMA_TN[3];
	bit        DMA_EC[3];
	bit  [1:0] DMA_CH;
	bit        DMA_RUN[3];
	bit        DMA_END;
	typedef enum bit [16:0] {
		DRS_IDLE         = 17'b00000000000000001,  
		DRS_DMA_INIT     = 17'b00000000000000010, 
		DRS_DMA_IND_READ = 17'b00000000000000100, 
		DRS_DMA_IND      = 17'b00000000000001000, 
		DRS_DMA_START    = 17'b00000000000010000, 
		DRS_ABUS_ADDR    = 17'b00000000000100000,
		DRS_ABUS_READ    = 17'b00000000001000000,
		DRS_ABUS_WAIT    = 17'b00000000010000000,
		DRS_BBUS_ADDR1   = 17'b00000000100000000,
		DRS_BBUS_ADDR2   = 17'b00000001000000000,
		DRS_BBUS_READ    = 17'b00000010000000000,
		DRS_BBUS_WAIT    = 17'b00000100000000000,
		DRS_CBUS_REQUEST = 17'b00001000000000000,
		DRS_CBUS_READ    = 17'b00010000000000000,
		DRS_CBUS_WAIT    = 17'b00100000000000000,
		DRS_DMA_DSP_WRITE= 17'b01000000000000000,
		DRS_DMA_END      = 17'b10000000000000000
	} DMAReadState_t;
	DMAReadState_t DMA_RST;
	
	typedef enum bit [12:0] {
		DWS_IDLE         = 13'b0000000000001,  
		DWS_ABUS_ADDR    = 13'b0000000000010,
		DWS_ABUS_WRITE   = 13'b0000000000100,
		DWS_ABUS_WAIT    = 13'b0000000001000,
		DWS_BBUS_ADDR1   = 13'b0000000010000,
		DWS_BBUS_ADDR2   = 13'b0000000100000,
		DWS_BBUS_WRITE   = 13'b0000001000000,
		DWS_BBUS_WAIT    = 13'b0000010000000,
		DWS_CBUS_REQUEST = 13'b0000100000000,
		DWS_CBUS_WRITE   = 13'b0001000000000,
		DWS_CBUS_WAIT    = 13'b0010000000000,
		DWS_DSP_WAIT     = 13'b0100000000000,
		DWS_END          = 13'b1000000000000
	} DMAWriteState_t;
	DMAWriteState_t DMA_WST;
	
	typedef enum bit [9:0] {
		CPUS_IDLE           = 10'b0000000001,  
		CPUS_ABUS_ADDR      = 10'b0000000010, 
		CPUS_ABUS_ACCESS    = 10'b0000000100, 
		CPUS_ABUS_WAIT      = 10'b0000001000,
		CPUS_BBUS_ADDR1     = 10'b0000010000,
		CPUS_BBUS_ADDR2     = 10'b0000100000,
		CPUS_BBUS_WRITE     = 10'b0001000000,
		CPUS_BBUS_WRITE_END = 10'b0010000000,
		CPUS_BBUS_READ      = 10'b0100000000,
		CPUS_BBUS_READ_WAIT = 10'b1000000000
	} CPUState_t;
	CPUState_t CPU_ST;
	
	parameter bit [19:0] DMA_TN_MASK[3] = '{20'hFFFFF,20'h00FFF,20'h00FFF};
	
	//Extern request
	bit IRQV_N_OLD, IRQH_N_OLD;
	bit IRQS_N_OLD;
	bit IRQ1_N_OLD;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			IRQV_N_OLD <= 1;
			IRQH_N_OLD <= 1;
			IRQS_N_OLD <= 1;
			IRQ1_N_OLD <= 1;
		end
		else begin
			if (!RES_N) begin
				IRQV_N_OLD <= 1;
				IRQH_N_OLD <= 1;
			end else if (CE_R) begin
				IRQH_N_OLD <= IRQH_N;
				IRQV_N_OLD <= IRQV_N;
				IRQS_N_OLD <= IRQS_N;
				IRQ1_N_OLD <= IRQ1_N;
			end
		end
	end
	wire VBL_IN   = !IRQV_N &  IRQV_N_OLD;
	wire VBL_OUT  =  IRQV_N & !IRQV_N_OLD;
	wire HBL_IN   = !IRQH_N &  IRQH_N_OLD;
	wire SCSP_REQ = !IRQS_N &  IRQS_N_OLD;
	wire VDP1_REQ = !IRQ1_N &  IRQ1_N_OLD;
	
	//DMA & CPU access
	wire ABUS_SEL = (~CCS1_N | (CA[24:20] < 5'h19 & ~CCS2_N)) & (~CRD_N | ~&CDQM_N);				//02000000-058FFFFF
	wire BBUS_SEL = CA[24:16] >= 9'h1A0 & CA[24:16] < 9'h1FE & ~CCS2_N & (~CRD_N | ~&CDQM_N);	//05A00000-05FDFFFF
	bit         CBUS_WAIT;
	
	bit DMA_FACT[3];
	always_comb begin
		for (int i=0; i<3; i++) begin
			case (DMD[i].FT)
				3'b000: DMA_FACT[i] = VBL_IN;
				3'b001: DMA_FACT[i] = VBL_OUT;
				3'b010: DMA_FACT[i] = HBL_IN;
				3'b011: DMA_FACT[i] = TM0_INT;
				3'b100: DMA_FACT[i] = TM1_INT;
				3'b101: DMA_FACT[i] = SCSP_REQ;
				3'b110: DMA_FACT[i] = VDP1_REQ;
				3'b111: DMA_FACT[i] = DEN[i].GO;
			endcase
		end
	end
	
	bit  [31:0] AB_DO;
	
	bit         DMA_PEND[3];
	bit         DSP_DMA_PEND;
	bit         DMA_WORD;
	bit  [26:0] DMA_RADDR,DMA_WADDR;
//	bit   [1:0] DMA_BUF_WCNT,DMA_BUF_RCNT;
//	bit   [2:0] DMA_BUF_AMOUNT;
	bit   [7:0] DMA_BUF[4];
	wire [31:0] DMA_BUF_Q = {DMA_BUF[0],DMA_BUF[1],DMA_BUF[2],DMA_BUF[3]};
	bit   [3:0] DMA_BUF_BE;
	bit         DMA_LAST;
	
	wire [36:0] FIFO_DATA = {DMA_LAST,DMA_BUF_BE,DMA_BUF_Q};
	bit  [36:0] FIFO_Q;
	bit         FIFO_WRREQ;
	bit         FIFO_RDREQ;
	bit         FIFO_EMPTY;
	bit         FIFO_FULL;
	SCU_DMA_FIFO FIFO(CLK,FIFO_DATA,FIFO_WRREQ,FIFO_RDREQ,FIFO_Q,FIFO_EMPTY,FIFO_FULL);
	
	wire [31:0] DMA_WRITE_DATA = FIFO_Q[31:0];
	wire  [3:0] DMA_WRITE_BE = FIFO_Q[35:32];
	wire        DMA_WRITE_LAST = FIFO_Q[36];
	
//	bit  [31:0] DMA_WRITE_DATA;
//	bit   [3:0] DMA_WRITE_BE;
//	bit         DMA_WRITE_LAST;
//	bit         DMA_WRITE_PEND;
	
	always @(posedge CLK or negedge RST_N) begin
		bit         DMA_WE;
		bit   [1:0] DMA_BA;
		bit  [19:0] DMA_TN_NEXT;
		bit         DMA_IND;
		bit   [1:0] DMA_IND_REG;
		bit         DMA_DSP;
		bit         ABBUS_SEL_OLD;
		bit         ABUS_WORD;
		bit   [1:0] BBUS_WORD;
//		bit         AB_BUS_RD;
		bit         AB_WORD;
		bit         LAST, ALLOW, CLEAR;
				
		if (!RST_N) begin
			AA <= '0;
			ADO <= '0;
			AAS_N <= 1;
			ARD_N <= 1;
			AWRL_N <= 1;
			AWRU_N <= 1;
			ACS0_N <= 1;
			ACS1_N <= 1;
			ACS2_N <= 1;
			AFC <= '1;
			ATIM0_N <= 1;
			ATIM1_N <= 1;
			ATIM2_N <= 1;
			
			BDO <= '0;
			BADDT_N <= 1;
			BDTEN_N <= 1;
			BCS1_N <= 1;
			BCS2_N <= 1;
			BCSS_N <= 1;
			
			DSTA <= DSTA_INIT;
			
			DMA_RST <= DRS_IDLE;
			DMA_WST <= DWS_IDLE;
			DMA_RA <= '{'0,'0,'0};
			DMA_WA <= '{'0,'0,'0};
			DMA_IA <= '{'0,'0,'0};
			DMA_TN <= '{'0,'0,'0};
			DMA_CH <= '0;
			DMA_PEND <= '{0,0,0};
			DSP_DMA_PEND <= 0;
			DMA_RUN <= '{0,0,0};
			DMA_END <= 0;
			DMA_INT <= '0;
			DMAIL_INT <= 0;
			
			ABUS_A <= '0;
			BBUS_A <= '0;
			CBUS_CS <= 0;
			CBUS_RD <= 0;
			CBUS_WR <= '0;
			CBUS_A <= '0;
			CBUS_D <= '0;
			CBUS_REQ <= 0;
			CBUS_WAIT <= 0;
			
			CPU_ST <= CPUS_IDLE;
			CPU_BBUS_REQ <= 0;
			CPU_ABUS_REQ <= 0;
			ABBUS_SEL_OLD <= 0;
		end
		else if (!RES_N) begin
			DSTA <= DSTA_INIT;
			
			DMA_RST <= DRS_IDLE;
			DMA_WST <= DWS_IDLE;
			DMA_RA <= '{'0,'0,'0};
			DMA_WA <= '{'0,'0,'0};
			DMA_IA <= '{'0,'0,'0};
			DMA_TN <= '{'0,'0,'0};
			DMA_EC <= '{0,0,0};
			DMA_CH <= '0;
			DMA_PEND <= '{0,0,0};
			DMA_RUN <= '{0,0,0};
			DMA_END <= 0;
			DMA_INT <= '0;
			DMAIL_INT <= 0;
			
			ABUS_A <= '0;
			BBUS_A <= '0;
			CBUS_A <= '0;
			CBUS_D <= '0;
			CBUS_REQ <= 0;
			CBUS_REL <= 0;
			CBUS_WAIT <= 0;
			
			CPU_ST <= CPUS_IDLE;
			CPU_BBUS_REQ <= 0;
			CPU_ABUS_REQ <= 0;
			ABBUS_SEL_OLD <= 0;
			
			FIFO_WRREQ <= 0;
			FIFO_RDREQ <= 0;
		end
		else begin
			FIFO_WRREQ <= 0;
			FIFO_RDREQ <= 0;
			
//			if (FIFO_WRREQ) begin
//				DMA_WRITE_DATA <= DMA_BUF_Q;
//				DMA_WRITE_BE <= DMA_BUF_BE;
//				DMA_WRITE_LAST <= DMA_LAST;
//				DMA_WRITE_PEND <= 1;
//			end
			
			BREQ_N <= 1;
			
			if (CE_R) begin
			DMA_RADDR = DMA_DSP /*&& !DSP_DMA_WE*/ ? {DSP_DMA_A,2'b00} : DMA_IND ? DMA_IA[DMA_CH] : DMA_RA[DMA_CH];
			DMA_WADDR = DMA_DSP /*&&  DSP_DMA_WE*/ ? {DSP_DMA_A,2'b00} : DMA_WA[DMA_CH];
			
			ABBUS_SEL_OLD <= ABUS_SEL | BBUS_SEL;
			if ((ABUS_SEL || BBUS_SEL) && !ABBUS_SEL_OLD && !CBUS_WAIT) CBUS_WAIT <= 1;
			if (!ABUS_SEL && CPU_ABUS_REQ) CPU_ABUS_REQ <= 0;
			if (!BBUS_SEL && CPU_BBUS_REQ) CPU_BBUS_REQ <= 0;
			end
			
			case (CPU_ST)
				CPUS_IDLE : if (CE_R) begin
					if (ABUS_SEL && !CPU_ABUS_REQ && !DSTA.DACSA) begin	//A-BUS 02000000-058FFFFF
						ABUS_A <= !CCS1_N ? {2'b01,CA[24:0]} : {2'b10,CA[24:0]};
						CPU_ABUS_REQ <= 1;
						CPU_ST <= CPUS_ABUS_ACCESS;
					end
					
					if (BBUS_SEL && !CPU_BBUS_REQ && !DSTA.DACSB) begin	//B-BUS 05A00000-05FDFFFF
						BBUS_A <= {CA[22:1],1'b0};
						BBUS_WORD <= {~&CDQM_N[3:2],~&CDQM_N[1:0]} | {2{~CRD_N}};
						CPU_BBUS_REQ <= 1;
						CPU_ST <= CPUS_BBUS_ADDR1;
					end
				end
				
				//A-BUS
				CPUS_ABUS_ADDR: if (CE_R) begin
					casez (ABUS_A[26:24])
						3'b0??: ACS0_N <= 0;
						3'b100: ACS1_N <= 0;
						default: ACS2_N <= 0;
					endcase
					AA <= ABUS_A[25:0];
					AAS_N <= 0;
					CPU_ST <= CPUS_ABUS_ACCESS;
				end
				
				CPUS_ABUS_ACCESS: if (CE_R) begin
					casez (ABUS_A[26:24])
						3'b0??: ACS0_N <= 0;
						3'b100: ACS1_N <= 0;
						default: ACS2_N <= 0;
					endcase
					AA <= ABUS_A[25:0];
					AAS_N <= 0;
					if ((!(&CDQM_N[3:2]) || !CRD_N) && !ABUS_WORD) begin
						ADO <= CDI[31:16];
						ARD_N <= CRD_N;
						AWRL_N <= CDQM_N[2];
						AWRU_N <= CDQM_N[3];
						ABUS_WORD <= ~&CDQM_N[1:0] | (CA[24:20] == 5'h18 & ~CA[19] & ~CCS2_N & ~CRD_N);
					end else begin
						ADO <= CDI[15:0];
						ARD_N <= CRD_N;
						AWRL_N <= CDQM_N[0];
						AWRU_N <= CDQM_N[1];
						ABUS_WORD <= 0;
					end
					CPU_ST <= CPUS_ABUS_WAIT;
					DBG_WAIT_CNT <= '0;
				end
					
//				CPUS_ABUS_ACCESS2: begin
//					CPU_ST <= CPUS_ABUS_WAIT;
//				end
				
				CPUS_ABUS_WAIT: if (CE_R) begin
					AAS_N <= 1;
					if (AWAIT_N) begin
						ARD_N <= 1;
						AWRL_N <= 1;
						AWRU_N <= 1;
						ACS0_N <= 1;
						ACS1_N <= 1;
						ACS2_N <= 1;
						if (!ABUS_A[1]) AB_DO[31:16] <= ADI;
						else            AB_DO[15: 0] <= ADI;
						if (ABUS_WORD) begin
							ABUS_A[1] <= 1;
							CPU_ST <= CPUS_ABUS_ACCESS;
						end else begin
							CBUS_WAIT <= 0;
							CPU_ST <= CPUS_IDLE;
						end
					end
					DBG_WAIT_CNT <= DBG_WAIT_CNT + 1'd1;
				end
				
				//B-BUS
				CPUS_BBUS_ADDR1: if (CE_R) begin
					//if ((BBUS_A[22:21] == 2'b01 && !BRDYS_N) || (BBUS_A[22:21] == 2'b10 && !BRDY1_N) || (BBUS_A[22:21] == 2'b11 && !BRDY2_N)) begin
					case (BBUS_A[22:21])
						2'b01: BCSS_N <= 0;
						2'b10: BCS1_N <= 0;
						2'b11: BCS2_N <= 0;
					endcase
					BDO <= {1'b0,&CDQM_N,2'b00,BBUS_A[20:9]};
					BDTEN_N <= 1;
					BADDT_N <= 1;
					BREQ_N <= 0;
					CPU_ST <= CPUS_BBUS_ADDR2;
					//end
				end
				
				CPUS_BBUS_ADDR2: if (CE_R) begin
					if (!CRD_N) 
						BDO <= {2'b10,2'b00,4'b0000,BBUS_A[8:1]};
					else if (!(&CDQM_N[3:2])) 
						BDO <= {2'b10,CDQM_N[3:2],4'b0000,BBUS_A[8:1]};
					else
						BDO <= {2'b10,CDQM_N[1:0],4'b0000,BBUS_A[8:1]};
					BDTEN_N <= 1;
					BADDT_N <= 1;
					BREQ_N <= 0;
					CPU_ST <= !CRD_N ? CPUS_BBUS_READ : CPUS_BBUS_WRITE;
				end
				
				CPUS_BBUS_WRITE: if (CE_R) begin
					if ((!BCSS_N && !BRDYS_N) || (!BCS1_N && !BRDY1_N) || (!BCS2_N && !BRDY2_N)) begin
					if (BBUS_WORD[1]) begin
						BDO <= CDI[31:16];
					end else begin
						BDO <= CDI[15:0];
					end
					BDTEN_N <= 0;
					BADDT_N <= 0;
					BREQ_N <= 0;
					
//					BBUS_WORD[1] <= 0;
//					if (BBUS_WORD[1] && BBUS_WORD[0]) begin
//						BBUS_A[1] <= 1;
//						CPU_ST <= CPUS_BBUS_ADDR1;
//					end else begin
//						CBUS_WAIT <= 0;
						CPU_ST <= CPUS_BBUS_WRITE_END;
//					end
					DBG_WAIT_CNT <= '0;
					end
				end
				
				CPUS_BBUS_WRITE_END: if (CE_R) begin
					if ((!BCSS_N && !BRDYS_N) || (!BCS1_N && !BRDY1_N) || (!BCS2_N && !BRDY2_N)) begin
					BDTEN_N <= 1;
					BADDT_N <= 1;
					
					BBUS_WORD[1] <= 0;
					if (BBUS_WORD[1] && BBUS_WORD[0]) begin
						BBUS_A[1] <= 1;
						CPU_ST <= CPUS_BBUS_ADDR1;
					end else begin
						BCSS_N <= 1;
						BCS1_N <= 1;
						BCS2_N <= 1;
						CBUS_WAIT <= 0;
						CPU_ST <= CPUS_IDLE;
					end
					
//					CPU_ST <= CPUS_IDLE;
					end
				end
				
				CPUS_BBUS_READ: if (CE_R) begin
					BDTEN_N <= 0;
					BADDT_N <= 0;
					BREQ_N <= 0;
					
					CPU_ST <= CPUS_BBUS_READ_WAIT;
					DBG_WAIT_CNT <= '0;
				end
					
				CPUS_BBUS_READ_WAIT: if (CE_R) begin
					if ((!BCSS_N && !BRDYS_N) || (!BCS1_N && !BRDY1_N) || (!BCS2_N && !BRDY2_N)) begin
						BDTEN_N <= 1;
						BADDT_N <= 1;
						BCSS_N <= 1;
						BCS1_N <= 1;
						BCS2_N <= 1;
						if (BBUS_WORD[1]) AB_DO[31:16] <= BDI;
						else              AB_DO[15: 0] <= BDI;
						
						BBUS_WORD[1] <= 0;
						if (BBUS_WORD[1] && BBUS_WORD[0]) begin
							BBUS_A[1] <= 1;
							CPU_ST <= CPUS_BBUS_ADDR1;
						end else begin
							CBUS_WAIT <= 0;
							CPU_ST <= CPUS_IDLE;
						end
					end
					DBG_WAIT_CNT <= DBG_WAIT_CNT + 1'd1;
				end
			endcase
			
			if (CE_R) begin
			DMAIL_INT <= 0;
			DSP_DMA_ACK <= 0;
			if (CBUS_REQ && CE_R) CBUS_REQ <= 0;
			if (CBUS_REL && CE_R) CBUS_REL <= 0;
			
			if (DMA_FACT[0] && DEN[0].EN && !DMA_PEND[0]) begin DMA_PEND[0] <= 1; DSTA.D0WT <= 1; end
			if (DMA_FACT[1] && DEN[1].EN && !DMA_PEND[1]) begin DMA_PEND[1] <= 1; DSTA.D1WT <= 1; end
			if (DMA_FACT[2] && DEN[2].EN && !DMA_PEND[2]) begin DMA_PEND[2] <= 1; DSTA.D2WT <= 1; end
			if (DSP_DMA_REQ && !DSP_DMA_PEND) begin DSP_DMA_PEND <= 1; DSTA.DDWT <= 1; end
			end
			
//			DMA_TN_NEXT = DMA_TN[DMA_CH] - (AB_BUS_RD ? 20'd2 : 20'd4);
			case (DMA_RST)
				DRS_IDLE: if (CE_R) begin
					DSTA.D0MV <= 0;//?
					DSTA.D1MV <= 0;//?
					DSTA.D2MV <= 0;//?
					DSTA.DDMV <= 0;//?
					if (DSP_DMA_PEND) begin
						DSP_DMA_PEND <= 0;;
						DMA_DSP <= 1;
						DMA_RST <= !DSP_DMA_WE ? DRS_DMA_START : DRS_DMA_DSP_WRITE;
						DSTA.DDWT <= 0;
						DSTA.DDMV <= 1;
					end else if (DMA_PEND[0]) begin
						DMA_PEND[0] <= 0;
						DMA_CH <= 2'd0;
						DMA_RUN[0] <= 1;
						DMA_RST <= DRS_DMA_INIT;
						DSTA.D0WT <= 0;
						DSTA.D0MV <= 1;
					end else if (DMA_PEND[1]) begin
						DMA_PEND[1] <= 0;
						DMA_CH <= 2'd1;
						DMA_RUN[1] <= 1;
						DMA_RST <= DRS_DMA_INIT;
						DSTA.D1WT <= 0;
						DSTA.D1MV <= 1;
					end else if (DMA_PEND[2]) begin
						DMA_PEND[2] <= 0;
						DMA_CH <= 2'd2;
						DMA_RUN[2] <= 1;
						DMA_RST <= DRS_DMA_INIT;
						DSTA.D2WT <= 0;
						DSTA.D2MV <= 1;
					end
				end
				
				DRS_DMA_INIT: if (CE_R) begin
					if (!DMD[DMA_CH].MOD) begin
						DMA_RA[DMA_CH] <= DR[DMA_CH];
						DMA_WA[DMA_CH] <= DW[DMA_CH];
						DMA_TN[DMA_CH] <= DC[DMA_CH];
							
//						DMA_BA <= DW[DMA_CH][1:0];
						DMA_LAST <= 0;
						DMA_IND <= 0;
						DMA_RST <= DRS_DMA_START;
					end else begin
						DMA_IA[DMA_CH] <= DW[DMA_CH];

//						DMA_BA <= '0;
						DMA_IND <= 1;
						DMA_IND_REG <= 2'd0;
						DMA_RST <= DRS_DMA_IND_READ;
					end
				end
				
				DRS_DMA_IND_READ: if (CE_R) begin
					ADDR_ERR_DBG <= 1;//debug
					if (DMA_RADDR[26:24] == 3'h6 && CE_R) begin	//C-BUS 06000000-07FFFFFF
						CBUS_REQ <= 1;
						DMA_BA <= '0;
						DMA_RST <= DRS_CBUS_REQUEST;
						ADDR_ERR_DBG <= 0;//debug
					end;
				end
				
				DRS_DMA_IND: if (CE_R) begin
					case (DMA_IND_REG)
						2'd0: DMA_TN[DMA_CH] <= DMA_BUF_Q[19:0];
						2'd1: DMA_WA[DMA_CH] <= DMA_BUF_Q[26:0];
						2'd2: {DMA_EC[DMA_CH],DMA_RA[DMA_CH]} <= {DMA_BUF_Q[31],DMA_BUF_Q[26:0]};
					endcase
					if (DMA_IND_REG < 2'd2) begin
						DMA_IND_REG <= DMA_IND_REG + 2'd1;
//						DMA_BA <= '0;
						DMA_IND <= 1;
						DMA_RST <= DRS_DMA_IND_READ;
					end else begin
//						DMA_BA <= DMA_RA[DMA_CH][1:0];
						DMA_LAST <= 0;
						DMA_IND <= 0;
						DMA_RST <= DRS_DMA_START;
					end
				end
				
				DRS_DMA_START: if (CE_R) begin
//					AB_BUS_RD <= 0;
					ADDR_ERR_DBG <= 1;//debug
					DMA_RST <= DRS_DMA_END;
					if (DMA_RADDR[26:20] >= 7'h20 && DMA_RADDR[26:20] < 7'h59 && !ABUS_SEL) begin	//A-BUS 02000000-058FFFFF
						DSTA.DACSA <= 1;
//						AB_BUS_RD <= 1;
						DMA_RST <= DRS_ABUS_READ;
						ADDR_ERR_DBG <= 0;//debug
					end
					if (DMA_RADDR[26:16] >= 11'h5A0 && DMA_RADDR[26:16] < 11'h5FE && !BBUS_SEL) begin	//B-BUS 05A00000-05FDFFFF
						DSTA.DACSB <= 1;
//						AB_BUS_RD <= 1;
						DMA_RST <= DRS_BBUS_ADDR1;
						ADDR_ERR_DBG <= 0;//debug
					end
					if (DMA_RADDR[26:24] == 3'h6 && CE_R) begin	//C-BUS 06000000-07FFFFFF
						CBUS_REQ <= 1;
						DMA_RST <= DRS_CBUS_REQUEST;
						ADDR_ERR_DBG <= 0;//debug
					end
					DMA_BA <= DMA_RADDR[1:0];
				end
				
				//A-BUS
				DRS_ABUS_ADDR: if (CE_R) begin
					if (!FIFO_FULL) begin
						casez (DMA_RADDR[26:24])
							3'b0??: ACS0_N <= 0;
							3'b100: ACS1_N <= 0;
							default: ACS2_N <= 0;
						endcase
						AA <= DMA_RADDR[25:0];
						AAS_N <= 0;
						DMA_RST <= DRS_ABUS_READ;
					end
				end
				
				DRS_ABUS_READ: if (CE_R) begin
					if (!FIFO_FULL) begin
						casez (DMA_RADDR[26:24])
							3'b0??: ACS0_N <= 0;
							3'b100: ACS1_N <= 0;
							default: ACS2_N <= 0;
						endcase
						AA <= DMA_RADDR[25:0];
						AAS_N <= 0;
						AAS_N <= 1;
						ARD_N <= 0;
						AWRL_N <= 1;
						AWRU_N <= 1;
						DMA_RST <= DRS_ABUS_WAIT;
					end
				end
					
				DRS_ABUS_WAIT: if (CE_R) begin
					AAS_N <= 1;
					if (AWAIT_N) begin
						ARD_N <= 1;
						AWRL_N <= 1;
						AWRU_N <= 1;
						ACS0_N <= 1;
						ACS1_N <= 1;
						ACS2_N <= 1;
						DMA_BUF[DMA_BA+2'd0] <= ADI[15: 8];
						DMA_BUF[DMA_BA+2'd1] <= ADI[ 7: 0];
						DMA_BA <= DMA_BA + 2'd2;
						if (!DMA_BA) DMA_BUF_BE[3:2] <= 2'b11;
						if ( DMA_BA) DMA_BUF_BE[1:0] <= 2'b11;
						
						if (DMA_DSP) begin
							if (!DMA_BA) begin
								DMA_RST <= DRS_ABUS_READ;
							end else begin
								FIFO_WRREQ <= 1;
//								DMA_DSP <= 0;
								DMA_END <= 1;
								DMA_RST <= DRS_DMA_END;
							end
						end else begin
							DMA_TN_NEXT = (DMA_TN[DMA_CH] - 20'd2) & DMA_TN_MASK[DMA_CH];
							DMA_TN[DMA_CH] <= DMA_TN_NEXT;
							if (!DMA_TN_NEXT) begin
								DSTA.DACSA <= 0;
								if (!DMD[DMA_CH].MOD || DMA_EC[DMA_CH]) begin
									DMA_END <= 1;
									DMA_RST <= DRS_DMA_END;
								end else begin
									DMA_IND <= 1;
									DMA_IND_REG <= 2'd0;
									DMA_RST <= DRS_DMA_END;
								end
								DMA_LAST <= 1;
								FIFO_WRREQ <= 1;
							end else begin
								if (DAD[DMA_CH].DRA) 
									DMA_RA[DMA_CH] <= DMA_RA[DMA_CH] + 27'd2;
								FIFO_WRREQ <= |DMA_BA;
								DMA_RST <= DRS_ABUS_ADDR;
							end
						end
					end
				end
				
				//B-BUS
				DRS_BBUS_ADDR1: if (CE_R) begin
					case (DMA_RADDR[22:21])
						2'b01: BCSS_N <= 0;
						2'b10: BCS1_N <= 0;
						2'b11: BCS2_N <= 0;
					endcase
					BDO <= {4'b0111,DMA_RADDR[20:9]};
					BDTEN_N <= 1;
					BADDT_N <= 1;
					BREQ_N <= 0;
					DMA_RST <= DRS_BBUS_ADDR2;
				end
				
				DRS_BBUS_ADDR2: if (CE_R) begin
					BDO <= {4'b1000,4'b0000,DMA_RADDR[8:1]};
					BDTEN_N <= 1;
					BADDT_N <= 1;
					BREQ_N <= 0;
					DMA_RST <= DRS_BBUS_READ;
				end
				
				DRS_BBUS_READ: begin
					if (!FIFO_FULL/*DMA_WRITE_PEND*/) begin
						BDTEN_N <= 0;
						BADDT_N <= 0;
						BREQ_N <= 0;
						DMA_RST <= DRS_BBUS_WAIT;
					end
				end
					
				DRS_BBUS_WAIT: if (CE_R) begin
					if ((!BCSS_N && !BRDYS_N) || (!BCS1_N && !BRDY1_N) || (!BCS2_N && !BRDY2_N)) begin
						BDTEN_N <= 1;
						BADDT_N <= 1;
						DMA_BUF[DMA_BA+2'd0] <= BDI[15: 8];
						DMA_BUF[DMA_BA+2'd1] <= BDI[ 7: 0];
						DMA_BA <= DMA_BA + 2'd2;
						if (!DMA_BA) DMA_BUF_BE[3:2] <= 2'b11;
						if ( DMA_BA) DMA_BUF_BE[1:0] <= 2'b11;
							
						if (DMA_DSP) begin
							if (!DMA_BA) begin
								DMA_RST <= DRS_BBUS_READ;
							end else begin
								FIFO_WRREQ <= 1;
//								DMA_DSP <= 0;
								DMA_END <= 1;
								DMA_RST <= DRS_DMA_END;
							end
						end else begin
							DMA_TN_NEXT = (DMA_TN[DMA_CH] - 20'd2) & DMA_TN_MASK[DMA_CH];
							DMA_TN[DMA_CH] <= DMA_TN_NEXT;
							if (!DMA_TN_NEXT) begin
								BCSS_N <= 1;
								BCS1_N <= 1;
								BCS2_N <= 1;
								DSTA.DACSB <= 0;
								if (!DMD[DMA_CH].MOD || DMA_EC[DMA_CH]) begin
									DMA_END <= 1;
									DMA_RST <= DRS_DMA_END;
								end else begin
									DMA_IND <= 1;
									DMA_IND_REG <= 2'd0;
									DMA_RST <= DRS_DMA_END;
								end
								DMA_LAST <= 1;
								FIFO_WRREQ <= 1;
							end else begin
								if (DAD[DMA_CH].DRA) 
									DMA_RA[DMA_CH] <= DMA_RA[DMA_CH] + 27'd2;
								FIFO_WRREQ <= |DMA_BA;
								DMA_RST <= DRS_BBUS_READ;
							end	
						end
					end
				end
				
				//C-BUS
				DRS_CBUS_REQUEST: begin
					if (!CBRLS && CE_R) begin
						DMA_RST <= DRS_CBUS_READ;
					end
				end
				
				DRS_CBUS_READ: begin
					if (!FIFO_FULL && CE_R) begin
						CBUS_A <= DMA_RADDR[26:0];
						CBUS_RD <= 1;
						CBUS_CS <= 1;
						DMA_RST <= DRS_CBUS_WAIT;
					end
				end
				
				DRS_CBUS_WAIT: begin
					if (ECWAIT_N && CE_R) begin
						CBUS_RD <= 0;
						DMA_BUF[2'd0] <= ECDI[31:24];
						DMA_BUF[2'd1] <= ECDI[23:16];
						DMA_BUF[2'd2] <= ECDI[15: 8];
						DMA_BUF[2'd3] <= ECDI[ 7: 0];
						DMA_BUF_BE <= 4'b1111;
						if (DMA_BA) 
							case (DMA_BA)
								2'b00: ;
								2'b01: DMA_BUF_BE[3:3] <= 1'b0;
								2'b10: DMA_BUF_BE[3:2] <= 2'b00;
								2'b11: DMA_BUF_BE[3:1] <= 3'b000;
							endcase
						if (!DMA_TN[DMA_CH][19:2]) 
							case (DMA_TN[DMA_CH][1:0])
								2'b00: ;
								2'b01: DMA_BUF_BE[2:0] <= 3'b000;
								2'b10: DMA_BUF_BE[1:0] <= 2'b00;
								2'b11: DMA_BUF_BE[0:0] <= 1'b0;
							endcase
						DMA_BA <= 2'd0;
						
						if (DMA_IND) begin
							DMA_IA[DMA_CH] <= DMA_IA[DMA_CH] + 27'd4;
							CBUS_REL <= 1;
							DMA_RST <= DRS_DMA_IND;
						end else if (DMA_DSP) begin
							FIFO_WRREQ <= 1;
//							DMA_DSP <= 0;
							DMA_END <= 1;
							DMA_RST <= DRS_DMA_END;
						end else begin
							if (!DMA_TN[DMA_CH][19:2]) DMA_TN_NEXT = 20'd0;
							else                       DMA_TN_NEXT = (DMA_TN[DMA_CH] - 20'd4) & DMA_TN_MASK[DMA_CH];
							DMA_TN[DMA_CH] <= DMA_TN_NEXT;
							if (!DMA_TN_NEXT) begin
								DMA_LAST <= 1;
								CBUS_REL <= 1;
								CBUS_CS <= 0;
								if (!DMD[DMA_CH].MOD || DMA_EC[DMA_CH]) begin
									DMA_END <= 1;
									DMA_RST <= DRS_DMA_END;
								end else begin
									DMA_IND <= 1;
									DMA_IND_REG <= 2'd0;
									DMA_RST <= DRS_DMA_END;
								end
								FIFO_WRREQ <= 1;
							end else begin
								DMA_RA[DMA_CH][1:0] <= '0;
								if (DAD[DMA_CH].DRA) 
									DMA_RA[DMA_CH][26:2] <= DMA_RA[DMA_CH][26:2] + 1'd1;
								FIFO_WRREQ <= 1;
								DMA_RST <= DRS_CBUS_READ;
							end
						end
					end
				end
				
				DRS_DMA_DSP_WRITE: if (CE_R) begin
					DSP_DMA_ACK <= 1;
					DMA_DSP <= 0;
					DMA_BUF[2'd0] = DSP_DMA_DO[31:24];
					DMA_BUF[2'd1] = DSP_DMA_DO[23:16];
					DMA_BUF[2'd2] = DSP_DMA_DO[15: 8];
					DMA_BUF[2'd3] = DSP_DMA_DO[ 7: 0];
					DMA_BUF_BE <= 4'b1111;
					DMA_LAST <= 1;
					FIFO_WRREQ <= 1;
					DSTA.DACSD <= 1;
					DMA_RST <= DRS_IDLE;
				end
				
				DRS_DMA_END: if (CE_R) begin
					if (DMA_WST == DWS_END) begin
						if (DMA_END) begin
							DMA_END <= 0;
							DMA_RUN[DMA_CH] <= 0;
							DMA_INT[DMA_CH] <= 1;
							DMA_DSP <= 0;
							DMA_RST <= DRS_IDLE;
						end 
						if (DMA_IND) begin
							DMA_RST <= DRS_DMA_IND_READ;
						end
					end
				end
			endcase
			
			case (DMA_WST)
				DWS_IDLE: if (CE_R) begin
					if (!FIFO_EMPTY/*DMA_WRITE_PEND*/) begin
						AB_WORD <= ~|DMA_WRITE_BE/*FIFO_Q_BE*/[3:2];
						ADDR_ERR_DBG <= 1;//debug
						if (DMA_DSP && !DSP_DMA_WE) begin
							DMA_WST <= DWS_DSP_WAIT;
//						end else if (DMA_WADDR[26:20] >= 7'h20 && DMA_WADDR[26:20] < 7'h59 && !ABUS_SEL) begin	//A-BUS 02000000-058FFFFF
//							DSTA.DACSA <= 1;
//							DMA_WST <= DWS_ABUS_ADDR;
//							ADDR_ERR_DBG <= 0;//debug
						end else if (DMA_WADDR[26:16] >= 11'h5A0 && DMA_WADDR[26:16] < 11'h5FE && !BBUS_SEL) begin	//B-BUS 05A00000-05FDFFFF
							DSTA.DACSB <= 1;
							DMA_WST <= DWS_BBUS_ADDR1;
							ADDR_ERR_DBG <= 0;//debug
						end else if (DMA_WADDR[26:24] == 3'h6 && CE_R) begin	//C-BUS 06000000-07FFFFFF
							CBUS_REQ <= 1;
							DMA_WST <= DWS_CBUS_REQUEST;
							ADDR_ERR_DBG <= 0;//debug
						end
					end
				end
				
				//DSP BUS
				DWS_DSP_WAIT: if (CE_R) begin
					DSP_DMA_ACK <= 1;
					DMA_WST <= DWS_END;
				end
				
//				//A-BUS
//				DWS_ABUS_ADDR: if (CE_R) begin
//					if (!FIFO_EMPTY/*DMA_WRITE_PEND*/) begin
//						casez (DMA_WADDR[26:24])
//							3'b0??: ACS0_N <= 0;
//							3'b100: ACS1_N <= 0;
//							default: ACS2_N <= 0;
//						endcase
//						AA <= DMA_WADDR[25:0];
//						AAS_N <= 0;
//						DMA_WST <= DWS_ABUS_WRITE;
//					end
//				end
//				
//				DWS_ABUS_WRITE: if (CE_R) begin
//					AAS_N <= 1;
//					ADO <= !AB_WORD ? DMA_WRITE_DATA[31:16] : DMA_WRITE_DATA[15:0];//FIFO_Q_DATA
//					ARD_N <= 1;
//					AWRL_N <= 0;
//					AWRU_N <= 0;
//					AB_WORD <= ~AB_WORD;
//					if (AB_WORD || !DMA_WRITE_BE[1:0]) FIFO_RDREQ <= 1;//DMA_WRITE_PEND <= 0;
//					LAST <= DMA_WRITE_LAST && (AB_WORD || !DMA_WRITE_BE[1:0]);
//					DMA_WST <= DWS_ABUS_WAIT;
//				end
//					
//				DWS_ABUS_WAIT: if (CE_R) begin
//					if (AWAIT_N) begin
//						if (DAD[DMA_CH].DWA)
//							DMA_WA[DMA_CH] <= DMA_WA[DMA_CH] + (27'd1 << DAD[DMA_CH].DWA);
//							
//						ARD_N <= 1;
//						AWRL_N <= 1;
//						AWRU_N <= 1;
//						ACS0_N <= 1;
//						ACS1_N <= 1;
//						ACS2_N <= 1;
//						if (!LAST) begin
//							DMA_WST <= DWS_ABUS_ADDR;
//						end else begin
//							DSTA.DACSA <= 0;
//							DMA_WST <= DWS_END;
//						end
//					end
//				end
				
				//B-BUS
				DWS_BBUS_ADDR1: if (CE_R) begin
					case (DMA_WADDR[22:21])
						2'b01: BCSS_N <= 0;
						2'b10: BCS1_N <= 0;
						2'b11: BCS2_N <= 0;
					endcase
					BDO <= {4'b0011,DMA_WADDR[20:9]};
					BDTEN_N <= 1;
					BADDT_N <= 1;
					BREQ_N <= 0;
					DMA_WST <= DWS_BBUS_ADDR2;
				end
				
				DWS_BBUS_ADDR2: if (CE_R) begin
					BDO <= {4'b1000,4'b0000,DMA_WADDR[8:1]};
					BDTEN_N <= 1;
					BADDT_N <= 1;
					BREQ_N <= 0;
					DMA_WST <= DWS_BBUS_WRITE;
				end
				
				DWS_BBUS_WRITE: if (CE_R) begin
					if (!FIFO_EMPTY) begin
						BDO <= !AB_WORD ? DMA_WRITE_DATA[31:16] : DMA_WRITE_DATA[15:0];//FIFO_Q_DATA
						BDTEN_N <= 0;
						BADDT_N <= 0;
						BREQ_N <= 0;
						FIFO_RDREQ <= (AB_WORD || !DMA_WRITE_BE[1:0]);
						AB_WORD <= ~AB_WORD;
//						if (AB_WORD || !DMA_WRITE_BE[1:0]) DMA_WRITE_PEND <= 0;
						LAST <= DMA_WRITE_LAST && (AB_WORD || !DMA_WRITE_BE[1:0]);
						DMA_WST <= DWS_BBUS_WAIT;
					end
				end
					
				DWS_BBUS_WAIT: /*if (CE_F) begin
					CLEAR <= 0;
					if (!FIFO_EMPTY && !ALLOW) begin
						AB_WORD <= ~AB_WORD;
//						if (AB_WORD || !DMA_WRITE_BE[1:0]) 
//							DMA_WRITE_PEND <= 0;//CLEAR <= 1;
						LAST <= DMA_WRITE_LAST && (AB_WORD || !DMA_WRITE_BE[1:0]);
						ALLOW <= 1;
					end
				end else*/ if (CE_R) begin
					if (((!BCSS_N && !BRDYS_N) || (!BCS1_N && !BRDY1_N) || (!BCS2_N && !BRDY2_N)) && (!FIFO_EMPTY || LAST)) begin
						if (DAD[DMA_CH].DWA)
							DMA_WA[DMA_CH] <= DMA_WA[DMA_CH] + (27'd1 << DAD[DMA_CH].DWA);
							
						if (!LAST) begin
							BDO <= !AB_WORD ? DMA_WRITE_DATA[31:16] : DMA_WRITE_DATA[15:0];
							BDTEN_N <= 0;
							BADDT_N <= 0;
							BREQ_N <= 0;
							FIFO_RDREQ <= (AB_WORD || !DMA_WRITE_BE[1:0]);
							AB_WORD <= ~AB_WORD;
							LAST <= DMA_WRITE_LAST && (AB_WORD || !DMA_WRITE_BE[1:0]);
						end else begin
							BDTEN_N <= 1;
							BADDT_N <= 1;
							BCSS_N <= 1;
							BCS1_N <= 1;
							BCS2_N <= 1;
							DSTA.DACSB <= 0;
							DMA_WST <= DWS_END;
						end
					end
				end
				
				//C-BUS
				DWS_CBUS_REQUEST: if (CE_R) begin
					if (!CBRLS) begin
						DMA_WST <= DWS_CBUS_WRITE;
					end
				end
				
				DWS_CBUS_WRITE: if (CE_R) begin
					if (!FIFO_EMPTY/*DMA_WRITE_PEND*/) begin
						CBUS_A <= DMA_WADDR[26:0];
						CBUS_D <= DMA_WRITE_DATA;//FIFO_Q_DATA;
						CBUS_WR <= DMA_WRITE_BE;//FIFO_Q_BE;
						CBUS_CS <= 1;
						FIFO_RDREQ <= 1;//DMA_WRITE_PEND <= 0;
						LAST <= DMA_WRITE_LAST;
						DMA_WST <= DWS_CBUS_WAIT;
					end
				end
				
				DWS_CBUS_WAIT: if (CE_R) begin
					if (ECWAIT_N) begin
						if (DAD[DMA_CH].DWA)
							DMA_WA[DMA_CH] <= DMA_WA[DMA_CH] + (27'd1 << DAD[DMA_CH].DWA);
							
						CBUS_CS <= 0;
						CBUS_WR <= '0;
						if (!LAST) begin
							DMA_WST <= DWS_CBUS_WRITE;
						end else begin
							CBUS_REL <= 1;
							DMA_WST <= DWS_END;
						end
					end
				end
				
				DWS_END: if (CE_R) begin
					DMA_WST <= DWS_IDLE;
				end
			endcase
			
			
			AFC <= '1;
			ATIM0_N <= 1;
			ATIM1_N <= 1;
			ATIM2_N <= 1;
			
			if (CE_R) begin
			if (REG_WR && CA[7:2] == 8'h60>>2) begin				//DSTP
				if (CDI[0]) begin
					DMA_END <= 0;
					DMA_RUN[0] <= 0;
					DMA_RUN[1] <= 0;
					DMA_RUN[2] <= 0;
					DMA_INT <= '0;
					DMA_RST <= DRS_IDLE;
				end
			end else if (REG_WR && CA[7:2] == 8'hA4>>2) begin	//IST
				if (!CDI[9])  DMA_INT[2] <= 0;
				if (!CDI[10]) DMA_INT[1] <= 0;
				if (!CDI[11]) DMA_INT[0] <= 0;
			end
			end
			
			if (VECT_RD && CE_F) begin	
				case (CA[3:0])
					4'h6: begin DMA_INT[1] <= 0; DMA_INT[2] <= 0; end
					4'h5: begin DMA_INT[0] <= 0; end
					default:;
				endcase
			end
		end
	end
	assign DBG_DMA_RADDR = DMA_RADDR;
	assign DBG_DMA_WADDR = DMA_WADDR;
	
	
	bit CBRLS;
	bit CBREQ;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			CBREQ <= 0;
			CBRLS <= 1;
		end
		else if (!RES_N) begin
			CBREQ <= 0;
			CBRLS <= 1;
		end
		else begin
			if (!RES_N) begin
				CBREQ <= 0;
				CBRLS <= 1;
			end
			else if (CE_F) begin
				if (CBUS_REQ && !CBREQ &&  CBRLS) begin
					CBREQ <= 1;
				end
				else if (CBREQ && !CBACK_N && CBRLS) begin
					CBRLS <= 0;
				end
				else if (CBREQ && CBUS_REL && !CBRLS) begin
					CBREQ <= 0;
				end
				else if (!CBREQ && !CBRLS) begin
					CBRLS <= 1;
				end
			end
		end
	end
	assign CBREQ_N = ~CBREQ;
	
				
	assign ECA = CBUS_A[24:0];
	assign ECDO = CBUS_D;
	assign ECDQM_N = ~CBUS_WR;
	assign ECRD_WR_N = ~|CBUS_WR;
	assign ECRD_N = ~CBUS_RD;
	assign ECCS3_N = ~CBUS_CS;
	
	//DSP
	bit DSP_CE;
	always @(posedge CLK) if (CE_R) DSP_CE <= ~DSP_CE;
	
	wire DSP_SEL = ~CCS2_N & CA[24:0] >= 25'h1FE0080 & CA[24:0] <= 25'h1FE008F;	//25FE0080-25FE008F
	
	bit [31:0] DSP_DO;
	SCU_DSP dsp(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE(DSP_CE & CE_R),
		
		.CE_R(CE_R),
		.CE_F(CE_F),
		.A(CA[3:2]),
		.DI(CDI),
		.DO(DSP_DO),
		.WE(DSP_SEL & CWE),
		.RE(DSP_SEL & CRE),
		
		.DMA_A(DSP_DMA_A),
		.DMA_DI(DSP_DMA_DI),
		.DMA_DO(DSP_DMA_DO),
		.DMA_WE(DSP_DMA_WE),
		.DMA_REQ(DSP_DMA_REQ),
		.DMA_ACK(DSP_DMA_ACK),
		
		.IRQ(DSP_IRQ)
	);
	
	assign DSP_DMA_DI = DMA_BUF_Q;
	
	//Timers
	bit [9:0] TM0;
	bit [8+2:0] TM1;
	always @(posedge CLK or negedge RST_N) begin
		bit TM0_OCCUR;
		
		if (!RST_N) begin
			TM0 <= '0;
			TM1 <= '0;
			TM0_INT <= 0;
			TM1_INT <= 0;
			TM0_OCCUR <= 0;
		end
		else if (!RES_N) begin
			TM0 <= '0;
			TM1 <= '0;
			TM0_INT <= 0;
			TM1_INT <= 0;
		end else if (CE_R) begin				
			if (T1MD.ENB) begin
				TM1 <= TM1 - 11'd1;
				if (!TM1 && TM0_OCCUR)  begin
					TM1_INT <= 1;
					TM0_OCCUR <= 0;
				end
			end
			
			if (HBL_IN) begin
				TM0 <= TM0 + 10'd1;
				TM0_OCCUR <= ~T1MD.MD;
				if (TM0 == T0C) begin
					TM0_INT <= 1;
					TM0_OCCUR <= 1;
				end
				TM1 <= {T1S,2'b11};
			end
			
			if (VBL_OUT) begin
				TM0 <= '0;
			end
			
			if (REG_WR && CA[7:2] == 8'hA4>>2) begin
				if (!CDI[3]) TM0_INT <= 0;
				if (!CDI[4]) TM1_INT <= 0;
			end
		end else if (CE_F) begin	
			 if (VECT_RD) begin
				case (CA[3:0])
					4'hC: TM0_INT <= 0;
					4'hB: TM1_INT <= 0;
					default:;
				endcase
			end
		end
	end
				
	//Interrupts
	always @(posedge CLK or negedge RST_N) begin
		bit DSP_IRQ_OLD;
		bit MIREQ_N_OLD;
		if (!RST_N) begin
			VBIN_INT <= 0;
			VBOUT_INT <= 0;
			HBIN_INT <= 0;
			DSP_INT <= 0;
			SCSP_INT <= 0;
			EXT_INT <= '0;
			PAD_INT <= 0;
			DSP_IRQ_OLD <= 0;
		end else if (!RES_N) begin
			VBIN_INT <= 0;
			VBOUT_INT <= 0;
			HBIN_INT <= 0;
			DSP_INT <= 0;
			SCSP_INT <= 0;
		end else if (CE_R) begin
			if (VBL_IN) VBIN_INT <= 1;
			if (VBL_OUT) VBOUT_INT <= 1;
			if (HBL_IN) HBIN_INT <= 1;
			if (SCSP_REQ) SCSP_INT <= 1;
			if (VDP1_REQ) VDP1_INT <= 1;
			
			DSP_IRQ_OLD <= DSP_IRQ;
			if (DSP_IRQ && !DSP_IRQ_OLD) DSP_INT <= 1;
			
			MIREQ_N_OLD <= MIREQ_N;
			if (!MIREQ_N && MIREQ_N_OLD) SM_INT <= 1;
			
			if (REG_WR && CA[7:2] == 8'hA4>>2) begin
				if (!CDI[0]) VBIN_INT <= 0;
				if (!CDI[1]) VBOUT_INT <= 0;
				if (!CDI[2]) HBIN_INT <= 0;
				if (!CDI[5]) DSP_INT <= 0;
				if (!CDI[6]) SCSP_INT <= 0;
				if (!CDI[7]) SM_INT <= 0;
				if (!CDI[13]) VDP1_INT <= 0;
			end 
		end else if (CE_F) begin
			if (VECT_RD) begin
				case (CA[3:0])
					4'hF: VBIN_INT <= 0;
					4'hE: VBOUT_INT <= 0;
					4'hD: HBIN_INT <= 0;
					4'hA: DSP_INT <= 0;
					4'h9: SCSP_INT <= 0;
					4'h8: SM_INT <= 0;//??
					4'h2: VDP1_INT <= 0;
					default:;
				endcase
			end
			EXT_INT <= '0;
			PAD_INT <= 0;
		end
	end
	
	wire [31:0] INT_STAT = {EXT_INT,2'b00,VDP1_INT,DMAIL_INT,DMA_INT[0],DMA_INT[1],DMA_INT[2],PAD_INT,SM_INT,SCSP_INT,DSP_INT,TM1_INT,TM0_INT,HBIN_INT,VBOUT_INT,VBIN_INT};
	
	bit [3:0] INT_LVL;
//	always @(posedge CLK or negedge RST_N) begin
//		bit INT_PEND;
//		
//		if (!RST_N) begin
//			INT_LVL <= '0;
//			INT_PEND <= 0;
//		end else if (!RES_N) begin
//			
//		end else begin
//			if (!INT_PEND && CE_R) begin
//				if      (VBIN_INT      && !IMS.MS0)  begin INT_LVL <= 4'hF; INT_PEND <= 1; end	//F
//				else if (VBOUT_INT     && !IMS.MS1)  begin INT_LVL <= 4'hE; INT_PEND <= 1; end	//E
//				else if (HBIN_INT      && !IMS.MS2)  begin INT_LVL <= 4'hD; INT_PEND <= 1; end	//D
//				else if (TM0_INT       && !IMS.MS3)  begin INT_LVL <= 4'hC; INT_PEND <= 1; end	//C
//				else if (TM1_INT       && !IMS.MS4)  begin INT_LVL <= 4'hB; INT_PEND <= 1; end	//B
//				else if (DSP_INT       && !IMS.MS5)  begin INT_LVL <= 4'hA; INT_PEND <= 1; end	//A
//				else if (SCSP_INT      && !IMS.MS6)  begin INT_LVL <= 4'h9; INT_PEND <= 1; end	//9
//				else if (SM_INT        && !IMS.MS7)  begin INT_LVL <= 4'h8; INT_PEND <= 1; end	//8
//				else if (PAD_INT       && !IMS.MS8)  begin INT_LVL <= 4'h8; INT_PEND <= 1; end	//8
//				else if ((EXT_INT[0] ||
//							 EXT_INT[1] ||
//							 EXT_INT[2] ||
//							 EXT_INT[3])  && !IMS.MS15) begin INT_LVL <= 4'h7; INT_PEND <= 1; end	//7
//				else if (DMA_INT[2]    && !IMS.MS9)  begin INT_LVL <= 4'h6; INT_PEND <= 1; end	//6
//				else if (DMA_INT[1]    && !IMS.MS10) begin INT_LVL <= 4'h6; INT_PEND <= 1; end	//6
//				else if (DMA_INT[0]    && !IMS.MS11) begin INT_LVL <= 4'h5; INT_PEND <= 1; end	//5
//				else if ((EXT_INT[4] ||
//							 EXT_INT[5] ||
//							 EXT_INT[6] ||
//							 EXT_INT[7])  && !IMS.MS15) begin INT_LVL <= 4'h4; INT_PEND <= 1; end	//4
//				else if (DMAIL_INT     && !IMS.MS12) begin INT_LVL <= 4'h3; INT_PEND <= 1; end	//3
//				else if (VDP1_INT      && !IMS.MS13) begin INT_LVL <= 4'h2; INT_PEND <= 1; end	//2
//				else if ((EXT_INT[8]  ||
//							 EXT_INT[9]  ||
//							 EXT_INT[10] ||
//							 EXT_INT[11] ||
//							 EXT_INT[12] ||
//							 EXT_INT[13] ||
//							 EXT_INT[14] ||
//							 EXT_INT[15]) && !IMS.MS15) begin INT_LVL <= 4'h1; INT_PEND <= 1; end	//1
////				else                                 INT_LVL <= 4'h0;	//0
//			end else if (VECT_RD) begin
//				INT_LVL = 4'h0;
//				INT_PEND <= 0;
//			end else if (REG_WR && CA[7:2] == 8'hA4>>2) begin
//				INT_LVL = 4'h0;
//				INT_PEND <= 0;
//			end
//			
//			if (INT_LVL == 4'hF) VBIN_INT_CNT <= VBIN_INT_CNT + 16'd1;
//			else VBIN_INT_CNT <= '0;
//		end
//	end
	always_comb begin
				if      (VBIN_INT      && !IMS.MS0)  begin INT_LVL <= 4'hF; end	//F
				else if (VBOUT_INT     && !IMS.MS1)  begin INT_LVL <= 4'hE; end	//E
				else if (HBIN_INT      && !IMS.MS2)  begin INT_LVL <= 4'hD; end	//D
				else if (TM0_INT       && !IMS.MS3)  begin INT_LVL <= 4'hC; end	//C
				else if (TM1_INT       && !IMS.MS4)  begin INT_LVL <= 4'hB; end	//B
				else if (DSP_INT       && !IMS.MS5)  begin INT_LVL <= 4'hA; end	//A
				else if (SCSP_INT      && !IMS.MS6)  begin INT_LVL <= 4'h9; end	//9
				else if (SM_INT        && !IMS.MS7)  begin INT_LVL <= 4'h8; end	//8
				else if (PAD_INT       && !IMS.MS8)  begin INT_LVL <= 4'h8; end	//8
				else if ((EXT_INT[0] ||
							 EXT_INT[1] ||
							 EXT_INT[2] ||
							 EXT_INT[3])  && !IMS.MS15) begin INT_LVL <= 4'h7; end	//7
				else if (DMA_INT[2]    && !IMS.MS9)  begin INT_LVL <= 4'h6; end	//6
				else if (DMA_INT[1]    && !IMS.MS10) begin INT_LVL <= 4'h6; end	//6
				else if (DMA_INT[0]    && !IMS.MS11) begin INT_LVL <= 4'h5; end	//5
				else if ((EXT_INT[4] ||
							 EXT_INT[5] ||
							 EXT_INT[6] ||
							 EXT_INT[7])  && !IMS.MS15) begin INT_LVL <= 4'h4; end	//4
				else if (DMAIL_INT     && !IMS.MS12) begin INT_LVL <= 4'h3; end	//3
				else if (VDP1_INT      && !IMS.MS13) begin INT_LVL <= 4'h2; end	//2
				else if ((EXT_INT[8]  ||
							 EXT_INT[9]  ||
							 EXT_INT[10] ||
							 EXT_INT[11] ||
							 EXT_INT[12] ||
							 EXT_INT[13] ||
							 EXT_INT[14] ||
							 EXT_INT[15]) && !IMS.MS15) begin INT_LVL <= 4'h1; end	//1
				else                                       INT_LVL <= 4'h0;			//0
	end
	assign CIRL_N = ~INT_LVL;
	
	bit [7:0] IVEC;
	always_comb begin
		case (CA[3:0])
			4'hF: IVEC = 8'h40;
			4'hE: IVEC = 8'h41;
			4'hD: IVEC = 8'h42;
			4'hC: IVEC = 8'h43;
			4'hB: IVEC = 8'h44;
			4'hA: IVEC = 8'h45;
			4'h9: IVEC = 8'h46;
			4'h8: IVEC = /*SM_INT      ?*/ 8'h47 /*: 8'h48*/;
			4'h7: IVEC = EXT_INT[0]  ? 8'h50 : 
			             EXT_INT[1]  ? 8'h51 : 
							 EXT_INT[2]  ? 8'h52 : 8'h53;
			4'h6: IVEC = DMA_INT[1]  ? 8'h4A : 8'h49;
			4'h5: IVEC = 8'h4B;
			4'h4: IVEC = EXT_INT[4]  ? 8'h54 : 
			             EXT_INT[5]  ? 8'h54 : 
							 EXT_INT[6]  ? 8'h56 : 8'h57;
			4'h3: IVEC = 8'h4C;
			4'h2: IVEC = 8'h4D;
			4'h1: IVEC = EXT_INT[8]  ? 8'h58 : 
			             EXT_INT[9]  ? 8'h59 : 
							 EXT_INT[10] ? 8'h5A : 
							 EXT_INT[11] ? 8'h5B :
							 EXT_INT[12] ? 8'h5C :
							 EXT_INT[13] ? 8'h5D :
							 EXT_INT[14] ? 8'h5E : 8'h5F;
			4'h0: IVEC = 8'h00;
		endcase
	end
	
	bit [7:0] IVEC_DO;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			IVEC_DO <= '0;
		end
		else if (!RES_N) begin
			IVEC_DO <= '0;
		end 
		else begin
			if (!CIVECF_N && !CRD_N && CE_R) begin
				IVEC_DO <= IVEC;
			end
		end
	end
	
	
	//Registers
	bit [31:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		
		if (!RST_N) begin
			DR <= '{'0,'0,'0};
			DW <= '{'0,'0,'0};
			DC <= '{'0,'0,'0};
			DAD <= '{'0,'0,'0};
			DEN <= '{'0,'0,'0};
			DMD <= '{'0,'0,'0};
			DSTP <= DSTP_INIT;
			T0C <= RSEL_INIT;
			T1S <= RSEL_INIT;
			T1MD <= T1MD_INIT;
			IMS <= IMS_INIT;
			RSEL <= RSEL_INIT;
			
			REG_DO <= '0;
		end
		else if (!RES_N) begin
			DR <= '{'0,'0,'0};
			DW <= '{'0,'0,'0};
			DC <= '{'0,'0,'0};
			DAD <= '{'0,'0,'0};
			DEN <= '{'0,'0,'0};
			DMD <= '{'0,'0,'0};
			DSTP <= DSTP_INIT;
			T0C <= RSEL_INIT;
			T1S <= RSEL_INIT;
			T1MD <= T1MD_INIT;
			IMS <= IMS_INIT;
			RSEL <= RSEL_INIT;
		end else if (CE_R) begin
			DEN[0].GO <= 0;
			DEN[1].GO <= 0;
			DEN[2].GO <= 0;
			if (REG_WR) begin
				case ({CA[7:2],2'b00})
					8'h00: begin
						if (!CDQM_N[0]) DR[0][ 7: 0] <= CDI[ 7: 0] & DxR_WMASK[ 7: 0];
						if (!CDQM_N[1]) DR[0][15: 8] <= CDI[15: 8] & DxR_WMASK[15: 8];
						if (!CDQM_N[2]) DR[0][23:16] <= CDI[23:16] & DxR_WMASK[23:16];
						if (!CDQM_N[3]) DR[0][26:24] <= CDI[26:24] & DxR_WMASK[26:24];
					end
					8'h04: begin
						if (!CDQM_N[0]) DW[0][ 7: 0] <= CDI[ 7: 0] & DxW_WMASK[ 7: 0];
						if (!CDQM_N[1]) DW[0][15: 8] <= CDI[15: 8] & DxW_WMASK[15: 8];
						if (!CDQM_N[2]) DW[0][23:16] <= CDI[23:16] & DxW_WMASK[23:16];
						if (!CDQM_N[3]) DW[0][26:24] <= CDI[26:24] & DxW_WMASK[26:24];
					end
					8'h08: begin
						if (!CDQM_N[0]) DC[0][ 7: 0] <= CDI[ 7: 0] & D0C_WMASK[ 7: 0];
						if (!CDQM_N[1]) DC[0][15: 8] <= CDI[15: 8] & D0C_WMASK[15: 8];
						if (!CDQM_N[2]) DC[0][19:16] <= CDI[19:16] & D0C_WMASK[19:16];
					end
					8'h0C: begin
						if (!CDQM_N[0] && !DMA_RUN[0]) DAD[0][ 7: 0] <= CDI[ 7: 0] & DxAD_WMASK[ 7: 0];
						if (!CDQM_N[1] && !DMA_RUN[0]) DAD[0][15: 8] <= CDI[15: 8] & DxAD_WMASK[15: 8];
						if (!CDQM_N[2] && !DMA_RUN[0]) DAD[0][23:16] <= CDI[23:16] & DxAD_WMASK[23:16];
						if (!CDQM_N[3] && !DMA_RUN[0]) DAD[0][31:24] <= CDI[31:24] & DxAD_WMASK[31:24];
					end
					8'h10: begin
						if (!CDQM_N[0]) DEN[0][ 7: 0] <= CDI[ 7: 0] & DxEN_WMASK[ 7: 0];
						if (!CDQM_N[1]) DEN[0][15: 8] <= CDI[15: 8] & DxEN_WMASK[15: 8];
						if (!CDQM_N[2]) DEN[0][23:16] <= CDI[23:16] & DxEN_WMASK[23:16];
						if (!CDQM_N[3]) DEN[0][31:24] <= CDI[31:24] & DxEN_WMASK[31:24];
					end
					8'h14: begin
						if (!CDQM_N[0] && !DMA_RUN[0]) DMD[0][ 7: 0] <= CDI[ 7: 0] & DxMD_WMASK[ 7: 0];
						if (!CDQM_N[1] && !DMA_RUN[0]) DMD[0][15: 8] <= CDI[15: 8] & DxMD_WMASK[15: 8];
						if (!CDQM_N[2] && !DMA_RUN[0]) DMD[0][23:16] <= CDI[23:16] & DxMD_WMASK[23:16];
						if (!CDQM_N[3] && !DMA_RUN[0]) DMD[0][31:24] <= CDI[31:24] & DxMD_WMASK[31:24];
					end
					8'h20: begin
						if (!CDQM_N[0]) DR[1][ 7: 0] <= CDI[ 7: 0] & DxR_WMASK[ 7: 0];
						if (!CDQM_N[1]) DR[1][15: 8] <= CDI[15: 8] & DxR_WMASK[15: 8];
						if (!CDQM_N[2]) DR[1][23:16] <= CDI[23:16] & DxR_WMASK[23:16];
						if (!CDQM_N[3]) DR[1][26:24] <= CDI[26:24] & DxR_WMASK[26:24];
					end
					8'h24: begin
						if (!CDQM_N[0]) DW[1][ 7: 0] <= CDI[ 7: 0] & DxW_WMASK[ 7: 0];
						if (!CDQM_N[1]) DW[1][15: 8] <= CDI[15: 8] & DxW_WMASK[15: 8];
						if (!CDQM_N[2]) DW[1][23:16] <= CDI[23:16] & DxW_WMASK[23:16];
						if (!CDQM_N[3]) DW[1][26:24] <= CDI[26:24] & DxW_WMASK[26:24];
					end
					8'h28: begin
						if (!CDQM_N[0]) DC[1][ 7: 0] <= CDI[ 7: 0] & D0C_WMASK[ 7: 0];
						if (!CDQM_N[1]) DC[1][11: 8] <= CDI[11: 8] & D0C_WMASK[11: 8];
					end
					8'h2C: begin
						if (!CDQM_N[0] && !DMA_RUN[1]) DAD[1][ 7: 0] <= CDI[ 7: 0] & DxAD_WMASK[ 7: 0];
						if (!CDQM_N[1] && !DMA_RUN[1]) DAD[1][15: 8] <= CDI[15: 8] & DxAD_WMASK[15: 8];
						if (!CDQM_N[2] && !DMA_RUN[1]) DAD[1][23:16] <= CDI[23:16] & DxAD_WMASK[23:16];
						if (!CDQM_N[3] && !DMA_RUN[1]) DAD[1][31:24] <= CDI[31:24] & DxAD_WMASK[31:24];
					end
					8'h30: begin
						if (!CDQM_N[0]) DEN[1][ 7: 0] <= CDI[ 7: 0] & DxEN_WMASK[ 7: 0];
						if (!CDQM_N[1]) DEN[1][15: 8] <= CDI[15: 8] & DxEN_WMASK[15: 8];
						if (!CDQM_N[2]) DEN[1][23:16] <= CDI[23:16] & DxEN_WMASK[23:16];
						if (!CDQM_N[3]) DEN[1][31:24] <= CDI[31:24] & DxEN_WMASK[31:24];
					end
					8'h34: begin
						if (!CDQM_N[0] && !DMA_RUN[1]) DMD[1][ 7: 0] <= CDI[ 7: 0] & DxMD_WMASK[ 7: 0];
						if (!CDQM_N[1] && !DMA_RUN[1]) DMD[1][15: 8] <= CDI[15: 8] & DxMD_WMASK[15: 8];
						if (!CDQM_N[2] && !DMA_RUN[1]) DMD[1][23:16] <= CDI[23:16] & DxMD_WMASK[23:16];
						if (!CDQM_N[3] && !DMA_RUN[1]) DMD[1][31:24] <= CDI[31:24] & DxMD_WMASK[31:24];
					end
					8'h40: begin
						if (!CDQM_N[0]) DR[2][ 7: 0] <= CDI[ 7: 0] & DxR_WMASK[ 7: 0];
						if (!CDQM_N[1]) DR[2][15: 8] <= CDI[15: 8] & DxR_WMASK[15: 8];
						if (!CDQM_N[2]) DR[2][23:16] <= CDI[23:16] & DxR_WMASK[23:16];
						if (!CDQM_N[3]) DR[2][26:24] <= CDI[26:24] & DxR_WMASK[26:24];
					end
					8'h44: begin
						if (!CDQM_N[0]) DW[2][ 7: 0] <= CDI[ 7: 0] & DxW_WMASK[ 7: 0];
						if (!CDQM_N[1]) DW[2][15: 8] <= CDI[15: 8] & DxW_WMASK[15: 8];
						if (!CDQM_N[2]) DW[2][23:16] <= CDI[23:16] & DxW_WMASK[23:16];
						if (!CDQM_N[3]) DW[2][26:24] <= CDI[26:24] & DxW_WMASK[26:24];
					end
					8'h48: begin
						if (!CDQM_N[0]) DC[2][ 7: 0] <= CDI[ 7: 0] & D0C_WMASK[ 7: 0];
						if (!CDQM_N[1]) DC[2][11: 8] <= CDI[11: 8] & D0C_WMASK[11: 8];
					end
					8'h4C: begin
						if (!CDQM_N[0] && !DMA_RUN[2]) DAD[2][ 7: 0] <= CDI[ 7: 0] & DxAD_WMASK[ 7: 0];
						if (!CDQM_N[1] && !DMA_RUN[2]) DAD[2][15: 8] <= CDI[15: 8] & DxAD_WMASK[15: 8];
						if (!CDQM_N[2] && !DMA_RUN[2]) DAD[2][23:16] <= CDI[23:16] & DxAD_WMASK[23:16];
						if (!CDQM_N[3] && !DMA_RUN[2]) DAD[2][31:24] <= CDI[31:24] & DxAD_WMASK[31:24];
					end
					8'h50: begin
						if (!CDQM_N[0]) DEN[2][ 7: 0] <= CDI[ 7: 0] & DxEN_WMASK[ 7: 0];
						if (!CDQM_N[1]) DEN[2][15: 8] <= CDI[15: 8] & DxEN_WMASK[15: 8];
						if (!CDQM_N[2]) DEN[2][23:16] <= CDI[23:16] & DxEN_WMASK[23:16];
						if (!CDQM_N[3]) DEN[2][31:24] <= CDI[31:24] & DxEN_WMASK[31:24];
					end
					8'h54: begin
						if (!CDQM_N[0] && !DMA_RUN[2]) DMD[2][ 7: 0] <= CDI[ 7: 0] & DxMD_WMASK[ 7: 0];
						if (!CDQM_N[1] && !DMA_RUN[2]) DMD[2][15: 8] <= CDI[15: 8] & DxMD_WMASK[15: 8];
						if (!CDQM_N[2] && !DMA_RUN[2]) DMD[2][23:16] <= CDI[23:16] & DxMD_WMASK[23:16];
						if (!CDQM_N[3] && !DMA_RUN[2]) DMD[2][31:24] <= CDI[31:24] & DxMD_WMASK[31:24];
					end
					
					8'h60: begin
						if (!CDQM_N[0]) DSTP[ 7: 0] <= CDI[ 7: 0] & DSTP_WMASK[ 7: 0];
						if (!CDQM_N[1]) DSTP[15: 8] <= CDI[15: 8] & DSTP_WMASK[15: 8];
						if (!CDQM_N[2]) DSTP[23:16] <= CDI[23:16] & DSTP_WMASK[23:16];
						if (!CDQM_N[3]) DSTP[31:24] <= CDI[31:24] & DSTP_WMASK[31:24];
					end
					
					8'h90: begin
						if (!CDQM_N[0]) T0C[ 7: 0] <= CDI[ 7: 0] & T0C_WMASK[ 7: 0];
						if (!CDQM_N[1]) T0C[ 9: 8] <= CDI[ 9: 8] & T0C_WMASK[ 9: 8];
					end
					8'h94: begin
						if (!CDQM_N[0]) T1S[ 7: 0] <= CDI[ 7: 0] & T1S_WMASK[ 7: 0];
						if (!CDQM_N[1]) T1S[ 8: 8] <= CDI[ 8: 8] & T1S_WMASK[ 8: 8];
					end
					8'h98: begin
						if (!CDQM_N[0]) T1MD[ 7: 0] <= CDI[ 7: 0] & T1MD_WMASK[ 7: 0];
						if (!CDQM_N[1]) T1MD[15: 8] <= CDI[15: 8] & T1MD_WMASK[15: 8];
						if (!CDQM_N[2]) T1MD[23:16] <= CDI[23:16] & T1MD_WMASK[23:16];
						if (!CDQM_N[3]) T1MD[31:24] <= CDI[31:24] & T1MD_WMASK[31:24];
					end
					8'hA0: begin
						if (!CDQM_N[0]) IMS[ 7: 0] <= CDI[ 7: 0] & IMS_WMASK[ 7: 0];
						if (!CDQM_N[1]) IMS[15: 8] <= CDI[15: 8] & IMS_WMASK[15: 8];
						if (!CDQM_N[2]) IMS[23:16] <= CDI[23:16] & IMS_WMASK[23:16];
						if (!CDQM_N[3]) IMS[31:24] <= CDI[31:24] & IMS_WMASK[31:24];
					end
					
					8'hB0: begin
						if (!CDQM_N[0]) ASR0[ 7: 0] <= CDI[ 7: 0] & ASR0_WMASK[ 7: 0];
						if (!CDQM_N[1]) ASR0[15: 8] <= CDI[15: 8] & ASR0_WMASK[15: 8];
						if (!CDQM_N[2]) ASR0[23:16] <= CDI[23:16] & ASR0_WMASK[23:16];
						if (!CDQM_N[3]) ASR0[31:24] <= CDI[31:24] & ASR0_WMASK[31:24];
					end
					8'hB4: begin
						if (!CDQM_N[0]) ASR1[ 7: 0] <= CDI[ 7: 0] & ASR1_WMASK[ 7: 0];
						if (!CDQM_N[1]) ASR1[15: 8] <= CDI[15: 8] & ASR1_WMASK[15: 8];
						if (!CDQM_N[2]) ASR1[23:16] <= CDI[23:16] & ASR1_WMASK[23:16];
						if (!CDQM_N[3]) ASR1[31:24] <= CDI[31:24] & ASR1_WMASK[31:24];
					end
					8'hC4: begin
						if (!CDQM_N[0]) RSEL <= CDI[0] & RSEL_WMASK[0];
					end
					default:;
				endcase
			end
			
			if (DMA_RUN[0]) begin
				
			end
			else if (DMA_END) begin
				if (DMD[DMA_CH].RUP) DR[DMA_CH] <= DMA_RA[DMA_CH];
				if (DMD[DMA_CH].WUP) DW[DMA_CH] <= !DMD[DMA_CH].MOD ? DMA_WA[DMA_CH] : DMA_IA[DMA_CH];
			end
		end else if (CE_F) begin
			if (REG_RD) begin
				case ({CA[7:2],2'b00})
					8'h00: REG_DO <= {5'h00,DR[0]} & DxR_RMASK;
					8'h04: REG_DO <= {5'h00,DW[0]} & DxW_RMASK;
					8'h08: REG_DO <= {12'h000,DC[0]} & D0C_RMASK;
					8'h20: REG_DO <= {5'h00,DR[1]} & DxR_RMASK;
					8'h24: REG_DO <= {5'h00,DW[1]} & DxW_RMASK;
					8'h28: REG_DO <= {12'h000,DC[1]} & D12C_RMASK;
					8'h40: REG_DO <= {5'h00,DR[2]} & DxR_RMASK;
					8'h44: REG_DO <= {5'h00,DW[2]} & DxW_RMASK;
					8'h48: REG_DO <= {12'h000,DC[2]} & D12C_RMASK;
					8'h7C: REG_DO <= DSTA & DSTA_RMASK;
					
					8'hA4: REG_DO <= INT_STAT & IST_RMASK;
					
					8'hB0: REG_DO <= ASR0 & ASR0_RMASK;
					8'hB4: REG_DO <= ASR1 & ASR1_RMASK;
					
					8'hC4: REG_DO <= {31'h00000000,RSEL} & RSEL_RMASK;
					
					default: REG_DO <= '0;
				endcase
			end
		end
	end
	
	assign CDO = ABUS_SEL || BBUS_SEL ? AB_DO : 
	             !CIVECF_N            ? {24'h000000,IVEC_DO} :
					 DSP_SEL              ? DSP_DO : 
					 REG_DO;
	assign CWAIT_N = ~CBUS_WAIT;
	
	assign DBG_ASR = ASR0^ASR1;
	
endmodule
