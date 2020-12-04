module SCU (
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	
	input       [1:0] A,
	input      [31:0] DI,
	output     [31:0] DO,
	input             WR,
	input             RD,
	
	output            IRQ
	
);
	import SCU_PKG::*;
	
	bit [26:2] DMA_A;
	bit [31:0] DMA_DO;
	bit [31:0] DMA_DI;
	bit        DMA_WR;
	bit        DMA_REQ;
	bit        DMA_ACK;

	SCU_DSP dsp(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		
		.A(A),
		.DI(DI),
		.DO(DO),
		.WR(WR),
		.RD(RD),
		
		
		.DMA_A(DMA_A),
		.DMA_DI(DMA_DI),
		.DMA_DO(DMA_DO),
		.DMA_WR(DMA_WR),
		.DMA_REQ(DMA_REQ),
		.DMA_ACK(DMA_ACK),
		
		.IRQ(IRQ)
	);
	
	reg [31:0] MEM [16] = '{
	32'h11111111, 32'h22222222, 32'h33333333, 32'h44444444, 
	32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 
	32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 
	32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000
	};
	
	bit [31:0] MEM_DO;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			MEM_DO <= '0;
			DMA_ACK <= 0;
		end
		else if (CE_R) begin
			DMA_ACK <= 0;
			if (DMA_REQ) begin
				if (!DMA_WR) begin
					MEM_DO <= MEM[DMA_A[5:2]];
					DMA_ACK <= 1;
				end
			end
		end
	end
	
	assign DMA_DI = MEM_DO;
	
endmodule
