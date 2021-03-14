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
	output     [15:0] FRAMES_DBG,
	output     [15:0] REG_DBG
);
	import VDP1_PKG::*;
	
	TVMR_t     TVMR;
	FBCR_t     FBCR;
	PTMR_t     PTMR;
	EWDR_t     EWDR;
	EWLR_t     EWLR;
	EWRR_t     EWRR;
	ENDR_t     ENDR;
	EDSR_t     EDSR;
	LOPR_t     LOPR;
	COPR_t     COPR;
	MODR_t     MODR;

	bit        FRAME_START;
	
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
	
	assign FB0_A  = FB_SEL ? FB_DRAW_A : FB_DISP_A;
	assign FB1_A  = FB_SEL ? FB_DISP_A : FB_DRAW_A;
	assign FB0_D  = FB_SEL ? FB_DRAW_D : '0;
	assign FB1_D  = FB_SEL ? '0        : FB_DRAW_D;
	assign FB0_WE = FB_SEL ? FB_DRAW_WE & CE_R      : DCLK;
	assign FB1_WE = FB_SEL ? DCLK : FB_DRAW_WE & CE_R;
	
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
		CMDS_SPR_START,
		CMDS_SPR_CALCX,
		CMDS_SPR_CALCY,
		CMDS_SPR_READ,
		CMDS_SPR_DRAW,
		CMDS_POLY_START,
		CMDS_POLY_CALCDL,
		CMDS_POLY_CALCDR,
		CMDS_LINE_START,
		CMDS_LINE_CALCD,
		CMDS_LINE_CALCDX,
		CMDS_LINE_CALCDY,
		CMDS_LINE_DRAW,
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
	bit  [10:0] DIV_A;
	bit  [10:0] DIV_B;
	bit  [20:0] DIV_Q;
	bit  [20:0] DIV_R;
	VDP1_DIV DIV(/*.clock(CLK), */.numer({DIV_A,10'h000}), .denom(DIV_B), .quotient(DIV_Q));
//	assign DIV_Q = {{DIV_A,10'h000} / DIV_B};
	always @(posedge CLK) DIV_R <= DIV_Q;
	
	CMDTBL_t   CMD;
	Clip_t     SYS_CLIP;
	Clip_t     USR_CLIP;
	Coord_t    LOC_COORD;
	Vertex_t   VERTA;
	Vertex_t   VERTB;
	bit [18:0] TEXT_X;
	bit [17:0] TEXT_Y;
	bit [18:0] TEXT_DX;
	bit [17:0] TEXT_DY;
	bit [15:0] TEXT_PAT;
	bit  [8:0] SPR_X;
	bit  [7:0] SPR_Y;
	bit  [8:0] SPR_SX;
	bit  [7:0] SPR_SY;
	bit [20:0] POLY_L;
	bit [20:0] POLY_R;
	bit [20:0] POLY_DL;
	bit [20:0] POLY_DR;
	bit [10:0] POLY_HL;
	bit [10:0] POLY_HR;
	bit  [9:0] POLY_PY;
	bit  [9:0] POLY_H;
	bit [20:0] LINE_X;
	bit [20:0] LINE_Y;
	bit [20:0] LINE_DX;
	bit [20:0] LINE_DY;
	bit [10:0] LINE_SX;
	bit [10:0] LINE_SY;
	bit  [9:0] LINE_POS;
	bit  [9:0] LINE_L;
	bit        LINE_DIRX;
	bit        LINE_DIRY;
	bit [10:0] DRAW_X;////
	bit [10:0] DRAW_Y;////
	bit        SCLIP;////
	bit        UCLIP;////
	bit [15:0] PAT_C;////
	bit        LAST;
	always @(posedge CLK or negedge RST_N) begin
	   bit [18:1] NEXT_ADDR;
		bit [18:1] CMD_JRET;
		CMDCOLR_t  CMDCOLR_LAST;
		bit  [8:0] LAST_SPR_X;
		
		if (!RST_N) begin
			CMD_ST <= CMDS_IDLE;
			CMD_ADDR <= '0;
			CMD_READ <= 0;
			SPR_READ <= 0;
			SYS_CLIP <= {10'h000,9'h000,10'h13F,9'h0FF};//CLIP_NULL;
			USR_CLIP <= CLIP_NULL;
			LOC_COORD <= COORD_NULL;
			VERTA <= VERT_NULL;
			
//			EDSR <= '0;
			LOPR <= '0;
			COPR <= '0;
			
			LAST_SPR_X <= '1;
		end else if (FRAME_START) begin
			CMD_ADDR <= '0;
			CMD_READ <= 1;
			SPR_READ <= 0;
			CLT_READ <= 0;
//			EDSR.CEF <= 0;
			CMD_ST <= CMDS_READ;
		end else if (CE_R) begin
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
								VERTA <= {CMD.CMDXA.COORD,CMD.CMDYA.COORD};
								SPR_X <= '0;
								SPR_Y <= '0;
								SPR_SX <= {CMD.CMDSIZE.SX,3'b000};
								SPR_SY <= CMD.CMDSIZE.SY;
								TEXT_X <= '0;
								TEXT_Y <= '0;
								TEXT_DX <= {9'h001,10'h000};
								TEXT_DY <= {8'h01,10'h000};
								if (CMD.CMDPMOD.CM == 3'b001 && CMDCOLR_LAST != CMD.CMDCOLR) begin
									CMDCOLR_LAST <= CMD.CMDCOLR;
									CLT_READ <= 1;
									CMD_ST <= CMDS_CLT_LOAD;
								end else begin
									SPR_READ <= 1;
									CMD_ST <= CMDS_SPR_READ;
								end
							end
							4'h1: begin	//scaled sprite
								case (CMD.CMDCTRL.ZP[1:0])
									2'b00: VERTA.X <= CMD.CMDXA.COORD;
									2'b01: VERTA.X <= CMD.CMDXA.COORD;
									2'b10: VERTA.X <= CMD.CMDXA.COORD-(CMD.CMDXB.COORD>>>1);
									2'b11: VERTA.X <= CMD.CMDXA.COORD-CMD.CMDXB.COORD;
								endcase
								case (CMD.CMDCTRL.ZP[3:2])
									2'b00: VERTA.Y <= CMD.CMDYA.COORD;
									2'b01: VERTA.Y <= CMD.CMDYA.COORD;
									2'b10: VERTA.Y <= CMD.CMDYA.COORD-(CMD.CMDYB.COORD>>>1);
									2'b11: VERTA.Y <= CMD.CMDYA.COORD-CMD.CMDYB.COORD;
								endcase
								SPR_X <= '0;
								SPR_Y <= '0;
								if (!CMD.CMDCTRL.ZP) begin
									SPR_SX <= CMD.CMDXC.COORD-CMD.CMDXA.COORD;
									SPR_SY <= CMD.CMDYC.COORD-CMD.CMDYA.COORD;
								end else begin
									SPR_SX <= CMD.CMDXB.COORD[8:0] + 9'd1;
									SPR_SY <= CMD.CMDYB.COORD[7:0] + 8'd1;
								end
								TEXT_X <= '0;
								TEXT_Y <= '0;
								if (CMD.CMDPMOD.CM == 3'b001 && CMDCOLR_LAST != CMD.CMDCOLR) begin
									CMDCOLR_LAST <= CMD.CMDCOLR;
									CLT_READ <= 1;
									CMD_ST <= CMDS_CLT_LOAD;
								end else begin
									CMD_ST <= CMDS_SPR_START;
								end
							end
							4'h7: begin	//polygon
								VERTA.X <= CMD.CMDXA.COORD;
								VERTA.Y <= CMD.CMDYA.COORD;
								VERTB.X <= CMD.CMDXB.COORD;
								VERTB.Y <= CMD.CMDYB.COORD;
								POLY_HL <= $signed(CMD.CMDYD.COORD) >= $signed(CMD.CMDYA.COORD) ? CMD.CMDYD.COORD - CMD.CMDYA.COORD : CMD.CMDYA.COORD - CMD.CMDYD.COORD;
								POLY_HR <= $signed(CMD.CMDYC.COORD) >= $signed(CMD.CMDYB.COORD) ? CMD.CMDYC.COORD - CMD.CMDYB.COORD : CMD.CMDYB.COORD - CMD.CMDYC.COORD;
								CMD_ST <= CMDS_POLY_START;
							end
							4'h6: begin	//line
								VERTA.X <= CMD.CMDXA.COORD;
								VERTA.Y <= CMD.CMDYA.COORD;
								VERTB.X <= CMD.CMDXB.COORD;
								VERTB.Y <= CMD.CMDYB.COORD;
								CMD_ST <= CMDS_LINE_START;
							end
							4'h8: USR_CLIP <= {CMD.CMDXA.COORD[9:0],CMD.CMDYA.COORD[8:0],CMD.CMDXC.COORD[9:0],CMD.CMDYC.COORD[8:0]};
							4'h9: SYS_CLIP <= {10'h000,9'h000,CMD.CMDXC.COORD[9:0],CMD.CMDYC.COORD[8:0]};
							4'hA: LOC_COORD <= {CMD.CMDXA.COORD[9:0],CMD.CMDYA.COORD[8:0]};
						endcase
					end
//					if (CMD.CMDCTRL.END) EDSR.CEF <= 1;
				end
				
				CMDS_CLT_LOAD: begin
					CLT_READ <= 0;
					if (VRAM_DONE) begin 
						if (!CMD.CMDCTRL.COMM) begin
							SPR_READ <= 1;
							CMD_ST <= CMDS_SPR_READ;
						end else begin
							CMD_ST <= CMDS_SPR_START;
						end
					end
				end
				
				CMDS_SPR_START: begin
					DIV_A <= {2'b00,CMD.CMDSIZE.SX,3'b000};
					DIV_B <= {2'b00,SPR_SX};
					CMD_ST <= CMDS_SPR_CALCX;
				end
				
				CMDS_SPR_CALCX: begin
					TEXT_DX <= DIV_R[18:0];
					DIV_A <= {3'b000,CMD.CMDSIZE.SY};
					DIV_B <= {3'b000,SPR_SY};
					CMD_ST <= CMDS_SPR_CALCY;
				end
				
				CMDS_SPR_CALCY: begin
					TEXT_DY <= DIV_R[17:0];
					SPR_READ <= 1;
					CMD_ST <= CMDS_SPR_READ;
				end
				
				CMDS_SPR_READ: begin
					SPR_READ <= 0;
					if (VRAM_DONE) begin 
						TEXT_PAT <= !SPR_ADDR[1] ? PAT[31:16] : PAT[15:0];
						CMD_ST <= CMDS_SPR_DRAW;
					end
				end
				
				CMDS_SPR_DRAW: begin
					if (LAST /*&& LAST_SPR_X != SPR_X[18:10]*/) begin
						//LAST_SPR_X <= SPR_X[18:10];
						SPR_READ <= 1;
						CMD_ST <= CMDS_SPR_READ;
					end
					
					SPR_X <= SPR_X + 9'd1;
					TEXT_X <= TEXT_X + TEXT_DX;
					if (SPR_X == SPR_SX - 1) begin
						SPR_X <= '0;
						SPR_Y <= SPR_Y + 8'd1;
						if (SPR_Y == SPR_SY - 1) begin
							SPR_READ <= 0;
							CMD_ST <= CMDS_END;
						end
						TEXT_X <= '0;
						TEXT_Y <= TEXT_Y + TEXT_DY;
					end
				end
				
				CMDS_POLY_START: begin
					if ($signed(POLY_HL) >= $signed(POLY_HR)) begin
						POLY_H <= POLY_HL[9:0];
						DIV_A <= POLY_HR;
						DIV_B <= POLY_HL;
						CMD_ST <= CMDS_POLY_CALCDR;
					end else begin
						POLY_H <= POLY_HR[9:0];
						DIV_A <= POLY_HL;
						DIV_B <= POLY_HR;
						CMD_ST <= CMDS_POLY_CALCDL;
					end
					POLY_PY <= '0;
					POLY_L <= '0;
					POLY_R <= '0;
				end
				
				CMDS_POLY_CALCDL: begin
					POLY_DL <= DIV_R;
					POLY_DR <= /*LINE_DIRY ?*/ {11'h001,10'h000} /*: {11'h7FF,10'h000}*/;
					CMD_ST <= CMDS_LINE_START;
				end
				
				CMDS_POLY_CALCDR: begin
					POLY_DL <= /*LINE_DIRX ?*/ {11'h001,10'h000} /*: {11'h7FF,10'h000}*/;
					POLY_DR <= DIV_R;
					CMD_ST <= CMDS_LINE_START;
				end
				
				CMDS_LINE_START: begin
					LINE_SX <= $signed(VERTB.X) >= $signed(VERTA.X) ? VERTB.X - VERTA.X : VERTA.X - VERTB.X;
					LINE_SY <= $signed(VERTB.Y) >= $signed(VERTA.Y) ? VERTB.Y - VERTA.Y : VERTA.Y - VERTB.Y;
					LINE_DIRX <= $signed(VERTB.X) >= $signed(VERTA.X);
					LINE_DIRY <= $signed(VERTB.Y) >= $signed(VERTA.Y);
					CMD_ST <= CMDS_LINE_CALCD;
				end
				
				CMDS_LINE_CALCD: begin
					if ($signed(LINE_SX) >= $signed(LINE_SY)) begin
						LINE_L <= LINE_SX[9:0];
						DIV_A <= LINE_SY;
						DIV_B <= LINE_SX;
						CMD_ST <= CMDS_LINE_CALCDY;
					end else begin
						LINE_L <= LINE_SY[9:0];
						DIV_A <= LINE_SX;
						DIV_B <= LINE_SY;
						CMD_ST <= CMDS_LINE_CALCDX;
					end
					LINE_POS <= '0;
					LINE_X <= '0;
					LINE_Y <= '0;
				end
				
				CMDS_LINE_CALCDX: begin
					LINE_DX <= DIV_R;
					LINE_DY <= LINE_DIRY ? {11'h001,10'h000} : {11'h7FF,10'h000};
					CMD_ST <= CMDS_LINE_DRAW;
				end
				
				CMDS_LINE_CALCDY: begin
					LINE_DX <= LINE_DIRX ? {11'h001,10'h000} : {11'h7FF,10'h000};
					LINE_DY <= DIV_R;
					CMD_ST <= CMDS_LINE_DRAW;
				end
				
				CMDS_LINE_DRAW: begin
					LINE_X <= LINE_X + LINE_DX;
					LINE_Y <= LINE_Y + LINE_DY;
					LINE_POS <= LINE_POS + 10'd1;
					if (LINE_POS == LINE_L - 1) begin
						POLY_L <= POLY_L + POLY_DL;
						POLY_R <= POLY_R + POLY_DR;
						POLY_PY <= POLY_PY + 10'd1;
						if (POLY_PY == POLY_H - 1 || CMD.CMDCTRL.COMM == 4'h6) begin
							CMD_ST <= CMDS_END;
						end else begin
							CMD_ST <= CMDS_LINE_NEXT;
						end
//						CMD_ST <= CMDS_END;
					end
				end
				
				CMDS_LINE_NEXT: begin
					VERTA.X <= CMD.CMDXA.COORD;
					VERTA.Y <= CMD.CMDYA.COORD + POLY_L[20:10];
					VERTB.X <= CMD.CMDXB.COORD;
					VERTB.Y <= CMD.CMDYB.COORD + POLY_R[20:10];
					CMD_ST <= CMDS_LINE_START;
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
	
	always_comb begin
		bit        TP;
		bit [15:0] ORIG_C;
		bit [15:0] CALC_C;
		
		PAT_C = GetPattern(TEXT_PAT, CMD.CMDPMOD.CM, TEXT_X[11:10] ^ {2{CMD.CMDCTRL.DIR[0]}});
		if (!CMD.CMDCTRL.COMM[2]) begin
			case (CMD.CMDPMOD.CM)
				3'b000: begin ORIG_C = {CMD.CMDCOLR[15:4],PAT_C[3:0]}; LAST = &TEXT_X[11:10]; end
				3'b001: begin ORIG_C = CLT_Q;                          LAST = &TEXT_X[11:10]; end
				3'b010: begin ORIG_C = {CMD.CMDCOLR[15:6],PAT_C[5:0]}; LAST = TEXT_X[10]; end
				3'b011: begin ORIG_C = {CMD.CMDCOLR[15:7],PAT_C[6:0]}; LAST = TEXT_X[10]; end
				3'b100: begin ORIG_C = {CMD.CMDCOLR[15:8],PAT_C[7:0]}; LAST = TEXT_X[10]; end
				3'b101: begin ORIG_C = PAT_C;                          LAST = 1; end
				default:begin ORIG_C = '0;                             LAST = 1; end
			endcase
			TP = ~|PAT_C;
			DRAW_X = {1'b0,LOC_COORD.X} + VERTA.X + {2'b00,SPR_X};
			DRAW_Y = {2'b00,LOC_COORD.Y} + VERTA.Y + {3'b000,SPR_Y};
		end else begin
			ORIG_C = CMD.CMDCOLR;
			LAST = 1;
			TP = 1;
			DRAW_X = {1'b0,LOC_COORD.X} + VERTA.X + LINE_X[20:10];
			DRAW_Y = {2'b00,LOC_COORD.Y} + VERTA.Y + LINE_Y[20:10];
		end
		CALC_C = ColorCalc(ORIG_C,FB_DRAW_Q,CMD.CMDPMOD.CCB);
					
		SCLIP = !DRAW_X[10] && DRAW_X[9:0] <= SYS_CLIP.X2 && !DRAW_Y[10] && !DRAW_Y[9] && DRAW_Y[8:0] <= SYS_CLIP.Y2;
		UCLIP = !DRAW_X[10] && DRAW_X[9:0] >= USR_CLIP.X1 && DRAW_X[9:0] <= USR_CLIP.X2 && !DRAW_Y[10] && !DRAW_Y[9] && DRAW_Y[8:0] >= USR_CLIP.Y1 && DRAW_Y[8:0] <= USR_CLIP.Y2;
		FB_DRAW_A = {DRAW_Y[7:0],DRAW_X[8:0]};
		FB_DRAW_D = CALC_C;
		FB_DRAW_WE = (CMD_ST == CMDS_SPR_DRAW || CMD_ST == CMDS_LINE_DRAW) & (~TP | CMD.CMDPMOD.SPD) & SCLIP & (UCLIP | ~CMD.CMDPMOD.CLIP);
		
		
		SPR_ADDR = SprAddr(TEXT_X[18:10],TEXT_Y[17:10],CMD.CMDSIZE,CMD.CMDCTRL.DIR,CMD.CMDSRCA,CMD.CMDPMOD.CM);
		CLT_ADDR = {CMD.CMDCOLR,2'b00};
		CLT_RA = PAT_C[3:0];
		ORIG_C_DBG = ORIG_C;
	end
	
	//FB out
	bit [8:0] OUT_X;
	bit [7:0] OUT_Y;
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
				FB_DISP_A <= {OUT_Y,OUT_X};
			end
			
			HTIM_N_OLD <= HTIM_N;
			if (HTIM_N && !HTIM_N_OLD && VTIM_N) begin
				OUT_X <= '0;
				OUT_Y <= OUT_Y + 8'd1;
			end
			
			VTIM_N_OLD <= VTIM_N;
			if (VTIM_N && !VTIM_N_OLD) begin
				OUT_Y <= '0;
			end
		end
	end
	
//	assign FB_DISP_A = {OUT_Y,OUT_X};
	assign VOUT = FB_DISP_Q;
		
	
	//VRAM
	wire CPU_VRAM_SEL = (A[20:19] == 2'b00) & ~DTEN_N & ~AD_N & ~CS_N;	//000000-07FFFF
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
			
			case (VRAM_ST)
				VS_IDLE: begin
					if (VRAM_ACCESS_PEND) begin
//						VRAM_ACCESS_PEND <= 0;
//						IO_DATA_PEND <= 0;
						VRAM_A <= A[18:1];
						VRAM_D <= DI;
						VRAM_WE <= ~WE_N;
						VRAM_RD <= &WE_N;
						VRAM_ST <= VS_CPU_READ;
					end else if (CMD_READ_PEND) begin
						CMD_READ_PEND <= 0;
//						CMD_DATA_PEND <= 0;
						VRAM_A <= CMD_ADDR;
						VRAM_WE <= '0;
						VRAM_RD <= 1;
						VRAM_ST <= VS_CMD_READ;
					end else if (SPR_READ_PEND) begin
						SPR_READ_PEND <= 0;
						PAT_DATA_PEND <= 0;
						VRAM_A <= {SPR_ADDR[18:2],1'b0};
						VRAM_WE <= '0;
						if (VRAM_A[18:2] != SPR_ADDR[18:2]) begin
							VRAM_RD <= 1;
							VRAM_ST <= VS_PAT_READ;
						end else begin
							VRAM_DONE <= 1;
						end
					end else if (CLT_READ_PEND) begin
						CLT_DATA_PEND <= 0;
						CLT_READ_PEND <= 0;
						VRAM_A <= CLT_ADDR;
						VRAM_WE <= '0;
						VRAM_RD <= 1;
						VRAM_ST <= VS_CLT_READ;
					end
					if (VRAM_DONE && CE_R) VRAM_DONE <= 0;
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
					if (VRAM_ARDY) begin
						VRAM_RD <= 0;
						PAT_DATA_PEND <= 1;
						LAST_DATA <= 1;
						VRAM_ST <= VS_IDLE;
					end
				end
				
//				VS_END: begin
//					VRAM_DONE <= 1;
//					VRAM_ST <= VS_IDLE;
//				end
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
	
//	wire TEXT_FIFO_WR = (VRAM_ST == VS_PAT_READ) & VRAM_RDY & !VRAM_RD & CE_R;
//	VDP1_FIFO TEXT_FIFO(.clock(CLK), .data(VRAM_Q), .wrreq(TEXT_FIFO_WR), .rdreq(TEXT_FIFO_RD), .q(TEXT_FIFO_Q), .empty(), .full(TEXT_FIFO_FULL));


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
		bit        FRAME_CHANGE_PEND;
		
		if (!RST_N) begin
			TVMR <= '0;
			FBCR <= '0;
			PTMR <= '0;
			EWDR <= '0;
			EWLR <= '0;
			EWRR <= '0;
			ENDR <= '0;
			EDSR <= '0;
			
			REG_DO <= '0;
			A <= '0;
			
			FRAME_CHANGE_PEND <= 0;
			
			FRAMES_DBG <= '0;
		end else if (!RES_N) begin
				
		end else begin
			if (!CS_N && DTEN_N && AD_N && CE_R) begin
				A <= {A[4:0],DI};
			end
			
			if (REG_SEL) begin
				if (!(&WE_N) && CE_R) begin
					case ({A[5:1],1'b0})
						5'h00: TVMR <= DI & TVMR_MASK;
						5'h02: FBCR <= DI & FBCR_MASK;
						5'h04: PTMR <= DI & PTMR_MASK;
						5'h06: EWDR <= DI & EWDR_MASK;
						5'h08: EWLR <= DI & EWLR_MASK;
						5'h0A: EWRR <= DI & EWRR_MASK;
						5'h0C: ENDR <= DI & ENDR_MASK;
						default:;
					endcase
					if (A[5:1] == 5'h02>>1 && DI[0]) FRAME_CHANGE_PEND <= 1;
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
			if (VTIM_N && !VTIM_N_OLD) begin
				if (!FBCR.FCM) begin
					FB_SEL <= ~FB_SEL;
					FRAME_START <= 1;
					EDSR.CEF <= 0;
					EDSR.BEF <= EDSR.CEF;
					FRAMES_DBG <= FRAMES_DBG + 16'd1;
				end else if (FBCR.FCT) begin
					if (FRAME_CHANGE_PEND) begin
						FB_SEL <= ~FB_SEL;
						FRAME_START <= 1;
						EDSR.CEF <= 0;
						EDSR.BEF <= EDSR.CEF;
						FRAME_CHANGE_PEND <= 0;
						FRAMES_DBG <= FRAMES_DBG + 16'd1;
					end
				end
			end
			
			if (CMD_ST == CMDS_END && CMD.CMDCTRL.END && !EDSR.CEF) EDSR.CEF <= 1;
		end
	end
	
	assign DO = REG_SEL ? REG_DO : IO_VRAM_DO;
	assign RDY_N = ~((CPU_VRAM_SEL & CPU_VRAM_RDY) | REG_SEL);
	
	assign IRQ_N = ~EDSR.CEF;

	assign REG_DBG = TVMR^FBCR^PTMR;
	
endmodule
