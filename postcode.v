module postcode

#(
	// Parameter Declarations

	// Timer timeout value
	// Refclk is 2MHz, so this is 500ns increments
	parameter TIMER_MAX = (15*2)-1

	/*
	parameter <param_name> = <default_value>,
	parameter [<msb>:<lsb>] <param_name> = <default_value>,
	parameter signed [<msb>:<lsb>] <param_name> = <default_value>
	...
	*/
)

(
	// Input Ports
	input refclk,							// Main reference clock (TTL osc)
	input testreq,							// Test REQuest (LA23)
	
	// Output Ports
	output testack,						// Test ACKnowledge (TESTAK)
	
	output[3:0] lcd_data,				// LCD display interface
	output lcd_rs,
	output lcd_e,
	
	input [7:0] txin,						// Data -> host (INPUT command)
	input tx_pending						// Data to host pending
);


	// Gate internal TESTACK against TESTREQ.
	// TESTACK should only ever drive high or open.
	reg testack_int;
	assign testack = (testreq & testack_int);
	
	
	// Monostable -- pulse train end detector
	// Reset to zero every time TESTREQ pulses high.
	// Stops on expiry.
	reg[7:0] timer;
	wire timer_expired = (timer == TIMER_MAX);
	
	always @(posedge refclk or posedge testreq) begin
		if (testreq) begin
			// TESTREQ pulse resets the timer
			timer <= 8'b0;
		end else begin
			// REFCLK pulse increments the timer
			if (timer <= TIMER_MAX) begin
				timer <= timer + 8'd1;
			end
		end
	end
	
	reg rx_shifter[7:0];
	
	
	/**
	 * INPUT:
	 *   Four pulses are sent.
	 *   The fourth pulse is repeated until TESTACK is asserted in response.
	 *   The following eight pulses then clock in eight data bits, MSB first.
	 *   TESTACK asserted is interpreted as a logical '1'.
	 *   If pulses continue without a break, they should be interpreted as
	 *     further polling for input and more data may be transferred without
	 *     returning to the initial four-pulse start-up.
	 *
	 * OUTPUT:
	 *   Three pulses are sent.
	 *   If TESTACK is asserted in response to the third pulse, the interface
	 *     is ready for data.
	 *   A break then occurs, and either another attempt is made or data is sent.
	 *   Data is transmitted as an eight-group sequence of either one or two pulses.
	 *     One puls is interpreted as a logical '1', two is a logical '0'.
	 *   Each sequence of eight bits is preceded by a sequence of three-pulse poll
	 *     operations to ensure the interface is ready for data.
	 *   A dummy three-pulse sequence is sent at the end of a series of bytes to
	 *     ensure that the last byte is recognised.
	 */
	
	// receive shift register -- data from the host
	reg[7:0] rxshift;
	wire rx_ready = 1'b1;
	
	// transmit shift register -- data to the host
	reg[7:0] txshift;
	wire tx_ready = tx_pending;
	wire tx_done;
	assign tx_done = (state == S_INPUT_BIT0) & testreq;

	
	// LCD interface on the rxshiftreg
	assign lcd_data = rxshift[3:0];
	assign lcd_rs = rxshift[4];
	// E-strobe is generated when a WRITE is followed by a READ, and rx'd MSB is set.
	assign lcd_e = (!rxshift[7]) & tx_done;
	
	
	
	// state machine
	reg[4:0] state;
	
	localparam S_INITIAL		= 5'd0;		// initial state, waiting for first pulse
	localparam S_SHIFTONE	= 5'd1;		// one pulse received (shift in a '1')
	localparam S_SHIFTZERO	= 5'd2;		// two pulses received (shift in a '0')
	localparam S_OUTPUTPOLL	= 5'd3;		// three pulses received (OUTPUT)
	localparam S_INPUTPOLL	= 5'd4;		// four pulses received (INPUT)
	localparam S_INPUT_BIT7	= 5'd5;		// shift out bits MSB..LSB in response to an INPUT command
	localparam S_INPUT_BIT6	= 5'd6;
	localparam S_INPUT_BIT5	= 5'd7;
	localparam S_INPUT_BIT4	= 5'd8;
	localparam S_INPUT_BIT3	= 5'd9;
	localparam S_INPUT_BIT2	= 5'd10;
	localparam S_INPUT_BIT1	= 5'd11;
	localparam S_INPUT_BIT0	= 5'd12;
	
	always @(posedge timer_expired) begin
		// Timer expiry -- shift in any data bits which were sent

		// Timer expiry in S_SHIFTONE shifts in a '1'
		if (state == S_SHIFTONE) begin
			rxshift <= {rxshift[6:0], 1'b1};

		// Timer expiry in S_SHIFTONE shifts in a '0'
		end else if (state == S_SHIFTZERO) begin
			rxshift <= {rxshift[6:0], 1'b0};
		end
	end

	// Generate delayed timer_expired
	reg timer_expired_d;
	always @(posedge refclk) begin
		timer_expired_d <= timer_expired;
	end
	
	always @(posedge testreq or posedge timer_expired_d) begin
	
		// TODO: Shift logic should only work if there's been an OUTPUT?

		if (timer_expired_d) begin
			// A timer expiry resets the state machine one EXTCLK after
			// timer_expired. This gives the shifter logic above a chance
			// to latch the incoming data bit.
			state <= S_INITIAL;
		end else begin
		
			// State specific logic
			case (state)
				S_INITIAL:		begin
										// state 0, no pulses yet
										
										// make sure to ack the first pulse
										testack_int <= 1'b1;

										// if we got a pulse in this state, advance
										state <= S_SHIFTONE;
									end
									
				S_SHIFTONE:		begin
										// One pulse received so far: Shift One

										// make sure to ack the second pulse, if any
										testack_int <= 1'b1;

										// Another pulse takes us to Shift Zero
										state <= S_SHIFTZERO;
									end
									
				S_SHIFTZERO:	begin
										// Two pulses received so far: Shift Zero
										
										// Third pulse response is "interface is ready for OUTPUT"
										// If this is zero, the interface will break (back to S_INITIAL)
										//   and try again with a fresh 3-pulse poll.
										testack_int <= rx_ready;
										state <= S_OUTPUTPOLL;
									end
									
				S_OUTPUTPOLL:	begin
										// Three pulses received so far. Poll OUTPUT ready state.
										//
										// The ACK response is set in the previous case block (i.e. the state transition).
										//
										// If NACK (no ACK pulse) then the host will delay, then send another 3-pulse POLL.
										//
										// If ACK (TESTACK pulses with TESTREQ) then the host will delay, then send eight bits with 
										//    SHIFT_ZERO and SHIFT_ONE commands.
										// 
										// Each sequence of eight bits is preceded by a POLL.
										//
										// At the end of a burst of bytes, a dummy 3-pulse poll burst occurs to make
										//   sure the last byte was recognised.
										//
										
										// The 4th pulse indicates the host wants to start an INPUT cycle and wants to know if we're ready.
										// Send the TX Ready flag then go to S_INPUTPOLL
										testack_int <= tx_ready;
										state <= S_INPUTPOLL;
									end
									
				S_INPUTPOLL:	begin
										// 4+ pulses. INPUT poll.
										// The fourth pulse is repeated until TESTACK is asserted in response.
										// After TESTACK is asserted, shift the next bit.

										// Load the shift register
										txshift <= txin;
										
										// Was the last pollbit we sent a '1'?
										if (!testack_int) begin
											// No data available, loop around sending poll bits
											testack_int <= tx_ready;
											state <= S_INPUTPOLL;
										end else begin
											// Latch the transmit data and send the ACK
											testack_int <= txin[7];
											state <= S_INPUT_BIT7;
										end
									end
									
				S_INPUT_BIT7:	begin
										// Currently sending bit 7, send bit 6 next
										testack_int <= txshift[6];
										state <= S_INPUT_BIT6;
									end

				S_INPUT_BIT6:	begin
										// Currently sending bit 6, send bit 5 next
										testack_int <= txshift[5];
										state <= S_INPUT_BIT5;
									end

				S_INPUT_BIT5:	begin
										// Currently sending bit 5, send bit 4 next
										testack_int <= txshift[4];
										state <= S_INPUT_BIT4;
									end

				S_INPUT_BIT4:	begin
										// Currently sending bit 4, send bit 3 next
										testack_int <= txshift[3];
										state <= S_INPUT_BIT3;
									end

				S_INPUT_BIT3:	begin
										// Currently sending bit 3, send bit 2 next
										testack_int <= txshift[2];
										state <= S_INPUT_BIT2;
									end

				S_INPUT_BIT2:	begin
										// Currently sending bit 2, send bit 1 next
										testack_int <= txshift[1];
										state <= S_INPUT_BIT1;
									end

				S_INPUT_BIT1:	begin
										// Currently sending bit 1, send bit 0 next
										testack_int <= txshift[0];
										state <= S_INPUT_BIT0;
									end

				S_INPUT_BIT0:	begin
										// Bit 0 is on the bus.
										// Raise TX_DONE (above), prepare to send the READY flag on the next pulse, then switch to S_INPUTPOLL
										// We need to do at least one polling cycle before we can send the next byte
										testack_int <= tx_ready;
										state <= S_INPUTPOLL;
									end
			
				default:			begin
										// Default state
										state <= S_INITIAL;
									end
			endcase
		end	
	end
	
endmodule
