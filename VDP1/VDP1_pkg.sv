package VDP1_PKG;

	//Registers
	typedef struct packed	//WO,100000
	{
		bit [11: 0] UNUSED;
		bit         VBE;
		bit [ 2: 0] TVM;
	} TVMR_t;
	parameter bit [15:0] TVMR_MASK = 16'h000F;

	typedef struct packed	//WO,100002
	{
		bit [10: 0] UNUSED;
		bit         EOS;
		bit         DIE;
		bit         DIL;
		bit         FCM;
		bit         FCT;
	} FBCR_t;
	parameter bit [15:0] FBCR_MASK = 16'h001F;

	typedef struct packed	//WO,100004
	{
		bit [13: 0] UNUSED;
		bit [ 1: 0] PTM;
	} PTMR_t;
	parameter bit [15:0] PTMR_MASK = 16'h0003;
	
	typedef bit [15:0] EWDR_t;	//WO,100006
	parameter bit [15:0] EWDR_MASK = 16'hFFFF;
	
	typedef struct packed	//WO,100008
	{
		bit         UNUSED;
		bit [ 8: 3] X1;
		bit [ 8: 0] Y1;
	} EWLR_t;
	parameter bit [15:0] EWLR_MASK = 16'h7FFF;

	typedef struct packed	//WO,10000A
	{
		bit [ 9: 3] X3;
		bit [ 8: 0] Y3;
	} EWRR_t;
	parameter bit [15:0] EWRR_MASK = 16'hFFFF;
	
	typedef bit [15:0] ENDR_t;	//WO,10000C
	parameter bit [15:0] ENDR_MASK = 16'h0000;
	
	typedef struct packed	//RO,100010
	{
		bit [13: 0] UNUSED;
		bit         CEF;
		bit         BEF;
	} EDSR_t;
	parameter bit [15:0] EDSR_MASK = 16'h0003;
	
	typedef bit [15:0] LOPR_t;	//RO,100012
	parameter bit [15:0] LOPR_MASK = 16'hFFFC;
	
	typedef bit [15:0] COPR_t;	//RO,100014
	parameter bit [15:0] COPR_MASK = 16'hFFFC;
	
	typedef struct packed	//RO,100016
	{
		bit [ 3: 0] VER;
		bit [ 2: 0] UNUSED;
		bit         PTM1;
		bit         EOS;
		bit         DIE;
		bit         DIL;
		bit         FCM;
		bit         VBE;
		bit [ 2: 0] TVM;
	} MODR_t;
	parameter bit [15:0] MODR_MASK = 16'hF1FF;
	
	//Command tables
	typedef struct packed	//00
	{
		bit         END;
		bit [ 2: 0] JP;
		bit [ 3: 0] ZP;
		bit [ 1: 0] UNUSED;
		bit [ 1: 0] DIR;
		bit [ 3: 0] COMM;
	} CMDCTRL_t;
	parameter bit [15:0] CMDCTRL_MASK = 16'hFF3F;
	
	typedef bit [15:0] CMDLINK_t;	//02
	parameter bit [15:0] CMDLINK_MASK = 16'hFFFC;
	
	typedef struct packed	//04
	{
		bit         MON;
		bit [ 1: 0] UNUSED;
		bit         HSS;
		bit         PCLP;
		bit         CLIP;
		bit         CMOD;
		bit         MESH;
		bit         ECD;
		bit         SPD;
		bit [ 2: 0] CM;
		bit [ 2: 0] CCB;
	} CMDPMOD_t;
	parameter bit [15:0] CMDPMOD_MASK = 16'h9FFF;
	
	typedef bit [15:0] CMDCOLR_t;	//06
	parameter bit [15:0] CMDCOLR_MASK = 16'hFFFF;
	
	typedef bit [15:0] CMDSRCA_t;	//08
	parameter bit [15:0] CMDSRCA_MASK = 16'hFFFC;
	
	typedef struct packed	//0A
	{
		bit [ 1: 0] UNUSED;
		bit [ 8: 3] SX;
		bit [ 7: 0] SY;
	} CMDSIZE_t;
	parameter bit [15:0] CMDSIZE_MASK = 16'h3FFF;
	
	typedef struct packed	//0C-1A
	{
		bit [ 4: 0] EXT;
		bit [10: 0] COORD;
	} CMDCRD_t;
	parameter bit [15:0] CMDCRD_MASK = 16'hFFFF;
	
	typedef bit [15:0] CMDGRDA_t;	//1C
	parameter bit [15:0] CMDGRDA_MASK = 16'hFFFF;
	
	typedef struct packed
	{
		CMDCTRL_t   CMDCTRL;	//00
		CMDLINK_t   CMDLINK;	//02
		CMDPMOD_t   CMDPMOD;	//04
		CMDCOLR_t   CMDCOLR;	//06
		CMDSRCA_t   CMDSRCA;	//08
		CMDSIZE_t   CMDSIZE;	//0A
		CMDCRD_t    CMDXA;	//0C
		CMDCRD_t    CMDYA;	//0E
		CMDCRD_t    CMDXB;	//10
		CMDCRD_t    CMDYB;	//12
		CMDCRD_t    CMDXC;	//14
		CMDCRD_t    CMDYC;	//16
		CMDCRD_t    CMDXD;	//18
		CMDCRD_t    CMDYD;	//1A
		CMDGRDA_t   CMDGRDA;	//1C
		bit [15: 0] UNUSED;	//1E
	} CMDTBL_t;
	
	//Command value
	parameter CMD_NSPR 	= 4'h0; 	//Normal sprite draw
	parameter CMD_SSPR 	= 4'h1; 	//Scaled sprite draw
	parameter CMD_DSPR 	= 4'h2;	//Distorted sprite draw
	parameter CMD_POLY 	= 4'h4;	//Polygon draw
	parameter CMD_PLIN 	= 4'h5;	//Polyline draw
	parameter CMD_LINE 	= 4'h6;	//Line draw
	parameter CMD_UCLIP 	= 4'h8;	//Set user clipping coordinate
	parameter CMD_SCLIP 	= 4'h9;	//Set system clipping coordinate
	parameter CMD_LCORD 	= 4'hA;	//Set local coordinate
	
	
	typedef struct packed
	{
		bit [ 9: 0] X1;
		bit [ 8: 0] Y1;
		bit [ 9: 0] X2;
		bit [ 8: 0] Y2;
	} Clip_t;
	parameter Clip_t CLIP_NULL = {10'h000,9'h000,10'h000,9'h000};
	
	typedef struct packed
	{
		bit [ 9: 0] X;
		bit [ 8: 0] Y;
	} Coord_t;
	parameter Coord_t COORD_NULL = {10'h000,9'h000};
	
	typedef struct packed
	{
		bit [10: 0] X;
		bit [10: 0] Y;
	} Vertex_t;
	parameter Vertex_t VERT_NULL = {11'h000,11'h000};
	
	typedef struct packed
	{
		bit [10: 0] X;
		bit [10: 0] Y;
	} Size_t;
	parameter Size_t SIZE_NULL = {11'h000,11'h000};
	
	function bit [18:1] SprAddr(input bit [9:0] X, input bit [9:0] Y, input CMDSIZE_t CMDSIZE, input bit [1:0] DIR, input CMDSRCA_t CMDSRCA, input bit [2:0] CM);
		bit [18:1] ADDR;
		bit  [9:0] offs_x;
		bit  [9:0] offs_y;
		bit [15:0] offs;
		
		offs_x = !DIR[0] ? X : {1'b0,CMDSIZE.SX,3'b000} - X - 10'd1;
		offs_y = !DIR[1] ? Y : {2'b00,CMDSIZE.SY} - Y - 10'd1;
		offs = (offs_y * CMDSIZE.SX);
		case (CM)
			3'b000,
			3'b001:  ADDR = {CMDSRCA,2'b00} + {1'b0,offs,1'b0}   + offs_x[9:2];
			3'b010,
			3'b011,
			3'b100:  ADDR = {CMDSRCA,2'b00} + {offs,2'b00}  + offs_x[9:1];
			default: ADDR = {CMDSRCA,2'b00} + {offs[14:0],3'b000} + offs_x[9:0];
		endcase
		return ADDR;
	endfunction
	
	function bit [15:0] GetPattern(input bit [15:0] DATA, input bit [2:0] CM, input bit [1:0] OFFSX);
		bit [15:0] P;
		
		case (CM)
			3'b000,
			3'b001: begin
				case (OFFSX)
					2'b00: P = {12'h000,DATA[15:12]};
					2'b01: P = {12'h000,DATA[11:8]};
					2'b10: P = {12'h000,DATA[7:4]};
					2'b11: P = {12'h000,DATA[3:0]};
				endcase
			end
			3'b010,
			3'b011,
			3'b100: begin
				case (OFFSX[0])
					1'b0: P = {8'h00,DATA[15:8]};
					1'b1: P = {8'h00,DATA[7:0]};
				endcase
			end
			default: P = DATA;
		endcase

		return P;
	endfunction
	
	function bit [14:0] ColorHalf(input bit [14:0] A);
		bit [4:0] AR,AG,AB;
		bit [4:0] HR,HG,HB;
		
		{AB,AG,AR} = A;
		
		HR = {1'b0,AR[4:1]};
		HG = {1'b0,AG[4:1]};
		HB = {1'b0,AB[4:1]};
		return {HB,HG,HR};
	endfunction
	
	function bit [14:0] ColorAdd(input bit [14:0] A, input bit [14:0] B);
		bit [4:0] AR,AG,AB;
		bit [4:0] BR,BG,BB;
		bit [4:0] SR,SG,SB;
		
		{AB,AG,AR} = A;
		{BB,BG,BR} = B;
		
		SR = AR + BR;
		SG = AG + BG;
		SB = AB + BB;
		return {SB,SG,SR};
	endfunction
	
	function bit [15:0] ColorCalc(input bit [15:0] ORIG, input bit [15:0] BACK, input bit [2:0] CCB);
		bit [15:0] CC;
		bit [14:0] ORIG_HALF,ORIG_ONE;
		bit [14:0] BACK_HALF,BACK_ONE;
		bit [14:0] A,B;
		bit        MSB;
		
		ORIG_HALF = ColorHalf(ORIG[14:0]);
		ORIG_ONE = ORIG[14:0];
		BACK_HALF = ColorHalf(BACK[14:0]);
		BACK_ONE = BACK[14:0];
		
		case (CCB)
			3'b000: begin A = ORIG_ONE;                        B = '0;                              MSB = ORIG[15]; end
			3'b001: begin A = '0;                              B = BACK[15] ? BACK_HALF : BACK_ONE; MSB = BACK[15]; end
			3'b010: begin A = ORIG_HALF;                       B = '0;                              MSB = ORIG[15]; end
			3'b011: begin A = BACK[15] ? ORIG_HALF : ORIG_ONE; B = BACK[15] ? BACK_HALF : '0;       MSB = BACK[15]; end
			3'b100: begin A = ORIG_ONE;                        B = '0;                              MSB = ORIG[15]; end//TODO Gouraud
			3'b101: begin A = '0;                              B = BACK_ONE;                        MSB = BACK[15]; end
			3'b110: begin A = ORIG_HALF;                       B = '0;                              MSB = ORIG[15]; end//TODO Gouraud
			3'b111: begin A = BACK[15] ? ORIG_HALF : ORIG_ONE; B = BACK[15] ? BACK_HALF : '0;       MSB = BACK[15]; end//TODO Gouraud
		endcase
		
		CC = {MSB,ColorAdd(A,B)};		
		return CC;
	endfunction

	
	function bit [10:0] Abs(input bit [10:0] C);
		return $signed(C) >= 0 ? $signed(C) : -$signed(C);
	endfunction
	
endpackage
