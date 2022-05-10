################
# Clear
################
clear -all

#source example_proofgrid_setup.tcl

################
# Analyze
################
analyze -v2k -f jg_tcbus.f
analyze -sv09 vcomp_tcbus.v

################
# Elaborate
################
elaborate -top te

################
# Clocks
################
clock clk_bus
clock clk_pkt

################
# Reset
################
reset !rst_n

################
# Constrain pins
################
assume -name ASM_bm_rdata_0 {bm_rdata == 8'd0}
assume -name ASM_da_rdata_0 {da_rdata == 4'd0}
assume -name ASM_da_rrdy_0 {da_rrdy == 0}
assume -name ASM_da_wrdy_0 {da_wrdy == 0}
assume -name ASM_pktib_data_0 {pktib_data == 16'b0}
assume -name ASM_pktib_sop_0 {pktib_sop == 2'b0}

################
# Settings
################

# Uncommenting the lines below will disable asssertions and precondition covers
# and hence leave only the covers
#assert -disable *
#cover -disable *precond*

set_prove_per_property_time_limit 1m

prove -all
