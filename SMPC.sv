module SMPC (
	input             CLK,
	input             RST_N,
	input             CE,
	
	input             MRES_N,
	
	input       [3:0] AC,
	
	input       [6:1] A,
	input       [7:0] DI,
	output      [7:0] DO,
	input             CS_N,
	input             RW_N,
	
	input             SRES_N,
	
	input             IRQV_N,
	input             EXL,
	
	output reg        MSHRES_N,
	output reg        MSHNMI_N,
	output reg        SSHRES_N,
	output reg        SSHNMI_N,
	output reg        SYSRES_N,
	output reg        SNDRES_N,
	output reg        CDRES_N,
	
	output reg        MIRQ_N,

	input       [6:0] P1I,
	output      [6:0] P1O,
	input       [6:0] P2I,
	output      [6:0] P2O,
	
	output      [6:0] TEMP
);

	//Registers
	bit   [7:0] COMREG;
	bit   [7:0] SR;
	bit         SF;
	bit   [7:0] IREG[7];
	bit   [7:0] OREG[32];
	bit   [6:0] PDR1;
	bit   [6:0] PDR2;
	bit   [6:0] DDR1;
	bit   [6:0] DDR2;
	bit   [1:0] IOSEL;
	bit   [1:0] EXLE;
	
	bit         DOTSEL;
	bit         RESD;
	
	bit   [7:0] SMEM[4];
	
	parameter SR_PDE = 2;
	parameter SR_RESB = 3;
	
	typedef enum bit [4:0] {
		CS_IDLE = 5'b00001,  
		CS_EXEC = 5'b00010, 
		CS_END  = 5'b00100,
		CS_WAIT = 5'b01000
	} CommExecState_t;
	CommExecState_t COMM_ST;
	
	bit [7:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		bit        RW_N_OLD;
		bit        CS_N_OLD;
		bit [19:0] WAIT_CNT;
		bit        SRES_EXEC;
		
		if (!RST_N) begin
			COMREG <= '0;
			SR <= '0;
			SF <= 0;
			IREG <= '{7{'0}};
			OREG <= '{32{'0}};
			PDR1 <= '0;
			PDR2 <= '0;
			DDR1 <= '0;
			DDR2 <= '0;
			IOSEL <= '0;
			EXLE <= '0;
			
			MSHRES_N <= 0;
			MSHNMI_N <= 0;
			SSHRES_N <= 0;
			SSHNMI_N <= 0;
			SYSRES_N <= 0;
			SNDRES_N <= 0;
			CDRES_N <= 0;
			MIRQ_N <= 1;
			RESD <= 1;
			
			REG_DO <= '0;
			RW_N_OLD <= 1;
			CS_N_OLD <= 1;
			COMM_ST <= CS_IDLE;
			SRES_EXEC <= 0;
		end
		else if (!MRES_N) begin
			MSHRES_N <= 1;
			MSHNMI_N <= 1;
			SSHRES_N <= 0;
			SSHNMI_N <= 1;
			SYSRES_N <= 1;
			SNDRES_N <= 0;
			CDRES_N <= 0;
			MIRQ_N <= 1;
			SR <= '0;
			RESD <= 1;
		end else begin
			RW_N_OLD <= RW_N;
			if (!RW_N && RW_N_OLD && !CS_N) begin
				case ({A,1'b1})
					7'h01: IREG[0] <= DI;
					7'h03: IREG[1] <= DI;
					7'h05: IREG[2] <= DI;
					7'h07: IREG[3] <= DI;
					7'h09: IREG[4] <= DI;
					7'h0B: IREG[5] <= DI;
					7'h0D: IREG[6] <= DI;
					7'h1F: COMREG <= DI;
					7'h63: SF <= DI[0];
					7'h75: PDR1 <= DI[6:0];
					7'h77: PDR2 <= DI[6:0];
					7'h79: DDR1 <= DI[6:0];
					7'h7B: DDR2 <= DI[6:0];
					7'h7D: IOSEL <= DI[1:0];
					7'h7F: EXLE <= DI[1:0];
					default:;
				endcase
			end 
			
			CS_N_OLD <= CS_N;
			if (!CS_N && CS_N_OLD && RW_N) begin
				case ({A,1'b1})
					7'h21: REG_DO <= OREG[0];
					7'h23: REG_DO <= OREG[1];
					7'h25: REG_DO <= OREG[2];
					7'h27: REG_DO <= OREG[3];
					7'h29: REG_DO <= OREG[4];
					7'h2B: REG_DO <= OREG[5];
					7'h2D: REG_DO <= OREG[6];
					7'h2F: REG_DO <= OREG[7];
					7'h31: REG_DO <= OREG[8];
					7'h33: REG_DO <= OREG[9];
					7'h35: REG_DO <= OREG[10];
					7'h37: REG_DO <= OREG[11];
					7'h39: REG_DO <= OREG[12];
					7'h3B: REG_DO <= OREG[13];
					7'h3D: REG_DO <= OREG[14];
					7'h3F: REG_DO <= OREG[15];
					7'h41: REG_DO <= OREG[16];
					7'h43: REG_DO <= OREG[17];
					7'h45: REG_DO <= OREG[18];
					7'h47: REG_DO <= OREG[19];
					7'h49: REG_DO <= OREG[20];
					7'h4B: REG_DO <= OREG[21];
					7'h4D: REG_DO <= OREG[22];
					7'h4F: REG_DO <= OREG[23];
					7'h51: REG_DO <= OREG[24];
					7'h53: REG_DO <= OREG[25];
					7'h55: REG_DO <= OREG[26];
					7'h57: REG_DO <= OREG[27];
					7'h59: REG_DO <= OREG[28];
					7'h5B: REG_DO <= OREG[29];
					7'h5D: REG_DO <= OREG[30];
					7'h5F: REG_DO <= OREG[31];
					7'h61: REG_DO <= SR;
					7'h63: REG_DO <= {7'b0000000,SF};
					7'h75: REG_DO <= {1'b0,PDR1};
					7'h77: REG_DO <= {1'b0,PDR2};
					default: REG_DO <= '0;
				endcase
			end
				
			if (CE) begin
				if (WAIT_CNT) WAIT_CNT <= WAIT_CNT - 20'd1;
				
				if (!SRES_N && !RESD && !SRES_EXEC) begin
					MSHNMI_N <= 0;
					SSHNMI_N <= 0;
					WAIT_CNT <= 20'd400000;
					SRES_EXEC <= 1;
				end else if (SRES_EXEC && !WAIT_CNT) begin
					MSHNMI_N <= 1;
					SSHNMI_N <= 1;
				end
				
				SR[SR_RESB] <= ~SRES_N;
				
				case (COMM_ST)
					CS_IDLE: begin
						if (SF && !SRES_EXEC) begin
							COMM_ST <= CS_EXEC;
						end
						MIRQ_N <= 1;///////////////////////
					end
					
					CS_EXEC: begin
						OREG[31] <= COMREG;
						case (COMREG) 
							8'h00: begin		//MSHON
								WAIT_CNT <= 20'd127;
								COMM_ST <= CS_WAIT;
							end
							
							8'h02: begin		//SSHON
								WAIT_CNT <= 20'd127;
								COMM_ST <= CS_WAIT;
							end
							
							8'h03: begin		//SSHOFF
								WAIT_CNT <= 20'd127;
								COMM_ST <= CS_WAIT;
							end
							
							8'h06: begin		//SNDON
								WAIT_CNT <= 20'd127;
								COMM_ST <= CS_WAIT;
							end
							
							8'h07: begin		//SNDOFF
								WAIT_CNT <= 20'd127;
								COMM_ST <= CS_WAIT;
							end
							
							8'h08: begin		//CDON
								WAIT_CNT <= 20'd159;
								COMM_ST <= CS_WAIT;
							end
							
							8'h09: begin		//CDOFF
								WAIT_CNT <= 20'd159;
								COMM_ST <= CS_WAIT;
							end
							
							8'h0D: begin		//SYSRES
								MSHRES_N <= 0;
								MSHNMI_N <= 0;
								SSHRES_N <= 0;
								SSHNMI_N <= 0;
								SNDRES_N <= 0;
								CDRES_N <= 0;
								SYSRES_N <= 0;
								WAIT_CNT <= 20'd400000;
								COMM_ST <= CS_WAIT;
							end
							
							8'h0E: begin		//CKCHG352
								WAIT_CNT <= 20'd400000;
								COMM_ST <= CS_WAIT;
							end
							
							8'h0F: begin		//CKCHG320
								WAIT_CNT <= 20'd400000;
								COMM_ST <= CS_WAIT;
							end
							
							8'h10: begin		//INTBACK
								if (!IREG[0][7:1] && IREG[2] == 8'hF0)  begin
									WAIT_CNT <= 20'd400000;
									COMM_ST <= CS_WAIT;
								end else begin
									COMM_ST <= CS_END;
								end
							end
							
							8'h16: begin		//SETTIME
								WAIT_CNT <= 20'd279;
								COMM_ST <= CS_WAIT;
							end
							
							8'h17: begin		//SETSMEM
								WAIT_CNT <= 20'd159;
								COMM_ST <= CS_WAIT;
							end
							
							8'h18: begin		//NMIREQ
								MSHNMI_N <= 0;
								WAIT_CNT <= 20'd127;
								COMM_ST <= CS_WAIT;
							end
							
							8'h19: begin		//RESENAB
								WAIT_CNT <= 20'd127;
								COMM_ST <= CS_WAIT;
							end
							
							8'h1A: begin		//RESDISA
								WAIT_CNT <= 20'd127;
								COMM_ST <= CS_WAIT;
							end
							
							default: begin
								COMM_ST <= CS_END;
							end
						endcase
					end
					
					CS_WAIT: begin
						if (!WAIT_CNT) COMM_ST <= CS_END;
					end
					
					CS_END: begin
						OREG[31] <= COMREG;
						SF <= 0;
						COMM_ST <= CS_IDLE;
						case (COMREG) 
							8'h00: begin		//MSHON
								MSHRES_N <= 1;
								MSHNMI_N <= 1;//?
							end
							
							8'h02: begin		//SSHON
								SSHRES_N <= 1;
								SSHNMI_N <= 1;//?
							end
							
							8'h03: begin		//SSHOFF
								SSHRES_N <= 0;
								SSHNMI_N <= 1;//?
							end
							
							8'h06: begin		//SNDON
								SNDRES_N <= 1;
							end
							
							8'h07: begin		//SNDOFF
								SNDRES_N <= 0;
							end
							
							8'h08: begin		//CDON
								CDRES_N <= 1;
							end
							
							8'h09: begin		//CDOFF
								CDRES_N <= 0;
							end
							
							8'h0D: begin		//SYSRES
								MSHRES_N <= 1;
								MSHNMI_N <= 1;
								SSHRES_N <= 1;
								SSHNMI_N <= 1;
								SNDRES_N <= 1;
								CDRES_N <= 1;
								SYSRES_N <= 1;
							end
							
							8'h0E: begin		//CKCHG352
								DOTSEL <= 1;
							end
							
							8'h0F: begin		//CKCHG320
								DOTSEL <= 0;
							end
							
							8'h10: begin		//INTBACK
								OREG[0] <= {1'b1,RESD,6'b000000};
								OREG[1] <= 8'h20;
								OREG[2] <= 8'h20;
								OREG[3] <= 8'h01;
								OREG[4] <= 8'h01;
								OREG[5] <= 8'h00;
								OREG[6] <= 8'h00;
								OREG[7] <= 8'h00;
								OREG[8] <= 8'h00;
								OREG[9] <= {4'b0000,AC};
								OREG[10] <= {1'b0,DOTSEL,2'b11,~MSHNMI_N,1'b1,~SYSRES_N,~SNDRES_N};
								OREG[11] <= {1'b0,~CDRES_N,6'b000000};
								OREG[12] <= SMEM[0];
								OREG[13] <= SMEM[1];
								OREG[14] <= SMEM[2];
								OREG[15] <= SMEM[3];
								OREG[31] <= 8'h00;
								MIRQ_N <= 0;
							end
							
							8'h16: begin		//SETTIME
								
							end
							
							8'h17: begin		//SETSMEM
								SMEM[0] <= IREG[0];
								SMEM[1] <= IREG[1];
								SMEM[2] <= IREG[2];
								SMEM[3] <= IREG[3];
							end
							
							
							8'h18: begin		//NMIREQ
								MSHNMI_N <= 1;
							end
							
							8'h19: begin		//RESENAB
								RESD <= 0;
							end
							
							8'h1A: begin		//RESDISA
								RESD <= 1;
							end
							
							default:;
						endcase
					end
				endcase
			end
		end
	end
	
	assign DO = REG_DO;
	
	assign P1O = '0;
	assign P2O = '0;
	assign TEMP = DDR1^DDR2^IOSEL^EXLE;

endmodule
