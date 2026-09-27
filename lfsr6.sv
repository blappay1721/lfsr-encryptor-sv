// LFSR generator
// This function is useful in both encoder and decoder
/* the 6 possible maximal-length feedback tap patterns from which to choose
  assign LFSR_ptrn[0] = 6'h21;
  assign LFSR_ptrn[1] = 6'h2D;
  assign LFSR_ptrn[2] = 6'h30;
  assign LFSR_ptrn[3] = 6'h33;
  assign LFSR_ptrn[4] = 6'h36;
  assign LFSR_ptrn[5] = 6'h39;
  */
module lfsr6(
  input              clk,
                     en,		  // 1: advance to next state; 0: hold current state
			         init,		  // 1: force state to "start"
  input       [5:0]  taps,		  // parity feedback pattern
                     start,		  // initial state
  output logic[5:0]  state);	  // current state

  logic[5:0] taptrn;			  // or just use taps input, if it never changes
  always @(posedge clk)
	if(init) begin
	  state  <= start;			  // load starting state (should match data_mem[63])
	  taptrn <= taps;			  // load tap pattern (should match data_mem[62])
	end
	else if(en)					  // advance to next state
	  state  <= {state[4:0],^(state&taptrn)};

endmodule