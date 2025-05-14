`ifndef TB_WB_RAM
`define TB_WB_RAM

`include "wb_ram.sv"
`include "wb_itf.sv"

import wb_itf::*;

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
  wb_input_t pA_wb_i;
  wb_input_t pB_wb_i;
  wb_output_t pA_wb_o;
  wb_output_t pB_wb_o;

  wb_ram DUT (.*);

  // gen clocks
  always #(WB_CLK_PERIOD/2) wb_clk = ~wb_clk;

  task wait_cycles(input bit [31:0] n);
    for(bit [31:0] i = n; i > 0; i--) @(posedge wb_clk);
  endtask

  task reset_dut();
    wb_clk = 0;
    wb_reset_n = 1;
    pA_wb_i = 'd0;
    pB_wb_i = 'd0;

    wait_cycles(1);
    wb_reset_n = 0;
    wait_cycles(2);
    wb_reset_n = 1;
  endtask

  task write_portA(
    input [ADDR_WIDTH-1:0] addr, 
    input [DATA_WIDTH-1:0] data, 
    input [SEL_WIDTH-1:0] byte_sel);

    wait_cycles(1);
    pA_wb_i.cyc   = 1;
    pA_wb_i.stb   = 1;
    pA_wb_i.we    = 1;
    pA_wb_i.addr  = addr;
    pA_wb_i.data  = data;
    pA_wb_i.sel   = byte_sel;

    `WAIT(pA_wb_o.ack, wb_clk);

    pA_wb_i = 'd0;
  endtask

  task read_portA(
    input [ADDR_WIDTH-1:0] addr, 
    input [SEL_WIDTH-1:0] byte_sel,
    output [DATA_WIDTH-1:0] data);

    wait_cycles(1);
    pA_wb_i.cyc   = 1;
    pA_wb_i.stb   = 1;
    pA_wb_i.we    = 0;
    pA_wb_i.addr  = addr;
    pA_wb_i.sel   = byte_sel;

    `WAIT(pA_wb_o.ack, wb_clk);
    pA_wb_i = 'd0;

    data = pA_wb_o.data;
  endtask

  task write_portB(
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] data,
    input [SEL_WIDTH-1:0] byte_sel);
      
    wait_cycles(1);
    pB_wb_i.cyc  = 1;
    pB_wb_i.stb  = 1;
    pB_wb_i.we   = 1;
    pB_wb_i.addr = addr;
    pB_wb_i.data = data;
    pB_wb_i.sel  = byte_sel;

    `WAIT(pB_wb_o.ack, wb_clk);

    pB_wb_i = '0;
  endtask

  task read_portB(
    input  [ADDR_WIDTH-1:0] addr,
    input  [SEL_WIDTH-1:0]  byte_sel,
    output [DATA_WIDTH-1:0] data);
      
    wait_cycles(1);
    pB_wb_i.cyc  = 1;
    pB_wb_i.stb  = 1;
    pB_wb_i.we   = 0;
    pB_wb_i.addr = addr;
    pB_wb_i.sel  = byte_sel;

    `WAIT(pB_wb_o.ack, wb_clk);

    data = pB_wb_o.data;
    pB_wb_i = '0;
  endtask

  // test can write to a ram from port A
  task automatic test_portA_write();
    bit [ADDR_WIDTH-1:0] TESTADDR  = 'h00;
    bit [DATA_WIDTH-1:0] TESTWORD  = 'hcafebabe;
    
    write_portA(TESTADDR, TESTWORD, {SEL_WIDTH{1'b1}});
    
    assert(DUT.RAM_A.RAM[TESTADDR[7:0]] == TESTWORD)
    else begin
      $error("Port A write failed @ addr 0x%0h: saw 0x%0h, expected 0x%0h",
             TESTADDR,
             DUT.RAM_A.RAM[TESTADDR[7:0]],
             TESTWORD);
      $fatal;
    end
  endtask

  // test can write to a ram from port A
  task automatic test_portB_write();
    bit [ADDR_WIDTH-1:0] TESTADDR  = 'h00;
    bit [DATA_WIDTH-1:0] TESTWORD  = 'hcafebabe;
    
    write_portB(TESTADDR, TESTWORD, {SEL_WIDTH{1'b1}});
    
    assert(DUT.RAM_B.RAM[TESTADDR[7:0]] == TESTWORD)
    else begin
      $error("Port B write failed @ addr 0x%0h: saw 0x%0h, expected 0x%0h",
              TESTADDR,
              DUT.RAM_B.RAM[TESTADDR[7:0]],
              TESTWORD);
      $fatal;
    end
  endtask

  // test the different byte selects on port A
  task automatic test_portA_write_diff_bytes();
    bit [ADDR_WIDTH-1:0] TESTADDR = 'h10;
    bit [DATA_WIDTH-1:0] ORIG     = 32'hffff_ffff;
    bit [DATA_WIDTH-1:0] DATA     = 32'h0102_0304;
    bit [DATA_WIDTH-1:0] dut_word;

    write_portA(TESTADDR, ORIG, {SEL_WIDTH{1'b1}});

    // write only byte 0
    write_portA(TESTADDR, DATA, 4'b0001);
    dut_word = DUT.RAM_A.RAM[TESTADDR[7:0]];
    assert (dut_word == {ORIG[31:8], DATA[7:0]})
    else begin
      $error("Byte0 write failed: got 0x%0h, expected 0x%0h",
              dut_word, {ORIG[31:8], DATA[7:0]});
      $fatal;
    end

    // write only byte 1
    write_portA(TESTADDR, DATA, 4'b0010);
    dut_word = DUT.RAM_A.RAM[TESTADDR[7:0]];
    assert (dut_word == {ORIG[31:16], DATA[15:0]})
      else begin
        $error("Byte1 write failed: got 0x%0h, expected 0x%0h",
               dut_word, {ORIG[31:16], DATA[15:0]});
        $fatal;
      end

    // write only byte 2
    write_portA(TESTADDR, DATA, 4'b0100);
    dut_word = DUT.RAM_A.RAM[TESTADDR[7:0]];
    assert (dut_word == {ORIG[31:24], DATA[23:0]})
      else begin
        $error("Byte2 write failed: got 0x%0h, expected 0x%0h",
               dut_word, {ORIG[31:24], DATA[23:0]});
        $fatal;
      end

    // write only byte 3
    write_portA(TESTADDR, DATA, 4'b1000);
    dut_word = DUT.RAM_A.RAM[TESTADDR[7:0]];
    assert (dut_word == DATA)
      else begin
        $error("Byte3 write failed: got 0x%0h, expected 0x%0h",
               dut_word, DATA);
        $fatal;
      end
  endtask

  // test the different byte selects on port B
  task automatic test_portB_write_diff_bytes();
    bit [ADDR_WIDTH-1:0] TESTADDR = 'h10;
    bit [DATA_WIDTH-1:0] ORIG     = 32'hffff_ffff;
    bit [DATA_WIDTH-1:0] DATA     = 32'h0102_0304;
    bit [DATA_WIDTH-1:0] dut_word;

    write_portB(TESTADDR, ORIG, {SEL_WIDTH{1'b1}});

    // write only byte 0
    write_portB(TESTADDR, DATA, 4'b0001);
    dut_word = DUT.RAM_B.RAM[TESTADDR[7:0]];
    assert (dut_word == {ORIG[31:8], DATA[7:0]})
    else begin
      $error("Byte0 write failed: got 0x%0h, expected 0x%0h",
              dut_word, {ORIG[31:8], DATA[7:0]});
      $fatal;
    end

    // write only byte 1
    write_portB(TESTADDR, DATA, 4'b0010);
    dut_word = DUT.RAM_B.RAM[TESTADDR[7:0]];
    assert (dut_word == {ORIG[31:16], DATA[15:0]})
      else begin
        $error("Byte1 write failed: got 0x%0h, expected 0x%0h",
               dut_word, {ORIG[31:16], DATA[15:0]});
        $fatal;
      end

    // write only byte 2
    write_portB(TESTADDR, DATA, 4'b0100);
    dut_word = DUT.RAM_B.RAM[TESTADDR[7:0]];
    assert (dut_word == {ORIG[31:24], DATA[23:0]})
      else begin
        $error("Byte2 write failed: got 0x%0h, expected 0x%0h",
               dut_word, {ORIG[31:24], DATA[23:0]});
        $fatal;
      end

    // write only byte 3
    write_portB(TESTADDR, DATA, 4'b1000);
    dut_word = DUT.RAM_B.RAM[TESTADDR[7:0]];
    assert (dut_word == DATA)
      else begin
        $error("Byte3 write failed: got 0x%0h, expected 0x%0h",
               dut_word, DATA);
        $fatal;
      end
  endtask

  // test reading back only selected bytes on Port A
  task automatic test_portA_read_diff_bytes();
    bit [ADDR_WIDTH-1:0]      TESTADDR = 'h10;
    bit [DATA_WIDTH-1:0]      ORIG     = 32'hDEAD_BEEF;
    bit [DATA_WIDTH-1:0]      dut_word;
    bit [DATA_WIDTH-1:0]      expected;

    // preload memory with a known pattern
    write_portA(TESTADDR, ORIG, {SEL_WIDTH{1'b1}});

    // read only byte 0 (LSB)
    read_portA(TESTADDR, 4'b0001, dut_word);
    expected = {24'h0, ORIG[7:0]};
    assert (dut_word == expected)
      else begin
        $error("Port A byte-0 read failed: got 0x%0h, expected 0x%0h",
               dut_word, expected);
        $fatal;
      end

    // read only byte 1
    read_portA(TESTADDR, 4'b0010, dut_word);
    expected = {16'h0, ORIG[15:8], 8'h0};
    assert (dut_word == expected)
      else begin
        $error("Port A byte-1 read failed: got 0x%0h, expected 0x%0h",
               dut_word, expected);
        $fatal;
      end

    // read only byte 2
    read_portA(TESTADDR, 4'b0100, dut_word);
    expected = {8'h0, ORIG[23:16], 16'h0};
    assert (dut_word == expected)
      else begin
        $error("Port A byte-2 read failed: got 0x%0h, expected 0x%0h",
               dut_word, expected);
        $fatal;
      end

    // read only byte 3 (MSB)
    read_portA(TESTADDR, 4'b1000, dut_word);
    expected = {ORIG[31:24], 24'h0};
    assert (dut_word == expected)
      else begin
        $error("Port A byte-3 read failed: got 0x%0h, expected 0x%0h",
               dut_word, expected);
        $fatal;
      end
  endtask

  task automatic test_portB_read_diff_bytes();
    bit [ADDR_WIDTH-1:0]      TESTADDR = 'h10;
    bit [DATA_WIDTH-1:0]      ORIG     = 32'hDEAD_BEEF;
    bit [DATA_WIDTH-1:0]      dut_word;
    bit [DATA_WIDTH-1:0]      expected;

    // preload memory with a known pattern
    write_portB(TESTADDR, ORIG, {SEL_WIDTH{1'b1}});

    // read only byte 0 (LSB)
    read_portB(TESTADDR, 4'b0001, dut_word);
    expected = {24'h0, ORIG[7:0]};
    assert (dut_word == expected)
      else begin
        $error("Port B byte-0 read failed: got 0x%0h, expected 0x%0h",
               dut_word, expected);
        $fatal;
      end

    // read only byte 1
    read_portB(TESTADDR, 4'b0010, dut_word);
    expected = {16'h0, ORIG[15:8], 8'h0};
    assert (dut_word == expected)
      else begin
        $error("Port B byte-1 read failed: got 0x%0h, expected 0x%0h",
               dut_word, expected);
        $fatal;
      end

    // read only byte 2
    read_portB(TESTADDR, 4'b0100, dut_word);
    expected = {8'h0, ORIG[23:16], 16'h0};
    assert (dut_word == expected)
      else begin
        $error("Port B byte-2 read failed: got 0x%0h, expected 0x%0h",
               dut_word, expected);
        $fatal;
      end

    // read only byte 3 (MSB)
    read_portB(TESTADDR, 4'b1000, dut_word);
    expected = {ORIG[31:24], 24'h0};
    assert (dut_word == expected)
      else begin
        $error("Port B byte-3 read failed: got 0x%0h, expected 0x%0h",
               dut_word, expected);
        $fatal;
      end
  endtask

  // test can read and write to a ram from port A
  task automatic test_portA_single_wr_rd();
    bit [ADDR_WIDTH-1:0] TESTADDR   = 'h00;
    bit [DATA_WIDTH-1:0] TESTWORD   = 32'hcafebabe;
    bit [DATA_WIDTH-1:0] dut_word;

    write_portA(TESTADDR, TESTWORD, {SEL_WIDTH{1'b1}});
    read_portA(TESTADDR, {SEL_WIDTH{1'b1}}, dut_word);

    assert (dut_word == TESTWORD)
      else begin
        $error("Port A read/write failed @ addr 0x%0h: got 0x%0h, expected 0x%0h",
               TESTADDR, dut_word, TESTWORD);
        $fatal;
      end
  endtask

  // test can read and write to a ram from port B
  task automatic test_portB_single_wr_rd();
    bit [ADDR_WIDTH-1:0] TESTADDR  = 'h00;
    bit [DATA_WIDTH-1:0] TESTWORD  = 'hcafebabe;
    bit [DATA_WIDTH-1:0] dut_word;
    
    write_portB(TESTADDR, TESTWORD, {SEL_WIDTH{1'b1}});
    read_portB(TESTADDR, {SEL_WIDTH{1'b1}}, dut_word);

    assert(dut_word == TESTWORD)
    else begin
      $error("Port B read/write failed @ addr 0x%0h: got 0x%0h, expected 0x%0h",
               TESTADDR, dut_word, TESTWORD);
      $fatal;
    end
  endtask

  // test can write to both ram from port A
  task test_portA_mult_wr_rd();
    bit [ADDR_WIDTH-1:0] addr;
    bit [DATA_WIDTH-1:0] write_data, read_data;
    for (int i = 0; i < 2 ** ADDR_WIDTH; i += 4) begin
      addr       = i[ADDR_WIDTH-1:0];
      write_data = 32'hffff_ffff - i;
      
      write_portA(addr, write_data, {SEL_WIDTH{1'b1}});
      read_portA(addr, {SEL_WIDTH{1'b1}}, read_data);

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
    bit [ADDR_WIDTH-1:0] addr;
    bit [DATA_WIDTH-1:0] write_data, read_data;
    for (int i = 0; i < 2 ** ADDR_WIDTH; i += 4) begin
      addr       = i[ADDR_WIDTH-1:0];
      write_data = 32'hffff_ffff - i;
      
      write_portB(addr, write_data, {SEL_WIDTH{1'b1}});
      read_portB(addr, {SEL_WIDTH{1'b1}}, read_data);

      assert (read_data == write_data)
        else begin
          $error("Port B multi test failed at index %0d (addr=0x%0h): got 0x%0h, expected 0x%0h",
                  i, addr, read_data, write_data);
          $fatal;
        end
    end
  endtask

  // test stalls
  task test_both_ports_wr_rd();
    // TODO: implement
  endtask



  // tests
  initial begin
    #1000;
    $error("[ERROR] TIMEOUT!!!");
    $fatal;
  end

  initial begin
    reset_dut();

    $finish();
  end

endmodule

`endif