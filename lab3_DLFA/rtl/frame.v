wire mask_sop; 
// calculate when eop should not be passed through
wire mask_eop;
reg sop_in_was_seen_before_remember_state;
//wire sop_in_was_seen_before;
reg pom =valid_in;




 /*always @(posedge clk or negedge rst_n) begin
if(valid_in && sop_in && !eop_in)
begin
pom <= 1'b1;
end
else begin
if(valid_in && eop_in)
begin
pom <=1'b0;
end
else begin
sop_in_was_seen_before_remember_state <= 1;

end
end
if(!rst_n) begin
sop_in_was_seen_before_remember_state <= 0;
	
  end else
  begin
	sop_in_was_seen_before_remember_state <= pom;
  end
end
*/

always @(posedge clk or negedge rst_n) begin
if(!rst_n)
 begin
sop_in_was_seen_before_remember_state <= 0; 
 end
 else begin 
if(valid_in && sop_in && !eop_in)
begin
pom <= 1'b1;
end
else begin
if(valid_in && eop_in)
begin
pom <=1'b0;
end
else 

end
end
sop_in_was_seen_before_remember_state <= pom;
end
//assign sop_in_was_seen_before = pom;

/// vidi nesto sa always blok

assign mask_sop = valid_in && sop_in && sop_in_was_seen_before_remember_state;
assign mask_eop = valid_in && eop_in && (!sop_in && !sop_in_was_seen_before_remember_state);

/********************  Combinational Logic     ********************/
//Replicate valid signal to valid_out port
assign valid_out = valid_in;

//Put your combinational logic here
assign sop_out  = valid_in && sop_in && !mask_sop;
assign eop_out  = valid_in && eop_in && !mask_eop;
