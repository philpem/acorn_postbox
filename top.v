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
  assign DIL_27 = lcd_dq[3];
  assign DIL_26 = lcd_dq[2];
  assign DIL_25 = lcd_dq[1];
  assign DIL_24 = lcd_dq[0];
  
  postcode p(
			DIL_1_GCK,		// refclk
			DIL_2_GCK,		// testreq
			DIL_3,			// testack
			
			lcd_dq,			// D4..7
			DIL_23,			// RS
			DIL_22,			// E
			
			8'd0,				// TX data in (for INPUT command) -- 0 indicates a display
			1'b1				// TX data pending
			);

endmodule
