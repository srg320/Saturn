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
	
	output reg [20:0] BA,
	input      [15:0] BDI,
	output reg [15:0] BDO,
	output reg        BADDT_N,
	output reg        BDTEN_N,
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
	
	input             MIREQ_N
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
	RSEL_t     RSEL;
	
	wire REG_SEL = ~CCS2_N & CA[24:0] >= 25'h1FE0000 & CA[24:0] <= 25'h1FE00CF;	//25FE0000-25FE00CF
	wire REG_WR = REG_SEL & ~CRD_WR_N && ~(&CDQM_N);
	wire REG_RD = REG_SEL & CRD_WR_N && ~CRD_N;

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
	bit [31:0] ABUS_D;
	bit        ABUS_WE;
	bit [31:0] ABUS_Q;
	bit        ABUS_REQ;
	bit        ABUS_RDY;
	typedef enum bit [4:0] {
		AS_IDLE  = 5'b00001,  
		AS_ADDR  = 5'b00010, 
		AS_READ  = 5'b00100,
		AS_WRITE = 5'b01000
	} ABusState_t;
	ABusState_t ABUS_ST;
	
	bit [22:0] BBUS_A;
	bit [31:0] BBUS_D;
	bit        BBUS_WE;
	bit [31:0] BBUS_Q;
	bit        BBUS_REQ;
	bit        BBUS_RDY;
	typedef enum bit [5:0] {
		BS_IDLE  = 6'b000001,  
		BS_ADDRL = 6'b000010, 
		BS_ADDRH = 6'b000100,
		BS_READ  = 6'b001000,
		BS_WRITE = 6'b010000,
		BS_END   = 6'b100000
	} BBusState_t;
	BBusState_t BBUS_ST;
	
	bit [26:0] CBUS_A;
	bit [31:0] CBUS_D;
	bit        CBUS_CS;
	bit        CBUS_WE;
	bit [31:0] CBUS_Q;
	bit        CBUS_REQ;
	bit        CBUS_RDY;
	typedef enum bit [4:0] {
		CS_IDLE  = 5'b00001,  
		CS_BUSREQ = 5'b00010, 
		CS_ADDR = 5'b00100,
		CS_READ  = 5'b01000,
		CS_WRITE = 5'b10000
	} CBusState_t;
	CBusState_t CBUS_ST;
	
	//DSP
	bit [26:0] DSP_DMA_A;
	bit [31:0] DSP_DMA_DO;
	bit [31:0] DSP_DMA_DI;
	bit        DSP_DMA_WE;
	bit        DSP_DMA_REQ;
	bit        DSP_DMA_ACK;
	bit        DSP_IRQ;
	
	//DMA
	bit [26:0] DMA_RA[3];
	bit [26:0] DMA_WA[3];
	bit [26:0] DMA_IA[3];
	bit [31:0] DMA_TN[3];
	bit  [1:0] DMA_CH;
	bit        DMA_PEND[3];
	bit        DMA_RUN[3];
	bit        DMA_END;
	typedef enum bit [8:0] {
		DS_IDLE       = 9'b000000001,  
		DS_CPU_ACCESS = 9'b000000010, 
		DS_CPU_END    = 9'b000000100, 
		DS_DMA_START  = 9'b000001000, 
		DS_DMA_IND    = 9'b000010000, 
		DS_DMA_ACCESS = 9'b000100000,
		DS_DMA_READ   = 9'b001000000,
		DS_DMA_WRITE  = 9'b010000000,
		DS_DMA_END    = 9'b100000000
	} DMAState_t;
	DMAState_t DMA_ST;
	
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
	wire ABUS_SEL = ~CCS1_N | (CA[24:16] < 9'h190 & ~CCS2_N);				//02000000-058FFFFF
	wire BBUS_SEL = CA[24:16] >= 9'h1A0 & CA[24:16] < 9'h1FE & ~CCS2_N;	//05A00000-05FDFFFF
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
	
	bit  [31:0] DMA_DATA;
	bit  [31:0] AB_DO;
	always @(posedge CLK or negedge RST_N) begin
		bit  [26:0] DMA_ADDR;
		bit         DMA_WE;
		bit         DMA_IND;
		bit   [1:0] DMA_IND_REG;
		bit         DMA_DSP;
		bit         ABBUS_SEL_OLD;
		
		if (!RST_N) begin
			DSTA <= DSTA_INIT;
			DMA_RA <= '{'0,'0,'0};
			DMA_WA <= '{'0,'0,'0};
			DMA_IA <= '{'0,'0,'0};
			DMA_TN <= '{'0,'0,'0};
			DMA_CH <= '0;
			DMA_PEND <= '{0,0,0};
			DMA_RUN <= '{0,0,0};
			DMA_END <= 0;
			DMA_ST <= DS_IDLE;
			DMA_INT <= '0;
			DMAIL_INT <= 0;
			
			ABUS_A <= '0;
			ABUS_D <= '0;
			ABUS_WE <= '0;
			ABUS_REQ <= 0;
			BBUS_A <= '0;
			BBUS_D <= '0;
			BBUS_WE <= '0;
			BBUS_REQ <= 0;
			CBUS_A <= '0;
			CBUS_D <= '0;
			CBUS_WE <= '0;
			CBUS_REQ <= 0;
			ABBUS_SEL_OLD <= 0;
		end
		else if (CE_R) begin
			DSP_DMA_ACK <= 0;
			DMA_DSP <= 0;
			
			ABBUS_SEL_OLD <= ABUS_SEL | BBUS_SEL;
			if ((ABUS_SEL || BBUS_SEL) && !ABBUS_SEL_OLD && !CBUS_WAIT) CBUS_WAIT <= 1;
			
			if (DMA_FACT[0] && DEN[0].EN && !DMA_PEND[0]) begin DMA_PEND[0] <= 1; DSTA.D0WT <= 1; end
			if (DMA_FACT[1] && DEN[1].EN && !DMA_PEND[1]) begin DMA_PEND[1] <= 1; DSTA.D1WT <= 1; end
			if (DMA_FACT[2] && DEN[2].EN && !DMA_PEND[2]) begin DMA_PEND[2] <= 1; DSTA.D2WT <= 1; end
			if (DSP_DMA_REQ) DSTA.DDWT <= 1;
			case (DMA_ST)
				DS_IDLE : begin
					DSTA.D0MV <= 0;//?
					DSTA.D1MV <= 0;//?
					DSTA.D2MV <= 0;//?
					DSTA.DDMV <= 0;//?
					if (ABUS_SEL || BBUS_SEL) begin
						DMA_ST <= DS_CPU_ACCESS;
					end else if (DSP_DMA_REQ) begin
						DMA_ADDR <= DSP_DMA_A;
						DMA_DATA <= DSP_DMA_DO;
						DMA_WE <= DSP_DMA_WE;
						DMA_DSP <= 1;
						DMA_ST <= DS_DMA_ACCESS;
						DSTA.DDWT <= 0;
						DSTA.DDMV <= 1;
					end else if (DMA_PEND[0]) begin
						DMA_PEND[0] <= 0;
						DMA_CH <= 2'd0;
						DMA_RUN[0] <= 1;
						DMA_ST <= DS_DMA_START;
						DSTA.D0WT <= 0;
						DSTA.D0MV <= 1;
					end else if (DMA_PEND[1]) begin
						DMA_PEND[1] <= 0;
						DMA_CH <= 2'd1;
						DMA_RUN[1] <= 1;
						DMA_ST <= DS_DMA_START;
						DSTA.D1WT <= 0;
						DSTA.D1MV <= 1;
					end else if (DMA_PEND[2]) begin
						DMA_PEND[2] <= 0;
						DMA_CH <= 2'd2;
						DMA_RUN[2] <= 1;
						DMA_ST <= DS_DMA_START;
						DSTA.D2WT <= 0;
						DSTA.D2MV <= 1;
					end
				end
				
				DS_CPU_ACCESS : begin
					if (ABUS_SEL && !ABUS_REQ) begin	//A-BUS 02000000-058FFFFF
						ABUS_A <= !CCS1_N ? {2'b01,CA[24:0]} : {2'b10,CA[24:0]};
						ABUS_D <= CDI;
						ABUS_WE <= ~CRD_WR_N;
						ABUS_REQ <= 1;
					end else if (ABUS_REQ && ABUS_RDY) begin
						AB_DO <= ABUS_Q;
						ABUS_REQ <= 0;
					end
					
					if (BBUS_SEL && !BBUS_REQ) begin	//B-BUS 05A00000-05FDFFFF
						BBUS_A <= CA[22:0];
						BBUS_D <= CDI;
						BBUS_WE <= ~CRD_WR_N;
						BBUS_REQ <= 1;
					end else if (BBUS_REQ && BBUS_RDY) begin
						AB_DO <= BBUS_Q;
						BBUS_REQ <= 0;
					end
					
					if ((ABUS_REQ && ABUS_RDY) || (BBUS_REQ && BBUS_RDY)) begin
						CBUS_WAIT <= 0;
						DMA_ST <= DS_CPU_END;
					end
				end
				
				DS_CPU_END : begin
					if (!ABUS_SEL && !BBUS_SEL) begin
						DMA_ST <= DS_IDLE;
					end
				end
				
				DS_DMA_START : begin
					if (!DMD[DMA_CH].MOD) begin
						DMA_RA[DMA_CH] <= DR[DMA_CH];
						DMA_WA[DMA_CH] <= DW[DMA_CH];
						DMA_TN[DMA_CH] <= {12'h000,DC[DMA_CH]};
						
						DMA_ADDR <= DR[DMA_CH];
						DMA_WE <= 0;
						DMA_IND <= 0;
						DMA_ST <= DS_DMA_ACCESS;
					end else begin
						DMA_IA[DMA_CH] <= DW[DMA_CH];
						
						DMA_ADDR <= DW[DMA_CH];
						DMA_WE <= 0;
						DMA_IND <= 1;
						DMA_IND_REG <= 2'd0;
						DMA_ST <= DS_DMA_ACCESS;
					end
				end
				
				DS_DMA_IND : begin
					DMA_IA[DMA_CH] <= DMA_IA[DMA_CH] + 27'd4;
					case (DMA_IND_REG)
						2'd0: DMA_RA[DMA_CH] <= DMA_DATA[26:0];
						2'd1: DMA_WA[DMA_CH] <= DMA_DATA[26:0];
						2'd2: DMA_TN[DMA_CH] <= DMA_DATA;
					endcase
					if (DMA_IND_REG < 2'd2) begin
						DMA_IND_REG <= DMA_IND_REG + 2'd1;
						DMA_ADDR <= DMA_ADDR + 27'd4;
						DMA_WE <= 0;
						DMA_IND <= 1;
						DMA_ST <= DS_DMA_ACCESS;
					end else begin
						DMA_ADDR <= DMA_RA[DMA_CH];
						DMA_WE <= 0;
						DMA_IND <= 0;
						DMA_ST <= DS_DMA_ACCESS;
					end
				end
				
				DS_DMA_ACCESS : begin
					if (DMA_ADDR[26:16] >= 11'h200 && DMA_ADDR[26:16] < 11'h590 && !ABUS_REQ) begin	//A-BUS 02000000-058FFFFF
						ABUS_A <= DMA_ADDR[26:0];
						ABUS_D <= DMA_DATA;
						ABUS_WE <= DMA_WE;
						ABUS_REQ <= 1;
						DSTA.DACSA <= 1;
					end else if (ABUS_REQ && ABUS_RDY) begin
						DMA_DATA <= ABUS_Q;
						ABUS_REQ <= 0;
						DSTA.DACSA <= 0;
					end
					
					if (DMA_ADDR[26:16] >= 11'h5A0 && DMA_ADDR[26:16] < 11'h5FE && !BBUS_REQ) begin	//B-BUS 05A00000-05FDFFFF
						BBUS_A <= DMA_ADDR[22:0];
						BBUS_D <= DMA_DATA;
						BBUS_WE <= DMA_WE;
						BBUS_REQ <= 1;
						DSTA.DACSB <= 1;
					end else if (BBUS_REQ && BBUS_RDY) begin
						DMA_DATA <= BBUS_Q;
						BBUS_REQ <= 0;
						DSTA.DACSB <= 0;
					end
					
					if (DMA_ADDR[26:24] == 3'h6 && !CBUS_REQ) begin	//C-BUS 06000000-07FFFFFF
						CBUS_A <= DMA_ADDR[26:0];
						CBUS_D <= DMA_DATA;
						CBUS_WE <= DMA_WE;
						CBUS_REQ <= 1;
					end else if (CBUS_REQ && CBUS_RDY) begin
						DMA_DATA <= CBUS_Q;
						CBUS_REQ <= 0;
					end
					
					DSTA.DACSD <= DMA_DSP;
					if ((ABUS_REQ && ABUS_RDY) || (BBUS_REQ && BBUS_RDY) || (CBUS_REQ && CBUS_RDY)) begin
						DMA_ST <= DMA_DSP ? DS_IDLE :
						          DMA_IND ? DS_DMA_IND : 
						          DMA_WE ? DS_DMA_WRITE : 
						          DS_DMA_READ;
						DSP_DMA_ACK <= DMA_DSP;
						DSTA.DACSD <= 0;
					end
				end
				
				DS_DMA_READ : begin
					if (DAD[DMA_CH].DRA) DMA_RA[DMA_CH] <= DMA_RA[DMA_CH] + 27'd4;
					
					DMA_ADDR <= DMA_WA[DMA_CH];
					DMA_WE <= 1;
					DMA_ST <= DS_DMA_ACCESS;
				end
				
				DS_DMA_WRITE : begin
					if (DAD[DMA_CH].DWA) DMA_WA[DMA_CH] <= DMA_WA[DMA_CH] + (27'd1 << DAD[DMA_CH].DWA);
					DMA_TN[DMA_CH][19:0] <= DMA_TN[DMA_CH][19:0] - 20'd4;
					if (!DMA_TN[DMA_CH][19:0]) begin
						if (!DMD[DMA_CH].MOD || DMA_TN[DMA_CH][31]) begin
							DMA_END <= 1;
							DMA_ST <= DS_DMA_END;
						end else begin
							DMA_ADDR <= DMA_IA[DMA_CH];
							DMA_WE <= 0;
							DMA_IND <= 1;
							DMA_IND_REG <= 2'd0;
							DMA_ST <= DS_DMA_ACCESS;
						end
					end else begin
						DMA_ADDR <= DMA_RA[DMA_CH];
						DMA_WE <= 0;
						DMA_ST <= DS_DMA_ACCESS;
					end
				end
				
				DS_DMA_END : begin
					DMA_END <= 0;
					DMA_INT[DMA_CH] <= 1;
					DMA_ST <= DS_IDLE;
				end
			endcase
		end else if (CE_F) begin
			if (REG_WR && CA[7:2] == 8'h60>>2) begin				//DSTA
				if (CDI[0]) begin
					DMA_END <= 0;
					DMA_INT <= '0;
					DMA_ST <= DS_IDLE;
				end
			end else if (REG_WR && CA[7:2] == 8'hA4>>2) begin	//IST
				if (!CDI[9])  DMA_INT[2] <= 0;
				if (!CDI[10]) DMA_INT[1] <= 0;
				if (!CDI[11]) DMA_INT[0] <= 0;
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		bit WORD;
		
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
			
			ABUS_ST <= AS_IDLE;
			ABUS_Q <= '0;
			ABUS_RDY <= 1;
			WORD <= 0;
		end
		else if (CE_R) begin
			case (ABUS_ST) 
				AS_IDLE: begin
					ABUS_RDY <= 0;
					if (ABUS_REQ) begin
						casez (ABUS_A[26:24])
							3'b0??: ACS0_N <= 0;
							3'b100: ACS1_N <= 0;
							default: ACS2_N <= 0;
						endcase
						ABUS_ST <= AS_ADDR;
					end
				end
				
				AS_ADDR: begin
					AA <= ABUS_A[25:0];
					AAS_N <= 0;
					WORD <= 0;
					ABUS_ST <= ABUS_WE ? AS_WRITE : AS_READ;
				end
					
				AS_READ: begin
					AAS_N <= 1;
					ARD_N <= 0;
					if (AWAIT_N) begin
						WORD <= ~WORD;
						if (!WORD) begin
							ABUS_Q[31:16] <= ADI;
						end else begin
							ABUS_Q[15:0] <= ADI;
							ARD_N <= 1;
							ACS0_N <= 1;
							ACS1_N <= 1;
							ACS2_N <= 1;
							ABUS_RDY <= 1;
							ABUS_ST <= AS_IDLE;
						end
					end
				end
				
				AS_WRITE: begin
					if (!WORD) begin
						ADO <= ABUS_D[31:16];
					end else begin
						ADO <= ABUS_D[15:0];
					end
					AAS_N <= 1;
					AWRL_N <= 0;
					AWRU_N <= 0;
					if (AWAIT_N) begin
						WORD <= ~WORD;
						if (WORD) begin
							AWRL_N <= 1;
							AWRU_N <= 1;
							ACS0_N <= 1;
							ACS1_N <= 1;
							ACS2_N <= 1;
							ABUS_RDY <= 1;
							ABUS_ST <= AS_IDLE;
						end
					end
				end
			endcase
			
			AFC <= '1;
			ATIM0_N <= 1;
			ATIM1_N <= 1;
			ATIM2_N <= 1;
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		bit WORD;
		bit [20:0] ADDR;
		
		if (!RST_N) begin
			BDO <= '0;
			BADDT_N <= 1;
			BDTEN_N <= 1;
			BCS1_N <= 1;
			BCS2_N <= 1;
			BCSS_N <= 1;
			
			BBUS_ST <= BS_IDLE;
			BBUS_Q <= '0;
			BBUS_RDY <= 1;
			WORD <= 0;
		end
		else if (CE_R) begin
			case (BBUS_ST) 
				BS_IDLE: begin
					BBUS_RDY <= 0;
					if (BBUS_REQ) begin
						BA <= BBUS_A[20:0];
						case (BBUS_A[22:21])
							2'b01: BCSS_N <= 0;
							2'b10: BCS1_N <= 0;
							2'b11: BCS2_N <= 0;
						endcase
						WORD <= 0;
						BBUS_ST <= BS_ADDRL;
					end
				end
				
				BS_ADDRL: begin
					BDO <= {11'h000,BA[20:16]};
					BDTEN_N <= 0;
					BADDT_N <= 0;
					BBUS_ST <= BS_ADDRH;
				end
				
				BS_ADDRH: begin
					BDO <= BA[15:0];
					BDTEN_N <= 0;
					BADDT_N <= 0;
					BBUS_ST <= BBUS_WE ? BS_WRITE : BS_READ;
				end
					
				BS_READ: begin
					BDTEN_N <= 0;
					BADDT_N <= 1;
					if ((!BCSS_N && !BRDYS_N) || (!BCS1_N && !BRDY1_N) || (!BCS2_N && !BRDY2_N)) begin
						BA <= BA + 21'd2;
						BDTEN_N <= 1;
						BADDT_N <= 1;
						WORD <= ~WORD;
						if (!WORD) begin
							BBUS_Q[31:16] <= BDI;
							BBUS_ST <= BS_ADDRL;
						end else begin
							BCS1_N <= 1;
							BCS2_N <= 1;
							BCSS_N <= 1;
							BBUS_Q[15:0] <= BDI;
							BBUS_RDY <= 1;
							BBUS_ST <= BS_END;
						end
					end
				end
				
				BS_WRITE: begin
					if (!WORD) begin
						BDO <= BBUS_D[31:16];
					end else begin
						BDO <= BBUS_D[15:0];
					end
					BDTEN_N <= 0;
					BADDT_N <= 1;
					if ((!BCSS_N && !BRDYS_N) || (!BCS1_N && !BRDY1_N) || (!BCS2_N && !BRDY2_N)) begin
						BA <= BA + 21'd2;
						BDTEN_N <= 1;
						BADDT_N <= 1;
						WORD <= ~WORD;
						if (!WORD) begin
							BBUS_ST <= BS_ADDRL;
						end else begin
							BCS1_N <= 1;
							BCS2_N <= 1;
							BCSS_N <= 1;
							BBUS_RDY <= 1;
							BBUS_ST <= BS_END;
						end
					end
				end
				
				BS_END: begin
					if (!BBUS_REQ) begin
						BBUS_ST <= BS_IDLE;
					end
				end
			endcase
		end
	end
	
	bit CBUS_RLS;
	bit CBREQ;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			CBREQ <= 0;
			CBUS_RLS <= 1;
		end
		else begin
			if (!RES_N) begin
				CBREQ <= 0;
				CBUS_RLS <= 1;
			end
			else if (CE_F) begin
				if (CBUS_REQ && CBUS_RLS) begin
					CBREQ <= 1;
				end
				else if (CBREQ && !CBACK_N && CBUS_RLS) begin
					CBUS_RLS <= 0;
				end
				else if (CBREQ && CBUS_RDY && !CBUS_RLS) begin
					CBREQ <= 0;
				end
				else if (!CBREQ && !CBUS_RLS) begin
					CBUS_RLS <= 1;
				end
			end
		end
	end
	
	assign CBREQ_N = ~CBREQ;
	
	always @(posedge CLK or negedge RST_N) begin		
		if (!RST_N) begin
			CBUS_CS <= 0;
			CBUS_ST <= CS_IDLE;
			CBUS_Q <= '0;
			CBUS_RDY <= 1;
		end
		else if (CE_R) begin
			case (CBUS_ST) 
				CS_IDLE: begin
					CBUS_RDY <= 0;
					if (CBUS_REQ && CBUS_RLS) begin
						CBUS_CS <= 1;
						CBUS_ST <= CS_ADDR;
					end
				end
				
				CS_ADDR: begin
					CBUS_ST <= CBUS_WE ? CS_WRITE : CS_READ;
				end
				
				CS_READ: begin
					if (ECWAIT_N) begin
						CBUS_Q <= ECDI;
						CBUS_CS <= 0;
						CBUS_RDY <= 1;
						CBUS_ST <= CS_IDLE;
					end
				end
				
				CS_WRITE: begin
					if (ECWAIT_N) begin
						CBUS_CS <= 0;
						CBUS_RDY <= 1;
						CBUS_ST <= CS_IDLE;
					end
				end
				
			endcase
		end
	end
				
	assign ECA = CBUS_A[24:0];
	assign ECDO = CBUS_D;
	assign ECDQM_N = ~{4{CBUS_WE}};
	assign ECRD_WR_N = ~CBUS_WE;
	assign ECRD_N = CBUS_WE;
	assign ECCS3_N = ~CBUS_CS;
	
	//DSP
	wire DSP_SEL = ~CCS2_N & CA[24:0] >= 25'h1FE0080 & CA[24:0] <= 25'h1FE008F;	//25FE0080-25FE008F
	
	bit [31:0] DSP_DO;
	SCU_DSP dsp(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		
		.A(CA[3:2]),
		.DI(CDI),
		.DO(DSP_DO),
		.CS_N(~DSP_SEL),
		.WR_N(CDQM_N),
		.RD_N(CRD_N),
		
		
		.DMA_A(DSP_DMA_A),
		.DMA_DI(DSP_DMA_DI),
		.DMA_DO(DSP_DMA_DO),
		.DMA_WE(DSP_DMA_WE),
		.DMA_REQ(DSP_DMA_REQ),
		.DMA_ACK(DSP_DMA_ACK),
		
		.IRQ(DSP_IRQ)
	);
	
	assign DSP_DMA_DI = DMA_DATA;
	
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
		else begin
			if (!RES_N) begin
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
				end
				
				if (REG_WR && CA[7:2] == 8'hA4>>2 && CE_F) begin
					if (!CDI[3]) TM0_INT <= 0;
					if (!CDI[4]) TM1_INT <= 0;
				end
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
			DSP_IRQ_OLD <= 0;
		end
		else begin
			if (!RES_N) begin
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
				
				if (REG_WR && CA[7:2] == 8'hA4>>2 && CE_F) begin
					if (!CDI[0]) VBIN_INT <= 0;
					if (!CDI[1]) VBOUT_INT <= 0;
					if (!CDI[2]) HBIN_INT <= 0;
					if (!CDI[5]) DSP_INT <= 0;
					if (!CDI[6]) SCSP_INT <= 0;
					if (!CDI[7]) SM_INT <= 0;
					if (!CDI[13]) VDP1_INT <= 0;
				end
			end
		end
	end
	
	wire [31:0] INT_STAT = {EXT_INT,2'b00,VDP1_INT,DMAIL_INT,DMA_INT[0],DMA_INT[1],DMA_INT[2],PAD_INT,SM_INT,SCSP_INT,DSP_INT,TM1_INT,TM0_INT,HBIN_INT,VBOUT_INT,VBIN_INT};
	
	always_comb begin
		if      (VBIN_INT      && !IMS.MS0)  CIRL_N = 4'h0;	//F
		else if (VBOUT_INT     && !IMS.MS1)  CIRL_N = 4'h1;	//E
		else if (HBIN_INT      && !IMS.MS2)  CIRL_N = 4'h2;	//D
		else if (TM0_INT       && !IMS.MS3)  CIRL_N = 4'h3;	//C
		else if (TM1_INT       && !IMS.MS4)  CIRL_N = 4'h4;	//B
		else if (DSP_INT       && !IMS.MS5)  CIRL_N = 4'h5;	//A
		else if (SCSP_INT      && !IMS.MS6)  CIRL_N = 4'h6;	//9
		else if (SM_INT        && !IMS.MS7)  CIRL_N = 4'h7;	//8
		else if (PAD_INT       && !IMS.MS8)  CIRL_N = 4'h7;	//8
		else if ((EXT_INT[0] ||
		          EXT_INT[1] ||
		          EXT_INT[2] ||
		          EXT_INT[3])  && !IMS.MS15) CIRL_N = 4'h8;	//7
		else if (DMA_INT[0]    && !IMS.MS9)  CIRL_N = 4'h9;	//6
		else if (DMA_INT[1]    && !IMS.MS10) CIRL_N = 4'h9;	//6
		else if (DMA_INT[2]    && !IMS.MS11) CIRL_N = 4'hA;	//5
		else if ((EXT_INT[4] ||
		          EXT_INT[5] ||
		          EXT_INT[6] ||
		          EXT_INT[7])  && !IMS.MS15) CIRL_N = 4'hB;	//4
		else if (DMAIL_INT     && !IMS.MS12) CIRL_N = 4'hC;	//3
		else if (VDP1_INT      && !IMS.MS13) CIRL_N = 4'hD;	//2
		else if ((EXT_INT[8]  ||
		          EXT_INT[9]  ||
		          EXT_INT[10] ||
		          EXT_INT[11] ||
		          EXT_INT[12] ||
		          EXT_INT[13] ||
		          EXT_INT[14] ||
		          EXT_INT[15]) && !IMS.MS15) CIRL_N = 4'hE;	//1
		else                                 CIRL_N = 4'hF;	//0
	end
	
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
			4'h8: IVEC = SM_INT ? 8'h47 : 8'h48;
			4'h7: IVEC = EXT_INT[0]  ? 8'h50 : 
			             EXT_INT[1]  ? 8'h51 : 
							 EXT_INT[2]  ? 8'h52 : 8'h53;
			4'h6: IVEC = DMA_INT[0]  ? 8'h49 : 8'h4A;
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
		else begin
			if (!RES_N) begin
				IVEC_DO <= '0;
			end else begin
				if (!CIVECF_N && CRD_N && CE_R) begin
					IVEC_DO <= IVEC;
				end
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
			RSEL <= 0;
			
			REG_DO <= '0;
		end
		else begin
			if (!RES_N) begin
				DR <= '{'0,'0,'0};
				DW <= '{'0,'0,'0};
				DC <= '{'0,'0,'0};
				
				RSEL <= RSEL_INIT;
			end else begin
				if (REG_WR && CE_F) begin
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
							if (!CDQM_N[0]) DAD[0][ 7: 0] <= CDI[ 7: 0] & DxAD_WMASK[ 7: 0];
							if (!CDQM_N[1]) DAD[0][15: 8] <= CDI[15: 8] & DxAD_WMASK[15: 8];
							if (!CDQM_N[2]) DAD[0][23:16] <= CDI[23:16] & DxAD_WMASK[23:16];
							if (!CDQM_N[3]) DAD[0][26:24] <= CDI[26:24] & DxAD_WMASK[26:24];
						end
						8'h10: begin
							if (!CDQM_N[0]) DEN[0][ 7: 0] <= CDI[ 7: 0] & DxEN_WMASK[ 7: 0];
							if (!CDQM_N[1]) DEN[0][15: 8] <= CDI[15: 8] & DxEN_WMASK[15: 8];
							if (!CDQM_N[2]) DEN[0][23:16] <= CDI[23:16] & DxEN_WMASK[23:16];
							if (!CDQM_N[3]) DEN[0][26:24] <= CDI[26:24] & DxEN_WMASK[26:24];
						end
						8'h14: begin
							if (!CDQM_N[0]) DMD[0][ 7: 0] <= CDI[ 7: 0] & DxMD_WMASK[ 7: 0];
							if (!CDQM_N[1]) DMD[0][15: 8] <= CDI[15: 8] & DxMD_WMASK[15: 8];
							if (!CDQM_N[2]) DMD[0][23:16] <= CDI[23:16] & DxMD_WMASK[23:16];
							if (!CDQM_N[3]) DMD[0][26:24] <= CDI[26:24] & DxMD_WMASK[26:24];
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
							if (!CDQM_N[0]) DAD[1][ 7: 0] <= CDI[ 7: 0] & DxAD_WMASK[ 7: 0];
							if (!CDQM_N[1]) DAD[1][15: 8] <= CDI[15: 8] & DxAD_WMASK[15: 8];
							if (!CDQM_N[2]) DAD[1][23:16] <= CDI[23:16] & DxAD_WMASK[23:16];
							if (!CDQM_N[3]) DAD[1][26:24] <= CDI[26:24] & DxAD_WMASK[26:24];
						end
						8'h30: begin
							if (!CDQM_N[0]) DEN[1][ 7: 0] <= CDI[ 7: 0] & DxEN_WMASK[ 7: 0];
							if (!CDQM_N[1]) DEN[1][15: 8] <= CDI[15: 8] & DxEN_WMASK[15: 8];
							if (!CDQM_N[2]) DEN[1][23:16] <= CDI[23:16] & DxEN_WMASK[23:16];
							if (!CDQM_N[3]) DEN[1][26:24] <= CDI[26:24] & DxEN_WMASK[26:24];
						end
						8'h34: begin
							if (!CDQM_N[0]) DMD[1][ 7: 0] <= CDI[ 7: 0] & DxMD_WMASK[ 7: 0];
							if (!CDQM_N[1]) DMD[1][15: 8] <= CDI[15: 8] & DxMD_WMASK[15: 8];
							if (!CDQM_N[2]) DMD[1][23:16] <= CDI[23:16] & DxMD_WMASK[23:16];
							if (!CDQM_N[3]) DMD[1][26:24] <= CDI[26:24] & DxMD_WMASK[26:24];
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
							if (!CDQM_N[0]) DAD[2][ 7: 0] <= CDI[ 7: 0] & DxAD_WMASK[ 7: 0];
							if (!CDQM_N[1]) DAD[2][15: 8] <= CDI[15: 8] & DxAD_WMASK[15: 8];
							if (!CDQM_N[2]) DAD[2][23:16] <= CDI[23:16] & DxAD_WMASK[23:16];
							if (!CDQM_N[3]) DAD[2][26:24] <= CDI[26:24] & DxAD_WMASK[26:24];
						end
						8'h50: begin
							if (!CDQM_N[0]) DEN[2][ 7: 0] <= CDI[ 7: 0] & DxEN_WMASK[ 7: 0];
							if (!CDQM_N[1]) DEN[2][15: 8] <= CDI[15: 8] & DxEN_WMASK[15: 8];
							if (!CDQM_N[2]) DEN[2][23:16] <= CDI[23:16] & DxEN_WMASK[23:16];
							if (!CDQM_N[3]) DEN[2][26:24] <= CDI[26:24] & DxEN_WMASK[26:24];
						end
						8'h54: begin
							if (!CDQM_N[0]) DMD[2][ 7: 0] <= CDI[ 7: 0] & DxMD_WMASK[ 7: 0];
							if (!CDQM_N[1]) DMD[2][15: 8] <= CDI[15: 8] & DxMD_WMASK[15: 8];
							if (!CDQM_N[2]) DMD[2][23:16] <= CDI[23:16] & DxMD_WMASK[23:16];
							if (!CDQM_N[3]) DMD[2][26:24] <= CDI[26:24] & DxMD_WMASK[26:24];
						end
						
						8'h60: begin
							if (!CDQM_N[0]) DSTP[ 7: 0] <= CDI[ 7: 0] & DSTP_WMASK[ 7: 0];
							if (!CDQM_N[1]) DSTP[15: 8] <= CDI[15: 8] & DSTP_WMASK[15: 8];
							if (!CDQM_N[2]) DSTP[23:16] <= CDI[23:16] & DSTP_WMASK[23:16];
							if (!CDQM_N[3]) DSTP[26:24] <= CDI[26:24] & DSTP_WMASK[26:24];
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
							if (!CDQM_N[3]) T1MD[26:24] <= CDI[26:24] & T1MD_WMASK[26:24];
						end
						8'hA0: begin
							if (!CDQM_N[0]) IMS[ 7: 0] <= CDI[ 7: 0] & IMS_WMASK[ 7: 0];
							if (!CDQM_N[1]) IMS[15: 8] <= CDI[15: 8] & IMS_WMASK[15: 8];
							if (!CDQM_N[2]) IMS[23:16] <= CDI[23:16] & IMS_WMASK[23:16];
							if (!CDQM_N[3]) IMS[26:24] <= CDI[26:24] & IMS_WMASK[26:24];
						end
						
						8'hC4: begin
							if (!CDQM_N[0]) RSEL <= CDI[0] & RSEL_WMASK[0];
						end
						default:;
					endcase
				end else if (REG_RD && CE_R) begin
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
						8'h70: REG_DO <= DSTA & DSTA_RMASK;
						
						8'hA4: REG_DO <= INT_STAT & IST_RMASK;
						
						8'hC4: REG_DO <= {31'h00000000,RSEL} & RSEL_RMASK;
						
						default: REG_DO <= '0;
					endcase
				end
				
				if (CE_R) begin
					if (DMA_RUN[0]) begin
						
					end
					else if (DMA_END) begin
						if (DMD[DMA_CH].RUP) DR[DMA_CH] <= DMA_RA[DMA_CH];
						if (DMD[DMA_CH].WUP) DW[DMA_CH] <= !DMD[DMA_CH].MOD ? DMA_WA[DMA_CH] : DMA_IA[DMA_CH];
					end
				end
			end
		end
	end
	
	assign CDO = ABUS_SEL || BBUS_SEL ? AB_DO : 
	             !CIVECF_N            ? {24'h000000,IVEC_DO} :
					 DSP_SEL              ? DSP_DO : 
					 REG_DO;
	assign CWAIT_N = ~CBUS_WAIT;
	
endmodule
