module VDP1 (
	input              CLK,
	input              RST_N,
	input              CE_R,
	input              CE_F,
	input              EN,
	
	input              RES_N,

	input      [15: 0] DI,
	output     [15: 0] DO,
	input              CS_N,
	input              AD_N,
	input              DTEN_N,
	input              REQ_N,
	output             RDY_N,
	
	output             IRQ_N,
	
	input              DCE_R,
	input              DCE_F,
	input              HTIM_N,
	input              VTIM_N,
	output     [15: 0] VOUT,
	
	output reg [18: 1] VRAM_A,
	output reg [15: 0] VRAM_D,
	input      [15: 0] VRAM_Q,
	output reg [ 1: 0] VRAM_WE,
	output reg         VRAM_RD,
	input              VRAM_RDY,
	
	output     [17: 1] FB0_A,
	output     [15: 0] FB0_D,
	input      [15: 0] FB0_Q,
	output     [ 1: 0] FB0_WE,
	output             FB0_RD,
	
	output     [17: 1] FB1_A,
	output     [15: 0] FB1_D,
	input      [15: 0] FB1_Q,
	output     [ 1: 0] FB1_WE,
	output             FB1_RD,
	input              FB_RDY,
	
	input      [ 7: 0] DBG_EXT
	
`ifdef DEBUG
	                   ,
	output             DBG_START,
	output             DBG_CMD_END,
	output     [18: 1] DBG_SPR_ADDR,
	output             DBG_LINE_DRAW_STEP,
	output             DBG_TEXT_READ_STEP,
	output     [15: 0] ORIG_C_DBG,
	output     [10: 0] DRAW_X_DBG,
	output     [10: 0] DRAW_Y_DBG,
	output       RGB_t DBG_ORIG_RGB,
	output             TP_DBG,
	output             SCLIP_DBG,
	output             UCLIP_DBG,
	output             DBG_LINE_OVER,
	output             DBG_DRAW_OVER,
	output     [ 7: 0] FRAMES_DBG,
	output     [ 7: 0] START_DRAW_CNT,
	output     [18: 1] DBG_CMD_ADDR16,
	output     [18: 1] DBG_CMD_ADDR_LAST,
	output   CMDSRCA_t DBG_CMD_CMDSRCA_LAST,
	output     [ 7: 0] DBG_CMD_CNT,
	output     [ 7: 0] DBG_CMD_WAIT_CNT,
	output             DBG_CMD_ADDR_ERR,
	output       RGB_t DBG_GHCOLOR_C,
	output       RGB_t DBG_GHCOLOR_D
`endif
);
	import VDP1_PKG::*;
	
	TVMR_t       TVMR;
	FBCR_t       FBCR;
	PTMR_t       PTMR;
	EWDR_t       EWDR;
	EWLR_t       EWLR;
	EWRR_t       EWRR;
	EDSR_t       EDSR;
	LOPR_t       LOPR;
	COPR_t       COPR;
	MODR_t       MODR;
	bit          DIE,DIL;

	bit          FRAME_START;
	bit          FRAME_ERASE;
	bit          VBLANK_ERASE;
	bit          FRAME_ERASE_HIT;
	bit          VBLANK_ERASE_HIT;
	bit          DRAW_TERMINATE;
	bit          DRAW_END;
	
	//Color lookup table
	bit          CLT_WE;
	bit  [ 3: 0] CLT_RA;
	bit  [15: 0] CLT_Q;
	
	//Frame buffers
	bit          FB_SEL;
	bit  [15: 0] FB_DRAW_Q;
	bit          FB_DRAW_WAIT;
	bit  [17: 1] FB_DISP_A;
	bit          FB_DISP_WE;
	bit  [15: 0] FB_DISP_Q;
	bit  [17: 1] FB_ERASE_A;
