// ============================================================================
// File: rtl/core/cache/moon_l1_cache_subsystem.sv
// Description: Integrated L1 Cache Subsystem wrapping 32 KB L1-I Cache and
//              32 KB L1-D Cache, interfacing moon_core directly to 64-bit AXI4.
// ============================================================================

`ifndef MOON_L1_CACHE_SUBSYSTEM_SV
`define MOON_L1_CACHE_SUBSYSTEM_SV

`include "moon_pkg.sv"
`include "axi_pkg.sv"
`include "moon_icache.sv"
`include "moon_dcache.sv"

module moon_l1_cache_subsystem
  import moon_pkg::*;
  import axi_pkg::*;
#(
  parameter int ICACHE_WAYS = 4,
  parameter int DCACHE_WAYS = 4,
  parameter int ICACHE_SETS = 128,
  parameter int DCACHE_SETS = 128,
  parameter int LINE_BYTES  = 64
)(
  input  logic clk_i,
  input  logic rst_ni,

  // --------------------------------------------------------------------------
  // Core Instruction Fetch Interface
  // --------------------------------------------------------------------------
  input  logic             imem_req_i,
  input  logic [XLEN-1:0]  imem_addr_i,
  output logic             imem_valid_o,
  output logic [ILEN-1:0]  imem_rdata_o,
  input  logic             fence_i_i,

  // --------------------------------------------------------------------------
  // Core Data Memory Interface
  // --------------------------------------------------------------------------
  input  logic             dmem_req_i,
  input  logic             dmem_we_i,
  input  logic [XLEN-1:0]  dmem_addr_i,
  input  logic [XLEN-1:0]  dmem_wdata_i,
  input  logic [7:0]       dmem_wstrb_i,
  output logic             dmem_valid_o,
  output logic [XLEN-1:0]  dmem_rdata_o,

  // RVA23 Cache Block Operations
  input  logic             cbo_inval_i,
  input  logic             cbo_clean_i,
  input  logic             cbo_flush_i,
  input  logic             cbo_zero_i,

  // --------------------------------------------------------------------------
  // AXI4 Master 0: Instruction Fetch
  // --------------------------------------------------------------------------
  output axi_ar_t          m0_ar_o,
  input  logic             m0_ar_ready_i,
  input  axi_r_t           m0_r_i,
  output logic             m0_r_ready_o,

  // --------------------------------------------------------------------------
  // AXI4 Master 1: Data Access
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // 1. L1 Instruction Cache (32 KB, 4-Way)
  // --------------------------------------------------------------------------
  moon_icache #(
    .NUM_WAYS   (ICACHE_WAYS),
    .NUM_SETS   (ICACHE_SETS),
    .LINE_BYTES (LINE_BYTES)
  ) u_icache (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .req_i        (imem_req_i),
    .addr_i       (imem_addr_i),
    .valid_o      (imem_valid_o),
    .rdata_o      (imem_rdata_o),
    .fence_i_i    (fence_i_i),
    .m_ar_o       (m0_ar_o),
    .m_ar_ready_i (m0_ar_ready_i),
    .m_r_i        (m0_r_i),
    .m_r_ready_o  (m0_r_ready_o)
  );

  // --------------------------------------------------------------------------
  // 2. L1 Data Cache (32 KB, 4-Way)
  // --------------------------------------------------------------------------
  moon_dcache #(
    .NUM_WAYS   (DCACHE_WAYS),
    .NUM_SETS   (DCACHE_SETS),
    .LINE_BYTES (LINE_BYTES)
  ) u_dcache (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .req_i        (dmem_req_i),
    .we_i         (dmem_we_i),
    .addr_i       (dmem_addr_i),
    .wdata_i      (dmem_wdata_i),
    .wstrb_i      (dmem_wstrb_i),
    .valid_o      (dmem_valid_o),
    .rdata_o      (dmem_rdata_o),
    .cbo_inval_i  (cbo_inval_i),
    .cbo_clean_i  (cbo_clean_i),
    .cbo_flush_i  (cbo_flush_i),
    .cbo_zero_i   (cbo_zero_i),
    .m_ar_o       (m1_ar_o),
    .m_ar_ready_i (m1_ar_ready_i),
    .m_r_i        (m1_r_i),
    .m_r_ready_o  (m1_r_ready_o),
    .m_aw_o       (m1_aw_o),
    .m_aw_ready_i (m1_aw_ready_i),
    .m_w_o        (m1_w_o),
    .m_w_ready_i  (m1_w_ready_i),
    .m_b_i        (m1_b_i),
    .m_b_ready_o  (m1_b_ready_o)
  );

endmodule : moon_l1_cache_subsystem

`endif // MOON_L1_CACHE_SUBSYSTEM_SV
