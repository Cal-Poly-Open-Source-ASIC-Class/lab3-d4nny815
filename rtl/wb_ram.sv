`ifndef WB_RAM
`define WB_RAM

`include "DFFRAM256x32.v"

localparam ADDR_WIDTH = 11;
localparam DATA_WIDTH = 32;
localparam SEL_WIDTH = DATA_WIDTH / 8;

module wb_ram (
  input  logic                       wb_clk,
  input  logic                       wb_reset_n,

  // Port A Wishbone signals
  input  logic                       pA_wb_cyc_i,
  input  logic                       pA_wb_stb_i,
  input  logic                       pA_wb_we_i,
  input  logic [ADDR_WIDTH-1:0]      pA_wb_addr_i,
  input  logic [DATA_WIDTH-1:0]      pA_wb_data_i,
  input  logic [SEL_WIDTH-1:0]       pA_wb_sel_i,
  output logic                       pA_wb_stall_o,
  output logic                       pA_wb_ack_o,
  output logic [DATA_WIDTH-1:0]      pA_wb_data_o,

  // Port B Wishbone signals
  input  logic                       pB_wb_cyc_i,
  input  logic                       pB_wb_stb_i,
  input  logic                       pB_wb_we_i,
  input  logic [ADDR_WIDTH-1:0]      pB_wb_addr_i,
  input  logic [DATA_WIDTH-1:0]      pB_wb_data_i,
  input  logic [SEL_WIDTH-1:0]       pB_wb_sel_i,
  output logic                       pB_wb_stall_o,
  output logic                       pB_wb_ack_o,
  output logic [DATA_WIDTH-1:0]      pB_wb_data_o
);

  // * =======================================================================
  // * Internal Signals
  // * =======================================================================

  typedef enum logic { 
    PORT_A = 1'b0,
    PORT_B = 1'b1
  } port_t;

  logic toggle_priority, priority_ram;

  logic pA_trans_mux_reg, pB_trans_mux_reg;

  logic pA_ack_reg, pB_ack_reg, pA_stall_reg, pB_stall_reg;

  // * =======================================================================
  // * CONTROL PATH
  // * =======================================================================

  // status
  logic pA_req, pB_req; 
  logic pA_ram_sel, pB_ram_sel;

  // control
  logic csA, csB;
  port_t muxA, muxB; 
  logic [SEL_WIDTH-1:0] pA_sel, pB_sel;

  // Priority FSM
  always_comb begin
    muxA = PORT_A;
    muxB = PORT_B;
    csA = 0;
    csB = 0;
    pA_stall_reg = 0;
    pB_stall_reg = 0;

    pA_sel = pA_wb_we_i ? pA_wb_sel_i : '0;
    pB_sel = pB_wb_we_i ? pB_wb_sel_i : '0; 

    toggle_priority = 0;

    if (pA_req && pB_req) begin
      // collision
      if (!pA_ram_sel && pB_ram_sel) begin
        // A is requesting RAM A, B is requesting RAM B
        csA = 1;
        csB = 1;
        muxA = PORT_A;        
        muxB = PORT_B;        
      end
      else if (pA_ram_sel && !pB_ram_sel) begin
        // A is requesting RAM B, B is requesting RAM A
        csA = 1;
        csB = 1;
        muxA = PORT_B;        
        muxB = PORT_A;
      end
      else if (!pA_ram_sel && !pB_ram_sel) begin
        csA = 1;
        // muxA = priority_ram ? PORT_A : PORT_B;
        muxA = port_t'( priority_ram ? PORT_A : PORT_B );
        
        pA_stall_reg = !priority_ram;
        pB_stall_reg = priority_ram;
        
        toggle_priority = 1;
      end
      else begin
        csB = 1;
        muxB = port_t'( priority_ram ? PORT_A : PORT_B );

        
        pA_stall_reg = !priority_ram;
        pB_stall_reg = priority_ram;
        
        toggle_priority = 1;
      end
    end
    else if (pA_req && !pB_req) begin
      if (!pA_ram_sel) begin
          muxA = PORT_A;
          csA = 1;      
      end
      else begin 
          muxB = PORT_A;
          csB = 1;
      end      
    end
    else if (!pA_req && pB_req) begin
      if (!pB_ram_sel) begin
        muxA = PORT_B;
        csA = 1;
      end
      else begin
        muxB = PORT_B;
        csB = 1;
      end
    end 
  end

  // * =======================================================================
  // * DATA PATH
  // * =======================================================================

  logic [7:0] pA_addr, pB_addr;
  logic [31:0] ramA_data, ramB_data;
  

  // Port A wishbone decoder
  always_comb begin
    pA_req = pA_wb_cyc_i && pA_wb_stb_i;
  end

  // Port A addr decoder
  always_comb begin
    pA_addr = pA_wb_addr_i[ADDR_WIDTH-2:2];
    pA_ram_sel = pA_wb_addr_i[ADDR_WIDTH-1];
  end

  // Port B wishbone decoder
  always_comb begin
    pB_req = pB_wb_cyc_i && pB_wb_stb_i;
  end

  // Port B addr decoder
  always_comb begin
    pB_addr = pB_wb_addr_i[ADDR_WIDTH-2:2];
    pB_ram_sel = pB_wb_addr_i[ADDR_WIDTH-1];
  end

  DFFRAM256x32 RAM_A (
    .CLK      (wb_clk),
    .WE0      (muxA == PORT_A ? pA_sel : pB_sel),
    .EN0      (csA),
    .Di0      (muxA == PORT_A ? pA_wb_data_i : pB_wb_data_i),
    .Do0      (ramA_data),
    .A0       (muxA == PORT_A ? pA_addr : pB_addr)
  );

  DFFRAM256x32 RAM_B (
    .CLK      (wb_clk),
    .WE0      (muxB == PORT_A ? pA_sel : pB_sel),
    .EN0      (csB),
    .Di0      (muxB == PORT_A ? pA_wb_data_i : pB_wb_data_i),
    .Do0      (ramB_data),
    .A0       (muxB == PORT_A ? pA_addr : pB_addr)
  );

  always_ff @(posedge wb_clk or negedge wb_reset_n) begin
    if (!wb_reset_n) begin
      priority_ram <= 0;
      pA_ack_reg <= 0;
      pA_trans_mux_reg <= PORT_A;
      pB_ack_reg <= 0;
      pB_trans_mux_reg <= PORT_A;
    end
    else begin
      pA_ack_reg <= (pA_req && !pA_stall_reg) ? 1 : 0;
      pA_trans_mux_reg <= pA_ram_sel;

      pB_ack_reg <= (pB_req && !pB_stall_reg) ? 1 : 0;
      pB_trans_mux_reg <= pB_ram_sel;

      if (toggle_priority) priority_ram <= ~priority_ram;
    end
  end

  assign pA_wb_stall_o = pA_stall_reg;
  assign pA_wb_ack_o = pA_ack_reg;
  assign pA_wb_data_o = !pA_trans_mux_reg ? ramA_data : ramB_data;
  
  assign pB_wb_stall_o = pB_stall_reg;
  assign pB_wb_ack_o = pB_ack_reg;
  assign pB_wb_data_o = !pB_trans_mux_reg ? ramA_data : ramB_data;

endmodule

`endif