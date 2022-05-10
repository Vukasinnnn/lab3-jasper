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

 Original Author: Paul Hylander

Michael Avery
Version 2.0  - 13 February 2015 
Changes to remove lint warnings in Jasper and produce assetion failures
in the event of the constraints being incorrectly defined.

******************************************************************************/

`include "dfafn_lib.h"

module te_pkt
#(
parameter MAX_PAYLOAD_IN_BYTES=16,
parameter AKID_WIDTH=2,
parameter SDID_WIDTH=4,
parameter XID_WIDTH=3,
parameter DMA_AWIDTH=10,
parameter DMA_MAX_LENGTH=32,
parameter BM_AWIDTH=10,
parameter BM_DWIDTH_IN_BYTES=8,
parameter BYTE_SIZE=8
)
(
clk_bus, clk_pkt, rst_n,
pktib_sop,
pktib_data,
pktob_sop,
pktob_data,
ib_bm_req,
ib_bm_last,
bm_ib_gnt,
ob_bm_req,
ob_bm_last,
bm_ob_gnt,
ib_bm_addr,
ob_bm_addr,
ib_bm_wdata,
bm_ob_rdata,
dma_pkt_req,
dma_pkt_dir,
dma_pkt_bytecnt,
dma_pkt_ob_saddr,
dma_pkt_ob_daddr,
dma_pkt_ib_saddr,
dma_pkt_ib_daddr,
pkt_dma_done
);
///////////////////////////////////////////////////////////////////////////////
//
// Local parameters
//
///////////////////////////////////////////////////////////////////////////////

localparam BM_DWIDTH = BM_DWIDTH_IN_BYTES*BYTE_SIZE;
localparam BM_AWIDTH_LSB = `dfafn_range2size(BM_DWIDTH_IN_BYTES);
localparam DWIDTH = 8;
localparam BYTECNT_WIDTH = `dfafn_range2size(MAX_PAYLOAD_IN_BYTES);
localparam DMA_BYTECNT_WIDTH = `dfafn_range2size(DMA_MAX_LENGTH);
localparam TYPE_WIDTH = 3;

// CMD pushed into fifo contains SID, XID, TYPE, and ADDR
// DEPTH is function of AKID_WIDTH
localparam CMD_WIDTH =	SDID_WIDTH + XID_WIDTH + TYPE_WIDTH +
			DMA_AWIDTH + BYTECNT_WIDTH;

// DEPTH is function of AKID_WIDTH
localparam IB_CMD_FIFO_DEPTH = `dfafn_pow2(AKID_WIDTH);

// There must be enough entries to hold 2**AKID_WIDTH packets worth of
// data.  Packet data is aligned to BM data width with zero padding. Because
// the start address can be misaligned, there can be one extra data
// item per packet.
localparam IB_DATA_FIFO_DEPTH =
    IB_CMD_FIFO_DEPTH * (MAX_PAYLOAD_IN_BYTES/BM_DWIDTH_IN_BYTES + 1);

localparam IB_OB_CMD_FIFO_DEPTH = 2;

// DEPTH is function of AKID_WIDTH
localparam OB_CMD_FIFO_DEPTH = `dfafn_pow2(AKID_WIDTH);

// There must be enough entries to hold 2**AKID_WIDTH packets worth of
// data.  Packet data is aligned to BM data width with zero padding. Because
// the start address can be misaligned, there can be one extra data
// item per packet.
localparam OB_DATA_FIFO_DEPTH = OB_CMD_FIFO_DEPTH*MAX_PAYLOAD_IN_BYTES;

localparam
    AK = 3'b000,
    WQ = 3'b001,
    WR = 3'b010,
    RQ = 3'b011,
    RR = 3'b100;


///////////////////////////////////////////////////////////////////////////////
//
// I/O declarations.  Note that I/Os that are prefixed with pkt are clocked
// or related to the clk_pkt domain.
//
///////////////////////////////////////////////////////////////////////////////
input clk_bus, clk_pkt, rst_n;
input pktib_sop;
input [DWIDTH-1:0] pktib_data;
output pktob_sop;
output [DWIDTH-1:0] pktob_data;
output ib_bm_req;
output ib_bm_last;
input bm_ib_gnt;
output ob_bm_req;
output ob_bm_last;
input bm_ob_gnt;
output [BM_AWIDTH-1:0] ib_bm_addr;
output [BM_AWIDTH-1:0] ob_bm_addr;
output [BM_DWIDTH-1:0] ib_bm_wdata;
input [BM_DWIDTH-1:0] bm_ob_rdata;
input dma_pkt_req;
input dma_pkt_dir;
input [DMA_BYTECNT_WIDTH-1:0] dma_pkt_bytecnt;
input [BM_AWIDTH-1:0] dma_pkt_ob_saddr;
input [DMA_AWIDTH-1:0] dma_pkt_ob_daddr;
input [DMA_AWIDTH-1:0] dma_pkt_ib_saddr;
input [BM_AWIDTH-1:0] dma_pkt_ib_daddr;
output pkt_dma_done;


