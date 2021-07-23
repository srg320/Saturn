module VDP1 (
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	
	input             RES_N,

	input      [15:0] DI,
	output     [15:0] DO,
	input             CS_N,
	input             AD_N,
	input             DTEN_N,
	input       [1:0] WE_N,
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
	input             VRAM_ARDY,
	input             VRAM_DRDY,
	
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
	
	output     [15:0] ORIG_C_DBG,
	output     [10:0] DRAW_X_DBG,
	output     [10:0] DRAW_Y_DBG,
	output     [15:0] FRAMES_DBG,
	output     [7:0] START_DRAW_CNT,
	output     [15:0] REG_DBG
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
	bit        FRAME_ERASE_HIT;
	bit        DRAW_TERMINATE;
	
	//Color lookup table
	bit  [3:1] CLT_WA;
	bit [31:0] CLT_D;
	bit        CLT_WE;
	bit  [3:0] CLT_RA;
	bit [15:0] CLT_Q;
	
	bit        TEXT_FIFO_FULL;
	bit        TEXT_FIFO_RD;
	bit [15:0] TEXT_FIFO_Q;
	
	
	//Frame buffers
	bit        FB_SEL;
	bit [17:1] FB_DRAW_A;
	bit [15:0] FB_DRAW_D;
	bit        FB_DRAW_WE;
	bit [15:0] FB_DRAW_Q;
	bit [17:1] FB_DISP_A;
	bit        FB_DISP_WE;
	bit [15:0] FB_DISP_Q;
	bit        FRAME;
	
	assign FB0_A  = FB_SEL ? FB_DRAW_A : FB_DISP_A;
	assign FB1_A  = FB_SEL ? FB_DISP_A : FB_DRAW_A;
	assign FB0_D  = FB_SEL ? FB_DRAW_D : EWDR;
	assign FB1_D  = FB_SEL ? EWDR      : FB_DRAW_D;
	assign FB0_WE = FB_SEL ? FB_DRAW_WE /*& CE_R*/  : FRAME_ERASE_HIT & DCLK;
	assign FB1_WE = FB_SEL ? FRAME_ERASE_HIT & DCLK : FB_DRAW_WE /*& CE_R*/;
	assign FB0_RD = 0;
	assign FB1_RD = 0;
	
	assign FB_DRAW_Q = FB_SEL ? FB0_Q : FB1_Q;
	assign FB_DISP_Q = FB_SEL ? FB1_Q : FB0_Q;
	
	bit [20:0] A;
	
	typedef enum bit [7:0] {
		VS_IDLE     = 8'b00000001,  
		VS_CPU_READ = 8'b00000010,
		VS_CMD_READ = 8'b00000100,
		VS_CMD_WRITE= 8'b00001000,
		VS_PAT_READ = 8'b00010000,
		VS_CLT_READ = 8'b00100000,
		VS_CLT_WRITE= 8'b01000000,
		VS_END      = 8'b10000000
	} VRAMState_t;
	VRAMState_t VRAM_ST;
	bit [15:0] IO_VRAM_DO;
	bit        VRAM_DONE;
	bit        VRAM_ACCESS_PEND;
	
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
	bit [31:0] PAT;
	bit [18:1] CLT_ADDR;
	bit        CLT_READ;
	
	//Divider
	bit  [9:0] DIV_A;
	bit  [9:0] DIV_B;
	bit  [19:0] DIV_R;
	bit  [19:0] DIV_Q;
	VDP1_DIV DIV(/*.clock(CLK), */.numer({DIV_A,10'h000}), .denom(DIV_B), .quotient(DIV_R));
	
	CMDTBL_t   CMD;
	Clip_t     SYS_CLIP;
	Clip_t     USR_CLIP;
	Coord_t    LOC_COORD;
	bit [18:0] TEXT_X;
	bit [18:0] TEXT_Y;
	bit [18:0] TEXT_DX;
	bit [18:0] TEXT_DY;
	bit [15:0] TEXT_PAT;
	bit  [8:0] SPR_X;
	bit  [7:0] SPR_Y;
	bit  [9:0] SPR_SX;
	bit  [9:0] SPR_SY;
	bit  [9:0] POLY_LSX;
	bit  [9:0] POLY_LSY;
	bit  [9:0] POLY_RSX;
	bit  [9:0] POLY_RSY;
	bit  [9:0] POLY_LDX;
	bit  [9:0] POLY_LDY;
	bit  [9:0] POLY_RDX;
	bit  [9:0] POLY_RDY;
	bit  [1:0] POLY_S;
	bit        POLY_LDIRX;
	bit        POLY_LDIRY;
	bit        POLY_RDIRX;
	bit        POLY_RDIRY;
	
	Vertex_t   LINE_VERTA;
	Vertex_t   LINE_VERTB;
	Vertex_t   LEFT_VERT;
	Vertex_t   RIGHT_VERT;
	bit  [9:0] LINE_SX;
	bit  [9:0] LINE_SY;
	bit        LINE_DIRX;
	bit        LINE_DIRY;
	bit        LINE_S;
	bit  [9:0] LINE_D;
	bit  [9:0] NEXT_LINE_D;
	bit [10:0] AA_X;
	bit [10:0] AA_Y;
	bit [10:0] DRAW_X;////
	bit [10:0] DRAW_Y;////
	bit        SCLIP;////
	bit        UCLIP;////
	bit [15:0] PAT_C;////
	always @(posedge CLK or negedge RST_N) begin
	   bit [18:1] NEXT_ADDR;
		bit [18:1] CMD_JRET;
		CMDCOLR_t  CMDCOLR_LAST;
		bit [10:0] NEW_LINE_SX;
		bit [10:0] NEW_LINE_SY;
		bit [10:0] NEW_POLY_LSX;
		bit [10:0] NEW_POLY_LSY;
		bit [10:0] NEW_POLY_RSX;
		bit [10:0] NEW_POLY_RSY;
		bit  [9:0] NEXT_POLY_LDX;
		bit  [9:0] NEXT_POLY_LDY;
		bit  [9:0] NEXT_POLY_RDX;
		bit  [9:0] NEXT_POLY_RDY;
		bit        DIV_WAIT;
		bit [18:0] NEXT_TEXT_X;
		bit [18:0] NEXT_TEXT_Y;
		bit        AA;
		bit  [8:0] XMASK;
		
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
		end else begin
			case (CMD.CMDPMOD.CM)
				3'b000,
				3'b001: XMASK = 9'b111111000;
				3'b010,
				3'b011,
				3'b100: XMASK = 9'b111111100;
				default:XMASK = 9'b111111110;
			endcase
					
			case (CMD_ST) 
				CMDS_IDLE: begin
				end
					
				CMDS_READ: begin
					CMD_READ <= 0;
					if (VRAM_DONE) begin 
						LOPR <= COPR;
						COPR <= CMD_ADDR[18:3];
						CMD_ST <= CMDS_EXEC;
					end
				end
					
				CMDS_EXEC: begin
					CMD_ST <= CMDS_END;
					if (!CMD.CMDCTRL.JP[2] && !CMD.CMDCTRL.END) begin
						case (CMD.CMDCTRL.COMM)
							4'h0: begin	//normal sprite
								if (CMD.CMDPMOD.CM == 3'b001 && CMDCOLR_LAST != CMD.CMDCOLR) begin
									CMDCOLR_LAST <= CMD.CMDCOLR;
									CLT_READ <= 1;
									CMD_ST <= CMDS_CLT_LOAD;
								end else begin
									SPR_READ <= 1;
									CMD_ST <= CMDS_NSPR_START;
								end
							end
							
							4'h1: begin	//scaled sprite
								if (CMD.CMDPMOD.CM == 3'b001 && CMDCOLR_LAST != CMD.CMDCOLR) begin
									CMDCOLR_LAST <= CMD.CMDCOLR;
									CLT_READ <= 1;
									CMD_ST <= CMDS_CLT_LOAD;
								end else begin
									CMD_ST <= CMDS_SSPR_START;
								end
							end
							
							4'h2,
							4'h3: begin	//distored sprite
								if (CMD.CMDPMOD.CM == 3'b001 && CMDCOLR_LAST != CMD.CMDCOLR) begin
									CMDCOLR_LAST <= CMD.CMDCOLR;
									CLT_READ <= 1;
									CMD_ST <= CMDS_CLT_LOAD;
								end else begin
									CMD_ST <= CMDS_DSPR_START;
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
							
							4'h8: USR_CLIP <= {CMD.CMDXA.COORD[9:0],CMD.CMDYA.COORD[8:0],CMD.CMDXC.COORD[9:0],CMD.CMDYC.COORD[8:0]};
							4'h9: SYS_CLIP <= {10'h000,9'h000,CMD.CMDXC.COORD[9:0],CMD.CMDYC.COORD[8:0]};
							4'hA: LOC_COORD <= {CMD.CMDXA.COORD[9:0],CMD.CMDYA.COORD[8:0]};
						endcase
					end
				end
				
				CMDS_CLT_LOAD: begin
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
					end
				end
				
				CMDS_NSPR_START: begin
					LINE_VERTA <= {CMD.CMDXA.COORD,CMD.CMDYA.COORD};
					LINE_VERTB.X <= CMD.CMDXA.COORD + {1'b0,CMD.CMDSIZE.SX,3'b000} - 10'd1;
					LINE_VERTB.Y <= CMD.CMDYA.COORD + {2'b00,CMD.CMDSIZE.SY} - 10'd1;
					TEXT_X <= '0;
					TEXT_Y <= '0;
					TEXT_DX <= {9'h001,10'h000};
					TEXT_DY <= {9'h001,10'h000};
					CMD_ST <= CMDS_SPR_READ;
				end
				
				CMDS_SSPR_START: begin
					case (CMD.CMDCTRL.ZP[1:0])
						2'b00: begin LINE_VERTA.X <= CMD.CMDXA.COORD;                       LINE_VERTB.X <= CMD.CMDXC.COORD; end
						2'b01: begin LINE_VERTA.X <= CMD.CMDXA.COORD;                       LINE_VERTB.X <= CMD.CMDXA.COORD + CMD.CMDXB.COORD; end
						2'b10: begin LINE_VERTA.X <= CMD.CMDXA.COORD-(CMD.CMDXB.COORD>>>1); LINE_VERTB.X <= CMD.CMDXA.COORD+((CMD.CMDXB.COORD+10'd1)>>>1); end
						2'b11: begin LINE_VERTA.X <= CMD.CMDXA.COORD-CMD.CMDXB.COORD;       LINE_VERTB.X <= CMD.CMDXA.COORD; end
					endcase
					case (CMD.CMDCTRL.ZP[3:2])
						2'b00: begin LINE_VERTA.Y <= CMD.CMDYA.COORD;                       LINE_VERTB.Y <= CMD.CMDYC.COORD; end
						2'b01: begin LINE_VERTA.Y <= CMD.CMDYA.COORD;                       LINE_VERTB.Y <= CMD.CMDYA.COORD + CMD.CMDYB.COORD; end
						2'b10: begin LINE_VERTA.Y <= CMD.CMDYA.COORD-(CMD.CMDYB.COORD>>>1); LINE_VERTB.Y <= CMD.CMDYA.COORD+((CMD.CMDYB.COORD+10'd1)>>>1); end
						2'b11: begin LINE_VERTA.Y <= CMD.CMDYA.COORD-CMD.CMDYB.COORD;       LINE_VERTB.Y <= CMD.CMDYA.COORD; end
					endcase
					TEXT_X <= '0;
					TEXT_Y <= '0;
					DIV_A <= {1'b0,CMD.CMDSIZE.SX,3'b000};
					if (!CMD.CMDCTRL.ZP) begin
						DIV_B <= CMD.CMDXC.COORD-CMD.CMDXA.COORD;
					end else begin
						DIV_B <= CMD.CMDXB.COORD[9:0] + 10'd1;
					end
					CMD_ST <= CMDS_SPR_CALCX;
				end
				
				CMDS_SPR_CALCX: begin
					DIV_WAIT <= ~DIV_WAIT;
					if (DIV_WAIT) begin
					TEXT_DX <= DIV_R[18:0];
					DIV_A <= {2'b00,CMD.CMDSIZE.SY};
					if (!CMD.CMDCTRL.ZP) begin
						DIV_B <= CMD.CMDYC.COORD-CMD.CMDYA.COORD;
					end else begin
						DIV_B <= CMD.CMDYB.COORD[9:0] + 10'd1;
					end
					CMD_ST <= CMDS_SPR_CALCY;
					end
				end
				
				CMDS_SPR_CALCY: begin
					DIV_WAIT <= ~DIV_WAIT;
					if (DIV_WAIT) begin
					TEXT_DY <= DIV_R[18:0];
					SPR_READ <= 1;
					CMD_ST <= CMDS_SPR_READ;
					end
				end
				
				CMDS_SPR_READ: begin
					SPR_READ <= 0;
					if (VRAM_DONE) begin 
						if (CMD.CMDCTRL.COMM == 4'h2) CMD_ST <= AA ? CMDS_AA_DRAW : CMDS_LINE_DRAW;
						else CMD_ST <= CMDS_SPR_DRAW;
					end
				end
				
				CMDS_SPR_DRAW: begin
					NEXT_TEXT_X = TEXT_X + TEXT_DX;
					NEXT_TEXT_Y = TEXT_Y;
					if (LINE_VERTA.X == LINE_VERTB.X) begin
						NEXT_TEXT_X = '0;
						NEXT_TEXT_Y = TEXT_Y + TEXT_DY;
					end
					
					if (((TEXT_X[18:10] & XMASK) != (NEXT_TEXT_X[18:10] & XMASK) || TEXT_Y[18:10] != NEXT_TEXT_Y[18:10])) begin
						SPR_READ <= 1;
						CMD_ST <= CMDS_SPR_READ;
					end
					TEXT_X <= NEXT_TEXT_X;
					TEXT_Y <= NEXT_TEXT_Y;
					
					LINE_VERTA.X <= LINE_VERTA.X + 10'd1;
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
						LINE_VERTA.Y <= LINE_VERTA.Y + 10'd1;
						if (LINE_VERTA.Y == LINE_VERTB.Y) begin
							SPR_READ <= 0;
							CMD_ST <= CMDS_END;
						end
					end
				end
				
				CMDS_DSPR_START: begin
					TEXT_X <= '0;
					TEXT_Y <= '0;
					CMD_ST <= CMDS_POLYGON_START;
				end
				
				CMDS_POLYGON_START: begin
					LEFT_VERT <= {CMD.CMDXA.COORD,CMD.CMDYA.COORD};
					RIGHT_VERT <= {CMD.CMDXB.COORD,CMD.CMDYB.COORD};
					NEW_POLY_LSX = CMD.CMDXD.COORD - CMD.CMDXA.COORD;
					NEW_POLY_LSY = CMD.CMDYD.COORD - CMD.CMDYA.COORD;
					NEW_POLY_RSX = CMD.CMDXC.COORD - CMD.CMDXB.COORD;
					NEW_POLY_RSY = CMD.CMDYC.COORD - CMD.CMDYB.COORD;
					
					POLY_LSX <= Abs(NEW_POLY_LSX);
					POLY_LSY <= Abs(NEW_POLY_LSY);
					POLY_RSX <= Abs(NEW_POLY_RSX);
					POLY_RSY <= Abs(NEW_POLY_RSY);
					POLY_LDIRX <= NEW_POLY_LSX[10];
					POLY_LDIRY <= NEW_POLY_LSY[10];
					POLY_RDIRX <= NEW_POLY_RSX[10];
					POLY_RDIRY <= NEW_POLY_RSY[10];
										
					CMD_ST <= CMDS_POLYGON_CALCD;
				end
				
				CMDS_POLYGON_CALCD: begin
					DIV_A <= {3'b000,CMD.CMDSIZE.SY};
					if (POLY_LSX >= POLY_LSY && POLY_LSX >= POLY_RSX && POLY_LSX >= POLY_RSY) begin
						POLY_S <= 2'b00;
						DIV_B <= POLY_LSX+10'd1;
					end else if (POLY_LSY >= POLY_LSX && POLY_LSY >= POLY_RSX && POLY_LSY >= POLY_RSY) begin
						POLY_S <= 2'b01;
						DIV_B <= POLY_LSY+10'd1;
					end else if (POLY_RSX >= POLY_LSX && POLY_RSX >= POLY_LSY && POLY_RSX >= POLY_RSY) begin
						POLY_S <= 2'b10;
						DIV_B <= POLY_RSX+10'd1;
					end else begin
						POLY_S <= 2'b11;
						DIV_B <= POLY_RSY+10'd1;
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
					TEXT_DY <= DIV_R[18:0];
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
					LINE_VERTA <= LEFT_VERT;
					LINE_VERTB <= RIGHT_VERT;
					NEW_LINE_SX = RIGHT_VERT.X - LEFT_VERT.X;
					NEW_LINE_SY = RIGHT_VERT.Y - LEFT_VERT.Y;
					LINE_SX <= Abs(NEW_LINE_SX);
					LINE_SY <= Abs(NEW_LINE_SY);
					LINE_DIRX <= NEW_LINE_SX[10];
					LINE_DIRY <= NEW_LINE_SY[10];

					DIV_A <= {1'b0,CMD.CMDSIZE.SX,3'b000};
					DIV_B <= Abs(NEW_LINE_SX) >= Abs(NEW_LINE_SY) ? Abs(NEW_LINE_SX)+1 : Abs(NEW_LINE_SY)+1;
					CMD_ST <= CMDS_LINE_CALCD;
				end
				
				CMDS_LINE_CALCD: begin
					DIV_WAIT <= ~DIV_WAIT;
					if (DIV_WAIT) begin
					LINE_S <= ~(LINE_SX >= LINE_SY);
					LINE_D <= '0;
					AA <= 0;
					
					TEXT_DX <= DIV_R[18:0];
					if (CMD.CMDCTRL.COMM <= 4'h3) begin
						SPR_READ <= 1;
						CMD_ST <= CMDS_SPR_READ;
					end else begin
						CMD_ST <= CMDS_LINE_DRAW;
					end
					end
				end
				
				CMDS_LINE_DRAW: begin
					NEXT_TEXT_X = TEXT_X + TEXT_DX;
					NEXT_TEXT_Y = TEXT_Y;
					if ((LINE_VERTA.X == LINE_VERTB.X && !LINE_S) || (LINE_VERTA.Y == LINE_VERTB.Y && LINE_S)) begin
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
					
					if (CMD.CMDCTRL.COMM <= 4'h3 && ((TEXT_X[18:10] & XMASK) != (NEXT_TEXT_X[18:10] & XMASK) || TEXT_Y[18:10] != NEXT_TEXT_Y[18:10])) begin
						SPR_READ <= 1;
						CMD_ST <= CMDS_SPR_READ;
					end
					if ((LINE_VERTA.X == LINE_VERTB.X && !LINE_S) || (LINE_VERTA.Y == LINE_VERTB.Y && LINE_S)) begin
						CMD_ST <= CMDS_LINE_NEXT;
						SPR_READ <= 0;
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
							
							if (LEFT_VERT.X == CMD.CMDXD.COORD) begin
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
							
							if (RIGHT_VERT.X == CMD.CMDXC.COORD) begin
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
					
					if (CMD.CMDCTRL.END) begin
						CMD_ST <= CMDS_IDLE;
					end else begin
						CMD_READ <= 1;
						CMD_ST <= CMDS_READ;
					end
				end
			endcase
		end
	end
		
	assign TEXT_PAT = !SPR_ADDR[1] ? PAT[31:16] : PAT[15:0];
		
	bit [15:0] ORIG_C;//////
	always_comb begin
		bit        TP;
		bit [15:0] CALC_C;
		
		PAT_C = GetPattern(TEXT_PAT, CMD.CMDPMOD.CM, TEXT_X[11:10] ^ {2{CMD.CMDCTRL.DIR[0]}});
		if (!CMD.CMDCTRL.COMM[2]) begin
			case (CMD.CMDPMOD.CM)
				3'b000: ORIG_C = {CMD.CMDCOLR[15:4],PAT_C[3:0]};
				3'b001: ORIG_C = CLT_Q;
				3'b010: ORIG_C = {CMD.CMDCOLR[15:6],PAT_C[5:0]};
				3'b011: ORIG_C = {CMD.CMDCOLR[15:7],PAT_C[6:0]};
				3'b100: ORIG_C = {CMD.CMDCOLR[15:8],PAT_C[7:0]};
				3'b101: ORIG_C = PAT_C;
				default:ORIG_C = '0;
			endcase
			TP = ~|PAT_C;
		end else begin
			ORIG_C = CMD.CMDCOLR;
			TP = 1;
		end
		CALC_C = ColorCalc(ORIG_C,FB_DRAW_Q,CMD.CMDPMOD.CCB);
					
		if (CMD_ST == CMDS_AA_DRAW && (LINE_DIRX^LINE_DIRY)) begin
			DRAW_X = {1'b0,LOC_COORD.X} + AA_X;
		end else begin
			DRAW_X = {1'b0,LOC_COORD.X} + LINE_VERTA.X;
		end
		if (CMD_ST == CMDS_AA_DRAW && !(LINE_DIRX^LINE_DIRY)) begin
			DRAW_Y = {2'b00,LOC_COORD.Y} + AA_Y;
		end else begin
			DRAW_Y = {2'b00,LOC_COORD.Y} + LINE_VERTA.Y;
		end
			
		SCLIP = !DRAW_X[10] && DRAW_X[9:0] <= SYS_CLIP.X2 && !DRAW_Y[10] && !DRAW_Y[9] && DRAW_Y[8:0] <= SYS_CLIP.Y2;
		UCLIP = !DRAW_X[10] && DRAW_X[9:0] >= USR_CLIP.X1 && DRAW_X[9:0] <= USR_CLIP.X2 && !DRAW_Y[10] && !DRAW_Y[9] && DRAW_Y[8:0] >= USR_CLIP.Y1 && DRAW_Y[8:0] <= USR_CLIP.Y2;
		FB_DRAW_A = {DRAW_Y[7:0],DRAW_X[8:0]};
		FB_DRAW_D = CALC_C;
		FB_DRAW_WE = (CMD_ST == CMDS_SPR_DRAW || CMD_ST == CMDS_LINE_DRAW || CMD_ST == CMDS_AA_DRAW) & (~TP | CMD.CMDPMOD.SPD) & SCLIP & (UCLIP | ~CMD.CMDPMOD.CLIP);
		
		SPR_ADDR = SprAddr(TEXT_X[18:10],TEXT_Y[18:10],CMD.CMDSIZE,CMD.CMDCTRL.DIR,CMD.CMDSRCA,CMD.CMDPMOD.CM);
		CLT_ADDR = {CMD.CMDCOLR,2'b00};
		CLT_RA = PAT_C[3:0];
	end
	assign ORIG_C_DBG = ORIG_C;
	assign DRAW_X_DBG = DRAW_X;
	assign DRAW_Y_DBG = DRAW_Y;
	
	//FB out
	bit [8:0] OUT_X;
	bit [8:0] OUT_Y;
	always @(posedge CLK or negedge RST_N) begin
		bit       HTIM_N_OLD;
		bit       VTIM_N_OLD;
		
		if (!RST_N) begin
			OUT_X <= '0;
			OUT_Y <= '0;
		end
		else begin
			if (OUT_X < 9'd352 && DCLK) begin
				OUT_X <= OUT_X + 9'd1;
				FB_DISP_A <= {OUT_Y[7:0],OUT_X};
			end
			
			HTIM_N_OLD <= HTIM_N;
			if (HTIM_N && !HTIM_N_OLD && VTIM_N) begin
				OUT_X <= '0;
				OUT_Y <= OUT_Y + 9'd1;
			end
			
			VTIM_N_OLD <= VTIM_N;
			if (VTIM_N && !VTIM_N_OLD) begin
				OUT_Y <= '0;
			end
		end
	end
	
	assign FRAME_ERASE_HIT = (OUT_X >= {EWLR.X1,3'b000}) & (OUT_X <= {EWRR.X3,3'b111}) & (OUT_Y >= EWLR.Y1) & (OUT_Y <= EWRR.Y3) & FRAME_ERASE;
	
//	assign FB_DISP_A = {OUT_Y,OUT_X};
	assign VOUT = FB_DISP_Q;
		
	
	//VRAM
	wire CPU_VRAM_SEL = (A[20:19] == 2'b00) & ~DTEN_N & ~AD_N & ~CS_N;	//000000-07FFFF
	wire CPU_FB_SEL = (A[20:19] == 2'b01) & ~DTEN_N & ~AD_N & ~CS_N;	//080000-0FFFFF
	bit [18:1] VRAM_LAST_A;
		bit        IO_DATA_PEND;
		bit        CLT_DATA_PEND;
		bit  [3:0] CLT_DATA_POS;
	always @(posedge CLK or negedge RST_N) begin
		bit        VRAM_SEL_OLD;
		bit        CMD_READ_PEND;
		bit        SPR_READ_PEND;
		bit        CLT_READ_PEND;
		bit        LAST_DATA;
		bit        CMD_DATA_PEND;
		bit  [3:0] CMD_DATA_POS;
		bit        PAT_DATA_PEND;
		bit        VRAM_DRDY_OLD;
		
		if (!RST_N) begin
			VRAM_ST <= VS_IDLE;
			VRAM_A <= '0;
			VRAM_D <= '0;
			VRAM_WE <= '0;
			VRAM_RD <= 0;
			VRAM_DONE <= 0;
			VRAM_ACCESS_PEND <= 0;
			CMD_READ_PEND <= 0;
			SPR_READ_PEND <= 0;
			CLT_READ_PEND <= 0;
			CMD <= '0;
		end
		else  begin
			VRAM_SEL_OLD <= CPU_VRAM_SEL;
			if (CPU_VRAM_SEL && !VRAM_SEL_OLD) VRAM_ACCESS_PEND <= 1;
			if (CMD_READ && !CMD_READ_PEND) CMD_READ_PEND <= 1;
			if (SPR_READ && !SPR_READ_PEND) SPR_READ_PEND <= 1;
			if (CLT_READ && !CLT_READ_PEND) CLT_READ_PEND <= 1;
			
			VRAM_DONE <= 0;
			case (VRAM_ST)
				VS_IDLE: begin
					if (VRAM_ACCESS_PEND) begin
//						VRAM_ACCESS_PEND <= 0;
						VRAM_A <= A[18:1];
						VRAM_D <= DI;
						VRAM_WE <= ~WE_N;
						VRAM_RD <= &WE_N;
						VRAM_ST <= VS_CPU_READ;
					end else if (CMD_READ_PEND) begin
						CMD_READ_PEND <= 0;
						VRAM_A <= CMD_ADDR;
						VRAM_WE <= '0;
						VRAM_RD <= 1;
						VRAM_ST <= VS_CMD_READ;
					end else if (SPR_READ_PEND) begin
						SPR_READ_PEND <= 0;
						PAT_DATA_PEND <= 0;
						VRAM_A <= {SPR_ADDR[18:2],1'b0};
						VRAM_WE <= '0;
//						if (VRAM_A[18:2] != SPR_ADDR[18:2]) begin
							VRAM_RD <= 1;
							VRAM_ST <= VS_PAT_READ;
//						end else begin
//							VRAM_DONE <= 1;
//						end
					end else if (CLT_READ_PEND) begin
						CLT_DATA_PEND <= 0;
						CLT_READ_PEND <= 0;
						VRAM_A <= CLT_ADDR;
						VRAM_WE <= '0;
						VRAM_RD <= 1;
						VRAM_ST <= VS_CLT_READ;
					end
				end
				
				VS_CPU_READ: begin
					if (VRAM_ARDY) begin
						VRAM_WE <= '0;
						VRAM_RD <= 0;
						VRAM_ACCESS_PEND <= 0;
						IO_DATA_PEND <= 1;
						VRAM_ST <= VS_IDLE;
					end
				end
					
				VS_CMD_READ: begin
					if (VRAM_ARDY && !CMD_DATA_PEND) begin
						VRAM_A <= VRAM_A + 18'd2;
						if ({VRAM_A[4:1],1'b0} == 5'h1C) begin
							LAST_DATA <= 1;
							VRAM_RD <= 0;
							VRAM_ST <= VS_IDLE;
						end
						CMD_DATA_POS <= VRAM_A[4:1];
						CMD_DATA_PEND <= 1;
					end
				end
				
				VS_CLT_READ: begin
					if (VRAM_ARDY && !CLT_DATA_PEND) begin
						VRAM_A <= VRAM_A + 18'd2;
						if ({VRAM_A[4:1],1'b0} == 5'h1C) begin
							LAST_DATA <= 1;
							VRAM_RD <= 0;
							VRAM_ST <= VS_IDLE;
						end
						CLT_DATA_POS <= VRAM_A[4:1];
						CLT_DATA_PEND <= 1;
					end
				end
				
				VS_PAT_READ: begin
					if (VRAM_ARDY && !PAT_DATA_PEND) begin
						VRAM_RD <= 0;
						PAT_DATA_PEND <= 1;
						LAST_DATA <= 1;
						VRAM_ST <= VS_IDLE;
					end
				end
			endcase
			
			VRAM_DRDY_OLD <= VRAM_DRDY;
			if (VRAM_DRDY && !VRAM_DRDY_OLD) begin
				if (IO_DATA_PEND) begin
					IO_VRAM_DO <= VRAM_Q[31:16];
					IO_DATA_PEND <= 0;
				end else if (CMD_DATA_PEND) begin
					case ({CMD_DATA_POS[3:1],1'b0})
						4'h0: {CMD.CMDCTRL,CMD.CMDLINK} <= VRAM_Q;
						4'h2: {CMD.CMDPMOD,CMD.CMDCOLR} <= VRAM_Q;
						4'h4: {CMD.CMDSRCA,CMD.CMDSIZE} <= VRAM_Q;
						4'h6: {CMD.CMDXA,CMD.CMDYA} <= VRAM_Q;
						4'h8: {CMD.CMDXB,CMD.CMDYB} <= VRAM_Q;
						4'hA: {CMD.CMDXC,CMD.CMDYC} <= VRAM_Q;
						4'hC: {CMD.CMDXD,CMD.CMDYD} <= VRAM_Q;
						4'hE: CMD.CMDGRDA <= VRAM_Q[31:16];
					endcase
					CMD_DATA_PEND <= 0;
					VRAM_DONE <= LAST_DATA;
					LAST_DATA <= 0;
				end else if (CLT_DATA_PEND) begin
					CLT_DATA_PEND <= 0;
					VRAM_DONE <= LAST_DATA;
					LAST_DATA <= 0;
				end else if (PAT_DATA_PEND) begin
					PAT <= VRAM_Q;
					PAT_DATA_PEND <= 0;
					VRAM_DONE <= LAST_DATA;
					LAST_DATA <= 0;
				end
			end
			
			if (FRAME_START) begin
				CMD_READ_PEND <= 0;
				SPR_READ_PEND <= 0;
				CLT_READ_PEND <= 0;
				VRAM_ST <= VS_IDLE;
			end
		end
	end
	
	assign CLT_WA = CLT_DATA_POS[3:1];
	assign CLT_D = VRAM_Q;
	assign CLT_WE = (CLT_DATA_PEND && VRAM_DRDY);
	COL_TBL CLT(.CLK(CLK), .WRADDR(CLT_WA), .DATA(CLT_D), .WREN(CLT_WE), .RDADDR(CLT_RA), .Q(CLT_Q));


	bit CPU_VRAM_RDY;
	always @(posedge CLK or negedge RST_N) begin
		bit VRAM_SEL_OLD;
		bit IO_PEND_OLD;
		
		if (!RST_N) begin
			CPU_VRAM_RDY <= 1;
		end
		else begin
			VRAM_SEL_OLD <= CPU_VRAM_SEL;
			IO_PEND_OLD <= IO_DATA_PEND;
			if (CPU_VRAM_SEL && !VRAM_SEL_OLD && CPU_VRAM_RDY) 
				CPU_VRAM_RDY <= 0;
			else if (!IO_DATA_PEND && IO_PEND_OLD && !CPU_VRAM_RDY) 
				CPU_VRAM_RDY <= 1;
		end
	end


	//Registers
	wire REG_SEL = (A[20:19] == 2'b10) & ~DTEN_N & ~AD_N & ~CS_N;
	
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
			
			REG_DO <= '0;
			A <= '0;
			
			FRAME_ERASECHANGE_PEND <= 0;
			DRAW_TERMINATE <= 0;
			
			FRAME <= 0;
			FRAMES_DBG <= '0;
			
			START_DRAW_CNT <= '0;
		end else if (!RES_N) begin
				
		end else begin
			if (!CS_N && DTEN_N && AD_N && CE_R) begin
				A <= {A[4:0],DI};
			end
			
			START_DRAW_PEND <= 0;
			DRAW_TERMINATE <= 0;
			if (REG_SEL) begin
				if (!(&WE_N) && CE_R) begin
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
					if (A[5:1] == 5'h04>>1 && DI[1:0] == 2'b01) begin START_DRAW_PEND <= 1; START_DRAW_CNT <= START_DRAW_CNT + 1; end
					if (A[5:1] == 5'h0C>>1 && DI[1]) DRAW_TERMINATE <= 1;
				end else if (WE_N && CE_F) begin
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
			FRAME_START <= 0;
			if (START_DRAW_PEND) begin
				FRAME_START <= 1;
				EDSR.CEF <= 0;
				EDSR.BEF <= EDSR.CEF;
			end else if (VTIM_N && !VTIM_N_OLD) begin
				FRAME_ERASE <= 0;
				if (!FBCR.FCM) begin
					FB_SEL <= ~FB_SEL;
					FRAME_ERASE <= 1;
					if (PTMR.PTM == 2'b10) begin
						FRAME_START <= 1;
						EDSR.CEF <= 0;
						EDSR.BEF <= EDSR.CEF;
					end
				end else if (FRAME_ERASECHANGE_PEND && FBCR.FCT) begin
					FB_SEL <= ~FB_SEL;
					if (PTMR.PTM == 2'b10) begin
						FRAME_START <= 1;
						EDSR.CEF <= 0;
						EDSR.BEF <= EDSR.CEF;
					end
					FRAME_ERASECHANGE_PEND <= 0;
//					FRAMES_DBG <= 16'd0;
				end else if (FRAME_ERASECHANGE_PEND && !FBCR.FCT) begin
					FRAME_ERASE <= 1;
					FRAME_ERASECHANGE_PEND <= 0;
				end
//				FRAME <= 1;//~FRAME;
				if (!EDSR.CEF) FRAMES_DBG <= FRAMES_DBG + 16'd1;
				else FRAMES_DBG <= 16'd0;
			end
			
			
			if (CMD_ST == CMDS_END && CMD.CMDCTRL.END && !EDSR.CEF) begin
				EDSR.CEF <= 1;
//				FRAMES_DBG <= 16'd0;
			end
		end
	end
	
	assign DO = REG_SEL ? REG_DO : IO_VRAM_DO;
	assign RDY_N = ~((CPU_VRAM_SEL & CPU_VRAM_RDY) | CPU_FB_SEL | REG_SEL);
	
	assign IRQ_N = ~EDSR.CEF;

	assign REG_DBG = TVMR;
	
endmodule
