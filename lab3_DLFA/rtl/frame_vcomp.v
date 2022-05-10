//////////////////////////////////////////////////////////////////////-
//
// Original Code Copyright (c)2006 - 2014 by Cadence Design Systems (www.cadence.com)
//
// All rights reserved.
//
// This source file may be used and distributed without restriction
// provided that this copyright statement is not removed from the file
// and that any derivative work contains this copyright notice.
//
//////////////////////////////////////////////////////////////////////-

//////////////////////////////////////////////////////////////////////
//
// File name: frame_vcomp.v
// Version  : 2.0
// Date     : 27/10/2014
// Author   : Mike Avery
// Company  : Cadence Design Systems
//
//////////////////////////////////////////////////////////////////////
//
// Revision history
//
// Rev:  Date;         Author:      Comments:
// 1.0   19/1/2006    Mike Avery   Initial issue
// 1.1   3/10/2007    Mike Avery   Initial issue
// 2.0   27/10/2014   Mike Avery   2009 and 2012 SV LRM update and Jasper support

//Description.
//Verification component for the frame module.
//Contains properties that will check if the users RTL implementation of the frame module
//meets the specification requirements
//**************************************************************************/

module frame_vcomp (
	input wire vc_clk,
	input wire vc_rst_n,
	input wire vc_valid_in,
	input wire vc_sop_in,
	input wire vc_eop_in,
	input wire vc_valid_out,
	input wire vc_sop_out,
	input wire vc_eop_out
	);

/******************************************************************/
/********************  Assertion Definition  ********************/
/******************************************************************/

