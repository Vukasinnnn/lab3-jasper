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

module te
#(
parameter DMA_NUM_CHANNELS=2,
parameter DMA_AWIDTH=10,
parameter DMA_MAX_LENGTH=32,
parameter PKT_NUM_IFC=2,
parameter PKT_MAX_PAYLOAD_IN_BYTES=16,
parameter PKT_AKID_WIDTH=2,
parameter PKT_XID_WIDTH=3,
parameter PKT_SDID_WIDTH=4,
parameter BM_PKTS_PER_CHANNEL=1,
parameter DA_DWIDTH_IN_BYTES=4,
parameter DA_MAX_BURSTLENGTH_IN_BYTES=16,
parameter TC_SCRATCH_SPACE_IN_BYTES=8,
parameter TC_DWIDTH_IN_BYTES=4,
parameter TC_PIPE_DEPTH=4,
parameter BYTE_SIZE=1

)
(
clk_pkt,clk_bus, rst_n,
bm_addr, bm_we, bm_wdata, bm_rdata,
tc_req, tc_rnw, tc_aack, tc_addr, tc_wack, tc_wdata, tc_rack, tc_rdata,
da_req, da_rnw, da_bytecnt, da_addr, da_wdata, da_wrdy, da_rdata, da_rrdy,
pktib_sop, pktib_data, pktob_sop, pktob_data
);

