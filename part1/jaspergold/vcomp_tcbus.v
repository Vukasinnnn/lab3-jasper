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

// tc_aack should not be asserted if the pipeline is full
assert_aack_only_if : assert property (@(posedge clk_bus)  <fill in this> );
//####  This is expected to fail   #######


// tc_rack should only be asserted if there are pending read transactions
assert_rack_only_if : assert property (@(posedge clk_bus)  <fill in this> );

// tc_wack should only be asserted if there are pending write transactions
// or a write transaction happening on this cycle
assert_wack_only_if : assert property (@(posedge clk_bus)
                  <fill in this> );


//############### Stability ######################################################

// address should be held stable until the transaction is acknowledged.
assume_addr_hold : assume property ( @(posedge clk_bus) 
                           <fill in this> );

// rnw should be held stable until the transaction is acknowledged.
assume_rnw_hold : assume property (@(posedge clk_bus)
                           <fill in this> );

// For write transactions wdata should be held stable until the transaction is acknowledged.
assume_wdata_hold : assume property (@(posedge clk_bus)
                           <fill in this> );

// request line should be held stable until it is acknowledged
assume_req_hold : assume property (<fill in this>);

//############### Response  ######################################################

// If the bus is requested, eventually it must be acknowledged
assert_req_eventually_aack : assert property ( <fill in this>);

// If a read transaction is in flight then eventually tc_rack should be asserted
assert_rd_cnt_eventually_rack : assert property (@(posedge clk_bus)
                           <fill in this>);

// If a write transaction is in flight then eventually tc_wack should be asserted
assert_wr_cnt_eventually_wack : assert property (@(posedge clk_bus)
                           <fill in this>);




//#############################################################################
//############## Cover Statements  ############################################
//#############################################################################



//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~   END OF EDIT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


endmodule
