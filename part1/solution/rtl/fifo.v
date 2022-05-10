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

module fifo
#(
    parameter NUM_ENTRIES = 16,	// number of entries in FIFO
    parameter DWIDTH=8
)
(
    input clk,
    input rst_n,
    input push,
    input pop,
    input [DWIDTH-1:0] idata,
    output full,
    output empty,
    output [DWIDTH-1:0] odata,
    output [NUM_ENTRIES*DWIDTH-1:0] memarray
);

localparam FD = `dfafn_range2size(NUM_ENTRIES);

wire [FD-1:0] raddr, waddr;
wire bypass, we;

fifo_cntl #(.NUM_ENTRIES(NUM_ENTRIES))
cntl (
    .clk(clk),
    .rst_n(rst_n),
    .push(push),
    .pop(pop),
    .full_ff(full),
    .empty_ff(empty),
    .bypass(bypass),
    .we(we),
    .waddr_ff(waddr),
    .raddr_ff(raddr)
);

wire [DWIDTH-1:0] pre_data;

dfafn_mem #( .NREAD(1), .NWRITE(1), .DEPTH(NUM_ENTRIES), .DWIDTH(DWIDTH) )
fifo_mem (
    .write_clk(clk),
    .write_enable(we),
    .wdata(idata),
    .waddr(waddr),
    .read_clk(clk),
    .raddr(raddr),
    .rdata(pre_data),
    .mem_out(memarray)
);

assign odata = bypass ? idata : pre_data;

endmodule

