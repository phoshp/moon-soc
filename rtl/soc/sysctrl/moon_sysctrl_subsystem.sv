// ============================================================================
// File: rtl/soc/sysctrl/moon_sysctrl_subsystem.sv
// Description: System Control Subsystem Block (AON / Power, Clock & Reset Macro)
//              integrating Moon Reset Controller, Clock & Reset Generator (CRG),
//              and Power Management Unit (PMU).
//              Organized as a dedicated macro partition for hierarchical ASIC synthesis.
// ============================================================================

`ifndef MOON_SYSCTRL_SUBSYSTEM_SV
`define MOON_SYSCTRL_SUBSYSTEM_SV

`include "axi_pkg.sv"
`include "moon_reset_ctrl.sv"
`include "moon_crg.sv"
`include "moon_pmu.sv"

module moon_sysctrl_subsystem
  import axi_pkg::*;
(
  input  logic ref_clk_i,
  input  logic raw_rst_ni,

  // --------------------------------------------------------------------------
  // APB Interfaces (from System Fabric)
  // --------------------------------------------------------------------------
  input  apb_req_t  crg_req_i,
  output apb_resp_t crg_resp_o,

  input  apb_req_t  pmu_req_i,
  output apb_resp_t pmu_resp_o,

  // --------------------------------------------------------------------------
  // Power Management Handshake (from CPU & Peripherals)
  // --------------------------------------------------------------------------
  input  logic wfi_i,
  input  logic irq_pending_i,

  // --------------------------------------------------------------------------
  // Domain Clock Outputs (to SoC Subsystems)
  // --------------------------------------------------------------------------
  output logic clk_aon_o,
  output logic clk_core_o,
  output logic clk_peri_o,
  output logic clk_mem_o,

  // --------------------------------------------------------------------------
  // Domain Reset Outputs (to SoC Subsystems)
  // --------------------------------------------------------------------------
  output logic rst_aon_no,
  output logic rst_core_no,
  output logic rst_peri_no,
  output logic rst_mem_no
);

  // Internal Control Interconnect
  logic core_clk_gate_req;
  logic peri_clk_gate_req;
  logic pll_pwr_down_req;
  logic sw_rst_req;

  logic internal_clk_aon;
  logic internal_rst_aon_n;

  assign clk_aon_o  = internal_clk_aon;
  assign rst_aon_no = internal_rst_aon_n;

  // --------------------------------------------------------------------------
  // Reset Controller & Multi-Domain Sequencer
  // --------------------------------------------------------------------------
  moon_reset_ctrl u_reset_ctrl (
    .clk_aon_i     (internal_clk_aon),
    .raw_rst_ni    (raw_rst_ni),
    .sw_rst_req_i  (sw_rst_req),
    .wdt_rst_req_i (1'b0),
    .rst_aon_no    (internal_rst_aon_n),
    .rst_core_no   (rst_core_no),
    .rst_peri_no   (rst_peri_no),
    .rst_mem_no    (rst_mem_no)
  );

  // --------------------------------------------------------------------------
  // Clock & Reset Generator (CRG)
  // --------------------------------------------------------------------------
  moon_crg u_crg (
    .ref_clk_i       (ref_clk_i),
    .rst_aon_ni      (internal_rst_aon_n),
    .req_i           (crg_req_i),
    .resp_o          (crg_resp_o),
    .core_clk_gate_i (core_clk_gate_req),
    .peri_clk_gate_i (peri_clk_gate_req),
    .pll_pwr_down_i  (pll_pwr_down_req),
    .clk_aon_o       (internal_clk_aon),
    .clk_core_o      (clk_core_o),
    .clk_peri_o      (clk_peri_o),
    .clk_mem_o       (clk_mem_o),
    .sw_rst_req_o    (sw_rst_req)
  );

  // --------------------------------------------------------------------------
  // Power Management Unit (PMU)
  // --------------------------------------------------------------------------
  logic [1:0] pmu_current_state;

  moon_pmu u_pmu (
    .clk_aon_i           (internal_clk_aon),
    .rst_aon_ni          (internal_rst_aon_n),
    .req_i               (pmu_req_i),
    .resp_o              (pmu_resp_o),
    .wfi_i               (wfi_i),
    .irq_pending_i       (irq_pending_i),
    .core_clk_gate_req_o (core_clk_gate_req),
    .peri_clk_gate_req_o (peri_clk_gate_req),
    .pll_pwr_down_req_o  (pll_pwr_down_req),
    .current_state_o     (pmu_current_state)
  );

  wire _unused_pmu = |{1'b0, pmu_current_state};

endmodule : moon_sysctrl_subsystem

`endif // MOON_SYSCTRL_SUBSYSTEM_SV
