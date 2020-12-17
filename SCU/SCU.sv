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
	output      [3:0] CIRL_N,
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
	
	RSEL_t     RSEL;
	
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
	typedef enum bit [4:0] {
		BS_IDLE  = 5'b00001,  
		BS_ADDRL = 5'b00010, 
		BS_ADDRH = 5'b00100,
		BS_READ  = 5'b01000,
		BS_WRITE = 5'b10000
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
	typedef enum bit [7:0] {
		DS_IDLE       = 8'b00000001,  
		DS_CPU_ACCESS = 8'b00000010, 
		DS_DMA_START  = 8'b00000100, 
		DS_DMA_IND    = 8'b00001000, 
		DS_DMA_ACCESS = 8'b00010000,
		DS_DMA_READ   = 8'b00100000,
		DS_DMA_WRITE  = 8'b01000000,
		DS_DMA_END    = 8'b10000000
	} DMAState_t;
	DMAState_t DMA_ST;
	
	wire ABUS_SEL = ~CCS1_N | (CA[24:16] < 9'h190 & ~CCS2_N);				//02000000-058FFFFF
	wire BBUS_SEL = CA[24:16] >= 9'h1A0 & CA[24:16] < 9'h1FE & ~CCS2_N;	//05A00000-05FDFFFF
	bit         CBUS_WAIT;
	
		bit  [31:0] DMA_DATA;
		bit  [31:0] AB_DO;
	always @(posedge CLK or negedge RST_N) begin
		bit  [26:0] DMA_ADDR;
		bit         DMA_WE;
		bit         DMA_IND;
		bit   [1:0] DMA_IND_REG;
		bit         DMA_DSP;
		
		if (!RST_N) begin
			DMA_RA <= '{'0,'0,'0};
			DMA_WA <= '{'0,'0,'0};
			DMA_IA <= '{'0,'0,'0};
			DMA_TN <= '{'0,'0,'0};
			DMA_CH <= '0;
			DMA_PEND <= '{0,0,0};
			DMA_RUN <= '{0,0,0};
			DMA_END <= 0;
			DMA_ST <= DS_IDLE;
			
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
		end
		else if (CE_R) begin
			DSP_DMA_ACK <= 0;
			DMA_DSP <= 0;
			
			if ((ABUS_SEL || BBUS_SEL) && !CBUS_WAIT) CBUS_WAIT <= 1;
			
			if (DEN[0].GO && DEN[0].EN && !DMA_PEND[0]) DMA_PEND[0] <= 1;
			if (DEN[1].GO && DEN[1].EN && !DMA_PEND[1]) DMA_PEND[1] <= 1;
			if (DEN[2].GO && DEN[2].EN && !DMA_PEND[2]) DMA_PEND[2] <= 1;
			case (DMA_ST)
				DS_IDLE : begin
					if (ABUS_SEL || BBUS_SEL) begin
						DMA_ST <= DS_CPU_ACCESS;
					end else if (DSP_DMA_REQ) begin
						DMA_ADDR <= DSP_DMA_A;
						DMA_DATA <= DSP_DMA_DO;
						DMA_WE <= DSP_DMA_WE;
						DMA_DSP <= 1;
						DMA_ST <= DS_DMA_ACCESS;
					end else if (DMA_PEND[0]) begin
						DMA_PEND[0] <= 0;
						DMA_CH <= 2'd0;
						DMA_RUN[0] <= 1;
						DMA_ST <= DS_DMA_START;
					end else if (DMA_PEND[1]) begin
						DMA_PEND[1] <= 0;
						DMA_CH <= 2'd1;
						DMA_RUN[1] <= 1;
						DMA_ST <= DS_DMA_START;
					end else if (DMA_PEND[2]) begin
						DMA_PEND[2] <= 0;
						DMA_CH <= 2'd2;
						DMA_RUN[2] <= 1;
						DMA_ST <= DS_DMA_START;
					end
				end
				
				DS_CPU_ACCESS : begin
					if (ABUS_SEL && !ABUS_REQ) begin	//A-BUS 02000000-058FFFFF
						ABUS_A <= CA[24:0];
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
					end else if (ABUS_REQ && ABUS_RDY) begin
						DMA_DATA <= ABUS_Q;
						ABUS_REQ <= 0;
					end
					
					if (DMA_ADDR[26:16] >= 11'h5A0 && DMA_ADDR[26:16] < 11'h5FE && !BBUS_REQ) begin	//B-BUS 05A00000-05FDFFFF
						BBUS_A <= DMA_ADDR[22:0];
						BBUS_D <= DMA_DATA;
						BBUS_WE <= DMA_WE;
						BBUS_REQ <= 1;
					end else if (BBUS_REQ && BBUS_RDY) begin
						DMA_DATA <= BBUS_Q;
						BBUS_REQ <= 0;
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
					
					if ((ABUS_REQ && ABUS_RDY) || (BBUS_REQ && BBUS_RDY) || (CBUS_REQ && CBUS_RDY)) begin
						DMA_ST <= DMA_DSP ? DS_IDLE :
						          DMA_IND ? DS_DMA_IND : 
						          DMA_WE ? DS_DMA_WRITE : 
						          DS_DMA_READ;
						DSP_DMA_ACK <= DMA_DSP;
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
					DMA_ST <= DS_IDLE;
				end
				
			endcase
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
						case (BBUS_A[22:21])
							2'b01: BCSS_N <= 0;
							2'b10: BCS1_N <= 0;
							2'b11: BCS2_N <= 0;
						endcase
						BBUS_ST <= BS_ADDRL;
					end
				end
				
				BS_ADDRL: begin
					BDO <= {11'h000,BBUS_A[20:16]};
					BDTEN_N <= 0;
					BADDT_N <= 0;
					BBUS_ST <= BS_ADDRH;
				end
				
				BS_ADDRH: begin
					BDO <= BBUS_A[15:0];
					BDTEN_N <= 0;
					BADDT_N <= 0;
					WORD <= 0;
					BBUS_ST <= BBUS_WE ? BS_WRITE : BS_READ;
				end
					
				BS_READ: begin
					BDTEN_N <= 0;
					BADDT_N <= 1;
					if ((!BCSS_N && !BRDYS_N) || (!BCS1_N && !BRDY1_N) || (!BCS2_N && !BRDY2_N)) begin
						WORD <= ~WORD;
						if (!WORD) begin
							BBUS_Q[31:16] <= BDI;
						end else begin
							BBUS_Q[15:0] <= BDI;
							BDTEN_N <= 1;
							BADDT_N <= 1;
							BCS1_N <= 1;
							BCS2_N <= 1;
							BCSS_N <= 1;
							BBUS_RDY <= 1;
							BBUS_ST <= BS_IDLE;
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
						WORD <= ~WORD;
						if (WORD) begin
							BDTEN_N <= 1;
							BADDT_N <= 1;
							BCS1_N <= 1;
							BCS2_N <= 1;
							BCSS_N <= 1;
							BBUS_RDY <= 1;
							BBUS_ST <= BS_IDLE;
						end
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
				else if (CBUS_RDY && !CBUS_RLS) begin
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
	
//	reg [31:0] MEM [16] = '{
//	32'h11111111, 32'h22222222, 32'h33333333, 32'h44444444, 
//	32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 
//	32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 
//	32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000
//	};
//	
//	bit [31:0] MEM_DO;
//	always @(posedge CLK or negedge RST_N) begin
//		if (!RST_N) begin
//			MEM_DO <= '0;
//			DSP_DMA_ACK <= 0;
//		end
//		else if (CE_R) begin
//			DSP_DMA_ACK <= 0;
//			if (DSP_DMA_REQ) begin
//				if (!DSP_DMA_WR) begin
//					MEM_DO <= MEM[DSP_DMA_A[5:2]];
//					DSP_DMA_ACK <= 1;
//				end
//			end
//		end
//	end
	
	assign DSP_DMA_DI = DMA_DATA;
	
	//Registers
	wire REG_SEL = ~CCS2_N & CA[24:0] >= 25'h1FE0000 & CA[24:0] <= 25'h1FE00CF;	//25FE0000-25FE00CF
	
	bit [31:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		
		if (!RST_N) begin
			DR <= '{'0,'0,'0};
			DW <= '{'0,'0,'0};
			DC <= '{'0,'0,'0};
			DSTA.D0MV <= 0;
			
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
				if (REG_SEL) begin
					if (!CRD_WR_N && !(&CDQM_N) && CE_F) begin
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
							
							8'hC4: begin
								if (!CDQM_N[0]) RSEL <= CDI[0] & RSEL_WMASK[0];
							end
							default:;
						endcase
					end else if (CRD_WR_N && !CRD_N && CE_R) begin
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
							8'hC4: REG_DO <= {31'h00000000,RSEL} & RSEL_RMASK;
							
							default: REG_DO <= '0;
						endcase
					end
				end
				
				if (CE_R) begin
					if (DMA_RUN[0]) begin
						DSTA.D0MV <= 1;
					end
					else if (DMA_END) begin
						if (DMD[DMA_CH].RUP) DR[DMA_CH] <= DMA_RA[DMA_CH];
						if (DMD[DMA_CH].WUP) DW[DMA_CH] <= !DMD[DMA_CH].MOD ? DMA_WA[DMA_CH] : DMA_IA[DMA_CH];
						DSTA.D0MV <= 0;
					end
				end
			end
		end
	end
	
	assign CDO = ABUS_SEL || BBUS_SEL ? AB_DO : 
	             DSP_SEL              ? DSP_DO : REG_DO;
	assign CWAIT_N = ~CBUS_WAIT;
	assign CIRL_N = 4'hF;
	
endmodule
