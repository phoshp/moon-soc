// ============================================================================
// File: synth/macros/blackbox/moon_soc_macros_bb.sv
// Description: Blackbox stubs for Yosys and LibreLane hierarchical synthesis.
//              Used during top-level moon_soc_top synthesis to treat hardened
//              subsystems as physical macros without flattening their gate logic.
// ============================================================================

`ifndef MOON_SOC_MACROS_BB_SV
`define MOON_SOC_MACROS_BB_SV

`include "moon_pkg.sv"
`include "axi_pkg.sv"

// ----------------------------------------------------------------------------
// Macro 1: CPU Compute Tile
// ----------------------------------------------------------------------------
(* blackbox *)
module moon_cpu_tile
  import moon_pkg::*;
#(
  parameter int HART_ID          = 0,
  parameter bit ENABLE_FPU       = 1'b0,
  parameter bit ENABLE_VECTOR    = 1'b0,
  parameter bit ENABLE_VECTOR_FP = 1'b0
)(
  input  logic             clk_i,
  input  logic             rst_ni,

  output logic             imem_req_o,
  output logic [XLEN-1:0]  imem_addr_o,
  input  logic             imem_valid_i,
  input  logic [ILEN-1:0]  imem_rdata_i,

  output logic             dmem_req_o,
  output logic             dmem_we_o,
  output logic [XLEN-1:0]  dmem_addr_o,
  output logic [XLEN-1:0]  dmem_wdata_o,
  output logic [7:0]       dmem_wstrb_o,
  input  logic             dmem_valid_i,
  input  logic [XLEN-1:0]  dmem_rdata_i,

  input  logic             timer_irq_i,
  input  logic             software_irq_i,
  input  logic             external_irq_i,

  input  logic             inv_valid_i,
  input  logic [XLEN-1:0]  inv_addr_i,

  output logic             wfi_o,
  output logic             interrupt_pending_o
);
endmodule

// ----------------------------------------------------------------------------
// Macro 2: L1 Cache Subsystem Tile
// ----------------------------------------------------------------------------
(* blackbox *)
module moon_cache_tile
  import moon_pkg::*;
  import axi_pkg::*;
#(
  parameter int ICACHE_WAYS = 2,
  parameter int DCACHE_WAYS = 2,
  parameter int ICACHE_SETS = 32,
  parameter int DCACHE_SETS = 32,
  parameter int LINE_BYTES  = 64
)(
  input  logic clk_i,
  input  logic rst_ni,

  input  logic             imem_req_i,
  input  logic [XLEN-1:0]  imem_addr_i,
  output logic             imem_valid_o,
  output logic [ILEN-1:0]  imem_rdata_o,
  input  logic             fence_i_i,

  input  logic             dmem_req_i,
  input  logic             dmem_we_i,
  input  logic [XLEN-1:0]  dmem_addr_i,
  input  logic [XLEN-1:0]  dmem_wdata_i,
  input  logic [7:0]       dmem_wstrb_i,
  output logic             dmem_valid_o,
  output logic [XLEN-1:0]  dmem_rdata_o,

  input  logic             cbo_inval_i,
  input  logic             cbo_clean_i,
  input  logic             cbo_flush_i,
  input  logic             cbo_zero_i,

  output axi_ar_t          m0_ar_o,
  input  logic             m0_ar_ready_i,
  input  axi_r_t           m0_r_i,
  output logic             m0_r_ready_o,

  output axi_ar_t          m1_ar_o,
  input  logic             m1_ar_ready_i,
  input  axi_r_t           m1_r_i,
  output logic             m1_r_ready_o,

  output axi_aw_t          m1_aw_o,
  input  logic             m1_aw_ready_i,
  output axi_w_t           m1_w_o,
  input  logic             m1_w_ready_i,
  input  axi_b_t           m1_b_i,
  output logic             m1_b_ready_o
);
endmodule

// ----------------------------------------------------------------------------
// Macro 3: On-Chip Memory Subsystem (Boot ROM & SRAM)
// ----------------------------------------------------------------------------
(* blackbox *)
module moon_mem_subsystem
  import axi_pkg::*;
#(
  parameter int ROM_SIZE_BYTES                   = 4096,
  parameter int SRAM_SIZE_BYTES                  = 4096,
  parameter logic [AXI_ADDR_WIDTH-1:0] ROM_BASE  = 64'h0000_1000,
  parameter logic [AXI_ADDR_WIDTH-1:0] SRAM_BASE = 64'h7000_0000
)(
  input  logic clk_i,
  input  logic rst_ni,

  input  axi_ar_t s_rom_ar_i,
  output logic    s_rom_ar_ready_o,
  output axi_r_t  s_rom_r_o,
  input  logic    s_rom_r_ready_i,

  input  axi_aw_t s_rom_aw_i,
  output logic    s_rom_aw_ready_o,
  input  axi_w_t  s_rom_w_i,
  output logic    s_rom_w_ready_o,
  output axi_b_t  s_rom_b_o,
  input  logic    s_rom_b_ready_i,

  input  axi_ar_t s_sram_ar_i,
  output logic    s_sram_ar_ready_o,
  output axi_r_t  s_sram_r_o,
  input  logic    s_sram_r_ready_i,

  input  axi_aw_t s_sram_aw_i,
  output logic    s_sram_aw_ready_o,
  input  axi_w_t  s_sram_w_i,
  output logic    s_sram_w_ready_o,
  output axi_b_t  s_sram_b_o,
  input  logic    s_sram_b_ready_i
);
endmodule

