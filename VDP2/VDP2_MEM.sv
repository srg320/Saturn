module VDP2_DPRAM
#(
	parameter addr_width = 8,
	parameter data_width = 8,
	parameter mem_init_file = "",
	parameter mem_sim_file = ""
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
	// synopsys translate_off
	`timescale 1 ps / 1 ps
	// synopsys translate_on


	wire [data_width-1:0] sub_wire0;
	wire [data_width-1:0] sub_wire1;

	altsyncram	altsyncram_component (
				.clock0 (CLK),
				.wren_a (WREN_A),
				.address_b (ADDR_B),
				.data_b (DATA_B),
				.wren_b (WREN_B),
				.address_a (ADDR_A),
				.data_a (DATA_A),
				.q_a (sub_wire0),
				.q_b (sub_wire1),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (1'b1),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.eccstatus (),
				.rden_a (1'b1),
				.rden_b (1'b1));
	defparam
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.indata_reg_b = "CLOCK0",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2**addr_width,
		altsyncram_component.numwords_b = 2**addr_width,
		altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_a = "UNREGISTERED",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.widthad_a = addr_width,
		altsyncram_component.widthad_b = addr_width,
		altsyncram_component.width_a = data_width,
		altsyncram_component.width_b = data_width,
		altsyncram_component.width_byteena_a = 1,
		altsyncram_component.width_byteena_b = 1,
		altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK0",
		altsyncram_component.init_file = mem_init_file; 

	assign Q_A = sub_wire0;
	assign Q_B = sub_wire1;
	
`endif

endmodule


module VDP2_SPRAM
#(
	parameter addr_width = 8,
	parameter data_width = 8,
	parameter mem_init_file = "",
	parameter mem_sim_file = ""
)
(
	input                   CLK,
	
	input  [addr_width-1:0] ADDR,
	input  [data_width-1:0] DATA,
	input                   WREN,
	output [data_width-1:0] Q
);

	DSP_DPRAM
	#(
		.addr_width(addr_width),
		.data_width(data_width),
		.mem_init_file(mem_init_file),
		.mem_sim_file(mem_sim_file)
	)
	dpram
	(
		.CLK(CLK),
		.ADDR_A(ADDR),
		.DATA_A(DATA),
		.WREN_A(1'b0),
		.Q_A(),
		.ADDR_B(ADDR),
		.DATA_B(DATA),
		.WREN_B(WREN),
		.Q_B(Q)
	);
	
endmodule


module VDP2_pal (
	address_a,
	address_b,
	clock,
	data_a,
	data_b,
	wren_a,
	wren_b,
	q_a,
	q_b);

	input	[10:0]  address_a;
	input	[10:0]  address_b;
	input	  clock;
	input	[15:0]  data_a;
	input	[15:0]  data_b;
	input	  wren_a;
	input	  wren_b;
	output	[15:0]  q_a;
	output	[15:0]  q_b;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri1	  clock;
	tri0	  wren_a;
	tri0	  wren_b;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire [15:0] sub_wire0;
	wire [15:0] sub_wire1;
	wire [15:0] q_a = sub_wire0[15:0];
	wire [15:0] q_b = sub_wire1[15:0];

	altsyncram	altsyncram_component (
				.clock0 (clock),
				.wren_a (wren_a),
				.address_b (address_b),
				.data_b (data_b),
				.wren_b (wren_b),
				.address_a (address_a),
				.data_a (data_a),
				.q_a (sub_wire0),
				.q_b (sub_wire1),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (1'b1),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.eccstatus (),
				.rden_a (1'b1),
				.rden_b (1'b1));
	defparam
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_input_b = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.clock_enable_output_b = "BYPASS",
		altsyncram_component.indata_reg_b = "CLOCK0",
		altsyncram_component.intended_device_family = "Cyclone V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 2048,
		altsyncram_component.numwords_b = 2048,
		altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_a = "UNREGISTERED",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
		altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.widthad_a = 11,
		altsyncram_component.widthad_b = 11,
		altsyncram_component.width_a = 16,
		altsyncram_component.width_b = 16,
		altsyncram_component.width_byteena_a = 1,
		altsyncram_component.width_byteena_b = 1,
		altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK0";


endmodule

module VDP2_WRITE_FIFO (
	input	        CLK,
	input	 [33:0] DATA,
	input	        WRREQ,
	input	        RDREQ,
	output [33:0] Q,
	output	     EMPTY,
	output	     FULL
);

	wire [33: 0] sub_wire0;
	bit  [ 2: 0] RADDR;
	bit  [ 2: 0] WADDR;
	bit  [ 3: 0] AMOUNT;
	
	always @(posedge CLK) begin
		if (WRREQ && !AMOUNT[3]) begin
			WADDR <= WADDR + 3'd1;
		end
		if (RDREQ && AMOUNT) begin
			RADDR <= RADDR + 3'd1;
		end
		
		if (WRREQ && !RDREQ && !AMOUNT[3]) begin
			AMOUNT <= AMOUNT + 4'd1;
		end else if (!WRREQ && RDREQ && AMOUNT) begin
			AMOUNT <= AMOUNT - 4'd1;
		end
	end
	assign EMPTY = ~|AMOUNT;
	assign FULL = AMOUNT[3];
	
	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RADDR),
				.wraddress (WADDR),
				.wren (WRREQ),
				.q (sub_wire0),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 34,
		altdpram_component.widthad = 3,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
		
	assign Q = sub_wire0;
		
		
		
//	wire  sub_wire0;
//	wire  sub_wire1;
//	wire [35:0] sub_wire2;
//
//	scfifo	scfifo_component (
//				.clock (CLK),
//				.data (DATA),
//				.rdreq (RDREQ),
//				.wrreq (WRREQ),
//				.empty (sub_wire0),
//				.full (sub_wire1),
//				.q (sub_wire2),
//				.aclr (),
//				.almost_empty (),
//				.almost_full (),
//				.sclr (),
//				.usedw ());
//	defparam
//		scfifo_component.add_ram_output_register = "OFF",
//		scfifo_component.intended_device_family = "Cyclone V",
//		scfifo_component.lpm_hint = "RAM_BLOCK_TYPE=MLAB",
//		scfifo_component.lpm_numwords = 8,
//		scfifo_component.lpm_showahead = "ON",
//		scfifo_component.lpm_type = "scfifo",
//		scfifo_component.lpm_width = 36,
//		scfifo_component.lpm_widthu = 3,
//		scfifo_component.overflow_checking = "OFF",
//		scfifo_component.underflow_checking = "OFF",
//		scfifo_component.use_eab = "OFF";
//		
//	assign Q = sub_wire2;
//	assign EMPTY = sub_wire0;
//	assign FULL = sub_wire1;

endmodule
