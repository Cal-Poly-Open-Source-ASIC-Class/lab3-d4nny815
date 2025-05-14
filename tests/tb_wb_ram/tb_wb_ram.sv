`ifndef TB_WB_RAM
`define TB_WB_RAM

`include "wb_itf.sv"
import wb_itf::*;

module tb_wb_ram ();

  localparam WB_CLK_PERIOD = 10;

  `ifdef USE_POWER_PINS
    wire VPWR;
    wire VGND;
    assign VPWR=1;
    assign VGND=0;
  `endif

  bit wb_clk = 0;
  bit wb_reset_n = 1;
  wb_input_t pA_wb_i;
  wb_input_t pB_wb_i;
  wb_output_t pA_wb_o;
  wb_output_t pB_wb_o;

  wb_ram DUT (.*);

  // gen clocks
  always #(WB_CLK_PERIOD/2) wb_clk = ~wb_clk;

  task send_portA_wr_req();
  endtask

  task send_portA_rd_req();
  endtask

  task send_portB_wr_req();
  endtask

  task send_portB_rd_req();
  endtask

endmodule

`endif