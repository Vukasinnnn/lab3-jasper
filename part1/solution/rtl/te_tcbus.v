/*****************************************************************************

 (c) Copyright 2005-2015, Cadence Design Systems, Inc.                       
 All rights reserved.                                                   

 This software is the proprietary information of Cadence Design         
 Systems, Inc. and may not be copied or reproduced in whole or in part  
 onto any medium without Cadence's express prior written consent.       

 This software is provided to the end user solely for his/her use.  No  
 warranties are expressed or implied herein including those as to       
 merchantability and fitness for a particular purpose.  In no event     
 shall Cadence be held liable for loss of profit, business              
 interruption, data, loss of information, or any other pecuniary loss   
 including but not limited to special, incidental, consequential, or    
 other damages.                                                         

 Original Author: Paul Hylander

Michael Avery
Version 2.0  - 13 February 2015 
Changes to remove lint warnings in Jasper and produce assetion failures
in the event of the constraints being incorrectly defined.

******************************************************************************/

`include "dfafn_lib.h"

module te_tcbus
#(
parameter BM_AWIDTH=10,
parameter BM_DWIDTH_IN_BYTES=8,
parameter CSR_AWIDTH=4,
parameter TC_AWIDTH=11,
parameter TC_DWIDTH_IN_BYTES=4,
parameter TC_PIPE_DEPTH=4,
parameter BYTE_SIZE=1
)
(
input clk, rst_n,
output tc_bm_req,
output tc_bm_last,
output [BM_AWIDTH-1:0] tc_bm_addr,
output tc_bm_rnw,
output [BM_DWIDTH_IN_BYTES*BYTE_SIZE-1:0] tc_bm_wdata,
input [BM_DWIDTH_IN_BYTES*BYTE_SIZE-1:0] bm_tc_rdata,
input bm_tc_gnt,
output tc_csr_req,
input csr_tc_ack,
output tc_csr_rnw,
output [CSR_AWIDTH-1:0] tc_csr_addr,
output [TC_DWIDTH_IN_BYTES*BYTE_SIZE-1:0] tc_csr_wdata,
input [TC_DWIDTH_IN_BYTES*BYTE_SIZE-1:0] tc_csr_rdata,
input tc_req,
input tc_rnw,
output tc_aack,
input [TC_AWIDTH-1:0] tc_addr,
output tc_wack,
input [TC_DWIDTH_IN_BYTES*BYTE_SIZE-1:0] tc_wdata,
output reg tc_rack,
output [TC_DWIDTH_IN_BYTES*BYTE_SIZE-1:0] tc_rdata
);

localparam TC_DWIDTH = TC_DWIDTH_IN_BYTES*BYTE_SIZE;
localparam BM_DWIDTH = BM_DWIDTH_IN_BYTES*BYTE_SIZE;
localparam TC_BM_DMULT = `dfafn_cdiv(BM_DWIDTH_IN_BYTES,TC_DWIDTH_IN_BYTES);
localparam TC_BM_LDMULT = `dfafn_range2size(TC_BM_DMULT);

// Need to create a delayed version of the grant for later use.  The grant
// is basically an acknowledge signal.  The init value must be 1 so that
// FIFO bypass works at the beginning.
reg bm_tc_gnt_ff;
reg csr_tc_ack_ff;
always @(posedge clk) begin
    if (!rst_n) bm_tc_gnt_ff <= 1'b1;
    else bm_tc_gnt_ff <= bm_tc_gnt;
    if (!rst_n) csr_tc_ack_ff <= 1'b1;
    else csr_tc_ack_ff <= csr_tc_ack;
end

///////////////////////////////////////////////////////////////////////////////
//
// The section below contains the TC transaction FIFO.  This FIFO buffers
// the transactions coming in from TCBUS.  It is first in first out, however
// all elements are visible simultaneously, because we allow for read
// access to addresses for which there are writes still pending in the fifo.
//
///////////////////////////////////////////////////////////////////////////////

// TCFIFO_DWIDTH must be wide enough to hold {RNW, ADDR, WDATA}
localparam TCFIFO_DWIDTH = 1 + TC_AWIDTH + TC_DWIDTH;

// All entries in the fifo must be readable.  Therefore the memory
// contained in the fifo is reflected in the array memarray.  memarray
// is organized into a set of TC_PIPE_DEPTH fields each of width TCFIFO_DWIDTH
// wide.
wire [TCFIFO_DWIDTH*TC_PIPE_DEPTH-1:0] memarray;

wire tcfifo_push, tcfifo_pop, tcfifo_empty, tcfifo_full, tcfifo_bypass;
reg tcfifo_pop_ff;
wire [TCFIFO_DWIDTH-1:0] tcfifo_pushdata, tcfifo_popdata;
//###########  MIKE_MOD  ################################################################
wire temp_block_pops_wire;
reg temp_block_pops;
reg constraint_error_seen;
//###########  END OF MIKE_MOD  #########################################################

assign temp_block_pops_wire = temp_block_pops;

fifo #(.NUM_ENTRIES(TC_PIPE_DEPTH), .DWIDTH(TCFIFO_DWIDTH)) tcfifo (
	.clk(clk),
	.rst_n(rst_n),
	.push(tcfifo_push),
	.pop(!temp_block_pops_wire && (tcfifo_pop || tcfifo_bypass)),
	.idata(tcfifo_pushdata),
	.full(tcfifo_full),
	.empty(tcfifo_empty),
	.odata(tcfifo_popdata),
	.memarray(memarray)
    );
//###############  MIKE_MOD ###########################
//This is the original. !tc_aack cannot occur, hence constraints LHS
// are not covered and there can never be pending write reqs, hence
//pending_wr_cnt_ff is never > 0, hence LHS of an assert is not covered either
//MIKE_MOD	.pop(tcfifo_pop || tcfifo_bypass),
//If tcfifo bypass removed from the port map
//MIKE_MOD	.pop(tcfifo_pop                 ),
//...then all asserts except 1 fail and all LHS of asserts and 
//constraints are covered

//###############  END OF MIKE_MOD ####################
    
assign tcfifo_push = tc_req && tc_aack;
assign tcfifo_pushdata = {tc_rnw, tc_addr, tc_wdata};

///////////////////////////////////////////////////////////////////////////////
//
// The section below unloads the fifo and breaks apart the transaction
// data into component pieces.
//
///////////////////////////////////////////////////////////////////////////////
wire tcslave_rnw;
wire [TC_AWIDTH-1:0] tcslave_addr;
wire [TC_DWIDTH-1:0] tcslave_wdata;

//###############  MIKE_MOD ###########################

// !tcfifo_pop_ff is necessary to avoid bypass data overwriting data coming out
// of the fifo memory from a pop the cycle before.
//The comment above was there originally. below is the orignal assign to the
//tcfifo_bypass
//assign  tcfifo_bypass =
//    !tcfifo_pop_ff && tcfifo_push && tcfifo_empty &&
//    (bm_tc_gnt_ff || csr_tc_ack_ff);
//This is modified below to blank it during the filling of the fifo
//All CEX's seem to be caused by byapss mode.
assign  tcfifo_bypass = !temp_block_pops &&
    !tcfifo_pop_ff && tcfifo_push && tcfifo_empty &&
    (bm_tc_gnt_ff || csr_tc_ack_ff);
//###############  END OF MIKE_MOD ####################


//###########  MIKE_MOD  ################################################################
//Replace the single line below to temporary block pops to allow pipe to get full
//assign tcfifo_pop = !tcfifo_empty && (bm_tc_gnt_ff || csr_tc_ack_ff);

reg [2:0] num_block_cycles_cnt;
always @(posedge clk or negedge rst_n)
    if (!rst_n)
      begin
	num_block_cycles_cnt <= 0;
        temp_block_pops <= 1'b1;
      end
//With num_block_cycles_cnt ==6 all asserts except 1 fail
//All assumes LHS covered. 3 is the minimum number to 
//get all assumes LHS covered but assetions still fail
    else if (num_block_cycles_cnt == 3 )
        temp_block_pops <= 1'b0;
    else 
	num_block_cycles_cnt <= num_block_cycles_cnt + 3'b001;

//assign tcfifo_pop = !temp_block_pops && !tcfifo_empty && (bm_tc_gnt_ff || csr_tc_ack_ff);
assign tcfifo_pop = !constraint_error_seen && !temp_block_pops && !tcfifo_empty && (bm_tc_gnt_ff || csr_tc_ack_ff);

//###########  END OF MIKE_MOD  #########################################################

//###########  MIKE_MOD  ################################################################
wire constraint_error;
reg [TC_DWIDTH_IN_BYTES*BYTE_SIZE-1:0] prev_tc_wdata;
reg prev_tc_rnw;
reg [TC_AWIDTH-1:0] prev_tc_addr;
reg prev_req_no_ack;
reg prev_tc_req;
wire inputs_stable;


assign constraint_error = prev_req_no_ack && !inputs_stable;
//mavery - tc_wdata only required to be stable for writes
assign inputs_stable = 
                      (prev_tc_rnw == tc_rnw) && ( (prev_tc_wdata == tc_wdata) || tc_rnw) && 
                      (prev_tc_addr == tc_addr) && (prev_tc_req   <= tc_req);

always @(posedge clk) begin
    if (!rst_n) 
       begin
           prev_req_no_ack <= 1'b0 ;
           prev_tc_rnw   <= 1'b0;
           prev_tc_wdata <= 0;
           prev_tc_addr  <= 0;
           prev_tc_req   <= 0;
           constraint_error_seen <= 1'b0 ;
       end
    else 
       begin
           prev_req_no_ack <= (tc_req && !tc_aack) ;
           prev_tc_rnw   <= tc_rnw;
           prev_tc_wdata <= tc_wdata;
           prev_tc_addr  <= tc_addr;
           prev_tc_req   <= tc_req;
           if (constraint_error)
                  constraint_error_seen <= 1'b1 ;
       end
end
//###########  END OF MIKE_MOD  #########################################################

always @(posedge clk)
    if (!rst_n)
	tcfifo_pop_ff <= 1'b0;
    else
	tcfifo_pop_ff <= tcfifo_pop;

assign {tcslave_rnw, tcslave_addr, tcslave_wdata} = tcfifo_popdata;

///////////////////////////////////////////////////////////////////////////////
//
// The section below decodes the target of the transaction
//
///////////////////////////////////////////////////////////////////////////////
localparam CSR_LO_ADDR = 0;
localparam CSR_HI_ADDR = `dfafn_pow2(CSR_AWIDTH);

