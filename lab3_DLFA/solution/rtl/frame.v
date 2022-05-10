//////////////////////////////////////////////////////////////////////
//
// Original Code Copyright (c)2006-2014 by Cadence Design Systems (www.cadence.com)
//
// All rights reserved.
//
// This source file may be used and distributed without restriction
// provided that this copyright statement is not removed from the file
// and that any derivative work contains this copyright notice.
//
//////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////
//
// File name: frame.v
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
// 2.0   27/10/2014   Mike Avery   2009 and 2012 SV LRM update and Jasper support
// 2.1   1/8/2016   Mike Avery     Removed rst_n from combinatorial expressions
//

//Description.
//Correct Start of Packet and end of packet errors.
//**************************************************************************/

module frame (
	input wire  clk,
	input wire  rst_n,
	input wire  valid_in,
	input wire  sop_in,
	input wire  eop_in,
	output wire valid_out,
	output wire sop_out,
	output wire eop_out
	);


//################################ EDIT HERE #########################//
/***********  Declarations ***************************************/
// calculate when sop should not be passed through
wire mask_sop; 
// calculate when eop should not be passed through
wire mask_eop;

// remember if sop was seen and an eop was not seen; use to calculate mask_sop
wire sop_seen_no_eop_seen;
reg sop_seen_no_eop_seen_ff;
/********************  End Combinational Logic ********************/

/********************  Combinational Logic     ********************/
//Replicate valid signal to valid_out port
assign valid_out = valid_in;

//Produce a value that gets stored in a FF on next clock.
//Its value is either '1' if an SOP (qualified by valid_in) is seen without an EOP,
//else '0' (if the proceding condition was false i.e. no EOP seen) and we now see EOP (qualified by valid_in)
//else we maintain the value stored on the FF that indicates we have seen an SOP but we waiting for EOP
assign sop_seen_no_eop_seen =
  (valid_in && sop_in && !eop_in) ? 1'b1 :
  (valid_in && eop_in) ? 1'b0 : sop_seen_no_eop_seen_ff;

//Mask SOP if we have already seen an sop with no sop (state held on a FF) *and*
//another sop is received, qualified by a valid_in signal
assign mask_sop = valid_in && sop_in && sop_seen_no_eop_seen_ff;

//mask EOP if we have not already seen a SOP without a EOP previously 
//or we do not see SOP at the present moment
assign mask_eop = valid_in && eop_in && (!sop_seen_no_eop_seen_ff && !sop_in) ;

//Drive the corrected SOP and EOP out when qualified by a VALID_IN and the mask signal is not asserted.
assign sop_out = valid_in && sop_in && !mask_sop;
assign eop_out = valid_in && eop_in && !mask_eop;

/********************  End Combinational Logic ********************/

/********************  Sequential Logic        ********************/
always @(posedge clk or negedge rst_n)
begin
  if(!rst_n) begin
	sop_seen_no_eop_seen_ff <= 1'b0;
  end else
  begin
	sop_seen_no_eop_seen_ff <= sop_seen_no_eop_seen;
  end
end
/********************  End Sequential Logic ********************/


`ifdef ABV_ON 
/////////////   Put your assertions here /////////////////////











//################################ END OF EDIT  #########################//






/******************************************************************/
/********************  DO NOT EDIT BELOW THIS LINE   **************/
/******************************************************************/

///////////////////////////////////////////////////////////////////////////////////////

//Conditionally instance a VCOMP module if we are performing the predefined ACID_TEST.

`ifdef ACID_TEST
    bind frame frame_vcomp frame_vcomp_acid_inst(
    .vc_clk(clk),
    .vc_rst_n(rst_n),
    .vc_valid_in(valid_in),
    .vc_sop_in(sop_in),
    .vc_eop_in(eop_in),
    .vc_valid_out(valid_out),
    .vc_sop_out(sop_out),
    .vc_eop_out(eop_out)
    );
`endif //ACID_TEST
///////////////////////////////////////////////////////////////////////////////////////

`endif // ABV_ON

endmodule

