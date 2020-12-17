module VDP2 (
	input             CLK,		//~53MHz
	input             RST_N,
	input             CE_R,
	input             CE_F,
	
	input             RES_N,
	
	input      [20:1] A,
	input      [15:0] DI,
	output     [15:0] DO,
	input             CS_N,
	input             WE_N,
	input             RD_N,
	
	output     [19:1] RA0_A,
	input      [15:0] RA0_DI,
	
	output     [19:1] RA1_A,
	input      [15:0] RA1_DI,
	
//	output     [19:1] RB0_A,
//	input      [15:0] RB0_DI,
//	
//	output     [19:1] RB1_A,
//	input      [15:0] RB1_DI
	
	output      [7:0] R,
	output      [7:0] G,
	output      [7:0] B,
	output            DCLK,
	output            HS_N,
	output            VS_N,
	output            HBL_N,
	output            VBL_N
);
	
	import VDP2_PKG::*;
	
	//H 427/455
	//V 263/313
	parameter HRES      = 9'd427;
	parameter HS_START  = 9'd369;
	parameter HS_END    = HS_START + 9'd32;
	parameter HBL_START = 9'd320;
	parameter VRES      = 9'd263;
	parameter VS_START  = 9'd235;
	parameter VS_END    = VS_START + 9'd3;
	parameter VBL_START = 9'd224;
	
	VDP2Regs_t REGS;
	

	bit DOT_CE;
