package VDP2_PKG;

	typedef struct packed
	{
		bit         DISP;
		bit [ 5: 0] UNUSED;
		bit         BDCLMD;
		bit [ 1: 0] LSMD;
		bit [ 1: 0] VRESO;
		bit         UNUSED2;
		bit [ 2: 0] HRESO;
	} TVMD_t;
	
	typedef struct packed
	{
		bit [ 5: 0] UNUSED;
		bit         EXLTEN;
		bit         EXSYEN;
		bit [ 5: 0] UNUSED2;
		bit         DASEL;
		bit         EXBGEN;
	} EXTEN_t;

	typedef struct packed
	{
		bit [ 5: 0] UNUSED;
		bit         EXLTFG;
		bit         EXSYFG;
		bit [ 3: 0] UNUSED2;
		bit         VBLANK;
		bit         HBLANK;
		bit         ODD;
		bit         PAL;
	} TVSTAT_t;
	
	typedef struct packed
	{
		bit [ 5: 0] UNUSED;
		bit [ 9: 0] HCT;
	} HCNT_t;
	
	typedef struct packed
	{
		bit [ 5: 0] UNUSED;
		bit [ 9: 0] VCT;
	} VCNT_t;
	
	typedef struct packed
	{
		bit         VRAMSZ;
		bit [10: 0] UNUSED;
		bit [ 3: 0] VER;
	} VRSIZE_t;
	
	typedef struct packed
	{
		bit         CRKTE;
		bit         UNUSED;
		bit [ 1: 0] CRMD;
		bit [ 1: 0] UNUSED2;
		bit         VRBMD;
		bit         VRAMD;
		bit [ 1: 0] RDBSB1;
		bit [ 1: 0] RDBSB0;
		bit [ 1: 0] RDBSA1;
		bit [ 1: 0] RDBSA0;
	} RAMCTL_t;
	
	typedef struct packed
	{
		bit [ 3: 0] VCP0x0;
		bit [ 3: 0] VCP1x0;
		bit [ 3: 0] VCP2x0;
		bit [ 3: 0] VCP3x0;
	} CYCx0L_t;
	
	typedef struct packed
	{
		bit [ 3: 0] VCP4x0;
		bit [ 3: 0] VCP5x0;
		bit [ 3: 0] VCP6x0;
		bit [ 3: 0] VCP7x0;
	} CYCx0U_t;
	
	typedef struct packed
	{
		bit [ 3: 0] VCP0x1;
		bit [ 3: 0] VCP1x1;
		bit [ 3: 0] VCP2x1;
		bit [ 3: 0] VCP3x1;
	} CYCx1L_t;
	
	typedef struct packed
	{
		bit [ 3: 0] VCP4x1;
		bit [ 3: 0] VCP5x1;
		bit [ 3: 0] VCP6x1;
		bit [ 3: 0] VCP7x1;
	} CYCx1U_t;
	
	typedef struct packed
	{
		bit [ 2: 0] UNUSED;
		bit         R0TPON;
		bit         N3TPON;
		bit         N2TPON;
		bit         N1TPON;
		bit         N0TPON;
		bit [ 1: 0] UNUSED2;
		bit         R1ON;
		bit         R0ON;
		bit         N3ON;
		bit         N2ON;
		bit         N1ON;
		bit         N0ON;
	} BGON_t;
	
	typedef struct packed
	{
		bit [ 1: 0] UNUSED;
		bit [ 1: 0] N1CHCN;
		bit [ 1: 0] N1BMSZ;
		bit         N1BMEN;
		bit         N1CHSZ;
		bit         UNUSED2;
		bit [ 2: 0] N0CHCN;
		bit [ 1: 0] N0BMSZ;
		bit         N0BMEN;
		bit         N0CHSZ;
	} CHCTLA_t;
	
	typedef struct packed
	{
		bit         UNUSED;
		bit [ 2: 0] R0CHCN;
		bit         UNUSED2;
		bit         R0BMSZ;
		bit         R0BMEN;
		bit         R0CHSZ;
		bit [ 1: 0] UNUSED3;
		bit         N3CHCN;
		bit         N3CHSZ;
		bit [ 1: 0] UNUSED4;
		bit         N2CHCN;
		bit         N2CHSZ;
	} CHCTLB_t;
	
	typedef struct packed
	{
		bit         NxPNB;
		bit         NxCNSM;
		bit [ 3: 0] UNUSED;
		bit         NxSPR;
		bit         NxSCC;
		bit [ 6: 4] NxSPLT;
		bit [ 4: 0] NxSCN;
	} PNCNx_t;
	
	typedef struct packed
	{
		bit         R0PNB;
		bit         R0CNSM;
		bit [ 3: 0] UNUSED;
		bit         R0SPR;
		bit         R0SCC;
		bit [ 6: 4] R0SPLT;
		bit [ 4: 0] R0SCN;
	} PNCR_t;
	
	typedef struct packed
	{
		bit [ 1: 0] RBOVR;
		bit [ 1: 0] RBPLSZ;
		bit [ 1: 0] RAOVR;
		bit [ 1: 0] RAPLSZ;
		bit [ 1: 0] N3PLSZ;
		bit [ 1: 0] N2PLSZ;
		bit [ 1: 0] N1PLSZ;
		bit [ 1: 0] N0PLSZ;
	} PLSZ_t;
	
	typedef struct packed
	{
		bit [ 1: 0] UNUSED;
		bit         N1BMPR;
		bit         N1BMCC;
		bit         UNUSED2;
		bit [ 6: 4] N1BMP;
		bit [ 1: 0] UNUSED3;
		bit         N0BMPR;
		bit         N0BMCC;
		bit         UNUSED4;
		bit [ 6: 4] N0BMP;
	} BMPNA_t;
	
	typedef struct packed
	{
		bit [ 9: 0] UNUSED;
		bit         R0BMPR;
		bit         R0BMCC;
		bit         UNUSED2;
		bit [ 6: 4] R0BMP;
	} BMPNB_t;
	
	typedef struct packed
	{
		bit         UNUSED;
		bit [ 8: 6] N3MP;
		bit         UNUSED2;
		bit [ 8: 6] N2MP;
		bit         UNUSED3;
		bit [ 8: 6] N1MP;
		bit         UNUSED4;
		bit [ 8: 6] N0MP;
	} MPOFN_t;
	
	typedef struct packed
	{
		bit [ 8: 0] UNUSED;
		bit [ 8: 6] RBMP;
		bit         UNUSED2;
		bit [ 8: 6] RAMP;
	} MPOFR_t;
	
	typedef struct packed
	{
		bit [ 1: 0] UNUSED;
		bit [ 5: 0] NxMPB;
		bit [ 1: 0] UNUSED2;
		bit [ 5: 0] NxMPA;
	} MPABNx_t;
	
	typedef struct packed
	{
		bit [ 1: 0] UNUSED;
		bit [ 5: 0] NxMPD;
		bit [ 1: 0] UNUSED2;
		bit [ 5: 0] NxMPC;
	} MPCDNx_t;
	
	typedef struct packed
	{
		bit [ 1: 0] UNUSED;
		bit [ 5: 0] RxMPB;
		bit [ 1: 0] UNUSED2;
		bit [ 5: 0] RxMPA;
	} MPABRx_t;
	
	typedef struct packed
	{
		bit [ 1: 0] UNUSED;
		bit [ 5: 0] RxMPD;
		bit [ 1: 0] UNUSED2;
		bit [ 5: 0] RxMPC;
	} MPCDRx_t;
	
	typedef struct packed
	{
		bit [ 1: 0] UNUSED;
		bit [ 5: 0] RxMPF;
		bit [ 1: 0] UNUSED2;
		bit [ 5: 0] RxMPE;
	} MPEFRx_t;
	
	typedef struct packed
	{
		bit [ 1: 0] UNUSED;
		bit [ 5: 0] RxMPH;
		bit [ 1: 0] UNUSED2;
		bit [ 5: 0] RxMPG;
	} MPGHRx_t;
	
	typedef struct packed
	{
		bit [ 1: 0] UNUSED;
		bit [ 5: 0] RxMPJ;
		bit [ 1: 0] UNUSED2;
		bit [ 5: 0] RxMPI;
	} MPIJRx_t;
	
	typedef struct packed
	{
		bit [ 1: 0] UNUSED;
		bit [ 5: 0] RxMPL;
		bit [ 1: 0] UNUSED2;
		bit [ 5: 0] RxMPK;
	} MPKLRx_t;
	
	typedef struct packed
	{
		bit  [1:0] UNUSED;
		bit  [5:0] RxMPN;
		bit  [1:0] UNUSED2;
		bit  [5:0] RxMPM;
	} MPMNRx_t;
	
	typedef struct packed
	{
		bit [ 1: 0] UNUSED;
		bit [ 5: 0] RxMPP;
		bit [ 1: 0] UNUSED2;
		bit [ 5: 0] RxMPO;
	} MPOPRx_t;
	
	typedef struct packed
	{
		bit [15: 0] RxOPN;
	} OVPNRx_t;
	
	typedef struct packed
	{
		bit [ 3: 0] MZSZV;
		bit [ 3: 0] MZSZH;
		bit [ 2: 0] UNUSED;
		bit         R0MZE;
		bit         N3MZE;
		bit         N2MZE;
		bit         N1MZE;
		bit         N0MZE;
	} MZCTL_t;
	
	typedef struct packed
	{
		bit [ 4: 0] UNUSED;
		bit [10: 0] NxSCXI;
	} SCXINx_t;
	
	typedef struct packed
	{
		bit [ 1: 8] NxSCXD;
		bit [ 7: 0] UNUSED;
	} SCXDNx_t;
	
	typedef struct packed
	{
		bit [ 4: 0] UNUSED;
		bit [10: 0] NxSCYI;
	} SCYINx_t;
	
	typedef struct packed
	{
		bit [ 1: 8] NxSCYD;
		bit [ 7: 0] UNUSED;
	} SCYDNx_t;
	
	typedef struct packed
	{
		bit [ 4: 0] UNUSED;
		bit [10: 0] NxSCX;
	} SCXNx_t;
	
	typedef struct packed
	{
		bit [ 4: 0] UNUSED;
		bit [10: 0] NxSCY;
	} SCYNx_t;
	
	typedef struct packed
	{
		bit [12: 0] UNUSED;
		bit [ 3: 0] NxZMXI;
	} ZMXINx_t;
	
	typedef struct packed
	{
		bit  [1:8] NxZMXD;
		bit  [7:0] UNUSED;
	} ZMXDNx_t;
	
	typedef struct packed
	{
		bit [12: 0] UNUSED;
		bit [ 3: 0] NxZMYI;
	} ZMYINx_t;
	
	typedef struct packed
	{
		bit [ 1: 8] NxZMYD;
		bit [ 7: 0] UNUSED;
	} ZMYDNx_t;
	
	typedef struct packed
	{
		bit [ 5: 0] UNUSED;
		bit         N1ZMQT;
		bit         N1ZMHF;
		bit [ 5: 0] UNUSED2;
		bit         N0ZMQT;
		bit         N0ZMHF;
	} ZMCTL_t;
	
	typedef struct packed
	{
		bit [ 1: 0] UNUSED;
		bit [ 1: 0] N1LSS;
		bit         N1LZMX;
		bit         N1LSCY;
		bit         N1LSCX;
		bit         N1VCSC;
		bit [ 1: 0] UNUSED2;
		bit [ 1: 0] N0LSS;
		bit         N0LZMX;
		bit         N0LSCY;
		bit         N0LSCX;
		bit         N0VCSC;
	} SCRCTL_t;
	
	typedef struct packed
	{
		bit [12: 0] UNUSED;
		bit [18:16] NxLSTA;
	} LSTAxU_t;
	
	typedef struct packed
	{
		bit [15: 1] NxLSTA;
		bit         UNUSED;
	} LSTAxL_t;
	
	typedef struct packed
	{
		bit [12: 0] UNUSED;
		bit [18:16] VCSTA;
	} VCSTAU_t;
	
	typedef struct packed
	{
		bit [15: 1] VCSTA;
		bit         UNUSED;
	} VCSTAL_t;
	
	typedef struct packed
	{
		bit [ 4: 0] UNUSED;
		bit         RBKASTRE;
		bit         RBYSTRE;
		bit         RBXSTRE;
		bit [ 4: 0] UNUSED2;
		bit         RAKASTRE;
		bit         RAYSTRE;
		bit         RAXSTRE;
	} RPRCTL_t;
	
	typedef struct packed
	{
		bit [12: 0] UNUSED;
		bit [18:16] RPTA;
	} RPTAU_t;
	
	typedef struct packed
	{
		bit [15: 1] RPTA;
		bit         UNUSED;
	} RPTAL_t;
	
	typedef struct packed
	{
		bit [13: 0] UNUSED;
		bit [ 1: 0] RPMD;
	} RPMD_t;
	
	typedef struct packed
	{
		bit [ 5: 0] UNUSED;
		bit [ 3: 0] RBKTAOS;
		bit [ 5: 0] UNUSED2;
		bit [ 3: 0] RAKTAOS;
	} KTAOF_t;
	
	typedef struct packed
	{
		bit         LCCLMD;
		bit [11: 0] UNUSED;
		bit [18:16] LCTA;
	} LCTAU_t;
	
	typedef struct packed
	{
		bit [15: 0] LCTA;
	} LCTAL_t;
	
	typedef struct packed
	{
		bit         BKCLMD;
		bit [11: 0] UNUSED;
		bit [18:16] BKTA;
	} BKTAU_t;
	
	typedef struct packed
	{
		bit [15: 0] BKTA;
	} BKTAL_t;
	
	typedef struct packed
	{
		bit [ 5: 0] UNUSED;
		bit [ 9: 0] WxSX;
	} WPSXx_t;
	
	typedef struct packed
	{
		bit [ 6: 0] UNUSED;
		bit [ 8: 0] WxSY;
	} WPSYx_t;
	
	typedef struct packed
	{
		bit [ 5: 0] UNUSED;
		bit [ 9: 0] WxEX;
	} WPEXx_t;
	
	typedef struct packed
	{
		bit [ 6: 0] UNUSED;
		bit [ 8: 0] WxEY;
	} WPEYx_t;
	
	typedef struct packed
	{
		bit         WxLWE;
		bit [11: 0] UNUSED;
		bit [18:16] WxLWTA;
	} LWTAxU_t;
	
	typedef struct packed
	{
		bit [15: 1] WxLWTA;
		bit         UNUSED;
	} LWTAxL_t;
	
	typedef struct packed
	{
		bit [ 1: 0] UNUSED;
		bit [ 1: 0] SPCCCS;
		bit         UNUSED2;
		bit [ 2: 0] SPCCN;
		bit [ 1: 0] UNUSED3;
		bit         SPCLMD;
		bit         SPWINEN;
		bit [ 3: 0] SPTYPE;
	} SPCTL_t;
	
	typedef struct packed
	{
		bit         N1LOG;
		bit         UNUSED;
		bit         N1SWE;
		bit         N1SWA;
		bit         N1W1E;
		bit         N1W1A;
		bit         N1W0E;
		bit         N1W0A;
		bit         N0LOG;
		bit         UNUSED2;
		bit         N0SWE;
		bit         N0SWA;
		bit         N0W1E;
		bit         N0W1A;
		bit         N0W0E;
		bit         N0W0A;
	} WCTLA_t;
	
	typedef struct packed
	{
		bit         N3LOG;
		bit         UNUSED;
		bit         N3SWE;
		bit         N3SWA;
		bit         N3W1E;
		bit         N3W1A;
		bit         N3W0E;
		bit         N3W0A;
		bit         N2LOG;
		bit         UNUSED2;
		bit         N2SWE;
		bit         N2SWA;
		bit         N2W1E;
		bit         N2W1A;
		bit         N2W0E;
		bit         N2W0A;
	} WCTLB_t;
	
	typedef struct packed
	{
		bit         SPLOG;
		bit         UNUSED;
		bit         SPSWE;
		bit         SPSWA;
		bit         SPW1E;
		bit         SPW1A;
		bit         SPW0E;
		bit         SPW0A;
		bit         R0LOG;
		bit         UNUSED2;
		bit         R0SWE;
		bit         R0SWA;
		bit         R0W1E;
		bit         R0W1A;
		bit         R0W0E;
		bit         R0W0A;
	} WCTLC_t;
	
	typedef struct packed
	{
		bit         CCLOG;
		bit         UNUSED;
		bit         CCSWE;
		bit         CCSWA;
		bit         CCW1E;
		bit         CCW1A;
		bit         CCW0E;
		bit         CCW0A;
		bit         RPLOG;
		bit [ 2: 0] UNUSED2;
		bit         RPW1E;
		bit         RPW1A;
		bit         RPW0E;
		bit         RPW0A;
	} WCTLD_t;
	
	typedef struct packed
	{
		bit [ 4: 0] UNUSED;
		bit [ 2: 0] S1PRIN;
		bit [ 4: 0] UNUSED2;
		bit [ 2: 0] S0PRIN;
	} PRISA_t;
	
	typedef struct packed
	{
		bit [ 4: 0] UNUSED;
		bit [ 2: 0] S3PRIN;
		bit [ 4: 0] UNUSED2;
		bit [ 2: 0] S2PRIN;
	} PRISB_t;
	
	typedef struct packed
	{
		bit [ 4: 0] UNUSED;
		bit [ 2: 0] S5PRIN;
		bit [ 4: 0] UNUSED2;
		bit [ 2: 0] S4PRIN;
	} PRISC_t;
	
	typedef struct packed
	{
		bit [ 4: 0] UNUSED;
		bit [ 2: 0] S7PRIN;
		bit [ 4: 0] UNUSED2;
		bit [ 2: 0] S6PRIN;
	} PRISD_t;
	
	typedef struct packed
	{
		bit [ 2: 0] UNUSED;
		bit [ 4: 0] S1CCRT;
		bit [ 2: 0] UNUSED2;
		bit [ 4: 0] S0CCRT;
	} CCRSA_t;
	
	typedef struct packed
	{
		bit [ 2: 0] UNUSED;
		bit [ 4: 0] S3CCRT;
		bit [ 2: 0] UNUSED2;
		bit [ 4: 0] S2CCRT;
	} CCRSB_t;
	
	typedef struct packed
	{
		bit [ 2: 0] UNUSED;
		bit [ 4: 0] S5CCRT;
		bit [ 2: 0] UNUSED2;
		bit [ 4: 0] S4CCRT;
	} CCRSC_t;
	
	typedef struct packed
	{
		bit [ 2: 0] UNUSED;
		bit [ 4: 0] S7CCRT;
		bit [ 2: 0] UNUSED2;
		bit [ 4: 0] S6CCRT;
	} CCRSD_t;
	
	typedef struct packed
	{
		bit         UNUSED;
		bit [ 2: 0] N3CAOS;
		bit         UNUSED2;
		bit [ 2: 0] N2CAOS;
		bit         UNUSED3;
		bit [ 2: 0] N1CAOS;
		bit         UNUSED4;
		bit [ 2: 0] N0CAOS;
	} CRAOFA_t;
	
	typedef struct packed
	{
		bit [ 8: 0] UNUSED;
		bit [ 2: 0] SPCAOS;
		bit         UNUSED2;
		bit [ 2: 0] R0CAOS;
	} CRAOFB_t;
	
	typedef struct packed
	{
		bit [10: 0] UNUSED;
		bit         R0SFCS;
		bit         N3SFCS;
		bit         N2SFCS;
		bit         N1SFCS;
		bit         N0SFCS;
	} SFSEL_t;
	
	typedef struct packed
	{
		bit [ 7: 0] SFCDB;
		bit [ 7: 0] SFCDA;
	} SFCODE_t;
	
	typedef struct packed
	{
		bit [ 4: 0] UNUSED;
		bit [ 2: 0] N1PRIN;
		bit [ 4: 0] UNUSED2;
		bit [ 2: 0] N0PRIN;
	} PRINA_t;
	
	typedef struct packed
	{
		bit [ 4: 0] UNUSED;
		bit [ 2: 0] N3PRIN;
		bit [ 4: 0] UNUSED2;
		bit [ 2: 0] N2PRIN;
	} PRINB_t;
	
	typedef struct packed
	{
		bit [12: 0] UNUSED;
		bit [ 2: 0] R0PRIN;
	} PRIR_t;
	
	typedef struct packed
	{
		bit [ 5: 0] UNUSED;
		bit [ 1: 0] R0SPRM;
		bit [ 1: 0] N3SPRM;
		bit [ 1: 0] N2SPRM;
		bit [ 1: 0] N1SPRM;
		bit [ 1: 0] N0SPRM;
	} SFPRMD_t;
	
	typedef struct packed
	{
		bit [ 9: 0] UNUSED;
		bit         SPLCEN;
		bit         R0LCEN;
		bit         N3LCEN;
		bit         N2LCEN;
		bit         N1LCEN;
		bit         N0LCEN;
	} LNCLEN_t;
	
	typedef struct packed
	{
		bit         BOKEN;
		bit [ 2: 0] BOKN;
		bit         UNUSED;
		bit         EXCCEN;
		bit         CCRTMD;
		bit         CCMD;
		bit         UNUSED2;
		bit         SPCCEN;
		bit         LCCCEN;
		bit         R0CCEN;
		bit         N3CCEN;
		bit         N2CCEN;
		bit         N1CCEN;
		bit         N0CCEN;
	} CCCTL_t;
	
	typedef struct packed
	{
		bit [ 2: 0] UNUSED;
		bit [ 4: 0] N1CCRT;
		bit [ 2: 0] UNUSED2;
		bit [ 4: 0] N0CCRT;
	} CCRNA_t;
	
	typedef struct packed
	{
		bit [ 2: 0] UNUSED;
		bit [ 4: 0] N3CCRT;
		bit [ 2: 0] UNUSED2;
		bit [ 4: 0] N2CCRT;
	} CCRNB_t;
	
	typedef struct packed
	{
		bit [10: 0] UNUSED;
		bit [ 4: 0] R0CCRT;
	} CCRR_t;
	
	typedef struct packed
	{
		bit [ 2: 0] UNUSED;
		bit [ 4: 0] BKCCRT;
		bit [ 2: 0] UNUSED2;
		bit [ 4: 0] LCCCRT;
	} CCRLB_t;
	
	typedef struct packed
	{
		bit [ 5: 0] UNUSED;
		bit [ 1: 0] R0SCCM;
		bit [ 1: 0] N3SCCM;
		bit [ 1: 0] N2SCCM;
		bit [ 1: 0] N1SCCM;
		bit [ 1: 0] N0SCCM;
	} SFCCMD_t;
	
	typedef struct packed
	{
		bit [ 8: 0] UNUSED;
		bit         SPCOEN;
		bit         BKCOEN;
		bit         R0COEN;
		bit         N3COEN;
		bit         N2COEN;
		bit         N1COEN;
		bit         N0COEN;
	} CLOFEN_t;
	
	typedef struct packed
	{
		bit [ 8: 0] UNUSED;
		bit         SPCOSL;
		bit         BKCOSL;
		bit         R0COSL;
		bit         N3COSL;
		bit         N2COSL;
		bit         N1COSL;
		bit         N0COSL;
	} CLOFSL_t;
	
	typedef struct packed
	{
		bit [ 6: 0] UNUSED;
		bit [ 8: 0] COxRD;
	} COxR_t;
	
	typedef struct packed
	{
		bit [ 6: 0] UNUSED;
		bit [ 8: 0] COxGR;
	} COxG_t;
	
	typedef struct packed
	{
		bit [ 6: 0] UNUSED;
		bit [ 8: 0] COxBL;
	} COxB_t;
	
	typedef struct packed
	{
		bit [ 6: 0] UNUSED;
		bit         TPSDSL;
		bit [ 1: 0] UNUSED2;
		bit         BKSDEN;
		bit         R0SDEN;
		bit         N3SDEN;
		bit         N2SDEN;
		bit         N1SDEN;
		bit         N0SDEN;
	} SDCTL_t;
	
	typedef struct packed
	{
		bit [ 2: 0] UNUSED;
		bit         RBKLCE;
		bit [ 1: 0] RBKMD;
		bit         RBKDBS;
		bit         RBKTE;
		bit [ 2: 0] UNUSED2;
		bit         RAKLCE;
		bit [ 1: 0] RAKMD;
		bit         RAKDBS;
		bit         RAKTE;
	} KTCTL_t;
	
	typedef struct packed
	{
		bit [15: 0] UNUSED;
	} RSRV_t;
	
	typedef struct packed
	{
		TVMD_t   TVMD;			//180000
		EXTEN_t  EXTEN;		//180002
		TVSTAT_t TVSTAT;		//180004
		VRSIZE_t VRSIZE;		//180006
		HCNT_t   HCNT;			//180008
		VCNT_t   VCNT;			//18000A
		RSRV_t   RSRV0;		//18000C
		RAMCTL_t RAMCTL;		//18000E
		CYCx0L_t CYCA0L;		//180010
		CYCx0U_t CYCA0U;		//180012
		CYCx1L_t CYCA1L;		//180014
		CYCx1U_t CYCA1U;		//180016
		CYCx0L_t CYCB0L;		//180018
		CYCx0U_t CYCB0U;		//18001A
		CYCx1L_t CYCB1L;		//18001C
		CYCx1U_t CYCB1U;		//18001E
		BGON_t   BGON;			//180020
		MZCTL_t  MZCTL;		//180022
		SFSEL_t  SFSEL;		//180024
		SFCODE_t SFCODE;		//180026
		CHCTLA_t CHCTLA;		//180028
		CHCTLB_t CHCTLB;		//18002A
		BMPNA_t  BMPNA;		//18002C
		BMPNB_t  BMPNB;		//18002E
		PNCNx_t  PNCN0;		//180030
		PNCNx_t  PNCN1;		//180032
		PNCNx_t  PNCN2;		//180034
		PNCNx_t  PNCN3;		//180036
		PNCR_t   PNCR;			//180038
		PLSZ_t   PLSZ;			//18003A
		MPOFN_t  MPOFN;		//18003C
		MPOFR_t  MPOFR;		//18003E
		MPABNx_t MPABN0;		//180040
		MPCDNx_t MPCDN0;		//180042
		MPABNx_t MPABN1;		//180044
		MPCDNx_t MPCDN1;		//180046
		MPABNx_t MPABN2;		//180048
		MPCDNx_t MPCDN2;		//18004A
		MPABNx_t MPABN3;		//18004C
		MPCDNx_t MPCDN3;		//18004E
		MPABRx_t MPABRA;		//180050
		MPCDRx_t MPCDRA;		//180052
		MPEFRx_t MPEFRA;		//180054
		MPGHRx_t MPGHRA;		//180056
		MPIJRx_t MPIJRA;		//180058
		MPKLRx_t MPKLRA;		//18005A
		MPMNRx_t MPMNRA;		//18005C
		MPOPRx_t MPOPRA;		//18005E
		MPABRx_t MPABRB;		//180060
		MPCDRx_t MPCDRB;		//180062
		MPEFRx_t MPEFRB;		//180064
		MPGHRx_t MPGHRB;		//180066
		MPIJRx_t MPIJRB;		//180068
		MPKLRx_t MPKLRB;		//18006A
		MPMNRx_t MPMNRB;		//18006C
		MPOPRx_t MPOPRB;		//18006E
		SCXINx_t SCXIN0;		//180070
		SCXDNx_t SCXDN0;		//180072
		SCYINx_t SCYIN0;		//180074
		SCYDNx_t SCYDN0;		//180076
		ZMXINx_t ZMXIN0;		//180078
		ZMXDNx_t ZMXDN0;		//18007A
		ZMYINx_t ZMYIN0;		//18007C
		ZMYDNx_t ZMYDN0;		//18007E
		SCXINx_t SCXIN1;		//180080
		SCXDNx_t SCXDN1;		//180082
		SCYINx_t SCYIN1;		//180084
		SCYDNx_t SCYDN1;		//180086
		ZMXINx_t ZMXIN1;		//180088
		ZMXDNx_t ZMXDN1;		//18008A
		ZMYINx_t ZMYIN1;		//18008C
		ZMYDNx_t ZMYDN1;		//18008E
		SCXNx_t  SCXN2;		//180090
		SCYNx_t  SCYN2;		//180092
		SCXNx_t  SCXN3;		//180094
		SCYNx_t  SCYN3;		//180096
		ZMCTL_t  ZMCTL;		//180098
		SCRCTL_t SCRCTL;		//18009A
		VCSTAU_t VCSTAU;		//18009C
		VCSTAL_t VCSTAL;		//18009E
		LSTAxU_t LSTA0U;		//1800A0
		LSTAxL_t LSTA0L;		//1800A2
		LSTAxU_t LSTA1U;		//1800A4
		LSTAxL_t LSTA1L;		//1800A6
		LCTAU_t  LCTAU;		//1800A8
		LCTAL_t  LCTAL;		//1800AA
		BKTAU_t  BKTAU;		//1800AC
		BKTAL_t  BKTAL;		//1800AE
		RPMD_t   RPMD;			//1800B0
		RPRCTL_t RPRCTL;		//1800B2
		KTCTL_t  KTCTL;		//1800B4
		KTAOF_t  KTAOF;		//1800B6
		OVPNRx_t OVPNRA;		//1800B8
		OVPNRx_t OVPNRB;		//1800BA
		RPTAU_t  RPTAU;		//1800BC
		RPTAL_t  RPTAL;		//1800BE
		WPSXx_t  WPSX0;		//1800C0
		WPSYx_t  WPSY0;		//1800C2
		WPEXx_t  WPEX0;		//1800C4
		WPEYx_t  WPEY0;		//1800C6
		WPSXx_t  WPSX1;		//1800C8
		WPSYx_t  WPSY1;		//1800CA
		WPEXx_t  WPEX1;		//1800CC
		WPEYx_t  WPEY1;		//1800CE
		WCTLA_t  WCTLA;		//1800D0
		WCTLB_t  WCTLB;		//1800D2
		WCTLC_t  WCTLC;		//1800D4
		WCTLD_t  WCTLD;		//1800D6
		LWTAxU_t LWTA0U;		//1800D8
		LWTAxL_t LWTA0L;		//1800DA
		LWTAxU_t LWTA1U;		//1800DC
		LWTAxL_t LWTA1L;		//1800DE
		SPCTL_t  SPCTL;		//1800E0
		SDCTL_t  SDCTL;		//1800E2
		CRAOFA_t CRAOFA;		//1800E4
		CRAOFB_t CRAOFB;		//1800E6
		LNCLEN_t LNCLEN;		//1800E8
		SFPRMD_t SFPRMD;		//1800EA
		CCCTL_t  CCCTL;		//1800EC
		SFCCMD_t SFCCMD;		//1800EE
		PRISA_t  PRISA;		//1800F0
		PRISB_t  PRISB;		//1800F2
		PRISC_t  PRISC;		//1800F4
		PRISD_t  PRISD;		//1800F6
		PRINA_t  PRINA;		//1800F8
		PRINB_t  PRINB;		//1800FA
		PRIR_t   PRIR;			//1800FC
		RSRV_t   RSRV1;		//1800FE
		CCRSA_t  CCRSA;		//180100
		CCRSB_t  CCRSB;		//180102
		CCRSC_t  CCRSC;		//180104
		CCRSD_t  CCRSD;		//180106
		CCRNA_t  CCRNA;		//180108
		CCRNB_t  CCRNB;		//18010A
		CCRR_t   CCRR;			//18010C
		CCRLB_t  CCRLB;		//18010E
		CLOFEN_t CLOFEN;		//180110
		CLOFSL_t CLOFSL;		//180112
		COxR_t   COAR;			//180114
		COxG_t   COAG;			//180116
		COxB_t   COAB;			//180118
		COxR_t   COBR;			//18011A
		COxG_t   COBG;			//18011C
		COxB_t   COBB;			//18011E
	} VDP2Regs_t;

	//VRAM access command value
	localparam VCP_N0PN 	= 4'h0;	//NBG0 pattern name data read
	localparam VCP_N1PN 	= 4'h1;	//NBG1 pattern name data read
	localparam VCP_N2PN 	= 4'h2;	//NBG2 pattern name data read
	localparam VCP_N3PN 	= 4'h3;	//NBG3 pattern name data read
	localparam VCP_N0CH 	= 4'h4;	//NBG0 character data read
	localparam VCP_N1CH 	= 4'h5;	//NBG1 character data read
	localparam VCP_N2CH 	= 4'h6;	//NBG2 character data read
	localparam VCP_N3CH 	= 4'h7;	//NBG3 character data read
	localparam VCP_N0VS 	= 4'hC;	//NBG0 vertical cell scroll data read
	localparam VCP_N1VS 	= 4'hD;	//NBG1 vertical cell scroll data read
	localparam VCP_CPU 	= 4'hE;	//CPU read/write
	localparam VCP_NA 	= 4'hF;	//No access
	
	//VRAM access timing
	localparam T0 	= 3'd0;
	localparam T1 	= 3'd1;
	localparam T2 	= 3'd2;
	localparam T3 	= 3'd3;
	localparam T4 	= 3'd4;
	localparam T5 	= 3'd5;
	localparam T6 	= 3'd6;
	localparam T7 	= 3'd7;
	
	typedef struct packed
	{
		bit         VF;
		bit         HF;
		bit         PR;
		bit         CC;
		bit [ 4: 0] UNUSED;
		bit [ 6: 0] PALN;
		bit         UNUSED2;
		bit [14: 0] CHRN;
	} PatternName_t;
	
	typedef struct packed
	{
		bit [ 8: 0] H_CNT; 
		bit [ 8: 0] V_CNT;
		bit [ 3: 0] VCPA0; 
		bit [ 3: 0] VCPA1; 
		bit [ 3: 0] VCPB0; 
		bit [ 3: 0] VCPB1;
	} VRAMAccessState_t;
	
	typedef VRAMAccessState_t VRAMAccessPipeline_t [3];
	

endpackage