//	bit          FRAME;
	wire         FB_ERASE_WE = (FRAME_ERASE_HIT & DCE_R) | (VBLANK_ERASE_HIT & CE_R);
	
	assign FB0_A  = FB_SEL ? FB_A                                        : (VBLANK_ERASE_HIT ? FB_ERASE_A : FB_DISP_A);
	assign FB1_A  = FB_SEL ? (VBLANK_ERASE_HIT ? FB_ERASE_A : FB_DISP_A) : FB_A;
	assign FB0_D  = FB_SEL ? FB_D                                        : EWDR;
	assign FB1_D  = FB_SEL ? EWDR                                        : FB_D;
	assign FB0_WE = FB_SEL ? FB_WE /*& CE_R*/                            : {2{FB_ERASE_WE}};
	assign FB1_WE = FB_SEL ? {2{FB_ERASE_WE}}                            : FB_WE /*& CE_R*/;
	assign FB0_RD = FB_SEL ? FB_RD                                       : 1'b0;
	assign FB1_RD = FB_SEL ? 1'b0                                        : FB_RD;
	
	assign FB_DRAW_Q = FB_SEL ? FB0_Q : FB1_Q;
	assign FB_DISP_Q = FB_SEL ? FB1_Q : FB0_Q;
	
	
	typedef enum bit [3:0] {
		VS_IDLE,  
		VS_CPU_WRITE,
		VS_CPU_READ,
		VS_CMD_READ,
		VS_CMD_END,
		VS_PAT_READ,
		VS_CLT_READ,
		VS_CLT_END,
		VS_GRD_READ,
		VS_GRD_END
	} VRAMState_t;
	VRAMState_t VRAM_ST;

	bit  [15: 0] VRAM_DATA;
	bit          VRAM_DONE;
	
	typedef enum bit [2:0] {
		FS_IDLE,  
		FS_CPU_WRITE,
		FS_CPU_WAIT,
		FS_CPU_READ,
		FS_DRAW
	} FBState_t;
	FBState_t FB_ST;
	bit  [17: 1] FB_A;
	bit  [15: 0] FB_D;
	bit  [ 1: 0] FB_WE;
	bit          FB_RD;
	
	typedef enum bit [4:0] {
		CMDS_IDLE,  
		CMDS_READ, 
		CMDS_GRD_LOAD,
		CMDS_EXEC,
		CMDS_CLT_LOAD,
		CMDS_GRD_CALC_LEFT,
		CMDS_GRD_CALC_RIGHT,
		CMDS_GRD_CALC_LINE,
		CMDS_NSPR_START,
		CMDS_NSPR_CALCY,
		CMDS_NSPR_CALCX,
		CMDS_NSPR_DRAW,
		CMDS_SSPR_START,
		CMDS_SSPR_CALCY,
		CMDS_SSPR_CALCX,
		CMDS_SSPR_DRAW,
		CMDS_DSPR_START,
		CMDS_POLYGON_START,
		CMDS_POLYGON_CALCD,
		CMDS_POLYGON_CALCTDY,
		CMDS_POLYLINE_START,
		CMDS_LINE_START,
		CMDS_LINE_CALC,
		CMDS_LINE_CALCD,
		CMDS_LINE_DRAW,
		CMDS_AA_DRAW,
		CMDS_LINE_END,
		CMDS_LINE_NEXT,
		CMDS_END
	} CMDState_t;
	CMDState_t CMD_ST;
	bit  [18: 1] CMD_ADDR;
	bit          CMD_READ;
	bit  [ 3: 0] CMD_POS;
	bit  [18: 1] SPR_ADDR;
	bit          SPR_READ;
	bit  [15: 0] SPR_DATA;
	bit          SPR_DATA_READY;
	bit  [18: 1] CLT_ADDR;
	bit          CLT_READ;
	bit  [ 3: 0] CLT_POS;
	bit  [18: 1] GRD_ADDR;
	bit          GRD_READ;
	bit  [ 1: 0] GRD_POS;
	bit  [15: 0] GRD_TBL[4];
	
	CMDTBL_t     CMD;
	Clip_t       SYS_CLIP;
	Clip_t       USR_CLIP;
	Coord_t      LOC_COORD;
	Pattern_t    PAT;
	bit  [ 8: 0] TEXT_X;
	bit  [ 7: 0] TEXT_Y;
	bit  [ 8: 0] TEXT_DX;
	bit  [ 8: 0] TEXT_SX;
	bit  [ 1: 0] TEXT_MASK;
	bit  [16: 3] SPR_OFFSY;
	bit  [10: 0] POLY_LSX;
	bit  [10: 0] POLY_LSY;
	bit  [10: 0] POLY_RSX;
	bit  [10: 0] POLY_RSY;
	bit  [11: 0] POLY_LDX;
	bit  [11: 0] POLY_LDY;
	bit  [11: 0] POLY_RDX;
	bit  [11: 0] POLY_RDY;
	bit  [ 1: 0] POLY_S;
	bit          POLY_LDIRX;
	bit          POLY_LDIRY;
	bit          POLY_RDIRX;
	bit          POLY_RDIRY;
	
	Vertex_t     LINE_VERTA;
	Vertex_t     LINE_VERTB;
	Vertex_t     LINE_VERTA_SAVE;
	Vertex_t     LEFT_VERT;
	Vertex_t     RIGHT_VERT;
	Vertex_t     BOTTOM_VERT;
	bit  [10: 0] ORIG_WIDTH;
	bit  [10: 0] ORIG_HEIGHT;
	bit  [10: 0] LINE_SX;
	bit  [10: 0] LINE_SY;
	bit          LINE_DIRX;
	bit          LINE_DIRY;
	bit          LINE_S;
	bit  [11: 0] LINE_D,ROW_D,COL_D;
	bit  [10: 0] ROW_WIDTH,COL_HEIGHT;
	bit          COL_DIRY;
	bit          SPR_ROW_ENLARGE,SPR_COL_ENLARGE;
	bit  [10: 0] AA_X;
	bit  [10: 0] AA_Y;
	bit          AA;
	bit  [ 1: 0] DIR;
	bit          DRAW_WAIT;
	bit          DRAW_ENABLE;
	
	bit          LINE_DRAW_STEP;
	bit          COL_DRAW_STEP;
	bit          TEXT_READ_STEP;
	bit          TEXTY_READ_STEP;
	bit  [11: 0] NEXT_ROW_D,NEXT_COL_D;
	bit  [ 3: 0] GRD_CALC_STEP;
	always_comb begin
		LINE_DRAW_STEP = 0;
		COL_DRAW_STEP = 0;
		TEXT_READ_STEP = 0;
		TEXTY_READ_STEP = 0;
		NEXT_ROW_D = '0;
		NEXT_COL_D = '0;
		case (CMD_ST) 
			CMDS_NSPR_DRAW: begin		
				LINE_DRAW_STEP = 1;		
				TEXT_READ_STEP = 1;
			end
				
			CMDS_SSPR_DRAW: begin
				if (SPR_ROW_ENLARGE) begin
					LINE_DRAW_STEP = 1;
					
					NEXT_ROW_D = ROW_D + {1'b0,ORIG_WIDTH};
					if (NEXT_ROW_D >= {1'b0,ROW_WIDTH}) begin
						NEXT_ROW_D = ROW_D + {1'b0,ORIG_WIDTH} - {1'b0,ROW_WIDTH};
						TEXT_READ_STEP = 1;
					end
				end else begin
					NEXT_ROW_D = ROW_D + {1'b0,ROW_WIDTH};
					if (NEXT_ROW_D >= {1'b0,ORIG_WIDTH}) begin
						NEXT_ROW_D = ROW_D + {1'b0,ROW_WIDTH} - {1'b0,ORIG_WIDTH};
						LINE_DRAW_STEP = 1;
					end					
					TEXT_READ_STEP = 1;
				end
			end
			
			CMDS_LINE_DRAW: begin
				if (CMD.CMDCTRL.COMM >= 4'h4) begin
					LINE_DRAW_STEP = 1;
				end else if (SPR_ROW_ENLARGE) begin
					LINE_DRAW_STEP = 1;
					NEXT_ROW_D = ROW_D + {1'b0,ORIG_WIDTH};
					if (NEXT_ROW_D >= {1'b0,ROW_WIDTH}) begin
						NEXT_ROW_D = ROW_D + {1'b0,ORIG_WIDTH} - {1'b0,ROW_WIDTH};
						TEXT_READ_STEP = 1;
					end
				end else begin
					NEXT_ROW_D = ROW_D + {1'b0,ROW_WIDTH};
					if (NEXT_ROW_D >= {1'b0,ORIG_WIDTH}) begin
						NEXT_ROW_D = ROW_D + {1'b0,ROW_WIDTH} - {1'b0,ORIG_WIDTH};
						LINE_DRAW_STEP = 1;
					end
					TEXT_READ_STEP = 1;
				end
			end
			
			CMDS_AA_DRAW,
			CMDS_LINE_END: begin
				LINE_DRAW_STEP = AA;
			end
			
			CMDS_LINE_NEXT: begin
				case (CMD.CMDCTRL.COMM) 
				4'h0: begin
					COL_DRAW_STEP = 1;
					TEXTY_READ_STEP = 1;
				end
				
				4'h1: begin
					if (SPR_COL_ENLARGE) begin
						COL_DRAW_STEP = 1;
						NEXT_COL_D = COL_D + {1'b0,ORIG_HEIGHT};
						if (NEXT_COL_D >= COL_HEIGHT) begin
							NEXT_COL_D = COL_D + {1'b0,ORIG_HEIGHT} - {1'b0,COL_HEIGHT};
							TEXTY_READ_STEP = 1;
						end
					end else begin
						NEXT_COL_D = COL_D + {1'b0,COL_HEIGHT};
						if (NEXT_COL_D > ORIG_HEIGHT) begin
							NEXT_COL_D = COL_D + {1'b0,COL_HEIGHT} - {1'b0,ORIG_HEIGHT};
							COL_DRAW_STEP = 1;
						end
						TEXTY_READ_STEP = 1;
					end
				end
				
				4'h2,
				4'h3: begin
					if (SPR_COL_ENLARGE) begin
						COL_DRAW_STEP = 1;
						NEXT_COL_D = COL_D + {1'b0,ORIG_HEIGHT};
						if (NEXT_COL_D >= COL_HEIGHT) begin
							NEXT_COL_D = COL_D + {1'b0,ORIG_HEIGHT} - {1'b0,COL_HEIGHT};
							TEXTY_READ_STEP = 1;
						end
					end else begin
						NEXT_COL_D = COL_D + {1'b0,COL_HEIGHT};
						if (NEXT_COL_D > ORIG_HEIGHT) begin
							NEXT_COL_D = COL_D + {1'b0,COL_HEIGHT} - {1'b0,ORIG_HEIGHT};
							COL_DRAW_STEP = 1;
						end
						TEXTY_READ_STEP = 1;
					end
				end
				
				4'h4: begin
					COL_DRAW_STEP = 1;
				end
				
				default:;
				endcase
			end

			default:;
		endcase
	end
	
	wire TEXT_DIRX = (CMD.CMDCTRL.DIR[0] ^ DIR[0]);
	wire TEXT_DIRY = (CMD.CMDCTRL.DIR[1] ^ DIR[1]);
	
	RGB_t        GHCOLOR_A,GHCOLOR_B,GHCOLOR_C,GHCOLOR_D;
	RGB_t        LEFT_GHCOLOR,RIGHT_GHCOLOR,LINE_GHCOLOR;
	bit  [15: 0] LEFT_GHCOLOR_DR,LEFT_GHCOLOR_DG,LEFT_GHCOLOR_DB;//5.11 unsigned
	bit  [15: 0] RIGHT_GHCOLOR_DR,RIGHT_GHCOLOR_DG,RIGHT_GHCOLOR_DB;//5.11 unsigned
	bit  [15: 0] LINE_GHCOLOR_DR,LINE_GHCOLOR_DG,LINE_GHCOLOR_DB;//5.11 unsigned
	bit          LEFT_GHCOLOR_DIRR,LEFT_GHCOLOR_DIRG,LEFT_GHCOLOR_DIRB;
	bit          RIGHT_GHCOLOR_DIRR,RIGHT_GHCOLOR_DIRG,RIGHT_GHCOLOR_DIRB;
	bit          LINE_GHCOLOR_DIRR,LINE_GHCOLOR_DIRG,LINE_GHCOLOR_DIRB;
	bit  [10: 0] LEFT_GHCOLOR_FR,LEFT_GHCOLOR_FG,LEFT_GHCOLOR_FB;
	bit  [10: 0] RIGHT_GHCOLOR_FR,RIGHT_GHCOLOR_FG,RIGHT_GHCOLOR_FB;
	bit  [10: 0] LINE_GHCOLOR_FR,LINE_GHCOLOR_FG,LINE_GHCOLOR_FB;
	
	assign GHCOLOR_A = GRD_TBL[0][14:0];
	assign GHCOLOR_B = GRD_TBL[1][14:0];
	assign GHCOLOR_C = GRD_TBL[2][14:0];
	assign GHCOLOR_D = GRD_TBL[3][14:0];
	
	bit  [15:11] GHCOLOR_DIV_A;//5.0 unsigned
	bit  [10: 0] GHCOLOR_DIV_B;//11.0 unsigned
	bit  [15: 0] GHCOLOR_DELTA;//5.11 unsigned
	VDP1_DIV DIV(.numer({GHCOLOR_DIV_A,11'b00000000000}), .denom(GHCOLOR_DIV_B), .quotient(GHCOLOR_DELTA));
	
`ifdef DEBUG
	assign DBG_GHCOLOR_C = GRD_TBL[2][14:0];
	assign DBG_GHCOLOR_D = GRD_TBL[3][14:0];
	assign DBG_LINE_DRAW_STEP = LINE_DRAW_STEP;
	assign DBG_TEXT_READ_STEP = TEXT_READ_STEP;
`endif
	
	always @(posedge CLK or negedge RST_N) begin
//	   bit         FRAME_START_PEND;
		bit [18: 1] NEXT_ADDR;
		bit [18: 1] CMD_RET_ADDR;
		bit         CMD_SUB_RUN;
		bit [11: 0] NEXT_LINE_D;
		bit         LINE_VERTA_NEXT;
		bit [11: 0] NEW_LINE_SX;
		bit [11: 0] NEW_LINE_SY;
		bit [10: 0] NEW_LINE_ASX;
		bit [10: 0] NEW_LINE_ASY;
		bit [11: 0] NEW_POLY_LSX;
		bit [11: 0] NEW_POLY_LSY;
		bit [11: 0] NEW_POLY_RSX;
		bit [11: 0] NEW_POLY_RSY;
		bit [11: 0] NEXT_POLY_LDX;
		bit [11: 0] NEXT_POLY_LDY;
		bit [11: 0] NEXT_POLY_RDX;
		bit [11: 0] NEXT_POLY_RDY;
		bit         EC_FIND;
		bit [10: 0] SSPR_WIDTH_ABS,SSPR_HEIGHT_ABS;
		bit         SSPR_DIRX,SSPR_DIRY;
		bit         GHCOLOR_DIR;
		bit [10: 0] SYS_CLIP_X1,SYS_CLIP_X2,SYS_CLIP_Y1,SYS_CLIP_Y2;
		bit [ 3: 0] CMD_COORD_LEFT_OVER,CMD_COORD_RIGHT_OVER,CMD_COORD_TOP_OVER,CMD_COORD_BOTTOM_OVER;
		bit         CMD_NSPR_LEFT_OVER,CMD_NSPR_TOP_OVER;
		bit         CMD_SSPR_WIDTH_OVER,CMD_SSPR_HEIGHT_OVER;
		bit         CMD_SSPR_LEFT_OVER,CMD_SSPR_TOP_OVER;
		bit         LINE_LEFT_OVER,LINE_RIGHT_OVER,LINE_TOP_OVER,LINE_BOTTOM_OVER;
		bit         CMD_TEXT_SIZE_OVER;
		
		if (!RST_N) begin
			CMD_ST <= CMDS_IDLE;
			CMD_ADDR <= '0;
			CMD_READ <= 0;
			SPR_READ <= 0;
			CLT_READ <= 0;
			GRD_READ <= 0;
			SYS_CLIP <= CLIP_NULL;
			USR_CLIP <= CLIP_NULL;
			LOC_COORD <= COORD_NULL;
			CMD_SUB_RUN <= 0;
			
			LOPR <= '0;
			COPR <= '0;
		end else if (FRAME_START) begin
			CMD_ADDR <= '0;
			CMD_READ <= 1;
			SPR_READ <= 0;
			CLT_READ <= 0;
			GRD_READ <= 0;
			CMD_SUB_RUN <= 0;
			CMD_ST <= CMDS_READ;
		end else if (DRAW_TERMINATE) begin
			CMD_READ <= 0;
			SPR_READ <= 0;
			CLT_READ <= 0;
			GRD_READ <= 0;
			CMD_ST <= CMDS_IDLE;
		end else if (EN) begin
			case (CMD.CMDPMOD.CM)
				3'b000,
				3'b001: begin TEXT_DX = 9'h001; TEXT_SX <= {2'b00,CMD.CMDSIZE.SX,1'b0}; TEXT_MASK = 2'b00; end
				3'b010,
				3'b011,
				3'b100: begin TEXT_DX = 9'h002; TEXT_SX <= {1'b0,CMD.CMDSIZE.SX,2'b00}; TEXT_MASK = 2'b01; end
				default:begin TEXT_DX = 9'h004; TEXT_SX <= {CMD.CMDSIZE.SX,3'b000}; TEXT_MASK = 2'b11; end
			endcase

			SYS_CLIP_X1 <= 11'd0 - $signed(LOC_COORD.X);
			SYS_CLIP_Y1 <= 11'd0 - $signed(LOC_COORD.Y);
			SYS_CLIP_X2 <= $signed(SYS_CLIP.X2) - $signed(LOC_COORD.X);
			SYS_CLIP_Y2 <= $signed(SYS_CLIP.Y2) - $signed(LOC_COORD.Y);
			
			
			CMD_COORD_LEFT_OVER   <= {$signed(CMD.CMDXD) < $signed({{5{SYS_CLIP_X1[10]}},SYS_CLIP_X1}),
			                          $signed(CMD.CMDXC) < $signed({{5{SYS_CLIP_X1[10]}},SYS_CLIP_X1}), 
			                          $signed(CMD.CMDXB) < $signed({{5{SYS_CLIP_X1[10]}},SYS_CLIP_X1}), 
			                          $signed(CMD.CMDXA) < $signed({{5{SYS_CLIP_X1[10]}},SYS_CLIP_X1})};
			CMD_COORD_RIGHT_OVER  <= {$signed(CMD.CMDXD) > $signed({{5{SYS_CLIP_X2[10]}},SYS_CLIP_X2}),
			                          $signed(CMD.CMDXC) > $signed({{5{SYS_CLIP_X2[10]}},SYS_CLIP_X2}), 
			                          $signed(CMD.CMDXB) > $signed({{5{SYS_CLIP_X2[10]}},SYS_CLIP_X2}), 
			                          $signed(CMD.CMDXA) > $signed({{5{SYS_CLIP_X2[10]}},SYS_CLIP_X2})};
			CMD_COORD_TOP_OVER    <= {$signed(CMD.CMDYD) < $signed({{5{SYS_CLIP_Y1[10]}},SYS_CLIP_Y1}),
								           $signed(CMD.CMDYC) < $signed({{5{SYS_CLIP_Y1[10]}},SYS_CLIP_Y1}),
								           $signed(CMD.CMDYB) < $signed({{5{SYS_CLIP_Y1[10]}},SYS_CLIP_Y1}),
								           $signed(CMD.CMDYA) < $signed({{5{SYS_CLIP_Y1[10]}},SYS_CLIP_Y1})};
			CMD_COORD_BOTTOM_OVER <= {$signed(CMD.CMDYD) > $signed({{5{SYS_CLIP_Y2[10]}},SYS_CLIP_Y2}),
								           $signed(CMD.CMDYC) > $signed({{5{SYS_CLIP_Y2[10]}},SYS_CLIP_Y2}),
								           $signed(CMD.CMDYB) > $signed({{5{SYS_CLIP_Y2[10]}},SYS_CLIP_Y2}),
								           $signed(CMD.CMDYA) > $signed({{5{SYS_CLIP_Y2[10]}},SYS_CLIP_Y2})};
											  
			CMD_NSPR_LEFT_OVER <= $signed(CMD.CMDXA) + $signed({7'h00,CMD.CMDSIZE.SX,3'b000}) < $signed({{5{SYS_CLIP_X1[10]}},SYS_CLIP_X1});
			CMD_NSPR_TOP_OVER  <= $signed(CMD.CMDYA) + $signed({8'h00,CMD.CMDSIZE.SY}) < $signed({{5{SYS_CLIP_Y1[10]}},SYS_CLIP_Y1});
			
			CMD_SSPR_LEFT_OVER <= $signed(CMD.CMDXA) + $signed(CMD.CMDXB) < $signed({{5{SYS_CLIP_X1[10]}},SYS_CLIP_X1});
			CMD_SSPR_TOP_OVER  <= $signed(CMD.CMDYA) + $signed(CMD.CMDYB) < $signed({{5{SYS_CLIP_Y1[10]}},SYS_CLIP_Y1});
												
			CMD_SSPR_WIDTH_OVER <= (CMD.CMDXB.COORD[10] && CMD.CMDCTRL.ZP);
			CMD_SSPR_HEIGHT_OVER <= (CMD.CMDYB.COORD[10] && CMD.CMDCTRL.ZP);
												
			CMD_TEXT_SIZE_OVER <= !CMD.CMDSIZE.SX || !CMD.CMDSIZE.SY;
											  
			LINE_LEFT_OVER = ($signed(LEFT_VERT.X) < $signed(SYS_CLIP_X1) && $signed(RIGHT_VERT.X) < $signed(SYS_CLIP_X1));
			LINE_RIGHT_OVER = ($signed(LEFT_VERT.X) > $signed(SYS_CLIP_X2) && $signed(RIGHT_VERT.X) > $signed(SYS_CLIP_X2));
			LINE_TOP_OVER = ($signed(LEFT_VERT.Y) < $signed(SYS_CLIP_Y1) && $signed(RIGHT_VERT.Y) < $signed(SYS_CLIP_Y1));
			LINE_BOTTOM_OVER = ($signed(LEFT_VERT.Y) > $signed(SYS_CLIP_Y2) && $signed(RIGHT_VERT.Y) > $signed(SYS_CLIP_Y2));

			ORIG_WIDTH = {2'b00,CMD.CMDSIZE.SX,3'b000};
			ORIG_HEIGHT <= {2'b00,CMD.CMDSIZE.SY};
									
			if (CE_R) DRAW_END <= 0;
			if (FBD_ST == FBDS_WRITE) DRAW_ENABLE <= 0;
			case (CMD_ST) 
				CMDS_IDLE: begin
				end
					
				CMDS_READ: begin
`ifdef DEBUG
					DBG_CMD_WAIT_CNT <= DBG_CMD_WAIT_CNT + 1'd1;
`endif
					CMD_READ <= 0;
					if (VRAM_DONE) begin
						case (CMD_POS)
							4'h0: CMD.CMDCTRL <= VRAM_DATA;
							4'h1: CMD.CMDLINK <= VRAM_DATA;
							4'h2: CMD.CMDPMOD <= VRAM_DATA;
							4'h3: CMD.CMDCOLR <= VRAM_DATA;
							4'h4: CMD.CMDSRCA <= VRAM_DATA;
							4'h5: CMD.CMDSIZE <= VRAM_DATA;
							4'h6: CMD.CMDXA <= VRAM_DATA;
							4'h7: CMD.CMDYA <= VRAM_DATA;
							4'h8: CMD.CMDXB <= VRAM_DATA;
							4'h9: CMD.CMDYB <= VRAM_DATA;
							4'hA: CMD.CMDXC <= VRAM_DATA;
							4'hB: CMD.CMDYC <= VRAM_DATA;
							4'hC: CMD.CMDXD <= VRAM_DATA;
							4'hD: CMD.CMDYD <= VRAM_DATA;
							4'hE: CMD.CMDGRDA <= VRAM_DATA;
						endcase
						
						if (!CMD.CMDCTRL.JP[2] && !CMD.CMDCTRL.END) begin
							case (CMD.CMDCTRL.COMM) 
								4'h0: if (CMD_POS == 4'hE) begin	//normal sprite
									if (CMD_NSPR_LEFT_OVER || CMD_NSPR_TOP_OVER || CMD_COORD_RIGHT_OVER[0] || CMD_COORD_BOTTOM_OVER[0] || CMD_TEXT_SIZE_OVER) begin
										CMD_ST <= CMDS_END;
									end else if (CMD.CMDPMOD.CCB[2]) begin
										GRD_READ <= 1;
										CMD_ST <= CMDS_GRD_LOAD;
									end else begin
										CMD_ST <= CMDS_EXEC;
									end
								end
							
								4'h1: if (CMD_POS == 4'hE) begin	//scaled sprite
									if (((CMD_COORD_LEFT_OVER[0] && CMD_COORD_LEFT_OVER[2]) || 
										  (CMD_COORD_RIGHT_OVER[0] && CMD_COORD_RIGHT_OVER[2]) ||
										  (CMD_COORD_TOP_OVER[0] && CMD_COORD_TOP_OVER[2]) || 
										  (CMD_COORD_BOTTOM_OVER[0] && CMD_COORD_BOTTOM_OVER[2]) && !CMD.CMDCTRL.ZP) ||
										 /*((CMD_SSPR_LEFT_OVER || CMD_SSPR_TOP_OVER || CMD_COORD_RIGHT_OVER[0] || CMD_COORD_BOTTOM_OVER[0]) && CMD.CMDCTRL.ZP) ||*/
										 CMD_TEXT_SIZE_OVER) begin
										CMD_ST <= CMDS_END;
									end else if (CMD.CMDPMOD.CCB[2]) begin
										GRD_READ <= 1;
										CMD_ST <= CMDS_GRD_LOAD;
									end else begin
										CMD_ST <= CMDS_EXEC;
									end
								end
								
								4'h2,
								4'h3: if (CMD_POS == 4'hE) begin	//distored sprite
									if (&CMD_COORD_LEFT_OVER || &CMD_COORD_RIGHT_OVER || &CMD_COORD_TOP_OVER || &CMD_COORD_BOTTOM_OVER || CMD_TEXT_SIZE_OVER) begin
										CMD_ST <= CMDS_END;
									end else if (CMD.CMDPMOD.CCB[2]) begin
										GRD_READ <= 1;
										CMD_ST <= CMDS_GRD_LOAD;
									end else begin
										CMD_ST <= CMDS_EXEC;
									end
								end
								
								4'h4,			//polygon
								4'h5,
								4'h7: if (CMD_POS == 4'hE) begin	//polyline
									if (&CMD_COORD_LEFT_OVER || &CMD_COORD_RIGHT_OVER || &CMD_COORD_TOP_OVER || &CMD_COORD_BOTTOM_OVER) begin
										CMD_ST <= CMDS_END;
									end else if (CMD.CMDPMOD.CCB[2]) begin
										GRD_READ <= 1;
										CMD_ST <= CMDS_GRD_LOAD;
									end else begin
										CMD_ST <= CMDS_EXEC;
									end
								end
								
								4'h6: if (CMD_POS == 4'hE) begin	//line
									if (&CMD_COORD_LEFT_OVER[1:0] || &CMD_COORD_RIGHT_OVER[1:0] || &CMD_COORD_TOP_OVER[1:0] || &CMD_COORD_BOTTOM_OVER[1:0]) begin
										CMD_ST <= CMDS_END;
									end else if (CMD.CMDPMOD.CCB[2]) begin
										GRD_READ <= 1;
										CMD_ST <= CMDS_GRD_LOAD;
									end else begin
										CMD_ST <= CMDS_EXEC;
									end
								end
							
								4'h8,
								4'hB: begin	
									if (CMD_POS == 4'h6) USR_CLIP.X1 <= {1'b0,VRAM_DATA[9:0]}; 
									if (CMD_POS == 4'h7) USR_CLIP.Y1 <= {2'b00,VRAM_DATA[8:0]}; 
									if (CMD_POS == 4'hA) USR_CLIP.X2 <= {1'b0,VRAM_DATA[9:0]};
									if (CMD_POS == 4'hB) USR_CLIP.Y2 <= {2'b00,VRAM_DATA[8:0]};
									if (CMD_POS == 4'hE) CMD_ST <= CMDS_END;
								end
								
								4'h9: begin	
									if (CMD_POS == 4'hA) SYS_CLIP.X2 <= {1'b0,VRAM_DATA[9:0]};
									if (CMD_POS == 4'hB) SYS_CLIP.Y2 <= {2'b00,VRAM_DATA[8:0]};
									if (CMD_POS == 4'hE) CMD_ST <= CMDS_END;
								end
								
								4'hA: begin	
									if (CMD_POS == 4'h6) LOC_COORD.X <= VRAM_DATA[10:0]; 
									if (CMD_POS == 4'h7) LOC_COORD.Y <= VRAM_DATA[10:0];
									if (CMD_POS == 4'hE) CMD_ST <= CMDS_END;
								end
							
								default: if (CMD_POS == 4'hE) begin	
									CMD_ST <= CMDS_END;
								end
							endcase
						end
						else begin
							if (CMD_POS == 4'hE) CMD_ST <= CMDS_END;
						end
						
						if (CMD_POS == 4'hE) begin 
							LOPR <= COPR;
							COPR <= CMD_ADDR[18:3];
`ifdef DEBUG
							DBG_CMD_WAIT_CNT <= '0;
							DBG_CMD_ADDR_ERR <= (CMD_ADDR > 18'h09000);
`endif
						end
					end
				end
				
				CMDS_GRD_LOAD: begin
					GRD_READ <= 0;
					if (VRAM_DONE) begin
						GRD_TBL[GRD_POS] <= VRAM_DATA;
						if (GRD_POS == 2'd3) begin 
							CMD_ST <= CMDS_EXEC;
						end
					end
				end
				
				CMDS_EXEC: begin
						case (CMD.CMDCTRL.COMM)
							4'h0,			//normal sprite
							4'h1,			//scaled sprite
							4'h2,
							4'h3: begin	//distored sprite
								if (CMD.CMDPMOD.CM == 3'b001) begin
									CLT_READ <= 1;
									CMD_ST <= CMDS_CLT_LOAD;
									
								end else begin
									case (CMD.CMDCTRL.COMM) 
										4'h0: CMD_ST <= CMDS_NSPR_START;
										4'h1: CMD_ST <= CMDS_SSPR_START;
										default: CMD_ST <= CMDS_DSPR_START;
									endcase
								end
							end
							
							4'h4: begin	//polygon
								CMD_ST <= CMDS_POLYGON_START;
							end
							
							4'h5,
							4'h7: begin	//polyline
								CMD_ST <= CMDS_POLYLINE_START;
							end
							
							4'h6: begin	//line
								CMD_ST <= CMDS_LINE_START;
							end
							
							default: begin	
								CMD_ST <= CMDS_END;
							end
						endcase
`ifdef DEBUG
						if (DBG_CMD_CNT == 16) begin
							DBG_CMD_ADDR16 <= CMD_ADDR;
						end
`endif
				end
				
				CMDS_CLT_LOAD: begin
					CLT_READ <= 0;
					if (VRAM_DONE) begin
						if (CLT_POS == 4'd15) begin 
							case (CMD.CMDCTRL.COMM) 
								4'h0: CMD_ST <= CMDS_NSPR_START;
								4'h1: CMD_ST <= CMDS_SSPR_START;
								default: CMD_ST <= CMDS_DSPR_START;
							endcase
						end
					end
				end
				
				CMDS_NSPR_START: begin
					LEFT_VERT.X <= CMD.CMDXA.COORD;
					LEFT_VERT.Y <= CMD.CMDYA.COORD;
					RIGHT_VERT.X <= CMD.CMDXA.COORD + {2'b00,CMD.CMDSIZE.SX,3'b000} - 11'd1;
					RIGHT_VERT.Y <= CMD.CMDYA.COORD;
					BOTTOM_VERT.Y <= CMD.CMDYA.COORD + {3'b000,CMD.CMDSIZE.SY} - 11'd1;
					TEXT_X <= '0;
					TEXT_Y <= '0;
					DIR[1] <= 0;
					ROW_WIDTH <= {2'b00,CMD.CMDSIZE.SX,3'b000};
					COL_HEIGHT <= {3'b000,CMD.CMDSIZE.SY};
					COL_DIRY <= 0;
					COL_D <= '0;
					SPR_COL_ENLARGE <= 0;
					CMD_ST <= CMDS_NSPR_CALCY;
				end
				
				CMDS_NSPR_CALCY: begin
//					if (ORIG_HEIGHT <= COL_HEIGHT) begin
//						SPR_COL_ENLARGE <= 1;
//						COL_D <= {2'b00,ORIG_HEIGHT[10:1]};
//					end else begin
//						SPR_COL_ENLARGE <= 0;
//						COL_D <= {2'b00,COL_HEIGHT[10:1]};
//					end
					SPR_OFFSY <= TEXT_DIRY ? (CMD.CMDSIZE.SY - 8'd1) * CMD.CMDSIZE.SX : '0;
					GRD_CALC_STEP <= '0;
					CMD_ST <= CMD.CMDPMOD.CCB[2] ? CMDS_GRD_CALC_LEFT : CMDS_NSPR_CALCX;
				end
				
				CMDS_SSPR_START: begin
					SSPR_DIRX = ~($signed(CMD.CMDXC.COORD) >= $signed(CMD.CMDXA.COORD));
					SSPR_DIRY = ~($signed(CMD.CMDYC.COORD) >= $signed(CMD.CMDYA.COORD));
					SSPR_WIDTH_ABS = CMD.CMDXB.COORD[10] ? 10'd0 - $signed(CMD.CMDXB.COORD) : CMD.CMDXB.COORD;
					SSPR_HEIGHT_ABS = CMD.CMDYB.COORD[10] ? 10'd0 - $signed(CMD.CMDYB.COORD) : CMD.CMDYB.COORD;
					case (CMD.CMDCTRL.ZP[1:0])
						2'b00: begin 
							LEFT_VERT.X <= CMD.CMDXA.COORD; 
							RIGHT_VERT.X <= CMD.CMDXC.COORD;
							DIR[0] <= SSPR_DIRX;
							ROW_WIDTH <= !SSPR_DIRX ? $signed(CMD.CMDXC.COORD) - $signed(CMD.CMDXA.COORD) + 11'd1 : $signed(CMD.CMDXA.COORD) - $signed(CMD.CMDXC.COORD) + 11'd1;
						end
						2'b01: begin 
							LEFT_VERT.X <= CMD.CMDXA.COORD; 
							RIGHT_VERT.X <= CMD.CMDXA.COORD + CMD.CMDXB.COORD;
							DIR[0] <= CMD.CMDXB.COORD[10];
							ROW_WIDTH <= SSPR_WIDTH_ABS + 11'd1;
						end
						2'b10: begin 
							LEFT_VERT.X <= CMD.CMDXA.COORD - {CMD.CMDXB.COORD[10],CMD.CMDXB.COORD[10:1]};
							RIGHT_VERT.X <= CMD.CMDXA.COORD + {CMD.CMDXB.COORD[10],CMD.CMDXB.COORD[10:1]} + {10'h000,CMD.CMDXB.COORD[0]};
							DIR[0] <= CMD.CMDXB.COORD[10];
							ROW_WIDTH <= SSPR_WIDTH_ABS + 11'd1;
						end
						2'b11: begin 
							LEFT_VERT.X <= CMD.CMDXA.COORD - CMD.CMDXB.COORD;
							RIGHT_VERT.X <= CMD.CMDXA.COORD;
							DIR[0] <= CMD.CMDXB.COORD[10];
							ROW_WIDTH <= SSPR_WIDTH_ABS + 11'd1;
						end
					endcase
					case (CMD.CMDCTRL.ZP[3:2])
						2'b00: begin 
							LEFT_VERT.Y <= CMD.CMDYA.COORD; 
							RIGHT_VERT.Y <= CMD.CMDYA.COORD;
							BOTTOM_VERT.Y <= CMD.CMDYC.COORD;
							COL_DIRY <= SSPR_DIRY;
							COL_HEIGHT <= !SSPR_DIRY ? $signed(CMD.CMDYC.COORD) - $signed(CMD.CMDYA.COORD) + 11'd1 : $signed(CMD.CMDYA.COORD) - $signed(CMD.CMDYC.COORD) + 11'd1;
							DIR[1] <= SSPR_DIRY;
						end
						2'b01: begin 
							LEFT_VERT.Y <= CMD.CMDYA.COORD; 
							RIGHT_VERT.Y <= CMD.CMDYA.COORD;
							BOTTOM_VERT.Y <= CMD.CMDYA.COORD + CMD.CMDYB.COORD;
							COL_DIRY <= CMD.CMDYB.COORD[10];
							COL_HEIGHT <= SSPR_HEIGHT_ABS + 11'd1;
							DIR[1] <= CMD.CMDYB.COORD[10];
						end
						2'b10: begin 
							LEFT_VERT.Y <= CMD.CMDYA.COORD - {CMD.CMDYB.COORD[10],CMD.CMDYB.COORD[10:1]};
							RIGHT_VERT.Y <= CMD.CMDYA.COORD - {CMD.CMDYB.COORD[10],CMD.CMDYB.COORD[10:1]};
							BOTTOM_VERT.Y <= CMD.CMDYA.COORD + {CMD.CMDYB.COORD[10],CMD.CMDYB.COORD[10:1]} + {10'h000,CMD.CMDYB.COORD[0]};
							COL_DIRY <= CMD.CMDYB.COORD[10];
							COL_HEIGHT <= SSPR_HEIGHT_ABS + 11'd1;
							DIR[1] <= CMD.CMDYB.COORD[10];
						end
						2'b11: begin 
							LEFT_VERT.Y <= CMD.CMDYA.COORD - CMD.CMDYB.COORD;
							RIGHT_VERT.Y <= CMD.CMDYA.COORD - CMD.CMDYB.COORD;
							BOTTOM_VERT.Y <= CMD.CMDYA.COORD;
							COL_DIRY <= CMD.CMDYB.COORD[10];
							COL_HEIGHT <= SSPR_HEIGHT_ABS + 11'd1;
							DIR[1] <= CMD.CMDYB.COORD[10];
						end
					endcase
					TEXT_X <= '0;
					TEXT_Y <= '0;
					CMD_ST <= CMDS_SSPR_CALCY;
				end
				
				CMDS_SSPR_CALCY: begin
					if (ORIG_HEIGHT <= COL_HEIGHT) begin
						SPR_COL_ENLARGE <= 1;
						COL_D <= {2'b00,ORIG_HEIGHT[10:1]};
					end else begin
						SPR_COL_ENLARGE <= 0;
						COL_D <= {2'b00,COL_HEIGHT[10:1]};
					end
					SPR_OFFSY <= TEXT_DIRY ? (CMD.CMDSIZE.SY - 8'd1) * CMD.CMDSIZE.SX : '0;
					GRD_CALC_STEP <= '0;
					CMD_ST <= CMD.CMDPMOD.CCB[2] ? CMDS_GRD_CALC_LEFT : CMDS_SSPR_CALCX;
				end
				
				CMDS_DSPR_START,
				CMDS_POLYGON_START: begin
					LEFT_VERT <= {CMD.CMDXA.COORD,CMD.CMDYA.COORD};
					RIGHT_VERT <= {CMD.CMDXB.COORD,CMD.CMDYB.COORD};
					NEW_POLY_LSX = $signed({CMD.CMDXD.COORD[10],CMD.CMDXD.COORD}) - $signed({CMD.CMDXA.COORD[10],CMD.CMDXA.COORD});
					NEW_POLY_LSY = $signed({CMD.CMDYD.COORD[10],CMD.CMDYD.COORD}) - $signed({CMD.CMDYA.COORD[10],CMD.CMDYA.COORD});
					NEW_POLY_RSX = $signed({CMD.CMDXC.COORD[10],CMD.CMDXC.COORD}) - $signed({CMD.CMDXB.COORD[10],CMD.CMDXB.COORD});
					NEW_POLY_RSY = $signed({CMD.CMDYC.COORD[10],CMD.CMDYC.COORD}) - $signed({CMD.CMDYB.COORD[10],CMD.CMDYB.COORD});
					
					POLY_LSX <= Abs(NEW_POLY_LSX) + 11'd1;
					POLY_LSY <= Abs(NEW_POLY_LSY) + 11'd1;
					POLY_RSX <= Abs(NEW_POLY_RSX) + 11'd1;
					POLY_RSY <= Abs(NEW_POLY_RSY) + 11'd1;
					POLY_LDIRX <= NEW_POLY_LSX[11];
					POLY_LDIRY <= NEW_POLY_LSY[11];
					POLY_RDIRX <= NEW_POLY_RSX[11];
					POLY_RDIRY <= NEW_POLY_RSY[11];
					
					DIR <= '0;
					TEXT_X <= '0;
					TEXT_Y <= '0;
										
					CMD_ST <= CMDS_POLYGON_CALCD;
				end
				
				CMDS_POLYGON_CALCD: begin
					if (POLY_LSX >= POLY_LSY && POLY_LSX >= POLY_RSX && POLY_LSX >= POLY_RSY) begin
						POLY_S <= 2'b00;
						COL_HEIGHT <= POLY_LSX;
					end else if (POLY_LSY >= POLY_LSX && POLY_LSY >= POLY_RSX && POLY_LSY >= POLY_RSY) begin
						POLY_S <= 2'b01;
						COL_HEIGHT <= POLY_LSY;
					end else if (POLY_RSX >= POLY_LSX && POLY_RSX >= POLY_LSY && POLY_RSX >= POLY_RSY) begin
						POLY_S <= 2'b10;
						COL_HEIGHT <= POLY_RSX;
					end else begin
						POLY_S <= 2'b11;
						COL_HEIGHT <= POLY_RSY;
					end
					
					POLY_LDX <= '0;
					POLY_LDY <= '0;
					POLY_RDX <= '0;
					POLY_RDY <= '0;
					
					CMD_ST <= CMDS_POLYGON_CALCTDY;
				end
				
				CMDS_POLYGON_CALCTDY: begin
					SPR_OFFSY <= TEXT_DIRY ? (CMD.CMDSIZE.SY - 8'd1) * CMD.CMDSIZE.SX : '0;
					if (ORIG_HEIGHT <= COL_HEIGHT) begin
						SPR_COL_ENLARGE <= 1;
						COL_D <= '0;//{1'b0,ORIG_HEIGHT};
					end else begin
						SPR_COL_ENLARGE <= 0;
						COL_D <= '0;//{1'b0,COL_HEIGHT};
					end
					GRD_CALC_STEP <= '0;
					CMD_ST <= CMD.CMDPMOD.CCB[2] ? CMDS_GRD_CALC_LEFT : CMDS_LINE_CALC;
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
				
				CMDS_GRD_CALC_LEFT: begin
					LEFT_GHCOLOR <= GHCOLOR_A;
					{LEFT_GHCOLOR_FR,LEFT_GHCOLOR_FG,LEFT_GHCOLOR_FB} <= '0;

					GRD_CALC_STEP <= GRD_CALC_STEP + 4'd1;
					case (GRD_CALC_STEP)
						4'd0: {GHCOLOR_DIR,GHCOLOR_DIV_A} <= GHCOLOR_D.R >= GHCOLOR_A.R ? {1'b0,GHCOLOR_D.R - GHCOLOR_A.R} : {1'b1,GHCOLOR_A.R - GHCOLOR_D.R};
						4'd2: {GHCOLOR_DIR,GHCOLOR_DIV_A} <= GHCOLOR_D.G >= GHCOLOR_A.G ? {1'b0,GHCOLOR_D.G - GHCOLOR_A.G} : {1'b1,GHCOLOR_A.G - GHCOLOR_D.G};
						4'd4: {GHCOLOR_DIR,GHCOLOR_DIV_A} <= GHCOLOR_D.B >= GHCOLOR_A.B ? {1'b0,GHCOLOR_D.B - GHCOLOR_A.B} : {1'b1,GHCOLOR_A.B - GHCOLOR_D.B};
					endcase
					GHCOLOR_DIV_B <= COL_HEIGHT - 11'd1;
					case (GRD_CALC_STEP)
						4'd2: {LEFT_GHCOLOR_DIRR,LEFT_GHCOLOR_DR} <= {GHCOLOR_DIR,GHCOLOR_DELTA};
						4'd4: {LEFT_GHCOLOR_DIRG,LEFT_GHCOLOR_DG} <= {GHCOLOR_DIR,GHCOLOR_DELTA};
						4'd6: {LEFT_GHCOLOR_DIRB,LEFT_GHCOLOR_DB} <= {GHCOLOR_DIR,GHCOLOR_DELTA};
					endcase
					
					if (GRD_CALC_STEP == 4'd6) begin
						GRD_CALC_STEP <= '0;
						CMD_ST <= CMDS_GRD_CALC_RIGHT;
					end
				end
				
				CMDS_GRD_CALC_RIGHT: begin
					RIGHT_GHCOLOR <= GHCOLOR_B;
					{RIGHT_GHCOLOR_FR,RIGHT_GHCOLOR_FG,RIGHT_GHCOLOR_FB} <= '0;

					GRD_CALC_STEP <= GRD_CALC_STEP + 4'd1;
					case (GRD_CALC_STEP)
						4'd0: {GHCOLOR_DIR,GHCOLOR_DIV_A} <= GHCOLOR_C.R >= GHCOLOR_B.R ? {1'b0,GHCOLOR_C.R - GHCOLOR_B.R} : {1'b1,GHCOLOR_B.R - GHCOLOR_C.R};
						4'd2: {GHCOLOR_DIR,GHCOLOR_DIV_A} <= GHCOLOR_C.G >= GHCOLOR_B.G ? {1'b0,GHCOLOR_C.G - GHCOLOR_B.G} : {1'b1,GHCOLOR_B.G - GHCOLOR_C.G};
						4'd4: {GHCOLOR_DIR,GHCOLOR_DIV_A} <= GHCOLOR_C.B >= GHCOLOR_B.B ? {1'b0,GHCOLOR_C.B - GHCOLOR_B.B} : {1'b1,GHCOLOR_B.B - GHCOLOR_C.B};
					endcase
					GHCOLOR_DIV_B <= COL_HEIGHT - 11'd1;
					case (GRD_CALC_STEP)
						4'd2: {RIGHT_GHCOLOR_DIRR,RIGHT_GHCOLOR_DR} <= {GHCOLOR_DIR,GHCOLOR_DELTA};
						4'd4: {RIGHT_GHCOLOR_DIRG,RIGHT_GHCOLOR_DG} <= {GHCOLOR_DIR,GHCOLOR_DELTA};
						4'd6: {RIGHT_GHCOLOR_DIRB,RIGHT_GHCOLOR_DB} <= {GHCOLOR_DIR,GHCOLOR_DELTA};
					endcase
					
					if (GRD_CALC_STEP == 4'd6) begin
						GRD_CALC_STEP <= '0;
						case (CMD.CMDCTRL.COMM) 
							4'h0: CMD_ST <= CMDS_NSPR_CALCX;
							4'h1: CMD_ST <= CMDS_SSPR_CALCX;
							default: CMD_ST <= CMDS_LINE_CALC;
						endcase
					end
				end
				
				CMDS_NSPR_CALCX: begin
					/*if ($signed(LEFT_VERT.X + LOC_COORD.X) < 0 && !CMD.CMDPMOD.PCLP) begin
						LINE_VERTA.X <= RIGHT_VERT.X;
						LINE_VERTA.Y <= RIGHT_VERT.Y;
						LINE_VERTB.X <= SYS_CLIP.X1 - LOC_COORD.X;
						LINE_VERTB.Y <= LEFT_VERT.Y;
						LINE_DIRX <= 1;
						LINE_DIRY <= 1;
						DIR[0] <= 1;
					end else if ($signed(RIGHT_VERT.X + LOC_COORD.X) > $signed(SYS_CLIP.X2) && !CMD.CMDPMOD.PCLP) begin
						LINE_VERTA.X <= LEFT_VERT.X;
						LINE_VERTA.Y <= LEFT_VERT.Y;
						LINE_VERTB.X <= SYS_CLIP.X2 - LOC_COORD.X;
						LINE_VERTB.Y <= RIGHT_VERT.Y;
						LINE_DIRX <= 0;
						LINE_DIRY <= 0;
						DIR[0] <= 0;
					end else*/ begin
						LINE_VERTA.X <= LEFT_VERT.X;
						LINE_VERTA.Y <= LEFT_VERT.Y;
						LINE_VERTB.X <= RIGHT_VERT.X;
						LINE_VERTB.Y <= RIGHT_VERT.Y;
						LINE_DIRX <= 0;
						LINE_DIRY <= 0;
						DIR[0] <= 0;
					end
					ROW_D <= '0;
					SPR_ROW_ENLARGE <= 0;
					LINE_D <= '0;
					EC_FIND <= 0;
					
					if ((LINE_LEFT_OVER || LINE_RIGHT_OVER || LINE_TOP_OVER || LINE_BOTTOM_OVER) && !CMD.CMDPMOD.PCLP) begin
						CMD_ST <= CMDS_LINE_NEXT;
					end else begin
						SPR_READ <= 1;
						CMD_ST <= CMD.CMDPMOD.CCB[2] ? CMDS_GRD_CALC_LINE : CMDS_NSPR_DRAW;
					end
				end
				
				CMDS_SSPR_CALCX: begin
					NEW_LINE_SX = {RIGHT_VERT.X[10],RIGHT_VERT.X} - {LEFT_VERT.X[10],LEFT_VERT.X};
					NEW_LINE_SY = {RIGHT_VERT.Y[10],RIGHT_VERT.Y} - {LEFT_VERT.Y[10],LEFT_VERT.Y};
					/*if ($signed(LEFT_VERT.X + LOC_COORD.X) < 0 && !CMD.CMDPMOD.PCLP) begin
						LINE_VERTA.X <= RIGHT_VERT.X;
						LINE_VERTA.Y <= RIGHT_VERT.Y;
						LINE_VERTB.X <= SYS_CLIP.X1 - LOC_COORD.X;
						LINE_VERTB.Y <= LEFT_VERT.Y;
						LINE_DIRX <= ~NEW_LINE_SX[11];
						LINE_DIRY <= ~NEW_LINE_SY[11];
						DIR[0] <= 1;
					end else if ($signed(RIGHT_VERT.X + LOC_COORD.X) > $signed(SYS_CLIP.X2) && !CMD.CMDPMOD.PCLP) begin
						LINE_VERTA.X <= LEFT_VERT.X;
						LINE_VERTA.Y <= LEFT_VERT.Y;
						LINE_VERTB.X <= SYS_CLIP.X2 - LOC_COORD.X;
						LINE_VERTB.Y <= RIGHT_VERT.Y;
						LINE_DIRX <= NEW_LINE_SX[11];
						LINE_DIRY <= NEW_LINE_SY[11];
						DIR[0] <= 0;
					end else*/ begin
						LINE_VERTA.X <= LEFT_VERT.X;
						LINE_VERTA.Y <= LEFT_VERT.Y;
						LINE_VERTB.X <= RIGHT_VERT.X;
						LINE_VERTB.Y <= RIGHT_VERT.Y;
						LINE_DIRX <= NEW_LINE_SX[11];
						LINE_DIRY <= NEW_LINE_SY[11];
						DIR[0] <= 0;
					end
					LINE_D <= '0;
					
					if (ORIG_WIDTH <= ROW_WIDTH) begin
						SPR_ROW_ENLARGE <= 1;
						ROW_D <= {2'b00,ORIG_WIDTH[10:1]};
					end else begin
						SPR_ROW_ENLARGE <= 0;
						ROW_D <= {2'b00,ROW_WIDTH[10:1]};
					end
					EC_FIND <= 0;
					
					if ((LINE_LEFT_OVER || LINE_RIGHT_OVER || LINE_TOP_OVER || LINE_BOTTOM_OVER) && !CMD.CMDPMOD.PCLP) begin
						CMD_ST <= CMDS_LINE_NEXT;
					end else begin
						SPR_READ <= 1;
						CMD_ST <= CMD.CMDPMOD.CCB[2] ? CMDS_GRD_CALC_LINE : CMDS_SSPR_DRAW;
					end
				end
				
				CMDS_LINE_CALC: begin
					NEW_LINE_SX = {RIGHT_VERT.X[10],RIGHT_VERT.X} - {LEFT_VERT.X[10],LEFT_VERT.X};
					NEW_LINE_SY = {RIGHT_VERT.Y[10],RIGHT_VERT.Y} - {LEFT_VERT.Y[10],LEFT_VERT.Y};
					NEW_LINE_ASX = Abs(NEW_LINE_SX);
					NEW_LINE_ASY = Abs(NEW_LINE_SY);
					if ($signed(LEFT_VERT.X) < $signed(SYS_CLIP_X1) && !CMD.CMDPMOD.PCLP) begin
						LINE_VERTA.X <= RIGHT_VERT.X;
						LINE_VERTA.Y <= RIGHT_VERT.Y;
						LINE_VERTB.X <= SYS_CLIP_X1;
						LINE_VERTB.Y <= LEFT_VERT.Y;
						LINE_DIRX <= ~NEW_LINE_SX[11];
						LINE_DIRY <= ~NEW_LINE_SY[11];
						DIR[0] <= 1;
					end else if ($signed(LEFT_VERT.X) > $signed(SYS_CLIP_X2) && !CMD.CMDPMOD.PCLP) begin
						LINE_VERTA.X <= RIGHT_VERT.X;
						LINE_VERTA.Y <= RIGHT_VERT.Y;
						LINE_VERTB.X <= SYS_CLIP_X2;
						LINE_VERTB.Y <= LEFT_VERT.Y;
						LINE_DIRX <= ~NEW_LINE_SX[11];
						LINE_DIRY <= ~NEW_LINE_SY[11];
						DIR[0] <= 1;
					end else if ($signed(RIGHT_VERT.X) < $signed(SYS_CLIP_X1) && !CMD.CMDPMOD.PCLP) begin
						LINE_VERTA.X <= LEFT_VERT.X;
						LINE_VERTA.Y <= LEFT_VERT.Y;
						LINE_VERTB.X <= SYS_CLIP_X1;
						LINE_VERTB.Y <= RIGHT_VERT.Y;
						LINE_DIRX <= NEW_LINE_SX[11];
						LINE_DIRY <= NEW_LINE_SY[11];
						DIR[0] <= 0;
					end else if ($signed(RIGHT_VERT.X) > $signed(SYS_CLIP_X2) && !CMD.CMDPMOD.PCLP) begin
						LINE_VERTA.X <= LEFT_VERT.X;
						LINE_VERTA.Y <= LEFT_VERT.Y;
						LINE_VERTB.X <= SYS_CLIP_X2;
						LINE_VERTB.Y <= RIGHT_VERT.Y;
						LINE_DIRX <= NEW_LINE_SX[11];
						LINE_DIRY <= NEW_LINE_SY[11];
						DIR[0] <= 0;
					end else begin
						LINE_VERTA.X <= LEFT_VERT.X;
						LINE_VERTA.Y <= LEFT_VERT.Y;
						LINE_VERTB.X <= RIGHT_VERT.X;
						LINE_VERTB.Y <= RIGHT_VERT.Y;
						LINE_DIRX <= NEW_LINE_SX[11];
						LINE_DIRY <= NEW_LINE_SY[11];
						DIR[0] <= 0;
					end
					LINE_SX <= NEW_LINE_ASX + 11'd1;
					LINE_SY <= NEW_LINE_ASY + 11'd1;

					ROW_WIDTH <= NEW_LINE_ASX >= NEW_LINE_ASY ? NEW_LINE_ASX + 11'd1 : NEW_LINE_ASY + 11'd1;
					CMD_ST <= CMDS_LINE_CALCD;
				end
				
				CMDS_LINE_CALCD: begin
					if (ORIG_WIDTH <= ROW_WIDTH) begin
						SPR_ROW_ENLARGE <= 1;
						ROW_D <= {2'b00,ORIG_WIDTH[10:1]};
					end else begin
						SPR_ROW_ENLARGE <= 0;
						ROW_D <= {2'b00,ROW_WIDTH[10:1]};
					end
				
					if (LINE_SX >= LINE_SY) begin
						LINE_S <= 0;
						LINE_D <= '0;//{1'b0,LINE_SY};
					end else begin
						LINE_S <= 1;
						LINE_D <= '0;//{1'b0,LINE_SX};
					end
					EC_FIND <= 0;
//					AA <= 0;
					
					if ((LINE_LEFT_OVER || LINE_RIGHT_OVER || LINE_TOP_OVER || LINE_BOTTOM_OVER) && !CMD.CMDPMOD.PCLP) begin
						CMD_ST <= CMDS_LINE_NEXT;
					end else begin
						SPR_READ <= ~CMD.CMDCTRL.COMM[2];
						CMD_ST <= CMD.CMDPMOD.CCB[2] ? CMDS_GRD_CALC_LINE : CMDS_LINE_DRAW;
					end
				end
				
				CMDS_GRD_CALC_LINE: begin
					LINE_GHCOLOR <= LINE_DIRX ? RIGHT_GHCOLOR : LEFT_GHCOLOR;
					{LINE_GHCOLOR_FR,LINE_GHCOLOR_FG,LINE_GHCOLOR_FB} <= '0;

					GRD_CALC_STEP <= GRD_CALC_STEP + 3'd1;
					case (GRD_CALC_STEP)
						3'd0: {GHCOLOR_DIR,GHCOLOR_DIV_A} <= RIGHT_GHCOLOR.R >= LEFT_GHCOLOR.R ? {1'b0,RIGHT_GHCOLOR.R - LEFT_GHCOLOR.R} : {1'b1,LEFT_GHCOLOR.R - RIGHT_GHCOLOR.R};
						3'd2: {GHCOLOR_DIR,GHCOLOR_DIV_A} <= RIGHT_GHCOLOR.G >= LEFT_GHCOLOR.G ? {1'b0,RIGHT_GHCOLOR.G - LEFT_GHCOLOR.G} : {1'b1,LEFT_GHCOLOR.G - RIGHT_GHCOLOR.G};
						3'd4: {GHCOLOR_DIR,GHCOLOR_DIV_A} <= RIGHT_GHCOLOR.B >= LEFT_GHCOLOR.B ? {1'b0,RIGHT_GHCOLOR.B - LEFT_GHCOLOR.B} : {1'b1,LEFT_GHCOLOR.B - RIGHT_GHCOLOR.B};
					endcase
					GHCOLOR_DIV_B <= ROW_WIDTH - 11'd1;
					case (GRD_CALC_STEP)
						3'd2: {LINE_GHCOLOR_DIRR,LINE_GHCOLOR_DR} <= {LINE_DIRX^GHCOLOR_DIR,GHCOLOR_DELTA};
						3'd4: {LINE_GHCOLOR_DIRG,LINE_GHCOLOR_DG} <= {LINE_DIRX^GHCOLOR_DIR,GHCOLOR_DELTA};
						3'd6: {LINE_GHCOLOR_DIRB,LINE_GHCOLOR_DB} <= {LINE_DIRX^GHCOLOR_DIR,GHCOLOR_DELTA};
					endcase
					
					if (GRD_CALC_STEP == 3'd6) begin
						GRD_CALC_STEP <= '0;
						case (CMD.CMDCTRL.COMM) 
							4'h0: CMD_ST <= CMDS_NSPR_DRAW;
							4'h1: CMD_ST <= CMDS_SSPR_DRAW;
							default: CMD_ST <= CMDS_LINE_DRAW;
						endcase
					end
				end
				
				CMDS_NSPR_DRAW,
				CMDS_SSPR_DRAW: if (!DRAW_WAIT && SPR_DATA_READY) begin
					DRAW_ENABLE <= LINE_DRAW_STEP;
					
					ROW_D <= NEXT_ROW_D;
					if (TEXT_READ_STEP) begin
						TEXT_X <= TEXT_X + TEXT_DX;
						if (!CMD.CMDPMOD.ECD && PAT.EC) EC_FIND <= 1;
					end
					
					if (LINE_DRAW_STEP) begin
						LINE_VERTA.X <= LINE_VERTA.X + {{10{LINE_DIRX}},1'b1};
						
						{LINE_GHCOLOR.R,LINE_GHCOLOR_FR} <= {LINE_GHCOLOR.R,LINE_GHCOLOR_FR} + (LINE_GHCOLOR_DR^{16{LINE_GHCOLOR_DIRR}}) + LINE_GHCOLOR_DIRR;
						{LINE_GHCOLOR.G,LINE_GHCOLOR_FG} <= {LINE_GHCOLOR.G,LINE_GHCOLOR_FG} + (LINE_GHCOLOR_DG^{16{LINE_GHCOLOR_DIRG}}) + LINE_GHCOLOR_DIRG;
						{LINE_GHCOLOR.B,LINE_GHCOLOR_FB} <= {LINE_GHCOLOR.B,LINE_GHCOLOR_FB} + (LINE_GHCOLOR_DB^{16{LINE_GHCOLOR_DIRB}}) + LINE_GHCOLOR_DIRB;
					end
					  
					if ((LINE_VERTA.X == LINE_VERTB.X && LINE_DRAW_STEP) || (!CMD.CMDPMOD.ECD && PAT.EC && EC_FIND && TEXT_READ_STEP)) begin
						SPR_READ <= 0;
						CMD_ST <= CMDS_LINE_NEXT;
					end
				end
				
				CMDS_LINE_DRAW: if (!DRAW_WAIT && (SPR_DATA_READY || CMD.CMDCTRL.COMM >= 4'h4)) begin
					DRAW_ENABLE <= LINE_DRAW_STEP;
					
					ROW_D <= NEXT_ROW_D;
					if (TEXT_READ_STEP) begin
						TEXT_X <= TEXT_X + TEXT_DX;
						if (CMD.CMDCTRL.COMM <= 4'h3 && !CMD.CMDPMOD.ECD && PAT.EC) EC_FIND <= 1;
					end
					
					if (LINE_DRAW_STEP) begin
						if (!LINE_S) begin
							LINE_VERTA.X <= LINE_VERTA.X + {{10{LINE_DIRX}},1'b1};
							NEXT_LINE_D = LINE_D + {1'b0,LINE_SY};
							if (NEXT_LINE_D >= {1'b0,LINE_SX}) begin
								NEXT_LINE_D = LINE_D + {1'b0,LINE_SY} - {1'b0,LINE_SX};
								LINE_VERTA.Y <= LINE_VERTA.Y + {{10{LINE_DIRY}},1'b1};
								AA_X <= LINE_VERTA.X;
								AA_Y <= LINE_VERTA.Y;
								AA <= 1;
								CMD_ST <= CMDS_AA_DRAW;
							end
							LINE_D <= NEXT_LINE_D;
						end else begin
							NEXT_LINE_D = LINE_D + {1'b0,LINE_SX};
							if (NEXT_LINE_D >= {1'b0,LINE_SY}) begin
								NEXT_LINE_D = LINE_D + {1'b0,LINE_SX} - {1'b0,LINE_SY};
								LINE_VERTA.X <= LINE_VERTA.X + {{10{LINE_DIRX}},1'b1};
								AA_X <= LINE_VERTA.X;
								AA_Y <= LINE_VERTA.Y;
								AA <= 1;
								CMD_ST <= CMDS_AA_DRAW;
							end
							LINE_D <= NEXT_LINE_D;
							LINE_VERTA.Y <= LINE_VERTA.Y + {{10{LINE_DIRY}},1'b1};
						end
					
						{LINE_GHCOLOR.R,LINE_GHCOLOR_FR} <= {LINE_GHCOLOR.R,LINE_GHCOLOR_FR} + (LINE_GHCOLOR_DR^{16{LINE_GHCOLOR_DIRR}}) + LINE_GHCOLOR_DIRR;
						{LINE_GHCOLOR.G,LINE_GHCOLOR_FG} <= {LINE_GHCOLOR.G,LINE_GHCOLOR_FG} + (LINE_GHCOLOR_DG^{16{LINE_GHCOLOR_DIRG}}) + LINE_GHCOLOR_DIRG;
						{LINE_GHCOLOR.B,LINE_GHCOLOR_FB} <= {LINE_GHCOLOR.B,LINE_GHCOLOR_FB} + (LINE_GHCOLOR_DB^{16{LINE_GHCOLOR_DIRB}}) + LINE_GHCOLOR_DIRB;
					end

					if ((LINE_VERTA.X == LINE_VERTB.X && !LINE_S && LINE_DRAW_STEP) || (LINE_VERTA.Y == LINE_VERTB.Y && LINE_S && LINE_DRAW_STEP) || 
					    (CMD.CMDCTRL.COMM <= 4'h3 && !CMD.CMDPMOD.ECD && PAT.EC && EC_FIND && TEXT_READ_STEP)) begin
						SPR_READ <= DIR[0];
						CMD_ST <= DIR[0] ? CMDS_LINE_END : CMDS_LINE_NEXT;
					end
				end
				
				CMDS_AA_DRAW: if (!DRAW_WAIT && (SPR_DATA_READY || CMD.CMDCTRL.COMM >= 4'h4)) begin
					DRAW_ENABLE <= 1;
					AA <= 0;
					CMD_ST <= CMDS_LINE_DRAW;
				end
				
				CMDS_LINE_END: if (!DRAW_WAIT && (SPR_DATA_READY || CMD.CMDCTRL.COMM >= 4'h4)) begin
					DRAW_ENABLE <= AA;
					AA <= 0;
					SPR_READ <= 0;
					CMD_ST <= CMDS_LINE_NEXT;
				end
				
				CMDS_LINE_NEXT: begin
					TEXT_X <= '0;
					if (TEXTY_READ_STEP) begin
						TEXT_Y <= TEXT_Y + 8'd1;
						SPR_OFFSY <= TEXT_DIRY ? SPR_OFFSY - CMD.CMDSIZE.SX : SPR_OFFSY + CMD.CMDSIZE.SX;
					end
					
					if (CMD.CMDCTRL.COMM == 4'h0 || CMD.CMDCTRL.COMM == 4'h1) begin
						CMD_ST <= CMDS_LINE_NEXT;
						if (COL_DRAW_STEP) begin
							LEFT_VERT.Y <= LEFT_VERT.Y + {{10{COL_DIRY}},1'b1};
							RIGHT_VERT.Y <= RIGHT_VERT.Y + {{10{COL_DIRY}},1'b1};
							
							{LEFT_GHCOLOR.R,LEFT_GHCOLOR_FR} <= {LEFT_GHCOLOR.R,LEFT_GHCOLOR_FR} + (LEFT_GHCOLOR_DR^{16{LEFT_GHCOLOR_DIRR}}) + LEFT_GHCOLOR_DIRR;
							{LEFT_GHCOLOR.G,LEFT_GHCOLOR_FG} <= {LEFT_GHCOLOR.G,LEFT_GHCOLOR_FG} + (LEFT_GHCOLOR_DG^{16{LEFT_GHCOLOR_DIRG}}) + LEFT_GHCOLOR_DIRG;
							{LEFT_GHCOLOR.B,LEFT_GHCOLOR_FB} <= {LEFT_GHCOLOR.B,LEFT_GHCOLOR_FB} + (LEFT_GHCOLOR_DB^{16{LEFT_GHCOLOR_DIRB}}) + LEFT_GHCOLOR_DIRB;
							{RIGHT_GHCOLOR.R,RIGHT_GHCOLOR_FR} <= {RIGHT_GHCOLOR.R,RIGHT_GHCOLOR_FR} + (RIGHT_GHCOLOR_DR^{16{RIGHT_GHCOLOR_DIRR}}) + RIGHT_GHCOLOR_DIRR;
							{RIGHT_GHCOLOR.G,RIGHT_GHCOLOR_FG} <= {RIGHT_GHCOLOR.G,RIGHT_GHCOLOR_FG} + (RIGHT_GHCOLOR_DG^{16{RIGHT_GHCOLOR_DIRG}}) + RIGHT_GHCOLOR_DIRG;
							{RIGHT_GHCOLOR.B,RIGHT_GHCOLOR_FB} <= {RIGHT_GHCOLOR.B,RIGHT_GHCOLOR_FB} + (RIGHT_GHCOLOR_DB^{16{RIGHT_GHCOLOR_DIRB}}) + RIGHT_GHCOLOR_DIRB;
							
							CMD_ST <= CMD.CMDCTRL.COMM == 4'h0 ? CMDS_NSPR_CALCX : CMDS_SSPR_CALCX;
							if (LEFT_VERT.Y == BOTTOM_VERT.Y) begin
								CMD_ST <= CMDS_END;
							end
						end
						COL_D <= NEXT_COL_D;
					end else if (CMD.CMDCTRL.COMM == 4'h2 || CMD.CMDCTRL.COMM == 4'h3 || CMD.CMDCTRL.COMM == 4'h4) begin 
						CMD_ST <= CMDS_LINE_NEXT;
						if (COL_DRAW_STEP) begin
							case (POLY_S)
							2'b00: begin
								LEFT_VERT.X <= LEFT_VERT.X + {{10{POLY_LDIRX}},1'b1};
								
								NEXT_POLY_LDX = POLY_LDX + POLY_LSY;
								if (NEXT_POLY_LDX >= POLY_LSX) begin
									NEXT_POLY_LDX = POLY_LDX + POLY_LSY - POLY_LSX;
									LEFT_VERT.Y <= LEFT_VERT.Y + {{10{POLY_LDIRY}},1'b1};
								end
								POLY_LDX <= NEXT_POLY_LDX;
								
								NEXT_POLY_RDX = POLY_RDX + POLY_RSX;
								if (NEXT_POLY_RDX >= POLY_LSX) begin
									NEXT_POLY_RDX = POLY_RDX + POLY_RSX - POLY_LSX;
									RIGHT_VERT.X <= RIGHT_VERT.X + {{10{POLY_RDIRX}},1'b1};
								end
								POLY_RDX <= NEXT_POLY_RDX;
								
								NEXT_POLY_RDY = POLY_RDY + POLY_RSY;
								if (NEXT_POLY_RDY >= POLY_LSX) begin
									NEXT_POLY_RDY = POLY_RDY + POLY_RSY - POLY_LSX;
									RIGHT_VERT.Y <= RIGHT_VERT.Y + {{10{POLY_RDIRY}},1'b1};
								end
								POLY_RDY <= NEXT_POLY_RDY;
								
								CMD_ST <= CMDS_LINE_CALC;
								if (LEFT_VERT.X == CMD.CMDXD.COORD) begin
									CMD_ST <= CMDS_END;
								end
							end
							2'b01: begin
								NEXT_POLY_LDY = POLY_LDY + POLY_LSX;
								if (NEXT_POLY_LDY >= POLY_LSY) begin
									NEXT_POLY_LDY = POLY_LDY + POLY_LSX - POLY_LSY;
									LEFT_VERT.X <= LEFT_VERT.X + {{10{POLY_LDIRX}},1'b1};
								end
								POLY_LDY <= NEXT_POLY_LDY;
								
								LEFT_VERT.Y <= LEFT_VERT.Y + {{10{POLY_LDIRY}},1'b1};
								
								NEXT_POLY_RDX = POLY_RDX + POLY_RSX;
								if (NEXT_POLY_RDX >= POLY_LSY) begin
									NEXT_POLY_RDX = POLY_RDX + POLY_RSX - POLY_LSY;
									RIGHT_VERT.X <= RIGHT_VERT.X + {{10{POLY_RDIRX}},1'b1};
								end
								POLY_RDX <= NEXT_POLY_RDX;
								
								NEXT_POLY_RDY = POLY_RDY + POLY_RSY;
								if (NEXT_POLY_RDY >= POLY_LSY) begin
									NEXT_POLY_RDY = POLY_RDY + POLY_RSY - POLY_LSY;
									RIGHT_VERT.Y <= RIGHT_VERT.Y + {{10{POLY_RDIRY}},1'b1};
								end
								POLY_RDY <= NEXT_POLY_RDY;
								
								CMD_ST <= CMDS_LINE_CALC;
								if (LEFT_VERT.Y == CMD.CMDYD.COORD) begin
									CMD_ST <= CMDS_END;
								end
							end
							2'b10: begin
								NEXT_POLY_LDX = POLY_LDX + POLY_LSX;
								if (NEXT_POLY_LDX >= POLY_RSX) begin
									NEXT_POLY_LDX = POLY_LDX + POLY_LSX - POLY_RSX;
									LEFT_VERT.X <= LEFT_VERT.X + {{10{POLY_LDIRX}},1'b1};
								end
								POLY_LDX <= NEXT_POLY_LDX;
								
								NEXT_POLY_LDY = POLY_LDY + POLY_LSY;
								if (NEXT_POLY_LDY >= POLY_RSX) begin
									NEXT_POLY_LDY = POLY_LDY + POLY_LSY - POLY_RSX;
									LEFT_VERT.Y <= LEFT_VERT.Y + {{10{POLY_LDIRY}},1'b1};
								end
								POLY_LDY <= NEXT_POLY_LDY;
								
								RIGHT_VERT.X <= RIGHT_VERT.X + {{10{POLY_RDIRX}},1'b1};
								
								NEXT_POLY_RDY = POLY_RDY + POLY_RSY;
								if (NEXT_POLY_RDY >= POLY_RSX) begin
									NEXT_POLY_RDY = POLY_RDY + POLY_RSY - POLY_RSX;
									RIGHT_VERT.Y <= RIGHT_VERT.Y + {{10{POLY_RDIRY}},1'b1};
								end
								POLY_RDY <= NEXT_POLY_RDY;
								
								CMD_ST <= CMDS_LINE_CALC;
								if (RIGHT_VERT.X == CMD.CMDXC.COORD) begin
									CMD_ST <= CMDS_END;
								end
							end
							2'b11: begin
								NEXT_POLY_LDX = POLY_LDX + POLY_LSX;
								if (NEXT_POLY_LDX >= POLY_RSY) begin
									NEXT_POLY_LDX = POLY_LDX + POLY_LSX - POLY_RSY;
									LEFT_VERT.X <= LEFT_VERT.X + {{10{POLY_LDIRX}},1'b1};
								end
								POLY_LDX <= NEXT_POLY_LDX;
								
								NEXT_POLY_LDY = POLY_LDY + POLY_LSY;
								if (NEXT_POLY_LDY >= POLY_RSY) begin
									NEXT_POLY_LDY = POLY_LDY + POLY_LSY - POLY_RSY;
									LEFT_VERT.Y <= LEFT_VERT.Y + {{10{POLY_LDIRY}},1'b1};
								end
								POLY_LDY <= NEXT_POLY_LDY;
								
								NEXT_POLY_RDX = POLY_RDX + POLY_RSX;
								if (NEXT_POLY_RDX >= POLY_RSY) begin
									NEXT_POLY_RDX = POLY_RDX + POLY_RSX - POLY_RSY;
									RIGHT_VERT.X <= RIGHT_VERT.X + {{10{POLY_RDIRX}},1'b1};
								end
								POLY_RDX <= NEXT_POLY_RDX;
								
								RIGHT_VERT.Y <= RIGHT_VERT.Y + {{10{POLY_RDIRY}},1'b1};
								
								CMD_ST <= CMDS_LINE_CALC;
								if (RIGHT_VERT.Y == CMD.CMDYC.COORD) begin
									CMD_ST <= CMDS_END;
								end
							end
							endcase
							
							{LEFT_GHCOLOR.R,LEFT_GHCOLOR_FR} <= {LEFT_GHCOLOR.R,LEFT_GHCOLOR_FR} + (LEFT_GHCOLOR_DR^{16{LEFT_GHCOLOR_DIRR}}) + LEFT_GHCOLOR_DIRR;
							{LEFT_GHCOLOR.G,LEFT_GHCOLOR_FG} <= {LEFT_GHCOLOR.G,LEFT_GHCOLOR_FG} + (LEFT_GHCOLOR_DG^{16{LEFT_GHCOLOR_DIRG}}) + LEFT_GHCOLOR_DIRG;
							{LEFT_GHCOLOR.B,LEFT_GHCOLOR_FB} <= {LEFT_GHCOLOR.B,LEFT_GHCOLOR_FB} + (LEFT_GHCOLOR_DB^{16{LEFT_GHCOLOR_DIRB}}) + LEFT_GHCOLOR_DIRB;
							{RIGHT_GHCOLOR.R,RIGHT_GHCOLOR_FR} <= {RIGHT_GHCOLOR.R,RIGHT_GHCOLOR_FR} + (RIGHT_GHCOLOR_DR^{16{RIGHT_GHCOLOR_DIRR}}) + RIGHT_GHCOLOR_DIRR;
							{RIGHT_GHCOLOR.G,RIGHT_GHCOLOR_FG} <= {RIGHT_GHCOLOR.G,RIGHT_GHCOLOR_FG} + (RIGHT_GHCOLOR_DG^{16{RIGHT_GHCOLOR_DIRG}}) + RIGHT_GHCOLOR_DIRG;
							{RIGHT_GHCOLOR.B,RIGHT_GHCOLOR_FB} <= {RIGHT_GHCOLOR.B,RIGHT_GHCOLOR_FB} + (RIGHT_GHCOLOR_DB^{16{RIGHT_GHCOLOR_DIRB}}) + RIGHT_GHCOLOR_DIRB;
						end
						COL_D <= NEXT_COL_D;
					end else if (CMD.CMDCTRL.COMM == 4'h5 || CMD.CMDCTRL.COMM == 4'h7) begin
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
						CMD_ST <= CMDS_END;
					end
				end
				
				CMDS_END: begin
					NEXT_ADDR = CMD_ADDR + 18'h10;
					case (CMD.CMDCTRL.JP[1:0])
						2'b00: begin CMD_ADDR <= NEXT_ADDR; end
						2'b01: begin CMD_ADDR <= {CMD.CMDLINK,2'b00}; end
						2'b10: begin CMD_ADDR <= {CMD.CMDLINK,2'b00}; CMD_RET_ADDR <= NEXT_ADDR; CMD_SUB_RUN <= 1; end
						2'b11: begin CMD_ADDR <= CMD_SUB_RUN ? CMD_RET_ADDR : NEXT_ADDR; CMD_SUB_RUN <= 0; end
					endcase
					
					if (CMD.CMDCTRL.END || CMD.CMDCTRL.COMM >= 4'hB) begin
						DRAW_END <= 1;
						CMD_ST <= CMDS_IDLE;
`ifdef DEBUG
						DBG_CMD_CNT <= '0;
`endif
					end else begin
						CMD_READ <= 1;
						CMD_ST <= CMDS_READ;
`ifdef DEBUG
						DBG_CMD_CNT <= DBG_CMD_CNT + 1'd1;
						DBG_CMD_ADDR_LAST <= CMD_ADDR;
						DBG_CMD_CMDSRCA_LAST <= CMD.CMDSRCA;
`endif
					end
				end
			endcase
		end
	end
`ifdef DEBUG
	assign DBG_START = (CMD_ST == CMDS_IDLE && (FRAME_START /*|| FRAME_START_PEND*/));
	assign DBG_CMD_END = (CMD_ST == CMDS_END);
	assign DBG_LINE_OVER = LINE_SX > 11'h200 || LINE_SY > 11'h200;
`endif
		
	assign PAT = GetPattern(SPR_DATA, CMD.CMDPMOD.CM, TEXT_X[1:0] ^ {2{CMD.CMDCTRL.DIR[0]}} ^ {2{DIR[0]}});
	
	typedef enum bit [2:0] {
		FBDS_IDLE,  
		FBDS_READ,
		FBDS_READWAIT,
		FBDS_READBACK,
		FBDS_WRITE
	} FBDrawState_t;
	FBDrawState_t FBD_ST;
	
	bit  [10: 0] DRAW_X;
	bit  [10: 0] DRAW_Y;
	Pattern_t    DRAW_PAT;
	RGB_t        DRAW_GHCOLOR;
	bit  [15: 0] DRAW_BACK_C;
	bit          FB_DRAW_PEND;
	bit          FB_READ_PEND;
	bit          PAT_WORD_NEXT;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			FBD_ST <= FBDS_IDLE;
			FB_DRAW_PEND <= 0;
			FB_READ_PEND <= 0;
			PAT_WORD_NEXT <= 0;
		end
		else begin
			PAT_WORD_NEXT <= 0;
			case (FBD_ST)
				FBDS_IDLE: begin
					if (SPR_DATA_READY || CMD.CMDCTRL.COMM >= 4'h4) begin
						if ((CMD_ST == CMDS_NSPR_DRAW || CMD_ST == CMDS_SSPR_DRAW || CMD_ST == CMDS_LINE_DRAW || CMD_ST == CMDS_AA_DRAW || CMD_ST == CMDS_LINE_END)) begin
							if ((CMD_ST == CMDS_AA_DRAW || CMD_ST == CMDS_LINE_END)) begin
								if ((LINE_DIRX^LINE_DIRY)) begin
									DRAW_X <= LOC_COORD.X + AA_X;
								end else begin
									DRAW_X <= LOC_COORD.X + LINE_VERTA.X;
								end
								if (!(LINE_DIRX^LINE_DIRY)) begin
									DRAW_Y <= LOC_COORD.Y + AA_Y;
								end else begin
									DRAW_Y <= LOC_COORD.Y + LINE_VERTA.Y;
								end
							end else begin
								DRAW_X <= LOC_COORD.X + LINE_VERTA.X;
								DRAW_Y <= LOC_COORD.Y + LINE_VERTA.Y;
							end
							DRAW_PAT <= PAT;
							DRAW_GHCOLOR <= LINE_GHCOLOR;
							
							FB_DRAW_PEND <= ~CMD.CMDPMOD.CCB[0] && LINE_DRAW_STEP;
							FB_READ_PEND <= CMD.CMDPMOD.CCB[0] && LINE_DRAW_STEP;
							FBD_ST <= CMD.CMDPMOD.CCB[0] && LINE_DRAW_STEP ? FBDS_READ : FBDS_WRITE;
						end
						PAT_WORD_NEXT <= TEXT_READ_STEP && ((TEXT_X[1:0] | TEXT_MASK) == 2'b11);
					end
				end
			
				FBDS_READ: begin
					if (!FB_DRAW_WAIT) begin
						FB_READ_PEND <= 0;
						FBD_ST <= FBDS_READWAIT;
					end
				end
			
				FBDS_READWAIT: begin
					FBD_ST <= FBDS_READBACK;
				end
			
				FBDS_READBACK: begin
					DRAW_BACK_C <= FB_DRAW_Q;
					FB_DRAW_PEND <= 1;
					FBD_ST <= FBDS_WRITE;
				end
				
				FBDS_WRITE: begin
					if (!FB_DRAW_WAIT) begin
						FB_DRAW_PEND <= 0;
						FBD_ST <= FBDS_IDLE;
					end
				end
			endcase
		end
	end
	assign DRAW_WAIT = (FBD_ST != FBDS_IDLE);
	
	assign SPR_ADDR = SprAddr(SPR_OFFSY, CMD.CMDSRCA, CMD.CMDPMOD.CM);
	assign CLT_ADDR = {CMD.CMDCOLR,2'b00};
	assign GRD_ADDR = {CMD.CMDGRDA,2'b00};
	
	bit  [15: 0] FB_DRAW_D;
	bit          FB_DRAW_WE;
	bit          SCLIP;////
	bit          UCLIP;////
		bit [15: 0] ORIG_C;
		bit         TP;
	always_comb begin
		bit [15: 0] CALC_C;
		bit         EC;
		bit         MESH;
		bit         IDRAW;
		
		if (!CMD.CMDCTRL.COMM[2]) begin
			case (CMD.CMDPMOD.CM)
				3'b000: ORIG_C = {CMD.CMDCOLR[15:4],DRAW_PAT.C[3:0]};
				3'b001: ORIG_C = CLT_Q;
				3'b010: ORIG_C = {CMD.CMDCOLR[15:6],DRAW_PAT.C[5:0]};
				3'b011: ORIG_C = {CMD.CMDCOLR[15:7],DRAW_PAT.C[6:0]};
				3'b100: ORIG_C = {CMD.CMDCOLR[15:8],DRAW_PAT.C[7:0]};
				default: ORIG_C = DRAW_PAT.C;
			endcase
			TP = DRAW_PAT.TP;
			EC = DRAW_PAT.EC;
		end else begin
			ORIG_C = CMD.CMDCOLR;
			TP = 0;
			EC = 0;
		end
		CALC_C = !TVMR.TVM[0] ? ColorCalc(ORIG_C, DRAW_BACK_C, DRAW_GHCOLOR, CMD.CMDPMOD.CCB, CMD.CMDPMOD.MON) : ORIG_C;
			
		SCLIP = !DRAW_X[10] && DRAW_X[9:0] <= SYS_CLIP.X2[9:0] && !DRAW_Y[10] && !DRAW_Y[9] && DRAW_Y[8:0] <= SYS_CLIP.Y2[8:0];
		UCLIP = !DRAW_X[10] && DRAW_X[9:0] >= USR_CLIP.X1[9:0] && DRAW_X[9:0] <= USR_CLIP.X2[9:0] && !DRAW_Y[10] && !DRAW_Y[9] && DRAW_Y[8:0] >= USR_CLIP.Y1[8:0] && DRAW_Y[8:0] <= USR_CLIP.Y2[8:0];
		MESH = ~(DRAW_X[0] ^ DRAW_Y[0]);
		IDRAW = ~(DIL ^ DRAW_Y[0]);
		FB_DRAW_D = CALC_C;
		FB_DRAW_WE = (~TP | CMD.CMDPMOD.SPD) & (~EC | CMD.CMDPMOD.ECD) & SCLIP & ((UCLIP^CMD.CMDPMOD.CMOD) | ~CMD.CMDPMOD.CLIP) & (MESH | ~CMD.CMDPMOD.MESH) & (IDRAW | ~DIE);
	end
`ifdef DEBUG
	assign ORIG_C_DBG = ORIG_C;
	assign DBG_ORIG_RGB = ORIG_C[14:0];
	assign DRAW_X_DBG = DRAW_X;
	assign DRAW_Y_DBG = DRAW_Y;
	assign TP_DBG = TP;
	assign SCLIP_DBG = SCLIP;
	assign UCLIP_DBG = UCLIP;
	
	assign DBG_DRAW_OVER = DRAW_X[10:8] == 3'b011 || DRAW_X[10:8] == 3'b101 || DRAW_Y[10:8] == 2'b011 || DRAW_Y[10:8] == 3'b101;
	assign DBG_SPR_ADDR = SPR_ADDR;
`endif

	//FB out
	bit          HBL_SKIP;
	bit  [ 8: 0] OUT_X;
	bit  [ 8: 0] OUT_Y;
	bit  [ 9: 0] ERASE_X;
	bit  [ 8: 0] ERASE_Y;
	always @(posedge CLK or negedge RST_N) begin
		bit       HTIM_N_OLD;
		bit       VTIM_N_OLD;
		
		if (!RST_N) begin
			OUT_X <= '0;
			OUT_Y <= '0;
			HBL_SKIP <= 0;
		end
		else begin
			HTIM_N_OLD <= HTIM_N;
			VTIM_N_OLD <= VTIM_N;
			
			if (!VTIM_N && VTIM_N_OLD) begin
				HBL_SKIP <= 1;
			end
			if (!HTIM_N && HTIM_N_OLD && HBL_SKIP) begin
				HBL_SKIP <= 0;
			end
			
			if (OUT_X < 9'd352 && VTIM_N && DCE_R) begin
				OUT_X <= OUT_X + 9'd1;
			end
			if (HTIM_N && !HTIM_N_OLD) begin
				OUT_X <= '0;
			end
			
			if (HTIM_N && !HTIM_N_OLD && VTIM_N) begin
				OUT_Y <= OUT_Y + 9'd1;
			end
			if (HTIM_N && !HTIM_N_OLD && !VTIM_N) begin
				OUT_Y <= '1;
			end
			
			
			if (CE_R) begin
				if (!VTIM_N && VBLANK_ERASE) begin
					ERASE_X <= ERASE_X + 10'd1;
					if (ERASE_X + 10'd1 == {EWRR.X3,3'b000}) begin
						ERASE_X <= {EWLR.X1,3'b000};
						ERASE_Y <= ERASE_Y + 9'd1;
					end
					FB_ERASE_A <= {ERASE_Y[7:0],ERASE_X[8:0]};//TODO: 8bit/pixel mode
				end
			end
			if (!VTIM_N && VTIM_N_OLD) begin
				ERASE_X <= {EWLR.X1,3'b000};
				ERASE_Y <= EWLR.Y1;
			end
		end
	end
	
	assign FRAME_ERASE_HIT = (OUT_X >= {EWLR.X1,3'b000}) & (OUT_X < {EWRR.X3,3'b000}) & (OUT_Y >= EWLR.Y1) & (OUT_Y <= EWRR.Y3) & FRAME_ERASE & VTIM_N;
	assign VBLANK_ERASE_HIT = (ERASE_X >= {EWLR.X1,3'b000}) & (ERASE_X < {EWRR.X3,3'b000}) & (ERASE_Y >= EWLR.Y1) & (ERASE_Y <= EWRR.Y3) & VBLANK_ERASE & ~VTIM_N;
	
	assign FB_DISP_A = {OUT_Y[7:0],OUT_X};
	bit DCLK;
	always @(posedge CLK) begin
		if      (DCE_R) DCLK <= 1;
		else if (DCE_F) DCLK <= 0;
	end
	assign VOUT = !TVMR.TVM[0] ? FB_DISP_Q : 
	              DCLK         ? {8'h00,FB_DISP_Q[15:8]} : {8'h00,FB_DISP_Q[7:0]};
		
	
	//VRAM
	wire CPU_VRAM_REQ = (A[20:19] == 2'b00) & ~AD_N & ~CS_N & ~REQ_N;	//000000-07FFFF
	wire CPU_FB_REQ = (A[20:19] == 2'b01) & ~AD_N & ~CS_N & ~REQ_N;	//080000-0FFFFF
	
	bit  [20: 1] A;
	bit          WE_N;
	bit  [ 1: 0] DQM;
	bit          BURST;
	
	bit          CPU_VRAM_RRDY;
	bit          CPU_FB_RRDY;
	bit          CPU_VRAM_WRDY;
	bit          CPU_FB_WRDY;
	bit          CPU_FB_RPEND;
	bit          CPU_FB_WPEND;
	
	wire         PAT_FIFO_WRREQ = VRAM_ST == VS_PAT_READ && VRAM_RDY;
	wire         PAT_FIFO_RDREQ = PAT_WORD_NEXT && SPR_DATA_READY;
	bit  [15: 0] PAT_FIFO_Q;
	bit          PAT_FIFO_EMPTY;
	bit          PAT_FIFO_FULL;
	wire         PAT_FIFO_RST = !SPR_READ;
	VDP1_PAT_FIFO PAT_FIFO(CLK, PAT_FIFO_RST, VRAM_Q, PAT_FIFO_WRREQ, PAT_FIFO_RDREQ, PAT_FIFO_Q, PAT_FIFO_EMPTY, PAT_FIFO_FULL);
	
	assign SPR_DATA = PAT_FIFO_Q;
	assign SPR_DATA_READY = !PAT_FIFO_EMPTY || PAT_WORD_CNT == TEXT_SX;
	
	bit  [15: 0] MEM_DO;
	bit  [ 8: 0] PAT_WORD_CNT;
	always @(posedge CLK or negedge RST_N) begin
		bit [18: 1] CPU_RA;
		bit [18: 1] CPU_WA;
		bit [15: 0] CPU_D;
		bit [ 1: 0] CPU_WE;
		bit [18: 1] SAVE_WA;
		bit [15: 0] SAVE_D;
		bit [ 1: 0] SAVE_WE;
		bit         CPU_VRAM_RPEND;
		bit         CPU_VRAM_WPEND;
		bit         CMD_READ_PEND;
		bit         CLT_READ_PEND;
		bit         GRD_READ_PEND;
		bit [ 3: 0] VRAM_READ_POS;
		
		if (!RST_N) begin
			VRAM_ST <= VS_IDLE;
			VRAM_A <= '0;
			VRAM_D <= '0;
			VRAM_WE <= '0;
			VRAM_RD <= 0;
			FB_ST <= FS_IDLE;
			FB_A <= '0;
			FB_D <= '0;
			FB_WE <= '0;
			FB_RD <= 0;
			VRAM_DONE <= 0;
			CMD_READ_PEND <= 0;
			CLT_READ_PEND <= 0;
			GRD_READ_PEND <= 0;
			
			A <= '0;
			WE_N <= 1;
			DQM <= '1;
			BURST <= 0;
			CPU_VRAM_RPEND <= 0;
			CPU_VRAM_RRDY <= 1;
			CPU_VRAM_WPEND <= 0;
			CPU_VRAM_WRDY <= 1;
			CPU_FB_RPEND <= 0;
			CPU_FB_RRDY <= 1;
			CPU_FB_WPEND <= 0;
			CPU_FB_WRDY <= 1;
		end 
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
			if (CS_N && BURST) begin
				BURST <= 0;
			end
			
			if (CMD_READ && !CMD_READ_PEND) CMD_READ_PEND <= 1;
			if (CLT_READ && !CLT_READ_PEND) CLT_READ_PEND <= 1;
			if (GRD_READ && !GRD_READ_PEND) GRD_READ_PEND <= 1;

			if (!SPR_READ) PAT_WORD_CNT <= '0;
			
			if ((CPU_VRAM_REQ || CPU_FB_REQ) &&  WE_N &&  DTEN_N) begin 
				CPU_RA <= A[18:1];
				if (CPU_VRAM_REQ) begin
					CPU_VRAM_RPEND <= 1;
					CPU_VRAM_RRDY <= 0;
				end 
				if (CPU_FB_REQ) begin
					CPU_FB_RPEND <= 1;
					CPU_FB_RRDY <= 0;
				end
				A <= A + 20'd1;
			end
			
			if (CPU_VRAM_REQ && !WE_N && !DTEN_N) begin
				if (!CPU_VRAM_WPEND) begin
					CPU_WA <= A[18:1];
					CPU_D <= DI;
					CPU_WE <= ~{2{WE_N}} & ~DQM;
					CPU_VRAM_WPEND <= 1;
				end else begin
					SAVE_WA <= A[18:1];
					SAVE_D <= DI;
					SAVE_WE <= ~{2{WE_N}} & ~DQM;
					CPU_VRAM_WRDY <= 0;
				end
				A <= A + 20'd1;
			end
			if (!CPU_VRAM_WRDY && !CPU_VRAM_WPEND) begin
				CPU_WA <= SAVE_WA;
				CPU_D <= SAVE_D;
				CPU_WE <= SAVE_WE;
				CPU_VRAM_WPEND <= 1;
				CPU_VRAM_WRDY <= 1;
			end
			
			if (CPU_FB_REQ && !WE_N && !DTEN_N) begin
				if (CPU_FB_REQ && !CPU_FB_WPEND) begin
					CPU_WA <= A[18:1];
					CPU_D <= DI;
					CPU_WE <= ~{2{WE_N}} & ~DQM;
					CPU_FB_WPEND <= 1;
				end else begin
					SAVE_WA <= A[18:1];
					SAVE_D <= DI;
					SAVE_WE <= ~{2{WE_N}} & ~DQM;
					CPU_FB_WRDY <= 0;
				end
				A <= A + 20'd1;
			end
			if (!CPU_FB_WRDY && !CPU_FB_WPEND) begin
				CPU_WA <= SAVE_WA;
				CPU_D <= SAVE_D;
				CPU_WE <= SAVE_WE;
				CPU_FB_WPEND <= 1;
				CPU_FB_WRDY <= 1;
			end
			
			VRAM_DONE <= 0;
			CLT_WE <= 0;
			case (VRAM_ST)
				VS_IDLE: if (VRAM_RDY) begin
					if (CPU_VRAM_WPEND) begin
						if (VRAM_RDY) begin
							VRAM_A <= CPU_WA;
							VRAM_D <= CPU_D;
							VRAM_WE <= CPU_WE;
							VRAM_RD <= 0;
							CPU_VRAM_WPEND <= 0;
							VRAM_ST <= VS_CPU_WRITE;
						end
					end else if (CPU_VRAM_RPEND) begin
						begin
							VRAM_A <= CPU_RA;
							VRAM_WE <= '0;
							VRAM_RD <= 1;
							CPU_VRAM_RPEND <= 0;
							VRAM_ST <= VS_CPU_READ;
						end
					end else if (CMD_READ_PEND && !FRAME_START && !BURST) begin
						CMD_READ_PEND <= 0;
						VRAM_READ_POS <= '0;
						VRAM_A <= CMD_ADDR;
						VRAM_WE <= '0;
						VRAM_RD <= 1;
						VRAM_ST <= VS_CMD_READ;
					end else if (SPR_READ && !PAT_FIFO_FULL && PAT_WORD_CNT < TEXT_SX && VRAM_RDY && !FRAME_START && !BURST) begin
						VRAM_A <= !TEXT_DIRX ? SPR_ADDR + PAT_WORD_CNT : SPR_ADDR + (TEXT_SX - PAT_WORD_CNT - 9'd1);
						VRAM_WE <= '0;
						VRAM_RD <= 1;
						VRAM_ST <= VS_PAT_READ;
					end else if (CLT_READ_PEND && !FRAME_START && !BURST) begin
						CLT_READ_PEND <= 0;
						VRAM_READ_POS <= '0;
						VRAM_A <= CLT_ADDR;
						VRAM_WE <= '0;
						VRAM_RD <= 1;
						VRAM_ST <= VS_CLT_READ;
					end else if (GRD_READ_PEND && !FRAME_START && !BURST) begin
						GRD_READ_PEND <= 0;
						VRAM_READ_POS <= '0;
						VRAM_A <= GRD_ADDR;
						VRAM_WE <= '0;
						VRAM_RD <= 1;
						VRAM_ST <= VS_GRD_READ;
					end
				end
				
				VS_CPU_WRITE: begin
					VRAM_WE <= '0;
					VRAM_ST <= VS_IDLE;
				end
				
				VS_CPU_READ: begin
					if (VRAM_RDY && CE_R) begin
						MEM_DO <= VRAM_Q;
						VRAM_RD <= 0;
						CPU_VRAM_RRDY <= 1;
						VRAM_ST <= VS_IDLE;
					end
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
						VRAM_DATA <= VRAM_Q;
						CMD_POS <= VRAM_READ_POS;
						VRAM_DONE <= 1;

						VRAM_A <= VRAM_A + 18'd1;
						VRAM_RD <= 1;
						VRAM_ST <= VS_CMD_READ;
						
						VRAM_READ_POS <= VRAM_READ_POS + 4'd1;
						if (VRAM_READ_POS == 4'd14) begin
							VRAM_RD <= 0;
							VRAM_ST <= VS_IDLE;
						end
					end
				end
				
				VS_CLT_READ: begin
					if (FRAME_START) begin
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
						VRAM_DATA <= VRAM_Q;
						CLT_POS <= VRAM_READ_POS;
						CLT_WE <= 1;
						VRAM_DONE <= 1;
						
						VRAM_A <= VRAM_A + 18'd1;
						VRAM_RD <= 1;
						VRAM_ST <= VS_CLT_READ;
						VRAM_READ_POS <= VRAM_READ_POS + 4'd1;
						if (VRAM_READ_POS == 4'd15) begin
							VRAM_RD <= 0;
							VRAM_ST <= VS_IDLE;
						end
					end
				end
				
				VS_PAT_READ: begin
					VRAM_RD <= 0;
					if (FRAME_START || !SPR_READ) begin
						VRAM_WE <= '0;
						VRAM_RD <= 0;
						VRAM_ST <= VS_IDLE;
					end else if (VRAM_RDY) begin
						PAT_WORD_CNT <= PAT_WORD_CNT + 1'd1;
						VRAM_ST <= VS_IDLE;
					end
				end
				
				VS_GRD_READ: begin
					if (FRAME_START) begin
						VRAM_RD <= 0;
						VRAM_ST <= VS_IDLE;
					end else begin
						VRAM_ST <= VS_GRD_END;
						VRAM_RD <= 0;
					end
				end
				
				VS_GRD_END: begin
					if (FRAME_START) begin
						VRAM_RD <= 0;
						VRAM_ST <= VS_IDLE;
					end else if (VRAM_RDY) begin
						VRAM_DATA <= VRAM_Q;
						GRD_POS <= VRAM_READ_POS[1:0];
						VRAM_DONE <= 1;
						
						VRAM_A <= VRAM_A + 18'd1;
						VRAM_RD <= 1;
						VRAM_ST <= VS_GRD_READ;
						VRAM_READ_POS <= VRAM_READ_POS + 4'd1;
						if (VRAM_READ_POS == 4'd3) begin
							VRAM_RD <= 0;
							VRAM_ST <= VS_IDLE;
						end
					end
				end
			endcase
			
			if (FRAME_START) begin
				CMD_READ_PEND <= 0;
				CLT_READ_PEND <= 0;
				GRD_READ_PEND <= 0;
			end
			
			case (FB_ST)
				FS_IDLE: begin
					if (CPU_FB_WPEND && !FB_WE) begin
						if (FB_RDY) begin
							FB_A <= CPU_WA[17:1];
							FB_D <= CPU_D;
							FB_WE <= CPU_WE;
							CPU_FB_WPEND <= 0;
							FB_ST <= FS_CPU_WRITE;
						end
					end else if (CPU_FB_RPEND && !FB_RD) begin
						if (FB_RDY) begin
							FB_A <= CPU_RA[17:1];
							FB_RD <= 1;
							CPU_FB_RPEND <= 0;
							FB_ST <= FS_CPU_WAIT;
						end
					end
					else if (((FB_READ_PEND && !FB_RD) || (FB_DRAW_PEND && !FB_WE)) && FB_DRAW_WE) begin
						if (!TVMR.TVM[0]) begin
							FB_A <= {(!DIE ? DRAW_Y[7:0] : DRAW_Y[8:1]),DRAW_X[8:0]};
							FB_D <= FB_DRAW_D;
							FB_WE <= {2{FB_DRAW_PEND}};
							FB_RD <= FB_READ_PEND;
						end else begin
							FB_A <= {(!DIE ? DRAW_Y[7:0] : DRAW_Y[8:1]),DRAW_X[9:1]};
							FB_D <= {FB_DRAW_D[7:0],FB_DRAW_D[7:0]};
							FB_WE <= {~DRAW_X[0],DRAW_X[0]} & {2{FB_DRAW_PEND}};
							FB_RD <= FB_READ_PEND;
						end
						FB_ST <= FS_DRAW;
					end
				end
				
				FS_CPU_WRITE: begin
					FB_WE <= '0;
					FB_ST <= FS_IDLE;
				end
				
				FS_CPU_WAIT: begin
					FB_ST <= FS_CPU_READ;
				end
				
				FS_CPU_READ: begin
					if (FB_RDY && CE_R) begin
						MEM_DO <= FB_DRAW_Q;
						FB_RD <= 0;
						CPU_FB_RRDY <= 1;
						FB_ST <= FS_IDLE;
					end
				end
				
				FS_DRAW: begin
					FB_WE <= '0;
					FB_RD <= 0;
					FB_ST <= FS_IDLE;
				end
			endcase
		end
	end
	assign FB_DRAW_WAIT = (FB_ST != FS_IDLE) || CPU_FB_WPEND || CPU_FB_RPEND;
	
	assign CLT_RA = DRAW_PAT.C[3:0];
	VDP1_COL_TBL CLT(.CLK(CLK), .WRADDR(CLT_POS), .DATA(VRAM_DATA), .WREN(CLT_WE), .RDADDR(CLT_RA), .Q(CLT_Q));

	//Registers
	wire REG_REQ = (A[20:19] == 2'b10) & ~AD_N & ~CS_N & ~REQ_N;
	
	assign MODR = {4'h0,3'b000,PTMR.PTM[1],FBCR.EOS,FBCR.DIE,FBCR.DIL,FBCR.FCM,TVMR.VBE,TVMR.TVM};
	
	bit  [15: 0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		bit        HTIM_N_OLD;
		bit        VTIM_N_OLD;
		bit        FRAME_ERASECHANGE_PEND;
		bit        START_DRAW_PEND;
		bit        VBE_CHECK;
		
		if (!RST_N) begin
			TVMR <= '0;
			FBCR <= '0;
			PTMR <= '0;
			EWDR <= 16'h0000;
			EWLR <= 16'h0000;
			EWRR <= 16'h0000;
			EDSR <= '0;
			IRQ_N <= 1;
			
			FRAME_ERASECHANGE_PEND <= 0;
			FRAME_ERASE <= 0;
			VBLANK_ERASE <= 0;
			DRAW_TERMINATE <= 0;
			VBE_CHECK <= 0;
			
			REG_DO <= '0;
		end else if (!RES_N) begin
			PTMR <= '0;
		end else begin
			START_DRAW_PEND <= 0;
			DRAW_TERMINATE <= 0;
			if (REG_REQ) begin
				if (!WE_N && !DTEN_N) begin
					case ({A[5:1],1'b0})
						5'h00: TVMR <= DI & TVMR_MASK;
						5'h02: FBCR <= DI & FBCR_MASK;
						5'h04: PTMR <= DI & PTMR_MASK;
						5'h06: EWDR <= DI & EWDR_MASK;
						5'h08: EWLR <= DI & EWLR_MASK;
						5'h0A: EWRR <= DI & EWRR_MASK;
						default:;
					endcase
					if (A[5:1] == 5'h02>>1 && DI[1]) FRAME_ERASECHANGE_PEND <= 1;
					if (A[5:1] == 5'h04>>1 && DI[1:0] == 2'b01) begin 
						START_DRAW_PEND <= 1; 
`ifdef DEBUG
						START_DRAW_CNT <= START_DRAW_CNT + 8'd1; 
`endif
					end
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
			
			HTIM_N_OLD <= HTIM_N;
			VTIM_N_OLD <= VTIM_N;
`ifdef DEBUG
			if (VTIM_N && !VTIM_N_OLD) begin
				FRAMES_DBG <= FRAMES_DBG + 8'd1;
			end
`endif
			
			if (DRAW_END) begin
				EDSR.CEF <= 1;
				IRQ_N <= 0;
			end

			FRAME_START <= 0;
			if (START_DRAW_PEND) begin
				FRAME_START <= 1;
				EDSR.CEF <= 0;
				EDSR.BEF <= EDSR.CEF;
				DIE <= FBCR.DIE;
				DIL <= FBCR.DIL;
			end
			if (VTIM_N && !VTIM_N_OLD) begin
				VBLANK_ERASE <= 0;
				if (!FBCR.FCM) begin
					FB_SEL <= ~FB_SEL;
					FRAME_ERASE <= 1;
					EDSR.CEF <= 0;
					EDSR.BEF <= EDSR.CEF;
					DIE <= FBCR.DIE;
					DIL <= FBCR.DIL;
					if (PTMR.PTM[1]) begin
						FRAME_START <= 1;
					end
`ifdef DEBUG
					FRAMES_DBG <= 8'd0;
`endif
				end else if (FRAME_ERASECHANGE_PEND && FBCR.FCT) begin
					FB_SEL <= ~FB_SEL;
					EDSR.CEF <= 0;
					EDSR.BEF <= EDSR.CEF;
					DIE <= FBCR.DIE;
					DIL <= FBCR.DIL;
					if (PTMR.PTM[1]) begin
						FRAME_START <= 1;
					end
					FRAME_ERASECHANGE_PEND <= 0;
`ifdef DEBUG
					FRAMES_DBG <= 8'd0;
`endif
				end else if (FRAME_ERASECHANGE_PEND && !FBCR.FCT) begin
					FRAME_ERASE <= 1;
					FRAME_ERASECHANGE_PEND <= 0;
				end
//				FRAME <= 1;//~FRAME;
			end else if (!VTIM_N && VTIM_N_OLD) begin
				FRAME_ERASE <= 0;
			end
			
			if (!VTIM_N) begin
				if (!HTIM_N && HTIM_N_OLD && HBL_SKIP) begin
					VBE_CHECK <= 1;
				end
				if (!HTIM_N && HTIM_N_OLD && !HBL_SKIP && VBE_CHECK) begin
					VBE_CHECK <= 0;
					if (TVMR.VBE && FBCR.FCT && FBCR.FCM) begin
						VBLANK_ERASE <= 1;
					end
				end
			end
			
			if (!IRQ_N && CE_R) IRQ_N <= 1;
		end
	end
	
	assign DO = A[20] ? REG_DO : MEM_DO;
	assign RDY_N = ~CPU_VRAM_RRDY | ~CPU_VRAM_WRDY | ~CPU_FB_RRDY | ~CPU_FB_WRDY;
	
endmodule


module VDP1_PAT_FIFO (
	input	         CLK,
	input          RST,
	
	input	 [15: 0] DATA,
	input	         WRREQ,
	input	         RDREQ,
	output [15: 0] Q,
	output	      EMPTY,
	output	      FULL
);

	wire [15: 0] sub_wire0;
	bit  [ 3: 0] RADDR;
	bit  [ 3: 0] WADDR;
	bit  [ 4: 0] AMOUNT;
	
	always @(posedge CLK) begin
		if (RST) begin
			AMOUNT <= '0;
			RADDR <= '0;
			WADDR <= '0;
		end
		else begin
			if (WRREQ && !AMOUNT[4]) begin
				WADDR <= WADDR + 4'd1;
			end
			if (RDREQ && AMOUNT) begin
				RADDR <= RADDR + 4'd1;
			end
			
			if (WRREQ && !RDREQ && !AMOUNT[4]) begin
				AMOUNT <= AMOUNT + 5'd1;
			end else if (!WRREQ && RDREQ && AMOUNT) begin
				AMOUNT <= AMOUNT - 5'd1;
			end
		end
	end
	assign EMPTY = ~|AMOUNT;
	assign FULL = AMOUNT[4];
	
	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RADDR),
				.wraddress (WADDR),
				.wren (WRREQ),
				.q (sub_wire0),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 16,
		altdpram_component.widthad = 4,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
		
	assign Q = sub_wire0;

endmodule

module VDP1_COL_TBL (
	input         CLK,
	input	  [3:0] WRADDR,
	input	 [15:0] DATA,
	input	        WREN,
	input	  [3:0] RDADDR,
	output [15:0] Q
);

	wire [15:0] sub_wire0;

	altdpram	altdpram0 (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RDADDR[3:0]),
				.wraddress (WRADDR[3:0]),
				.wren (WREN),
				.q (sub_wire0),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
				//.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram0.indata_aclr = "OFF",
		altdpram0.indata_reg = "INCLOCK",
		altdpram0.intended_device_family = "Cyclone V",
		altdpram0.lpm_type = "altdpram",
		altdpram0.outdata_aclr = "OFF",
		altdpram0.outdata_reg = "UNREGISTERED",
		altdpram0.ram_block_type = "MLAB",
		altdpram0.rdaddress_aclr = "OFF",
		altdpram0.rdaddress_reg = "UNREGISTERED",
		altdpram0.rdcontrol_aclr = "OFF",
		altdpram0.rdcontrol_reg = "UNREGISTERED",
		altdpram0.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram0.width = 16,
		altdpram0.widthad = 4,
		altdpram0.width_byteena = 1,
		altdpram0.wraddress_aclr = "OFF",
		altdpram0.wraddress_reg = "INCLOCK",
		altdpram0.wrcontrol_aclr = "OFF",
		altdpram0.wrcontrol_reg = "INCLOCK";

	assign Q =  sub_wire0;

endmodule

module VDP1_DIV (
	denom,
	numer,
	quotient,
	remain);

	input	[10:0]  denom;
	input	[15:0]  numer;
	output	[15:0]  quotient;
	output	[10:0]  remain;

	wire [15:0] sub_wire0;
	wire [10:0] sub_wire1;
	wire [15:0] quotient = sub_wire0[15:0];
	wire [10:0] remain = sub_wire1[10:0];

	lpm_divide	LPM_DIVIDE_component (
				.denom (denom),
				.numer (numer),
				.quotient (sub_wire0),
				.remain (sub_wire1),
				.aclr (1'b0),
				.clken (1'b1),
				.clock (1'b0));
	defparam
		LPM_DIVIDE_component.lpm_drepresentation = "UNSIGNED",
		LPM_DIVIDE_component.lpm_hint = "LPM_REMAINDERPOSITIVE=TRUE",
		LPM_DIVIDE_component.lpm_nrepresentation = "UNSIGNED",
		LPM_DIVIDE_component.lpm_type = "LPM_DIVIDE",
		LPM_DIVIDE_component.lpm_widthd = 11,
		LPM_DIVIDE_component.lpm_widthn = 16;

endmodule
