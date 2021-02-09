module VDP1_tb;

	bit        CLK;
	bit        RST_N;
	bit        CE_R, CE_F;

	always #5 CLK = ~CLK;

	initial begin
	  RST_N = 0;
	  #12 RST_N = 1;
	end
	
	always @(posedge CLK) begin
		CE_R <= ~CE_R;
	end
	assign CE_F = ~CE_R;
	
	bit [18:1] VRAM_A;
	bit [15:0] VRAM_D;
	bit [15:0] VRAM_Q;
	bit  [1:0] VRAM_WE;
	bit        VRAM_RD;
	bit [15:0] RA1_DO;
	bit        VTIM_N;
	
	initial begin
	  VTIM_N = 1;
	  
	  #100
	  VTIM_N = 0;
	  #100
	  VTIM_N = 1;
	end
	
	VDP1 VDP1
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		
		.RES_N(1'b1),
		
		.DI('0),
		.DO(),
		.CS_N(1'b1),
		.AD_N(1'b1),
		.DTEN_N(1'b1),
		.WE_N(2'b11),
		.RDY_N(),
		
		.HTIM_N(1'b1),
		.VTIM_N(VTIM_N),
	
		.VRAM_A(VRAM_A),
		.VRAM_D(VRAM_D),
		.VRAM_WE(VRAM_WE),
		.VRAM_RD(VRAM_RD),
		.VRAM_Q(VRAM_Q),
		.VRAM_RDY(1'b1),
		
		.FB0_A(),
		.FB0_D(),
		.FB0_WE(),
		.FB0_RD(),
		.FB0_Q('0),
		
		.FB1_A(),
		.FB1_D(),
		.FB1_WE(),
		.FB1_RD(),
		.FB1_Q('0)
	);
	
	assign RA0_DO = '0;
	assign RA1_DO = '0;
	
	RAM_tb #(18,16,"vram.txt") VRAM(CLK, VRAM_A, VRAM_D, 1'b1, VRAM_WE, VRAM_Q);
//	RAM_tb #(17,16,"vram_a1.txt") FB0(CLK, RA1_A, RA1_DO, 1'b1, 2'b00, RA1_DI);
//	RAM_tb #(17,16,"vram_a1.txt") FB1(CLK, RA1_A, RA1_DO, 1'b1, 2'b00, RA1_DI);

	

endmodule