assign tc_csr_req =	(tcfifo_pop_ff || tcfifo_bypass) &&
			tcslave_addr<CSR_HI_ADDR &&
			tcslave_addr>=CSR_LO_ADDR ;

assign tc_bm_req =	(tcfifo_pop_ff || tcfifo_bypass) && !tc_csr_req;

///////////////////////////////////////////////////////////////////////////////
//
// This section drives the appropriate values for bm related transactions
//
///////////////////////////////////////////////////////////////////////////////

// Since tc requests to bm are only one data transfer, this can be tied high.
 assign tc_bm_last = 1'b1;

wire [TC_AWIDTH-1:0] pre_tc_bm_addr = tcslave_addr - CSR_HI_ADDR[TC_AWIDTH-1:0];
reg [BM_DWIDTH-1:0] pre_tc_bm_wdata;
integer i;
always @* begin
    pre_tc_bm_wdata = {BM_DWIDTH{1'b0}};
    for(i=0;i<TC_BM_DMULT;i=i+1)
	pre_tc_bm_wdata[i*TC_DWIDTH +: TC_DWIDTH] = tcslave_wdata;
end

assign tc_bm_addr = tc_bm_req ?
    pre_tc_bm_addr[BM_AWIDTH+TC_BM_LDMULT-1:TC_BM_LDMULT] :
    {BM_AWIDTH{1'b0}};
assign tc_bm_wdata = tc_bm_req ?  pre_tc_bm_wdata : {BM_DWIDTH{1'b0}};
assign tc_bm_rnw = tcslave_rnw;

///////////////////////////////////////////////////////////////////////////////
//
// This section drives the appropriate values for csr related transactions
//
///////////////////////////////////////////////////////////////////////////////

assign tc_csr_addr = tc_csr_req ? tcslave_addr[CSR_AWIDTH-1:0] : {CSR_AWIDTH{1'b0}};
assign tc_csr_rnw = tcslave_rnw;
assign tc_csr_wdata = tc_csr_req ? tcslave_wdata : {TC_DWIDTH{1'b0}};

///////////////////////////////////////////////////////////////////////////////
//
// This section drives the appropriate responses back onto tc bus
//
///////////////////////////////////////////////////////////////////////////////
assign tc_aack = !tcfifo_full;
wire [TC_BM_DMULT-1:0] rdata_mux_sel;
dfafn_bin2hot #(TC_BM_DMULT) rdata_mux_sel_hot(tc_bm_addr[TC_BM_LDMULT-1:0], rdata_mux_sel);
dfafn_switch #(.N(TC_BM_DMULT), .M(1), .WIDTH(TC_DWIDTH))
    rdata_mux (
	.datain(bm_tc_rdata),
	.select(rdata_mux_sel),
	.dataout(tc_rdata)
    );

// tc_rack is delayed by a clock relative to the bm_tc_gnt, because
// bm_tc_gnt is one cycle advanced relative to read data valid
always @(posedge clk)
    if (!rst_n) tc_rack <= 1'b0;
    else
	tc_rack <= tcslave_rnw &&
         ((tc_bm_req && bm_tc_gnt) || 
          (tc_csr_req && csr_tc_ack)  );

assign tc_wack = !tcslave_rnw &&
         ((tc_bm_req && bm_tc_gnt) || 
          (tc_csr_req && csr_tc_ack)  );

endmodule

