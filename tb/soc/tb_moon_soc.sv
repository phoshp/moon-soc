// ============================================================================
// File: tb/soc/tb_moon_soc.sv
// Description: Standalone SystemVerilog testbench for moon_soc_top integrating
//              AXI4 external RAM model, Boot ROM, UART capture, and test status.
// ============================================================================

`timescale 1ns/1ps

`include "moon_pkg.sv"
`include "axi_pkg.sv"
`include "moon_soc_top.sv"

module tb_moon_soc (
  input  logic clk,
  input  logic rst_n,
  output logic test_passed,
  output logic test_failed,
  output logic [31:0] test_error_code,
  output logic [63:0] debug_pc,
  output logic [31:0] debug_instr,
  output logic        uart_tx,
  output logic        spi_mosi,
  output logic        spi_sck,
  output logic        spi_cs_n,
  output logic        i2c_scl,
  output logic        i2c_sda_o,
  output logic        i2c_sda_oe
);

  import moon_pkg::*;
  import axi_pkg::*;

  // Core debug signals
  assign debug_pc    = dut.u_cpu_tile.u_core.u_if_stage.pc_q;
  assign debug_instr = dut.u_cpu_tile.u_core.if_id_instr;

  // External RAM AXI4 signals
  axi_ar_t ext_ar;
  logic    ext_ar_ready;
  axi_r_t  ext_r;
  logic    ext_r_ready;

  axi_aw_t ext_aw;
  logic    ext_aw_ready;
  axi_w_t  ext_w;
  logic    ext_w_ready;
  axi_b_t  ext_b;
  logic    ext_b_ready;

  // --------------------------------------------------------------------------
  // DUT: Moon-SoC Top Integration
  // --------------------------------------------------------------------------
  moon_soc_top #(
    .HART_ID(0),
    .ROM_SIZE_BYTES(4096),
    .SRAM_SIZE_BYTES(131072),
    .ENABLE_FPU(1'b1)
  ) dut (
    .clk_i            (clk),
    .rst_ni           (rst_n),
    .uart_rx_i        (1'b1),
    .uart_tx_o        (uart_tx),
    .spi_miso_i       (1'b0),
    .spi_mosi_o       (spi_mosi),
    .spi_sck_o        (spi_sck),
    .spi_cs_no        (spi_cs_n),
    .i2c_sda_i        (1'b1),
    .i2c_scl_o        (i2c_scl),
    .i2c_sda_o        (i2c_sda_o),
    .i2c_sda_oe_o     (i2c_sda_oe),
    .ext_irq_i        ('0),
    .m_ext_ar_o       (ext_ar),
    .m_ext_ar_ready_i (ext_ar_ready),
    .m_ext_r_i        (ext_r),
    .m_ext_r_ready_o  (ext_r_ready),
    .m_ext_aw_o       (ext_aw),
    .m_ext_aw_ready_i (ext_aw_ready),
    .m_ext_w_o        (ext_w),
    .m_ext_w_ready_i  (ext_w_ready),
    .m_ext_b_i        (ext_b),
    .m_ext_b_ready_o  (ext_b_ready)
  );

  // --------------------------------------------------------------------------
  // External Simulated RAM (256 KB backing 0x8000_0000 upwards)
  // --------------------------------------------------------------------------
  localparam int RAM_BYTES = 262144; // 256 KB
  logic [7:0] ram_mem [0:RAM_BYTES-1];

  int fd, r;
  logic [31:0] word;
  int rom_idx;
  string hex_file = "tb/tests/asm/base/test_rv64_all.hex";

  initial begin
    test_passed     = 1'b0;
    test_failed     = 1'b0;
    test_error_code = 32'd0;

    for (int i = 0; i < RAM_BYTES; i++) begin
      ram_mem[i] = 8'h00;
    end
    for (int i = 0; i < 8192; i++) begin
      dut.u_mem_subsystem.u_bootrom.rom_mem[i] = 32'h0000_0013;
    end

    void'($value$plusargs("hex_file=%s", hex_file));
    fd = $fopen(hex_file, "r");
    if (fd != 0) begin
      rom_idx = 0;
      while (!$feof(fd)) begin
        r = $fscanf(fd, "%h\n", word);
        if (r == 1) begin
          if (rom_idx < 8192) begin
            dut.u_mem_subsystem.u_bootrom.rom_mem[rom_idx] = word;
          end
          if (4*rom_idx + 16'h1000 + 3 < RAM_BYTES) begin
            ram_mem[4*rom_idx + 16'h1000 + 0] = word[7:0];
            ram_mem[4*rom_idx + 16'h1000 + 1] = word[15:8];
            ram_mem[4*rom_idx + 16'h1000 + 2] = word[23:16];
            ram_mem[4*rom_idx + 16'h1000 + 3] = word[31:24];
          end
          rom_idx = rom_idx + 1;
        end
      end
      $fclose(fd);
      $display("[TB] SoC Loaded %0d firmware words into Boot ROM and RAM", rom_idx);
    end else begin
      $display("[TB ERROR] Could not open hex file: %s", hex_file);
    end
  end

  // Read Responder with AXI4 Burst Support
  typedef enum logic [1:0] {
    RAM_R_IDLE = 2'd0,
    RAM_R_RESP = 2'd1
  } ram_r_state_e;

  ram_r_state_e r_st_q, r_st_d;
  logic [AXI_ID_WIDTH-1:0]   r_id_q,   r_id_d;
  logic [AXI_ADDR_WIDTH-1:0] r_addr_q, r_addr_d;
  logic [AXI_DATA_WIDTH-1:0] r_data_q, r_data_d;
  logic [7:0]                r_len_q,  r_len_d;
  logic [7:0]                r_cnt_q,  r_cnt_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_st_q   <= RAM_R_IDLE;
      r_id_q   <= '0;
      r_addr_q <= '0;
      r_data_q <= '0;
      r_len_q  <= '0;
      r_cnt_q  <= '0;
    end else begin
      r_st_q   <= r_st_d;
      r_id_q   <= r_id_d;
      r_addr_q <= r_addr_d;
      r_data_q <= r_data_d;
      r_len_q  <= r_len_d;
      r_cnt_q  <= r_cnt_d;
    end
  end

  wire [17:0] ram_r_offset = r_addr_d[17:0];
  wire is_last_r_beat = (r_cnt_q == r_len_q);

  always_comb begin
    r_st_d       = r_st_q;
    r_id_d       = r_id_q;
    r_addr_d     = r_addr_q;
    r_data_d     = r_data_q;
    r_len_d      = r_len_q;
    r_cnt_d      = r_cnt_q;
    ext_ar_ready = 1'b0;
    ext_r        = '0;

    case (r_st_q)
      RAM_R_IDLE: begin
        ext_ar_ready = 1'b1;
        if (ext_ar.valid) begin
          r_id_d   = ext_ar.id;
          r_addr_d = ext_ar.addr;
          r_len_d  = ext_ar.len;
          r_cnt_d  = 8'd0;
          for (int b = 0; b < 8; b++) begin
            r_data_d[b*8 +: 8] = (ext_ar.addr[17:0] + b < RAM_BYTES) ? ram_mem[ext_ar.addr[17:0] + b] : 8'h0;
          end
          r_st_d = RAM_R_RESP;
        end
      end

      RAM_R_RESP: begin
        ext_r.valid = 1'b1;
        ext_r.id    = r_id_q;
        ext_r.data  = r_data_q;
        ext_r.resp  = AXI_RESP_OKAY;
        ext_r.last  = is_last_r_beat;
        if (ext_r_ready) begin
          if (is_last_r_beat) begin
            r_st_d = RAM_R_IDLE;
          end else begin
            r_cnt_d  = r_cnt_q + 8'd1;
            r_addr_d = r_addr_q + 64'd8;
            for (int b = 0; b < 8; b++) begin
              r_data_d[b*8 +: 8] = (ram_r_offset + 8 + b < RAM_BYTES) ? ram_mem[ram_r_offset + 8 + b] : 8'h0;
            end
          end
        end
      end

      default: r_st_d = RAM_R_IDLE;
    endcase
  end

  // Write Responder with AXI4 Burst Support
  typedef enum logic [1:0] {
    RAM_W_IDLE  = 2'd0,
    RAM_W_BURST = 2'd1,
    RAM_W_RESP  = 2'd2
  } ram_w_state_e;

  ram_w_state_e w_st_q, w_st_d;
  logic [AXI_ID_WIDTH-1:0]   w_id_q,   w_id_d;
  logic [AXI_ADDR_WIDTH-1:0] w_addr_q, w_addr_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_st_q   <= RAM_W_IDLE;
      w_id_q   <= '0;
      w_addr_q <= '0;
    end else begin
      w_st_q   <= w_st_d;
      w_id_q   <= w_id_d;
      w_addr_q <= w_addr_d;
    end
  end

  wire [17:0] ram_w_offset = w_addr_q[17:0];

  always_comb begin
    w_st_d       = w_st_q;
    w_id_d       = w_id_q;
    w_addr_d     = w_addr_q;
    ext_aw_ready = 1'b0;
    ext_w_ready  = 1'b0;
    ext_b        = '0;

    case (w_st_q)
      RAM_W_IDLE: begin
        ext_aw_ready = 1'b1;
        if (ext_aw.valid) begin
          w_id_d   = ext_aw.id;
          w_addr_d = ext_aw.addr;
          w_st_d   = RAM_W_BURST;
        end
      end

      RAM_W_BURST: begin
        ext_w_ready = 1'b1;
        if (ext_w.valid) begin
          w_addr_d = w_addr_q + 64'd8;
          if (ext_w.last) begin
            w_st_d = RAM_W_RESP;
          end
        end
      end

      RAM_W_RESP: begin
        ext_b.valid = 1'b1;
        ext_b.id    = w_id_q;
        ext_b.resp  = AXI_RESP_OKAY;
        if (ext_b_ready) begin
          w_st_d = RAM_W_IDLE;
        end
      end

      default: w_st_d = RAM_W_IDLE;
    endcase
  end

  // Synchronous Write Commit & Test Pass/Fail Detection
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      test_passed     <= 1'b0;
      test_failed     <= 1'b0;
      test_error_code <= 32'd0;
    end else if (w_st_q == RAM_W_BURST && ext_w.valid) begin
      for (int b = 0; b < 8; b++) begin
        if (ext_w.strb[b] && (ram_w_offset + b < RAM_BYTES)) begin
          ram_mem[ram_w_offset + b] <= ext_w.data[b*8 +: 8];
        end
      end

      // Check protocol write to 0x8000_1000 (offset 0x1000 in RAM)
      if (w_addr_q[31:0] == 32'h8000_1000) begin
        if (ext_w.data[31:0] == 32'hCAFE_BABE) begin
          test_passed     <= 1'b1;
          test_error_code <= 32'h0;
        end else begin
          test_failed     <= 1'b1;
          test_error_code <= ext_w.data[31:0];
        end
      end
    end
  end

endmodule : tb_moon_soc