`ifdef ABV_ON 

//Define a default clocking block
default clocking MYDEFCLK @(posedge vc_clk);
endclocking
 
//###########################################################################
//Check that an EOP does not occur without a corresponding SOP
//###########################################################################
//The property needs to have a RHS that is weak or we will just 
//see an infinite length CEX where vc_sop_out never occurs.
//Its only finite length CEX's in which we are interested.
//Note that the enabling condition is the completion of the previous SOP-EOP pair
//regardless of whether the corresponding SOP was in the same cycle or a previous one.
//We have a seperate property to check that there is not an initial EOP without
//a SOP so we can assume that the first EOP is correct, which simplifies 
//what we need to say in this property
SOL_NO_EOP_WO_SOP  : assert property 
                           ( @(posedge vc_clk) 
                             disable iff (!vc_rst_n)
                             ( vc_eop_out |=>  weak(!vc_eop_out[*] ##1 vc_sop_out)) 
                           );



//Another way of defining the same check with Auxiliary code.
//This turns a property containing a potetnially infinite length sequence into 
//a property which has same cycle implication.
   reg vc_sop_without_eop;

   always @(posedge vc_clk or negedge vc_rst_n)
     if (!vc_rst_n)
       vc_sop_without_eop <= 1'b0;
     else begin
	if (vc_sop_out && !vc_eop_out)
	  vc_sop_without_eop <= 1'b1;
	else if (vc_eop_out)
	  vc_sop_without_eop <= 1'b0;
     end

SOL_NO_EOP_WO_SOP_W_AUX_CODE: assert property ( 
                                @(posedge vc_clk)
		                 (vc_eop_out && !vc_sop_out) |-> vc_sop_without_eop
                              );




//###########################################################################
//Check we do not have two SOP's without an EOP
//###########################################################################
//Remember that we could have consecutive frames of length 1, i.e. SOP and EOP high in the same cycle consecutively.
//In addition we want to check that we don't get a conditon where we have an sop and no eop, followed in some
//later cycle by an occurence of sop and eop on the *same* cycle. This is an error because two frames would overlap
//If this was PSL then we would describe this with the inclusive form of until.

SOL_NOT_TWO_SOPS_WO_EOP : assert property 
                           ( @(posedge vc_clk) 
                             disable iff (!vc_rst_n)
                            (vc_sop_out && !vc_eop_out) |=> 
                              weak( (!vc_sop_out && !vc_eop_out)[*0:$] ##1 (!vc_sop_out && vc_eop_out ) )
                           );



//Another way of defining the same check with Auxiliary code.
//This turns a property containing a potetnially infinite length sequence into 
//a property which has same cycle implication.
   reg vc_pending_sop;

   always @(posedge vc_clk or negedge vc_rst_n)
     if (!vc_rst_n)
       vc_pending_sop <= 1'b0;
     else begin
	if (vc_sop_out && !vc_eop_out)
	  vc_pending_sop <= 1'b1;
	else if (vc_eop_out)
	  vc_pending_sop <= 1'b0;
     end

SOL_NOT_TWO_SOPS_WO_EOP_W_AUX_CODE: assert property ( @(posedge vc_clk)
		     vc_sop_out |-> !vc_pending_sop);


//######################################################################################
//Sanity Check Which We Are Expecting to Fail - Confidence check of tool and environment
//#######################################################################################
//Remember that we could have consecutive frames of length 1, i.e. SOP and EOP high in the same cycle consecutively.
//Therefore it is interesting to see the result of the property below.
//Notice that when the enabling condition occurs then we are not saying anything about
//what EOP is doing. Therefore we could be enabling the property when the EOP occured
//at the same time as the SOP, hence the requirements of the design are met but the property we wrote
//below still has future obligations, namely for the RHS to occur.
//Contrast the property below with the property SOL_NOT_TWO_SOPS_WO_EOP above.
//Surely then we will see a false negative because there could be a vc_sop_out the very next cycle, 
//which would cause the property to fail.
//We don't need to worry about corner cases. If there is a way in which the property could
//fail then formal will find it.

SOL_SHOULD_FAIL_SANITY_CHECK : assert property 
                           ( @(posedge vc_clk) 
                             disable iff (!vc_rst_n)
                            vc_sop_out  |=> 
                              weak( (!vc_sop_out && !vc_eop_out)[*0:$] ##1 (!vc_sop_out && vc_eop_out ) )
                           );



//###########################################################################
//Check that an SOP and EOP out do not occur without a vc_valid_out signal, when
//reset is inactive
//###########################################################################
SOL_NO_SOP_WO_VALID_IMP:        assert property ( @(posedge vc_clk) (vc_sop_out && vc_rst_n) |-> vc_valid_out );
SOL_NO_EOP_WO_VALID_IMP:        assert property ( @(posedge vc_clk) (vc_eop_out && vc_rst_n) |-> vc_valid_out );

//###########################################################################
//Check that no SOP and EOP when reset is active
//###########################################################################
SOL_NO_SOP_IN_RESET_IMP:        assert property ( @(posedge vc_clk) vc_sop_out |-> vc_rst_n);
SOL_NO_EOP_IN_RESET_IMP:        assert property ( @(posedge vc_clk) vc_eop_out |-> vc_rst_n);

//###########################################################################
//Check that no *OP_OUT only true in same cycle as *OP_IN
//###########################################################################
SOL_ONLY_SOP_OUT_WHEN_SOP_IN: assert property ( @(posedge vc_clk) ( vc_sop_out |-> vc_sop_in) );
SOL_ONLY_EOP_OUT_WHEN_EOP_IN: assert property ( @(posedge vc_clk) ( vc_eop_out |-> vc_eop_in) );


//###########################################################################
//Check that there is no inital EOP without a SOP after reset
//###########################################################################
//In Formal you often would like to define one-shot properties. In PSL you can describe this easily :-
//Below is a PSL property without an always or never. This kind of property is only evaluated from the
//initial cycle, hence is an example of a single shot property. It checks that from the first evaluation
//cycle, we do not get an eop without a sop.
//The property terminates, never to be reactivated under the following conditions:-
//a) vc_eop_out == '1' before vc_sop_out == '1', this is a failure
//b) vc_sop_out == '1' without vc_eop_out == '1' on a previous cycle , this is a pass
//NO_INITIAL_EOP_PSL : assert ((!vc_eop_out) until (vc_sop_out)); 

//In SVA the approach has to be different as SVA does not have semantics for describing 
//one-shot roperties directly.
// The property below is not one-shot
//unless we constrain reset to always be inactive after the the formal tool 
//and design are initialised.
SOL_NO_INITIAL_EOP_IMP : assert property ( 
                         @(posedge vc_clk) 
                          $rose(vc_rst_n)  |-> 
                             weak((!vc_eop_out && !vc_sop_out)[*] ##1 vc_sop_out )
                         );



//Another way of defining the same check with Auxiliary code.
//This turns a property containing a potetnially infinite length sequence into 
//a property which has same cycle implication.
   reg vc_first_eop_seen;
   reg vc_first_sop_seen;

always @(posedge vc_clk or negedge vc_rst_n)
  if (!vc_rst_n) begin
     vc_first_eop_seen <= 0;
     vc_first_sop_seen <= 0;
  end
  else begin
    if (vc_eop_out)
      vc_first_eop_seen <= 1;
    if (vc_sop_out) 
      vc_first_sop_seen <= 1;
  end

SOL_NO_INITAL_EOP_W_AUX_CODE:   assert property ( 
                               @(posedge vc_clk) vc_first_eop_seen |-> vc_first_sop_seen 
                                                );

/******************************************************************/
/********************  Coverage Definition  ***********************/
/******************************************************************/

//###########################################################################
//Cover that we can have consectutive back to back transfers
//###########################################################################
SOL_COV_B2B_SINGLE_CYCLE_TXNS: cover property ( 
                                 @(posedge vc_clk)  
                                 (vc_sop_out && vc_eop_out)[*3]
                               );

//###########################################################################
//Cover that we can have SOP then EOP 5 cycles later
//###########################################################################
SOL_COV_SOP_THEN_EOP_5_CYCLES: cover property ( 
                                 @(posedge vc_clk)  
            (vc_sop_out ##1 (!vc_sop_out && !vc_eop_out)[*4] ##1 vc_eop_out)
                               );

//###########################################################################
//Cover that we can have SOP/EOP OUT is not EQUAL to SOP/EOP IN
//###########################################################################
sequence SIGS_NOT_EQUAL(SIG1, SIG2);
             (SIG1 != SIG2);
endsequence

SOV_COV_EOPIN_NEQ_EOPOUT: cover property ( 
                                 @(posedge vc_clk)  
                                 SIGS_NOT_EQUAL(vc_eop_in, vc_eop_out)
                          );
SOV_COV_SOPIN_NEQ_SOPOUT: cover property ( 
                                 @(posedge vc_clk)  
                                 SIGS_NOT_EQUAL(vc_sop_in, vc_sop_out)
                          );
//###########################################################################
//Cover corrected SOP OUT 
//###########################################################################
SOV_COV_CORRECTED_SOPOUT: cover property ( 
                                 @(posedge vc_clk)  
             ( (vc_sop_in && !vc_eop_out) ##1 (!vc_sop_in && !vc_eop_out)[*3] 
                ##1 (vc_sop_in && !vc_eop_out) ##1 (!vc_sop_in && !vc_eop_out) ##1 vc_eop_out)
                          );

//###########################################################################
//Cover corrected EOP OUT 
//###########################################################################
SOV_COV_CORRECTED_EOPOUT: cover property ( 
                                 @(posedge vc_clk)  
             ( (vc_sop_out && !vc_eop_in) ##1 (!vc_sop_out && !vc_eop_in)[*2] 
                ##1 (!vc_sop_out && vc_eop_in)[*2] ##1 vc_sop_out)
                          );


`endif // ABV_ON

endmodule

