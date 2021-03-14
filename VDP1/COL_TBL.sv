module COL_TBL (
	input         CLK,
	input	  [3:1] WRADDR,
	input	 [31:0] DATA,
	input	        WREN,
	input	  [3:0] RDADDR,
	output [15:0] Q);

	// synopsys translate_off
	`define SIM
	// synopsys translate_on
	
`ifdef SIM
	
	reg [31:0] MEM [8];

	initial begin
		MEM = '{8{'0}};
	end
	
	always @(posedge CLK) begin
		if (WREN) begin
			MEM[WRADDR] <= DATA;
		end
	end
		
	assign Q = !RDADDR[0] ? MEM[RDADDR][31:16] : MEM[RDADDR][15:0];
	
`else

	wire [15:0] sub_wire0,sub_wire1;

	altdpram	altdpram0 (
				.data (DATA[31:16]),
				.inclock (CLK),
				.outclock (CLK),
				.rdaddress (RDADDR[3:1]),
				.wraddress (WRADDR[3:1]),
				.wren (WREN),
				.q (sub_wire0),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.outclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
				//.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram0.indata_aclr = "OFF",
		altdpram0.indata_reg = "INCLOCK",
		altdpram0.intended_device_family = "Cyclone V",
		altdpram0.lpm_type = "altdpram",
		altdpram0.outdata_aclr = "OFF",
		altdpram0.outdata_reg = "UNREGISTERED",
		altdpram0.ram_block_type = "MLAB",
		altdpram0.rdaddress_aclr = "OFF",
		altdpram0.rdaddress_reg = "UNREGISTERED",
		altdpram0.rdcontrol_aclr = "OFF",
		altdpram0.rdcontrol_reg = "UNREGISTERED",
		altdpram0.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram0.width = 16,
		altdpram0.widthad = 3,
		altdpram0.width_byteena = 1,
		altdpram0.wraddress_aclr = "OFF",
		altdpram0.wraddress_reg = "INCLOCK",
		altdpram0.wrcontrol_aclr = "OFF",
		altdpram0.wrcontrol_reg = "INCLOCK";
	
	altdpram	altdpram1 (
				.data (DATA[15:0]),
				.inclock (CLK),
				.outclock (CLK),
				.rdaddress (RDADDR[3:1]),
				.wraddress (WRADDR[3:1]),
				.wren (WREN),
				.q (sub_wire1),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.outclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
				//.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram1.indata_aclr = "OFF",
		altdpram1.indata_reg = "INCLOCK",
		altdpram1.intended_device_family = "Cyclone V",
		altdpram1.lpm_type = "altdpram",
		altdpram1.outdata_aclr = "OFF",
		altdpram1.outdata_reg = "UNREGISTERED",
		altdpram1.ram_block_type = "MLAB",
		altdpram1.rdaddress_aclr = "OFF",
		altdpram1.rdaddress_reg = "UNREGISTERED",
		altdpram1.rdcontrol_aclr = "OFF",
		altdpram1.rdcontrol_reg = "UNREGISTERED",
		altdpram1.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram1.width = 16,
		altdpram1.widthad = 3,
		altdpram1.width_byteena = 1,
		altdpram1.wraddress_aclr = "OFF",
		altdpram1.wraddress_reg = "INCLOCK",
		altdpram1.wrcontrol_aclr = "OFF",
		altdpram1.wrcontrol_reg = "INCLOCK";
		
	assign Q = !RDADDR[0] ? sub_wire0 : sub_wire1;
	
`endif

endmodule

