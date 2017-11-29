# Uncomment below when data needs to be handshaked into the s_axi_lite_aclk domain
# Make sure the path from the iData_int register to oData register is smaller than 2 OutClk (s00_axi_aclk) periods
#set OutClk [get_clocks -of [get_ports s_axi_lite_aclk]]

#set_max_delay -datapath_only -from [get_pins -filter {NAME =~ */HandshakeData*/iData_int_reg[*]/C} -hier] -to [get_pins -filter {NAME =~ */HandshakeData*/oData_reg[*]/D} -hier] [expr [get_property -min PERIOD $OutClk] * 2]