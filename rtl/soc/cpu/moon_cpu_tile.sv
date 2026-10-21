// ============================================================================
// File: rtl/soc/cpu/moon_cpu_tile.sv
// Description: CPU Compute Tile (CPU Block) integrating 64-bit RV64 Moon Core,
//              execution accelerators (FPU, Vector unit), and MMU/PMP.
//              Organized as a dedicated macro partition for hierarchical ASIC synthesis.
// ============================================================================

`ifndef MOON_CPU_TILE_SV
`define MOON_CPU_TILE_SV

`include "moon_pkg.sv"
`include "moon_core.sv"

module moon_cpu_tile
  import moon_pkg::*;
#(
  parameter int HART_ID          = 0,
  parameter bit ENABLE_FPU       = 1'b0,
  parameter int TLB_ENTRIES      = 8,
  parameter int PMP_ENTRIES      = 8
)(
  input  logic             clk_i,
  input  logic             rst_ni,

  // Instruction Memory Bus Interface (to Cache Tile)
  output logic             imem_req_o,
  output logic [XLEN-1:0]  imem_addr_o,
  input  logic             imem_valid_i,
  input  logic [ILEN-1:0]  imem_rdata_i,

  // Data Memory Bus Interface (to Cache Tile)
  output logic             dmem_req_o,
  output logic             dmem_we_o,
  output logic [XLEN-1:0]  dmem_addr_o,
  output logic [XLEN-1:0]  dmem_wdata_o,
  output logic [7:0]       dmem_wstrb_o,
  input  logic             dmem_valid_i,
  input  logic [XLEN-1:0]  dmem_rdata_i,

  // Hardware Interrupt Lines (from Peripheral Subsystem)
  input  logic             timer_irq_i,
  input  logic             software_irq_i,
  input  logic             external_irq_i,

  // Cache Coherence Invalidation Line
  input  logic             inv_valid_i,
  input  logic [XLEN-1:0]  inv_addr_i,

  // Power Management & Hardware Status Signals (to System Control)
  output logic             wfi_o,
  output logic             interrupt_pending_o
);

  moon_core #(
    .HART_ID(HART_ID),
    .ENABLE_FPU(ENABLE_FPU),
    .TLB_ENTRIES(TLB_ENTRIES),
    .PMP_ENTRIES(PMP_ENTRIES)
  ) u_core (
    .clk_i               (clk_i),
    .rst_ni              (rst_ni),
    .imem_req_o          (imem_req_o),
    .imem_addr_o         (imem_addr_o),
    .imem_valid_i        (imem_valid_i),
    .imem_rdata_i        (imem_rdata_i),
    .dmem_req_o          (dmem_req_o),
    .dmem_we_o           (dmem_we_o),
    .dmem_addr_o         (dmem_addr_o),
    .dmem_wdata_o        (dmem_wdata_o),
    .dmem_wstrb_o        (dmem_wstrb_o),
    .dmem_valid_i        (dmem_valid_i),
    .dmem_rdata_i        (dmem_rdata_i),
    .timer_irq_i         (timer_irq_i),
    .software_irq_i      (software_irq_i),
    .external_irq_i      (external_irq_i),
    .inv_valid_i         (inv_valid_i),
    .inv_addr_i          (inv_addr_i),
    .wfi_o               (wfi_o),
    .interrupt_pending_o (interrupt_pending_o)
  );

endmodule : moon_cpu_tile

`endif // MOON_CPU_TILE_SV
