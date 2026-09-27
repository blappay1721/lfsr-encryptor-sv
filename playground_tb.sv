// Scratch testbench for LFSR message encryption (also dumps waveforms to dump.vcd)
// full testbench for programmable message encryption
// the 6 possible maximal-length feedback tap patterns from which to choose
/*  
  assign LFSR_ptrn[0] = 6'h21;
  assign LFSR_ptrn[1] = 6'h2D;
  assign LFSR_ptrn[2] = 6'h30;
  assign LFSR_ptrn[3] = 6'h33;
  assign LFSR_ptrn[4] = 6'h36;
  assign LFSR_ptrn[5] = 6'h39;
  */
module playground_tb                 ;
  bit        clk               ;		 // advances simulation step-by-step
  bit        init = 1          ;         // init (reset, start) command to DUT
  wire       done              ;         // done flag returned by DUT
  bit  [7:0] message[52]       ,		 // original message, in binary
             msg_padded[64]    ,		 // original message, plus pre- and post-padding
             msg_crypto[64]    ,		 // encrypted message to test against DUT
             msg_crypto_DUT[64],         // encrypted message according to the DUT
			 pre_length        ;         // encrypted space bytes before first character in message
  bit  [5:0] lfsr_ptrn         ,         // one of 6 maximal length 6-tap shift reg. ptrns
			 lfsr_state        ;         // initial state of encrypting LFSR         
  bit  [5:0] LFSR              ;		 // linear feedback shift register, makes PN code
  bit  [7:0] ind               ;		 // index counter -- increments on each clock cycle

// ***** original message string to be encrypted *****
// the design handles any ASCII string
//   whose characters are chosen from ASCII vales of 0x40 through 0x7F
// our original American Standard Code for Information Interchange message follows
// A-Z   a-z  @ ' [] {} | \ ^ ~ _
//  string     str  = "Mr_Watson_come_here_I_want_to_see_you";
//  string  str = "Hello_their_xor_is_^_";
  string           str = "`@``@@```@@@````@@@@`````@@@@@`````@@@@@@";
  int str_len                  ;		 // length of string (character count)
  assign str_len = str.len     ;
//  initial #10ns $display("string length = %0d  %0d",str_len,str.len);
// displayed encrypted string will go here:
  string     str_enc[64]       ; 	 

// the DUT's top level module is top_level
  top_level dut(.clk  (clk),	 	     // device under test
                .init (init),            // request from test bench  
                .done (done)) ;          // acknowledge from DUT

// ***** choose one of the 6 feedback TAP patterns *****
  int i;                                 // choose the LFSR_ptrn; legal values = 0 to 5; 
  int j = 7;                             // preamble length
//  logic[5:0] LFSR_ptrn[6];               // testbench will automatically apply whichever is chosen
//  assign LFSR_ptrn[0] = 6'h21;           //  and check the DUT's results
//  assign LFSR_ptrn[1] = 6'h2D;
//  assign LFSR_ptrn[2] = 6'h30;
//  assign LFSR_ptrn[3] = 6'h33;
//  assign LFSR_ptrn[4] = 6'h36;
//  assign LFSR_ptrn[5] = 6'h39;

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
// ***** select the preamble length *****  
    if(j<7)  j  =  7;  			         // minimum preamble length
    if(j>12) j  = 12;              		 // maximum preamble length
	pre_length  = j;                     // set preamble length
//    if(i>5) begin 
//      i   = 5            ;               // restricts to legal
//      $display("illegal tap pattern chosen, force to 6'h39");        
//    end
//	else $display("tap pattern selected = %d",LFSR_ptrn[i]);
//    lfsr_ptrn   = LFSR_ptrn[i] ;         // selects one of 6 permitted
    i = 4;
    case(i) 
      0: lfsr_ptrn = 6'h21;
      1: lfsr_ptrn = 6'h2D;
      2: lfsr_ptrn = 6'h30;
      3: lfsr_ptrn = 6'h33;
      4: lfsr_ptrn = 6'h36;
      default: lfsr_ptrn = 6'h39;      
    endcase  
    
