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

module fifo_dc_cntl
#(
    parameter NUM_ENTRIES = 16	// number of entries in FIFO
)
(
    input clk_push,		// single clock domain for push side
    input clk_pop,		// single clock domain for pop side
    input rst_n,		// reset (async AL)
    input push,			// push an entry (AH)
    input pop,			// pop an entry (AH)
    output reg full_ff,		// asserted when fifo is full (AH)
    output reg empty_ff,		// asserted when fifo is empty (AH)
    output we,			// write enable for RAM (AH)
    output [`dfafn_range2size(NUM_ENTRIES)-1:0] waddr_ff,	// write address for RAM
    output [`dfafn_range2size(NUM_ENTRIES)-1:0] raddr_ff	// read address for RAM
);

localparam FD = `dfafn_range2size(NUM_ENTRIES);

reg [FD:0] wa_bin_ff, wa_gray_ff, wa_gray_sync;
reg [FD:0] ra_bin_ff, ra_gray_ff, ra_gray_sync;

wire [FD:0] wa_bin, wa_gray;
wire [FD:0] ra_bin, ra_gray;
wire full, empty;

reg rd_rst_n, wr_rst_n;
reg rd_rst_release, wr_rst_release;

/******************************************************************************
 * Reset logic generation - synchronize the release of reset to avoid
 * races.  Provide a reset per clock domain.
 *****************************************************************************/
always @(posedge clk_pop or negedge rst_n)
    if(!rst_n) rd_rst_release <= 1'b0;
    else rd_rst_release <= 1'b1;

always @(posedge clk_push or negedge rst_n)
    if(!rst_n) wr_rst_release <= 1'b0;
    else wr_rst_release <= 1'b1;

always @(posedge clk_pop or negedge rst_n)
    if(!rst_n) rd_rst_n <= 1'b0;
    else if(rd_rst_release) rd_rst_n <= 1'b1;

always @(posedge clk_push or negedge rst_n)
    if(!rst_n) wr_rst_n <= 1'b0;
    else if(wr_rst_release) wr_rst_n <= 1'b1;


/******************************************************************************
 * Push domain flops
 *****************************************************************************/
always @(posedge clk_push)
    if(!wr_rst_n) begin
	wa_bin_ff <= {FD+1{1'b0}};
	wa_gray_ff <= {FD+1{1'b0}};
	full_ff <= 1'b1;
    end
    else if(we) begin
	wa_bin_ff <= wa_bin;
	wa_gray_ff <= wa_gray;
	full_ff <= full;
    end

// read address synchronization
always @(posedge clk_push) ra_gray_sync <= ra_gray_ff;

/******************************************************************************
 * Pop domain flops
 *****************************************************************************/
always @(posedge clk_pop)
    if(!rd_rst_n) begin
	ra_bin_ff <= {FD+1{1'b0}};
	ra_gray_ff <= {FD+1{1'b0}};
	empty_ff <= 1'b1;
    end
    else if(pop) begin
	ra_bin_ff <= ra_bin;
	ra_gray_ff <= ra_gray;
	empty_ff <= empty;
    end

// write address synchronization
always @(posedge clk_pop) wa_gray_sync <= wa_gray_ff;

/******************************************************************************
 * Push domain logic
 *****************************************************************************/
assign wa_bin  = wa_bin_ff + {{FD{1'b0}},1'b1};
dfafn_bin2gray #(FD+1)
    do_wa_bin2gray(.bin_value(wa_bin), .gray_result(wa_gray));

assign full =
    (ra_gray_sync[FD-1:0] == wa_gray_ff[FD-1:0] && ra_gray_sync[FD] != wa_gray_ff[FD]) |
    (push && ra_gray_sync[FD-1:0] == wa_gray[FD-1:0] && ra_gray_sync[FD] == wa_gray[FD]);

assign we = push&!full_ff;

assign waddr_ff = wa_bin_ff[FD-1:0];

/******************************************************************************
 * Pop domain logic
 *****************************************************************************/
assign ra_bin  = ra_bin_ff + {{FD{1'b0}},1'b1};
dfafn_bin2gray #(FD+1)
    do_ra_bin2gray(.bin_value(ra_bin), .gray_result(ra_gray));

assign empty =
    (wa_gray_sync == ra_gray_ff) | (pop & (wa_gray_sync == ra_gray));

assign raddr_ff = ra_bin_ff[FD-1:0];

endmodule

