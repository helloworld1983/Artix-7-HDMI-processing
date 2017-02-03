 ## pcie_x1:0.rst_n
set_property LOC AB7 [get_ports pcie_x1_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports pcie_x1_rst_n]
 ## pcie_x1:0.clk_p
set_property LOC F6 [get_ports pcie_x1_clk_p]
 ## pcie_x1:0.clk_n
set_property LOC E6 [get_ports pcie_x1_clk_n]
 ## pcie_x1:0.rx_p
set_property LOC B8 [get_ports pcie_x1_rx_p]
 ## pcie_x1:0.rx_n
set_property LOC A8 [get_ports pcie_x1_rx_n]
 ## pcie_x1:0.tx_p
set_property LOC B4 [get_ports pcie_x1_tx_p]
 ## pcie_x1:0.tx_n
set_property LOC A4 [get_ports pcie_x1_tx_n]
 ## serial:0.tx
set_property LOC T1 [get_ports serial_tx]
set_property IOSTANDARD LVCMOS33 [get_ports serial_tx]
 ## serial:0.rx
set_property LOC U1 [get_ports serial_rx]
set_property IOSTANDARD LVCMOS33 [get_ports serial_rx]
 ## user_led:0
set_property LOC AB1 [get_ports user_led0]
set_property IOSTANDARD LVCMOS33 [get_ports user_led0]
 ## user_btn:0
set_property LOC AA1 [get_ports user_btn0]
set_property IOSTANDARD LVCMOS33 [get_ports user_btn0]
 ## user_led:1
set_property LOC AB8 [get_ports user_led1]
set_property IOSTANDARD LVCMOS33 [get_ports user_led1]
 ## user_btn:1
set_property LOC AB6 [get_ports user_btn1]
set_property IOSTANDARD LVCMOS33 [get_ports user_btn1]

set_property INTERNAL_VREF 0.750 [get_iobanks 35]


create_clock -name pcie_clk -period 10 [get_pins {pcie_phy/pcie_support_i/pcie_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i/TXOUTCLK}]
