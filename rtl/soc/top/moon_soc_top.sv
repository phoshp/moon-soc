// ============================================================================
// File: rtl/soc/top/moon_soc_top.sv
// Description: Moon-SoC Top-Level System-on-Chip module integrating moon_core,
//              64-bit AXI4 crossbar, AXI-to-APB bridge, Boot ROM, On-Chip SRAM,
//              CLINT, PLIC, UART 16550, and external memory AXI interface.
// ============================================================================

`ifndef MOON_SOC_TOP_SV
`define MOON_SOC_TOP_SV

`include "moon_pkg.sv"
`include "axi_pkg.sv"
`include "moon_core.sv"
`include "moon_l1_cache_subsystem.sv"
`include "axi_crossbar.sv"
`include "axi_to_apb_bridge.sv"
`include "apb_crossbar.sv"
`include "moon_bootrom.sv"
`include "moon_sram_ctrl.sv"
`include "moon_clint.sv"
`include "moon_plic.sv"
`include "moon_uart.sv"
`include "moon_crg.sv"
`include "moon_reset_ctrl.sv"
`include "moon_pmu.sv"
`include "moon_spi.sv"
`include "moon_i2c.sv"

module moon_soc_top
  import moon_pkg::*;
  import axi_pkg::*;
#(
  parameter int HART_ID = 0,
  parameter int ROM_SIZE_BYTES  = 32768,  // 32 KB Boot ROM
  parameter int SRAM_SIZE_BYTES = 131072, // 128 KB On-Chip SRAM
  parameter int ICACHE_SETS     = 128,
  parameter int DCACHE_SETS     = 128,
  parameter int ICACHE_WAYS     = 4,
  parameter int DCACHE_WAYS     = 4,
  parameter bit ENABLE_FPU       = 1'b1,
  parameter bit ENABLE_VECTOR_FP = 1'b1
)(
  input  logic clk_i,
  input  logic rst_ni,

  // External UART Console Pins
  input  logic uart_rx_i,
  output logic uart_tx_o,
  input  logic spi_miso_i,
  output logic spi_mosi_o,
  output logic spi_sck_o,
  output logic spi_cs_no,
  input  logic i2c_sda_i,
  output logic i2c_scl_o,
  output logic i2c_sda_o,
  output logic i2c_sda_oe_o,

  // External Interrupt Inputs (from external board pins)
  input  logic [30:0] ext_irq_i,

  // --------------------------------------------------------------------------
  // External Main Memory AXI4 Interface (to DRAM / HyperRAM controller)
  // --------------------------------------------------------------------------
  output axi_ar_t m_ext_ar_o,
  input  logic    m_ext_ar_ready_i,
  input  axi_r_t  m_ext_r_i,
  output logic    m_ext_r_ready_o,

  output axi_aw_t m_ext_aw_o,
  input  logic    m_ext_aw_ready_i,
  output axi_w_t  m_ext_w_o,
  input  logic    m_ext_w_ready_i,
  input  axi_b_t  m_ext_b_i,
  output logic    m_ext_b_ready_o
);

  // --------------------------------------------------------------------------
  // Internal Interrupt Signals
  // --------------------------------------------------------------------------
  logic timer_irq;
  logic software_irq;
  logic external_irq;
  logic uart_irq;

  // --------------------------------------------------------------------------
  // Domain Clocks & Resets
  // --------------------------------------------------------------------------
  logic clk_aon;
  logic clk_core;
  logic clk_peri;
  logic clk_mem;

  logic rst_aon_n;
  logic rst_core_n;
  logic rst_peri_n;
  logic rst_mem_n;

  // --------------------------------------------------------------------------
  // PMU & CRG Signals
  // --------------------------------------------------------------------------
  logic core_clk_gate_req;
  logic peri_clk_gate_req;
  logic pll_pwr_down_req;
  logic sw_rst_req;
  logic wfi_core;
  logic irq_pending_core;

  // --------------------------------------------------------------------------
  // Core Memory Signals
  // --------------------------------------------------------------------------
  logic             imem_req;
  logic [XLEN-1:0]  imem_addr;
  logic             imem_valid;
  logic [ILEN-1:0]  imem_rdata;

  logic             dmem_req;
  logic             dmem_we;
  logic [XLEN-1:0]  dmem_addr;
  logic [XLEN-1:0]  dmem_wdata;
  logic [7:0]       dmem_wstrb;
  logic             dmem_valid;
  logic [XLEN-1:0]  dmem_rdata;

  // --------------------------------------------------------------------------
  // 0. Reset Controller & Sequencer
  // --------------------------------------------------------------------------
  moon_reset_ctrl u_reset_ctrl (
    .clk_aon_i     (clk_aon),
    .raw_rst_ni    (rst_ni),
    .sw_rst_req_i  (sw_rst_req),
    .wdt_rst_req_i (1'b0),
    .rst_aon_no    (rst_aon_n),
    .rst_core_no   (rst_core_n),
    .rst_peri_no   (rst_peri_n),
    .rst_mem_no    (rst_mem_n)
  );

  // --------------------------------------------------------------------------
  // 1. CPU Core Instantiation
  // --------------------------------------------------------------------------
  moon_core #(
    .HART_ID(HART_ID),
    .ENABLE_FPU(ENABLE_FPU),
    .ENABLE_VECTOR_FP(ENABLE_VECTOR_FP)
  ) u_core (
    .clk_i               (clk_core),
    .rst_ni              (rst_core_n),
    .imem_req_o          (imem_req),
    .imem_addr_o         (imem_addr),
    .imem_valid_i        (imem_valid),
    .imem_rdata_i        (imem_rdata),
    .dmem_req_o          (dmem_req),
    .dmem_we_o           (dmem_we),
    .dmem_addr_o         (dmem_addr),
    .dmem_wdata_o        (dmem_wdata),
    .dmem_wstrb_o        (dmem_wstrb),
    .dmem_valid_i        (dmem_valid),
    .dmem_rdata_i        (dmem_rdata),
    .timer_irq_i         (timer_irq),
    .software_irq_i      (software_irq),
    .external_irq_i      (external_irq),
    .inv_valid_i         (1'b0),
    .inv_addr_i          ('0),
    .wfi_o               (wfi_core),
    .interrupt_pending_o (irq_pending_core)
  );

  // --------------------------------------------------------------------------
  // 2. L1 Cache Subsystem (32 KB L1-I & 32 KB L1-D) with AXI4 Masters
  // --------------------------------------------------------------------------
  axi_ar_t [1:0] core_ar;
  logic    [1:0] core_ar_ready;
  axi_r_t  [1:0] core_r;
  logic    [1:0] core_r_ready;

  axi_aw_t [1:0] core_aw;
  logic    [1:0] core_aw_ready;
  axi_w_t  [1:0] core_w;
  logic    [1:0] core_w_ready;
  axi_b_t  [1:0] core_b;
  logic    [1:0] core_b_ready;

  moon_l1_cache_subsystem #(
    .ICACHE_WAYS (ICACHE_WAYS),
    .DCACHE_WAYS (DCACHE_WAYS),
    .ICACHE_SETS (ICACHE_SETS),
    .DCACHE_SETS (DCACHE_SETS)
  ) u_l1_cache (
    .clk_i         (clk_core),
    .rst_ni        (rst_core_n),
    .imem_req_i    (imem_req),
    .imem_addr_i   (imem_addr),
    .imem_valid_o  (imem_valid),
    .imem_rdata_o  (imem_rdata),
    .fence_i_i     (1'b0),
    .dmem_req_i    (dmem_req),
    .dmem_we_i     (dmem_we),
    .dmem_addr_i   (dmem_addr),
    .dmem_wdata_i  (dmem_wdata),
    .dmem_wstrb_i  (dmem_wstrb),
    .dmem_valid_o  (dmem_valid),
    .dmem_rdata_o  (dmem_rdata),
    .cbo_inval_i   (1'b0),
    .cbo_clean_i   (1'b0),
    .cbo_flush_i   (1'b0),
    .cbo_zero_i    (1'b0),
    .m0_ar_o       (core_ar[0]),
    .m0_ar_ready_i (core_ar_ready[0]),
    .m0_r_i        (core_r[0]),
    .m0_r_ready_o  (core_r_ready[0]),
    .m1_ar_o       (core_ar[1]),
    .m1_ar_ready_i (core_ar_ready[1]),
    .m1_r_i        (core_r[1]),
    .m1_r_ready_o  (core_r_ready[1]),
    .m1_aw_o       (core_aw[1]),
    .m1_aw_ready_i (core_aw_ready[1]),
    .m1_w_o        (core_w[1]),
    .m1_w_ready_i  (core_w_ready[1]),
    .m1_b_i        (core_b[1]),
    .m1_b_ready_o  (core_b_ready[1])
  );

  always_comb begin
    core_aw[0] = '0;
    core_w[0]  = '0;
  end

  // --------------------------------------------------------------------------
  // 3. AXI4 System Crossbar
  // --------------------------------------------------------------------------
  // S0: Boot ROM, S1: SRAM, S2: APB Bridge, S3: External Main Memory
  axi_ar_t [3:0] s_ar;
  logic    [3:0] s_ar_ready;
  axi_r_t  [3:0] s_r;
  logic    [3:0] s_r_ready;

  axi_aw_t [3:0] s_aw;
  logic    [3:0] s_aw_ready;
  axi_w_t  [3:0] s_w;
  logic    [3:0] s_w_ready;
  axi_b_t  [3:0] s_b;
  logic    [3:0] s_b_ready;

  axi_crossbar #(
    .NUM_MASTERS(2),
    .NUM_SLAVES(4)
  ) u_axi_crossbar (
    .clk_i        (clk_core),
    .rst_ni       (rst_core_n),
    .m_ar_i       (core_ar),
    .m_ar_ready_o (core_ar_ready),
    .m_r_o        (core_r),
    .m_r_ready_i  (core_r_ready),
    .m_aw_i       (core_aw),
    .m_aw_ready_o (core_aw_ready),
    .m_w_i        (core_w),
    .m_w_ready_o  (core_w_ready),
    .m_b_o        (core_b),
    .m_b_ready_i  (core_b_ready),
    .s_ar_o       (s_ar),
    .s_ar_ready_i (s_ar_ready),
    .s_r_i        (s_r),
    .s_r_ready_o  (s_r_ready),
    .s_aw_o       (s_aw),
    .s_aw_ready_i (s_aw_ready),
    .s_w_o        (s_w),
    .s_w_ready_i  (s_w_ready),
    .s_b_i        (s_b),
    .s_b_ready_o  (s_b_ready)
  );

  // --------------------------------------------------------------------------
  // 4. S0: Boot ROM (0x0000_1000 - 0x0000_8FFF)
  // --------------------------------------------------------------------------
  moon_bootrom #(
    .ROM_SIZE_BYTES(ROM_SIZE_BYTES),
    .BASE_ADDR(64'h0000_1000)
  ) u_bootrom (
    .clk_i        (clk_mem),
    .rst_ni       (rst_mem_n),
    .s_ar_i       (s_ar[0]),
    .s_ar_ready_o (s_ar_ready[0]),
    .s_r_o        (s_r[0]),
    .s_r_ready_i  (s_r_ready[0]),
    .s_aw_i       (s_aw[0]),
    .s_aw_ready_o (s_aw_ready[0]),
    .s_w_i        (s_w[0]),
    .s_w_ready_o  (s_w_ready[0]),
    .s_b_o        (s_b[0]),
    .s_b_ready_i  (s_b_ready[0])
  );

  // --------------------------------------------------------------------------
  // 5. S1: On-Chip SRAM (0x7000_0000 - 0x7001_FFFF)
  // --------------------------------------------------------------------------
  moon_sram_ctrl #(
    .SRAM_SIZE_BYTES(SRAM_SIZE_BYTES),
    .BASE_ADDR(64'h7000_0000)
  ) u_sram (
    .clk_i        (clk_mem),
    .rst_ni       (rst_mem_n),
    .s_ar_i       (s_ar[1]),
    .s_ar_ready_o (s_ar_ready[1]),
    .s_r_o        (s_r[1]),
    .s_r_ready_i  (s_r_ready[1]),
    .s_aw_i       (s_aw[1]),
    .s_aw_ready_o (s_aw_ready[1]),
    .s_w_i        (s_w[1]),
    .s_w_ready_o  (s_w_ready[1]),
    .s_b_o        (s_b[1]),
    .s_b_ready_i  (s_b_ready[1])
  );

  // --------------------------------------------------------------------------
  // 6. S2: AXI-to-APB Bridge & APB Crossbar
  // --------------------------------------------------------------------------
  apb_req_t  bridge_apb_req;
  apb_resp_t bridge_apb_resp;

  axi_to_apb_bridge u_axi_to_apb (
    .clk_i        (clk_peri),
    .rst_ni       (rst_peri_n),
    .s_ar_i       (s_ar[2]),
    .s_ar_ready_o (s_ar_ready[2]),
    .s_r_o        (s_r[2]),
    .s_r_ready_i  (s_r_ready[2]),
    .s_aw_i       (s_aw[2]),
    .s_aw_ready_o (s_aw_ready[2]),
    .s_w_i        (s_w[2]),
    .s_w_ready_o  (s_w_ready[2]),
    .s_b_o        (s_b[2]),
    .s_b_ready_i  (s_b_ready[2]),
    .apb_req_o    (bridge_apb_req),
    .apb_resp_i   (bridge_apb_resp)
  );

  // APB Peripherals: CLINT, PLIC, UART, CRG, PMU, SPI, I2C
  apb_req_t  [6:0] p_req;
  apb_resp_t [6:0] p_resp;

  apb_crossbar #(
    .NUM_PERIPHS(7)
  ) u_apb_crossbar (
    .m_req_i  (bridge_apb_req),
    .m_resp_o (bridge_apb_resp),
    .p_req_o  (p_req),
    .p_resp_i (p_resp)
  );

  // P0: CLINT (0x0200_0000)
  moon_clint u_clint (
    .clk_i          (clk_peri),
    .rst_ni         (rst_peri_n),
    .req_i          (p_req[0]),
    .resp_o         (p_resp[0]),
    .timer_irq_o    (timer_irq),
    .software_irq_o (software_irq)
  );

  // P1: PLIC (0x0C00_0000)
  wire [31:1] plic_irq_sources = {ext_irq_i, uart_irq};

  moon_plic #(
    .NUM_SOURCES(31)
  ) u_plic (
    .clk_i          (clk_peri),
    .rst_ni         (rst_peri_n),
    .req_i          (p_req[1]),
    .resp_o         (p_resp[1]),
    .irq_sources_i  (plic_irq_sources),
    .external_irq_o (external_irq)
  );

  // P2: UART 16550 (0x1000_0000)
  moon_uart u_uart (
    .clk_i      (clk_peri),
    .rst_ni     (rst_peri_n),
    .req_i      (p_req[2]),
    .resp_o     (p_resp[2]),
    .uart_rx_i  (uart_rx_i),
    .uart_tx_o  (uart_tx_o),
    .uart_irq_o (uart_irq)
  );

  // P3: CRG (0x1000_5000)
  moon_crg u_crg (
    .ref_clk_i       (clk_i),
    .rst_aon_ni      (rst_aon_n),
    .req_i           (p_req[3]),
    .resp_o          (p_resp[3]),
    .core_clk_gate_i (core_clk_gate_req),
    .peri_clk_gate_i (peri_clk_gate_req),
    .pll_pwr_down_i  (pll_pwr_down_req),
    .clk_aon_o       (clk_aon),
    .clk_core_o      (clk_core),
    .clk_peri_o      (clk_peri),
    .clk_mem_o       (clk_mem),
    .sw_rst_req_o    (sw_rst_req)
  );

  // P4: PMU (0x1000_5080)
  moon_pmu u_pmu (
    .clk_aon_i           (clk_aon),
    .rst_aon_ni          (rst_aon_n),
    .req_i               (p_req[4]),
    .resp_o              (p_resp[4]),
    .wfi_i               (wfi_core),
    .irq_pending_i       (irq_pending_core || timer_irq || software_irq || external_irq),
    .core_clk_gate_req_o (core_clk_gate_req),
    .peri_clk_gate_req_o (peri_clk_gate_req),
    .pll_pwr_down_req_o  (pll_pwr_down_req),
    .current_state_o     ()
  );

  // P5: SPI master (0x1000_6000)
  moon_spi u_spi (
    .clk_i(clk_peri), .rst_ni(rst_peri_n), .req_i(p_req[5]), .resp_o(p_resp[5]),
    .miso_i(spi_miso_i), .mosi_o(spi_mosi_o), .sck_o(spi_sck_o), .cs_no(spi_cs_no)
  );

  // P6: I2C master (0x1000_7000); sda_oe_o requests open-drain low.
  moon_i2c u_i2c (
    .clk_i(clk_peri), .rst_ni(rst_peri_n), .req_i(p_req[6]), .resp_o(p_resp[6]),
    .sda_i(i2c_sda_i), .scl_o(i2c_scl_o), .sda_o(i2c_sda_o), .sda_oe_o(i2c_sda_oe_o)
  );

  // --------------------------------------------------------------------------
  // 7. S3: External Main Memory Port Pass-Through
  // --------------------------------------------------------------------------
  assign m_ext_ar_o       = s_ar[3];
  assign s_ar_ready[3]    = m_ext_ar_ready_i;
  assign s_r[3]           = m_ext_r_i;
  assign m_ext_r_ready_o  = s_r_ready[3];

  assign m_ext_aw_o       = s_aw[3];
  assign s_aw_ready[3]    = m_ext_aw_ready_i;
  assign m_ext_w_o        = s_w[3];
  assign s_w_ready[3]     = m_ext_w_ready_i;
  assign s_b[3]           = m_ext_b_i;
  assign m_ext_b_ready_o  = s_b_ready[3];

endmodule : moon_soc_top

`endif // MOON_SOC_TOP_SV