// registers include:
//	interrupt status register	0
//	interrupt control register	1
//	port enable			2
//	dma#1 source			8
//	dma#1 dest			9
//	dma#1 priority & byte count	10
//	dma#1 control & status		11
//	    ...
//	dma#N source			4*N
//	dma#N dest			4*N+1
//	dma#N priority & byte count	4*N+2
//	dma#N control & status		4*N+3
//
// The CSR address space occupies the low order portion of the
// TC address space.  Scratch space begins at the next power of
// two after 8*N+5 and extends for TC_SCRATCH_SPACE_IN_BYTES.
// DMA buffer space starts where scratch space ends and extends
// for an amount that is sufficient to buffer the relevant number
// of DMA channels.
localparam CSR_SPACE_IN_WORDS = 4*DMA_NUM_CHANNELS+3;
localparam CSR_AWIDTH = `dfafn_range2size(CSR_SPACE_IN_WORDS);

localparam BM_SPACE_IN_BYTES =
    TC_SCRATCH_SPACE_IN_BYTES + BM_PKTS_PER_CHANNEL*DMA_NUM_CHANNELS*PKT_MAX_PAYLOAD_IN_BYTES;

localparam BM_DWIDTH_IN_BYTES = 2*DA_DWIDTH_IN_BYTES;
localparam BM_DWIDTH = BM_DWIDTH_IN_BYTES*BYTE_SIZE;
localparam BM_AWIDTH =
    `dfafn_range2size(`dfafn_cdiv(BM_SPACE_IN_BYTES,BM_DWIDTH_IN_BYTES));

// Round up to next highest power of 2 address
localparam TC_SCRATCH_START =
    `dfafn_pow2(`dfafn_range2size(CSR_SPACE_IN_WORDS*TC_DWIDTH_IN_BYTES));
// TC address space must be big enough to hold CSR's, scratch,
// and BM buffer space.
localparam TC_ASPACE_IN_BYTES =
    TC_SCRATCH_START +
    BM_SPACE_IN_BYTES;
localparam TC_AWIDTH =
    `dfafn_range2size(`dfafn_cdiv(TC_ASPACE_IN_BYTES,TC_DWIDTH_IN_BYTES));
localparam TC_DWIDTH = TC_DWIDTH_IN_BYTES*BYTE_SIZE;

localparam DA_DWIDTH = DA_DWIDTH_IN_BYTES*BYTE_SIZE;
localparam DA_BYTECNT_WIDTH = `dfafn_range2size(DA_MAX_BURSTLENGTH_IN_BYTES+1);
localparam DMA_BYTECNT_WIDTH = `dfafn_range2size(DMA_MAX_LENGTH);

localparam PKT_DWIDTH = 8;
localparam PNI = PKT_NUM_IFC;

input clk_pkt, clk_bus, rst_n;
output [BM_AWIDTH-1:0] bm_addr;
output bm_we;
output [BM_DWIDTH-1:0] bm_wdata;
input [BM_DWIDTH-1:0] bm_rdata;
input tc_req;
input tc_rnw;
output tc_aack;
input [TC_AWIDTH-1:0] tc_addr;
output tc_wack;
input [TC_DWIDTH-1:0] tc_wdata;
output tc_rack;
output [TC_DWIDTH-1:0] tc_rdata;
output da_req;
output da_rnw;
output [DA_BYTECNT_WIDTH-1:0] da_bytecnt;
output [DMA_AWIDTH-1:0] da_addr;
output [DA_DWIDTH-1:0] da_wdata;
input da_wrdy;
output [DA_DWIDTH-1:0] da_rdata;
input da_rrdy;
input [PNI-1:0] pktib_sop;
input [PNI*PKT_DWIDTH-1:0] pktib_data;
output [PNI-1:0] pktob_sop;
output [PNI*PKT_DWIDTH-1:0] pktob_data;

///////////////////////////////////////////////////////////////////////////////
//
// Control and status registers
//
///////////////////////////////////////////////////////////////////////////////
wire tc_csr_req;
wire tc_csr_rnw;
wire csr_tc_ack;
wire [CSR_AWIDTH-1:0] tc_csr_addr;
wire [TC_DWIDTH-1:0] tc_csr_wdata, tc_csr_rdata;

te_csr
    #(
	.DMA_NUM_CHANNELS(DMA_NUM_CHANNELS), .DMA_AWIDTH(DMA_AWIDTH),
	.DMA_MAX_LENGTH(DMA_MAX_LENGTH), .TC_DWIDTH(TC_DWIDTH),
	.PKT_NUM_IFC(PNI)
    )
    csr (
	.clk(clk_bus), .rst_n(rst_n),
	.tc_csr_req(tc_csr_req),
	.tc_csr_rnw(tc_csr_rnw),
	.csr_tc_ack(csr_tc_ack),
	.tc_csr_addr(tc_csr_addr[CSR_AWIDTH-1:0]),
	.tc_csr_wdata(tc_csr_wdata),
	.tc_csr_rdata(tc_csr_rdata)
    );

///////////////////////////////////////////////////////////////////////////////
//
// Buffer memory control
//
///////////////////////////////////////////////////////////////////////////////
wire [PNI-1:0] ib_bm_req, ib_bm_last, bm_ib_gnt;
wire [PNI-1:0] ob_bm_req, ob_bm_last, bm_ob_gnt;
wire da_bm_req, da_bm_last, bm_da_gnt;
wire tc_bm_req, tc_bm_last, bm_tc_gnt;
wire tc_bm_rnw, da_bm_rnw;
wire [BM_AWIDTH-1:0] tc_bm_addr, da_bm_addr;
wire [PNI*BM_AWIDTH-1:0] ib_bm_addr, ob_bm_addr;
wire [BM_DWIDTH-1:0] tc_bm_wdata, da_bm_wdata;
wire [PNI*BM_DWIDTH-1:0] ib_bm_wdata;
wire [BM_DWIDTH-1:0] bm_tc_rdata, bm_da_rdata;
wire [PNI*BM_DWIDTH-1:0] bm_ob_rdata;

te_bm
    #(
	.BM_AWIDTH(BM_AWIDTH),
	.BM_DWIDTH(BM_DWIDTH),
	.PKT_NUM_IFC(PNI)
    )
    buffer_mem(
	.clk(clk_bus), .rst_n(rst_n),
	.bm_addr(bm_addr),
	.bm_we(bm_we),
	.bm_wdata(bm_wdata),
	.bm_rdata(bm_rdata),
	.ib_bm_req(ib_bm_req),
	.ib_bm_last(ib_bm_last),
	.bm_ib_gnt(bm_ib_gnt),
	.ob_bm_req(ob_bm_req),
	.ob_bm_last(ob_bm_last),
	.bm_ob_gnt(bm_ob_gnt),
	.da_bm_req(da_bm_req),
	.da_bm_last(da_bm_last),
	.bm_da_gnt(bm_da_gnt),
	.tc_bm_req(tc_bm_req),
	.tc_bm_last(tc_bm_last),
	.bm_tc_gnt(bm_tc_gnt),
	.tc_bm_rnw(tc_bm_rnw),
	.da_bm_rnw(da_bm_rnw),
	.tc_bm_addr(tc_bm_addr),
	.da_bm_addr(da_bm_addr),
	.ib_bm_addr(ib_bm_addr),
	.ob_bm_addr(ob_bm_addr),
	.tc_bm_wdata(tc_bm_wdata),
	.da_bm_wdata(da_bm_wdata),
	.ib_bm_wdata(ib_bm_wdata),
	.bm_tc_rdata(bm_tc_rdata),
	.bm_da_rdata(bm_da_rdata),
	.bm_ob_rdata(bm_ob_rdata)
    );

///////////////////////////////////////////////////////////////////////////////
//
// Transfer control bus interface
//
///////////////////////////////////////////////////////////////////////////////
te_tcbus
    #(
	.BM_AWIDTH(BM_AWIDTH), .BM_DWIDTH_IN_BYTES(BM_DWIDTH_IN_BYTES),
	.CSR_AWIDTH(CSR_AWIDTH),
	.TC_AWIDTH(TC_AWIDTH), .TC_DWIDTH_IN_BYTES(TC_DWIDTH_IN_BYTES),
	.TC_PIPE_DEPTH(TC_PIPE_DEPTH), .BYTE_SIZE(BYTE_SIZE)
    )
    tcbus(
	.clk(clk_bus), .rst_n(rst_n),
	.tc_bm_req(tc_bm_req),
	.tc_bm_last(tc_bm_last),
	.tc_bm_addr(tc_bm_addr),
	.tc_bm_rnw(tc_bm_rnw),
	.tc_bm_wdata(tc_bm_wdata),
	.bm_tc_rdata(bm_tc_rdata),
	.bm_tc_gnt(bm_tc_gnt),
	.tc_csr_req(tc_csr_req),
	.tc_csr_rnw(tc_csr_rnw),
	.csr_tc_ack(csr_tc_ack),
	.tc_csr_addr(tc_csr_addr),
	.tc_csr_wdata(tc_csr_wdata),
	.tc_csr_rdata(tc_csr_rdata),
	.tc_req(tc_req),
	.tc_rnw(tc_rnw),
	.tc_aack(tc_aack),
	.tc_addr(tc_addr),
	.tc_wack(tc_wack),
	.tc_wdata(tc_wdata),
	.tc_rack(tc_rack),
	.tc_rdata(tc_rdata)
    );

///////////////////////////////////////////////////////////////////////////////
//
// Data access bus interface
//
///////////////////////////////////////////////////////////////////////////////
wire [BM_DWIDTH-1:0] dma_da_req;
wire dma_da_dir;
wire [DMA_BYTECNT_WIDTH-1:0] dma_da_bytecnt;
wire [BM_AWIDTH-1:0] dma_da_ob_saddr;
wire [DMA_AWIDTH-1:0] dma_da_ob_daddr;
wire [DMA_AWIDTH-1:0] dma_da_ib_saddr;
wire [BM_AWIDTH-1:0] dma_da_ib_daddr;
wire da_dma_done;

te_dabus
    #(
	.DMA_AWIDTH(DMA_AWIDTH), .DMA_MAX_LENGTH(DMA_MAX_LENGTH),
	.BM_AWIDTH(BM_AWIDTH), .BM_DWIDTH(BM_DWIDTH),
	.DA_DWIDTH_IN_BYTES(DA_DWIDTH_IN_BYTES),
	.DA_MAX_BURSTLENGTH_IN_BYTES(DA_MAX_BURSTLENGTH_IN_BYTES),
	.BYTE_SIZE(BYTE_SIZE)
    )
    dabus (
	.clk(clk_bus), .rst_n(rst_n),
	.da_req(da_req),
	.da_rnw(da_rnw),
	.da_bytecnt(da_bytecnt),
	.da_addr(da_addr),
	.da_wdata(da_wdata),
	.da_wrdy(da_wrdy),
	.da_rdata(da_rdata),
	.da_rrdy(da_rrdy),
	.da_bm_req(da_bm_req),
	.da_bm_last(da_bm_last),
	.bm_da_gnt(bm_da_gnt),
	.da_bm_rnw(da_bm_rnw),
	.da_bm_addr(da_bm_addr),
	.da_bm_wdata(da_bm_wdata),
	.bm_da_rdata(bm_da_rdata),
	.dma_da_req(dma_da_req),
	.dma_da_dir(dma_da_dir),
	.dma_da_bytecnt(dma_da_bytecnt),
	.dma_da_ob_saddr(dma_da_ob_saddr),
	.dma_da_ob_daddr(dma_da_ob_daddr),
	.dma_da_ib_saddr(dma_da_ib_saddr),
	.dma_da_ib_daddr(dma_da_ib_daddr),
	.da_dma_done(da_dma_done)
    );

///////////////////////////////////////////////////////////////////////////////
//
// Packet Interface(s)
//
///////////////////////////////////////////////////////////////////////////////
wire [PNI-1:0] dma_pkt_req;
wire [PNI-1:0] dma_pkt_dir;
wire [PNI*DMA_BYTECNT_WIDTH-1:0] dma_pkt_bytecnt;
wire [PNI*BM_AWIDTH-1:0] dma_pkt_ob_saddr;
wire [PNI*DMA_AWIDTH-1:0] dma_pkt_ob_daddr;
wire [PNI*DMA_AWIDTH-1:0] dma_pkt_ib_saddr;
wire [PNI*BM_AWIDTH-1:0] dma_pkt_ib_daddr;
wire [PNI-1:0] pkt_dma_done;

generate
genvar i;
for(i=0;i<PNI;i=i+1) begin :pkt_loop

te_pkt
    #(
	.MAX_PAYLOAD_IN_BYTES(PKT_MAX_PAYLOAD_IN_BYTES),
	.AKID_WIDTH(PKT_AKID_WIDTH),
	.SDID_WIDTH(PKT_SDID_WIDTH),
	.XID_WIDTH(PKT_XID_WIDTH),
	.DMA_AWIDTH(DMA_AWIDTH), .DMA_MAX_LENGTH(DMA_MAX_LENGTH),
	.BM_AWIDTH(BM_AWIDTH), .BM_DWIDTH_IN_BYTES(BM_DWIDTH_IN_BYTES),
	.BYTE_SIZE(BYTE_SIZE)
    )
    pi (
	.clk_bus(clk_bus), .clk_pkt(clk_pkt), .rst_n(rst_n),
	.pktib_sop(pktib_sop[i]),
	.pktib_data(pktib_data[i*PKT_DWIDTH +: PKT_DWIDTH]),
	.pktob_sop(pktob_sop[i]),
	.pktob_data(pktob_data[i*PKT_DWIDTH +: PKT_DWIDTH]),
	.ib_bm_req(ib_bm_req[i]),
	.ib_bm_last(ib_bm_last[i]),
	.bm_ib_gnt(bm_ib_gnt[i]),
	.ob_bm_req(ob_bm_req[i]),
	.ob_bm_last(ob_bm_last[i]),
	.bm_ob_gnt(bm_ob_gnt[i]),
	.ib_bm_addr(ib_bm_addr[i*BM_AWIDTH +: BM_AWIDTH]),
	.ob_bm_addr(ob_bm_addr[i*BM_AWIDTH +: BM_AWIDTH]),
	.ib_bm_wdata(ib_bm_wdata[i*BM_DWIDTH +: BM_DWIDTH]),
	.bm_ob_rdata(bm_ob_rdata[i*BM_DWIDTH +: BM_DWIDTH]),
	.dma_pkt_req(dma_pkt_req[i]),
	.dma_pkt_dir(dma_pkt_dir[i]),
	.dma_pkt_bytecnt(dma_pkt_bytecnt[i*DMA_BYTECNT_WIDTH +: DMA_BYTECNT_WIDTH]),
	.dma_pkt_ob_saddr(dma_pkt_ob_saddr[i*BM_AWIDTH +: BM_AWIDTH]),
	.dma_pkt_ob_daddr(dma_pkt_ob_daddr[i*DMA_AWIDTH +: DMA_AWIDTH]),
	.dma_pkt_ib_saddr(dma_pkt_ib_saddr[i*DMA_AWIDTH +: DMA_AWIDTH]),
	.dma_pkt_ib_daddr(dma_pkt_ib_daddr[i*BM_AWIDTH +: BM_AWIDTH]),
	.pkt_dma_done(pkt_dma_done[i])
    );

end
endgenerate

`ifdef ABV_ON

vcomp_tcbus 
#(.TC_AWIDTH(TC_AWIDTH), .TC_DWIDTH(TC_DWIDTH)) vcomp_tbus_inst(.clk_bus(clk_bus), .rst_n(rst_n), .tc_req(tc_req), 
								.tc_rnw(tc_rnw), .tc_addr(tc_addr), .tc_wdata(tc_wdata), 
								.tc_aack(tc_aack), .tc_rack(tc_rack), .tc_wack(tc_wack));

`endif

endmodule
