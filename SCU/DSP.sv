module SCU_DSP (
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	
	input       [1:0] A,
	input      [31:0] DI,
	output     [31:0] DO,
	input             WR,
	input             RD,
	
	output reg [26:2] DMA_A,
	input      [31:0] DMA_DI,
	output     [31:0] DMA_DO,
	output            DMA_WR,
	output reg        DMA_REQ,
	input             DMA_ACK,
	
	output            IRQ
	
);
	import SCUDSP_PKG::*;

	//Registers
	ALUReg_t   AC;
	ALUReg_t   P;
	bit [31:0] RX;
	bit [31:0] RY;
	bit  [7:0] PC;
	bit [11:0] LOP;
	bit  [7:0] TOP;
	bit  [5:0] CT0;
	bit  [5:0] CT1;
	bit  [5:0] CT2;
	bit  [5:0] CT3;
	bit [31:0] RA0;
	bit [31:0] WA0;
	bit  [7:0] TN0;
	bit        T0;
	bit        EX;
	bit        EP; 
	bit        PR;
	bit        ES;
	bit        LE;
	bit        E;
	bit        S;
	bit        Z;
	bit        C;
	bit        V;

	bit  [5:0] DATA_RAM_ADDR [4];
	bit [31:0] DATA_RAM_D [4];
	bit        DATA_RAM_WE [4];
	bit [31:0] DATA_RAM_Q [4];
	
	bit  [7:0] PRG_RAM_ADDR;
	bit [31:0] PRG_RAM_D;
	bit        PRG_RAM_WE;
	bit [31:0] PRG_RAM_Q;
	
	bit  [7:0] DATA_TRANS_ADDR;
	bit  [7:0] PRG_TRANS_ADDR;
	
	wire RUN = EX || ES;
	wire DMA_RUN = T0 && DMA_ACK;

	//PRG RAM
	assign PRG_RAM_ADDR = RUN ? PC : PRG_TRANS_ADDR;
	assign PRG_RAM_D = DI;
	assign PRG_RAM_WE = !RUN && A == 2'b01 & WR;
	DSP_SPRAM #(8,32,"","prg.txt") PRG_RAM(CLK, PRG_RAM_ADDR, PRG_RAM_D, PRG_RAM_WE & CE_R, PRG_RAM_Q);
	
	reg [31:0] IC;
	DecInst_t DECI;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			IC <= '0;
		end
		else if (RUN && CE_R) begin
			IC <= PRG_RAM_Q;
		end
	end
	
	wire COND = IC[24] ? ((IC[22]&T0) | (IC[21]&C) | (IC[20]&S) | (IC[19]&Z)) : ((~IC[22]|~T0) & (~IC[21]|~C) & (~IC[20]|~S) & (~IC[19]|~Z));
	assign DECI = Decode(IC, COND);
	
	DMAInst_t  DMAI;
	
	
	//ALU
	ALUReg_t   ALU_Q;
	bit        ALU_C;
	always_comb begin
		{ALU_C,ALU_Q} = {1'b0,AC};
		case (IC[29:26])
			4'b0001: {ALU_C,ALU_Q.L} = {1'b0,AC.L} & {1'b0,P.L};
			4'b0010: {ALU_C,ALU_Q.L} = {1'b0,AC.L} & {1'b0,P.L};
			4'b0011: {ALU_C,ALU_Q.L} = {1'b0,AC.L} | {1'b0,P.L};
			4'b0100: {ALU_C,ALU_Q.L} = {1'b0,AC.L} + {1'b0,P.L};
			4'b0101: {ALU_C,ALU_Q.L} = {1'b0,AC.L} - {1'b0,P.L};
			4'b0110: {ALU_C,ALU_Q  } = {1'b0,AC  } + {1'b0,P  };
			4'b1000: {ALU_Q.L,ALU_C} = {AC.L[31],AC.L};
			4'b1001: {ALU_Q.L,ALU_C} = {AC.L[0],AC.L};
			4'b1010: {ALU_C,ALU_Q.L} = {AC.L,1'b0};
			4'b1011: {ALU_C,ALU_Q.L} = {AC.L,AC.L[31]};
			4'b1111: {ALU_C,ALU_Q.L} = {AC.L[24:0],AC.L[31:24]};
			default: ;
		endcase
	end
	
	always @(posedge CLK or negedge RST_N) begin
		bit S31, S47, ZL, ZH;
		
		if (!RST_N) begin
			S <= 0;
			Z <= 0;
			C <= 0;
			V <= 0;
		end
		else if (CE_R) begin
			if (RUN) begin
				S31 = ALU_Q[31];
				S47 = ALU_Q[47];
				ZL = ~|ALU_Q.L;
				ZH = ~|ALU_Q.H;
				if (DECI.ALU) begin
					case (IC[29:26])
						4'b0001: begin S = S31; Z = ZL;    C = ALU_C; end
						4'b0010: begin S = S31; Z = ZL;    C = ALU_C; end
						4'b0011: begin S = S31; Z = ZL;    C = ALU_C; end
						4'b0100: begin S = S31; Z = ZL;    C = ALU_C; end
						4'b0101: begin S = S31; Z = ZL;    C = ALU_C; end
						4'b0110: begin S = S47; Z = ZL&ZH; C = ALU_C; end
						4'b1000: begin S = S31; Z = ZL;    C = ALU_C; end
						4'b1001: begin S = S31; Z = ZL;    C = ALU_C; end
						4'b1010: begin S = S31; Z = ZL;    C = ALU_C; end
						4'b1011: begin S = S31; Z = ZL;    C = ALU_C; end
						4'b1111: begin S = S31; Z = ZL;    C = ALU_C; end
						default:;
					endcase
					V <= 0;//TODO
				end
			end
			else begin
				if (A == 2'b00 && RD) begin
					V <= 0;
				end
			end
		end
	end
	
	wire [47:0] MUL = RX * RY;


	bit [31:0] D0BUSO;
	bit [31:0] D1BUS;
	bit [31:0] XBUS;
	bit [31:0] YBUS;
	always_comb begin
		bit [31:0] IMM;
		
		IMM = ImmSext(IC, DECI.IMMT);
		
		case (DECI.XBUS.RAMS)
			2'b00: XBUS = DATA_RAM_Q[0];
			2'b01: XBUS = DATA_RAM_Q[1];
			2'b10: XBUS = DATA_RAM_Q[2];
			2'b11: XBUS = DATA_RAM_Q[3];
		endcase
		
		case (DECI.YBUS.RAMS)
			2'b00: YBUS = DATA_RAM_Q[0];
			2'b01: YBUS = DATA_RAM_Q[1];
			2'b10: YBUS = DATA_RAM_Q[2];
			2'b11: YBUS = DATA_RAM_Q[3];
		endcase
		
		if (DECI.D1BUS.IMMS) begin
			D1BUS = IMM;
		end
		else if (DECI.D1BUS.ALUS) begin
			case (DECI.D1BUS.RAMS[0])
				1'b0: D1BUS = {{16{ALU_Q.H[15]}},ALU_Q.H};
				2'b1: D1BUS = ALU_Q.L;
			endcase
		end
		else begin
			case (DECI.D1BUS.RAMS)
				2'b00: D1BUS = DATA_RAM_Q[0];
				2'b01: D1BUS = DATA_RAM_Q[1];
				2'b10: D1BUS = DATA_RAM_Q[2];
				2'b11: D1BUS = DATA_RAM_Q[3];
			endcase
		end
		
		case (DECI.DMA.RAMS)
			2'b00: D0BUSO = DATA_RAM_Q[0];
			2'b01: D0BUSO = DATA_RAM_Q[1];
			2'b10: D0BUSO = DATA_RAM_Q[2];
			2'b11: D0BUSO = DATA_RAM_Q[3];
		endcase
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			RX <= '0;
			RY <= '0;
			AC <= '0;
			P <= '0;
			// synopsys translate_off
			RX <= 32'h11111111;
			RY <= 32'h22222222;
			AC <= 48'h0123456789AB;
			P <= 48'h55AA55AA55AA;
			// synopsys translate_on
		end
		else if (RUN && CE_R) begin
			//X set
			if (DECI.XBUS.RXW) begin
				RX <= XBUS;
			end
			if (DECI.D1BUS.RXW) begin
				RX <= D1BUS;
			end
			
			//Y set
			if (DECI.YBUS.RYW) begin
				RY <= YBUS;
			end
			
			//AC set
			if (DECI.YBUS.ACW) begin
				case (DECI.YBUS.ACS)
					2'b01: AC <= '0;
					2'b10: AC <= ALU_Q;
					2'b11: AC <= {{16{YBUS[31]}},YBUS};
					default:;
				endcase
			end
			
			//P set
			if (DECI.XBUS.PW) begin
				if (DECI.XBUS.MULS) P <= MUL[47:0];
				else P <= {{16{XBUS[31]}},XBUS};
			end
			if (DECI.D1BUS.PW) begin
				P <= {{16{D1BUS[31]}},D1BUS};
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			CT0 <= '0;
			CT1 <= '0;
			CT2 <= '0;
			CT3 <= '0;
			// synopsys translate_off
			CT0 <= 6'h00;
			CT1 <= 6'h11;
			CT2 <= 6'h22;
			CT3 <= 6'h33;
			// synopsys translate_on
		end
		else if (CE_R) begin
			if (RUN) begin
				if (DECI.XBUS.CTI[0] || DECI.YBUS.CTI[0] || DECI.D1BUS.CTI[0] || DECI.DMA.CTI[0]) CT0 <= CT0 + 6'd1;
				if (DECI.D1BUS.CTW[0]) CT0 <= D1BUS[5:0];
				
				if (DECI.XBUS.CTI[1] || DECI.YBUS.CTI[1] || DECI.D1BUS.CTI[1] || DECI.DMA.CTI[1]) CT1 <= CT1 + 6'd1;
				if (DECI.D1BUS.CTW[1]) CT1 <= D1BUS[5:0];
				
				if (DECI.XBUS.CTI[2] || DECI.YBUS.CTI[2] || DECI.D1BUS.CTI[2] || DECI.DMA.CTI[2]) CT2 <= CT2 + 6'd1;
				if (DECI.D1BUS.CTW[2]) CT2 <= D1BUS[5:0];
				
				if (DECI.XBUS.CTI[3] || DECI.YBUS.CTI[3] || DECI.D1BUS.CTI[3] || DECI.DMA.CTI[3]) CT3 <= CT3 + 6'd1;
				if (DECI.D1BUS.CTW[3]) CT3 <= D1BUS[5:0];
			end
			
			if (DMA_RUN) begin
				if (DMAI.RAMW[0]) CT0 <= CT0 + 6'd1;
				if (DMAI.RAMW[1]) CT1 <= CT1 + 6'd1;
				if (DMAI.RAMW[2]) CT2 <= CT2 + 6'd1;
				if (DMAI.RAMW[3]) CT3 <= CT3 + 6'd1;
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			PC <= '0;
			LOP <= '0;
			TOP <= '0;
		end
		else if (CE_R) begin
			if (RUN) begin
				PC <= PC + 8'd1;
				if (DECI.D1BUS.PCW) begin
					PC <= D1BUS[7:0];
					TOP <= PC;
				end
				if (DECI.JPCW) begin
					PC <= IC[7:0];
				end
				if (DECI.CTL.BTM || DECI.CTL.LPS) begin
					if (LOP) begin
						LOP <= LOP - 8'd1;
						if (DECI.CTL.BTM) PC <= TOP;
					end
				end
				
				if (DECI.D1BUS.LOPW) begin
					LOP <= D1BUS[11:0];
				end
				
				if (DECI.D1BUS.TOPW) begin
					TOP <= D1BUS[7:0];
				end
			end
			else begin
				if (A == 2'b00 && WR && LE) begin
					PC <= DI[7:0];
				end
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		bit [7:0] CNT_VAL;
		
		if (!RST_N) begin
			RA0 <= '0;
			WA0 <= '0;
			TN0 <= '0;
			T0 <= 0;
			DMAI <= '{1'b0, 1'b0, 4'b0000, 1'b0, 2'b00, 3'b000, 1'b0, 2'b00, 4'b0000, 1'b0};
			DMA_A <= '0;
			DMA_REQ = 0;
		end
		else if (CE_R) begin
			DMA_REQ = 0;
			if (RUN) begin
				if (DECI.D1BUS.RA0W) begin
					RA0 <= D1BUS;
				end
				
				if (DECI.D1BUS.WA0W) begin
					WA0 <= D1BUS;
				end
				
				if (DECI.DMA.CNTM) begin
					case (DECI.DMA.CNTS)
						2'b00: CNT_VAL = DATA_RAM_Q[0][7:0];
						2'b01: CNT_VAL = DATA_RAM_Q[1][7:0];
						2'b10: CNT_VAL = DATA_RAM_Q[2][7:0];
						2'b11: CNT_VAL = DATA_RAM_Q[3][7:0];
					endcase
				end
				else begin
					CNT_VAL = IC[7:0];
				end
		
				if (DECI.DMA.ST && !T0) begin
					T0 <= 1;
					TN0 <= CNT_VAL;
					DMAI <= DECI.DMA;
					DMA_A <= !DECI.DMA.DIR ? RA0[24:0] : WA0[24:0];
					DMA_REQ = 1;
				end
			end
			
			if (DMA_RUN) begin
				DMA_A <= DMA_A + DMAAddrAdd(DMAI.ADDI);
				if (!DMAI.DIR && !DMAI.HOLD) RA0 <= RA0 + DMAAddrAdd(DMAI.ADDI);
				if (DMAI.DIR && !DMAI.HOLD) WA0 <= WA0 + DMAAddrAdd(DMAI.ADDI);
				if (!TN0) begin
					T0 <= 0;
				end
				else begin
					TN0 <= TN0 - 8'd1;
					DMA_REQ = 1;
				end
			end
		end
	end
	
	assign DMA_DO = D0BUSO;
	assign DMA_WR = DMAI.DIR;
	
	wire [31:0] D0BUSI = DMA_DI;
	
	//DATA RAM
	assign DATA_RAM_ADDR[0] = RUN || DMA_RUN ? CT0 : DATA_TRANS_ADDR[5:0];
	assign DATA_RAM_D[0] = DMA_RUN ? D0BUSI : RUN ? D1BUS : DI;
	assign DATA_RAM_WE[0] = DMA_RUN ? DMAI.RAMW[0] : RUN ? DECI.D1BUS.RAMW[0] : A == 2'b11 & WR && DATA_TRANS_ADDR[7:6] == 2'b00;
	DSP_SPRAM #(6,32) DATA_RAM0(CLK, DATA_RAM_ADDR[0], DATA_RAM_D[0], DATA_RAM_WE[0] & CE_R, DATA_RAM_Q[0]);
	
	assign DATA_RAM_ADDR[1] = RUN || DMA_RUN ? CT1 : DATA_TRANS_ADDR[5:0];
	assign DATA_RAM_D[1] = DMA_RUN ? D0BUSI : RUN ? D1BUS : DI;
	assign DATA_RAM_WE[1] = DMA_RUN ? DMAI.RAMW[1] : RUN ? DECI.D1BUS.RAMW[1] : A == 2'b11 & WR && DATA_TRANS_ADDR[7:6] == 2'b01;
	DSP_SPRAM #(6,32) DATA_RAM1(CLK, DATA_RAM_ADDR[1], DATA_RAM_D[1], DATA_RAM_WE[1] & CE_R, DATA_RAM_Q[1]);
	
	assign DATA_RAM_ADDR[2] = RUN || DMA_RUN ? CT2 : DATA_TRANS_ADDR[5:0];
	assign DATA_RAM_D[2] = DMA_RUN ? D0BUSI : RUN ? D1BUS : DI;
	assign DATA_RAM_WE[2] = DMA_RUN ? DMAI.RAMW[2] : RUN ? DECI.D1BUS.RAMW[2] : A == 2'b11 & WR && DATA_TRANS_ADDR[7:6] == 2'b10;
	DSP_SPRAM #(6,32) DATA_RAM2(CLK, DATA_RAM_ADDR[2], DATA_RAM_D[2], DATA_RAM_WE[2] & CE_R, DATA_RAM_Q[2]);
	
	assign DATA_RAM_ADDR[3] = RUN || DMA_RUN ? CT3 : DATA_TRANS_ADDR[5:0];
	assign DATA_RAM_D[3] = DMA_RUN ? D0BUSI : RUN ? D1BUS : DI;
	assign DATA_RAM_WE[3] = DMA_RUN ? DMAI.RAMW[3] : RUN ? DECI.D1BUS.RAMW[3] : A == 2'b11 & WR && DATA_TRANS_ADDR[7:6] == 2'b11;
	DSP_SPRAM #(6,32) DATA_RAM3(CLK, DATA_RAM_ADDR[3], DATA_RAM_D[3], DATA_RAM_WE[3] & CE_R, DATA_RAM_Q[3]);
	
	//Control port
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			EX <= 0;
			EP <= 0; 
			PR <= 0;
			ES <= 0;
			LE <= 0;
			E <= 0;
			PRG_TRANS_ADDR <= '0;
			DATA_TRANS_ADDR <= '0;
		end
		else begin
			if (WR && CE_R) begin
				case (A)
					2'b00: begin
						EX <= DI[16];
						LE <= DI[15];
						PRG_TRANS_ADDR <= DI[7:0];
						if (EX && !EP && DI[25]) begin
							EP <= 1; 
							PR <= 0;
						end
						if (EX && !PR && DI[26]) begin
							PR <= 1;
							EP <= 0; 
						end
						if (!EX && DI[17]) begin
							ES <= 1;
						end
					end
					2'b01: begin
						PRG_TRANS_ADDR <= PRG_TRANS_ADDR + 8'd1;
					end
					2'b10: begin
						DATA_TRANS_ADDR <= DI[7:0];
					end
					2'b11: begin
						DATA_TRANS_ADDR <= DATA_TRANS_ADDR + 8'd1;
					end
					default:;
				endcase
			end
			
			if (RD && CE_F) begin
				case (A)
					2'b00: DO <= {8'h00,T0,S,Z,C,V,E,1'b0,EX,8'h00,PC};
					2'b01: DO <= '0;
					2'b10: DO <= '0;
					2'b11: begin
						case (DATA_TRANS_ADDR[7:6])
							2'b00: DO <= DATA_RAM_Q[0];
							2'b01: DO <= DATA_RAM_Q[1];
							2'b10: DO <= DATA_RAM_Q[2];
							2'b11: DO <= DATA_RAM_Q[3];
						endcase
					end
					default: DO <= '0;
				endcase
			end
			
			if (CE_R) begin
				if (RUN) begin
					if (ES) ES <= 0;
					
					if (DECI.CTL.END) begin
						EX <= 0;
						E <= DECI.CTL.EI;
					end
				end
				if (A == 2'b00 && RD) begin
					E <= 0;
				end
			end
		end
	end
	
	assign IRQ = E;

	
endmodule
