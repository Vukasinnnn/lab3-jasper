module vcomp_tcbus #(parameter TC_AWIDTH=8,
           parameter TC_DWIDTH=8)
(
   input clk_bus,
   input rst_n,
   input tc_req,
   input tc_rnw,
   input [TC_AWIDTH-1:0] tc_addr,
   input [TC_DWIDTH-1:0] tc_wdata,
   input tc_aack,
   input tc_rack,
   input tc_wack
);


// Auxiliary Code

reg [2:0] pending_rd_cnt, pending_wr_cnt;
reg [2:0] pending_rd_cnt_ff, pending_wr_cnt_ff;

always @* begin
   // Update the read counter
   pending_rd_cnt = pending_rd_cnt_ff;
   if (tc_aack && tc_req && tc_rnw) begin
      if (!tc_rack)
         pending_rd_cnt = pending_rd_cnt_ff + 1'b1;
   end
   else if (tc_rack)
      pending_rd_cnt = pending_rd_cnt_ff - 1'b1;

   // Update the write counter
   pending_wr_cnt = pending_wr_cnt_ff;
   if (tc_aack && tc_req && !tc_rnw) begin
      if (!tc_wack)
         pending_wr_cnt = pending_wr_cnt_ff + 1'b1;
   end
   else if (tc_wack)
      pending_wr_cnt = pending_wr_cnt_ff - 1'b1;
end

always @(posedge clk_bus or negedge rst_n)
   if (!rst_n) begin
      pending_rd_cnt_ff <= 3'b000;
      pending_wr_cnt_ff <= 3'b000;
   end
   else begin
      pending_rd_cnt_ff <= pending_rd_cnt;
      pending_wr_cnt_ff <= pending_wr_cnt;
   end

wire [2:0] pending_cnt;
assign pending_cnt = pending_rd_cnt_ff + pending_wr_cnt_ff;


//Specify default clock for all properties
default clocking DEFCLK @(posedge clk_bus);
endclocking

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~   EDIT HERE ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

//#############################################################################
//########### Black Box Protocol Properties   #################################
//#############################################################################

//############### Stimulus ######################################################
// tc_aack should only be asserted if the pipeline is not full
//####  This is expected to fail   #######
assert_aack_only_if : assert property (@(posedge clk_bus)  tc_aack |-> pending_cnt <= 3'd4 );


// tc_rack should only be asserted if there are pending read transactions
assert_rack_only_if : assert property (@(posedge clk_bus)  tc_rack |-> pending_rd_cnt_ff != 3'd0 );

// tc_wack should only be asserted if there are pending write transactions
// or a write transaction happening on this cycle
assert_wack_only_if : assert property (@(posedge clk_bus)
                  tc_wack |-> (pending_wr_cnt_ff != 3'd0) || (tc_req && !tc_rnw && tc_aack) );


//############### Stability ######################################################

// address should be held stable until the transaction is acknowledged.
assume_addr_hold : assume property ( @(posedge clk_bus) 
                           (tc_req && !tc_aack) |=> (tc_addr == $past(tc_addr)) );

// rnw should be held stable until the transaction is acknowledged.
assume_rnw_hold : assume property (@(posedge clk_bus)
                           (tc_req && !tc_aack) |=> (tc_rnw == $past(tc_rnw)) );

// wdata should be held stable until the transaction is acknowledged.
//mavery - only if the transaction is a write
assume_wdata_hold : assume property (@(posedge clk_bus)
                           (tc_req && !tc_aack && !tc_rnw) |=> (tc_wdata == $past(tc_wdata)) );

// request line should be held stable until it is acknowledged
assume_req_hold : assume property ((tc_req && !tc_aack) |=> tc_req);

//############### Response  ######################################################

// If the bus is requested, eventually it must be acknowledged
assert_req_eventually_aack : assert property ( tc_req   |-> s_eventually tc_aack);


// If a read transaction is in flight then eventually tc_rack should be asserted
assert_rd_cnt_eventually_rack : assert property (@(posedge clk_bus)
                           pending_rd_cnt_ff > 0   |-> s_eventually tc_rack);

// If a write transaction is in flight then eventually tc_wack should be asserted
assert_wr_cnt_eventually_wack : assert property (@(posedge clk_bus)
                           pending_wr_cnt_ff > 0   |-> s_eventually tc_wack);


//#############################################################################
//############## Cover Statements  ############################################
//#############################################################################

// tc_req and tc_aack can be asserted at the same time
cover_tc_req_and_tc_aack: cover property ( @(posedge clk_bus) tc_req && tc_aack);

// tc_aack can be speculatively asserted
cover_tc_aack_speculative: cover property ( @(posedge clk_bus) tc_aack && !tc_req);

// The transaction buffer pipe can become full
cover_transaction_buffer_full: cover property ( @(posedge clk_bus) pending_cnt == 3'd4);

// The transaction buffer has unfulfilled write requests
cover_write_pending: cover property ( @(posedge clk_bus) pending_wr_cnt_ff > 3'd0);

// The transaction buffer has unfulfilled read requests
cover_read_pending: cover property ( @(posedge clk_bus) pending_rd_cnt_ff > 3'd0);


// tc_rack and tc_wack can be asserted at the same time
cover_tc_rack_and_tc_wack : cover property ( @(posedge clk_bus) tc_rack && tc_wack );

// tc_rack can be high for more than one cycle
cover_tc_rack_multiple_high : cover property ( @(posedge clk_bus) tc_rack ##1 tc_rack );

// tc_addr can change value
cover_tc_addr_change : cover property ( @(posedge clk_bus) 1'b1 ##1 tc_addr != $past(tc_addr) );

// tc_wdata can change value
cover_tc_wdata_change : cover property ( @(posedge clk_bus) 1'b1 ##1 tc_wdata != $past(tc_wdata) );

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~   END OF EDIT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


endmodule
