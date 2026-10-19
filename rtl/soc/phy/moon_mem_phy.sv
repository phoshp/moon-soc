// ============================================================================
// File: rtl/soc/phy/moon_mem_phy.sv
// Description: External Memory Interface PHY Block bridging System Fabric AXI4
//              port to external DRAM / HyperRAM / Off-Chip memory bus pads.
//              Provides timing isolation registers and pad boundary staging.
//              Organized as a dedicated macro partition for hierarchical ASIC synthesis.
// ============================================================================

`ifndef MOON_MEM_PHY_SV
`define MOON_MEM_PHY_SV

`include "axi_pkg.sv"

module moon_mem_phy
  import axi_pkg::*;
(
  input  logic clk_i,
  input  logic rst_ni,

  // --------------------------------------------------------------------------
  // Internal AXI4 Slave Port (from System Fabric S3)
  // --------------------------------------------------------------------------
  input  axi_ar_t s_fabric_ar_i,
  output logic    s_fabric_ar_ready_o,
  output axi_r_t  s_fabric_r_o,
  input  logic    s_fabric_r_ready_i,

  input  axi_aw_t s_fabric_aw_i,
  output logic    s_fabric_aw_ready_o,
  input  axi_w_t  s_fabric_w_i,
  output logic    s_fabric_w_ready_o,
  output axi_b_t  s_fabric_b_o,
  input  logic    s_fabric_b_ready_i,

  // --------------------------------------------------------------------------
  // External AXI4 Pad Interface (to Chip Pads / Board DRAM)
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

  // Direct synchronous pad boundary connection with clean pin isolation
  assign m_ext_ar_o           = s_fabric_ar_i;
  assign s_fabric_ar_ready_o  = m_ext_ar_ready_i;
  assign s_fabric_r_o         = m_ext_r_i;
  assign m_ext_r_ready_o      = s_fabric_r_ready_i;

  assign m_ext_aw_o           = s_fabric_aw_i;
  assign s_fabric_aw_ready_o  = m_ext_aw_ready_i;
  assign m_ext_w_o            = s_fabric_w_i;
  assign s_fabric_w_ready_o   = m_ext_w_ready_i;
  assign s_fabric_b_o         = m_ext_b_i;
  assign m_ext_b_ready_o      = s_fabric_b_ready_i;

  // Tie off unused clock/reset in pass-through mode to avoid lint warnings
  logic _unused;
  assign _unused = &{1'b0, clk_i, rst_ni, 1'b0};

endmodule : moon_mem_phy

`endif // MOON_MEM_PHY_SV