///////////////////////////////////////////////////////////////////////////////
//
// Inbound path clk_pkt domain wires/regs
//
///////////////////////////////////////////////////////////////////////////////

wire [TYPE_WIDTH-1:0] pktib_type;
reg  [TYPE_WIDTH-1:0] pktib_type_ff;
wire [AKID_WIDTH-1:0] pktib_akid;
reg  [AKID_WIDTH-1:0] pktib_akid_ff;
wire [XID_WIDTH-1:0] pktib_xid;
reg  [XID_WIDTH-1:0] pktib_xid_ff;
reg  [SDID_WIDTH-1:0] pktib_sid, pktib_did;
reg  [SDID_WIDTH-1:0] pktib_sid_ff, pktib_did_ff;
reg  [BYTECNT_WIDTH-1:0] pktib_bytecnt;
reg  [BYTECNT_WIDTH-1:0] pktib_bytecnt_ff;
wire  [DMA_AWIDTH-1:0] pktib_addr;
reg  [DMA_AWIDTH-1:0] pktib_addr_ff;
wire [1:0] pktib_hpos;
reg  [1:0] pktib_hpos_ff;
wire [BYTECNT_WIDTH-1:0] pktib_dpos;
reg  [BYTECNT_WIDTH-1:0] pktib_dpos_ff;
wire pktib_hip;
reg  pktib_hip_ff;
wire pktib_dip;
reg  pktib_dip_ff;
wire pktib_cmd_push;
wire [CMD_WIDTH-1:0] pktib_cmd_pushdata;
wire pktib_cmd_full;
wire [CMD_WIDTH*IB_CMD_FIFO_DEPTH-1:0] pktib_cmd_memarray;
wire pktib_data_push;
reg [BM_DWIDTH-1:0] pktib_data_pushdata;
wire pktib_data_full;
wire [BM_DWIDTH*IB_DATA_FIFO_DEPTH-1:0] pktib_data_memarray;
reg [BM_DWIDTH-1:0] pktib_data_pushdata_ff;
wire [DMA_AWIDTH-1:0] pktib_data_addr;
reg [DMA_AWIDTH-1:0] pktib_data_addr_ff;
wire [BM_AWIDTH_LSB-1:0] pktib_data_bp;
wire [AKID_WIDTH-1:0] pktib_ak_cnt;
reg [AKID_WIDTH-1:0] pktib_ak_cnt_ff;
wire pktib_akreq_full;
wire [AKID_WIDTH*IB_OB_CMD_FIFO_DEPTH-1:0] pktib_akreq_memarray;

///////////////////////////////////////////////////////////////////////////////
//
// Inbound path clk_bus domain wires/regs
//
///////////////////////////////////////////////////////////////////////////////
wire ib_cmd_pop;
wire [CMD_WIDTH-1:0] ib_cmd_popdata;
wire ib_cmd_empty;
wire ib_data_pop;
wire [BM_DWIDTH-1:0] ib_data_popdata;
wire ib_data_empty;
wire [TYPE_WIDTH-1:0] ib_type;
reg [TYPE_WIDTH-1:0] ib_type_ff;
wire [XID_WIDTH-1:0] ib_xid;
reg [XID_WIDTH-1:0] ib_xid_ff;
wire  [SDID_WIDTH-1:0] ib_sid;
reg  [SDID_WIDTH-1:0] ib_sid_ff;
wire  [BYTECNT_WIDTH-1:0] ib_bytecnt;
reg  [BYTECNT_WIDTH-1:0] ib_bytecnt_ff;
wire  [DMA_AWIDTH-1:0] ib_addr;
reg  [DMA_AWIDTH-1:0] ib_addr_ff;
wire  [DMA_AWIDTH-1:0] ib_orig_addr;
reg  [DMA_AWIDTH-1:0] ib_orig_addr_ff;
wire  [DMA_AWIDTH-1:0] ib_bm_addr_pretrunc;
reg  [BM_DWIDTH-1:0] ib_bm_wdata_ff;
wire [DMA_AWIDTH-BM_AWIDTH_LSB-1:0] ib_aligned_addr_msb;
wire [BM_AWIDTH_LSB-1:0] ib_aligned_addr_lsb;
wire [DMA_AWIDTH-1:0] ib_aligned_addr;
wire ib_ip;
reg ib_ip_ff;
wire ib_cmd_done, ib_dp_done;
reg ib_cmd_done_ff, ib_dp_done_ff;
reg ib_data_pop_ff;
reg ib_bm_req_ff;
wire [CMD_WIDTH-1:0] ib_ob_cmd_pushdata;
wire ib_ob_cmd_push;
wire ib_ob_cmd_full;
wire [CMD_WIDTH*IB_OB_CMD_FIFO_DEPTH-1:0] ib_ob_cmd_memarray;

