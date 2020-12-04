module SCU_tb;

	import SCU_PKG::*;
	
	bit        CLK;
	bit        RST_N;
	bit        CE_R, CE_F;
	
	bit  [1:0] SCU_A;
	bit [31:0] SCU_DO;
	bit [31:0] SCU_DI;
	bit  [3:0] SCU_WR;
	bit        SCU_RD;
	
	bit [31:0] RAM_DO, RAM_DI;
	bit RAM_WE;
	 
	//clock generation
	always #5 CLK = ~CLK;
	 
	//reset generation
	initial begin
	  RST_N = 0;
	  #12 RST_N = 1;
	end
	
	initial begin
	  SCU_A = '0;
	  SCU_DI = '0;
	  SCU_WR = 0;
	  
	  #20 SCU_A = 2'h2;
	      SCU_DI = 32'h00000040;
	      SCU_WR = 1;
	  #20 SCU_WR = 0;
	  
	  #20 SCU_A = 2'h3;
	      SCU_DI = 32'h00000000;
	      SCU_WR = 1;
	  #20 SCU_WR = 0;
	  
	  #20 SCU_A = 2'h3;
	      SCU_DI = 32'h00000000;
	      SCU_WR = 1;
	  #20 SCU_WR = 0;
	  
	  #20 SCU_A = 2'h0;
	      SCU_DI = 32'h00010000;
	      SCU_WR = 1;
	  #20 SCU_WR = 0;
	end
	
	always @(posedge CLK) begin
		CE_R <= ~CE_R;
	end
	assign CE_F = ~CE_R;
	
	SCU scu
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		
		.A(SCU_A),
		.DI(SCU_DI),
		.DO(SCU_DO),
		.WR(SCU_WR),
		.RD(SCU_RD),
		
		.IRQ()
		
	);

endmodule
