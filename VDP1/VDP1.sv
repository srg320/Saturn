module VDP1 (
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	input             EN,
	
	input             RES_N,

	input      [15:0] DI,
	output     [15:0] DO,
	input             CS_N,
	input             AD_N,
	input             DTEN_N,
	input             REQ_N,
	output            RDY_N,
	
	output            IRQ_N,
	
	input             DCLK,
	input             HTIM_N,
	input             VTIM_N,
	output     [15:0] VOUT,
	
	output reg [18:1] VRAM_A,
	output reg [15:0] VRAM_D,
	input      [31:0] VRAM_Q,
	output reg  [1:0] VRAM_WE,
	output reg        VRAM_RD,
	input             VRAM_RDY,
	
	output     [17:1] FB0_A,
	output     [15:0] FB0_D,
	input      [15:0] FB0_Q,
	output            FB0_WE,
	output            FB0_RD,
	
	output     [17:1] FB1_A,
	output     [15:0] FB1_D,
	input      [15:0] FB1_Q,
	output            FB1_WE,
	output            FB1_RD,
	
	output            DBG_START,
	output            DBG_CMD_END,
	output     [15:0] ORIG_C_DBG,
	output     [10:0] DRAW_X_DBG,
	output     [10:0] DRAW_Y_DBG,
	output            DBG_LINE_OVER,
	output            DBG_DRAW_OVER,
	output      [7:0] FRAMES_DBG,
	output      [7:0] START_DRAW_CNT,
	output     [18:1] DBG_CMD_ADDR16,
	output     [18:1] DBG_CMD_ADDR_LAST,
	output CMDSRCA_t DBG_CMD_CMDSRCA_LAST,
	output     [7:0] DBG_CMD_CNT,
	output     [7:0] DBG_CMD_WAIT_CNT,
	output     [7:0] CPU_VRAM_RDY_CNT
);
	import VDP1_PKG::*;
	
	TVMR_t     TVMR;
	FBCR_t     FBCR;
	PTMR_t     PTMR;
	EWDR_t     EWDR;
	EWLR_t     EWLR;
	EWRR_t     EWRR;
	EDSR_t     EDSR;
	LOPR_t     LOPR;
	COPR_t     COPR;
	MODR_t     MODR;

	bit        FRAME_START;
	bit        FRAME_ERASE;
	bit        VBLANK_ERASE;
	bit        FRAME_ERASE_HIT;
	bit        VBLANK_ERASE_HIT;
	bit        DRAW_TERMINATE;
	
	//Color lookup table
	bit  [3:0] CLT_WA;
	bit [15:0] CLT_D;
	bit        CLT_WE;
	bit  [3:0] CLT_RA;
	bit [15:0] CLT_Q;
	
	//Frame buffers
	bit        FB_SEL;
	bit [17:1] FB_DRAW_A;
	bit [15:0] FB_DRAW_D;
	bit        FB_DRAW_WE;
	bit [15:0] FB_DRAW_Q;
	bit [17:1] FB_DISP_A;
	bit        FB_DISP_WE;
	bit [15:0] FB_DISP_Q;
	bit [17:1] FB_ERASE_A;
