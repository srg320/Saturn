module VDP2_tb;

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
	
	bit [19:1] RA0_A;
	bit [15:0] RA0_DI;
	bit [15:0] RA0_DO;
	bit [19:1] RA1_A;
	bit [15:0] RA1_DI;
	bit [15:0] RA1_DO;
	VDP2 VDP2
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		
		.RES_N(1'b1),
		
		.DI('0),
		.DO(),
		.CS_N(1'b1),
		.WE_N(1'b1),
		.RD_N(1'b1),
		
		.RA0_A(RA0_A),
		.RA0_DI(RA0_DI),
		.RA1_A(RA1_A),
		.RA1_DI(RA1_DI)
	);
	
	assign RA0_DO = '0;
	assign RA1_DO = '0;
	
	RAM_tb #(19,16,"vram_a0.txt") VRAM_A0(CLK, RA0_A, RA0_DO, 1'b0, 2'b00, RA0_DI);
	RAM_tb #(19,16,"vram_a1.txt") VRAM_A1(CLK, RA1_A, RA1_DO, 1'b0, 2'b00, RA1_DI);

	

endmodule

