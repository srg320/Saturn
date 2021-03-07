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
	input      [15:0] VRAM_Q,
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
	
	output     [15:0] ORIG_C_DBG
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

	CMDTBL_t   CMD;
	bit [18:1] CMD_JRET;
	Clip_t     SYS_CLIP;
	Clip_t     USR_CLIP;
	Coord_t    LOC_COORD;
	Vertex_t   SPR_VERTA;
	bit [18:1] SPR_SRCA;
	bit [18:0] TEXT_X;
	bit [17:0] TEXT_Y;
	bit [18:0] TEXT_DX;
	bit [17:0] TEXT_DY;
	bit  [8:0] SPR_X;
	bit  [7:0] SPR_Y;
	bit  [8:0] SPR_SX;
	bit  [7:0] SPR_SY;
	bit [15:0] SPR_PAT;
	
	//Color lookup table
	bit  [3:0] CLT_WA;
	bit [15:0] CLT_D;
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
	bit [15:0] VRAM_DO;
	bit        VRAM_DONE;
	bit        VRAM_ACCESS_PEND;
	
	typedef enum bit [3:0] {
		CMDS_IDLE,  
		CMDS_READ, 
		CMDS_EXEC,
		CMDS_NSPR,
		CMDS_CLT_LOAD,
		CMDS_SPR_START,
		CMDS_SPR_CALCX,
		CMDS_SPR_CALCY,
		CMDS_SPR_READ,
		CMDS_SPR_DRAW,
		CMDS_END
	} CMDState_t;
	CMDState_t CMD_ST;
	bit [18:1] CMD_ADDR;
	bit        CMD_READ;
	bit [18:1] SPR_ADDR;
	bit        SPR_READ;
	bit [15:0] PAT;
	bit [18:1] CLT_ADDR;
	bit        CLT_READ;
	
	//Divider
	bit  [9:0] DIV_A;
	bit  [9:0] DIV_B;
	bit [19:0] DIV_Q;
	bit  [9:0] DIV_R;
