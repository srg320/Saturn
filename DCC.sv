module DCC (
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	
	input             RES_N,
	
	input      [24:1] A,
	input             BS_N,
	input             CS0_N,
	input             CS1_N,
	input             CS2_N,
	input             RD_WR_N,
	input       [1:0] WE_N,
	input             RD_N,
	output            WAIT_N,
	
	output            BRLS_N,
	input             BGR_N,
	input             BREQ_N,
	output            BACK_N,
	input             EXBREQ_N,
	output            EXBACK_N,
	
	input             WTIN_N,
	input             IVECF_N,
	
	input             HINT_N,
	input             VINT_N,
	output      [2:1] IREQ_N,
	
	output            MFTI,
	output            SFTI,
	
	output            DCE_N,
	output            DOE_N,
	output      [1:0] DWE_N,
	
	output            ROMCE_N,
	output            SRAMCE_N,
	output            SMPCCE_N,
	output            MOE_N,
	output            MWR_N
);

	assign WAIT_N = WTIN_N;///////////////////////
	
	assign BRLS_N = 1;
	assign BACK_N = 1;
	assign EXBACK_N = 1;
	
	assign IREQ_N = {VINT_N,HINT_N};////////////////
	
	assign ROMCE_N = ~(A[24:20] == 5'b00000) | CS0_N;
	assign SMPCCE_N = ~(A[24:19] == 6'b000010) | CS0_N;
	assign SRAMCE_N = ~(A[24:19] == 6'b000011) | CS0_N;
	assign MOE_N = RD_N;
	assign MWR_N = WE_N[1];
	
	
	assign DCE_N = ~(A[24:21] == 4'b0001) | CS0_N;
	assign DOE_N = RD_N;
	assign DWE_N = WE_N;
	
	assign MFTI = 0;
	assign SFTI = 0;

endmodule