///////////////////////////////////////////////////////////////////////////////
//
// Outbound path clk_pkt domain wires/regs
//
///////////////////////////////////////////////////////////////////////////////

wire pktob_cmd_pop;
wire [CMD_WIDTH-1:0] pktob_cmd_popdata;
wire pktob_cmd_empty;

wire pktob_data_pop;
wire [BYTE_SIZE-1:0] pktob_data_popdata;
wire pktob_data_empty;

wire pktob_akreq_pop;
reg pktob_akreq_pop_ff;
wire pktob_akreq_bypass;
wire pktob_akreq_empty;
wire [AKID_WIDTH-1:0] pktob_akreq_popdata;

wire pktob_done;
wire [TYPE_WIDTH-1:0] pktob_type;

///////////////////////////////////////////////////////////////////////////////
//
// Outbound path clk_bus domain wires/regs
//
///////////////////////////////////////////////////////////////////////////////

wire ob_cmd_push;
wire [CMD_WIDTH-1:0] ob_cmd_pushdata;
wire ob_cmd_full;
wire [CMD_WIDTH*OB_CMD_FIFO_DEPTH-1:0] ob_cmd_memarray;

wire ob_data_push;
wire [BYTE_SIZE-1:0] ob_data_pushdata;
wire ob_data_full;
wire [BYTE_SIZE*OB_DATA_FIFO_DEPTH-1:0] ob_data_memarray;

wire ob_ib_cmd_pop;
wire ob_ib_cmd_empty;
wire [CMD_WIDTH-1:0] ob_ib_cmd_popdata;

wire [1:0] ob_gnt;
wire ob_ib_req;


///////////////////////////////////////////////////////////////////////////////
//
// Outbound path clk_bus domain wires/regs
//
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
//
// Inbound path clk_pkt domain logic
//
///////////////////////////////////////////////////////////////////////////////

assign {pktib_type, pktib_akid, pktib_xid} =
    pktib_sop ?
	{pktib_data[4+TYPE_WIDTH:5], pktib_data[2+AKID_WIDTH:3], pktib_data[XID_WIDTH-1:0]} :
	{pktib_type_ff, pktib_akid_ff, pktib_xid_ff};

assign pktib_hpos =
    pktib_sop ? 2'd0 :
    pktib_hip ? pktib_hpos_ff + 1'b1 :
    pktib_hpos_ff;

// pktib_hip is used to indicate whether the current cycle is a header cycle
// pktib_hip_ff is used to indicate whether the previous cycle was a header cycle
assign pktib_hip =
    pktib_sop ? 1'b1 :
    pktib_type == AK ? 1'b0 : 
    pktib_type == WQ && DMA_AWIDTH>4 && pktib_hpos_ff==2'd3 ? 1'b0 :
    pktib_type == WQ && DMA_AWIDTH<=4 && pktib_hpos_ff==2'd2 ? 1'b0 :
    pktib_type == WR && pktib_hpos_ff==2'd1 ? 1'b0 :
    pktib_type == RQ && DMA_AWIDTH>4 && pktib_hpos_ff==2'd3 ? 1'b0 :
    pktib_type == RQ && DMA_AWIDTH<=4 && pktib_hpos_ff==2'd2 ? 1'b0 :
    pktib_type == RR && pktib_hpos_ff==2'd2 ? 1'b0 :
    pktib_hip_ff;

