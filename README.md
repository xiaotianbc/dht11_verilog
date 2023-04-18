# a DHT11 verilog module


signal:


| signal      | Description |
| ----------- | ----------- |
| clk25M      | any clk input (such as 25M)       |
| io_dht11   | in & out port of DHT11        |
| [31:0]   dht11_data   | dht11_data        |
| dht11_data_valid   | if data is valid, is high       |


If the clock is not 25M, just modify the parameter `CLK_IN` in module module `clk_1us_gen`.