/*****************************************************************************

 (c) Copyright 2005, Cadence Design Systems, Inc.                       
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

 Author: Paul Hylander

******************************************************************************/

`include "dfafn_lib.h"

module te_bm
#(
parameter BM_AWIDTH=10,
parameter BM_DWIDTH=64,
parameter PKT_NUM_IFC=2
)
(
input clk, rst_n,
output [BM_AWIDTH-1:0] bm_addr,
output bm_we,
output [BM_DWIDTH-1:0] bm_wdata,
input [BM_DWIDTH-1:0] bm_rdata,

input [PKT_NUM_IFC-1:0] ib_bm_req,
input [PKT_NUM_IFC-1:0] ib_bm_last,
output [PKT_NUM_IFC-1:0] bm_ib_gnt,
input [PKT_NUM_IFC-1:0] ob_bm_req,
input [PKT_NUM_IFC-1:0] ob_bm_last,
output [PKT_NUM_IFC-1:0] bm_ob_gnt,
input da_bm_req,
input da_bm_last,
output bm_da_gnt,
input tc_bm_req,
input tc_bm_last,
output  bm_tc_gnt,

input tc_bm_rnw,
input da_bm_rnw,
input [BM_AWIDTH-1:0] tc_bm_addr,
input [BM_AWIDTH-1:0] da_bm_addr,
input [PKT_NUM_IFC*BM_AWIDTH-1:0] ib_bm_addr,
input [PKT_NUM_IFC*BM_AWIDTH-1:0] ob_bm_addr,
input [BM_DWIDTH-1:0] tc_bm_wdata,
input [BM_DWIDTH-1:0] da_bm_wdata,
input [PKT_NUM_IFC*BM_DWIDTH-1:0] ib_bm_wdata,
output [BM_DWIDTH-1:0] bm_tc_rdata,
output [BM_DWIDTH-1:0] bm_da_rdata,
output [PKT_NUM_IFC*BM_DWIDTH-1:0] bm_ob_rdata

);

///////////////////////////////////////////////////////////////////////////////
//
// The section below is the BM access arbitration.  It takes requests from TCBUS
// DABUS and PKT1 and PKT2.  Arbitration is as follows:
//
//  TC accesses - highest priority
//  PKT0, PKT1 (both inbound and outbound directions) and DABUS accesses have 
//	equal priority.  Round-robin amongst these accesses.
//
///////////////////////////////////////////////////////////////////////////////

// First, arbitrate between pkt interfaces and da interface.
localparam NUM_BM_REQ = PKT_NUM_IFC*2+1+1;
wire [NUM_BM_REQ-2:0] gnt_lev1;
wire [NUM_BM_REQ-1:0] gnt_lev2;

assign {bm_ib_gnt, bm_ob_gnt, bm_da_gnt, bm_tc_gnt} =
    gnt_lev2;

dfafn_arb #(.N(NUM_BM_REQ-1), .ARB_TYPE("ROUND_ROBIN"), .PRIO_DIR("SEARCH_LEFT"))
pkt_da_rr_arb(
    .clk(clk), .rst_n(rst_n),
    .gnt(gnt_lev1),
    .req({ib_bm_req, ob_bm_req, da_bm_req}),
    .last({ib_bm_last, ob_bm_last, da_bm_last}),
    .init_prio({ {NUM_BM_REQ-2{1'b0}}, 1'b1 })
);

// Use the result of the pkt/da arb to feed into this arb which then chooses
// between TC requests and pkt/da requests.
dfafn_arb #(.N(NUM_BM_REQ), .ARB_TYPE("PRIORITY"), .PRIO_DIR("SEARCH_LEFT"))
tc_versus_rest_arb(
    .clk(clk), .rst_n(rst_n),
    .gnt(gnt_lev2),
    .req({gnt_lev1, tc_bm_req}),
    .last({ib_bm_last, ob_bm_last, da_bm_last, tc_bm_last}),
    .init_prio({ {NUM_BM_REQ-1{1'b0}}, 1'b1 })
);


///////////////////////////////////////////////////////////////////////////////
//
// The section below is the BM address mux
//
///////////////////////////////////////////////////////////////////////////////
wire [NUM_BM_REQ*BM_AWIDTH-1:0] addr_mux_addr =
{
    ib_bm_addr,
    ob_bm_addr,
    da_bm_addr,
    tc_bm_addr
};

dfafn_switch #(.N(NUM_BM_REQ), .M(1), .WIDTH(BM_AWIDTH))
addr_mux(
    .datain(addr_mux_addr),
    .select(gnt_lev2),
    .dataout(bm_addr)
);

///////////////////////////////////////////////////////////////////////////////
//
// The section below is the BM data mux for the write direction
//
///////////////////////////////////////////////////////////////////////////////

// Since inbound from pkt's are always writes and outbound are always reads,
// use known constants for their positions.  da_bm_rnw is a rnw signal which
// is active low when the da is reading data from externally and wants to
// write to bm.
assign bm_we = |(gnt_lev2 & {2'b11, 2'b00, ~da_bm_rnw, ~tc_bm_rnw});

localparam NUM_BM_WR_REQ = PKT_NUM_IFC+1+1;

wire [NUM_BM_WR_REQ*BM_DWIDTH-1:0] wdata_mux_wdata =
{
    ib_bm_wdata,
    da_bm_wdata,
    tc_bm_wdata
};

wire [NUM_BM_WR_REQ-1:0] wdata_mux_sel =
{
    gnt_lev2[NUM_BM_REQ-1:NUM_BM_REQ-PKT_NUM_IFC],
    gnt_lev2[NUM_BM_REQ-PKT_NUM_IFC*2-1:0]
};

dfafn_switch #(.N(NUM_BM_WR_REQ), .M(1), .WIDTH(BM_DWIDTH))
wdata_mux(
    .datain(wdata_mux_wdata),
    .select(wdata_mux_sel),
    .dataout(bm_wdata)
);

///////////////////////////////////////////////////////////////////////////////
//
// The section below is the BM data demux for the read direction
//
///////////////////////////////////////////////////////////////////////////////
localparam NUM_BM_RD_REQ = PKT_NUM_IFC+1+1;

wire [NUM_BM_WR_REQ*BM_DWIDTH-1:0] rdata_demux_rdata;

reg [NUM_BM_RD_REQ-1:0] rdata_demux_sel;

// Need to delay by a clock to account for memory delay
always @(posedge clk)
    rdata_demux_sel <= gnt_lev2[NUM_BM_REQ-PKT_NUM_IFC-1:0];

dfafn_switch #(.N(1), .M(NUM_BM_RD_REQ), .WIDTH(BM_DWIDTH))
rdata_demux(
    .datain(bm_rdata),
    .select(rdata_demux_sel),
    .dataout(rdata_demux_rdata)
);

assign 
{
    bm_ob_rdata,
    bm_da_rdata,
    bm_tc_rdata
} = rdata_demux_rdata;


endmodule

