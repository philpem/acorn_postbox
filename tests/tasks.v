// pulse(n, ack) -->
//   send <n> TESTREQ pulses
//   stores the last ACK state in <ack>
//
//   e.g. n=3, ack is the output ack state
task pulse;
	input [7:0] n;
	begin
		repeat(n) begin
			testreq=1'b1;
			#PWID;
			testreq=1'b0;
			#PGAP;
		end
	end
endtask

// pulsebreak(n, ack) -->
//   send <n> TESTREQ pulses followed by a BREAK
//   stores the last ACK state in <ack>
//
//   e.g. n=3, ack is the output ack state
task pulsebreak;
	input [7:0] n;
	begin
		pulse(n);
		#BREAK;
	end
endtask

// outbyte(n) --> OUTPUT phase 2, send bits
task outbyte;
	input [7:0] byte;

	// shift register
	reg [7:0] sr;

	begin
		sr = byte;

		// send 8 bits
		repeat(8) begin
			if (sr[7]) begin
				pulsebreak(1);	// SHIFT-ONE is one pulse
			end else begin
				pulsebreak(2);	// SHIFT-ZERO is two pulses
			end

			// shift the shift register left one bit
			sr = {sr[6:0], 1'b0};
		end
	end
endtask


// Latch the most recent TESTACK state
reg lastAck;
initial lastAck = 1'b0;
always @(posedge testreq) begin
	#10 lastAck = (testack == 1'b1) ? 1'b1 : 1'b0;
end

// Track the number of TESTREQ pulses
integer reqcount;
initial reqcount = 0;
always @(posedge testreq) reqcount = reqcount + 1;