// ----------------------------------------------------------------------------
// Macro 4: System Interconnect Fabric
// ----------------------------------------------------------------------------
(* blackbox *)
module moon_sys_fabric
  import axi_pkg::*;
(
  input  logic clk_i,
  input  logic rst_ni,

  input  axi_ar_t m0_ar_i,
  output logic    m0_ar_ready_o,
  output axi_r_t  m0_r_o,
  input  logic    m0_r_ready_i,

  input  axi_ar_t m1_ar_i,
  output logic    m1_ar_ready_o,
  output axi_r_t  m1_r_o,
  input  logic    m1_r_ready_i,

  input  axi_aw_t m1_aw_i,
  output logic    m1_aw_ready_o,
  input  axi_w_t  m1_w_i,
  output logic    m1_w_ready_o,
  output axi_b_t  m1_b_o,
  input  logic    m1_b_ready_i,

  output axi_ar_t s_rom_ar_o,
  input  logic    s_rom_ar_ready_i,
  input  axi_r_t  s_rom_r_i,
  output logic    s_rom_r_ready_o,

  output axi_aw_t s_rom_aw_o,
  input  logic    s_rom_aw_ready_i,
  output axi_w_t  s_rom_w_o,
  input  logic    s_rom_w_ready_i,
  input  axi_b_t  s_rom_b_i,
  output logic    s_rom_b_ready_o,

  output axi_ar_t s_sram_ar_o,
  input  logic    s_sram_ar_ready_i,
  input  axi_r_t  s_sram_r_i,
  output logic    s_sram_r_ready_o,

  output axi_aw_t s_sram_aw_o,
  input  logic    s_sram_aw_ready_i,
  output axi_w_t  s_sram_w_o,
  input  logic    s_sram_w_ready_i,
  input  axi_b_t  s_sram_b_i,
  output logic    s_sram_b_ready_o,

  output axi_ar_t s_ext_ar_o,
  input  logic    s_ext_ar_ready_i,
  input  axi_r_t  s_ext_r_i,
  output logic    s_ext_r_ready_o,

  output axi_aw_t s_ext_aw_o,
  input  logic    s_ext_aw_ready_i,
  output axi_w_t  s_ext_w_o,
  input  logic    s_ext_w_ready_i,
  input  axi_b_t  s_ext_b_i,
  output logic    s_ext_b_ready_o,

  output apb_req_t  [6:0] p_req_o,
  input  apb_resp_t [6:0] p_resp_i
);
endmodule

// ----------------------------------------------------------------------------
// Macro 5: Peripheral Subsystem Block
// ----------------------------------------------------------------------------
(* blackbox *)
module moon_periph_subsystem
  import axi_pkg::*;
(
  input  logic clk_i,
  input  logic rst_ni,

  input  apb_req_t  clint_req_i,
  output apb_resp_t clint_resp_o,

  input  apb_req_t  plic_req_i,
  output apb_resp_t plic_resp_o,

  input  apb_req_t  uart_req_i,
  output apb_resp_t uart_resp_o,

  input  apb_req_t  spi_req_i,
  output apb_resp_t spi_resp_o,

  input  apb_req_t  i2c_req_i,
  output apb_resp_t i2c_resp_o,

  input  logic        uart_rx_i,
  output logic        uart_tx_o,

  input  logic        spi_miso_i,
  output logic        spi_mosi_o,
  output logic        spi_sck_o,
  output logic        spi_cs_no,

  input  logic        i2c_sda_i,
  output logic        i2c_scl_o,
  output logic        i2c_sda_o,
  output logic        i2c_sda_oe_o,

  input  logic [30:0] ext_irq_i,

  output logic        timer_irq_o,
  output logic        software_irq_o,
  output logic        external_irq_o,
  output logic        uart_irq_o
);
endmodule

// ----------------------------------------------------------------------------
// Macro 6: System Control Subsystem Block (AON / Power & Clock)
// ----------------------------------------------------------------------------
(* blackbox *)
module moon_sysctrl_subsystem
  import axi_pkg::*;
(
  input  logic ref_clk_i,
  input  logic raw_rst_ni,

  input  apb_req_t  crg_req_i,
  output apb_resp_t crg_resp_o,

  input  apb_req_t  pmu_req_i,
  output apb_resp_t pmu_resp_o,

  input  logic wfi_i,
  input  logic irq_pending_i,

  output logic clk_aon_o,
  output logic clk_core_o,
  output logic clk_peri_o,
  output logic clk_mem_o,

  output logic rst_aon_no,
  output logic rst_core_no,
  output logic rst_peri_no,
  output logic rst_mem_no
);
endmodule

`endif // MOON_SOC_MACROS_BB_SV
