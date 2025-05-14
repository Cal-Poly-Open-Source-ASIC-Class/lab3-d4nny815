`ifndef WB_RAM
`define WB_RAM

`include "wb_itf.sv"
`include "DFFRAM256x32.v"

import wb_itf::*;

module wb_ram (
  input logic wb_clk,
  input logic wb_reset_n,
  input wb_input_t pA_wb_i,
  input wb_input_t pB_wb_i,
  output wb_output_t pA_wb_o,
  output wb_output_t pB_wb_o
  );

  // * =======================================================================
  // * Internal Signals
  // * =======================================================================

  typedef enum logic [1:0] { 
    IDLE_A,
    IDLE_B,
    PORT_A,
    PORT_B
  } state_t;
  state_t PS, NS;

  always_ff @(posedge wb_clk or negedge wb_reset_n) begin
    if (!wb_reset_n) 
      PS <= IDLE_A;
    else
      PS <= NS;
  end

  // * =======================================================================
  // * CONTROL PATH
  // * =======================================================================

  always_comb begin
    case (PS)
      IDLE_A: begin
      end

      IDLE_B: begin
      end

      PORT_A: begin
      end

      PORT_B: begin
      end
    endcase
  end


  // * =======================================================================
  // * DATA PATH
  // * =======================================================================

  DFFRAM256x32 RAM_A (
    .CLK      (),
    .WE0      (),
    .EN0      (),
    .Di0      (),
    .Do0      (),
    .A0       ()
  );

  DFFRAM256x32 RAM_B (
    .CLK      (),
    .WE0      (),
    .EN0      (),
    .Di0      (),
    .Do0      (),
    .A0       ()
  );

  assign pA_wb_o.stall = 0;
  assign pA_wb_o.ack = 0;
  assign pA_wb_o.data = 0;
  
  assign pB_wb_o.stall = 0;
  assign pB_wb_o.ack = 0;
  assign pB_wb_o.data = 0;



endmodule

`endif