import VDP1_PKG::*;
	
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
	output            FB1_RD
);

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
	bit  [8:0] SPR_X;
	bit  [7:0] SPR_Y;
	bit [15:0] SPR_PAT;
	
	bit [20:0] A;
	
	typedef enum bit [4:0] {
		VS_IDLE    = 5'b00001,  
		VS_CPU_READ= 5'b00010,
		VS_CMD_READ= 5'b00100,
		VS_PAT_READ= 5'b01000,
		VS_END     = 5'b10000
	} VRAMState_t;
	VRAMState_t VRAM_ST;
	bit [15:0] VRAM_DO;
	bit        VRAM_DONE;
	bit        VRAM_ACCESS_PEND;
	
	typedef enum {
		CMDS_IDLE,  
		CMDS_READ, 
		CMDS_EXEC,
		CMDS_NSPR,
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
	
	
	always @(posedge CLK or negedge RST_N) begin
		bit        VTIM_N_OLD;
	   bit [18:1] NEXT_ADDR;
		
		if (!RST_N) begin
			CMD_ST <= CMDS_IDLE;
			CMD_ADDR <= '0;
			CMD_READ <= 0;
			SPR_ADDR <= '0;
			SPR_READ <= 0;
			SYS_CLIP <= CLIP_NULL;
			USR_CLIP <= CLIP_NULL;
			LOC_COORD <= COORD_NULL;
			SPR_VERTA <= VERT_NULL;
			
			EDSR <= '0;
			LOPR <= '0;
			COPR <= '0;
			
			VTIM_N_OLD <= 1;
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
								SPR_SRCA <= {CMD.CMDSRCA,2'b00};
								SPR_X <= '0;
								SPR_Y <= '0;
//								CMD_ST <= CMDS_NSPR;
							end
							4'h8: USR_CLIP <= {CMD.CMDXA.COORD[9:0],CMD.CMDYA.COORD[8:0],CMD.CMDXC.COORD[9:0],CMD.CMDYC.COORD[8:0]};
							4'h9: SYS_CLIP <= {10'h000,9'h000,CMD.CMDXC.COORD[9:0],CMD.CMDYC.COORD[8:0]};
							4'hA: LOC_COORD <= {CMD.CMDXA.COORD[9:0],CMD.CMDYA.COORD[8:0]};
						endcase
						
					end
					if (CMD.CMDCTRL.END) EDSR.CEF <= 1;
				end
				
				CMDS_NSPR: begin
					SPR_X <= SPR_X + 9'd1;
					if (SPR_X == {CMD.CMDSIZE.SX,3'b111}) begin
						SPR_X <= '0;
						SPR_Y <= SPR_Y + 8'd1;
						if (SPR_Y == CMD.CMDSIZE.SY) begin
							CMD_ST <= CMDS_END;
						end
					end
					SPR_ADDR <= SPR_SRCA + {2'b00,SPR_Y,SPR_X[8:2]};
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
					
//					if (VRAM_DONE) begin 
						
						CMD_ST <= CMDS_NSPR;
//					end
				end
				
				CMDS_END: begin
					NEXT_ADDR = CMD_ADDR + 18'd16;
					case (CMD.CMDCTRL.JP[1:0])
						2'b00: CMD_ADDR <= NEXT_ADDR;
						2'b01: CMD_ADDR <= {CMD.CMDLINK,2'b00};
						2'b10: begin CMD_ADDR <= {CMD.CMDLINK,2'b00}; CMD_JRET <= NEXT_ADDR; end
						2'b11: CMD_ADDR <= CMD_JRET;
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
				EDSR.CEF <= 0;
				EDSR.BEF <= EDSR.CEF;
				CMD_ST <= CMDS_READ;
			end
		end
	end
	
	wire CPU_VRAM_SEL = (A[20:19] == 2'b00) & ~DTEN_N & ~AD_N & ~CS_N;	//000000-07FFFF
	always @(posedge CLK or negedge RST_N) begin
		bit       VRAM_SEL_OLD;
		bit       CMD_READ_PEND;
		
		if (!RST_N) begin
			VRAM_ST <= VS_IDLE;
			VRAM_A <= '0;
			VRAM_D <= '0;
			VRAM_WE <= '0;
			VRAM_RD <= 0;
			VRAM_DONE <= 0;
			VRAM_ACCESS_PEND <= 0;
			CMD_READ_PEND <= 0;
			CMD <= '0;
		end
		else if (CE_R) begin
			VRAM_SEL_OLD <= CPU_VRAM_SEL;
			if (CPU_VRAM_SEL && !VRAM_SEL_OLD) VRAM_ACCESS_PEND <= 1;
			if (CMD_READ) CMD_READ_PEND <= 1;
			
			case (VRAM_ST)
				VS_IDLE: begin
					if (VRAM_ACCESS_PEND) begin
						VRAM_ACCESS_PEND <= 0;
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
					end
					VRAM_DONE <= 0;
				end
				
				VS_CPU_READ: begin
					if (VRAM_RDY) begin
						VRAM_DO <= VRAM_Q;
						VRAM_WE <= '0;
						VRAM_RD <= 0;
						VRAM_ST <= VS_IDLE;
					end
				end
					
				VS_CMD_READ: begin
					VRAM_RD <= 0;
					if (VRAM_RDY && !VRAM_RD) begin
						VRAM_A <= VRAM_A + 18'd1;
						case ({VRAM_A[4:1],1'b0})
							5'h00: CMD.CMDCTRL <= VRAM_Q;
							5'h02: CMD.CMDLINK <= VRAM_Q;
							5'h04: CMD.CMDPMOD <= VRAM_Q;
							5'h06: CMD.CMDCOLR <= VRAM_Q;
							5'h08: CMD.CMDSRCA <= VRAM_Q;
							5'h0A: CMD.CMDSIZE <= VRAM_Q;
							5'h0C: CMD.CMDXA   <= VRAM_Q;
							5'h0E: CMD.CMDYA   <= VRAM_Q;
							5'h10: CMD.CMDXB   <= VRAM_Q;
							5'h12: CMD.CMDYB   <= VRAM_Q;
							5'h14: CMD.CMDXC   <= VRAM_Q;
							5'h16: CMD.CMDYC   <= VRAM_Q;
							5'h18: CMD.CMDXD   <= VRAM_Q;
							5'h1A: CMD.CMDYD   <= VRAM_Q;
							5'h1C: CMD.CMDGRDA <= VRAM_Q;
							5'h1E: CMD.UNUSED  <= '0;
						endcase
						if ({VRAM_A[4:1],1'b0} == 5'h1E) begin
							VRAM_ST <= VS_END;
						end else
							VRAM_RD <= 1;
					end
				end
				
				VS_PAT_READ: begin
					VRAM_RD <= 0;
					if (VRAM_RDY && !VRAM_RD) begin
						 PAT <= VRAM_Q;
						 VRAM_ST <= VS_END;
					end
				end
				
				VS_END: begin
					VRAM_DONE <= 1;
					VRAM_ST <= VS_IDLE;
				end
			endcase
		end
	end


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
	wire REG_SEL = A[20:19] == 2'b10 && !DTEN_N && !AD_N && !CS_N;
	
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
			if (!CS_N && !DTEN_N && CE_R) begin
				if (AD_N) begin
					A <= {A[4:0],DI};
				end else begin
				
				end
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
