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

module te_csr
#(
parameter DMA_NUM_CHANNELS=2,
parameter DMA_AWIDTH=10,
parameter DMA_MAX_LENGTH=16,
parameter TC_DWIDTH=32,
parameter PKT_NUM_IFC=2
)
(
clk, rst_n,
tc_csr_req,
tc_csr_rnw,
csr_tc_ack,
tc_csr_addr,
tc_csr_wdata,
tc_csr_rdata
);

localparam CSR_SPACE_IN_WORDS = 4*DMA_NUM_CHANNELS+3;
localparam CSR_AWIDTH = `dfafn_range2size(CSR_SPACE_IN_WORDS);
localparam LWIDTH = `dfafn_range2size(DMA_MAX_LENGTH);
localparam CSR_DWIDTH = `dfafn_max3(DMA_AWIDTH, LWIDTH, DMA_NUM_CHANNELS);

input clk, rst_n;
input tc_csr_req;
input tc_csr_rnw;
output csr_tc_ack;
input [CSR_AWIDTH-1:0] tc_csr_addr;
input [TC_DWIDTH-1:0] tc_csr_wdata;
output [TC_DWIDTH-1:0] tc_csr_rdata;

///////////////////////////////////////////////////////////////////////////////
//
//
//
//
///////////////////////////////////////////////////////////////////////////////

assign csr_tc_ack = 1'b1;
assign tc_csr_rdata = {TC_DWIDTH{1'b0}};

endmodule

