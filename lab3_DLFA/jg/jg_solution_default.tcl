clear -all
analyze -sv09 +define+ABV_ON=1+ACID_TEST=1 ../solution/rtl/frame.v 
analyze -sv09 +define+ABV_ON=1+ACID_TEST=1 ../rtl/frame_vcomp_default.v
elaborate -top frame -create_related_covers witness
clock clk
reset !rst_n
prove -all
