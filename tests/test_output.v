`timescale 1ns/10ps

module test;

	// Clock period, ns
	parameter CLOCK_PERIOD = 500;

	// Pulse width, gap and break delay
	parameter PWID  = 500;
	parameter PGAP  = 500;
	parameter BREAK = 25000;	// 25us

	// time constants
	localparam USEC = 1000;
	localparam MSEC = 1000000;

	// Output waveform file for this test
	initial begin
		$dumpfile("tests/test_output.lxt2");
		$dumpvars(0, test);
	end

	// 2MHz reference clock
	reg refclk;
	initial
		refclk = 1'b0;
	always
		#(CLOCK_PERIOD/2) refclk = !refclk;


	// POST port interface
	reg testreq;
	wire testack;
	initial testreq = 1'b0;

	// LCD interface
	wire [3:0] lcd_data;
	wire lcd_rs, lcd_e;

	// Transmit interface is omitted, display adapters always tx 0x00

	// Instantiate the module we're testing
	postcode p(
		.refclk(refclk),
		.testreq(testreq),
		.testack(testack),

		.lcd_data(lcd_data),
		.lcd_rs(lcd_rs),
		.lcd_e(lcd_e),

		.txin(8'd0),			// always transmit 0x00, display interface
		.tx_pending(1'b1)
	);


`include "tasks.v"


	// Count the number of E-strobes
	reg[7:0] lcd_e_count;
	initial lcd_e_count=0;
	always @(posedge lcd_e) lcd_e_count += 1;


	// Testbench
	reg oRdy;
	initial begin
		// Startup delay
		#25

		// Four pulses to initialise the FSM to a known state
		pulsebreak(4);

		// Three pulses for OUTPUT
		pulsebreak(3);

		$display($time, "<< sent OUTPUT req, READY=%d >>", oRdy);
		if (oRdy != 1'b1) begin
			$display("*** DUT ERROR at time %d. Output-ready was not received when expected.", $time);
			#5 $finish;
		end


		// Send a byte
		lcd_e_count = 0;
		outbyte(8'h09);
		$display($time, "<< LCD state PreRead  -- data 0x%X, RS=%d E-strobes=%d >>", lcd_data, lcd_rs, lcd_e_count);
		if (lcd_e_count != 0) begin
			$display("*** DUT ERROR at time %d. LCD E-strobe count mismatch -- is %d, wanted 0.", $time, lcd_e_count);
			$finish;
		end


		// Send an INPUT chaser and see if we got an E-strobe from the LCD
		lcd_e_count = 0;
		pulsebreak(12);
		#1000;
		$display($time, "<< LCD state PostRead -- data 0x%X, RS=%d E-strobes=%d >>", lcd_data, lcd_rs, lcd_e_count);
		if (lcd_e_count != 1) begin
			$display("*** DUT ERROR at time %d. LCD E-strobe count mismatch -- is %d, wanted 1.", $time, lcd_e_count);
			$finish;
		end


		$finish;
	end

endmodule
