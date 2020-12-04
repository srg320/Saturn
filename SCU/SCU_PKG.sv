package SCU_PKG;

	typedef bit [26:0] DxR_t;	//R/W,25FE0000,25FE0020,25FE0040
	const bit [31:0] DxR_MASK = 32'h07FFFFFF;
	
	typedef bit [26:0] DxW_t;	//R/W,25FE0004,25FE0024,25FE0044
	const bit [31:0] DxW_MASK = 32'h07FFFFFF;
	
	typedef bit [19:0] D0C_t;	//R/W,25FE0008
	const bit [31:0] D0C_MASK = 32'h000FFFFF;
	
	typedef bit [11:0] D12C_t;	//R/W,25FE0028,25FE0048
	const bit [31:0] D12C_MASK = 32'h00000FFF;

	typedef struct packed		//W,25FE000C,25FE002C,25FE004C
	{
		bit [22: 0] UNSIGNED;
		bit         DRA;			//W
		bit [ 4: 0] UNSIGNED2;
		bit [ 2: 0] DWA;			//W
	} DxAD_t;
	const bit [31:0] DxAD_MASK = 32'h00000107;
	const bit [31:0] DxAD_INIT = 32'h00000101;
	
	typedef struct packed		//W,25FE0010,25FE0030,25FE0050
	{
		bit [22: 0] UNSIGNED;
		bit         EN;			//W
		bit [ 6: 0] UNSIGNED2;
		bit         GO;			//W
	} DxEN_t;
	const bit [31:0] DxEN_MASK = 32'h00000101;
	const bit [31:0] DxEN_INIT = 32'h00000000;
	
	typedef struct packed		//W,25FE0014,25FE0034,25FE0054
	{
		bit [ 6: 0] UNSIGNED;
		bit         MOD;			//W
		bit [ 6: 0] UNSIGNED2;
		bit         RUP;			//W
		bit [ 6: 0] UNSIGNED3;
		bit         WUP;			//W
		bit [ 4: 0] UNSIGNED4;
		bit [ 2: 0] FT;			//W
	} DxMD_t;
	const bit [31:0] DxMD_MASK = 32'h01010107;
	const bit [31:0] DxMD_INIT = 32'h00000007;

	typedef struct packed		//W,25FE0060
	{
		bit [30: 0] UNSIGNED;
		bit         STOP;			//W
	} DSTP_t;
	const bit [31:0] DSTP_MASK = 32'h00000001;
	const bit [31:0] DSTP_INIT = 32'h00000000;
	
	typedef struct packed		//R,25FE0070
	{
		bit [ 8: 0] UNSIGNED;
		bit         ACSD;			//R
		bit         ACSB;			//R
		bit         ACSA;			//R
		bit [ 1: 0] UNSIGNED2;
		bit         D1BK;			//R
		bit         D0BK;			//R
		bit [ 1: 0] UNSIGNED3;
		bit         D2WT;			//R
		bit         D2MV;			//R
		bit [ 1: 0] UNSIGNED4;
		bit         D1WT;			//R
		bit         D1MV;			//R
		bit [ 1: 0] UNSIGNED5;
		bit         D0WT;			//R
		bit         D0MV;			//R
		bit [ 1: 0] UNSIGNED6;
		bit         DDWT;			//R
		bit         DDMV;			//R
	} DSTA_t;
	const bit [31:0] DSTA_MASK = 32'h00733333;
	const bit [31:0] DSTA_INIT = 32'h00000000;
	
	typedef struct packed		//R/W,25FE0080
	{
		bit [ 4: 0] UNSIGNED;
		bit         PR;			//W
		bit         EP;			//W
		bit         UNSIGNED2;
		bit         T0;			//R
		bit         S;				//R
		bit         Z;				//R
		bit         C;				//R
		bit         V;				//R
		bit         E;				//R
		bit         ES;			//W
		bit         EX;			//R/W
		bit         LE;			//W
		bit [ 6: 0] UNSIGNED3;
		bit [ 7: 0] P;				//R/W
	} PPAF_t;
	const bit [31:0] PPAF_MASK = 32'h06FF80FF;
	const bit [31:0] PPAF_INIT = 32'h00000000;
	
	typedef bit [31:0] PPD_t;	//W,25FE0084
	const bit [31:0] PPD_MASK = 32'hFFFFFFFF;
	
	typedef struct packed		//W,25FE0088
	{
		bit [23: 0] UNSIGNED;
		bit [ 7: 0] RA;			//W
	} PDA_t;
	const bit [31:0] PDA_MASK = 32'h000000FF;
	const bit [31:0] PDA_INIT = 32'h00000000;
	
	typedef bit [31:0] PDD_t;	//W/R,25FE008C
	const bit [31:0] PDD_MASK = 32'hFFFFFFFF;
	
	typedef bit [9:0] T0C_t;	//W,25FE0090
	const bit [31:0] T0C_MASK = 32'h000003FF;
	
	typedef bit [8:0] T1S_t;	//W,25FE0094
	const bit [31:0] T1S_MASK = 32'h000001FF;
	
	typedef struct packed		//W,25FE0098
	{
		bit [22: 0] UNSIGNED;
		bit         MD;			//W
		bit [ 6: 0] UNSIGNED3;
		bit         ENB;			//W
	} T1MD_t;
	const bit [31:0] T1MD_MASK = 32'h00000101;
	const bit [31:0] T1MD_INIT = 32'h00000000;
	
	typedef struct packed		//W,25FE00A0
	{
		bit [15: 0] UNSIGNED;
		bit         MS15;			//W
		bit         UNSIGNED2;
		bit         MS13;			//W
		bit         MS12;			//W
		bit         MS11;			//W
		bit         MS10;			//W
		bit         MS9;			//W
		bit         MS8;			//W
		bit         MS7;			//W
		bit         MS6;			//W
		bit         MS5;			//W
		bit         MS4;			//W
		bit         MS3;			//W
		bit         MS2;			//W
		bit         MS1;			//W
		bit         MS0;			//W
	} IMS_t;
	const bit [31:0] IMS_MASK = 32'h0000BFFF;
	const bit [31:0] IMS_INIT = 32'h0000BFFF;
	
	typedef struct packed		//R/W,25FE00A4
	{
		bit [15: 0] EIS;			//R/W
		bit [ 1: 0] UNSIGNED;
		bit         SDEI;			//R/W
		bit         DII;			//R/W
		bit         D0EI;			//R/W
		bit         D1EI;			//R/W
		bit         D2EI;			//R/W
		bit         PADI;			//R/W
		bit         SMI;			//R/W
		bit         SRI;			//R/W
		bit         PEI;			//R/W
		bit         T1I;			//R/W
		bit         T0I;			//R/W
		bit         HBII;			//R/W
		bit         VBOI;			//R/W
		bit         VBII;			//R/W
	} IST_t;
	const bit [31:0] IST_MASK = 32'hFFFF3FFF;
	const bit [31:0] IST_INIT = 32'h00000000;
	
	typedef bit AIACK_t;		//R/W,25FE00A8
	const bit [31:0] AIACK_MASK = 32'h00000001;
	const bit [31:0] AIACK_INIT = 32'h00000000;
	
	typedef struct packed		//W,25FE00B0
	{
		bit         A0PRD;		//W
		bit         A0WPC;		//W
		bit         A0RPC;		//W
		bit         A0EWT;		//W
		bit [ 3: 0] A0BW;			//W
		bit [ 3: 0] A0NW;			//W
		bit [ 1: 0] A0LN;			//W
		bit         UNSIGNED;
		bit         A0SZ;			//W
		bit         A1PRD;		//W
		bit         A1WPC;		//W
		bit         A1RPC;		//W
		bit         A1EWT;		//W
		bit [ 3: 0] A1BW;			//W
		bit [ 3: 0] A1NW;			//W
		bit [ 1: 0] A1LN;			//W
		bit         UNSIGNED2;
		bit         A1SZ;			//W
	} ASR0_t;
	const bit [31:0] ASR0_MASK = 32'hFFFDFFFD;
	const bit [31:0] ASR0_INIT = 32'h00000000;
	
	typedef struct packed		//W,25FE00B4
	{
		bit         A2PRD;		//W
		bit         A2WPC;		//W
		bit         A2RPC;		//W
		bit         A2EWT;		//W
		bit [ 7: 0] UNSIGNED;
		bit [ 1: 0] A2LN;			//W
		bit         UNSIGNED2;
		bit         A2SZ;			//W
		bit         A3PRD;		//W
		bit         A3WPC;		//W
		bit         A3RPC;		//W
		bit         A3EWT;		//W
		bit [ 3: 0] A3BW;			//W
		bit [ 3: 0] A3NW;			//W
		bit [ 1: 0] A3LN;			//W
		bit         UNSIGNED3;
		bit         A3SZ;			//W
	} ASR1_t;
	const bit [31:0] ASR1_MASK = 32'hF00DFFFD;
	const bit [31:0] ASR1_INIT = 32'h00000000;
	
	typedef struct packed		//W,25FE00B8
	{
		bit [26: 0] UNSIGNED;
		bit         ARFEN;		//W
		bit [ 3: 0] ARWT;			//W
	} AREF_t;
	const bit [31:0] AREF_MASK = 32'h0000001F;
	const bit [31:0] AREF_INIT = 32'h00000000;
	
	typedef bit RSEL_t;			//R/W,25FE00C4
	const bit [31:0] RSEL_MASK = 32'h00000001;
	const bit [31:0] RSEL_INIT = 32'h00000000;
	
	typedef bit [3:0] VER_t;	//R,25FE00C8
	const bit [31:0] VER_MASK = 32'h0000000F;
	const bit [31:0] VER_INIT = 32'h00000000;
	
endpackage