always @* begin
    pktib_sid = pktib_sid_ff;
    pktib_did = pktib_did_ff;
    pktib_bytecnt = pktib_bytecnt_ff;

    if (pktib_hpos_ff == 2'd0) begin
	pktib_sid = pktib_data[SDID_WIDTH+3:4];
	pktib_did = pktib_data[SDID_WIDTH-1:0];
    end
    if (pktib_hpos_ff == 2'd1) begin
	pktib_bytecnt = pktib_data[BYTECNT_WIDTH+3 : 4];
    end
end

generate
if (DMA_AWIDTH>4) begin
    assign pktib_addr[DMA_AWIDTH-1:DMA_AWIDTH-4] =
	pktib_hpos_ff == 2'd1 ?
	    pktib_data[3:0] :
	    pktib_addr_ff[DMA_AWIDTH-1:DMA_AWIDTH-4];
    assign pktib_addr[DMA_AWIDTH-5:0] =
	pktib_hpos_ff == 2'd2 ?
	    pktib_data[DMA_AWIDTH-5:0] :
	    pktib_addr_ff[DMA_AWIDTH-5:0];
end
else begin
    assign pktib_addr[DMA_AWIDTH-1:0] =
	pktib_hpos_ff == 2'd1 ?
	    pktib_data[DMA_AWIDTH-1:0] :
	    pktib_addr_ff[DMA_AWIDTH-1:0];
end
endgenerate

assign pktib_dpos =
    !pktib_hip && pktib_hip_ff ? {BYTECNT_WIDTH{1'b0}} :
    pktib_dip ? pktib_dpos_ff + 1'b1 :
    pktib_dpos_ff;

// pktib_hip is used to indicate whether the current cycle is a data cycle
// pktib_hip_ff is used to indicate whether the previous cycle was a data cycle
assign pktib_dip =
    !pktib_hip && pktib_hip_ff && (pktib_type==WQ || pktib_type==RR) ? 1'b1 :
    pktib_dip_ff && pktib_dpos_ff == pktib_bytecnt ? 1'b0 :
    pktib_dip_ff;

assign pktib_cmd_push =
    pktib_hip && pktib_hip_ff &&
	(pktib_type==WQ || pktib_type==RR || pktib_type==RQ);

assign pktib_cmd_pushdata =
    {pktib_sid, pktib_xid, pktib_type, pktib_addr, pktib_bytecnt};

// ATTN: need to fix these three and add ak counter
//assign pktib_data_push = pktib_;

always @* begin
    pktib_data_pushdata = pktib_data_pushdata_ff;
    pktib_data_pushdata[pktib_data_bp +: BYTE_SIZE] = pktib_data;
end

assign pktib_data_addr =
    !pktib_dip_ff && pktib_dip ? pktib_addr :
    pktib_data_addr_ff + 1'b1;

assign pktib_data_bp = pktib_data_addr[BM_AWIDTH_LSB-1:0];

assign pktib_data_push = pktib_dip && (pktib_data_bp == {BM_AWIDTH_LSB{1'b1}});

assign pktob_ak_cnt =
    pktib_hip && pktib_type==AK && pktob_done && pktob_type!=AK ?
	pktib_ak_cnt_ff :
    pktib_hip && pktib_type==AK ?
	pktib_ak_cnt_ff - 1'b1 :
    pktob_done && pktob_type != AK ?
	pktib_ak_cnt_ff + 1'b1 :
    pktib_ak_cnt_ff;

fifo #(.NUM_ENTRIES(IB_OB_CMD_FIFO_DEPTH), .DWIDTH(AKID_WIDTH))
    pktib_ob_akreq_fifo (
	.clk(clk_pkt),
	.rst_n(rst_n),
	.push(pktib_sop),
	.pop(pktob_akreq_pop || pktob_akreq_bypass),
	.idata(pktib_akid),
	.full(pktib_akreq_full),
	.empty(pktob_akreq_empty),
	.odata(pktob_akreq_popdata),
	.memarray(pktib_akreq_memarray)
    );

always @(posedge clk_pkt) begin
    pktib_type_ff <= pktib_type;
    pktib_akid_ff <= pktib_akid;
    pktib_xid_ff <= pktib_xid;
    pktib_sid_ff <= pktib_sid;
    pktib_did_ff <= pktib_did;
    pktib_bytecnt_ff <= pktib_bytecnt;
    pktib_hpos_ff  <= pktib_hpos;
    pktib_dpos_ff <= pktib_dpos;
    pktib_addr_ff <= pktib_addr;
    pktib_data_pushdata_ff <= pktib_data_pushdata;
    pktib_data_addr_ff <= pktib_data_addr_ff;

    if (!rst_n) begin
	pktib_hip_ff <= 1'b0;
	pktib_dip_ff <= 1'b0;
	pktib_ak_cnt_ff <= {AKID_WIDTH{1'b0}};
    end
    else begin
	pktib_hip_ff <= pktib_hip;
	pktib_dip_ff <= pktib_dip;
	pktib_ak_cnt_ff <= pktib_ak_cnt;
    end
end

///////////////////////////////////////////////////////////////////////////////
//
// Inbound path clock crossing fifos
//
///////////////////////////////////////////////////////////////////////////////

fifo_dc #(.NUM_ENTRIES(IB_CMD_FIFO_DEPTH), .DWIDTH(CMD_WIDTH))
    pktib_cmd_fifo (
	.clk_push(clk_pkt),
	.clk_pop(clk_bus),
	.rst_n(rst_n),
	.push(pktib_cmd_push),
	.pop(ib_cmd_pop),
	.idata(pktib_cmd_pushdata),
	.full(pktib_cmd_full),
	.empty(ib_cmd_empty),
	.odata(ib_cmd_popdata),
	.memarray(pktib_cmd_memarray)
    );

fifo_dc #(.NUM_ENTRIES(IB_DATA_FIFO_DEPTH), .DWIDTH(BM_DWIDTH))
    pktib_data_fifo (
	.clk_push(clk_pkt),
	.clk_pop(clk_bus),
	.rst_n(rst_n),
	.push(pktib_data_push),
	.pop(ib_data_pop),
	.idata(pktib_data_pushdata),
	.full(pktib_data_full),
	.empty(ib_data_empty),
	.odata(ib_data_popdata),
	.memarray(pktib_data_memarray)
    );

///////////////////////////////////////////////////////////////////////////////
//
// Inbound path clk_bus domain logic
//
///////////////////////////////////////////////////////////////////////////////
assign ib_cmd_pop =
    !ib_cmd_empty && (!ib_ip_ff || ib_cmd_done_ff);

assign ib_ip =
    ib_cmd_pop ? 1'b1 :
    ib_cmd_done_ff ? 1'b0 :
    ib_ip_ff;

//ATTN: needs to be adjusted
assign ib_cmd_done = ib_ip &&
    (ib_type==AK || ib_type==WR || ib_type==RQ)  ||
    (ib_type==WQ || ib_type==RR) &&
	ib_dp_done && (ib_bytecnt < BM_DWIDTH_IN_BYTES[BYTECNT_WIDTH-1:0]);

//ATTN: need to consider whether queue is empty.  Then command is not
// done for RQ until it has been pushed
assign ib_ob_cmd_push = ib_cmd_done && ib_type==RQ;
assign ib_ob_cmd_pushdata = ib_cmd_popdata;

assign ib_dp_done = ib_bm_req && bm_ib_gnt;

assign ib_data_pop =
    ib_cmd_pop && (ib_type==WQ || ib_type==RR) ? 1'b1 :
    ib_dp_done_ff &&
	(ib_bytecnt_ff >= BM_DWIDTH_IN_BYTES[BYTECNT_WIDTH-1:0]) ? 1'b1 :
    1'b0;

assign ib_bm_req =
    ib_data_pop_ff ? 1'b1 :
    ib_dp_done_ff ? 1'b0 :
    ib_bm_req_ff;

assign {ib_sid, ib_xid, ib_type} =
    ib_cmd_pop ? ib_cmd_popdata[CMD_WIDTH-1:DMA_AWIDTH+BYTECNT_WIDTH] :
    {ib_sid_ff, ib_xid_ff, ib_type_ff};

assign ib_aligned_addr_msb = ib_addr[DMA_AWIDTH-1:BM_AWIDTH_LSB] + 1'b1;

assign ib_aligned_addr_lsb = ib_addr[BM_AWIDTH_LSB-1:0];

assign ib_aligned_addr = {ib_aligned_addr_msb, {BM_AWIDTH_LSB{1'b0}} };

assign ib_addr =
    ib_cmd_pop ? ib_cmd_popdata[BYTECNT_WIDTH+DMA_AWIDTH-1:BYTECNT_WIDTH] :
    ib_dp_done ? ib_aligned_addr :
    ib_addr_ff;

assign ib_orig_addr =
    ib_cmd_pop ? ib_addr :
    ib_orig_addr_ff;

assign ib_bytecnt =
    ib_cmd_pop ? ib_cmd_popdata[BYTECNT_WIDTH-1:0] :
    ib_dp_done ? ib_bytecnt_ff - ({1'b1, {BM_AWIDTH_LSB{1'b0}} } - ib_aligned_addr_lsb) :
    ib_bytecnt_ff;

assign ib_bm_addr_pretrunc = ib_addr - ib_orig_addr;
assign ib_bm_addr = ib_bm_addr_pretrunc[BM_AWIDTH-1:0] + dma_pkt_ib_daddr ;

assign ib_bm_wdata = ib_data_popdata;

assign ib_bm_last = 1'b1;

fifo #(.NUM_ENTRIES(IB_OB_CMD_FIFO_DEPTH), .DWIDTH(CMD_WIDTH))
    ib_ob_cmd_fifo (
	.clk(clk_bus),
	.rst_n(rst_n),
	.push(ib_ob_cmd_push),
	.pop(ob_ib_cmd_pop),
	.idata(ib_ob_cmd_pushdata),
	.full(ib_ob_cmd_full),
	.empty(ob_ib_cmd_empty),
	.odata(ob_ib_cmd_popdata),
	.memarray(ib_ob_cmd_memarray)
    );

always @(posedge clk_bus) begin
    ib_type_ff <= ib_type;
    ib_xid_ff <= ib_xid;
    ib_sid_ff <= ib_sid;
    ib_cmd_done_ff <= ib_cmd_done;
    ib_bytecnt_ff <= ib_bytecnt;
    ib_addr_ff <= ib_addr;
    ib_orig_addr_ff <= ib_orig_addr;
    ib_bm_wdata_ff <= ib_bm_wdata;

    if (!rst_n) begin
	ib_ip_ff <= 1'b0;
	ib_bm_req_ff <= 1'b0;
	ib_dp_done_ff <= 1'b0;
	ib_data_pop_ff <= 1'b0;
    end
    else begin
	ib_ip_ff <= ib_ip;
	ib_bm_req_ff <= ib_bm_req;
	ib_dp_done_ff <= ib_dp_done;
	ib_data_pop_ff <= ib_data_pop;
    end
end

///////////////////////////////////////////////////////////////////////////////
//
// Outbound path clk_bus domain logic
//
///////////////////////////////////////////////////////////////////////////////

// This arbiter chooses from between dma initiated bm reads and inbound
// path initiated packets. There is round-robin priority between these
// two sources.  This arbiter is in the clk_bus domain.
dfafn_arb #(.N(2), .ARB_TYPE("ROUND_ROBIN"), .PRIO_DIR("SEARCH_LEFT"))
pkt_da_rr_arb(
    .clk(clk_bus), .rst_n(rst_n),
    .gnt(ob_gnt),
    .req({dma_ob_req, ob_ibpath_req}),
    .last(),
    .init_prio(2'b01)
);

assign {ob_dma_bm_read_gnt, ob_rr_gnt} = ob_gnt;

assign ob_bm_last = 1'b1;

///////////////////////////////////////////////////////////////////////////////
//
// Outbound path clock crossing fifos
//
///////////////////////////////////////////////////////////////////////////////

fifo_dc #(.NUM_ENTRIES(OB_CMD_FIFO_DEPTH), .DWIDTH(CMD_WIDTH))
    ob_cmd_fifo (
	.clk_push(clk_bus),
	.clk_pop(clk_pkt),
	.rst_n(rst_n),
	.push(ob_cmd_push),
	.pop(pktob_cmd_pop),
	.idata(ob_cmd_pushdata),
	.full(ob_cmd_full),
	.empty(pktob_cmd_empty),
	.odata(pktob_cmd_popdata),
	.memarray(ob_cmd_memarray)
    );

fifo_dc #(.NUM_ENTRIES(OB_DATA_FIFO_DEPTH), .DWIDTH(BYTE_SIZE))
    ob_data_fifo (
	.clk_push(clk_bus),
	.clk_pop(clk_pkt),
	.rst_n(rst_n),
	.push(ob_data_push),
	.pop(pktob_data_pop),
	.idata(ob_data_pushdata),
	.full(ob_data_full),
	.empty(pktob_data_empty),
	.odata(pktob_data_popdata),
	.memarray(ob_data_memarray)
    );

///////////////////////////////////////////////////////////////////////////////
//
// Outbound path clk_pkt domain logic
//
///////////////////////////////////////////////////////////////////////////////
//ak from counter>0
// This arbiter chooses from between data packets and ak packets.  Data packet
// activity is masked if the ak request counter is at maximum.


endmodule

