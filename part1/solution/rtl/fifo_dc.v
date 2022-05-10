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

module fifo_dc
#(
    parameter NUM_ENTRIES = 16,	// number of entries in FIFO
    parameter DWIDTH=8
)
(
    input clk_push,
    input clk_pop,
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

wire [FD-1:0] raddr;
wire [FD-1:0] waddr;

wire we;

fifo_dc_cntl #(.NUM_ENTRIES(NUM_ENTRIES))
cntl (
    .clk_push(clk_push),
    .clk_pop(clk_pop),
    .rst_n(rst_n),
    .push(push),
    .pop(pop),
    .full_ff(full),
    .empty_ff(empty),
    .we(we),
    .waddr_ff(waddr),
    .raddr_ff(raddr)
);

dfafn_mem #( .NREAD(1), .NWRITE(1), .DEPTH(NUM_ENTRIES), .DWIDTH(DWIDTH) )
fifo_mem (
    .write_clk(clk_push),
    .write_enable(we),
    .wdata(idata),
    .waddr(waddr),
    .read_clk(clk_pop),
    .raddr(raddr),
    .rdata(odata),
    .mem_out(memarray)
);

endmodule
