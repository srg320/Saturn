package SCSP_PKG;

	//Slot control registers, offset 100000+n*20
	typedef struct packed		//RW,00
	{
		bit [ 2: 0] UNUSED;
		bit         KX;
		bit         KB;
		bit [ 1: 0] SBCTL;
		bit [ 1: 0] SSCTL;
		bit [ 1: 0] LPCTL;
		bit         PCM8B;
		bit [ 3: 0] SAH;
	} SCR0_t;
	parameter bit [15:0] SCR0_MASK = 16'h1FFF;
	
	typedef bit [15:0] SA_t;	//RW,02
	parameter bit [15:0] SA_MASK = 16'hFFFF;
	
	typedef bit [15:0] LSA_t;	//RW,04
	parameter bit [15:0] LSA_MASK = 16'hFFFF;
	
	typedef bit [15:0] LEA_t;	//RW,06
	parameter bit [15:0] LEA_MASK = 16'hFFFF;
	
	typedef struct packed		//RW,08
	{
		bit         UNUSED;
		bit         LS;
		bit [ 3: 0] KRS;
		bit [ 4: 0] DL;
		bit [ 4: 0] RR;
	} SCR1_t;
	parameter bit [15:0] SCR1_MASK = 16'hFFFF;
	
	typedef struct packed		//RW,0A
	{
		bit [ 4: 0] D2R;
		bit [ 4: 0] D1R;
		bit         HO;
		bit [ 4: 0] AR;
	} SCR2_t;
	parameter bit [15:0] SCR2_MASK = 16'h7FFF;
	
	typedef struct packed		//RW,0C
	{
		bit [ 5: 0] UNUSED;
		bit         SI;
		bit         SD;
		bit [ 7: 0] TL;
	} SCR3_t;
	parameter bit [15:0] SCR3_MASK = 16'h03FF;
	
	typedef struct packed		//RW,0E
	{
		bit [ 3: 0] MDL;
		bit [ 5: 0] MDXSL;
		bit [ 5: 0] MDYSL;
	} SCR4_t;
	parameter bit [15:0] SCR4_MASK = 16'hFFFF;
	
	typedef struct packed		//RW,10
	{
		bit         UNUSED;
		bit [ 3: 0] OCT;
		bit         UNUSED2;
		bit [ 9: 0] FNS;
	} SCR5_t;
	parameter bit [15:0] SCR5_MASK = 16'h7BFF;
	
	typedef struct packed		//RW,12
	{
		bit         RE;
		bit [ 4: 0] LFOF;
		bit [ 1: 0] PLFOWS;
		bit [ 2: 0] PLFOS;
		bit [ 1: 0] ALFOWS;
		bit [ 2: 0] ALFOS;
	} SCR6_t;
	parameter bit [15:0] SCR6_MASK = 16'hFFFF;
	
	typedef struct packed		//RW,14
	{
		bit [ 8: 0] UNUSED;
		bit [ 3: 0] ISEL;
		bit [ 2: 0] IMXL;
	} SCR7_t;
	parameter bit [15:0] SCR7_MASK = 16'h007F;
	
	typedef struct packed		//RW,16
	{
		bit [ 2: 0] DISDL;
		bit [ 4: 0] DIPAN;
		bit [ 2: 0] EFSDL;
		bit [ 4: 0] EFPAN;
	} SCR8_t;
	parameter bit [15:0] SCR8_MASK = 16'hFFFF;
	
	//Control registers
	typedef struct packed		//RW,100400
	{
		bit [ 5: 0] UNUSED;
		bit         M4;
		bit         DB;
		bit [ 3: 0] UNUSED2;
		bit [ 3: 0] MVOL;
	} CR0_t;
	parameter bit [15:0] CR0_MASK = 16'h030F;
	
	typedef struct packed		//RW,100402
	{
		bit [ 6: 0] UNUSED;
		bit [ 1: 0] RBL;
		bit [ 6: 0] RBP;
	} CR1_t;
	parameter bit [15:0] CR1_MASK = 16'h01FF;
	
	typedef struct packed		//RW,100404
	{
		bit [ 2: 0] UNUSED;
		bit         OF;
		bit         OE;
		bit         IO;
		bit         IF;
		bit         IE;
		bit [ 7: 0] MIBUF;
	} CR2_t;
	parameter bit [15:0] CR2_MASK = 16'h1FFF;
	
	typedef struct packed		//RW,100406
	{
		bit [ 7: 0] UNUSED;
		bit [ 7: 0] MOBUF;
	} CR3_t;
	parameter bit [15:0] CR3_MASK = 16'h00FF;
	
	typedef struct packed		//RW,100408
	{
		bit [ 4: 0] MSLC;
		bit [ 3: 0] CA;
		bit [ 6: 0] UNUSED;
	} CR4_t;
	parameter bit [15:0] CR4_MASK = 16'h00FF;
	
	typedef struct packed		//RW,100412
	{
		bit [14: 0] DMEAL;
		bit         UNUSED;
	} CR5_t;
	parameter bit [15:0] CR5_MASK = 16'hFFFE;
	
	typedef struct packed		//RW,100414
	{
		bit [ 3: 0] DMEAH;
		bit [10: 0] DRGA;
		bit         UNUSED;
	} CR6_t;
	parameter bit [15:0] CR6_MASK = 16'hFFFE;
	
	typedef struct packed		//RW,100416
	{
		bit         UNUSED;
		bit         GA;
		bit         DI;
		bit         EX;
		bit [10: 0] DRGA;
		bit         UNUSED2;
	} CR7_t;
	parameter bit [15:0] CR7_MASK = 16'h7FFE;
	
	typedef struct packed		//RW,100418
	{
		bit [ 4: 0] UNUSED;
		bit [ 2: 0] TACTL;
		bit [ 7: 0] TIMA;
	} CR8_t;
	parameter bit [15:0] CR8_MASK = 16'h07FF;
	
	typedef struct packed		//RW,10041A
	{
		bit [ 4: 0] UNUSED;
		bit [ 2: 0] TBCTL;
		bit [ 7: 0] TIMB;
	} CR9_t;
	parameter bit [15:0] CR9_MASK = 16'h07FF;
	
	typedef struct packed		//RW,10041C
	{
		bit [ 4: 0] UNUSED;
		bit [ 2: 0] TCCTL;
		bit [ 7: 0] TIMC;
	} CR10_t;
	parameter bit [15:0] CR10_MASK = 16'h07FF;
	
	typedef struct packed		//RW,10041E
	{
		bit [ 4: 0] UNUSED;
		bit [10: 0] SCIEB;
	} CR11_t;
	parameter bit [15:0] CR11_MASK = 16'h07FF;
	
	typedef struct packed		//RW,100420
	{
		bit [ 4: 0] UNUSED;
		bit [10: 0] SCIPD;
	} CR12_t;
	parameter bit [15:0] CR12_MASK = 16'h07FF;
	
	typedef struct packed		//RW,100422
	{
		bit [ 4: 0] UNUSED;
		bit [10: 0] SCIRE;
	} CR13_t;
	parameter bit [15:0] CR13_MASK = 16'h07FF;
	
	typedef struct packed		//RW,100424
	{
		bit [ 7: 0] UNUSED;
		bit [ 7: 0] SCILV0;
	} CR14_t;
	parameter bit [15:0] CR14_MASK = 16'h00FF;
	
	typedef struct packed		//RW,100426
	{
		bit [ 7: 0] UNUSED;
		bit [ 7: 0] SCILV1;
	} CR15_t;
	parameter bit [15:0] CR15_MASK = 16'h00FF;
	
	typedef struct packed		//RW,100428
	{
		bit [ 7: 0] UNUSED;
		bit [ 7: 0] SCILV2;
	} CR16_t;
	parameter bit [15:0] CR16_MASK = 16'h00FF;
	
	typedef struct packed		//RW,10042A
	{
		bit [ 4: 0] UNUSED;
		bit [10: 0] MCIEB;
	} CR17_t;
	parameter bit [15:0] CR17_MASK = 16'h07FF;
	
	typedef struct packed		//RW,10042C
	{
		bit [ 4: 0] UNUSED;
		bit [10: 0] MCIPD;
	} CR18_t;
	parameter bit [15:0] CR18_MASK = 16'h07FF;
	
	typedef struct packed		//RW,10042E
	{
		bit [ 4: 0] UNUSED;
		bit [10: 0] MCIRE;
	} CR19_t;
	parameter bit [15:0] CR19_MASK = 16'h07FF;
	
	typedef bit [15:0] SOUS_t;		//RW,100600-10067F
	parameter bit [15:0] SOUS_MASK = 16'hFFFF;
	
	
	typedef struct packed
	{
		SCR0_t      SCR0;
		SA_t        SA;
		LSA_t       LSA;
		LEA_t       LEA;
		SCR1_t      SCR1;
		SCR2_t      SCR2;
		SCR3_t      SCR3;
		SCR4_t      SCR4;
		SCR5_t      SCR5;
		SCR6_t      SCR6;
		SCR7_t      SCR7;
		SCR8_t      SCR8;
	} SCR_t;
	
	typedef SOUS_t STACK_t[64];
	
	typedef enum bit [4:0] {
		EGS_IDLE    = 5'b00001,  
		EGS_ATTACK  = 5'b00010, 
		EGS_DECAY1  = 5'b00100,
		EGS_DECAY2  = 5'b01000,
		EGS_RELEASE = 5'b10000
	} EGState_t;
	
	typedef struct packed
	{
		bit [14: 0] PHASE;
	} OP1State_t;
	
	typedef struct packed
	{
		bit [15: 0] MD;	//Modulation data
		bit [18: 1] ADP;	//Address pointer
	} OP2State_t;
	
	typedef struct packed
	{
		bit [ 9: 0] EVOL;	//Envelope volume
		EGState_t   ST;	//Envelope generator state
	} OP4State_t;
	
	typedef struct packed
	{
		bit [ 4: 0] SLOT;	//
		bit         KON;	//
		bit         KOFF;	//
	} OPPipe_t;
	parameter OPPipe_t OP_PIPE_RESET = '{'0,0,0};
	
	function bit [15:0] SoundSel(input bit [15:0] WAVE, input bit [15:0] NOISE, SCR0_t SCR0);
		bit [15:0] SD;
		bit [15:0] temp;
		
		case (SCR0.SSCTL)
			2'b00: temp = WAVE;
			2'b01: temp = NOISE;
			default: temp = 16'H0000;
		endcase
		SD = {temp[15] ^ SCR0.SBCTL[1], temp[14:0] ^ {15{SCR0.SBCTL[0]}}}; 
	
		return SD;
	endfunction

	function bit [15:0] MDCalc(input STACK_t STACK, SCR4_t SCR4);
		bit [15:0] MD;
		bit [15:0] X,Y;
		bit [16:0] TEMP;
		
		X = STACK[SCR4.MDXSL];
		Y = STACK[SCR4.MDYSL];
		TEMP = $signed(X )+ $signed(Y); 
		MD = TEMP[16:1];
		
		return MD;
	endfunction
	
	function bit [14:0] PhaseCalc(SCR5_t SCR5);
		bit [14:0] P;
		P = {SCR5.OCT,SCR5.FNS};
		
		return P;
	endfunction
	
endpackage
