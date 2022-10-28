module CART (
	input             CLK,
	input             RST_N,
	
	input             RES_N,
	
	input             CE_R,
	input             CE_F,
	input      [25:0] AA,
	input      [15:0] ADI,
	output     [15:0] ADO,
	input       [1:0] AFC,
	input             ACS0_N,
	input             ACS1_N,
	input             ACS2_N,
	input             ARD_N,
	input             AWRL_N,
	input             AWRU_N,
	input             ATIM0_N,
	input             ATIM2_N,
	output            AWAIT_N,
	output            ARQT_N,
	
	output     [24:1] MEMA,
	input      [15:0] MEMDI,
	output     [15:0] MEMDO,
	output            MEMWRL_N,
	output            MEMWRH_N,
	output            MEMRD_N
);

	wire CART_SEL = ~ACS0_N;
	bit [15:0] CART_DO;
	bit        ABUS_WAIT;
	always @(posedge CLK or negedge RST_N) begin
		bit        AWR_N_OLD;
		bit        ARD_N_OLD;
		if (!RST_N) begin
			ABUS_WAIT <= 0;
		end else begin
			if (!RES_N) begin
				
			end else begin
				if (CE_R) begin
					AWR_N_OLD <= AWRL_N & AWRU_N;
					ARD_N_OLD <= ARD_N;
				end

				if (CART_SEL) begin
					if ((!AWRL_N || !AWRU_N) && AWR_N_OLD && CE_R) begin
						
					end else if (!ARD_N && ARD_N_OLD && CE_F) begin
						CART_DO <= 16'hFFFF;
					end
				end
			end
		end
	end

	assign ADO = CART_DO;
	assign AWAIT_N = 1;
	assign ARQT_N = 1;
	
	assign MEMA = '0;
	assign MEMDO = '1;
	assign MEMWRL_N = 1;
	assign MEMWRH_N = 1;
	assign MEMRD_N = 1;
	
endmodule