//	VDP1_DIV DIV(.numer({DIV_A,10'h000}), .denom(DIV_B), .quotient(DIV_Q), .remain(DIV_R));
	assign DIV_Q = {DIV_A / DIV_B,DIV_A % DIV_B};
	
	bit [10:0] DRAW_X;////
	bit [10:0] DRAW_Y;////
	bit        SCLIP;////
	bit        UCLIP;////
	bit [15:0] PAT_C;////
	bit        LAST;
	always @(posedge CLK or negedge RST_N) begin
		bit        VTIM_N_OLD;
	   bit [18:1] NEXT_ADDR;
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
			SPR_VERTA <= VERT_NULL;
			
			EDSR <= '0;
			LOPR <= '0;
			COPR <= '0;
			
			VTIM_N_OLD <= 1;
			LAST_SPR_X <= '1;
		end
		else if (CE_R) begin
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
							4'h0: begin
								SPR_VERTA <= {CMD.CMDXA.COORD,CMD.CMDYA.COORD};
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
							4'h1: begin
								case (CMD.CMDCTRL.ZP[1:0])
									2'b00: SPR_VERTA.X <= CMD.CMDXA.COORD;
									2'b01: SPR_VERTA.X <= CMD.CMDXA.COORD;
									2'b10: SPR_VERTA.X <= CMD.CMDXA.COORD-(CMD.CMDXB.COORD>>>1);
									2'b11: SPR_VERTA.X <= CMD.CMDXA.COORD-CMD.CMDXB.COORD;
								endcase
								case (CMD.CMDCTRL.ZP[3:2])
									2'b00: SPR_VERTA.Y <= CMD.CMDYA.COORD;
									2'b01: SPR_VERTA.Y <= CMD.CMDYA.COORD;
									2'b10: SPR_VERTA.Y <= CMD.CMDYA.COORD-(CMD.CMDYB.COORD>>>1);
									2'b11: SPR_VERTA.Y <= CMD.CMDYA.COORD-CMD.CMDYB.COORD;
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
									SPR_READ <= 1;
									CMD_ST <= CMDS_SPR_START;
								end
							end
							4'h8: USR_CLIP <= {CMD.CMDXA.COORD[9:0],CMD.CMDYA.COORD[8:0],CMD.CMDXC.COORD[9:0],CMD.CMDYC.COORD[8:0]};
							4'h9: SYS_CLIP <= {10'h000,9'h000,CMD.CMDXC.COORD[9:0],CMD.CMDYC.COORD[8:0]};
							4'hA: LOC_COORD <= {CMD.CMDXA.COORD[9:0],CMD.CMDYA.COORD[8:0]};
						endcase
					end
					if (CMD.CMDCTRL.END) EDSR.CEF <= 1;
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
					DIV_A <= {1'b0,CMD.CMDSIZE.SX,3'b000};
					DIV_B <= SPR_SX;
					CMD_ST <= CMDS_SPR_CALCX;
				end
				
				CMDS_SPR_CALCX: begin
					TEXT_DX <= DIV_Q[18:0];
					DIV_A <= {2'b00,CMD.CMDSIZE.SY};
					DIV_B <= SPR_SY;
					CMD_ST <= CMDS_SPR_CALCY;
				end
				
				CMDS_SPR_CALCY: begin
					TEXT_DY <= DIV_Q[17:0];
					SPR_READ <= 1;
					CMD_ST <= CMDS_SPR_READ;
				end
				
				CMDS_SPR_READ: begin
					SPR_READ <= 0;
					if (VRAM_DONE) begin 
						SPR_PAT <= PAT;
						CMD_ST <= CMDS_SPR_DRAW;
					end
				end
				
				CMDS_SPR_DRAW: begin
//					case (CMD.CMDPMOD.CM)
//						3'b000: begin ORIG_C = {CMD.CMDCOLR[15:4],PAT_C[3:0]}; LAST = &TEXT_X[11:10]; end
//						3'b001: begin ORIG_C = CLT_Q;                          LAST = &TEXT_X[11:10]; end
//						3'b010: begin ORIG_C = {CMD.CMDCOLR[15:6],PAT_C[5:0]}; LAST = TEXT_X[10]; end
//						3'b011: begin ORIG_C = {CMD.CMDCOLR[15:7],PAT_C[6:0]}; LAST = TEXT_X[10]; end
//						3'b100: begin ORIG_C = {CMD.CMDCOLR[15:8],PAT_C[7:0]}; LAST = TEXT_X[10]; end
//						3'b101: begin ORIG_C = PAT_C;                          LAST = 1; end
//						default:begin ORIG_C = '0;                             LAST = 1; end
//					endcase
//					ORIG_C_DBG = ORIG_C;
//					CALC_C = ColorCalc(ORIG_C,FB_DRAW_Q,CMD.CMDPMOD.CCB);
//					TP = ~|PAT_C;
					
//					DRAW_X = {1'b0,LOC_COORD.X} + SPR_VERTA.X + {2'b00,SPR_X};
//					DRAW_Y = {2'b00,LOC_COORD.Y} + SPR_VERTA.Y + {3'b000,SPR_Y};
//					SCLIP = !DRAW_X[10] && DRAW_X[9:0] <= SYS_CLIP.X2 && !DRAW_Y[10] && !DRAW_Y[9] && DRAW_Y[8:0] <= SYS_CLIP.Y2;
//					UCLIP = !DRAW_X[10] && DRAW_X[9:0] >= USR_CLIP.X1 && DRAW_X[9:0] <= USR_CLIP.X2 && !DRAW_Y[10] && !DRAW_Y[9] && DRAW_Y[8:0] >= USR_CLIP.Y1 && DRAW_Y[8:0] <= USR_CLIP.Y2;
					
//					FB_DRAW_A <= {DRAW_Y[7:0],DRAW_X[8:0]};
//					FB_DRAW_D <= CALC_C;
//					FB_DRAW_WE <= (~TP | CMD.CMDPMOD.SPD) & SCLIP & (UCLIP | ~CMD.CMDPMOD.CLIP);

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
			
			VTIM_N_OLD <= VTIM_N;
			if (VTIM_N && !VTIM_N_OLD) begin
				CMD_ADDR <= '0;
				CMD_READ <= 1;
				SPR_READ <= 0;
				CLT_READ <= 0;
				EDSR.CEF <= 0;
				EDSR.BEF <= EDSR.CEF;
				CMD_ST <= CMDS_READ;
			end
		end
	end
	
	always_comb begin
		bit        TP;
		bit [15:0] ORIG_C;
		bit [15:0] CALC_C;
		
		SPR_ADDR = SprAddr(TEXT_X[18:10],TEXT_Y[17:10],CMD.CMDSIZE,CMD.CMDCTRL.DIR,CMD.CMDSRCA,CMD.CMDPMOD.CM);
		CLT_ADDR = {CMD.CMDCOLR,2'b00};
		CLT_RA = PAT_C[3:0];
		
		PAT_C = GetPattern(SPR_PAT, CMD.CMDPMOD.CM, TEXT_X[11:10] ^ {2{CMD.CMDCTRL.DIR[0]}});
		case (CMD.CMDPMOD.CM)
			3'b000: begin ORIG_C = {CMD.CMDCOLR[15:4],PAT_C[3:0]}; LAST = &TEXT_X[11:10]; end
			3'b001: begin ORIG_C = CLT_Q;                          LAST = &TEXT_X[11:10]; end
			3'b010: begin ORIG_C = {CMD.CMDCOLR[15:6],PAT_C[5:0]}; LAST = TEXT_X[10]; end
			3'b011: begin ORIG_C = {CMD.CMDCOLR[15:7],PAT_C[6:0]}; LAST = TEXT_X[10]; end
			3'b100: begin ORIG_C = {CMD.CMDCOLR[15:8],PAT_C[7:0]}; LAST = TEXT_X[10]; end
			3'b101: begin ORIG_C = PAT_C;                          LAST = 1; end
			default:begin ORIG_C = '0;                             LAST = 1; end
		endcase
		CALC_C = ColorCalc(ORIG_C,FB_DRAW_Q,CMD.CMDPMOD.CCB);
		TP = ~|PAT_C;
					
		DRAW_X = {1'b0,LOC_COORD.X} + SPR_VERTA.X + {2'b00,SPR_X};
		DRAW_Y = {2'b00,LOC_COORD.Y} + SPR_VERTA.Y + {3'b000,SPR_Y};
		SCLIP = !DRAW_X[10] && DRAW_X[9:0] <= SYS_CLIP.X2 && !DRAW_Y[10] && !DRAW_Y[9] && DRAW_Y[8:0] <= SYS_CLIP.Y2;
		UCLIP = !DRAW_X[10] && DRAW_X[9:0] >= USR_CLIP.X1 && DRAW_X[9:0] <= USR_CLIP.X2 && !DRAW_Y[10] && !DRAW_Y[9] && DRAW_Y[8:0] >= USR_CLIP.Y1 && DRAW_Y[8:0] <= USR_CLIP.Y2;
		FB_DRAW_A = {DRAW_Y[7:0],DRAW_X[8:0]};
		FB_DRAW_D = CALC_C;
		FB_DRAW_WE = (CMD_ST == CMDS_SPR_DRAW) & (~TP | CMD.CMDPMOD.SPD) & SCLIP & (UCLIP | ~CMD.CMDPMOD.CLIP);
		
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
				FB_SEL <= ~FB_SEL;
			end
		end
	end
	
//	assign FB_DISP_A = {OUT_Y,OUT_X};
	assign VOUT = FB_DISP_Q;
		
	
	//VRAM
	wire CPU_VRAM_SEL = (A[20:19] == 2'b00) & ~DTEN_N & ~AD_N & ~CS_N;	//000000-07FFFF
	bit [18:1] VRAM_LAST_A;
	bit [15:0] VRAM_LAST_Q;
	always @(posedge CLK or negedge RST_N) begin
		bit        VRAM_SEL_OLD;
		bit        CMD_READ_PEND;
		bit        SPR_READ_PEND;
		bit        CLT_READ_PEND;
		bit        VTIM_N_OLD;
		
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
//			if (CE_R) begin
			VRAM_SEL_OLD <= CPU_VRAM_SEL;
			if (CPU_VRAM_SEL && !VRAM_SEL_OLD) VRAM_ACCESS_PEND <= 1;
			if (CMD_READ && !CMD_READ_PEND) CMD_READ_PEND <= 1;
			if (SPR_READ && !SPR_READ_PEND) SPR_READ_PEND <= 1;
			if (CLT_READ && !CLT_READ_PEND) CLT_READ_PEND <= 1;
//			end
			
			VRAM_LAST_Q <= VRAM_Q;
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
					end else if (SPR_READ_PEND/*SPR_READ && !TEXT_FIFO_FULL*/) begin
						SPR_READ_PEND <= 0;
						VRAM_A <= SPR_ADDR;
						VRAM_WE <= '0;
						VRAM_RD <= 1;
						VRAM_ST <= VS_PAT_READ;
					end else if (CLT_READ_PEND) begin
						CLT_READ_PEND <= 0;
						VRAM_A <= CLT_ADDR;
						VRAM_WE <= '0;
						VRAM_RD <= 1;
						VRAM_ST <= VS_CLT_READ;
					end
					if (CE_R) VRAM_DONE <= 0;
				end
				
				VS_CPU_READ: begin
					if (VRAM_RDY) begin
						VRAM_DO <= VRAM_Q;
						VRAM_WE <= '0;
						VRAM_RD <= 0;
						VRAM_ACCESS_PEND <= 0;
						VRAM_ST <= VS_IDLE;
					end
				end
					
				VS_CMD_READ: begin
					if (VRAM_RDY) begin
						VRAM_ST <= VS_CMD_WRITE;
						VRAM_RD <= 0;
					end
				end
				
				VS_CMD_WRITE: begin
					VRAM_A <= VRAM_A + 18'd1;
					case ({VRAM_A[4:1],1'b0})
						5'h00: CMD.CMDCTRL <= VRAM_LAST_Q;
						5'h02: CMD.CMDLINK <= VRAM_LAST_Q;
						5'h04: CMD.CMDPMOD <= VRAM_LAST_Q;
						5'h06: CMD.CMDCOLR <= VRAM_LAST_Q;
						5'h08: CMD.CMDSRCA <= VRAM_LAST_Q;
						5'h0A: CMD.CMDSIZE <= VRAM_LAST_Q;
						5'h0C: CMD.CMDXA   <= VRAM_LAST_Q;
						5'h0E: CMD.CMDYA   <= VRAM_LAST_Q;
						5'h10: CMD.CMDXB   <= VRAM_LAST_Q;
						5'h12: CMD.CMDYB   <= VRAM_LAST_Q;
						5'h14: CMD.CMDXC   <= VRAM_LAST_Q;
						5'h16: CMD.CMDYC   <= VRAM_LAST_Q;
						5'h18: CMD.CMDXD   <= VRAM_LAST_Q;
						5'h1A: CMD.CMDYD   <= VRAM_LAST_Q;
						5'h1C: CMD.CMDGRDA <= VRAM_LAST_Q;
						5'h1E: CMD.UNUSED  <= '0;
					endcase
					if ({VRAM_A[4:1],1'b0} == 5'h1C) begin
						VRAM_DONE <= 1;
						VRAM_ST <= VS_IDLE;
					end else begin
						VRAM_RD <= 1;
						VRAM_ST <= VS_CMD_READ;
					end
				end
				
				VS_CLT_READ: begin
					if (VRAM_RDY) begin
						VRAM_RD <= 0;
						VRAM_ST <= VS_CLT_WRITE;
					end
				end
				
				VS_CLT_WRITE: begin
					VRAM_A <= VRAM_A + 18'd1;
					if ({VRAM_A[4:1],1'b0} == 5'h1E) begin
						VRAM_DONE <= 1;
						VRAM_ST <= VS_IDLE;
					end else begin
						VRAM_RD <= 1;
						VRAM_ST <= VS_CLT_READ;
					end
				end
				
				VS_PAT_READ: begin
					if (VRAM_RDY) begin
						VRAM_RD <= 0;
						PAT <= VRAM_Q;
						VRAM_DONE <= 1;
						VRAM_ST <= VS_IDLE;
					end
				end
				
				VS_END: begin
					VRAM_DONE <= 1;
					VRAM_ST <= VS_IDLE;
				end
			endcase
			
			VTIM_N_OLD <= VTIM_N;
			if (VTIM_N && !VTIM_N_OLD) begin
				CMD_READ_PEND <= 0;
				SPR_READ_PEND <= 0;
				CLT_READ_PEND <= 0;
				VRAM_ST <= VS_IDLE;
			end
		end
	end
	
	assign CLT_WA = VRAM_A[4:1];
	assign CLT_D = VRAM_LAST_Q;
	assign CLT_WE = (VRAM_ST == VS_CLT_WRITE);
//	assign CLT_RA = SPR_PAT[15:12];
	COL_TBL CLT(.CLK(CLK), .WRADDR(CLT_WA), .DATA(CLT_D), .WREN(CLT_WE), .RDADDR(CLT_RA), .Q(CLT_Q));
	
//	wire TEXT_FIFO_WR = (VRAM_ST == VS_PAT_READ) & VRAM_RDY & !VRAM_RD & CE_R;
//	VDP1_FIFO TEXT_FIFO(.clock(CLK), .data(VRAM_Q), .wrreq(TEXT_FIFO_WR), .rdreq(TEXT_FIFO_RD), .q(TEXT_FIFO_Q), .empty(), .full(TEXT_FIFO_FULL));


	bit CPU_VRAM_RDY;
	always @(posedge CLK or negedge RST_N) begin
		bit VRAM_SEL_OLD;
		bit VRAM_PEND_OLD;
		
		if (!RST_N) begin
			CPU_VRAM_RDY <= 1;
		end
		else begin
			VRAM_SEL_OLD <= CPU_VRAM_SEL;
			VRAM_PEND_OLD <= VRAM_ACCESS_PEND;
			if (CPU_VRAM_SEL && !VRAM_SEL_OLD && CPU_VRAM_RDY) 
				CPU_VRAM_RDY <= 0;
			else if (!VRAM_ACCESS_PEND && VRAM_PEND_OLD && !CPU_VRAM_RDY) 
				CPU_VRAM_RDY <= 1;
		end
	end


	//Registers
	wire REG_SEL = (A[20:19] == 2'b10) & ~DTEN_N & ~AD_N & ~CS_N;
	
	assign MODR = {4'h0,3'b000,PTMR.PTM[1],FBCR.EOS,FBCR.DIE,FBCR.DIL,FBCR.FCM,TVMR.VBE,TVMR.TVM};
	
	bit [15:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		
		if (!RST_N) begin
			TVMR <= '0;
			FBCR <= '0;
			PTMR <= '0;
			EWDR <= '0;
			EWLR <= '0;
			EWRR <= '0;
			ENDR <= '0;

			REG_DO <= '0;
			A <= '0;
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
		end
	end
	
	assign DO = REG_SEL ? REG_DO : VRAM_DO;
	assign RDY_N = ~((CPU_VRAM_SEL & CPU_VRAM_RDY) | REG_SEL);
	
	assign IRQ_N = ~EDSR.CEF;

	
endmodule
