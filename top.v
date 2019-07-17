module top(

output DIL_1,
input  DIL_1_GCK,
output DIL_2,
input  DIL_2_GCK,
output DIL_3,
/* 
	DIL_4, DIL_5, DIL_6, DIL_7,
   DIL_8, DIL_9, DIL_10, DIL_11,
	DIL_12, DIL_13, DIL_15, DIL_16,
	DIL_17, DIL_18, DIL_19,	DIL_20,
	DIL_21,
*/
output DIL_22,
output DIL_23,
output DIL_24,
output DIL_25,
output DIL_26,
output DIL_27,
output _PGND1,
output _PGND2
);

  // PGND need to be pulled low to avoid ground bounce
  assign _PGND1 = 1'b0;
  assign _PGND2 = 1'b0;
  
  // DIL1 and DIL2 are paired with the GCKs and need to be assigned hi-Z
  assign DIL_1 = 1'bZ;
  assign DIL_2 = 1'bZ;
  
  wire[3:0] lcd_dq;
  wire lcd_rs, lcd_e;
  assign DIL_27 = lcd_dq[3];
  assign DIL_26 = lcd_dq[2];
  assign DIL_25 = lcd_dq[1];
  assign DIL_24 = lcd_dq[0];
  assign DIL_23 = lcd_rs;
  assign DIL_22 = lcd_e;

  wire testack_int;
  assign DIL_3 = testack_int ? 1'b1 : 1'bZ;		// Only allow TESTACK to drive high or float

  wire [7:0] rxdata;
  wire rxready;
  wire rxstrobe;
  
  postcode p(
			.refclk(DIL_1_GCK),		// refclk
			.testreq(DIL_2_GCK),		// testreq
			.testack(testack_int),	// testack
			
			.rxout(rxdata),			// received data
			.rxready(rxready),		// receive ready (1=ready)
			.rxstrobe(rxstrobe),		// receive strobe (1=data in rxout)
			
			.txin(8'd0),				// TX data in (for INPUT command) -- 0 indicates a display
			.tx_pending(1'b1)			// TX data pending
			);
			
	// Ref clock is 12MHz, tweak the timer for this
	defparam p.TIMER_MAX = (15*12)-1;		// 15us timeout, 12MHz clock

	
	// Latch the data from the shift register and extend the E signal
	
	reg[7:0] rxlatch;
	reg lcd_e_long;
	wire lcd_e_masked = (!rxdata[0]) & rxstrobe;
	always @(posedge lcd_e_masked) begin
		// Latch the LCD data on every E-strobe
		rxlatch <= rxdata;
	end

	always @(posedge lcd_e_masked or posedge DIL_2_GCK) begin
		if (lcd_e_masked) begin
			// Data received, latch it and set the E-line
			lcd_e_long <= 1'b1;
		end else begin
			// TESTREQ pulse, start of next command. Clear the E-line.
			lcd_e_long <= 1'b0;
		end
	end
	
	// Wire up the LCD
	assign lcd_dq = rxlatch[7:4];			// Data is in the most significant nibble
	assign lcd_rs = rxlatch[3];				// RS is bit 3
		// Bits 2 and 1 are unused
	assign lcd_e = lcd_e_long;
	
	
	// Monostable to generate the 5ms lockout
	localparam LCD_CMD_TMAX = (5000*12);
	reg[15:0] lcd_cmd_timer;
	always @(posedge DIL_1_GCK or posedge lcd_e_long) begin
		if (lcd_e_long) begin
			lcd_cmd_timer <= 0;
		end else begin
			if (lcd_cmd_timer < LCD_CMD_TMAX) begin
				lcd_cmd_timer <= lcd_cmd_timer + 16'd1;
			end
		end
	end
	
	assign rxready = (lcd_cmd_timer >= LCD_CMD_TMAX);

	
endmodule
