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

module fifo_cntl
#(
    parameter NUM_ENTRIES = 16	// number of entries in FIFO
)
(
    input clk,			// single clock domain for both read and write
    input rst_n,		// reset (async AL)
    input push,			// push an entry (AH)
    input pop,			// pop an entry (AH)
    output reg full_ff,		// asserted when fifo is full (AH)
    output reg empty_ff,		// asserted when fifo is empty (AH)
    output reg bypass,		// bypass data in to data out for RAM, when FIFO is empty and
				// push is active (AH)
    output reg we,			// write enable for RAM (AH)
    output reg [`dfafn_range2size(NUM_ENTRIES)-1:0] waddr_ff,	// write address for RAM
    output reg [`dfafn_range2size(NUM_ENTRIES)-1:0] raddr_ff	// read address for RAM
);

/******************************************************************************
 * Signals and logic used in both properties and RTL
 *****************************************************************************/
localparam FD = `dfafn_range2size(NUM_ENTRIES);

reg			full;
reg			empty;
reg	[FD-1:00]	waddr;
reg	[FD-1:00]	raddr;

wire	[FD-1:00]	max_index;

assign max_index = {FD{1'b1}};

/******************************************************************************
 * Logic starts here
 *****************************************************************************/
always @*
begin

    if(push & ((!full_ff & !empty_ff) | (empty_ff & !pop)) ) begin
	waddr = waddr_ff==max_index ? {FD{1'b0}} : waddr_ff+{{FD-1{1'b0}},1'b1};
    end
    else begin
	waddr = waddr_ff;
    end

    if(pop&!empty_ff) begin
	raddr = raddr_ff==max_index ? {FD{1'b0}} : raddr_ff+{{FD-1{1'b0}},1'b1};
    end
    else begin
	raddr = raddr_ff;
    end

    bypass = push&pop&empty_ff;
    we = push&!full_ff&!bypass;
    full = waddr==raddr & push & !empty_ff | (full_ff & !pop);
    empty = waddr==raddr & pop | (empty_ff & !push);
end

/******************************************************************************
 * State elements
 *****************************************************************************/
always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
        raddr_ff <= {FD{1'b0}};
        waddr_ff <= {FD{1'b0}};
        empty_ff <= 1'b1;
        full_ff <= 1'b0;
    end
    else begin
        raddr_ff <= raddr;
        waddr_ff <= waddr;
        empty_ff <= empty;
        full_ff <= full;
    end

endmodule

