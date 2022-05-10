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

module te_dabus
#(
parameter DMA_AWIDTH=10,
parameter DMA_MAX_LENGTH=32,
parameter BM_AWIDTH=10,
parameter BM_DWIDTH=64,
parameter DA_DWIDTH_IN_BYTES=4,
parameter DA_MAX_BURSTLENGTH_IN_BYTES=16,
parameter BYTE_SIZE=8
)
(
clk, rst_n,
da_req,
da_rnw,
da_bytecnt,
da_addr,
da_wdata,
da_wrdy,
da_rdata,
da_rrdy,
da_bm_req,
da_bm_last,
bm_da_gnt,
da_bm_rnw,
da_bm_addr,
da_bm_wdata,
bm_da_rdata,
dma_da_req,
dma_da_dir,
dma_da_bytecnt,
dma_da_ob_saddr,
dma_da_ob_daddr,
dma_da_ib_saddr,
dma_da_ib_daddr,
da_dma_done
);

localparam DA_DWIDTH = DA_DWIDTH_IN_BYTES*BYTE_SIZE;
localparam DA_BYTECNT_WIDTH = `dfafn_range2size(DA_MAX_BURSTLENGTH_IN_BYTES+1);
localparam DMA_BYTECNT_WIDTH = `dfafn_range2size(DMA_MAX_LENGTH);
localparam DA_AWIDTH = DMA_AWIDTH;
localparam DA_AWIDTH_LSB = `dfafn_range2size(DA_DWIDTH_IN_BYTES);

input clk, rst_n;
output reg da_req;
output reg da_rnw;
output reg [DA_BYTECNT_WIDTH-1:0] da_bytecnt;
output reg [DMA_AWIDTH-1:0] da_addr;
output reg [DA_DWIDTH-1:0] da_wdata;
input da_wrdy;
input [DA_DWIDTH-1:0] da_rdata;
input da_rrdy;
output da_bm_req;
output da_bm_last;
input bm_da_gnt;
output da_bm_rnw;
output [BM_AWIDTH-1:0] da_bm_addr;
output [BM_DWIDTH-1:0] da_bm_wdata;
input [BM_DWIDTH-1:0] bm_da_rdata;
input [BM_DWIDTH-1:0] dma_da_req;
input dma_da_dir;
input [DMA_BYTECNT_WIDTH-1:0] dma_da_bytecnt;
input [BM_AWIDTH-1:0] dma_da_ob_saddr;
input [DMA_AWIDTH-1:0] dma_da_ob_daddr;
input [DMA_AWIDTH-1:0] dma_da_ib_saddr;
input [BM_AWIDTH-1:0] dma_da_ib_daddr;
output da_dma_done;

assign {da_bm_req, da_bm_last} = 2'b01;

wire req_internal, rnw_internal;
wire [DMA_AWIDTH-1:0] addr_internal;
wire [DA_DWIDTH-1:0] wdata_internal;
wire [DA_BYTECNT_WIDTH-1:0] bytecnt_internal;

wire dp_done = da_req && ((da_rrdy && da_rnw) || (da_wrdy && !da_rnw));
wire xact_done = da_req && (da_bytecnt <= DA_DWIDTH_IN_BYTES) && dp_done;

wire pre_da_req = (xact_done || !da_req) ? req_internal : da_req;
wire pre_da_rnw = (xact_done || !da_req) ? rnw_internal : da_rnw;

wire [DA_AWIDTH-DA_AWIDTH_LSB-1:0] next_aligned_addr_msb =
	da_addr[DA_AWIDTH-1:DA_AWIDTH_LSB] + 1'b1;

wire [DA_AWIDTH_LSB-1:0] next_aligned_addr_lsb = da_addr[DA_AWIDTH_LSB-1:0];

wire [DA_AWIDTH-1:0] next_aligned_addr =
	{next_aligned_addr_msb, {DA_AWIDTH_LSB{1'b0}} };

wire [DA_AWIDTH-1:0] pre_da_addr =
	dp_done ?
	    (xact_done ? addr_internal : next_aligned_addr) :
	    da_addr;

wire [DA_DWIDTH-1:0] pre_da_wdata = (dp_done || !da_req) ? wdata_internal : da_wdata; 

wire [DA_BYTECNT_WIDTH-1:0]  next_bytecnt =
	da_bytecnt - ({1'b1, {DA_AWIDTH_LSB{1'b0}}} - next_aligned_addr_lsb); 

wire [DA_BYTECNT_WIDTH-1:0] pre_da_bytecnt =
	dp_done ?
	    (xact_done ? bytecnt_internal[DA_BYTECNT_WIDTH-1:0] : next_bytecnt) :
	    da_bytecnt;

// drive req stable until transaction is done
always @(posedge clk)
    if(!rst_n) begin
	da_req <= 1'b0;
	da_rnw <= 1'b0;
	da_addr <= {DMA_AWIDTH{1'b0}} ;
	da_wdata <= {DA_DWIDTH{1'b0}} ;
	da_bytecnt <= {DA_BYTECNT_WIDTH{1'b0}} ;
    end
    else begin
	da_req <= pre_da_req;
	da_rnw <= pre_da_rnw;
	da_addr <= pre_da_addr;
	da_wdata <= pre_da_wdata;
	da_bytecnt <= pre_da_bytecnt;
    end

endmodule

