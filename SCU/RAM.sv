module DSP_DPRAM
#(
	parameter addr_width = 8,
	parameter data_width = 8,
	parameter mem_init_file = " ",
	parameter mem_sim_file = " "
)
(
	input                   CLK,
	
	input  [addr_width-1:0] ADDR_A,
	input  [data_width-1:0] DATA_A,
	input                   WREN_A,
	output [data_width-1:0] Q_A,
	
	input  [addr_width-1:0] ADDR_B,
	input  [data_width-1:0] DATA_B,
	input                   WREN_B,
	output [data_width-1:0] Q_B
);

	// synopsys translate_off
	`define SIM
	// synopsys translate_on
	
`ifdef SIM
	
	reg [data_width-1:0] MEM [2**addr_width];

	initial begin
		$readmemh(mem_sim_file, MEM);
	end
	
	always @(posedge CLK) begin
		if (WREN_A) begin
			MEM[ADDR_A] <= DATA_A;
		end
		if (WREN_B) begin
			MEM[ADDR_B] <= DATA_B;
		end
	end
		
	assign Q_A = MEM[ADDR_A];
	assign Q_B = MEM[ADDR_B];
	
`else
	
	wire [data_width-1:0] sub_wire0, sub_wire1;

	altsyncram	altsyncram_component (
				.address_a (ADDR_A),
				.address_b (ADDR_B),
				.clock0 (CLK),
				.clock1 (CLK),
				.data_a (DATA_A),
				.data_b (DATA_B),
				.wren_a (WREN_A),
				.wren_b (WREN_B),
				.q_a (sub_wire0),
				.q_b (sub_wire1),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (1'b1),
				.byteena_b (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.eccstatus (),
				.rden_a (1'b1),
				.rden_b (1'b1));
	defparam
		altsyncram_component.address_reg_b = "CLOCK1",
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
//		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
//		altsyncram_component.indata_reg_b = "CLOCK1",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**addr_width,
		altsyncram_component.numwords_b = 2**addr_width,
		altsyncram_component.operation_mode = "DUAL_PORT",
//		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_aclr_b = "NONE",
//		altsyncram_component.outdata_reg_a = "UNREGISTERED",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",		
		altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.widthad_a = addr_width,
		altsyncram_component.widthad_b = addr_width,
		altsyncram_component.width_a = data_width,
		altsyncram_component.width_b = data_width,
		altsyncram_component.width_byteena_a = 1,
//		altsyncram_component.width_byteena_b = 1,
		altsyncram_component.init_file = mem_init_file; 


	assign Q_A = sub_wire0;
	assign Q_B = sub_wire1;
	
`endif

endmodule


module DSP_SPRAM
#(
	parameter addr_width = 8,
	parameter data_width = 8,
	parameter mem_init_file = " ",
	parameter mem_sim_file = " "
)
(
	input                   CLK,
	
	input  [addr_width-1:0] ADDR,
	input  [data_width-1:0] DATA,
	input                   WREN,
	output [data_width-1:0] Q
);

//	DSP_DPRAM
//	#(
//		.addr_width(addr_width),
//		.data_width(data_width),
//		.mem_init_file(mem_init_file),
//		.mem_sim_file(mem_sim_file)
//	)
//	dpram
//	(
//		.CLK(CLK),
//		.ADDR_A(ADDR),
//		.DATA_A(DATA),
//		.WREN_A(1'b0),
//		.Q_A(),
//		.ADDR_B(ADDR),
//		.DATA_B(DATA),
//		.WREN_B(WREN),
//		.Q_B(Q)
//	);
	
	spram #(addr_width,data_width,mem_init_file) spram
	(
		.clock(CLK),
		.address(ADDR),
		.data(DATA),
		.wren(WREN),
		.q(Q)
	);

	
endmodule
