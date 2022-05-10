clear -all
analyze -sv09 +define+ABV_ON=1 ../rtl/frame.v 
elaborate -top frame -create_related_covers witness
clock clk
reset !rst_n
prove -all
