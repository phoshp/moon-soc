// ============================================================================
// File: rtl/soc/cache/moon_cache_tile.sv
// Description: L1 Cache Subsystem Tile (Cache Block) integrating 4-way set-associative
//              L1-I Cache and L1-D Cache (write-back, write-allocate) with AXI4
//              master burst interfaces.
//              Organized as a dedicated macro partition for hierarchical ASIC synthesis.
// ============================================================================

`ifndef MOON_CACHE_TILE_SV
`define MOON_CACHE_TILE_SV

`include "moon_pkg.sv"
`include "axi_pkg.sv"
`include "moon_l1_cache_subsystem.sv"

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

  // --------------------------------------------------------------------------
  // Core Instruction Fetch Interface (from CPU Tile)
  // --------------------------------------------------------------------------
  input  logic             imem_req_i,
  input  logic [XLEN-1:0]  imem_addr_i,
  output logic             imem_valid_o,
  output logic [ILEN-1:0]  imem_rdata_o,
  input  logic             fence_i_i,

  // --------------------------------------------------------------------------
  // Core Data Memory Interface (from CPU Tile)
  // --------------------------------------------------------------------------
  input  logic             dmem_req_i,
  input  logic             dmem_we_i,
  input  logic [XLEN-1:0]  dmem_addr_i,
  input  logic [XLEN-1:0]  dmem_wdata_i,
  input  logic [7:0]       dmem_wstrb_i,
  output logic             dmem_valid_o,
  output logic [XLEN-1:0]  dmem_rdata_o,

  // RVA23 Cache Block Operations (CBO)
  input  logic             cbo_inval_i,
  input  logic             cbo_clean_i,
  input  logic             cbo_flush_i,
  input  logic             cbo_zero_i,

  // --------------------------------------------------------------------------
  // AXI4 Master 0: Instruction Refill (to System Fabric)
  // --------------------------------------------------------------------------
  output axi_ar_t          m0_ar_o,
  input  logic             m0_ar_ready_i,
  input  axi_r_t           m0_r_i,
  output logic             m0_r_ready_o,

  // --------------------------------------------------------------------------
  // AXI4 Master 1: Data Access & Eviction (to System Fabric)
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

  moon_l1_cache_subsystem #(
    .ICACHE_WAYS (ICACHE_WAYS),
    .DCACHE_WAYS (DCACHE_WAYS),
    .ICACHE_SETS (ICACHE_SETS),
    .DCACHE_SETS (DCACHE_SETS),
    .LINE_BYTES  (LINE_BYTES)
  ) u_l1_cache (
    .clk_i         (clk_i),
    .rst_ni        (rst_ni),
    .imem_req_i    (imem_req_i),
    .imem_addr_i   (imem_addr_i),
    .imem_valid_o  (imem_valid_o),
    .imem_rdata_o  (imem_rdata_o),
    .fence_i_i     (fence_i_i),
    .dmem_req_i    (dmem_req_i),
    .dmem_we_i     (dmem_we_i),
    .dmem_addr_i   (dmem_addr_i),
    .dmem_wdata_i  (dmem_wdata_i),
    .dmem_wstrb_i  (dmem_wstrb_i),
    .dmem_valid_o  (dmem_valid_o),
    .dmem_rdata_o  (dmem_rdata_o),
    .cbo_inval_i   (cbo_inval_i),
    .cbo_clean_i   (cbo_clean_i),
    .cbo_flush_i   (cbo_flush_i),
    .cbo_zero_i    (cbo_zero_i),
    .m0_ar_o       (m0_ar_o),
    .m0_ar_ready_i (m0_ar_ready_i),
    .m0_r_i        (m0_r_i),
    .m0_r_ready_o  (m0_r_ready_o),
    .m1_ar_o       (m1_ar_o),
    .m1_ar_ready_i (m1_ar_ready_i),
    .m1_r_i        (m1_r_i),
    .m1_r_ready_o  (m1_r_ready_o),
    .m1_aw_o       (m1_aw_o),
    .m1_aw_ready_i (m1_aw_ready_i),
    .m1_w_o        (m1_w_o),
    .m1_w_ready_i  (m1_w_ready_i),
    .m1_b_i        (m1_b_i),
    .m1_b_ready_o  (m1_b_ready_o)
  );

endmodule : moon_cache_tile

`endif // MOON_CACHE_TILE_SV
