# Định nghĩa clock đầu vào trên cổng clk_in
create_clock -period 4.0 [get_ports clk]

# Thêm input delay cho input data
#set_input_delay -clock [get_clocks clk] -max 4.0 [get_ports din]
#set_input_delay -clock [get_clocks clk] -min 2.0 [get_ports din]



## Thêm input delay cho input addr_w
#set_input_delay -clock [get_clocks clk] -max 3.0 [get_ports addr_w]
#set_input_delay -clock [get_clocks clk] -min 2.0 [get_ports addr_w]

## Thêm input delay cho input addr_r
#set_input_delay -clock [get_clocks clk] -max 3.0 [get_ports addr_r]
#set_input_delay -clock [get_clocks clk] -min 2.0 [get_ports addr_r]

## Thêm input delay cho wen
#set_input_delay -clock [get_clocks clk] -max 3.0 [get_ports wen]
#set_input_delay -clock [get_clocks clk] -min 2.0 [get_ports wen]


## Thêm input delay cho ren
#set_input_delay -clock [get_clocks clk] -max 3.0 [get_ports ren]
#set_input_delay -clock [get_clocks clk] -min 2.0 [get_ports ren]

## Thêm input delay cho rst
#set_input_delay -clock [get_clocks clk] -max 3.0 [get_ports rst]
#set_input_delay -clock [get_clocks clk] -min 2.0 [get_ports rst]

## Thêm output delay cho output data
#set_output_delay -clock [get_clocks clk] -max 2.2 [get_ports dout]
#set_output_delay -clock [get_clocks clk] -min -0.5 [get_ports dout]

