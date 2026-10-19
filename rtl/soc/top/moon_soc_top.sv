// ============================================================================
// File: rtl/soc/top/moon_soc_top.sv
// Description: Moon-SoC Top-Level System-on-Chip module organized into modern,
//              hierarchical macro partitions (Compute Tile, Cache Tile,
//              Memory Subsystem, System Fabric, Peripheral Subsystem, System
//              Control, and PHY Blocks) matching industry SoC architectures.
// ============================================================================

`ifndef MOON_SOC_TOP_SV
`define MOON_SOC_TOP_SV

`include "moon_pkg.sv"
`include "axi_pkg.sv"

`ifdef SYNTHESIS
  `define _MOON_USE_MACRO_BLACKBOX
`elsif YOSYS
  `define _MOON_USE_MACRO_BLACKBOX
`elsif USE_SYNTHESIS_BLACKBOX
  `define _MOON_USE_MACRO_BLACKBOX
`endif

`ifdef _MOON_USE_MACRO_BLACKBOX
`include "moon_soc_macros_bb.sv"
`else
`include "moon_sysctrl_subsystem.sv"
`include "moon_cpu_tile.sv"
`include "moon_cache_tile.sv"
`include "moon_mem_subsystem.sv"
`include "moon_sys_fabric.sv"
`include "moon_periph_subsystem.sv"
`endif

`include "moon_mem_phy.sv"
`include "moon_io_phy.sv"

module moon_soc_top
  import moon_pkg::*;
  import axi_pkg::*;
#(
  parameter int HART_ID          = 0,
  parameter int ROM_SIZE_BYTES   = 4096,  // 4 KB Boot ROM
  parameter int SRAM_SIZE_BYTES  = 4096,  // 4 KB On-Chip SRAM (Sky130 OpenRAM macro target)
  parameter int ICACHE_SETS      = 32,    // 32 sets x 2 ways x 64 B = 4 KB L1-I Cache
  parameter int DCACHE_SETS      = 32,    // 32 sets x 2 ways x 64 B = 4 KB L1-D Cache
  parameter int ICACHE_WAYS      = 2,
  parameter int DCACHE_WAYS      = 2,
  parameter bit ENABLE_FPU       = 1'b0,
  parameter bit ENABLE_VECTOR    = 1'b0,
  parameter bit ENABLE_VECTOR_FP = 1'b0
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

  // ==========================================================================
  // Inter-Block Interconnect Signals
  // ==========================================================================

  // Domain Clocks & Resets (from System Control Macro)
  logic clk_aon;
  logic clk_core;
  logic clk_peri;
  logic clk_mem;

  logic rst_aon_n;
  logic rst_core_n;
  logic rst_peri_n;
  logic rst_mem_n;

  // CPU <-> Cache Memory Bus
  logic            imem_req;
  logic [XLEN-1:0] imem_addr;
  logic            imem_valid;
  logic [ILEN-1:0] imem_rdata;

  logic            dmem_req;
  logic            dmem_we;
  logic [XLEN-1:0] dmem_addr;
  logic [XLEN-1:0] dmem_wdata;
  logic [7:0]      dmem_wstrb;
  logic            dmem_valid;
  logic [XLEN-1:0] dmem_rdata;

  // Cache <-> System Fabric AXI4 Masters
  axi_ar_t cache_m0_ar;
  logic    cache_m0_ar_ready;
  axi_r_t  cache_m0_r;
  logic    cache_m0_r_ready;

  axi_ar_t cache_m1_ar;
  logic    cache_m1_ar_ready;
  axi_r_t  cache_m1_r;
  logic    cache_m1_r_ready;

  axi_aw_t cache_m1_aw;
  logic    cache_m1_aw_ready;
  axi_w_t  cache_m1_w;
  logic    cache_m1_w_ready;
  axi_b_t  cache_m1_b;
  logic    cache_m1_b_ready;

  // System Fabric <-> Memory Subsystem AXI4 Slaves
  axi_ar_t fabric_s_rom_ar;
  logic    fabric_s_rom_ar_ready;
  axi_r_t  fabric_s_rom_r;
  logic    fabric_s_rom_r_ready;
  axi_aw_t fabric_s_rom_aw;
  logic    fabric_s_rom_aw_ready;
  axi_w_t  fabric_s_rom_w;
  logic    fabric_s_rom_w_ready;
  axi_b_t  fabric_s_rom_b;
  logic    fabric_s_rom_b_ready;

  axi_ar_t fabric_s_sram_ar;
  logic    fabric_s_sram_ar_ready;
  axi_r_t  fabric_s_sram_r;
  logic    fabric_s_sram_r_ready;
  axi_aw_t fabric_s_sram_aw;
  logic    fabric_s_sram_aw_ready;
  axi_w_t  fabric_s_sram_w;
  logic    fabric_s_sram_w_ready;
  axi_b_t  fabric_s_sram_b;
  logic    fabric_s_sram_b_ready;

  // System Fabric <-> Memory PHY AXI4 Slave S3
  axi_ar_t fabric_s_ext_ar;
  logic    fabric_s_ext_ar_ready;
  axi_r_t  fabric_s_ext_r;
  logic    fabric_s_ext_r_ready;
  axi_aw_t fabric_s_ext_aw;
  logic    fabric_s_ext_aw_ready;
  axi_w_t  fabric_s_ext_w;
  logic    fabric_s_ext_w_ready;
  axi_b_t  fabric_s_ext_b;
  logic    fabric_s_ext_b_ready;

  // System Fabric <-> APB Peripherals & System Control
  apb_req_t  [6:0] p_req;
  apb_resp_t [6:0] p_resp;

  // Core Interrupts & Power Handshake
  logic timer_irq;
  logic software_irq;
  logic external_irq;
  logic uart_irq;
  logic wfi_core;
  logic irq_pending_core;

  // PHY <-> Peripheral Subsystem Core Lines
  logic        core_uart_rx;
  logic        core_uart_tx;
  logic        core_spi_miso;
  logic        core_spi_mosi;
  logic        core_spi_sck;
  logic        core_spi_cs_n;
  logic        core_i2c_sda_in;
  logic        core_i2c_scl;
  logic        core_i2c_sda_out;
  logic        core_i2c_sda_oe;
  logic [30:0] core_ext_irq;

  // ==========================================================================
  // SECTION 1: System Control Macro (AON, CRG, PMU, Reset Sequencer)
  // ==========================================================================
  moon_sysctrl_subsystem u_sysctrl_subsystem (
    .ref_clk_i     (clk_i),
    .raw_rst_ni    (rst_ni),
    .crg_req_i     (p_req[3]),
    .crg_resp_o    (p_resp[3]),
    .pmu_req_i     (p_req[4]),
    .pmu_resp_o    (p_resp[4]),
    .wfi_i         (wfi_core),
    .irq_pending_i (irq_pending_core || timer_irq || software_irq || external_irq),
    .clk_aon_o     (clk_aon),
    .clk_core_o    (clk_core),
    .clk_peri_o    (clk_peri),
    .clk_mem_o     (clk_mem),
    .rst_aon_no    (rst_aon_n),
    .rst_core_no   (rst_core_n),
    .rst_peri_no   (rst_peri_n),
    .rst_mem_no    (rst_mem_n)
  );

  // ==========================================================================
  // SECTION 2: CPU Compute Tile (CPU Core Block)
  // ==========================================================================
  moon_cpu_tile #(
    .HART_ID          (HART_ID),
    .ENABLE_FPU       (ENABLE_FPU),
    .ENABLE_VECTOR    (ENABLE_VECTOR),
    .ENABLE_VECTOR_FP (ENABLE_VECTOR_FP)
  ) u_cpu_tile (
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

  // ==========================================================================
  // SECTION 3: Cache Subsystem Tile (L1 Cache Block)
  // ==========================================================================
  moon_cache_tile #(
    .ICACHE_WAYS (ICACHE_WAYS),
    .DCACHE_WAYS (DCACHE_WAYS),
    .ICACHE_SETS (ICACHE_SETS),
    .DCACHE_SETS (DCACHE_SETS)
  ) u_cache_tile (
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
    .m0_ar_o       (cache_m0_ar),
    .m0_ar_ready_i (cache_m0_ar_ready),
    .m0_r_i        (cache_m0_r),
    .m0_r_ready_o  (cache_m0_r_ready),
    .m1_ar_o       (cache_m1_ar),
    .m1_ar_ready_i (cache_m1_ar_ready),
    .m1_r_i        (cache_m1_r),
    .m1_r_ready_o  (cache_m1_r_ready),
    .m1_aw_o       (cache_m1_aw),
    .m1_aw_ready_i (cache_m1_aw_ready),
    .m1_w_o        (cache_m1_w),
    .m1_w_ready_i  (cache_m1_w_ready),
    .m1_b_i        (cache_m1_b),
    .m1_b_ready_o  (cache_m1_b_ready)
  );

  // ==========================================================================
  // SECTION 4: Memory Subsystem (Boot ROM & SRAM Block)
  // ==========================================================================
  moon_mem_subsystem #(
    .ROM_SIZE_BYTES  (ROM_SIZE_BYTES),
    .SRAM_SIZE_BYTES (SRAM_SIZE_BYTES),
    .ROM_BASE        (64'h0000_1000),
    .SRAM_BASE       (64'h7000_0000)
  ) u_mem_subsystem (
    .clk_i            (clk_mem),
    .rst_ni           (rst_mem_n),
    .s_rom_ar_i       (fabric_s_rom_ar),
    .s_rom_ar_ready_o (fabric_s_rom_ar_ready),
    .s_rom_r_o        (fabric_s_rom_r),
    .s_rom_r_ready_i  (fabric_s_rom_r_ready),
    .s_rom_aw_i       (fabric_s_rom_aw),
    .s_rom_aw_ready_o (fabric_s_rom_aw_ready),
    .s_rom_w_i        (fabric_s_rom_w),
    .s_rom_w_ready_o  (fabric_s_rom_w_ready),
    .s_rom_b_o        (fabric_s_rom_b),
    .s_rom_b_ready_i  (fabric_s_rom_b_ready),
    .s_sram_ar_i      (fabric_s_sram_ar),
    .s_sram_ar_ready_o(fabric_s_sram_ar_ready),
    .s_sram_r_o       (fabric_s_sram_r),
    .s_sram_r_ready_i (fabric_s_sram_r_ready),
    .s_sram_aw_i      (fabric_s_sram_aw),
    .s_sram_aw_ready_o(fabric_s_sram_aw_ready),
    .s_sram_w_i       (fabric_s_sram_w),
    .s_sram_w_ready_o (fabric_s_sram_w_ready),
    .s_sram_b_o       (fabric_s_sram_b),
    .s_sram_b_ready_i (fabric_s_sram_b_ready)
  );

  // ==========================================================================
  // SECTION 5: System Interconnect Fabric (Uncore / Bus Crossbar Block)
  // ==========================================================================
  moon_sys_fabric u_sys_fabric (
    .clk_i            (clk_core),
    .rst_ni           (rst_core_n),
    .m0_ar_i          (cache_m0_ar),
    .m0_ar_ready_o    (cache_m0_ar_ready),
    .m0_r_o           (cache_m0_r),
    .m0_r_ready_i     (cache_m0_r_ready),
    .m1_ar_i          (cache_m1_ar),
    .m1_ar_ready_o    (cache_m1_ar_ready),
    .m1_r_o           (cache_m1_r),
    .m1_r_ready_i     (cache_m1_r_ready),
    .m1_aw_i          (cache_m1_aw),
    .m1_aw_ready_o    (cache_m1_aw_ready),
    .m1_w_i           (cache_m1_w),
    .m1_w_ready_o     (cache_m1_w_ready),
    .m1_b_o           (cache_m1_b),
    .m1_b_ready_i     (cache_m1_b_ready),
    .s_rom_ar_o       (fabric_s_rom_ar),
    .s_rom_ar_ready_i (fabric_s_rom_ar_ready),
    .s_rom_r_i        (fabric_s_rom_r),
    .s_rom_r_ready_o  (fabric_s_rom_r_ready),
    .s_rom_aw_o       (fabric_s_rom_aw),
    .s_rom_aw_ready_i (fabric_s_rom_aw_ready),
    .s_rom_w_o        (fabric_s_rom_w),
    .s_rom_w_ready_i  (fabric_s_rom_w_ready),
    .s_rom_b_i        (fabric_s_rom_b),
    .s_rom_b_ready_o  (fabric_s_rom_b_ready),
    .s_sram_ar_o      (fabric_s_sram_ar),
    .s_sram_ar_ready_i(fabric_s_sram_ar_ready),
    .s_sram_r_i       (fabric_s_sram_r),
    .s_sram_r_ready_o (fabric_s_sram_r_ready),
    .s_sram_aw_o      (fabric_s_sram_aw),
    .s_sram_aw_ready_i(fabric_s_sram_aw_ready),
    .s_sram_w_o       (fabric_s_sram_w),
    .s_sram_w_ready_i (fabric_s_sram_w_ready),
    .s_sram_b_i       (fabric_s_sram_b),
    .s_sram_b_ready_o (fabric_s_sram_b_ready),
    .s_ext_ar_o       (fabric_s_ext_ar),
    .s_ext_ar_ready_i (fabric_s_ext_ar_ready),
    .s_ext_r_i        (fabric_s_ext_r),
    .s_ext_r_ready_o  (fabric_s_ext_r_ready),
    .s_ext_aw_o       (fabric_s_ext_aw),
    .s_ext_aw_ready_i (fabric_s_ext_aw_ready),
    .s_ext_w_o        (fabric_s_ext_w),
    .s_ext_w_ready_i  (fabric_s_ext_w_ready),
    .s_ext_b_i        (fabric_s_ext_b),
    .s_ext_b_ready_o  (fabric_s_ext_b_ready),
    .p_req_o          (p_req),
    .p_resp_i         (p_resp)
  );

  // ==========================================================================
  // SECTION 6: Peripheral Subsystem (Southbridge / Low-Speed I/O Block)
  // ==========================================================================
  moon_periph_subsystem u_periph_subsystem (
    .clk_i          (clk_peri),
    .rst_ni         (rst_peri_n),
    .clint_req_i    (p_req[0]),
    .clint_resp_o   (p_resp[0]),
    .plic_req_i     (p_req[1]),
    .plic_resp_o    (p_resp[1]),
    .uart_req_i     (p_req[2]),
    .uart_resp_o    (p_resp[2]),
    .spi_req_i      (p_req[5]),
    .spi_resp_o     (p_resp[5]),
    .i2c_req_i      (p_req[6]),
    .i2c_resp_o     (p_resp[6]),
    .uart_rx_i      (core_uart_rx),
    .uart_tx_o      (core_uart_tx),
    .spi_miso_i     (core_spi_miso),
    .spi_mosi_o     (core_spi_mosi),
    .spi_sck_o      (core_spi_sck),
    .spi_cs_no      (core_spi_cs_n),
    .i2c_sda_i      (core_i2c_sda_in),
    .i2c_scl_o      (core_i2c_scl),
    .i2c_sda_o      (core_i2c_sda_out),
    .i2c_sda_oe_o   (core_i2c_sda_oe),
    .ext_irq_i      (core_ext_irq),
    .timer_irq_o    (timer_irq),
    .software_irq_o (software_irq),
    .external_irq_o (external_irq),
    .uart_irq_o     (uart_irq)
  );

  // ==========================================================================
  // SECTION 7: External Memory Interface PHY Block
  // ==========================================================================
  moon_mem_phy u_mem_phy (
    .clk_i               (clk_mem),
    .rst_ni              (rst_mem_n),
    .s_fabric_ar_i       (fabric_s_ext_ar),
    .s_fabric_ar_ready_o (fabric_s_ext_ar_ready),
    .s_fabric_r_o        (fabric_s_ext_r),
    .s_fabric_r_ready_i  (fabric_s_ext_r_ready),
    .s_fabric_aw_i       (fabric_s_ext_aw),
    .s_fabric_aw_ready_o (fabric_s_ext_aw_ready),
    .s_fabric_w_i        (fabric_s_ext_w),
    .s_fabric_w_ready_o  (fabric_s_ext_w_ready),
    .s_fabric_b_o        (fabric_s_ext_b),
    .s_fabric_b_ready_i  (fabric_s_ext_b_ready),
    .m_ext_ar_o          (m_ext_ar_o),
    .m_ext_ar_ready_i    (m_ext_ar_ready_i),
    .m_ext_r_i           (m_ext_r_i),
    .m_ext_r_ready_o     (m_ext_r_ready_o),
    .m_ext_aw_o          (m_ext_aw_o),
    .m_ext_aw_ready_i    (m_ext_aw_ready_i),
    .m_ext_w_o           (m_ext_w_o),
    .m_ext_w_ready_i     (m_ext_w_ready_i),
    .m_ext_b_i           (m_ext_b_i),
    .m_ext_b_ready_o     (m_ext_b_ready_o)
  );

  // ==========================================================================
  // SECTION 8: Peripheral I/O PHY & Pad Ring Block
  // ==========================================================================
  moon_io_phy #(
    .ENABLE_INPUT_SYNC   (1'b0)
  ) u_io_phy (
    .clk_i               (clk_peri),
    .rst_ni              (rst_peri_n),
    .core_uart_rx_o      (core_uart_rx),
    .core_uart_tx_i      (core_uart_tx),
    .core_spi_miso_o     (core_spi_miso),
    .core_spi_mosi_i     (core_spi_mosi),
    .core_spi_sck_i      (core_spi_sck),
    .core_spi_cs_ni      (core_spi_cs_n),
    .core_i2c_sda_o      (core_i2c_sda_in),
    .core_i2c_scl_i      (core_i2c_scl),
    .core_i2c_sda_i      (core_i2c_sda_out),
    .core_i2c_sda_oe_i   (core_i2c_sda_oe),
    .core_ext_irq_o      (core_ext_irq),
    .pad_uart_rx_i       (uart_rx_i),
    .pad_uart_tx_o       (uart_tx_o),
    .pad_spi_miso_i      (spi_miso_i),
    .pad_spi_mosi_o      (spi_mosi_o),
    .pad_spi_sck_o       (spi_sck_o),
    .pad_spi_cs_no       (spi_cs_no),
    .pad_i2c_sda_i       (i2c_sda_i),
    .pad_i2c_scl_o       (i2c_scl_o),
    .pad_i2c_sda_o       (i2c_sda_o),
    .pad_i2c_sda_oe_o    (i2c_sda_oe_o),
    .pad_ext_irq_i       (ext_irq_i)
  );

endmodule : moon_soc_top

`endif // MOON_SOC_TOP_SV
