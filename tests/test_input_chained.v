/***
 * test_input_chained
 *
 * The INPUT command takes the following form:
 *
 * REQ  __|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|___
 * ACK  __|_|_x_y_d_d_d_d_d_d_d_d_y_D_D_D_D_D_D_D_D_y___
 *
 * x is "OUTPUT ready" and is ignored
 * y is "INPUT  ready".
 *   If it is 0, the host will keep sending REQ pulses until it receives y=1
 *   If it is 1, the host will advance to receiving 8 bits of data from the pod.
 *
 * After 8 bits are received, there may be an extra 'y' bit or a break pause.
 * A break pause resets the state machine.
 *
 * However, if an additional 'y' bit is clocked by the host, the pod will
 * keep sending status bits and (if available) data.
 *
 * This test confirms that chained INPUT commands work correctly.
 */


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
		$dumpfile("tests/test_input_chained.lxt2");
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


	// Shift register, receives data sent in response to an INPUT req
	reg [7:0] sr;
	initial sr = 0;
	always @(posedge testreq) #5 sr <= {sr[6:0], testack};

	initial begin
		// Startup delay
		#(25*USEC)

		// Four pulses to initialise the FSM to a known state
		pulsebreak(4);

		// Four pulses for INPUT, lastAck will NACK because txpend = 0
		pulse(4);
		if (lastAck != 1'b0) begin
			$display("*** DUT ERROR at t=%d. DUT Acked an INPUT when txpend = 0", $time);
			$finish;
		end


		// Send five chained bytes
		reqcount = 0;
		repeat(5) begin
			txin = 8'h5A;
			txpend = 1;
			repeat (9) begin
				// 8 data bit clocks plus the ack
				pulse(1);
			end

			if (sr != 8'h5A) begin
				$display("*** DUT ERROR at t=%d. INPUT phase, data mismatch. Got 0x%02X, wanted 0x%02X", $time, sr, txin);
				$finish;
			end
		end
		#BREAK;			// break to clear the FSM down

		if (reqcount != (9*5)) begin
			$display("*** DUT ERROR at t=%d. Request clock count mismatch. Got %d", $time, reqcount);
			$finish;
		end

		$display("<OK>  Chained input test completed. reqcount=%d, time=%d", reqcount, $time);

		#(5*USEC);
		$finish;
	end

endmodule