// ***** choose any nonzero 6-bit starting state for the LFSR ******
	lfsr_state  = 6'h01        ;         // any nonzero value will do; something simple facilitates debug
	if(!lfsr_state) lfsr_state = 6'h20;  // prevents nonzero lfsr_state by substituting 6'b10_0000
    LFSR        = lfsr_state   ;         // initalize test bench's LFSR
	$display("initial LFSR_state = %h",lfsr_state);
    $display("%s",str)         ;         // print original message in transcript window
    $display("string length = %d",str_len);
    for(int j=0; j<64; j++) 			 // pre-fill message_padded with ASCII _ characters
      msg_padded[j] = 8'h5F;         	 //    as placeholders: see next line  
    for(int l=0; l<str_len; l++)  		 // overwrite up to 54 of these spaces w/ message itself
	  msg_padded[pre_length+l] = str[l]; // leaves pre_length ASCII _ in front of the message itself
    for(int n=0; n<pre_length; n++)
	  dut.dm1.core[n] = 8'h5F;           // prefill data mem w/ _
    for(int m=0; m<str_len; m++)  
	  dut.dm1.core[m+1] = str[m];	         // copy original string into device's data memory[0:49]
    for(int n=str_len+1; n<61; n++)
	  dut.dm1.core[n] = 8'h5f;
	$display("preamble_length = %d",pre_length);
    dut.dm1.core[61] = pre_length;//-1;     // number of bytes preceding message 
	dut.dm1.core[62] = lfsr_ptrn;		 // LFSR feedback tap positions (8 possible ptrns)
	dut.dm1.core[63] = lfsr_state;		 // LFSR starting state (nonzero)
//  optional diagnostic print statement:
//    $display("%d  %h  %h  %h  %s",i,message[i],msg_padded[i],msg_crypto[i],str[i]);
    #20ns init = 0             ;
    #60ns; 	  
    for(int ij=0; ij<64; ij++) begin
      msg_crypto[ij]        = msg_padded[ij] ^ {2'b0,LFSR}; // encrypt 6 LSBs
//  $displayb(msg_padded[i],,,LFSR,,,msg_crypto[i]);
      LFSR                 = (LFSR<<1)+(^(LFSR&lfsr_ptrn));//{LFSR[4:0],feedback};		   // roll the rolling code
      str_enc[ij]           = string'(msg_crypto[ij]);
    end
                               // wait for 6 clock cycles of nominal 10ns each
    wait(done);                          // wait for DUT's done flag to go high
	// print testbench version of encrypted message next to DUT's version -- should match
/*    if(i<15)
      $display("%d  %h  %h  %h  %s  %s",
        i,message[i],msg_padded[i],msg_crypto[i],str[i-16],str_enc[i]);
    else
      $display("%d  %h  %h  %h  ",
        i,message[i],msg_padded[i],msg_crypto[i]);//,str[i],str_enc[i]);
*/ 
    for(int n=0; n<64; n++)	begin
      $write("%d bench msg: %s %h %h %s dut msg: %h",n, msg_padded[n],msg_padded[n],msg_crypto[n],msg_crypto[n],dut.dm1.core[n+64]);   
      if(msg_crypto[n]==dut.dm1.core[n+64]) $display("    very nice!");
	  else $display("      oops!");
	end
    $display("original message  = %s",string'(msg_padded));
    $write  ("encrypted message = ");
    for(int kk=0; kk<64; kk++)
      $write("%s",string'(msg_crypto[kk]));//msg_crypto);
    $display();  
    $stop;
  end

always begin							 // continuous loop
  #5ns clk = 1;							 // clock tick
  #5ns clk = 0;							 // clock tock
// print count, message, padded message, encrypted message, ASCII of message and encrypted
end										 // continue

endmodule