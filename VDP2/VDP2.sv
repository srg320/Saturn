module VDP2 (
	input             CLK,		//~53MHz
	input             RST_N,
	
	input      [ 8:0] IO_A,
	input      [15:0] IO_DI,
	input             IO_WE,
	
	output     [19:1] RA0_A,
	input      [15:0] RA0_DI,
	
	output     [19:1] RA1_A,
	input      [15:0] RA1_DI/*,
	
	output     [19:1] RB0_A,
	input      [15:0] RB0_DI,
	
	output     [19:1] RB1_A,
	input      [15:0] RB1_DI*/

);
	
	import VDP2_PKG::*;
	
	VDP2Regs_t REGS;
	
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
		end
		else begin
			if (IO_WE) begin
				case (IO_A[8:1])
					0: REGS.TVMD <= IO_DI;
					1: REGS.EXTEN <= IO_DI;
					2: REGS.TVSTAT <= IO_DI;
					3: REGS.VRSIZE <= IO_DI;
					4: REGS.HCNT <= IO_DI;
					5: REGS.VCNT <= IO_DI;
					6: REGS.RSRV0 <= IO_DI;
					7: REGS.RAMCTL <= IO_DI;
					8: REGS.CYCA0L <= IO_DI;
					9: REGS.CYCA0U <= IO_DI;
					10: REGS.CYCA1L <= IO_DI;
					11: REGS.CYCA1U <= IO_DI;
					12: REGS.CYCB0L <= IO_DI;
					13: REGS.CYCB0U <= IO_DI;
					14: REGS.CYCB1L <= IO_DI;
					15: REGS.CYCB1U <= IO_DI;
					16: REGS.BGON <= IO_DI;
					17: REGS.MZCTL <= IO_DI;
					18: REGS.SFSEL <= IO_DI;
					19: REGS.SFCODE <= IO_DI;
					20: REGS.CHCTLA <= IO_DI;
					21: REGS.CHCTLB <= IO_DI;
					22: REGS.BMPNA <= IO_DI;
					23: REGS.BMPNB <= IO_DI;
					24: REGS.PNCN0 <= IO_DI;
					25: REGS.PNCN1 <= IO_DI;
					26: REGS.PNCN2 <= IO_DI;
					27: REGS.PNCN3 <= IO_DI;
					28: REGS.PNCR <= IO_DI;
					29: REGS.PLSZ <= IO_DI;
					30: REGS.MPOFN <= IO_DI;
					31: REGS.MPOFR <= IO_DI;
					32: REGS.MPABN0 <= IO_DI;
					33: REGS.MPCDN0 <= IO_DI;
					34: REGS.MPABN1 <= IO_DI;
					35: REGS.MPCDN1 <= IO_DI;
					36: REGS.MPABN2 <= IO_DI;
					37: REGS.MPCDN2 <= IO_DI;
					38: REGS.MPABN3 <= IO_DI;
					39: REGS.MPCDN3 <= IO_DI;
					40: REGS.MPABRA <= IO_DI;
					41: REGS.MPCDRA <= IO_DI;
					42: REGS.MPEFRA <= IO_DI;
					43: REGS.MPGHRA <= IO_DI;
					44: REGS.MPIJRA <= IO_DI;
					45: REGS.MPKLRA <= IO_DI;
					46: REGS.MPMNRA <= IO_DI;
					47: REGS.MPOPRA <= IO_DI;
					48: REGS.MPABRB <= IO_DI;
					49: REGS.MPCDRB <= IO_DI;
					50: REGS.MPEFRB <= IO_DI;
					51: REGS.MPGHRB <= IO_DI;
					52: REGS.MPIJRB <= IO_DI;
					53: REGS.MPKLRB <= IO_DI;
					54: REGS.MPMNRB <= IO_DI;
					55: REGS.MPOPRB <= IO_DI;
					56: REGS.SCXIN0 <= IO_DI;
					57: REGS.SCXDN0 <= IO_DI;
					58: REGS.SCYIN0 <= IO_DI;
					59: REGS.SCYDN0 <= IO_DI;
					60: REGS.ZMXIN0 <= IO_DI;
					61: REGS.ZMXDN0 <= IO_DI;
					62: REGS.ZMYIN0 <= IO_DI;
					63: REGS.ZMYDN0 <= IO_DI;
					64: REGS.SCXIN1 <= IO_DI;
					65: REGS.SCXDN1 <= IO_DI;
					66: REGS.SCYIN1 <= IO_DI;
					67: REGS.SCYDN1 <= IO_DI;
					68: REGS.ZMXIN1 <= IO_DI;
					69: REGS.ZMXDN1 <= IO_DI;
					70: REGS.ZMYIN1 <= IO_DI;
					71: REGS.ZMYDN1 <= IO_DI;
					72: REGS.SCXN2 <= IO_DI;
					73: REGS.SCYN2 <= IO_DI;
					74: REGS.SCXN3 <= IO_DI;
					75: REGS.SCYN3 <= IO_DI;
					76: REGS.ZMCTL <= IO_DI;
					77: REGS.SCRCTL <= IO_DI;
					78: REGS.VCSTAU <= IO_DI;
					79: REGS.VCSTAL <= IO_DI;
					80: REGS.LSTA0U <= IO_DI;
					81: REGS.LSTA0L <= IO_DI;
					82: REGS.LSTA1U <= IO_DI;
					83: REGS.LSTA1L <= IO_DI;
					84: REGS.LCTAU <= IO_DI;
					85: REGS.LCTAL <= IO_DI;
					86: REGS.BKTAU <= IO_DI;
					87: REGS.BKTAL <= IO_DI;
					88: REGS.RPMD <= IO_DI;
					89: REGS.RPRCTL <= IO_DI;
					90: REGS.KTCTL <= IO_DI;
					91: REGS.KTAOF <= IO_DI;
					92: REGS.OVPNRA <= IO_DI;
					93: REGS.OVPNRB <= IO_DI;
					94: REGS.RPTAU <= IO_DI;
					95: REGS.RPTAL <= IO_DI;
					96: REGS.WPSX0 <= IO_DI;
					97: REGS.WPSY0 <= IO_DI;
					98: REGS.WPEX0 <= IO_DI;
					99: REGS.WPEY0 <= IO_DI;
					100: REGS.WPSX1 <= IO_DI;
					101: REGS.WPSY1 <= IO_DI;
					102: REGS.WPEX1 <= IO_DI;
					103: REGS.WPEY1 <= IO_DI;
					104: REGS.WCTLA <= IO_DI;
					105: REGS.WCTLB <= IO_DI;
					106: REGS.WCTLC <= IO_DI;
					107: REGS.WCTLD <= IO_DI;
					108: REGS.LWTA0U <= IO_DI;
					109: REGS.LWTA0L <= IO_DI;
					110: REGS.LWTA1U <= IO_DI;
					111: REGS.LWTA1L <= IO_DI;
					112: REGS.SPCTL <= IO_DI;
					113: REGS.SDCTL <= IO_DI;
					114: REGS.CRAOFA <= IO_DI;
					115: REGS.CRAOFB <= IO_DI;
					116: REGS.LNCLEN <= IO_DI;
					117: REGS.SFPRMD <= IO_DI;
					118: REGS.CCCTL <= IO_DI;
					119: REGS.SFCCMD <= IO_DI;
					120: REGS.PRISA <= IO_DI;
					121: REGS.PRISB <= IO_DI;
					122: REGS.PRISC <= IO_DI;
					123: REGS.PRISD <= IO_DI;
					124: REGS.PRINA <= IO_DI;
					125: REGS.PRINB <= IO_DI;
					126: REGS.PRIR <= IO_DI;
					127: REGS.RSRV1 <= IO_DI;
					128: REGS.CCRSA <= IO_DI;
					129: REGS.CCRSB <= IO_DI;
					130: REGS.CCRSC <= IO_DI;
					131: REGS.CCRSD <= IO_DI;
					132: REGS.CCRNA <= IO_DI;
					133: REGS.CCRNB <= IO_DI;
					134: REGS.CCRR <= IO_DI;
					135: REGS.CCRLB <= IO_DI;
					136: REGS.CLOFEN <= IO_DI;
					137: REGS.CLOFSL <= IO_DI;
					138: REGS.COAR <= IO_DI;
					139: REGS.COAG <= IO_DI;
					140: REGS.COAB <= IO_DI;
					141: REGS.COBR <= IO_DI;
					142: REGS.COBG <= IO_DI;
					143: REGS.COBB <= IO_DI;
				endcase
			end
		end
	end

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
	
	bit [2:0] ACCESS_TIME;
