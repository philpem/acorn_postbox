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
		$dumpfile("tests/test_input.lxt2");
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

	// Transmit interface
	reg [7:0] txin;
	reg txpend;

	initial txpend = 1'b0;
	initial txin = 8'd0;

	// Transmit interface is omitted, display adapters always tx 0x00

	// Instantiate the module we're testing
	postcode p(
		.refclk(refclk),
		.testreq(testreq),
		.testack(testack),

		.lcd_data(lcd_data),
		.lcd_rs(lcd_rs),
		.lcd_e(lcd_e),

		.txin(txin),			// always transmit 0x00, display interface
		.tx_pending(txpend)
	);

`include "tasks.v"


	// Testbench
	integer x;
	localparam WS = 3;	// number of wait states

	// Shift register, receives data sent in response to an INPUT req
	reg [7:0] sr;
	initial sr = 0;
	always @(posedge testreq) #5 sr <= {sr[6:0], testack};

	initial begin
		// Startup delay
		#(25*USEC)

		// Four pulses to initialise the FSM to a known state
		pulsebreak(4);

		// Four pulses for INPUT, lastAck will NACK because txpend=0
		pulse(4);
		if (lastAck != 1'b0) begin
			$display("*** DUT ERROR at t=%d. DUT Acked an INPUT with txpend = 0", $time);
			$finish;
		end


		// Send <WS> waitstates followed by an ACK and 8 data bits
		x = 0;
		txin = 8'h5A;
		while (x < 8+WS) begin		// 8 data bit clocks plus wait states
			//$display("lastAck = %d, x = %d", lastAck, x);
			pulse(1);
			x += 1;

			if (x == WS-1) begin
				txpend = 1'b1;
			end else if (x >= WS) begin
				txpend = 1'b0;
			end
		end
		#BREAK;			// break to clear the FSM down

		//$display("lastAck = %d, x = %d", lastAck, x);
		if (sr != 8'h5A) begin
			$display("*** DUT ERROR at t=%d. INPUT phase, data mismatch. Got 0x%02X, wanted 0x%02X", $time, sr, txin);
			$finish;
		end

		$display("<OK>  Chained input test completed. time=%d", $time);

		#(5*USEC);
		$finish;
	end

endmodule
