`timescale 1ns/1ps

`ifndef TB_WB_RAM
`define TB_WB_RAM


`define WAIT(cond, clk)        \
  begin                         \
    while (!(cond))             \
      @(posedge clk);           \
    @(posedge clk);             \
  end

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
  logic                       pA_wb_cyc_i;
  logic                       pA_wb_stb_i;
  logic                       pA_wb_we_i;
  logic [11-1:0]      pA_wb_addr_i;
  logic [32-1:0]      pA_wb_data_i;
  logic [4-1:0]       pA_wb_sel_i;
  logic                       pA_wb_stall_o;
  logic                       pA_wb_ack_o;
  logic [32-1:0]      pA_wb_data_o;

  // Port B Wishbone signals
  logic                       pB_wb_cyc_i;
  logic                       pB_wb_stb_i;
  logic                       pB_wb_we_i;
  logic [11-1:0]      pB_wb_addr_i;
  logic [32-1:0]      pB_wb_data_i;
  logic [4-1:0]       pB_wb_sel_i;
  logic                       pB_wb_stall_o;
  logic                       pB_wb_ack_o;
  logic [32-1:0]      pB_wb_data_o;

  wb_ram DUT (.*);

  // gen clocks
  always #(WB_CLK_PERIOD/2) wb_clk = ~wb_clk;

  task automatic wait_cycles(input bit [31:0] n);
    for(bit [31:0] i = n; i > 0; i--) begin
       @(posedge wb_clk);
    end
  endtask

  task reset_dut();
    wb_clk = 0;
    wb_reset_n = 1;
    pA_wb_cyc_i   = 'd0;
    pA_wb_stb_i   = 'd0;
    pA_wb_we_i    = 'd0;
    pA_wb_addr_i  = 'd0;
    pA_wb_data_i  = 'd0;
    pA_wb_sel_i   = 'd0;
    pB_wb_cyc_i   = 'd0;
    pB_wb_stb_i   = 'd0;
    pB_wb_we_i    = 'd0;
    pB_wb_addr_i  = 'd0;
    pB_wb_data_i  = 'd0;
    pB_wb_sel_i   = 'd0;

    wait_cycles(1);
    wb_reset_n = 0;
    wait_cycles(2);
    wb_reset_n = 1;
  endtask

  task write_portA(
    input [11-1:0] addr, 
    input [32-1:0] data, 
    input [4-1:0] byte_sel);

    wait(!pA_wb_ack_o && !pA_wb_stall_o);
    wait_cycles(1);
    pA_wb_cyc_i   = 'd1;
    pA_wb_stb_i   = 'd1;
    pA_wb_we_i    = 'd1;
    pA_wb_addr_i  = addr;
    pA_wb_data_i  = data;
    pA_wb_sel_i   = byte_sel;

    // `WAIT(pA_wb_ack_o, wb_clk);
    wait(pA_wb_ack_o);
    // @(posedge wb_clk);
    pA_wb_cyc_i   = 'd0;
    pA_wb_stb_i   = 'd0;
    pA_wb_we_i    = 'd0;
    pA_wb_addr_i  = 'd0;
    pA_wb_data_i  = 'd0;
    pA_wb_sel_i   = 'd0;

    @(posedge wb_clk);
  endtask

  task read_portA(
    input [11-1:0] addr, 
    input [4-1:0] byte_sel,
    output [32-1:0] data);

    wait_cycles(1);
    pA_wb_cyc_i   = 'd1;
    pA_wb_stb_i   = 'd1;
    pA_wb_we_i    = 'd0;
    pA_wb_addr_i  = addr;
    pA_wb_sel_i   = byte_sel;

    wait(pA_wb_ack_o);
    pA_wb_cyc_i   = 'd0;
    pA_wb_stb_i   = 'd0;
    pA_wb_we_i    = 'd0;
    pA_wb_addr_i  = 'd0;
    pA_wb_sel_i   = 'd0;
    
    @(posedge wb_clk);

    // data =  DUT.ramA_data;
    data = pA_wb_data_o;
    
    // $error("%h or %h -> %h", DUT.ramA_data, DUT.ramB_data, data);
  endtask

  task write_portB(
    input [11-1:0] addr,
    input [32-1:0] data,
    input [4-1:0] byte_sel);
      
    wait(!pB_wb_ack_o && !pB_wb_stall_o);
    wait_cycles(1);
    pB_wb_cyc_i  = 'd1;
    pB_wb_stb_i  = 'd1;
    pB_wb_we_i   = 'd1;
    pB_wb_addr_i = addr;
    pB_wb_data_i = data;
    pB_wb_sel_i  = byte_sel;

    // `WAIT(pB_wb_ack_o, wb_clk);
    wait(pB_wb_ack_o);

    pB_wb_cyc_i  = 'd0;
    pB_wb_stb_i  = 'd0;
    pB_wb_we_i   = 'd0;
    pB_wb_addr_i = 'd0;
    pB_wb_data_i = 'd0;
    pB_wb_sel_i  = 'd0;
  endtask

  task read_portB(
    input  [11-1:0] addr,
    input  [4-1:0]  byte_sel,
    output [32-1:0] data);
      
    wait_cycles(1);
    pB_wb_cyc_i  = 'd1;
    pB_wb_stb_i  = 'd1;
    pB_wb_we_i   = 'd0;
    pB_wb_addr_i = addr;
    pB_wb_sel_i  = byte_sel;

    wait(pB_wb_ack_o);
    pB_wb_cyc_i  = 'd0;
    pB_wb_stb_i  = 'd0;
    pB_wb_we_i   = 'd0;
    pB_wb_addr_i = 'd0;
    pB_wb_sel_i  = 'd0;
    data = pB_wb_data_o;
    wait_cycles(1);
    
  endtask

  // test can write to a ram from port A
  // task automatic test_portA_write();
  //   bit [11-1:0] TESTADDR;  
  //   bit [32-1:0] TESTWORD;
    
  //   TESTADDR = 'h04;
  //   TESTWORD = 'hcafebabe;
    
  //   write_portA(TESTADDR, TESTWORD, {4{1'b1}});
    
  //   @(negedge wb_clk);
  //   // assert(DUT.RAM_A.RAM[TESTADDR[9:2]] == TESTWORD)
  //   // else begin
  //     // $error("Port A write failed @ addr 0x%0h: saw 0x%0h, expected 0x%0h",
  //           //  TESTADDR,
  //           //  DUT.RAM_A.RAM[TESTADDR[9:2]],
  //           //  TESTWORD);
  //     // $fatal;
  //   // end
  //   // @(posedge wb_clk);

  // endtask

  // // test can write to a ram from port B
  // task automatic test_portB_write();
  //   bit [11-1:0] TESTADDR  = 'h08;
  //   bit [32-1:0] TESTWORD  = 'hdead_beef;
    
  //   write_portB(TESTADDR, TESTWORD, {4{1'b1}});
    
  //   @(negedge wb_clk);
  //   // assert(DUT.RAM_A.RAM[TESTADDR[9:2]] == TESTWORD)
  //   // else begin
  //     // $error("Port B write failed @ addr 0x%0h: saw 0x%0h, expected 0x%0h",
  //             // TESTADDR,
  //             // DUT.RAM_A.RAM[TESTADDR[9:2]],
  //             // TESTWORD);
  //     // $fatal;
  //   // end
  //   @(posedge wb_clk);

  // endtask

  // // test the different byte selects on port A
  // task automatic test_portA_write_diff_bytes();
  //   bit [11-1:0] TESTADDR = 'h10;
  //   bit [32-1:0] ORIG     = 32'hffff_ffff;
  //   bit [32-1:0] DATA     = 32'h0102_0304;
  //   bit [32-1:0] dut_word;
  //   bit [32-1:0]      expected;
  //   logic [4-1:0]     sel;

  //   write_portA(TESTADDR, ORIG, {4{1'b1}});

  //   for (int i = 0; i < (1 << 4); i++) begin
  //     sel = i[4-1:0];

  //     write_portA(TESTADDR, DATA, sel);

  //     dut_word = DUT.RAM_A.RAM[TESTADDR[9:2]];

  //     expected = {
  //       sel[3] ? DATA[31:24] : ORIG[31:24],
  //       sel[2] ? DATA[23:16] : ORIG[23:16],
  //       sel[1] ? DATA[15: 8] : ORIG[15: 8],
  //       sel[0] ? DATA[ 7: 0] : ORIG[ 7: 0]
  //     };

  //   @(negedge wb_clk);
  //     assert (dut_word == expected)
  //     else begin
  //       $error("PortA write byte-select %0b failed @ addr 0x%0h: got 0x%0h, expected 0x%0h",
  //               sel, TESTADDR, dut_word, expected);
  //       $fatal;
  //     end

  //     write_portA(TESTADDR, ORIG, {4{1'b1}});
  //   end
  //   @(posedge wb_clk);

  // endtask

  // task automatic test_portB_write_diff_bytes();
  //   bit [11-1:0]   TESTADDR = 'h10;
  //   bit [32-1:0]   ORIG     = 32'hffff_ffff;
  //   bit [32-1:0]   DATA     = 32'h0102_0304;
  //   bit [32-1:0]   dut_word;
  //   bit [32-1:0]   expected;
  //   logic [4-1:0]  sel;

  //   write_portB(TESTADDR, ORIG, {4{1'b1}});

  //   for (int i = 0; i < (1 << 4); i++) begin
  //     sel = i[4-1:0];
  //     write_portB(TESTADDR, DATA, sel);

  //     // inspect internal RAM
  //     dut_word = DUT.RAM_A.RAM[TESTADDR[9:2]];

  //     // build expected word
  //     expected = {
  //       sel[3] ? DATA[31:24] : ORIG[31:24],
  //       sel[2] ? DATA[23:16] : ORIG[23:16],
  //       sel[1] ? DATA[15: 8] : ORIG[15: 8],
  //       sel[0] ? DATA[ 7: 0] : ORIG[ 7: 0]
  //     };

  //   @(negedge wb_clk);
  //     assert (dut_word == expected)
  //       else begin
  //         $error("PortB write byte-select %0b failed @ addr 0x%0h: got 0x%0h, expected 0x%0h",
  //                sel, TESTADDR, dut_word, expected);
  //         $fatal;
  //       end

  //     // restore original before next
  //     write_portB(TESTADDR, ORIG, {4{1'b1}});
  //   end
  //   @(posedge wb_clk);
  // endtask

  // // test reading back only selected bytes on Port A
  // task automatic test_portA_read_diff_bytes();
  //   bit [11-1:0]      TESTADDR = 'h10;
  //   bit [32-1:0]      ORIG     = 32'hDEAD_BEEF;
  //   bit [32-1:0]      dut_word;
  //   bit [32-1:0]      expected;

  //   // preload memory with a known pattern
  //   write_portA(TESTADDR, ORIG, {4{1'b1}});

  //   // read only byte 0 (LSB)
  //   read_portA(TESTADDR, 4'b0001, dut_word);
  //   expected = {24'h0, ORIG[7:0]};
  //   assert (dut_word == expected)
  //     else begin
  //       $error("Port A byte-0 read failed: got 0x%0h, expected 0x%0h",
  //              dut_word, expected);
  //       $fatal;
  //     end

  //   // read only byte 1
  //   read_portA(TESTADDR, 4'b0010, dut_word);
  //   expected = {16'h0, ORIG[15:8], 8'h0};
  //   assert (dut_word == expected)
  //     else begin
  //       $error("Port A byte-1 read failed: got 0x%0h, expected 0x%0h",
  //              dut_word, expected);
  //       $fatal;
  //     end

  //   // read only byte 2
  //   read_portA(TESTADDR, 4'b0100, dut_word);
  //   expected = {8'h0, ORIG[23:16], 16'h0};
  //   assert (dut_word == expected)
  //     else begin
  //       $error("Port A byte-2 read failed: got 0x%0h, expected 0x%0h",
  //              dut_word, expected);
  //       $fatal;
  //     end

  //   // read only byte 3 (MSB)
  //   read_portA(TESTADDR, 4'b1000, dut_word);
  //   expected = {ORIG[31:24], 24'h0};
  //   assert (dut_word == expected)
  //     else begin
  //       $error("Port A byte-3 read failed: got 0x%0h, expected 0x%0h",
  //              dut_word, expected);
  //       $fatal;
  //     end
  // endtask

  // task automatic test_portB_read_diff_bytes();
  //   bit [11-1:0]      TESTADDR = 'h10;
  //   bit [32-1:0]      ORIG     = 32'hDEAD_BEEF;
  //   bit [32-1:0]      dut_word;
  //   bit [32-1:0]      expected;

  //   // preload memory with a known pattern
  //   write_portB(TESTADDR, ORIG, {4{1'b1}});

  //   // read only byte 0 (LSB)
  //   read_portB(TESTADDR, 4'b0001, dut_word);
  //   expected = {24'h0, ORIG[7:0]};
  //   assert (dut_word == expected)
  //     else begin
  //       $error("Port B byte-0 read failed: got 0x%0h, expected 0x%0h",
  //              dut_word, expected);
  //       $fatal;
  //     end

  //   // read only byte 1
  //   read_portB(TESTADDR, 4'b0010, dut_word);
  //   expected = {16'h0, ORIG[15:8], 8'h0};
  //   assert (dut_word == expected)
  //     else begin
  //       $error("Port B byte-1 read failed: got 0x%0h, expected 0x%0h",
  //              dut_word, expected);
  //       $fatal;
  //     end

  //   // read only byte 2
  //   read_portB(TESTADDR, 4'b0100, dut_word);
  //   expected = {8'h0, ORIG[23:16], 16'h0};
  //   assert (dut_word == expected)
  //     else begin
  //       $error("Port B byte-2 read failed: got 0x%0h, expected 0x%0h",
  //              dut_word, expected);
  //       $fatal;
  //     end

  //   // read only byte 3 (MSB)
  //   read_portB(TESTADDR, 4'b1000, dut_word);
  //   expected = {ORIG[31:24], 24'h0};
  //   assert (dut_word == expected)
  //     else begin
  //       $error("Port B byte-3 read failed: got 0x%0h, expected 0x%0h",
  //              dut_word, expected);
  //       $fatal;
  //     end
  // endtask

  // test can read and write to a ram from port A
  task automatic test_portA_single_wr_rd();
    bit [11-1:0] TESTADDR   = 'h00;
    bit [32-1:0] TESTWORD   = 32'hcafebabe;
    bit [32-1:0] dut_word;

    write_portA(TESTADDR, TESTWORD, {4{1'b1}});
    read_portA(TESTADDR, {4{1'b1}}, dut_word);

    // wait_cycles(1);
    @(negedge wb_clk);
    assert (dut_word == TESTWORD)
      else begin
        $error("Port A read/write failed @ addr 0x%0h: got 0x%0h, expected 0x%0h",
               TESTADDR, dut_word, TESTWORD);
        wait_cycles(1);
        $fatal;
      end
  endtask

  // test can read and write to a ram from port B
  task automatic test_portB_single_wr_rd();
    bit [11-1:0] TESTADDR  = 'h00;
    bit [32-1:0] TESTWORD  = 'hcafebabe;
    bit [32-1:0] dut_word;
    
    write_portB(TESTADDR, TESTWORD, {4{1'b1}});
    read_portB(TESTADDR, {4{1'b1}}, dut_word);

    @(negedge wb_clk);
    assert(dut_word == TESTWORD)
    else begin
      $error("Port B read/write failed @ addr 0x%0h: got 0x%0h, expected 0x%0h",
               TESTADDR, dut_word, TESTWORD);
      $fatal;
    end
  endtask

  // test can write to both ram from port A
  task test_portA_mult_wr_rd();
    bit [11-1:0] addr;
    bit [32-1:0] write_data, read_data;
    for (int i = 0; i < 2 ** 11; i += 32) begin
      addr       = i[11-1:0];
      write_data = 32'hffff_ffff - i;
      
      write_portA(addr, write_data, {4{1'b1}});
      read_portA(addr, {4{1'b1}}, read_data);

    @(negedge wb_clk);
      assert (read_data == write_data)
        else begin
          $error("Port A multi test failed at index %0d (addr=0x%0h): got 0x%0h, expected 0x%0h",
                  i, addr, read_data, write_data);
          $fatal;
        end
    end
  endtask

  // test can write to both ram from port B
  task test_portB_mult_wr_rd();
    bit [11-1:0] addr;
    bit [32-1:0] write_data, read_data;
    for (int i = 0; i < 2 ** 11; i += 32) begin
      addr       = i[11-1:0];
      write_data = 32'hffff_ffff - i;
      
      write_portB(addr, write_data, {4{1'b1}});
      read_portB(addr, {4{1'b1}}, read_data);

    @(negedge wb_clk);
      assert (read_data == write_data)
        else begin
          $error("Port B multi test failed at index %0d (addr=0x%0h): got 0x%0h, expected 0x%0h",
                  i, addr, read_data, write_data);
          $fatal;
        end
    end
  endtask

  // test stalls
  task automatic test_both_ports_wr_rd();
    bit [11-1:0] addrA  = 'h04;
    bit [11-1:0] addrB  = 'h08;
    bit [32-1:0] dataA  = 32'hdead_beef;
    bit [32-1:0] dataB  = 32'hcafebabe;

    pA_wb_cyc_i  = 0;
    pA_wb_stb_i  = 0;
    pA_wb_we_i   = 0;
    pA_wb_addr_i = 0;
    pA_wb_data_i = 0;
    pA_wb_sel_i  = 0;

    pB_wb_cyc_i  = 0;
    pB_wb_stb_i  = 0;
    pB_wb_we_i   = 0;
    pB_wb_addr_i = 0;
    pB_wb_data_i = 0;
    pB_wb_sel_i  = 0;

    wait_cycles(1);

    for (int i = 0; i < 10; i++) begin
      wait(!pA_wb_ack_o && !pA_wb_stall_o);
      wait(!pB_wb_ack_o && !pB_wb_stall_o);
      pA_wb_cyc_i  = 1;
      pA_wb_stb_i  = 1;
      pA_wb_we_i   = 1;
      pA_wb_addr_i = addrA;
      pA_wb_data_i = dataA;
      pA_wb_sel_i  = {4{1'b1}};

      pB_wb_cyc_i  = 1;
      pB_wb_stb_i  = 1;
      pB_wb_we_i   = 1;
      pB_wb_addr_i = addrB;
      pB_wb_data_i = dataB;
      pB_wb_sel_i  = {4{1'b1}};

      wait(pB_wb_stall_o || pA_wb_stall_o)
      assert(pB_wb_stall_o ^ pA_wb_stall_o)
      else begin
        $error("Expected exactly one port to stall: A_stall=%0b, B_stall=%0b",
                pA_wb_stall_o, pB_wb_stall_o);
        $fatal;
      end

      @(posedge wb_clk);
      wait(pA_wb_ack_o || pB_wb_ack_o)
      assert(pA_wb_ack_o ^ pB_wb_ack_o)
      else begin
        $error("Expected exactly one port to ack: A_ack=%0b, B_ack=%0b",
                pA_wb_ack_o, pB_wb_ack_o);
        @(posedge wb_clk);
        $fatal;
      end
    end

    pA_wb_cyc_i  = 0;
    pA_wb_stb_i  = 0;
    pA_wb_we_i   = 0;
    pA_wb_addr_i = 0;
    pA_wb_data_i = 0;
    pA_wb_sel_i  = 0;

    pB_wb_cyc_i  = 0;
    pB_wb_stb_i  = 0;
    pB_wb_we_i   = 0;
    pB_wb_addr_i = 0;
    pB_wb_data_i = 0;
    pB_wb_sel_i  = 0;

  endtask

  // tests
  initial begin
    #100000;
    $error("[ERROR] TIMEOUT!!!");
    $fatal;
  end

  initial begin
    `ifdef VERILATOR
      $dumpfile("tb_verilator.vcd");
      $dumpvars(0, tb_wb_ram);
    `elsif GL 
      $dumpfile("tb_icarus_gl.vcd");
      $dumpvars(2, tb_wb_ram);
    `else
      $dumpfile("tb_icarus.vcd");
      $dumpvars(0, tb_wb_ram);
    `endif

    reset_dut();

    test_portA_write();

    test_portB_write();

    test_portA_write_diff_bytes();

    test_portB_write_diff_bytes();

    test_portA_single_wr_rd();

    test_portB_single_wr_rd();

    test_portA_mult_wr_rd();

    test_portB_mult_wr_rd();
    
    test_both_ports_wr_rd();

    wait_cycles(1);

    $finish();
  end

endmodule

`endif