//	always @(posedge CLK or negedge RST_N) begin
//		if (!RST_N) begin
//			ACCESS_TIME <= '0;
//			VA_PIPE[0].H_CNT <= '0;
//			VA_PIPE[0].V_CNT <= '0;
//		end
//		else if (DOT_CE) begin
//			VA_PIPE[0].H_CNT++;
//			if (VA_PIPE[0].H_CNT == 320-1) begin
//				VA_PIPE[0].H_CNT <= '0;
//				VA_PIPE[0].V_CNT++;
//				if (VA_PIPE[0].V_CNT == 224-1) begin
//					VA_PIPE[0].V_CNT <= '0;
//				end
//			end
//			ACCESS_TIME++;
//		end
//	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			VA_PIPE <= '{'0,'0,'0};
		end
		else if (DOT_CE) begin
			VA_PIPE[0].H_CNT <= VA_PIPE[0].H_CNT + 1;
			if (VA_PIPE[0].H_CNT == 320-1) begin
				VA_PIPE[0].H_CNT <= '0;
				VA_PIPE[0].V_CNT <= VA_PIPE[0].V_CNT + 1;
				if (VA_PIPE[0].V_CNT == 224-1) begin
					VA_PIPE[0].V_CNT <= '0;
				end
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
	
	
endmodule