//	bit [8:0] H_CNT, V_CNT;
	VRAMAccessPipeline_t VA_PIPE;
	PatternName_t PNA0, PNA1, PNB0, PNB1;
	bit [19:1] VRAMA0_ADDR, VRAMA1_ADDR, VRAMB0_ADDR, VRAMB1_ADDR;
	
	
	bit [2:0] DOTCLK_DIV;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			DOTCLK_DIV <= '0;
			DOT_CE <= 0;
		end
		else begin
			DOTCLK_DIV++;
			if (DOTCLK_DIV == 7) DOT_CE = 1;
		end
	end
	
	assign DCLK = DOT_CE;
	
	bit [2:0] ACCESS_TIME;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			HS_N <= 1;
			VS_N <= 1;
			HBL_N <= 1;
			VBL_N <= 1;
			VA_PIPE <= '{'0,'0,'0};
		end
		else if (DOT_CE) begin
			VA_PIPE[0].H_CNT <= VA_PIPE[0].H_CNT + 9'd1;
			if (VA_PIPE[0].H_CNT == HRES-1) begin
				VA_PIPE[0].H_CNT <= '0;
				VA_PIPE[0].V_CNT <= VA_PIPE[0].V_CNT + 9'd1;
				if (VA_PIPE[0].V_CNT == VRES-1) begin
					VA_PIPE[0].V_CNT <= '0;
				end
			end
			if (VA_PIPE[0].H_CNT == HS_START-1) begin
				HS_N <= 0;
			end else if (VA_PIPE[0].H_CNT == HS_END-1) begin
				HS_N <= 1;
			end
			if (VA_PIPE[0].H_CNT == HBL_START-1) begin
				HBL_N <= 0;
				if (VA_PIPE[0].V_CNT == VS_START-1) begin
					VS_N <= 0;
				end else if (VA_PIPE[0].V_CNT == VS_END-1) begin
					VS_N <= 1;
				end
				if (VA_PIPE[0].V_CNT == VBL_START-1) begin
					VBL_N <= 0;
				end else if (VA_PIPE[0].V_CNT == VRES-1) begin
					VBL_N <= 1;
				end
			end else if (VA_PIPE[0].H_CNT == HRES-1) begin
				HBL_N <= 1;
			end
			ACCESS_TIME++;
			
			case (ACCESS_TIME)
				T0: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0L[15:12]; VA_PIPE[0].VCPA1 <= REGS.CYCA1L[15:12]; VA_PIPE[0].VCPB0 <= REGS.CYCB0L[15:12]; VA_PIPE[0].VCPB1 <= REGS.CYCB1L[15:12]; end
				T1: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0L[11: 8]; VA_PIPE[0].VCPA1 <= REGS.CYCA1L[11: 8]; VA_PIPE[0].VCPB0 <= REGS.CYCB0L[11: 8]; VA_PIPE[0].VCPB1 <= REGS.CYCB1L[11: 8]; end
				T2: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0L[ 7: 4]; VA_PIPE[0].VCPA1 <= REGS.CYCA1L[ 7: 4]; VA_PIPE[0].VCPB0 <= REGS.CYCB0L[ 7: 4]; VA_PIPE[0].VCPB1 <= REGS.CYCB1L[ 7: 4]; end
				T3: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0L[ 3: 0]; VA_PIPE[0].VCPA1 <= REGS.CYCA1L[ 3: 0]; VA_PIPE[0].VCPB0 <= REGS.CYCB0L[ 3: 0]; VA_PIPE[0].VCPB1 <= REGS.CYCB1L[ 3: 0]; end
				T4: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0U[15:12]; VA_PIPE[0].VCPA1 <= REGS.CYCA1U[15:12]; VA_PIPE[0].VCPB0 <= REGS.CYCB0U[15:12]; VA_PIPE[0].VCPB1 <= REGS.CYCB1U[15:12]; end
				T5: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0U[11: 8]; VA_PIPE[0].VCPA1 <= REGS.CYCA1U[11: 8]; VA_PIPE[0].VCPB0 <= REGS.CYCB0U[11: 8]; VA_PIPE[0].VCPB1 <= REGS.CYCB1U[11: 8]; end
				T6: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0U[ 7: 4]; VA_PIPE[0].VCPA1 <= REGS.CYCA1U[ 7: 4]; VA_PIPE[0].VCPB0 <= REGS.CYCB0U[ 7: 4]; VA_PIPE[0].VCPB1 <= REGS.CYCB1U[ 7: 4]; end
				T7: begin VA_PIPE[0].VCPA0 <= REGS.CYCA0U[ 3: 0]; VA_PIPE[0].VCPA1 <= REGS.CYCA1U[ 3: 0]; VA_PIPE[0].VCPB0 <= REGS.CYCB0U[ 3: 0]; VA_PIPE[0].VCPB1 <= REGS.CYCB1U[ 3: 0]; end
			endcase
			VA_PIPE[1] <= VA_PIPE[0];
			VA_PIPE[2] <= VA_PIPE[1];
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		bit [8:0] map_addr;
		bit [6:0] cell_offs_x,cell_offs_y;
		
		if (!RST_N) begin
			VRAMA0_ADDR <= '0;
			VRAMA1_ADDR <= '0;
		end
		else if (DOT_CE) begin
			cell_offs_x = VA_PIPE[0].H_CNT[8:3];
			cell_offs_y = VA_PIPE[0].V_CNT[8:3];
			case (VA_PIPE[0].VCPA0)
				VCP_N0PN: begin
					case (REGS.PLSZ.N0PLSZ)
						2'b00: map_addr = {REGS.MPOFN.N0MP,REGS.MPABN0.NxMPA};
						2'b01: map_addr = {REGS.MPOFN.N0MP,REGS.MPABN0.NxMPA[5:1],cell_offs_x[6]};
						2'b10,2'b11: map_addr = {REGS.MPOFN.N0MP,REGS.MPABN0.NxMPA[5:2],cell_offs_y[6],cell_offs_x[6]};
					endcase
					case ({REGS.CHCTLA.N0CHSZ,REGS.PNCN0.NxPNB})
						2'b00: begin 
							VRAMA0_ADDR <= {map_addr[5:0],cell_offs_y[5:0],cell_offs_x[5:0],1'b0};
						end
						2'b01: begin 
							VRAMA0_ADDR <= {map_addr[6:0],cell_offs_y[5:0],cell_offs_x[5:0]};
						end
						2'b10: begin 
							VRAMA0_ADDR <= {map_addr[7:0],cell_offs_y[5:1],cell_offs_x[5:1],1'b0};
						end
						2'b11: begin 
							VRAMA0_ADDR <= {map_addr[8:0],cell_offs_y[5:1],cell_offs_x[5:1]};
						end
					endcase
				end
			endcase
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			PNA0 <= '0;
		end
		else if (DOT_CE) begin
			case (VA_PIPE[1].VCPA0)
				VCP_N0PN: begin
					if (!REGS.PNCN0.NxPNB) begin
						if (!VRAMA0_ADDR[1])
							PNA0[31:16] <= RA0_DI;
						else
							PNA0[15: 0] <= RA0_DI;
					end else begin
						case ({REGS.CHCTLA.N0CHSZ,|REGS.CHCTLA.N0CHCN})
							2'b00: begin 
								PNA0[31:30] <= RA0_DI[11:10] & {2{~REGS.PNCN0.NxCNSM}}; 
								PNA0[29:28] <= {REGS.PNCN0.NxSPR,REGS.PNCN0.NxSCC}; 
								PNA0[22:16] <= {REGS.PNCN0.NxSPLT,RA0_DI[15:12]};
								PNA0[14:12] <= REGS.PNCN0.NxSCN[4:2];
								PNA0[11:10] <= (REGS.PNCN0.NxSCN[1:0] & {2{~REGS.PNCN0.NxCNSM}}) | (RA0_DI[11:10] & {2{REGS.PNCN0.NxCNSM}});
								PNA0[ 9: 0] <= RA0_DI[9:0];
							end
							2'b01: begin 
								PNA0[31:30] <= RA0_DI[11:10] & {2{~REGS.PNCN0.NxCNSM}}; 
								PNA0[29:28] <= {REGS.PNCN0.NxSPR,REGS.PNCN0.NxSCC}; 
								PNA0[22:16] <= {RA0_DI[14:12],4'b0000};
								PNA0[14:12] <= REGS.PNCN0.NxSCN[4:2];
								PNA0[11:10] <= (REGS.PNCN0.NxSCN[1:0] & {2{~REGS.PNCN0.NxCNSM}}) | (RA0_DI[11:10] & {2{REGS.PNCN0.NxCNSM}});
								PNA0[ 9: 0] <= RA0_DI[9:0];
							end
							2'b10: begin 
								PNA0[31:30] <= RA0_DI[11:10] & {2{~REGS.PNCN0.NxCNSM}}; 
								PNA0[29:28] <= {REGS.PNCN0.NxSPR,REGS.PNCN0.NxSCC}; 
								PNA0[22:16] <= {REGS.PNCN0.NxSPLT,RA0_DI[15:12]};
								PNA0[14]    <= REGS.PNCN0.NxSCN[4];
								PNA0[13:12] <= (REGS.PNCN0.NxSCN[3:2] & {2{~REGS.PNCN0.NxCNSM}}) | (RA0_DI[11:10] & {2{REGS.PNCN0.NxCNSM}});
								PNA0[11: 0] <= {RA0_DI[9:0],REGS.PNCN0.NxSCN[1:0]};
							end
							2'b11: begin 
								PNA0[31:30] <= RA0_DI[11:10] & {2{~REGS.PNCN0.NxCNSM}}; 
								PNA0[29:28] <= {REGS.PNCN0.NxSPR,REGS.PNCN0.NxSCC}; 
								PNA0[22:16] <= {RA0_DI[14:12],4'b0000};
								PNA0[14]    <= REGS.PNCN0.NxSCN[4];
								PNA0[13:12] <= (REGS.PNCN0.NxSCN[3:2] & {2{~REGS.PNCN0.NxCNSM}}) | (RA0_DI[11:10] & {2{REGS.PNCN0.NxCNSM}});
								PNA0[11: 0] <= {RA0_DI[9:0],REGS.PNCN0.NxSCN[1:0]};
							end
						endcase
					end
				end
				VCP_N0CH:;
				VCP_CPU:;
				default:;
			endcase
		end
	end
	
	
	assign RA0_A = VRAMA0_ADDR;
	assign RA1_A = VRAMA1_ADDR;
//	assign RB0_A = VRAMB0_ADDR;
//	assign RB1_A = VRAMB1_ADDR;
	
	
	wire REG_SEL = A[20:18] == 3'b110;	//180000-1BFFFF
	
	bit [15:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		
		if (!RST_N) begin
			REGS.TVMD <= '0;
			REGS.EXTEN <= '0;
			REGS.TVSTAT <= '0;
			REGS.VRSIZE <= '0;
			REGS.HCNT <= '0;
			REGS.VCNT <= '0;
			REGS.RSRV0 <= '0;
			REGS.RAMCTL <= '0;
			REGS.CYCA0L <= '0;
			REGS.CYCA0U <= '0;
			REGS.CYCA1L <= '0;
			REGS.CYCA1U <= '0;
			REGS.CYCB0L <= '0;
			REGS.CYCB0U <= '0;
			REGS.CYCB1L <= '0;
			REGS.CYCB1U <= '0;
			REGS.BGON <= '0;
			REGS.MZCTL <= '0;
			REGS.SFSEL <= '0;
			REGS.SFCODE <= '0;
			REGS.CHCTLA <= '0;
			REGS.CHCTLB <= '0;
			REGS.BMPNA <= '0;
			REGS.BMPNB <= '0;
			REGS.PNCN0 <= '0;
			REGS.PNCN1 <= '0;
			REGS.PNCN2 <= '0;
			REGS.PNCN3 <= '0;
			REGS.PNCR <= '0;
			REGS.PLSZ <= '0;
			REGS.MPOFN <= '0;
			REGS.MPOFR <= '0;
			REGS.MPABN0 <= '0;
			REGS.MPCDN0 <= '0;
			REGS.MPABN1 <= '0;
			REGS.MPCDN1 <= '0;
			REGS.MPABN2 <= '0;
			REGS.MPCDN2 <= '0;
			REGS.MPABN3 <= '0;
			REGS.MPCDN3 <= '0;
			REGS.MPABRA <= '0;
			REGS.MPCDRA <= '0;
			REGS.MPEFRA <= '0;
			REGS.MPGHRA <= '0;
			REGS.MPIJRA <= '0;
			REGS.MPKLRA <= '0;
			REGS.MPMNRA <= '0;
			REGS.MPOPRA <= '0;
			REGS.MPABRB <= '0;
			REGS.MPCDRB <= '0;
			REGS.MPEFRB <= '0;
			REGS.MPGHRB <= '0;
			REGS.MPIJRB <= '0;
			REGS.MPKLRB <= '0;
			REGS.MPMNRB <= '0;
			REGS.MPOPRB <= '0;
			REGS.SCXIN0 <= '0;
			REGS.SCXDN0 <= '0;
			REGS.SCYIN0 <= '0;
			REGS.SCYDN0 <= '0;
			REGS.ZMXIN0 <= '0;
			REGS.ZMXDN0 <= '0;
			REGS.ZMYIN0 <= '0;
			REGS.ZMYDN0 <= '0;
			REGS.SCXIN1 <= '0;
			REGS.SCXDN1 <= '0;
			REGS.SCYIN1 <= '0;
			REGS.SCYDN1 <= '0;
			REGS.ZMXIN1 <= '0;
			REGS.ZMXDN1 <= '0;
			REGS.ZMYIN1 <= '0;
			REGS.ZMYDN1 <= '0;
			REGS.SCXN2 <= '0;
			REGS.SCYN2 <= '0;
			REGS.SCXN3 <= '0;
			REGS.SCYN3 <= '0;
			REGS.ZMCTL <= '0;
			REGS.SCRCTL <= '0;
			REGS.VCSTAU <= '0;
			REGS.VCSTAL <= '0;
			REGS.LSTA0U <= '0;
			REGS.LSTA0L <= '0;
			REGS.LSTA1U <= '0;
			REGS.LSTA1L <= '0;
			REGS.LCTAU <= '0;
			REGS.LCTAL <= '0;
			REGS.BKTAU <= '0;
			REGS.BKTAL <= '0;
			REGS.RPMD <= '0;
			REGS.RPRCTL <= '0;
			REGS.KTCTL <= '0;
			REGS.KTAOF <= '0;
			REGS.OVPNRA <= '0;
			REGS.OVPNRB <= '0;
			REGS.RPTAU <= '0;
			REGS.RPTAL <= '0;
			REGS.WPSX0 <= '0;
			REGS.WPSY0 <= '0;
			REGS.WPEX0 <= '0;
			REGS.WPEY0 <= '0;
			REGS.WPSX1 <= '0;
			REGS.WPSY1 <= '0;
			REGS.WPEX1 <= '0;
			REGS.WPEY1 <= '0;
			REGS.WCTLA <= '0;
			REGS.WCTLB <= '0;
			REGS.WCTLC <= '0;
			REGS.WCTLD <= '0;
			REGS.LWTA0U <= '0;
			REGS.LWTA0L <= '0;
			REGS.LWTA1U <= '0;
			REGS.LWTA1L <= '0;
			REGS.SPCTL <= '0;
			REGS.SDCTL <= '0;
			REGS.CRAOFA <= '0;
			REGS.CRAOFB <= '0;
			REGS.LNCLEN <= '0;
			REGS.SFPRMD <= '0;
			REGS.CCCTL <= '0;
			REGS.SFCCMD <= '0;
			REGS.PRISA <= '0;
			REGS.PRISB <= '0;
			REGS.PRISC <= '0;
			REGS.PRISD <= '0;
			REGS.PRINA <= '0;
			REGS.PRINB <= '0;
			REGS.PRIR <= '0;
			REGS.RSRV1 <= '0;
			REGS.CCRSA <= '0;
			REGS.CCRSB <= '0;
			REGS.CCRSC <= '0;
			REGS.CCRSD <= '0;
			REGS.CCRNA <= '0;
			REGS.CCRNB <= '0;
			REGS.CCRR <= '0;
			REGS.CCRLB <= '0;
			REGS.CLOFEN <= '0;
			REGS.CLOFSL <= '0;
			REGS.COAR <= '0;
			REGS.COAG <= '0;
			REGS.COAB <= '0;
			REGS.COBR <= '0;
			REGS.COBG <= '0;
			REGS.COBB <= '0;
			
			REG_DO <= '0;
		end
		else begin
			if (!RES_N) begin
				
			end else begin
				if (REG_SEL) begin
					if (!CS_N && !WE_N && CE_F) begin
						case ({A[8:1],1'b0})
							9'h000: REGS.TVMD <= DI & TVMD_MASK;
							9'h002: REGS.EXTEN <= DI & EXTEN_MASK;
							9'h004: REGS.TVSTAT <= DI & TVSTAT_MASK;
							9'h006: REGS.VRSIZE <= DI & VRSIZE_MASK;
							9'h008: REGS.HCNT <= DI & HCNT_MASK;
							9'h00A: REGS.VCNT <= DI & VCNT_MASK;
							9'h00C: REGS.RSRV0 <= DI & RSRV_MASK;
							9'h00E: REGS.RAMCTL <= DI & RAMCTL_MASK;
							9'h010: REGS.CYCA0L <= DI & CYCx0L_MASK;
							9'h012: REGS.CYCA0U <= DI & CYCx0U_MASK;
							9'h014: REGS.CYCA1L <= DI & CYCx1L_MASK;
							9'h016: REGS.CYCA1U <= DI & CYCx1U_MASK;
							9'h018: REGS.CYCB0L <= DI & CYCx0L_MASK;
							9'h01A: REGS.CYCB0U <= DI & CYCx0U_MASK;
							9'h01C: REGS.CYCB1L <= DI & CYCx1L_MASK;
							9'h01E: REGS.CYCB1U <= DI & CYCx1U_MASK;
							9'h020: REGS.BGON <= DI & BGON_MASK;
							9'h022: REGS.MZCTL <= DI & MZCTL_MASK;
							9'h024: REGS.SFSEL <= DI & SFSEL_MASK;
							9'h026: REGS.SFCODE <= DI & SFCODE_MASK;
							9'h028: REGS.CHCTLA <= DI & CHCTLA_MASK;
							9'h02A: REGS.CHCTLB <= DI & CHCTLB_MASK;
							9'h02C: REGS.BMPNA <= DI & BMPNA_MASK;
							9'h02E: REGS.BMPNB <= DI & BMPNB_MASK;
							9'h030: REGS.PNCN0 <= DI & PNCNx_MASK;
							9'h032: REGS.PNCN1 <= DI & PNCNx_MASK;
							9'h034: REGS.PNCN2 <= DI & PNCNx_MASK;
							9'h036: REGS.PNCN3 <= DI & PNCNx_MASK;
							9'h038: REGS.PNCR <= DI & PNCR_MASK;
							9'h03A: REGS.PLSZ <= DI & PLSZ_MASK;
							9'h03C: REGS.MPOFN <= DI & MPOFN_MASK;
							9'h03E: REGS.MPOFR <= DI & MPOFR_MASK;
							9'h040: REGS.MPABN0 <= DI & MPABNx_MASK;
							9'h042: REGS.MPCDN0 <= DI & MPCDNx_MASK;
							9'h044: REGS.MPABN1 <= DI & MPABNx_MASK;
							9'h046: REGS.MPCDN1 <= DI & MPCDNx_MASK;
							9'h048: REGS.MPABN2 <= DI & MPABNx_MASK;
							9'h04A: REGS.MPCDN2 <= DI & MPCDNx_MASK;
							9'h04C: REGS.MPABN3 <= DI & MPABNx_MASK;
							9'h04E: REGS.MPCDN3 <= DI & MPCDNx_MASK;
							9'h050: REGS.MPABRA <= DI & MPABRx_MASK;
							9'h052: REGS.MPCDRA <= DI & MPCDRx_MASK;
							9'h054: REGS.MPEFRA <= DI & MPEFRx_MASK;
							9'h056: REGS.MPGHRA <= DI & MPGHRx_MASK;
							9'h058: REGS.MPIJRA <= DI & MPIJRx_MASK;
							9'h05A: REGS.MPKLRA <= DI & MPKLRx_MASK;
							9'h05C: REGS.MPMNRA <= DI & MPMNRx_MASK;
							9'h05E: REGS.MPOPRA <= DI & MPOPRx_MASK;
							9'h060: REGS.MPABRB <= DI & MPABRx_MASK;
							9'h062: REGS.MPCDRB <= DI & MPCDRx_MASK;
							9'h064: REGS.MPEFRB <= DI & MPEFRx_MASK;
							9'h066: REGS.MPGHRB <= DI & MPGHRx_MASK;
							9'h068: REGS.MPIJRB <= DI & MPIJRx_MASK;
							9'h06A: REGS.MPKLRB <= DI & MPKLRx_MASK;
							9'h06C: REGS.MPMNRB <= DI & MPMNRx_MASK;
							9'h06E: REGS.MPOPRB <= DI & MPOPRx_MASK;
							9'h070: REGS.SCXIN0 <= DI & SCXINx_MASK;
							9'h072: REGS.SCXDN0 <= DI & SCXDNx_MASK;
							9'h074: REGS.SCYIN0 <= DI & SCYINx_MASK;
							9'h076: REGS.SCYDN0 <= DI & SCYDNx_MASK;
							9'h078: REGS.ZMXIN0 <= DI & ZMXINx_MASK;
							9'h07A: REGS.ZMXDN0 <= DI & ZMXDNx_MASK;
							9'h07C: REGS.ZMYIN0 <= DI & ZMYINx_MASK;
							9'h07E: REGS.ZMYDN0 <= DI & ZMYDNx_MASK;
							9'h080: REGS.SCXIN1 <= DI & SCXINx_MASK;
							9'h082: REGS.SCXDN1 <= DI & SCXDNx_MASK;
							9'h084: REGS.SCYIN1 <= DI & SCYINx_MASK;
							9'h086: REGS.SCYDN1 <= DI & SCYDNx_MASK;
							9'h088: REGS.ZMXIN1 <= DI & ZMXINx_MASK;
							9'h08A: REGS.ZMXDN1 <= DI & ZMXDNx_MASK;
							9'h08C: REGS.ZMYIN1 <= DI & ZMYINx_MASK;
							9'h08E: REGS.ZMYDN1 <= DI & ZMYDNx_MASK;
							9'h090: REGS.SCXN2 <= DI & SCXNx_MASK;
							9'h092: REGS.SCYN2 <= DI & SCYNx_MASK;
							9'h094: REGS.SCXN3 <= DI & SCXNx_MASK;
							9'h096: REGS.SCYN3 <= DI & SCYNx_MASK;
							9'h098: REGS.ZMCTL <= DI & ZMCTL_MASK;
							9'h09A: REGS.SCRCTL <= DI & SCRCTL_MASK;
							9'h09C: REGS.VCSTAU <= DI & VCSTAU_MASK;
							9'h09E: REGS.VCSTAL <= DI & VCSTAL_MASK;
							9'h0A0: REGS.LSTA0U <= DI & LSTAxU_MASK;
							9'h0A2: REGS.LSTA0L <= DI & LSTAxL_MASK;
							9'h0A4: REGS.LSTA1U <= DI & LSTAxU_MASK;
							9'h0A6: REGS.LSTA1L <= DI & LSTAxL_MASK;
							9'h0A8: REGS.LCTAU <= DI & LCTAU_MASK;
							9'h0AA: REGS.LCTAL <= DI & LCTAL_MASK;
							9'h0AC: REGS.BKTAU <= DI & BKTAU_MASK;
							9'h0AE: REGS.BKTAL <= DI & BKTAL_MASK;
							9'h0B0: REGS.RPMD <= DI & RPMD_MASK;
							9'h0B2: REGS.RPRCTL <= DI & RPRCTL_MASK;
							9'h0B4: REGS.KTCTL <= DI & KTCTL_MASK;
							9'h0B6: REGS.KTAOF <= DI & KTAOF_MASK;
							9'h0B8: REGS.OVPNRA <= DI & OVPNRx_MASK;
							9'h0BA: REGS.OVPNRB <= DI & OVPNRx_MASK;
							9'h0BC: REGS.RPTAU <= DI & RPTAU_MASK;
							9'h0BE: REGS.RPTAL <= DI & RPTAL_MASK;
							9'h0C0: REGS.WPSX0 <= DI & WPSXx_MASK;
							9'h0C2: REGS.WPSY0 <= DI & WPSYx_MASK;
							9'h0C4: REGS.WPEX0 <= DI & WPEXx_MASK;
							9'h0C6: REGS.WPEY0 <= DI & WPEYx_MASK;
							9'h0C8: REGS.WPSX1 <= DI & WPSXx_MASK;
							9'h0CA: REGS.WPSY1 <= DI & WPSYx_MASK;
							9'h0CC: REGS.WPEX1 <= DI & WPEXx_MASK;
							9'h0CE: REGS.WPEY1 <= DI & WPEYx_MASK;
							9'h0D0: REGS.WCTLA <= DI & WCTLA_MASK;
							9'h0D2: REGS.WCTLB <= DI & WCTLB_MASK;
							9'h0D4: REGS.WCTLC <= DI & WCTLC_MASK;
							9'h0D6: REGS.WCTLD <= DI & WCTLD_MASK;
							9'h0D8: REGS.LWTA0U <= DI & LWTAxU_MASK;
							9'h0DA: REGS.LWTA0L <= DI & LWTAxL_MASK;
							9'h0DC: REGS.LWTA1U <= DI & LWTAxU_MASK;
							9'h0DE: REGS.LWTA1L <= DI & LWTAxL_MASK;
							9'h0E0: REGS.SPCTL <= DI & SPCTL_MASK;
							9'h0E2: REGS.SDCTL <= DI & SDCTL_MASK;
							9'h0E4: REGS.CRAOFA <= DI & CRAOFA_MASK;
							9'h0E6: REGS.CRAOFB <= DI & CRAOFB_MASK;
							9'h0E8: REGS.LNCLEN <= DI & LNCLEN_MASK;
							9'h0EA: REGS.SFPRMD <= DI & SFPRMD_MASK;
							9'h0EC: REGS.CCCTL <= DI & CCCTL_MASK;
							9'h0EE: REGS.SFCCMD <= DI & SFCCMD_MASK;
							9'h0F0: REGS.PRISA <= DI & PRISA_MASK;
							9'h0F2: REGS.PRISB <= DI & PRISB_MASK;
							9'h0F4: REGS.PRISC <= DI & PRISC_MASK;
							9'h0F6: REGS.PRISD <= DI & PRISD_MASK;
							9'h0F8: REGS.PRINA <= DI & PRINA_MASK;
							9'h0FA: REGS.PRINB <= DI & PRINB_MASK;
							9'h0FC: REGS.PRIR <= DI & PRIR_MASK;
							9'h0FE: REGS.RSRV1 <= DI & RSRV_MASK;
							9'h100: REGS.CCRSA <= DI & CCRSA_MASK;
							9'h102: REGS.CCRSB <= DI & CCRSB_MASK;
							9'h104: REGS.CCRSC <= DI & CCRSC_MASK;
							9'h106: REGS.CCRSD <= DI & CCRSD_MASK;
							9'h108: REGS.CCRNA <= DI & CCRNA_MASK;
							9'h10A: REGS.CCRNB <= DI & CCRNA_MASK;
							9'h10C: REGS.CCRR <= DI & CCRR_MASK;
							9'h10E: REGS.CCRLB <= DI & CCRLB_MASK;
							9'h110: REGS.CLOFEN <= DI & CLOFEN_MASK;
							9'h112: REGS.CLOFSL <= DI & CLOFSL_MASK;
							9'h114: REGS.COAR <= DI & COxR_MASK;
							9'h116: REGS.COAG <= DI & COxG_MASK;
							9'h118: REGS.COAB <= DI & COxB_MASK;
							9'h11A: REGS.COBR <= DI & COxR_MASK;
							9'h11C: REGS.COBG <= DI & COxG_MASK;
							9'h11E: REGS.COBB <= DI & COxB_MASK;
							default:;
						endcase
					end else if (!CS_N && !RD_N && CE_R) begin
						case ({A[8:1],1'b0})
							9'h000: REG_DO <= REGS.TVMD & TVMD_MASK;
							9'h002: REG_DO <= REGS.EXTEN & EXTEN_MASK;
							9'h004: REG_DO <= REGS.TVSTAT & TVSTAT_MASK;
							9'h006: REG_DO <= REGS.VRSIZE & VRSIZE_MASK;
							9'h008: REG_DO <= REGS.HCNT & HCNT_MASK;
							9'h00A: REG_DO <= REGS.VCNT & VCNT_MASK;
							9'h00C: REG_DO <= REGS.RSRV0 & RSRV_MASK;
							9'h00E: REG_DO <= REGS.RAMCTL & RAMCTL_MASK;
							9'h010: REG_DO <= REGS.CYCA0L & CYCx0L_MASK;
							9'h012: REG_DO <= REGS.CYCA0U & CYCx0U_MASK;
							9'h014: REG_DO <= REGS.CYCA1L & CYCx1L_MASK;
							9'h016: REG_DO <= REGS.CYCA1U & CYCx1L_MASK;
							9'h018: REG_DO <= REGS.CYCB0L & CYCx0L_MASK;
							9'h01A: REG_DO <= REGS.CYCB0U & CYCx0U_MASK;
							9'h01C: REG_DO <= REGS.CYCB1L & CYCx1L_MASK;
							9'h01E: REG_DO <= REGS.CYCB1U & CYCx1L_MASK;
							9'h020: REG_DO <= REGS.BGON & BGON_MASK;
							9'h022: REG_DO <= REGS.MZCTL & MZCTL_MASK;
							9'h024: REG_DO <= REGS.SFSEL & SFSEL_MASK;
							9'h026: REG_DO <= REGS.SFCODE & SFCODE_MASK;
							9'h028: REG_DO <= REGS.CHCTLA & CHCTLA_MASK;
							9'h02A: REG_DO <= REGS.CHCTLB & CHCTLB_MASK;
							9'h02C: REG_DO <= REGS.BMPNA & BMPNA_MASK;
							9'h02E: REG_DO <= REGS.BMPNB & BMPNB_MASK;
							9'h030: REG_DO <= REGS.PNCN0 & PNCNx_MASK;
							9'h032: REG_DO <= REGS.PNCN1 & PNCNx_MASK;
							9'h034: REG_DO <= REGS.PNCN2 & PNCNx_MASK;
							9'h036: REG_DO <= REGS.PNCN3 & PNCNx_MASK;
							9'h038: REG_DO <= REGS.PNCR & PNCR_MASK;
							9'h03A: REG_DO <= REGS.PLSZ & PLSZ_MASK;
							9'h03C: REG_DO <= REGS.MPOFN & MPOFN_MASK;
							9'h03E: REG_DO <= REGS.MPOFR & MPOFR_MASK;
							9'h040: REG_DO <= REGS.MPABN0 & MPABNx_MASK;
							9'h042: REG_DO <= REGS.MPCDN0 & MPCDNx_MASK;
							9'h044: REG_DO <= REGS.MPABN1 & MPABNx_MASK;
							9'h046: REG_DO <= REGS.MPCDN1 & MPCDNx_MASK;
							9'h048: REG_DO <= REGS.MPABN2 & MPABNx_MASK;
							9'h04A: REG_DO <= REGS.MPCDN2 & MPCDNx_MASK;
							9'h04C: REG_DO <= REGS.MPABN3 & MPABNx_MASK;
							9'h04E: REG_DO <= REGS.MPCDN3 & MPCDNx_MASK;
							9'h050: REG_DO <= REGS.MPABRA & MPABRx_MASK;
							9'h052: REG_DO <= REGS.MPCDRA & MPCDRx_MASK;
							9'h054: REG_DO <= REGS.MPEFRA & MPEFRx_MASK;
							9'h056: REG_DO <= REGS.MPGHRA & MPGHRx_MASK;
							9'h058: REG_DO <= REGS.MPIJRA & MPIJRx_MASK;
							9'h05A: REG_DO <= REGS.MPKLRA & MPKLRx_MASK;
							9'h05C: REG_DO <= REGS.MPMNRA & MPMNRx_MASK;
							9'h05E: REG_DO <= REGS.MPOPRA & MPOPRx_MASK;
							9'h060: REG_DO <= REGS.MPABRB & MPABRx_MASK;
							9'h062: REG_DO <= REGS.MPCDRB & MPCDRx_MASK;
							9'h064: REG_DO <= REGS.MPEFRB & MPEFRx_MASK;
							9'h066: REG_DO <= REGS.MPGHRB & MPGHRx_MASK;
							9'h068: REG_DO <= REGS.MPIJRB & MPIJRx_MASK;
							9'h06A: REG_DO <= REGS.MPKLRB & MPKLRx_MASK;
							9'h06C: REG_DO <= REGS.MPMNRB & MPMNRx_MASK;
							9'h06E: REG_DO <= REGS.MPOPRB & MPOPRx_MASK;
							9'h070: REG_DO <= REGS.SCXIN0 & SCXINx_MASK;
							9'h072: REG_DO <= REGS.SCXDN0 & SCXDNx_MASK;
							9'h074: REG_DO <= REGS.SCYIN0 & SCYINx_MASK;
							9'h076: REG_DO <= REGS.SCYDN0 & SCYDNx_MASK;
							9'h078: REG_DO <= REGS.ZMXIN0 & ZMXINx_MASK;
							9'h07A: REG_DO <= REGS.ZMXDN0 & ZMXDNx_MASK;
							9'h07C: REG_DO <= REGS.ZMYIN0 & ZMYINx_MASK;
							9'h07E: REG_DO <= REGS.ZMYDN0 & ZMYDNx_MASK;
							9'h080: REG_DO <= REGS.SCXIN1 & SCXINx_MASK;
							9'h082: REG_DO <= REGS.SCXDN1 & SCXDNx_MASK;
							9'h084: REG_DO <= REGS.SCYIN1 & SCYINx_MASK;
							9'h086: REG_DO <= REGS.SCYDN1 & SCYDNx_MASK;
							9'h088: REG_DO <= REGS.ZMXIN1 & ZMXINx_MASK;
							9'h08A: REG_DO <= REGS.ZMXDN1 & ZMXDNx_MASK;
							9'h08C: REG_DO <= REGS.ZMYIN1 & ZMYINx_MASK;
							9'h08E: REG_DO <= REGS.ZMYDN1 & ZMYDNx_MASK;
							9'h090: REG_DO <= REGS.SCXN2 & SCXNx_MASK;
							9'h092: REG_DO <= REGS.SCYN2 & SCYNx_MASK;
							9'h094: REG_DO <= REGS.SCXN3 & SCXNx_MASK;
							9'h096: REG_DO <= REGS.SCYN3 & SCYNx_MASK;
							9'h098: REG_DO <= REGS.ZMCTL & ZMCTL_MASK;
							9'h09A: REG_DO <= REGS.SCRCTL & SCRCTL_MASK;
							9'h09C: REG_DO <= REGS.VCSTAU & VCSTAU_MASK;
							9'h09E: REG_DO <= REGS.VCSTAL & VCSTAL_MASK;
							9'h0A0: REG_DO <= REGS.LSTA0U & LSTAxU_MASK;
							9'h0A2: REG_DO <= REGS.LSTA0L & LSTAxL_MASK;
							9'h0A4: REG_DO <= REGS.LSTA1U & LSTAxU_MASK;
							9'h0A6: REG_DO <= REGS.LSTA1L & LSTAxL_MASK;
							9'h0A8: REG_DO <= REGS.LCTAU & LCTAU_MASK;
							9'h0AA: REG_DO <= REGS.LCTAL & LCTAL_MASK;
							9'h0AC: REG_DO <= REGS.BKTAU & BKTAU_MASK;
							9'h0AE: REG_DO <= REGS.BKTAL & BKTAL_MASK;
							9'h0B0: REG_DO <= REGS.RPMD & RPMD_MASK;
							9'h0B2: REG_DO <= REGS.RPRCTL & RPRCTL_MASK;
							9'h0B4: REG_DO <= REGS.KTCTL & KTCTL_MASK;
							9'h0B6: REG_DO <= REGS.KTAOF & KTAOF_MASK;
							9'h0B8: REG_DO <= REGS.OVPNRA & OVPNRx_MASK;
							9'h0BA: REG_DO <= REGS.OVPNRB & OVPNRx_MASK;
							9'h0BC: REG_DO <= REGS.RPTAU & RPTAU_MASK;
							9'h0BE: REG_DO <= REGS.RPTAL & RPTAL_MASK;
							9'h0C0: REG_DO <= REGS.WPSX0 & WPSXx_MASK;
							9'h0C2: REG_DO <= REGS.WPSY0 & WPSYx_MASK;
							9'h0C4: REG_DO <= REGS.WPEX0 & WPEXx_MASK;
							9'h0C6: REG_DO <= REGS.WPEY0 & WPEYx_MASK;
							9'h0C8: REG_DO <= REGS.WPSX1 & WPSXx_MASK;
							9'h0CA: REG_DO <= REGS.WPSY1 & WPSYx_MASK;
							9'h0CC: REG_DO <= REGS.WPEX1 & WPEXx_MASK;
							9'h0CE: REG_DO <= REGS.WPEY1 & WPEYx_MASK;
							9'h0D0: REG_DO <= REGS.WCTLA & WCTLA_MASK;
							9'h0D2: REG_DO <= REGS.WCTLB & WCTLB_MASK;
							9'h0D4: REG_DO <= REGS.WCTLC & WCTLC_MASK;
							9'h0D6: REG_DO <= REGS.WCTLD & WCTLD_MASK;
							9'h0D8: REG_DO <= REGS.LWTA0U & LWTAxU_MASK;
							9'h0DA: REG_DO <= REGS.LWTA0L & LWTAxL_MASK;
							9'h0DC: REG_DO <= REGS.LWTA1U & LWTAxU_MASK;
							9'h0DE: REG_DO <= REGS.LWTA1L & LWTAxL_MASK;
							9'h0E0: REG_DO <= REGS.SPCTL & SPCTL_MASK;
							9'h0E2: REG_DO <= REGS.SDCTL & SDCTL_MASK;
							9'h0E4: REG_DO <= REGS.CRAOFA & CRAOFA_MASK;
							9'h0E6: REG_DO <= REGS.CRAOFB & CRAOFB_MASK;
							9'h0E8: REG_DO <= REGS.LNCLEN & LNCLEN_MASK;
							9'h0EA: REG_DO <= REGS.SFPRMD & SFPRMD_MASK;
							9'h0EC: REG_DO <= REGS.CCCTL & CCCTL_MASK;
							9'h0EE: REG_DO <= REGS.SFCCMD & SFCCMD_MASK;
							9'h0F0: REG_DO <= REGS.PRISA & PRISA_MASK;
							9'h0F2: REG_DO <= REGS.PRISB & PRISB_MASK;
							9'h0F4: REG_DO <= REGS.PRISC & PRISC_MASK;
							9'h0F6: REG_DO <= REGS.PRISD & PRISD_MASK;
							9'h0F8: REG_DO <= REGS.PRINA & PRINA_MASK;
							9'h0FA: REG_DO <= REGS.PRINB & PRINB_MASK;
							9'h0FC: REG_DO <= REGS.PRIR & PRIR_MASK;
							9'h0FE: REG_DO <= REGS.RSRV1 & RSRV_MASK;
							9'h100: REG_DO <= REGS.CCRSA & CCRSA_MASK;
							9'h102: REG_DO <= REGS.CCRSB & CCRSB_MASK;
							9'h104: REG_DO <= REGS.CCRSC & CCRSC_MASK;
							9'h106: REG_DO <= REGS.CCRSD & CCRSD_MASK;
							9'h108: REG_DO <= REGS.CCRNA & CCRNA_MASK;
							9'h10A: REG_DO <= REGS.CCRNB & CCRNB_MASK;
							9'h10C: REG_DO <= REGS.CCRR & CCRR_MASK;
							9'h10E: REG_DO <= REGS.CCRLB & CCRLB_MASK;
							9'h110: REG_DO <= REGS.CLOFEN & CLOFEN_MASK;
							9'h112: REG_DO <= REGS.CLOFSL & CLOFSL_MASK;
							9'h114: REG_DO <= REGS.COAR & COxR_MASK;
							9'h116: REG_DO <= REGS.COAG & COxG_MASK;
							9'h118: REG_DO <= REGS.COAB & COxB_MASK;
							9'h11A: REG_DO <= REGS.COBR & COxR_MASK;
							9'h11C: REG_DO <= REGS.COBG & COxG_MASK;
							9'h11E: REG_DO <= REGS.COBB & COxB_MASK;
							default: REG_DO <= '0;
						endcase
					end
				end
			end
		end
	end
	
	assign DO = REG_DO;
	
endmodule