//	bit        FRAME;
	wire       FB_ERASE_WE = (FRAME_ERASE_HIT & DCLK) | (VBLANK_ERASE_HIT & CE_R);
	
	assign FB0_A  = FB_SEL ? FB_DRAW_A                                   : (VBLANK_ERASE_HIT ? FB_ERASE_A : FB_DISP_A);
	assign FB1_A  = FB_SEL ? (VBLANK_ERASE_HIT ? FB_ERASE_A : FB_DISP_A) : FB_DRAW_A;
	assign FB0_D  = FB_SEL ? FB_DRAW_D                                   : EWDR;
	assign FB1_D  = FB_SEL ? EWDR                                        : FB_DRAW_D;
	assign FB0_WE = FB_SEL ? FB_DRAW_WE /*& CE_R*/                           : FB_ERASE_WE;
	assign FB1_WE = FB_SEL ? FB_ERASE_WE                                 : FB_DRAW_WE /*& CE_R*/;
	assign FB0_RD = 0;
	assign FB1_RD = 0;
	
	assign FB_DRAW_Q = FB_SEL ? FB0_Q : FB1_Q;
	assign FB_DISP_Q = FB_SEL ? FB1_Q : FB0_Q;
	
	bit [20:1] A;
	bit        WE_N;
	bit  [1:0] DQM;
	bit        BURST;
	
	typedef enum bit [10:0] {
		VS_IDLE          = 11'b00000000001,  
		VS_CPU_WRITE     = 11'b00000000010,
		VS_CPU_WRITE_END = 11'b00000000100,
		VS_CPU_READ      = 11'b00000001000,
		VS_CPU_READ_END  = 11'b00000010000,
		VS_CMD_READ      = 11'b00000100000,
		VS_CMD_END       = 11'b00001000000,
		VS_PAT_READ      = 11'b00010000000,
		VS_PAT_END       = 11'b00100000000,
		VS_CLT_READ      = 11'b01000000000,
		VS_CLT_END       = 11'b10000000000
	} VRAMState_t;
	VRAMState_t VRAM_ST;
	bit [18:1] IO_VRAM_RA;
	bit [18:1] IO_VRAM_WA;
	bit [15:0] IO_VRAM_D;
	bit  [1:0] IO_VRAM_WE;
	bit [15:0] IO_VRAM_DO;
	bit        CPU_VRAM_READ_PEND;
	bit        CPU_VRAM_WRITE_PEND;
	bit        CPU_VRAM_RRDY;
	bit        CPU_VRAM_WRDY;
	bit        VRAM_DONE;
	
	typedef enum bit [4:0] {
		CMDS_IDLE,  
		CMDS_READ, 
		CMDS_EXEC,
		CMDS_CLT_LOAD,
		CMDS_NSPR_START,
		CMDS_SSPR_START,
		CMDS_DSPR_START,
		CMDS_SPR_CALCX,
		CMDS_SPR_CALCY,
		CMDS_SPR_READ,
		CMDS_SPR_DRAW,
		CMDS_POLYGON_START,
		CMDS_POLYGON_CALCD,
		CMDS_POLYGON_CALCTDY,
		CMDS_POLYLINE_START,
		CMDS_LINE_START,
		CMDS_LINE_CALC,
		CMDS_LINE_CALCD,
		CMDS_LINE_DRAW,
		CMDS_AA_DRAW,
		CMDS_LINE_PAT,
		CMDS_LINE_NEXT,
		CMDS_END
	} CMDState_t;
	CMDState_t CMD_ST;
	bit [18:1] CMD_ADDR;
	bit        CMD_READ;
	bit [18:1] SPR_ADDR;
	bit        SPR_READ;
	bit [15:0] SPR_DATA;
	bit [18:1] CLT_ADDR;
	bit        CLT_READ;
	
	//Divider
	bit [10:0] DIV_A;
	bit [10:0] DIV_B;
	bit [21:0] DIV_R;
	VDP1_DIV DIV(.numer({DIV_A,11'h000}), .denom(DIV_B), .quotient(DIV_R));
	
	CMDTBL_t   CMD;
	Clip_t     SYS_CLIP;
	Clip_t     USR_CLIP;
	Coord_t    LOC_COORD;
	bit [19:0] TEXT_X;
	bit [19:0] TEXT_Y;
	bit [19:0] TEXT_DX;
	bit [19:0] TEXT_DY;
	bit [15:0] TEXT_PAT;
	bit [10:0] POLY_LSX;
	bit [10:0] POLY_LSY;
	bit [10:0] POLY_RSX;
	bit [10:0] POLY_RSY;
	bit [10:0] POLY_LDX;
	bit [10:0] POLY_LDY;
	bit [10:0] POLY_RDX;
	bit [10:0] POLY_RDY;
	bit  [1:0] POLY_S;
	bit        POLY_LDIRX;
	bit        POLY_LDIRY;
	bit        POLY_RDIRX;
	bit        POLY_RDIRY;
	
	Vertex_t   LINE_VERTA;
	Vertex_t   LINE_VERTB;
	Vertex_t   LEFT_VERT;
	Vertex_t   RIGHT_VERT;
	bit [10:0] LINE_SX;
	bit [10:0] LINE_SY;
	bit        LINE_DIRX;
	bit        LINE_DIRY;
	bit        LINE_S;
	bit [10:0] LINE_D;
	bit [10:0] NEXT_LINE_D;
	bit [10:0] AA_X;
	bit [10:0] AA_Y;
	bit [10:0] DRAW_X;////
	bit [10:0] DRAW_Y;////
	bit        SCLIP;////
	bit        UCLIP;////
	Pattern_t  PAT;////
	always @(posedge CLK or negedge RST_N) begin
//	   bit        FRAME_START_PEND;
		bit [18:1] NEXT_ADDR;
		bit [18:1] CMD_JRET;
		CMDCOLR_t  CMDCOLR_LAST;
		bit [10:0] CMDXA_CLIP;
		bit [10:0] CMDXB_CLIP;
		bit [10:0] CMDXC_CLIP;
		bit [10:0] CMDXD_CLIP;
		bit [10:0] RIGHT_VERT_X_CLIP;
		bit [10:0] RIGHT_VERT_Y_CLIP;
		bit [11:0] NEW_LINE_SX;
		bit [11:0] NEW_LINE_SY;
		bit [11:0] NEW_POLY_LSX;
		bit [11:0] NEW_POLY_LSY;
		bit [11:0] NEW_POLY_RSX;
		bit [11:0] NEW_POLY_RSY;
		bit [10:0] NEXT_POLY_LDX;
		bit [10:0] NEXT_POLY_LDY;
		bit [10:0] NEXT_POLY_RDX;
		bit [10:0] NEXT_POLY_RDY;
		bit        DIV_WAIT;
		bit [19:0] NEXT_TEXT_X;
		bit [19:0] NEXT_TEXT_Y;
		bit        AA;
		bit        EC_FIND;
		bit  [8:0] XMASK;
		bit        CMD_COORD_OVER;
		
		if (!RST_N) begin
			CMD_ST <= CMDS_IDLE;
			CMD_ADDR <= '0;
			CMD_READ <= 0;
			SPR_READ <= 0;
			SYS_CLIP <= {10'h000,9'h000,10'h13F,9'h0FF};//CLIP_NULL;
			USR_CLIP <= CLIP_NULL;
			LOC_COORD <= COORD_NULL;
			
			LOPR <= '0;
			COPR <= '0;
			
		end else if (FRAME_START) begin
			CMD_ADDR <= '0;
			CMD_READ <= 1;
			SPR_READ <= 0;
			CLT_READ <= 0;
			CMD_ST <= CMDS_READ;
		end else if (DRAW_TERMINATE) begin
			CMD_READ <= 0;
			SPR_READ <= 0;
			CLT_READ <= 0;
			CMD_ST <= CMDS_IDLE;
		end else if (EN /*&& CE_R*/) begin
			case (CMD.CMDPMOD.CM)
				3'b000,
				3'b001: XMASK = 9'b111111100;
				3'b010,
				3'b011,
				3'b100: XMASK = 9'b111111110;
				default:XMASK = 9'b111111111;
			endcase
			
//			if (FRAME_START && CMD_ST != CMDS_IDLE) FRAME_START_PEND <= 1;

			CMD_COORD_OVER = (CMD.CMDXA.COORD + LOC_COORD.X > SYS_CLIP.X2 && CMD.CMDXB.COORD + LOC_COORD.X > SYS_CLIP.X2 && CMD.CMDXC.COORD + LOC_COORD.X > SYS_CLIP.X2 && CMD.CMDXD.COORD + LOC_COORD.X > SYS_CLIP.X2) ||
								  (CMD.CMDYA.COORD + LOC_COORD.Y > SYS_CLIP.Y2 && CMD.CMDYB.COORD + LOC_COORD.Y > SYS_CLIP.Y2 && CMD.CMDYC.COORD + LOC_COORD.Y > SYS_CLIP.Y2 && CMD.CMDYD.COORD + LOC_COORD.Y > SYS_CLIP.Y2);
					
			case (CMD_ST) 
				CMDS_IDLE: begin
//					if (FRAME_START || FRAME_START_PEND) begin
//						FRAME_START_PEND <= 0;
//						CMD_ADDR <= '0;
//						CMD_READ <= 1;
//						SPR_READ <= 0;
//						CLT_READ <= 0;
//						CMD_ST <= CMDS_READ;
//					end
				end
					
				CMDS_READ: begin
					DBG_CMD_WAIT_CNT <= DBG_CMD_WAIT_CNT + 1'd1;
					CMD_READ <= 0;
					if (VRAM_DONE) begin 
						LOPR <= COPR;
						COPR <= CMD_ADDR[18:3];
						CMD_ST <= CMDS_EXEC;
						DBG_CMD_WAIT_CNT <= '0;
					end
				end
					
				CMDS_EXEC: begin
					CMD_ST <= CMDS_END;
					if (!CMD.CMDCTRL.JP[2] && !CMD.CMDCTRL.END) begin
						case (CMD.CMDCTRL.COMM)
							4'h0: begin	//normal sprite
								if (CMD.CMDSIZE.SX && CMD.CMDSIZE.SY) begin
									if (CMD.CMDPMOD.CM == 3'b001 && CMDCOLR_LAST != CMD.CMDCOLR) begin
										CMDCOLR_LAST <= CMD.CMDCOLR;
										CLT_READ <= 1;
										CMD_ST <= CMDS_CLT_LOAD;
									end else begin
										SPR_READ <= 1;
										CMD_ST <= CMDS_NSPR_START;
									end
								end
							end
							
							4'h1: begin	//scaled sprite
								if (CMD.CMDSIZE.SX && CMD.CMDSIZE.SY) begin
									if (CMD.CMDPMOD.CM == 3'b001 && CMDCOLR_LAST != CMD.CMDCOLR) begin
										CMDCOLR_LAST <= CMD.CMDCOLR;
										CLT_READ <= 1;
										CMD_ST <= CMDS_CLT_LOAD;
									end else begin
										CMD_ST <= CMDS_SSPR_START;
									end
								end
							end
							
							4'h2,
							4'h3: begin	//distored sprite
								if (!CMD_COORD_OVER && CMD.CMDSIZE.SX && CMD.CMDSIZE.SY) begin
									if (CMD.CMDPMOD.CM == 3'b001 && CMDCOLR_LAST != CMD.CMDCOLR) begin
										CMDCOLR_LAST <= CMD.CMDCOLR;
										CLT_READ <= 1;
										CMD_ST <= CMDS_CLT_LOAD;
									end else begin
										CMD_ST <= CMDS_DSPR_START;
									end
								end
							end
							
							4'h4: begin	//polygon
								if (!CMD_COORD_OVER) begin
									CMD_ST <= CMDS_DSPR_START/*CMDS_POLYGON_START*/;
								end
							end
							
							4'h5,
							4'h7: begin	//polyline
								if (!CMD_COORD_OVER) begin
									CMD_ST <= CMDS_POLYLINE_START;
								end
							end
							
							4'h6: begin	//line
								if (!CMD_COORD_OVER) begin
									CMD_ST <= CMDS_LINE_START;
								end
							end
							
							4'h8: USR_CLIP <= {{1'b0,CMD.CMDXA.COORD[9:0]},{2'b00,CMD.CMDYA.COORD[8:0]},{1'b0,CMD.CMDXC.COORD[9:0]},{2'b00,CMD.CMDYC.COORD[8:0]}};
							4'h9: SYS_CLIP <= {11'h000,11'h000,{1'b0,CMD.CMDXC.COORD[9:0]},{2'b00,CMD.CMDYC.COORD[8:0]}};
							4'hA: LOC_COORD <= {CMD.CMDXA.COORD,CMD.CMDYA.COORD};
						endcase
						if (DBG_CMD_CNT == 16) begin
							DBG_CMD_ADDR16 <= CMD_ADDR;
							
						end
					end
				end
				
				CMDS_CLT_LOAD: begin
					DBG_CMD_WAIT_CNT <= DBG_CMD_WAIT_CNT + 1'd1;
					CLT_READ <= 0;
					if (VRAM_DONE) begin 
						if (CMD.CMDCTRL.COMM == 4'h0) begin
							SPR_READ <= 1;
							CMD_ST <= CMDS_NSPR_START;
						end else if (CMD.CMDCTRL.COMM == 4'h1) begin 
							CMD_ST <= CMDS_SSPR_START;
						end else begin
							CMD_ST <= CMDS_DSPR_START;
						end
						DBG_CMD_WAIT_CNT <= '0;
					end
				end
				
				CMDS_NSPR_START: begin
					LINE_VERTA <= {CMD.CMDXA.COORD,CMD.CMDYA.COORD};
					LINE_VERTB.X <= CMD.CMDXA.COORD + {2'b00,CMD.CMDSIZE.SX,3'b000} - 11'd1;
					LINE_VERTB.Y <= CMD.CMDYA.COORD + {3'b000,CMD.CMDSIZE.SY} - 11'd1;
					TEXT_X <= '0;
					TEXT_Y <= '0;
					TEXT_DX <= {9'h001,11'h000};
					TEXT_DY <= {9'h001,11'h000};
					CMD_ST <= CMDS_SPR_READ;
				end
				
				CMDS_SSPR_START: begin
					case (CMD.CMDCTRL.ZP[1:0])
						2'b00: begin LINE_VERTA.X <= CMD.CMDXA.COORD;                       LINE_VERTB.X <= CMD.CMDXC.COORD; end
						2'b01: begin LINE_VERTA.X <= CMD.CMDXA.COORD;                       LINE_VERTB.X <= CMD.CMDXA.COORD + CMD.CMDXB.COORD; end
						2'b10: begin LINE_VERTA.X <= CMD.CMDXA.COORD-(CMD.CMDXB.COORD>>>1); LINE_VERTB.X <= CMD.CMDXA.COORD+((CMD.CMDXB.COORD+11'd1)>>>1); end
						2'b11: begin LINE_VERTA.X <= CMD.CMDXA.COORD-CMD.CMDXB.COORD;       LINE_VERTB.X <= CMD.CMDXA.COORD; end
					endcase
					case (CMD.CMDCTRL.ZP[3:2])
						2'b00: begin LINE_VERTA.Y <= CMD.CMDYA.COORD;                       LINE_VERTB.Y <= CMD.CMDYC.COORD; end
						2'b01: begin LINE_VERTA.Y <= CMD.CMDYA.COORD;                       LINE_VERTB.Y <= CMD.CMDYA.COORD + CMD.CMDYB.COORD; end
						2'b10: begin LINE_VERTA.Y <= CMD.CMDYA.COORD-(CMD.CMDYB.COORD>>>1); LINE_VERTB.Y <= CMD.CMDYA.COORD+((CMD.CMDYB.COORD+11'd1)>>>1); end
						2'b11: begin LINE_VERTA.Y <= CMD.CMDYA.COORD-CMD.CMDYB.COORD;       LINE_VERTB.Y <= CMD.CMDYA.COORD; end
					endcase
					TEXT_X <= '0;
					TEXT_Y <= '0;
					DIV_A <= {2'b00,CMD.CMDSIZE.SX,3'b000};
					if (!CMD.CMDCTRL.ZP) begin
						DIV_B <= CMD.CMDXC.COORD - CMD.CMDXA.COORD;
					end else begin
						DIV_B <= CMD.CMDXB.COORD + 11'd1;
					end
					CMD_ST <= CMDS_SPR_CALCX;
				end
				
				CMDS_SPR_CALCX: begin
					DIV_WAIT <= ~DIV_WAIT;
					if (DIV_WAIT) begin
						TEXT_DX <= DIV_R[19:0];
						DIV_A <= {3'b000,CMD.CMDSIZE.SY};
						if (!CMD.CMDCTRL.ZP) begin
							DIV_B <= CMD.CMDYC.COORD - CMD.CMDYA.COORD;
						end else begin
							DIV_B <= CMD.CMDYB.COORD + 11'd1;
						end
						CMD_ST <= CMDS_SPR_CALCY;
					end
				end
				
				CMDS_SPR_CALCY: begin
					DIV_WAIT <= ~DIV_WAIT;
					if (DIV_WAIT) begin
						TEXT_DY <= DIV_R[19:0];
						SPR_READ <= 1;
						CMD_ST <= CMDS_SPR_READ;
					end
				end
				
				CMDS_SPR_READ: begin
					DBG_CMD_WAIT_CNT <= DBG_CMD_WAIT_CNT + 1'd1;
					SPR_READ <= 0;
					if (VRAM_DONE) begin 
						if (CMD.CMDCTRL.COMM == 4'h2) CMD_ST <= AA ? CMDS_AA_DRAW : CMDS_LINE_DRAW;
						else CMD_ST <= CMDS_SPR_DRAW;
					DBG_CMD_WAIT_CNT <= '0;
					end
				end
				
				CMDS_SPR_DRAW: begin
					NEXT_TEXT_X = TEXT_X + TEXT_DX;
					NEXT_TEXT_Y = TEXT_Y;
					if (LINE_VERTA.X == LINE_VERTB.X) begin
						NEXT_TEXT_X = '0;
						NEXT_TEXT_Y = TEXT_Y + TEXT_DY;
					end
					
					if (((TEXT_X[19:11] & XMASK) != (NEXT_TEXT_X[19:11] & XMASK) || TEXT_Y[19:11] != NEXT_TEXT_Y[19:11])) begin
						SPR_READ <= 1;
						CMD_ST <= CMDS_SPR_READ;
					end
					TEXT_X <= NEXT_TEXT_X;
					TEXT_Y <= NEXT_TEXT_Y;
					
					LINE_VERTA.X <= LINE_VERTA.X + 11'd1;
					if (LINE_VERTA.X == LINE_VERTB.X) begin
						if (CMD.CMDCTRL.COMM == 4'd0) begin
							LINE_VERTA.X <= CMD.CMDXA.COORD;
						end else begin
							case (CMD.CMDCTRL.ZP[1:0])
								2'b00: begin LINE_VERTA.X <= CMD.CMDXA.COORD; end
								2'b01: begin LINE_VERTA.X <= CMD.CMDXA.COORD; end
								2'b10: begin LINE_VERTA.X <= CMD.CMDXA.COORD-(CMD.CMDXB.COORD>>>1); end
								2'b11: begin LINE_VERTA.X <= CMD.CMDXA.COORD-CMD.CMDXB.COORD; end
							endcase
						end
						LINE_VERTA.Y <= LINE_VERTA.Y + 11'd1;
						if (LINE_VERTA.Y == LINE_VERTB.Y) begin
							SPR_READ <= 0;
							CMD_ST <= CMDS_END;
						end
					end
				end
				
				CMDS_DSPR_START: begin
					CMDXA_CLIP <= $signed(CMD.CMDXA.COORD) < $signed(SYS_CLIP.X1 - LOC_COORD.X) ? SYS_CLIP.X1 - LOC_COORD.X : 
					               $signed(CMD.CMDXA.COORD) > $signed(SYS_CLIP.X2 - LOC_COORD.X) ? SYS_CLIP.X2 - LOC_COORD.X : 
					               CMD.CMDXA.COORD;
					CMDXB_CLIP <= $signed(CMD.CMDXB.COORD) < $signed(SYS_CLIP.X1 - LOC_COORD.X) ? SYS_CLIP.X1 - LOC_COORD.X : 
					               $signed(CMD.CMDXB.COORD) > $signed(SYS_CLIP.X2 - LOC_COORD.X) ? SYS_CLIP.X2 - LOC_COORD.X : 
					               CMD.CMDXB.COORD;
					CMDXC_CLIP <= $signed(CMD.CMDXC.COORD) < $signed(SYS_CLIP.X1 - LOC_COORD.X) ? SYS_CLIP.X1 - LOC_COORD.X : 
					               $signed(CMD.CMDXC.COORD) > $signed(SYS_CLIP.X2 - LOC_COORD.X) ? SYS_CLIP.X2 - LOC_COORD.X : 
					               CMD.CMDXC.COORD;
					CMDXD_CLIP <= $signed(CMD.CMDXD.COORD) < $signed(SYS_CLIP.X1 - LOC_COORD.X) ? SYS_CLIP.X1 - LOC_COORD.X : 
					               $signed(CMD.CMDXD.COORD) > $signed(SYS_CLIP.X2 - LOC_COORD.X) ? SYS_CLIP.X2 - LOC_COORD.X : 
					               CMD.CMDXD.COORD;
					TEXT_X <= '0;
					TEXT_Y <= '0;
					CMD_ST <= CMDS_POLYGON_START;
				end
				
				CMDS_POLYGON_START: begin
					LEFT_VERT <= {CMD.CMDXA.COORD,CMD.CMDYA.COORD};
					RIGHT_VERT <= {CMD.CMDXB.COORD,CMD.CMDYB.COORD};
					NEW_POLY_LSX = {CMD.CMDXD.COORD[10],CMD.CMDXD.COORD} - /*{CMDXA_CLIP[10],CMDXA_CLIP}*/{CMD.CMDXA.COORD[10],CMD.CMDXA.COORD};
					NEW_POLY_LSY = {CMD.CMDYD.COORD[10],CMD.CMDYD.COORD} - {CMD.CMDYA.COORD[10],CMD.CMDYA.COORD};
					NEW_POLY_RSX = {CMD.CMDXC.COORD[10],CMD.CMDXC.COORD} - /*{CMDXB_CLIP[10],CMDXB_CLIP}*/{CMD.CMDXB.COORD[10],CMD.CMDXB.COORD};
					NEW_POLY_RSY = {CMD.CMDYC.COORD[10],CMD.CMDYC.COORD} - {CMD.CMDYB.COORD[10],CMD.CMDYB.COORD};
					
					POLY_LSX <= Abs(NEW_POLY_LSX);
					POLY_LSY <= Abs(NEW_POLY_LSY);
					POLY_RSX <= Abs(NEW_POLY_RSX);
					POLY_RSY <= Abs(NEW_POLY_RSY);
					POLY_LDIRX <= NEW_POLY_LSX[11];
					POLY_LDIRY <= NEW_POLY_LSY[11];
					POLY_RDIRX <= NEW_POLY_RSX[11];
					POLY_RDIRY <= NEW_POLY_RSY[11];
										
					CMD_ST <= CMDS_POLYGON_CALCD;
				end
				
				CMDS_POLYGON_CALCD: begin
					DIV_A <= {3'b000,CMD.CMDSIZE.SY};
					if (POLY_LSX >= POLY_LSY && POLY_LSX >= POLY_RSX && POLY_LSX >= POLY_RSY) begin
						POLY_S <= 2'b00;
						DIV_B <= POLY_LSX + 11'd1;
					end else if (POLY_LSY >= POLY_LSX && POLY_LSY >= POLY_RSX && POLY_LSY >= POLY_RSY) begin
						POLY_S <= 2'b01;
						DIV_B <= POLY_LSY + 11'd1;
					end else if (POLY_RSX >= POLY_LSX && POLY_RSX >= POLY_LSY && POLY_RSX >= POLY_RSY) begin
						POLY_S <= 2'b10;
						DIV_B <= POLY_RSX + 11'd1;
					end else begin
						POLY_S <= 2'b11;
						DIV_B <= POLY_RSY + 11'd1;
					end
					
					POLY_LDX <= '0;
					POLY_LDY <= '0;
					POLY_RDX <= '0;
					POLY_RDY <= '0;
					
					CMD_ST <= CMDS_POLYGON_CALCTDY;
				end
				
				CMDS_POLYGON_CALCTDY: begin
					DIV_WAIT <= ~DIV_WAIT;
					if (DIV_WAIT) begin
						TEXT_DY <= DIV_R[19:0];
						CMD_ST <= CMDS_LINE_CALC;
					end
				end
				
				CMDS_POLYLINE_START: begin
					LEFT_VERT <= {CMD.CMDXA.COORD,CMD.CMDYA.COORD};
					RIGHT_VERT <= {CMD.CMDXB.COORD,CMD.CMDYB.COORD};
					POLY_S <= 2'b00;
					CMD_ST <= CMDS_LINE_CALC;
				end
				
				CMDS_LINE_START: begin
					LEFT_VERT <= {CMD.CMDXA.COORD,CMD.CMDYA.COORD};
					RIGHT_VERT <= {CMD.CMDXB.COORD,CMD.CMDYB.COORD};
					CMD_ST <= CMDS_LINE_CALC;
				end
				
				CMDS_LINE_CALC: begin
					RIGHT_VERT_X_CLIP = $signed(RIGHT_VERT.X) < $signed(SYS_CLIP.X1 - LOC_COORD.X) ? SYS_CLIP.X1 - LOC_COORD.X : 
					                    $signed(RIGHT_VERT.X) > $signed(SYS_CLIP.X2 - LOC_COORD.X) ? SYS_CLIP.X2 - LOC_COORD.X : 
					                    RIGHT_VERT.X;
					RIGHT_VERT_Y_CLIP = $signed(RIGHT_VERT.Y) < $signed(SYS_CLIP.Y1 - LOC_COORD.Y) ? SYS_CLIP.Y1 - LOC_COORD.Y : 
					                    $signed(RIGHT_VERT.Y) > $signed(SYS_CLIP.Y2 - LOC_COORD.Y) ? SYS_CLIP.Y2 - LOC_COORD.Y : 
					                    RIGHT_VERT.Y;
					LINE_VERTA <= LEFT_VERT;
					LINE_VERTB <= RIGHT_VERT;//{RIGHT_VERT_X_CLIP,RIGHT_VERT_Y_CLIP};
					NEW_LINE_SX = {RIGHT_VERT.X[10],RIGHT_VERT.X} - {LEFT_VERT.X[10],LEFT_VERT.X};
					NEW_LINE_SY = {RIGHT_VERT.Y[10],RIGHT_VERT.Y} - {LEFT_VERT.Y[10],LEFT_VERT.Y};
					LINE_SX <= Abs(NEW_LINE_SX);
					LINE_SY <= Abs(NEW_LINE_SY);
					LINE_DIRX <= NEW_LINE_SX[11];
					LINE_DIRY <= NEW_LINE_SY[11];

					DIV_A <= {2'b00,CMD.CMDSIZE.SX,3'b000};
					DIV_B <= Abs(NEW_LINE_SX) >= Abs(NEW_LINE_SY) ? Abs(NEW_LINE_SX) + 11'd1 : Abs(NEW_LINE_SY) + 11'd1;
					CMD_ST <= CMDS_LINE_CALCD;
				end
				
				CMDS_LINE_CALCD: begin
					DIV_WAIT <= ~DIV_WAIT;
					if (DIV_WAIT) begin
						LINE_S <= ~(LINE_SX >= LINE_SY);
						LINE_D <= '0;
						AA <= 0;
						
						TEXT_DX <= DIV_R[19:0];
						if (CMD.CMDCTRL.COMM <= 4'h3) begin
							SPR_READ <= 1;
							CMD_ST <= CMDS_SPR_READ;
						end else begin
							CMD_ST <= CMDS_LINE_DRAW;
						end
						
						EC_FIND <= 0;
					end
				end
				
				CMDS_LINE_DRAW: begin
					if (CMD.CMDCTRL.COMM <= 4'h3 && !CMD.CMDPMOD.ECD && PAT.EC) EC_FIND <= 1;
					NEXT_TEXT_X = TEXT_X + TEXT_DX;
					NEXT_TEXT_Y = TEXT_Y;
					if ((LINE_VERTA.X == LINE_VERTB.X && !LINE_S) || (LINE_VERTA.Y == LINE_VERTB.Y && LINE_S) || (CMD.CMDCTRL.COMM <= 4'h3 && !CMD.CMDPMOD.ECD && PAT.EC && EC_FIND)) begin
						NEXT_TEXT_X = '0;
						NEXT_TEXT_Y = TEXT_Y + TEXT_DY;
					end
					
					if (!LINE_S) begin
						LINE_VERTA.X <= LINE_VERTA.X + {{10{LINE_DIRX}},1'b1};
						NEXT_LINE_D = LINE_D + LINE_SY;
						if (NEXT_LINE_D >= LINE_SX) begin
							NEXT_LINE_D = NEXT_LINE_D - LINE_SX;
							LINE_VERTA.Y <= LINE_VERTA.Y + {{10{LINE_DIRY}},1'b1};
							AA_X <= LINE_VERTA.X;
							AA_Y <= LINE_VERTA.Y;
							AA <= 1;
							CMD_ST <= CMDS_AA_DRAW;
//							SPR_READ <= 0;
						end
						LINE_D <= NEXT_LINE_D;
					end else begin
						NEXT_LINE_D = LINE_D + LINE_SX;
						if (NEXT_LINE_D >= LINE_SY) begin
							NEXT_LINE_D = NEXT_LINE_D - LINE_SY;
							LINE_VERTA.X <= LINE_VERTA.X + {{10{LINE_DIRX}},1'b1};
							AA_X <= LINE_VERTA.X;
							AA_Y <= LINE_VERTA.Y;
							AA <= 1;
							CMD_ST <= CMDS_AA_DRAW;
//							SPR_READ <= 0;
						end
						LINE_D <= NEXT_LINE_D;
						LINE_VERTA.Y <= LINE_VERTA.Y + {{10{LINE_DIRY}},1'b1};
					end
					TEXT_X <= NEXT_TEXT_X;
					TEXT_Y <= NEXT_TEXT_Y;
					
					if (CMD.CMDCTRL.COMM <= 4'h3 && ((TEXT_X[19:11] & XMASK) != (NEXT_TEXT_X[19:11] & XMASK) || TEXT_Y[19:11] != NEXT_TEXT_Y[19:11]) && SCLIP) begin
						SPR_READ <= 1;
						CMD_ST <= CMDS_SPR_READ;
					end
					if ((LINE_VERTA.X == LINE_VERTB.X && !LINE_S) || (LINE_VERTA.Y == LINE_VERTB.Y && LINE_S) || (CMD.CMDCTRL.COMM <= 4'h3 && !CMD.CMDPMOD.ECD && PAT.EC && EC_FIND)) begin
						CMD_ST <= CMDS_LINE_NEXT;
						SPR_READ <= 0;
						EC_FIND <= 0;
					end
				end
				
				CMDS_AA_DRAW: begin
					AA <= 0;
					CMD_ST <= CMDS_LINE_DRAW;
				end
				
				CMDS_LINE_NEXT: begin
					if (CMD.CMDCTRL.COMM == 4'h5) begin
						CMD_ST <= CMDS_LINE_CALC;
						case (POLY_S)
							2'd0: begin
								LEFT_VERT <= {CMD.CMDXB.COORD,CMD.CMDYB.COORD};
								RIGHT_VERT <= {CMD.CMDXC.COORD,CMD.CMDYC.COORD};
							end
							2'd1: begin
								LEFT_VERT <= {CMD.CMDXC.COORD,CMD.CMDYC.COORD};
								RIGHT_VERT <= {CMD.CMDXD.COORD,CMD.CMDYD.COORD};
							end
							2'd2: begin
								LEFT_VERT <= {CMD.CMDXD.COORD,CMD.CMDYD.COORD};
								RIGHT_VERT <= {CMD.CMDXA.COORD,CMD.CMDYA.COORD};
							end
						endcase
						POLY_S <= POLY_S + 2'd01;
						if (POLY_S == 2'd3) CMD_ST <= CMDS_END;
					end else if (CMD.CMDCTRL.COMM == 4'h6) begin
						CMD_ST <= CMDS_END;
					end else begin
						CMD_ST <= CMDS_LINE_CALC;
						if (POLY_S == 2'b00) begin
							LEFT_VERT.X <= LEFT_VERT.X + {{10{POLY_LDIRX}},1'b1};
							
							NEXT_POLY_LDX = POLY_LDX + POLY_LSY;
							if (NEXT_POLY_LDX >= POLY_LSX) begin
								NEXT_POLY_LDX = NEXT_POLY_LDX - POLY_LSX;
								LEFT_VERT.Y <= LEFT_VERT.Y + {{10{POLY_LDIRY}},1'b1};
							end
							POLY_LDX <= NEXT_POLY_LDX;
							
							NEXT_POLY_RDX = POLY_RDX + POLY_RSX;
							if (NEXT_POLY_RDX >= POLY_LSX) begin
								NEXT_POLY_RDX = NEXT_POLY_RDX - POLY_LSX;
								RIGHT_VERT.X <= RIGHT_VERT.X + {{10{POLY_RDIRX}},1'b1};
							end
							POLY_RDX <= NEXT_POLY_RDX;
							
							NEXT_POLY_RDY = POLY_RDY + POLY_RSY;
							if (NEXT_POLY_RDY >= POLY_LSX) begin
								NEXT_POLY_RDY = NEXT_POLY_RDY - POLY_LSX;
								RIGHT_VERT.Y <= RIGHT_VERT.Y + {{10{POLY_RDIRY}},1'b1};
							end
							POLY_RDY <= NEXT_POLY_RDY;
							
							if (LEFT_VERT.X == /*CMDXD_CLIP*/CMD.CMDXD.COORD) begin
								CMD_ST <= CMDS_END;
							end
						end else if (POLY_S == 2'b01) begin
							NEXT_POLY_LDY = POLY_LDY + POLY_LSX;
							if (NEXT_POLY_LDY >= POLY_LSY) begin
								NEXT_POLY_LDY = NEXT_POLY_LDY - POLY_LSY;
								LEFT_VERT.X <= LEFT_VERT.X + {{10{POLY_LDIRX}},1'b1};
							end
							POLY_LDY <= NEXT_POLY_LDY;
							
							LEFT_VERT.Y <= LEFT_VERT.Y + {{10{POLY_LDIRY}},1'b1};
							
							NEXT_POLY_RDX = POLY_RDX + POLY_RSX;
							if (NEXT_POLY_RDX >= POLY_LSY) begin
								NEXT_POLY_RDX = NEXT_POLY_RDX - POLY_LSY;
								RIGHT_VERT.X <= RIGHT_VERT.X + {{10{POLY_RDIRX}},1'b1};
							end
							POLY_RDX <= NEXT_POLY_RDX;
							
							NEXT_POLY_RDY = POLY_RDY + POLY_RSY;
							if (NEXT_POLY_RDY >= POLY_LSY) begin
								NEXT_POLY_RDY = NEXT_POLY_RDY - POLY_LSY;
								RIGHT_VERT.Y <= RIGHT_VERT.Y + {{10{POLY_RDIRY}},1'b1};
							end
							POLY_RDY <= NEXT_POLY_RDY;
							
							if (LEFT_VERT.Y == CMD.CMDYD.COORD) begin
								CMD_ST <= CMDS_END;
							end
						end else if (POLY_S == 2'b10) begin
							NEXT_POLY_LDX = POLY_LDX + POLY_LSX;
							if (NEXT_POLY_LDX >= POLY_RSX) begin
								NEXT_POLY_LDX = NEXT_POLY_LDX - POLY_RSX;
								LEFT_VERT.X <= LEFT_VERT.X + {{10{POLY_LDIRX}},1'b1};
							end
							POLY_LDX <= NEXT_POLY_LDX;
							
							NEXT_POLY_LDY = POLY_LDY + POLY_LSY;
							if (NEXT_POLY_LDY >= POLY_RSX) begin
								NEXT_POLY_LDY = NEXT_POLY_LDY - POLY_RSX;
								LEFT_VERT.Y <= LEFT_VERT.Y + {{10{POLY_LDIRY}},1'b1};
							end
							POLY_LDY <= NEXT_POLY_LDY;
							
							RIGHT_VERT.X <= RIGHT_VERT.X + {{10{POLY_RDIRX}},1'b1};
							
							NEXT_POLY_RDY = POLY_RDY + POLY_RSY;
							if (NEXT_POLY_RDY >= POLY_RSX) begin
								NEXT_POLY_RDY = NEXT_POLY_RDY - POLY_RSX;
								RIGHT_VERT.Y <= RIGHT_VERT.Y + {{10{POLY_RDIRY}},1'b1};
							end
							POLY_RDY <= NEXT_POLY_RDY;
							
							if (RIGHT_VERT.X == /*CMDXC_CLIP*/CMD.CMDXC.COORD) begin
								CMD_ST <= CMDS_END;
							end
						end else begin
							NEXT_POLY_LDX = POLY_LDX + POLY_LSX;
							if (NEXT_POLY_LDX >= POLY_RSY) begin
								NEXT_POLY_LDX = NEXT_POLY_LDX - POLY_RSY;
								LEFT_VERT.X <= LEFT_VERT.X + {{10{POLY_LDIRX}},1'b1};
							end
							POLY_LDX <= NEXT_POLY_LDX;
							
							NEXT_POLY_LDY = POLY_LDY + POLY_LSY;
							if (NEXT_POLY_LDY >= POLY_RSY) begin
								NEXT_POLY_LDY = NEXT_POLY_LDY - POLY_RSY;
								LEFT_VERT.Y <= LEFT_VERT.Y + {{10{POLY_LDIRY}},1'b1};
							end
							POLY_LDY <= NEXT_POLY_LDY;
							
							NEXT_POLY_RDX = POLY_RDX + POLY_RSX;
							if (NEXT_POLY_RDX >= POLY_RSY) begin
								NEXT_POLY_RDX = NEXT_POLY_RDX - POLY_RSY;
								RIGHT_VERT.X <= RIGHT_VERT.X + {{10{POLY_RDIRX}},1'b1};
							end
							POLY_RDX <= NEXT_POLY_RDX;
							
							RIGHT_VERT.Y <= RIGHT_VERT.Y + {{10{POLY_RDIRY}},1'b1};
							
							if (RIGHT_VERT.Y == CMD.CMDYC.COORD) begin
								CMD_ST <= CMDS_END;
							end
						end
					end
				end
				
				CMDS_END: begin
					NEXT_ADDR = CMD_ADDR + 18'd16;
					case (CMD.CMDCTRL.JP[1:0])
						2'b00: begin CMD_ADDR <= NEXT_ADDR; end
						2'b01: begin CMD_ADDR <= {CMD.CMDLINK,2'b00}; end
						2'b10: begin CMD_ADDR <= {CMD.CMDLINK,2'b00}; CMD_JRET <= NEXT_ADDR; end
						2'b11: begin CMD_ADDR <= CMD_JRET; end
					endcase
					
					if (CMD.CMDCTRL.END /*|| FRAME_START_PEND*/) begin
						CMD_ST <= CMDS_IDLE;
						DBG_CMD_CNT <= '0;
					end else begin
						CMD_READ <= 1;
						CMD_ST <= CMDS_READ;
						DBG_CMD_CNT <= DBG_CMD_CNT + 1'd1;
						DBG_CMD_ADDR_LAST <= CMD_ADDR;
						DBG_CMD_CMDSRCA_LAST <= CMD.CMDSRCA;
					end
				end
			endcase
		end
	end
	
	assign DBG_START = (CMD_ST == CMDS_IDLE && (FRAME_START /*|| FRAME_START_PEND*/));
	assign DBG_CMD_END = (CMD_ST == CMDS_END);
	assign DBG_LINE_OVER = LINE_SX > 11'd200 || LINE_SY > 11'd200;
		
	assign TEXT_PAT = SPR_DATA;
		
	bit [15:0] ORIG_C;//////
	always_comb begin
		bit        TP;
		bit        EC;
		bit [15:0] CALC_C;
		bit        MESH;
		
		PAT = GetPattern(TEXT_PAT, CMD.CMDPMOD.CM, TEXT_X[12:11] ^ {2{CMD.CMDCTRL.DIR[0]}});
		if (!CMD.CMDCTRL.COMM[2]) begin
			case (CMD.CMDPMOD.CM)
				3'b000: ORIG_C = {CMD.CMDCOLR[15:4],PAT.C[3:0]};
				3'b001: ORIG_C = CLT_Q;
				3'b010: ORIG_C = {CMD.CMDCOLR[15:6],PAT.C[5:0]};
				3'b011: ORIG_C = {CMD.CMDCOLR[15:7],PAT.C[6:0]};
				3'b100: ORIG_C = {CMD.CMDCOLR[15:8],PAT.C[7:0]};
				3'b101: ORIG_C = PAT.C;
				default:ORIG_C = '0;
			endcase
			TP = PAT.TP;
			EC = PAT.EC;
		end else begin
			ORIG_C = CMD.CMDCOLR;
			TP = 0;
			EC = 0;
		end
		CALC_C = ColorCalc(ORIG_C,FB_DRAW_Q,CMD.CMDPMOD.CCB);
					
		if (CMD_ST == CMDS_AA_DRAW && (LINE_DIRX^LINE_DIRY)) begin
			DRAW_X = LOC_COORD.X + AA_X;
		end else begin
			DRAW_X = LOC_COORD.X + LINE_VERTA.X;
		end
		if (CMD_ST == CMDS_AA_DRAW && !(LINE_DIRX^LINE_DIRY)) begin
			DRAW_Y = LOC_COORD.Y + AA_Y;
		end else begin
			DRAW_Y = LOC_COORD.Y + LINE_VERTA.Y;
		end
			
		SCLIP = !DRAW_X[10] && DRAW_X[9:0] <= SYS_CLIP.X2[9:0] && !DRAW_Y[10] && !DRAW_Y[9] && DRAW_Y[8:0] <= SYS_CLIP.Y2[8:0];
		UCLIP = !DRAW_X[10] && DRAW_X[9:0] >= USR_CLIP.X1[9:0] && DRAW_X[9:0] <= USR_CLIP.X2[9:0] && !DRAW_Y[10] && !DRAW_Y[9] && DRAW_Y[8:0] >= USR_CLIP.Y1[8:0] && DRAW_Y[8:0] <= USR_CLIP.Y2[8:0];
		MESH = ~(DRAW_X[0] ^ DRAW_Y[0]);
		FB_DRAW_A = {DRAW_Y[7:0],DRAW_X[8:0]};
		FB_DRAW_D = CALC_C;
		FB_DRAW_WE = (CMD_ST == CMDS_SPR_DRAW || CMD_ST == CMDS_LINE_DRAW || CMD_ST == CMDS_AA_DRAW) & (~TP | CMD.CMDPMOD.SPD) & (~EC | CMD.CMDPMOD.ECD) & SCLIP & (UCLIP | ~CMD.CMDPMOD.CLIP) & (MESH | ~CMD.CMDPMOD.MESH);
		
		SPR_ADDR = SprAddr(TEXT_X[19:11],TEXT_Y[19:11],CMD.CMDSIZE,CMD.CMDCTRL.DIR,CMD.CMDSRCA,CMD.CMDPMOD.CM);
		CLT_ADDR = {CMD.CMDCOLR,2'b00};
		CLT_RA = PAT.C[3:0];
	end
	assign ORIG_C_DBG = ORIG_C;
	assign DRAW_X_DBG = DRAW_X;
	assign DRAW_Y_DBG = DRAW_Y;
	
	assign DBG_DRAW_OVER = DRAW_X[10:8] == 3'b011 || DRAW_X[10:8] == 3'b101 || DRAW_Y[10:8] == 2'b011 || DRAW_Y[10:8] == 3'b101;
	
	//FB out
	bit [8:0] OUT_X, ERASE_X;
	bit [8:0] OUT_Y, ERASE_Y;
	always @(posedge CLK or negedge RST_N) begin
		bit       HTIM_N_OLD;
		bit       VTIM_N_OLD;
		
		if (!RST_N) begin
			OUT_X <= '0;
			OUT_Y <= '0;
		end
		else begin
			if (OUT_X < 9'd352 && VTIM_N && DCLK) begin
				OUT_X <= OUT_X + 9'd1;
				FB_DISP_A <= {OUT_Y[7:0],OUT_X};
			end
			
			HTIM_N_OLD <= HTIM_N;
			if (HTIM_N && !HTIM_N_OLD /*&& VTIM_N*/) begin
				OUT_X <= '0;
				OUT_Y <= OUT_Y + 9'd1;
				if (!VTIM_N) begin
					OUT_Y <= '0;
				end
			end
			
			if (CE_R) begin
				if (!VTIM_N) begin
					ERASE_X <= ERASE_X + 9'd1;
					if (ERASE_X == {EWRR.X3,3'b111}) begin
						ERASE_X <= {EWLR.X1,3'b000};
						ERASE_Y <= ERASE_Y + 9'd1;
					end
					FB_ERASE_A <= {ERASE_Y[7:0],ERASE_X};
				end else begin
					ERASE_X <= {EWLR.X1,3'b000};
					ERASE_Y <= EWLR.Y1;
				end
			end
//			VTIM_N_OLD <= VTIM_N;
//			if (VTIM_N && !VTIM_N_OLD) begin
//				OUT_Y <= '0;
//			end
		end
	end
	
	assign FRAME_ERASE_HIT = (OUT_X >= {EWLR.X1,3'b000}) & (OUT_X <= {EWRR.X3,3'b111}) & (OUT_Y >= EWLR.Y1) & (OUT_Y <= EWRR.Y3) & FRAME_ERASE & VTIM_N;
	assign VBLANK_ERASE_HIT = (ERASE_X >= {EWLR.X1,3'b000}) & (ERASE_X <= {EWRR.X3,3'b111}) & (ERASE_Y >= EWLR.Y1) & (ERASE_Y <= EWRR.Y3) & VBLANK_ERASE & ~VTIM_N;
	
//	assign FB_DISP_A = {OUT_Y,OUT_X};
	assign VOUT = FB_DISP_Q;
		
	
	//VRAM
	wire CPU_VRAM_REQ = (A[20:19] == 2'b00) & ~DTEN_N & ~AD_N & ~CS_N & ~REQ_N;	//000000-07FFFF
//	wire CPU_FB_REQ = (A[20:19] == 2'b01) & ~DTEN_N & ~AD_N & ~CS_N & ~REQ_N;	//080000-0FFFFF
	bit [18:1] VRAM_LAST_A;
	always @(posedge CLK or negedge RST_N) begin
		bit        CMD_READ_PEND;
		bit        SPR_READ_PEND;
		bit        CLT_READ_PEND;
		bit        LAST_DATA;
		bit        CMD_DATA_PEND;
		bit  [3:0] CMD_DATA_POS;
		bit        VRAM_RDY_OLD;
//		bit        CPU_VRAM_LOCK;
		
		if (!RST_N) begin
			VRAM_ST <= VS_IDLE;
			VRAM_A <= '0;
			VRAM_D <= '0;
			VRAM_WE <= '0;
			VRAM_RD <= 0;
			VRAM_DONE <= 0;
			CMD_READ_PEND <= 0;
			SPR_READ_PEND <= 0;
			CLT_READ_PEND <= 0;
			CMD <= '0;
			
			A <= '0;
			WE_N <= 1;
			DQM <= '1;
			BURST <= 0;
//			CPU_VRAM_LOCK <= 0;
			CPU_VRAM_RRDY <= 1;
			CPU_VRAM_WRDY <= 1;
		end 
//		else if (FRAME_START) begin
//			CMD_READ_PEND <= 0;
//			SPR_READ_PEND <= 0;
//			CLT_READ_PEND <= 0;
//			VRAM_WE <= '0;
//			VRAM_RD <= 0;
//			CMD_ST <= VS_IDLE;
		else begin
			if (!CS_N && DTEN_N && AD_N && CE_R) begin
				if (!DI[15]) begin
					A[20:9] <= DI[11:0];
					WE_N <= DI[14];
					BURST <= DI[13];
				end else begin
					A[8:1] <= DI[7:0];
					DQM <= DI[13:12];
				end
			end
			
			if (CMD_READ && !CMD_READ_PEND) CMD_READ_PEND <= 1;
			if (SPR_READ && !SPR_READ_PEND) SPR_READ_PEND <= 1;
			if (CLT_READ && !CLT_READ_PEND) CLT_READ_PEND <= 1;
			
			if (CPU_VRAM_REQ && !WE_N && CPU_VRAM_WRDY) CPU_VRAM_WRDY <= 0;
			if (CPU_VRAM_REQ &&  WE_N && CPU_VRAM_RRDY) CPU_VRAM_RRDY <= 0;
			
			VRAM_DONE <= 0;
			CLT_WE <= 0;
			case (VRAM_ST)
				VS_IDLE: begin
					if ((CPU_VRAM_REQ && !WE_N) || !CPU_VRAM_WRDY) begin
						if (VRAM_RDY) begin
							VRAM_A <= A[18:1];
							VRAM_D <= DI;
							VRAM_WE <= ~{2{WE_N}} & ~DQM;
							VRAM_RD <= 0;
							A <= A + 20'd1;
							CPU_VRAM_WRDY <= 1;
							VRAM_ST <= VS_CPU_WRITE;
						end
					end else if ((CPU_VRAM_REQ && WE_N) || !CPU_VRAM_RRDY) begin
						begin
							VRAM_A <= A[18:1];
							VRAM_WE <= '0;
							VRAM_RD <= 1;
							A <= A + 20'd1;
							VRAM_ST <= VS_CPU_READ;
						end
					end else if (CMD_READ_PEND && !FRAME_START) begin
						CMD_READ_PEND <= 0;
						VRAM_A <= CMD_ADDR;
						VRAM_WE <= '0;
						VRAM_RD <= 1;
						VRAM_ST <= VS_CMD_READ;
					end else if (SPR_READ_PEND && !FRAME_START) begin
						SPR_READ_PEND <= 0;
						VRAM_A <= SPR_ADDR[18:1];
						VRAM_WE <= '0;
						VRAM_RD <= 1;
						VRAM_ST <= VS_PAT_READ;
					end else if (CLT_READ_PEND && !FRAME_START) begin
						CLT_READ_PEND <= 0;
						VRAM_A <= CLT_ADDR;
						VRAM_WE <= '0;
						VRAM_RD <= 1;
						VRAM_ST <= VS_CLT_READ;
					end
				end
				
				VS_CPU_WRITE: begin
					VRAM_WE <= '0;
					VRAM_ST <= VS_IDLE;
				end
				
				VS_CPU_WRITE_END: begin
//					if (VRAM_RDY) begin
//						VRAM_WE <= '0;
//						if (BURST && !AD_N) begin
//							VRAM_ST <= VS_CPU_WRITE;
//						end else 
//							VRAM_ST <= VS_IDLE;
//					end
				end
				
				VS_CPU_READ: begin
//					VRAM_ST <= VS_CPU_READ_END;
					if (VRAM_RDY && CE_R) begin
						IO_VRAM_DO <= VRAM_Q[31:16];
						VRAM_RD <= 0;
						CPU_VRAM_RRDY <= 1;
						VRAM_ST <= VS_IDLE;
					end
				end
				
				VS_CPU_READ_END: begin
//					if (VRAM_RDY) begin
//						IO_VRAM_DO <= VRAM_Q[31:16];
//						VRAM_RD <= 0;
//						VRAM_ST <= VS_IDLE;
//					end
				end
					
				VS_CMD_READ: begin
					if (FRAME_START) begin
						VRAM_WE <= '0;
						VRAM_RD <= 0;
						VRAM_ST <= VS_IDLE;
					end else begin
						VRAM_RD <= 0;
						VRAM_ST <= VS_CMD_END;
					end
				end
				
				VS_CMD_END: begin
					if (FRAME_START) begin
						VRAM_RD <= 0;
						VRAM_ST <= VS_IDLE;
					end else if (VRAM_RDY) begin
						case (VRAM_A[4:1])
							4'h0: CMD.CMDCTRL <= VRAM_Q[31:16];
							4'h1: CMD.CMDLINK <= VRAM_Q[31:16];
							4'h2: CMD.CMDPMOD <= VRAM_Q[31:16];
							4'h3: CMD.CMDCOLR <= VRAM_Q[31:16];
							4'h4: CMD.CMDSRCA <= VRAM_Q[31:16];
							4'h5: CMD.CMDSIZE <= VRAM_Q[31:16];
							4'h6: CMD.CMDXA <= VRAM_Q[31:16];
							4'h7: CMD.CMDYA <= VRAM_Q[31:16];
							4'h8: CMD.CMDXB <= VRAM_Q[31:16];
							4'h9: CMD.CMDYB <= VRAM_Q[31:16];
							4'hA: CMD.CMDXC <= VRAM_Q[31:16];
							4'hB: CMD.CMDYC <= VRAM_Q[31:16];
							4'hC: CMD.CMDXD <= VRAM_Q[31:16];
							4'hD: CMD.CMDYD <= VRAM_Q[31:16];
							4'hE: CMD.CMDGRDA <= VRAM_Q[31:16];
						endcase
						VRAM_A <= VRAM_A + 18'd1;
						VRAM_RD <= 1;
						VRAM_ST <= VS_CMD_READ;
						if ({VRAM_A[4:1],1'b0} == 5'h1C) begin
							VRAM_RD <= 0;
							VRAM_DONE <= 1;
							VRAM_ST <= VS_IDLE;
						end
					end
				end
				
				VS_CLT_READ: begin
					if (FRAME_START) begin
						VRAM_WE <= '0;
						VRAM_RD <= 0;
						VRAM_ST <= VS_IDLE;
					end else begin
						VRAM_ST <= VS_CLT_END;
						VRAM_RD <= 0;
					end
				end
				
				VS_CLT_END: begin
					if (FRAME_START) begin
						VRAM_RD <= 0;
						VRAM_ST <= VS_IDLE;
					end else if (VRAM_RDY) begin
						VRAM_A <= VRAM_A + 18'd1;
						VRAM_RD <= 1;
						VRAM_ST <= VS_CLT_READ;
						if ({VRAM_A[4:1],1'b0} == 5'h1E) begin
							VRAM_RD <= 0;
							VRAM_DONE <= 1;
							VRAM_ST <= VS_IDLE;
						end
						CLT_WA <= VRAM_A[4:1];
						CLT_D <= VRAM_Q[31:16];
						CLT_WE <= 1;
					end
				end
				
				VS_PAT_READ: begin
					if (FRAME_START) begin
						VRAM_WE <= '0;
						VRAM_RD <= 0;
						VRAM_ST <= VS_IDLE;
					end else begin
						VRAM_RD <= 0;
						VRAM_ST <= VS_PAT_END;
					end
				end
				
				VS_PAT_END: begin
					if (FRAME_START) begin
						VRAM_WE <= '0;
						VRAM_RD <= 0;
						VRAM_ST <= VS_IDLE;
					end else if (VRAM_RDY) begin
						SPR_DATA <= VRAM_Q[31:16];
						VRAM_RD <= 0;
						VRAM_DONE <= 1;
						VRAM_ST <= VS_IDLE;
					end
				end
			endcase
			
			if (FRAME_START) begin
				CMD_READ_PEND <= 0;
				SPR_READ_PEND <= 0;
				CLT_READ_PEND <= 0;
			end
		end
	end
	
	COL_TBL CLT(.CLK(CLK), .WRADDR(CLT_WA), .DATA(CLT_D), .WREN(CLT_WE), .RDADDR(CLT_RA), .Q(CLT_Q));

//	always @(posedge CLK or negedge RST_N) begin
//		bit VRAM_SEL_OLD;
//		
//		if (!RST_N) begin
//			CPU_VRAM_RRDY <= 1;
//			CPU_VRAM_WRDY <= 1;
//			CPU_VRAM_READ_PEND <= 0;
//			CPU_VRAM_WRITE_PEND <= 0;
//		end
//		else begin
//			VRAM_SEL_OLD <= CPU_VRAM_SEL;
//			if (CPU_VRAM_SEL && !VRAM_SEL_OLD && WE_N && !CPU_VRAM_READ_PEND) begin
//				IO_VRAM_RA <= A[18:1];
//				CPU_VRAM_READ_PEND <= 1;
//			end else if (VRAM_ST == VS_CPU_READ_END && VRAM_RDY && !VRAM_WE && CPU_VRAM_READ_PEND && !CPU_VRAM_WRITE_PEND) begin
//				CPU_VRAM_READ_PEND <= 0;
//			end
//			
//			if (CPU_VRAM_SEL && !VRAM_SEL_OLD && WE_N && CPU_VRAM_RRDY) begin
//				CPU_VRAM_RRDY <= 0;
//			end else if (VRAM_ST == VS_CPU_READ_END && VRAM_RDY && !VRAM_WE && !CPU_VRAM_RRDY) begin
//				CPU_VRAM_RRDY <= 1;
//			end
//			
//			if (CPU_VRAM_SEL && !WE_N && !CPU_VRAM_WRITE_PEND && !CPU_VRAM_READ_PEND && CE_R) begin
//				IO_VRAM_WA <= A[18:1];
//				IO_VRAM_D <= DI;
//				IO_VRAM_WE <= ~{2{WE_N}} & ~DQM;
//				CPU_VRAM_WRITE_PEND <= 1;
//			end else if (VRAM_ST == VS_CPU_WRITE && CPU_VRAM_WRITE_PEND) begin
//				CPU_VRAM_WRITE_PEND <= 0;
//			end
//			
//			if (CPU_VRAM_SEL /*&& !VRAM_SEL_OLD*/ && !WE_N && CPU_VRAM_WRDY /*&& CPU_VRAM_WRITE_PEND && CE_F*/) begin
//				CPU_VRAM_WRDY <= 0;
//			end else if (VRAM_ST == VS_CPU_WRITE && !CPU_VRAM_WRDY) begin
//				CPU_VRAM_WRDY <= 1;
//			end
//			
////			if (!CPU_VRAM_RDY) CPU_VRAM_RDY_CNT <= CPU_VRAM_RDY_CNT + 1'd1;
////			else CPU_VRAM_RDY_CNT <= '0;
//		end
//	end


	//Registers
	wire REG_REQ = (A[20:19] == 2'b10) & ~DTEN_N & ~AD_N & ~CS_N & ~REQ_N;
	
	assign MODR = {4'h0,3'b000,PTMR.PTM[1],FBCR.EOS,FBCR.DIE,FBCR.DIL,FBCR.FCM,TVMR.VBE,TVMR.TVM};
	
	bit [15:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		bit        VTIM_N_OLD;
		bit        FRAME_ERASECHANGE_PEND;
		bit        START_DRAW_PEND;
		
		if (!RST_N) begin
			TVMR <= '0;
			FBCR <= '0;
			PTMR <= '0;
			EWDR <= '0;
			EWLR <= 16'h0000;
			EWRR <= 16'h4EFF;
			EDSR <= '0;
			IRQ_N <= 1;
			
			REG_DO <= '0;
//			A <= '0;
//			WE_N <= 1;
//			DQM <= '1;
//			BURST <= 0;
			
			FRAME_ERASECHANGE_PEND <= 0;
			FRAME_ERASE <= 0;
			VBLANK_ERASE <= 0;
			DRAW_TERMINATE <= 0;
			
//			FRAME <= 0;
			FRAMES_DBG <= '0;
			START_DRAW_CNT <= '0;
		end else if (!RES_N) begin
				
		end else begin
//			if (!CS_N && DTEN_N && AD_N && CE_R) begin
//				if (!DI[15]) begin
//					A[20:9] <= DI[11:0];
//					WE_N <= DI[14];
//					BURST <= DI[13];
//				end else begin
//					A[8:1] <= DI[7:0];
//					DQM <= DI[13:12];
//				end
//			end else if (!CS_N && !DTEN_N && !AD_N && BURST && CE_R) begin
//				if ((CPU_VRAM_SEL && CPU_VRAM_RRDY && CPU_VRAM_WRDY) || CPU_FB_SEL || REG_REQ) begin
//					A <= A + 20'd1;
//				end
//			end
			
			START_DRAW_PEND <= 0;
			DRAW_TERMINATE <= 0;
			if (REG_REQ) begin
				if (!WE_N) begin
					case ({A[5:1],1'b0})
						5'h00: TVMR <= DI & TVMR_MASK;
						5'h02: FBCR <= DI & FBCR_MASK;
						5'h04: PTMR <= DI & PTMR_MASK;
						5'h06: EWDR <= DI & EWDR_MASK;
						5'h08: EWLR <= DI & EWLR_MASK;
						5'h0A: EWRR <= DI & EWRR_MASK;
						default:;
					endcase
					if (A[5:1] == 5'h00>>1 && DI[3]) VBLANK_ERASE <= 1;
					if (A[5:1] == 5'h02>>1 && DI[1]) FRAME_ERASECHANGE_PEND <= 1;
					if (A[5:1] == 5'h04>>1 && DI[1:0] == 2'b01) begin START_DRAW_PEND <= 1; START_DRAW_CNT <= START_DRAW_CNT + 8'd1; end
					if (A[5:1] == 5'h0C>>1 && DI[1]) DRAW_TERMINATE <= 1;
				end else begin
					case ({A[5:1],1'b0})
						5'h10: REG_DO <= EDSR & EDSR_MASK;
						5'h12: REG_DO <= LOPR & LOPR_MASK;
						5'h14: REG_DO <= COPR & COPR_MASK;
						5'h16: REG_DO <= MODR & MODR_MASK;
						default: REG_DO <= '0;
					endcase
				end
			end
			
			VTIM_N_OLD <= VTIM_N;
			if (VTIM_N && !VTIM_N_OLD) begin
				FRAMES_DBG <= FRAMES_DBG + 8'd1;
			end
			
			if (CMD_ST == CMDS_END && CMD.CMDCTRL.END /*&& !EDSR.CEF*/) begin
				EDSR.CEF <= 1;
				IRQ_N <= 0;
//				FRAMES_DBG <= 16'd0;
			end

			FRAME_START <= 0;
			if (START_DRAW_PEND) begin
				FRAME_START <= 1;
				EDSR.CEF <= 0;
				EDSR.BEF <= EDSR.CEF;
			end else if (/*PTMR.PTM == 2'b10 &&*/ VTIM_N && !VTIM_N_OLD) begin
				FRAME_ERASE <= 0;
				VBLANK_ERASE <= 0;
				if (TVMR.VBE && FBCR.FCT && FBCR.FCM) begin
					FB_SEL <= ~FB_SEL;
					VBLANK_ERASE <= 1;
					if (PTMR.PTM == 2'b10) begin
						FRAME_START <= 1;
					end
					EDSR.CEF <= 0;
					EDSR.BEF <= EDSR.CEF;
					FRAME_ERASECHANGE_PEND <= 0;
					FRAMES_DBG <= 8'd0;
				end else if (!FBCR.FCM) begin
					FB_SEL <= ~FB_SEL;
					FRAME_ERASE <= 1;
					if (PTMR.PTM == 2'b10) begin
						FRAME_START <= 1;
					end
					EDSR.CEF <= 0;
					EDSR.BEF <= EDSR.CEF;
					FRAMES_DBG <= 8'd0;
				end else if (FRAME_ERASECHANGE_PEND && FBCR.FCT) begin
					FB_SEL <= ~FB_SEL;
					if (PTMR.PTM == 2'b10) begin
						FRAME_START <= 1;
					end
					EDSR.CEF <= 0;
					EDSR.BEF <= EDSR.CEF;
					FRAME_ERASECHANGE_PEND <= 0;
					FRAMES_DBG <= 8'd0;
				end else if (FRAME_ERASECHANGE_PEND && !FBCR.FCT) begin
					FRAME_ERASE <= 1;
					FRAME_ERASECHANGE_PEND <= 0;
				end
//				FRAME <= 1;//~FRAME;
			end
			
			if (!IRQ_N && CE_R) IRQ_N <= 1;
		end
	end
	
	assign DO = A[20] ? REG_DO : IO_VRAM_DO;
	assign RDY_N = ~CPU_VRAM_RRDY | ~CPU_VRAM_WRDY;//~((CPU_VRAM_SEL & CPU_VRAM_RRDY & CPU_VRAM_WRDY) | CPU_FB_SEL | REG_SEL);
	
//	assign IRQ_N = ~EDSR.CEF;
	
endmodule
