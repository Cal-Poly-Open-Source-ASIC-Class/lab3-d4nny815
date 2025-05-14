`ifndef WB_ITF
`define WB_ITF

package wb_itf;
  
  localparam ADDR_WIDTH = 11;
  localparam DATA_WIDTH = 32;
  localparam SEL_WIDTH = DATA_WIDTH / 8;

  typedef struct packed {
    logic cyc;
    logic stb;
    logic we;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] data;
    logic [SEL_WIDTH-1:0]  sel;
  } wb_input_t;

  typedef struct packed {
    logic stall;
    logic ack;
    logic [DATA_WIDTH-1:0] data;
  } wb_output_t;

endpackage

`endif