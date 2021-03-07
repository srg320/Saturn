module Saturn (
	input             CLK,
	input             RST_N,
	input             CE,
	
	input             SRES_N,
	
	output     [24:0] MEM_A,
	input      [31:0] MEM_DI,
	output     [31:0] MEM_DO,
	output            ROM_CS_N,
	output            RAML_CS_N,
	output            RAMH_CS_N,
	output      [3:0] MEM_DQM_N,
	output            MEM_RD_N,
	input             MEM_WAIT_N,
	
	output     [18:1] VDP1_VRAM_A,
	output     [15:0] VDP1_VRAM_D,
	input      [15:0] VDP1_VRAM_Q,
	output      [1:0] VDP1_VRAM_WE,
	output            VDP1_VRAM_RD,
	input             VDP1_VRAM_RDY,
	
	output     [17:1] VDP1_FB0_A,
	output     [15:0] VDP1_FB0_D,
	input      [15:0] VDP1_FB0_Q,
	output            VDP1_FB0_WE,
	output            VDP1_FB0_RD,
	
	output     [17:1] VDP1_FB1_A,
	output     [15:0] VDP1_FB1_D,
	input      [15:0] VDP1_FB1_Q,
	output            VDP1_FB1_WE,
	output            VDP1_FB1_RD,
	
	output     [16:1] VDP2_RA0_A,
	output     [15:0] VDP2_RA0_D,
	input      [31:0] VDP2_RA0_Q,
	output      [1:0] VDP2_RA0_WE,
	output            VDP2_RA0_RD,
	
	output     [16:1] VDP2_RA1_A,
	output     [15:0] VDP2_RA1_D,
	input      [31:0] VDP2_RA1_Q,
	output      [1:0] VDP2_RA1_WE,
	output            VDP2_RA1_RD,
	
	output     [16:1] VDP2_RB0_A,
	output     [15:0] VDP2_RB0_D,
	input      [31:0] VDP2_RB0_Q,
	output      [1:0] VDP2_RB0_WE,
	output            VDP2_RB0_RD,
	
	output     [16:1] VDP2_RB1_A,
	output     [15:0] VDP2_RB1_D,
	input      [31:0] VDP2_RB1_Q,
	output      [1:0] VDP2_RB1_WE,
	output            VDP2_RB1_RD,

	output     [18:1] SCSP_RAM_A,
	output     [15:0] SCSP_RAM_D,
	output      [1:0] SCSP_RAM_WE,
	input      [15:0] SCSP_RAM_Q,
	
	output      [7:0] R,
	output      [7:0] G,
	output      [7:0] B,
	output reg        DCLK,
	output reg        HS_N,
	output reg        VS_N,
	output reg        HBL_N,
	output reg        VBL_N,
	
	input      [15:0] JOY1,
	
	input       [5:0] SCRN_EN,
	
	output      [7:0] DBG_WAIT_CNT
);

	bit CE_R, CE_F;
	always @(posedge CLK) begin
		if (CE) CE_R <= ~CE_R;
	end
	assign CE_F = ~CE_R;
	
	bit         SYSRES_N;
	
	//SCU
	bit  [24:0] CA;
	bit  [31:0] CDO;
	bit  [31:0] CDI;
	bit         CBS_N;
	bit         CCS0_N;
	bit         CCS1_N;
	bit         CCS2_N;
	bit         CCS3_N;
	bit         CRD_WR_N;
	bit   [3:0] CDQM_N;
	bit         CRD_N;
	bit         CWAIT_N;
	bit         CWATIN_N;
	bit         CIVECF_N;
	bit   [3:0] CIRL_N;
	bit         CBREQ_N;
	bit         CBACK_N;
	
	bit  [24:0] ECA;
	bit  [31:0] ECDI;
	bit  [31:0] ECDO;
	bit   [3:0] ECDQM_N;
	bit         ECRD_WR_N;
	bit         ECCS3_N;
	bit         ECRD_N;
	bit         ECWAIT_N;

	bit  [25:0] AA;
	bit  [15:0] ADI;
	bit  [15:0] ADO;
	bit   [1:0] AFC;
	bit         AAS_N;
	bit         ACS0_N;
	bit         ACS1_N;
	bit         ACS2_N;
	bit         AWAIT_N;
	bit         AIRQ_N;
	bit         ARD_N;
	bit         AWRL_N;
	bit         AWRU_N;
	bit         ATIM0_N;
	bit         ATIM1_N;
	bit         ATIM2_N;
	
	bit  [15:0] BDI;
	bit  [15:0] BDO;
	bit         BADDT_N;
	bit         BDTEN_N;
	bit   [1:0] BWE_N;
	bit         BCS1_N;
	bit         BRDY1_N;
	bit         IRQ1_N;
	bit         BCS2_N;
	bit         BRDY2_N;
	bit         IRQV_N;
	bit         IRQH_N;
	bit         IRQL_N;
	bit         BCSS_N;
	bit         BRDYS_N;
	bit         IRQS_N;
	
	bit         MIRQ_N;
	
	bit  [31:0] SCU_DO;
	
	//MSH
	bit  [26:0] MSHA;
	bit  [31:0] MSHDO;
	bit  [31:0] MSHDI;
	bit         MSHBS_N;
	bit         MSHCS0_N;
	bit         MSHCS1_N;
	bit         MSHCS2_N;
	bit         MSHCS3_N;
	bit         MSHRD_WR_N;
	bit   [3:0] MSHDQM_N;
	bit         MSHRD_N;
	bit         MSHWAIT_N;
	bit         MSHIVECF_N;
	bit   [3:0] MSHIRL_N;
	bit         MSHRES_N;
	bit         MSHNMI_N;
	bit         MSHBGR_N;
	bit         MSHBRLS_N;
	
	//SSH
	bit  [26:0] SSHA;
	bit  [31:0] SSHDO;
	bit  [31:0] SSHDI;
	bit         SSHBS_N;
	bit         SSHCS0_N;
	bit         SSHCS1_N;
	bit         SSHCS2_N;
	bit         SSHCS3_N;
	bit         SSHRD_WR_N;
	bit   [3:0] SSHDQM_N;
	bit         SSHRD_N;
	bit         SSHWAIT_N;
	bit         SSHIVECF_N;
	bit   [3:0] SSHIRL_N;
	bit         SSHRES_N;
	bit         SSHNMI_N;
	bit         SSHBREQ_N;
	bit         SSHBACK_N;
	
	//DCC
	bit         DRAMCE_N;
	bit         ROMCE_N;
	bit         SMPCCE_N;
	bit         MWR_N;
	bit   [1:0] BIRL;
	
	//SMPC
	bit   [7:0] SMPC_DO;
	bit         SNDRES_N;
	
	//VDP1
	bit  [15:0] VDP1_DO;
	bit  [15:0] VOUT;
	
	//VDP2
	bit  [15:0] VDP2_DO;
	bit         HTIM_N;
	bit         VTIM_N;
	
	//SCSP
	bit  [15:0] SCSP_DO;
	
	
	SH7604 MSH
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		
		.RES_N(MSHRES_N),
		.NMI_N(1'b1/*MSHNMI_N*/),
		
		.IRL_N(MSHIRL_N),
		
		.A(MSHA),
		.DI(MSHDI),
		.DO(MSHDO),
		.BS_N(MSHBS_N),
		.CS0_N(MSHCS0_N),
		.CS1_N(MSHCS1_N),
		.CS2_N(MSHCS2_N),
		.CS3_N(MSHCS3_N),
		.RD_WR_N(MSHRD_WR_N),
		.WE_N(MSHDQM_N),
		.RD_N(MSHRD_N),
		.IVECF_N(MSHIVECF_N),
		
		.EA(SSHA),
		.EDI(SSHDI),
		.EDO(SSHDO),
		.EBS_N(SSHBS_N),
		.ECS0_N(SSHCS0_N),
		.ECS1_N(SSHCS1_N),
		.ECS2_N(SSHCS2_N),
		.ECS3_N(SSHCS3_N),
		.ERD_WR_N(SSHRD_WR_N),
		.EWE_N(SSHDQM_N),
		.ERD_N(SSHRD_N),
		.ECE_N(1'b1),
		.EOE_N(1'b1),
		.EIVECF_N(SSHIVECF_N),
		
		.WAIT_N(MSHWAIT_N),
		.IVECF_N(),
//		.BRLS_N(MSHBRLS_N),
//		.BGR_N(MSHBGR_N),
		.BRLS_N(CBREQ_N),
		.BGR_N(CBACK_N),
		
		.DREQ0(1'b1),
		.DREQ1(1'b1),
		
		.FTCI(1'b1),
		.FTI(1'b0),
		
		.RXD(1'b1),
		.TXD(),
		.SCKO(),
		.SCKI(1'b1),
		
		.MD(6'b001000)
	);
	
	SH7604 SSH
	(
		.CLK(CLK),
		.RST_N(0/*RST_N*/),
		.CE_R(CE_R),
		.CE_F(CE_F),
		
		.RES_N(SSHRES_N),
		.NMI_N(SSHNMI_N),
		
		.IRL_N(SSHIRL_N),
		
		.A(SSHA),
		.DI(SSHDI),
		.DO(SSHDO),
		.BS_N(SSHBS_N),
		.CS0_N(SSHCS0_N),
		.CS1_N(SSHCS1_N),
		.CS2_N(SSHCS2_N),
		.CS3_N(SSHCS3_N),
		.RD_WR_N(SSHRD_WR_N),
		.WE_N(SSHDQM_N),
		.RD_N(SSHRD_N),
		.IVECF_N(SSHIVECF_N),
		
		.EA({2'b00,ECA}),
		.EDI(ECDI),
		.EDO(ECDO),
		.EBS_N(1'b1),
		.ECS0_N(1'b1),
		.ECS1_N(1'b1),
		.ECS2_N(1'b1),
		.ECS3_N(ECCS3_N),
		.ERD_WR_N(ECRD_WR_N),
		.EWE_N(ECDQM_N),
		.ERD_N(ECRD_N),
		.ECE_N(1'b1),
		.EOE_N(1'b1),
		.EIVECF_N(1'b1),
		
		.WAIT_N(SSHWAIT_N),
		.BRLS_N(SSHBACK_N),
		.BGR_N(SSHBREQ_N),
		
		.DREQ0(1'b1),
		.DREQ1(1'b1),
		
		.FTCI(1'b1),
		.FTI(1'b0),
		
		.RXD(1'b1),
		.TXD(),
		.SCKO(),
		.SCKI(1'b1),
		
		.MD(6'b101000)
	);
	
	assign MSHIRL_N  = CIRL_N;
	assign SSHIRL_N  = {1'b1,BIRL,1'b1};
	assign SSHBACK_N = MSHBGR_N;
	assign MSHBRLS_N = SSHBREQ_N;

	assign MSHDI     = CDO;
	assign MSHWAIT_N = CWAIT_N & (MEM_WAIT_N | (MSHCS3_N & DRAMCE_N & ROMCE_N));
	assign SSHWAIT_N = CWAIT_N & (MEM_WAIT_N | (MSHCS3_N & DRAMCE_N & ROMCE_N));
	
	assign CA       = MSHA[24:0];
	assign CDO      = !MSHCS3_N || !DRAMCE_N || !ROMCE_N ? MEM_DI :
                     !SMPCCE_N                          ? {4{SMPC_DO}} :
							SCU_DO;
	assign CDI      = MSHDO;
	assign CBS_N    = MSHBS_N;
	assign CCS0_N   = MSHCS0_N;
	assign CCS1_N   = MSHCS1_N;
	assign CCS2_N   = MSHCS2_N;
	assign CCS3_N   = MSHCS3_N;
	assign CRD_WR_N = MSHRD_WR_N;
	assign CDQM_N   = MSHDQM_N;
	assign CRD_N    = MSHRD_N;
	assign CIVECF_N = MSHIVECF_N;
	
	assign ECWAIT_N = MEM_WAIT_N;
	assign AWAIT_N  = 1;
	assign AIRQ_N   = 1;
	assign BDI      = !BCS1_N ? VDP1_DO :
	                  !BCS2_N ? VDP2_DO :
							!BCSS_N ? SCSP_DO : 16'h0000;
	assign IRQL_N   = 1;
	assign IRQS_N   = 1;
	
	bit [20:0] BA;
	SCU SCU
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		
		.RES_N(SYSRES_N),
		
		.CA(CA),
		.CDI(CDI),
		.CDO(SCU_DO),
		.CCS1_N(CCS1_N),
		.CCS2_N(CCS2_N),
		.CCS3_N(CCS3_N),
		.CRD_WR_N(CRD_WR_N),
		.CDQM_N(CDQM_N),
		.CRD_N(CRD_N),
		.CWAIT_N(CWATIN_N),
		.CIVECF_N(CIVECF_N),
		.CIRL_N(CIRL_N),
		.CBREQ_N(CBREQ_N),
		.CBACK_N(CBACK_N),
		
		.ECA(ECA),
		.ECDI(ECDI),
		.ECDO(ECDO),
		.ECDQM_N(ECDQM_N),
		.ECRD_WR_N(ECRD_WR_N),
		.ECCS3_N(ECCS3_N),
		.ECRD_N(ECRD_N),
		.ECWAIT_N(ECWAIT_N),
		
		.AA(AA),
		.ADI(ADI),
		.ADO(ADO),
		.AFC(AFC),
		.AAS_N(AAS_N),
		.ACS0_N(ACS0_N),
		.ACS1_N(ACS1_N),
		.ACS2_N(ACS2_N),
		.AWAIT_N(AWAIT_N),
		.AIRQ_N(AIRQ_N),
		.ARD_N(ARD_N),
		.AWRL_N(AWRL_N),
		.AWRU_N(AWRU_N),
		.ATIM0_N(ATIM0_N),
		.ATIM1_N(ATIM1_N),
		.ATIM2_N(ATIM2_N),
		
		.BDI(BDI),
		.BDO(BDO),
		.BADDT_N(BADDT_N),
		.BDTEN_N(BDTEN_N),
		.BWE_N(BWE_N),
		.BCS1_N(BCS1_N),
		.BRDY1_N(BRDY1_N),
		.IRQ1_N(IRQ1_N),
		.BCS2_N(BCS2_N),
		.BRDY2_N(BRDY2_N),
		.IRQV_N(IRQV_N),
		.IRQH_N(IRQH_N),
		.IRQL_N(IRQL_N),
		.BCSS_N(BCSS_N),
		.BRDYS_N(BRDYS_N),
		.IRQS_N(IRQS_N),
	
		.MIREQ_N(MIRQ_N)
	);
	
	
	DCC DCC
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		
		.RES_N(SYSRES_N),
		
		.A(CA[24:1]),
		.BS_N(CBS_N),
		.CS0_N(CCS0_N),
		.CS1_N(CCS1_N),
		.CS2_N(CCS2_N),
		.RD_WR_N(CRD_WR_N),
		.WE_N(CDQM_N[1:0]),
		.RD_N(CRD_N),
		.WAIT_N(CWAIT_N),
		
		.BRLS_N(),
		.BGR_N(1'b1),
		.BREQ_N(1'b1),
		.BACK_N(),
		.EXBREQ_N(1'b1),
		.EXBACK_N(),
		
		.WTIN_N(CWATIN_N),
		.IVECF_N(1'b1),
		
		.HINT_N(1'b1),
		.VINT_N(1'b1),
		.IREQ_N(BIRL),
		
		.MFTI(),
		.SFTI(),
		
		.DCE_N(DRAMCE_N),
		.DOE_N(),
		.DWE_N(),
		
		.ROMCE_N(ROMCE_N),
		.SRAMCE_N(),
		.SMPCCE_N(SMPCCE_N),
		.MOE_N(),
		.MWR_N(MWR_N)
	);
	
	assign MEM_A     = CA[24:0];
	assign MEM_DO    = CDI;
	assign MEM_DQM_N = CDQM_N;
	assign MEM_RD_N  = CRD_N;
	assign ROM_CS_N  = ROMCE_N;
	assign RAML_CS_N = DRAMCE_N;
	assign RAMH_CS_N = MSHCS3_N;
	
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DBG_WAIT_CNT <= '0;
		end else if (CE_R) begin
			DBG_WAIT_CNT <= DBG_WAIT_CNT + 8'd1;
			if (CRD_N && CDQM_N[0] && CDQM_N[1] && CDQM_N[2] && CDQM_N[3]) begin
				DBG_WAIT_CNT <= 8'd0;
			end
		end
	end
	
	bit SMPC_CE;
	bit MRES_N;
	always @(posedge CLK or negedge RST_N) begin
		bit [2:0] CLK_CNT;
		
		if (!RST_N) begin
			SMPC_CE <= 0;
			CLK_CNT <= '0;
			MRES_N <= 0;
		end else if (CE_R) begin
			SMPC_CE <= 0;
				
			CLK_CNT <= CLK_CNT + 3'd1;
			if (CLK_CNT == 3'd6) begin
				CLK_CNT <= 3'd0;
				SMPC_CE <= 1;
			end
			
			if (SMPC_CE) MRES_N <= 1;
		end
	end
	
	SMPC SMPC
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE(SMPC_CE),
		
		.MRES_N(MRES_N),
		
		.AC(4'h4),	//North America area
		
		.A(CA[6:1]),
		.DI(CDI[7:0]),
		.DO(SMPC_DO),
		.CS_N(SMPCCE_N),
		.RW_N(MWR_N),
		
		.SRES_N(SRES_N),
		
		.IRQV_N(IRQV_N),
		.EXL(1'b0),
		
		.MSHRES_N(MSHRES_N),
		.MSHNMI_N(MSHNMI_N),
		
		.SSHRES_N(SSHRES_N),
		.SSHNMI_N(SSHNMI_N),
		
		.SYSRES_N(SYSRES_N),
		.SNDRES_N(SNDRES_N),
		.CDRES_N(),
		
		.MIRQ_N(MIRQ_N),
		
		.P1I(7'h00),
		.P1O(),
		.P2I(7'h00),
		.P2O(),
		
		.JOY1(JOY1)
	);
	

	VDP1 VDP1
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		
		.RES_N(SYSRES_N),
		
		.DI(BDO),
		.DO(VDP1_DO),
		.CS_N(BCS1_N),
		.AD_N(BADDT_N),
		.DTEN_N(BDTEN_N),
		.WE_N(BWE_N),
		.RDY_N(BRDY1_N),
		
		.IRQ_N(IRQ1_N), 
		
		.DCLK(DCLK),
		.VTIM_N(VTIM_N),
		.HTIM_N(HTIM_N),
		.VOUT(VOUT),
		
		.VRAM_A(VDP1_VRAM_A),
		.VRAM_D(VDP1_VRAM_D),
		.VRAM_WE(VDP1_VRAM_WE),
		.VRAM_RD(VDP1_VRAM_RD),
		.VRAM_Q(VDP1_VRAM_Q),
		.VRAM_RDY(VDP1_VRAM_RDY),
		
		.FB0_A(VDP1_FB0_A),
		.FB0_D(VDP1_FB0_D),
		.FB0_WE(VDP1_FB0_WE),
		.FB0_RD(VDP1_FB0_RD),
		.FB0_Q(VDP1_FB0_Q),
		
		.FB1_A(VDP1_FB1_A),
		.FB1_D(VDP1_FB1_D),
		.FB1_WE(VDP1_FB1_WE),
		.FB1_RD(VDP1_FB1_RD),
		.FB1_Q(VDP1_FB1_Q)
	);
	
	VDP2 VDP2
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		
		.RES_N(SYSRES_N),
		
		.DI(BDO),
		.DO(VDP2_DO),
		.CS_N(BCS2_N),
		.AD_N(BADDT_N),
		.DTEN_N(BDTEN_N),
		.WE_N(BWE_N),
		.RDY_N(BRDY2_N),
		
		.VINT_N(IRQV_N),
		.HINT_N(IRQH_N),
		
		.HTIM_N(HTIM_N),
		.VTIM_N(VTIM_N),
		.FBD(VOUT),
		
		.RA0_A(VDP2_RA0_A),
		.RA0_D(VDP2_RA0_D),
		.RA0_WE(VDP2_RA0_WE),
		.RA0_RD(VDP2_RA0_RD),
		.RA0_Q(VDP2_RA0_Q),
		
		.RA1_A(VDP2_RA1_A),
		.RA1_D(VDP2_RA1_D),
		.RA1_WE(VDP2_RA1_WE),
		.RA1_RD(VDP2_RA1_RD),
		.RA1_Q(VDP2_RA1_Q),
		
		.RB0_A(VDP2_RB0_A),
		.RB0_D(VDP2_RB0_D),
		.RB0_WE(VDP2_RB0_WE),
		.RB0_RD(VDP2_RB0_RD),
		.RB0_Q(VDP2_RB0_Q),
		
		.RB1_A(VDP2_RB1_A),
		.RB1_D(VDP2_RB1_D),
		.RB1_WE(VDP2_RB1_WE),
		.RB1_RD(VDP2_RB1_RD),
		.RB1_Q(VDP2_RB1_Q),
		
		.R(R),
		.G(G),
		.B(B),
		.DCLK(DCLK),
		.VS_N(VS_N),
		.HS_N(HS_N),
		.HBL_N(HBL_N),
		.VBL_N(VBL_N),
		
		.SCRN_EN(SCRN_EN)
	);
	
	
	bit         SCCE_R;
	bit         SCCE_F;
	bit  [23:1] SCA;
	bit  [15:0] SCDI;
	bit  [15:0] SCDO;
	bit         SCRW_N;
	bit         SCAS_N;
	bit         SCLDS_N;
	bit         SCUDS_N;
	bit         SCDTACK_N;
	bit   [2:0] SCFC;
	bit         SCAVEC_N;
	bit   [2:0] SCIPL_N;
	SCSP SCSP
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE(CE_R),
		
		.RES_N(SYSRES_N),
		
		.CE_R(CE_R),
		.CE_F(CE_F),
		.DI(BDO),
		.DO(SCSP_DO),
		.CS_N(BCSS_N),
		.AD_N(BADDT_N),
		.DTEN_N(BDTEN_N),
		.WE_N(BWE_N),
		.RDY_N(BRDYS_N),
		
		.SCCE_R(SCCE_R),
		.SCCE_F(SCCE_F),
		.SCA(SCA),
		.SCDI(SCDI),
		.SCDO(SCDO),
		.SCRW_N(SCRW_N),
		.SCAS_N(SCAS_N),
		.SCLDS_N(SCLDS_N),
		.SCUDS_N(SCUDS_N),
		.SCDTACK_N(SCDTACK_N),
		.SCFC(SCFC),
		.SCAVEC_N(SCAVEC_N),
		.SCIPL_N(SCIPL_N),
		
		.RAM_A(SCSP_RAM_A),
		.RAM_D(SCSP_RAM_D),
		.RAM_WE(SCSP_RAM_WE),
		.RAM_Q(SCSP_RAM_Q)
	);
	
	fx68k M68K
	(
		.clk(CLK),
		.extReset(1/*~SNDRES_N*/),
		.pwrUp(~RST_N),
		.enPhi1(SCCE_R),
		.enPhi2(SCCE_F),

		.eab(SCA),
		.iEdb(SCDO),
		.oEdb(SCDI),
		.eRWn(SCRW_N),
		.ASn(SCAS_N),
		.UDSn(SCLDS_N),
		.LDSn(SCUDS_N),
		.DTACKn(SCDTACK_N),

		.IPL0n(SCIPL_N[0]),
		.IPL1n(SCIPL_N[1]),
		.IPL2n(SCIPL_N[2]),

		.VPAn(SCAVEC_N),
		
		.FC0(SCFC[0]),
		.FC1(SCFC[1]),
		.FC2(SCFC[2]),

		.BGn(),
		.BRn(1),
		.BGACKn(1),

		.BERRn(1),
		.HALTn(1)
	);

	
	
	//CD
	bit [15:0] AD;
	assign AD = AA[1] ? CDI[15:0] : CDI[31:16];
	
	bit [15:0] HIRQ;
	bit [15:0] HIRQMASK;
	bit [15:0] CR[4];
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			HIRQ <= 16'hFFFF;
			HIRQMASK <= 16'hFFFF;
			CR <= '{16'h0043,16'h4442,16'h4C4F,16'h434B};//'{16'hFFFF,16'hFFFF,16'hFFFF,16'hFFFF}
		end else if (CE_R) begin
			if (!ACS2_N && AA[25:16] == 10'h189 && (!AWRL_N || !AWRU_N)) begin
				case ({AA[15:1],1'b0})
//					16'h0008: HIRQ <= HIRQ & AD;//HIRQ
					16'h000C: HIRQMASK <= AD;	//HIRQMASK
//					16'h0018: CR[0] <= AD;	//CR1
//					16'h001C: CR[1] <= AD;	//CR2
//					16'h0020: CR[2] <= AD;	//CR3
//					16'h0024: CR[3] <= AD;	//CR4
					default: ;
				endcase
			end
		end
	end

	always_comb begin
		ADI = '0;
		if (!ACS1_N) begin
			ADI = 16'hFFFF;
		end else if (!ACS2_N && AA[25:16] == 10'h189) begin
			case ({AA[15:1],1'b0})
				16'h0008: ADI = HIRQ;		//HIRQ
				16'h000C: ADI = HIRQMASK;	//HIRQMASK
				16'h0018: ADI = CR[0];		//CR1
				16'h001C: ADI = CR[1];		//CR2
				16'h0020: ADI = CR[2];		//CR3
				16'h0024: ADI = CR[3];		//CR4
				default: ADI = '0;
			endcase
		end
	end
	
	
endmodule
