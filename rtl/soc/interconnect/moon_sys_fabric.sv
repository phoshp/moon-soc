// ============================================================================
// File: rtl/soc/interconnect/moon_sys_fabric.sv
// Description: System Interconnect Fabric (Uncore / Bus Crossbar Block)
//              integrating 64-bit multi-master AXI4 crossbar, AXI-to-APB bridge,
//              and APB peripheral routing matrix.
//              Organized as a dedicated macro partition for hierarchical ASIC synthesis.
// ============================================================================

`ifndef MOON_SYS_FABRIC_SV
`define MOON_SYS_FABRIC_SV

`include "axi_pkg.sv"
`include "axi_crossbar.sv"
`include "axi_to_apb_bridge.sv"
`include "apb_crossbar.sv"

module moon_sys_fabric
  import axi_pkg::*;
(
  input  logic clk_i,
  input  logic rst_ni,

  // --------------------------------------------------------------------------
  // Master Port 0: Instruction Cache Refill (from Cache Tile)
  // --------------------------------------------------------------------------
  input  axi_ar_t m0_ar_i,
  output logic    m0_ar_ready_o,
  output axi_r_t  m0_r_o,
  input  logic    m0_r_ready_i,

  // --------------------------------------------------------------------------
  // Master Port 1: Data Cache Access & Eviction (from Cache Tile)
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Slave Port 0: Boot ROM (to Memory Subsystem)
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Slave Port 1: On-Chip SRAM (to Memory Subsystem)
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Slave Port 2: External Memory AXI4 Port (to Memory PHY)
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // APB Peripheral Bus Ports (to Peripherals & System Control)
  // 0: CLINT, 1: PLIC, 2: UART, 3: CRG, 4: PMU, 5: SPI, 6: I2C
  // --------------------------------------------------------------------------
  output apb_req_t  [6:0] p_req_o,
  input  apb_resp_t [6:0] p_resp_i
);

  // Pack Master Channels for AXI Crossbar
  axi_ar_t [1:0] xbar_m_ar;
  logic    [1:0] xbar_m_ar_ready;
  axi_r_t  [1:0] xbar_m_r;
  logic    [1:0] xbar_m_r_ready;

  axi_aw_t [1:0] xbar_m_aw;
  logic    [1:0] xbar_m_aw_ready;
  axi_w_t  [1:0] xbar_m_w;
  logic    [1:0] xbar_m_w_ready;
  axi_b_t  [1:0] xbar_m_b;
  logic    [1:0] xbar_m_b_ready;

  assign xbar_m_ar[0]       = m0_ar_i;
  assign m0_ar_ready_o      = xbar_m_ar_ready[0];
  assign m0_r_o             = xbar_m_r[0];
  assign xbar_m_r_ready[0]  = m0_r_ready_i;

  assign xbar_m_aw[0]       = '0;
  assign xbar_m_w[0]        = '0;
  assign xbar_m_b_ready[0]  = 1'b1;

  assign xbar_m_ar[1]       = m1_ar_i;
  assign m1_ar_ready_o      = xbar_m_ar_ready[1];
  assign m1_r_o             = xbar_m_r[1];
  assign xbar_m_r_ready[1]  = m1_r_ready_i;

  assign xbar_m_aw[1]       = m1_aw_i;
  assign m1_aw_ready_o      = xbar_m_aw_ready[1];
  assign xbar_m_w[1]        = m1_w_i;
  assign m1_w_ready_o       = xbar_m_w_ready[1];
  assign m1_b_o             = xbar_m_b[1];
  assign xbar_m_b_ready[1]  = m1_b_ready_i;

  // AXI Crossbar Slaves (4 slaves: S0 ROM, S1 SRAM, S2 APB Bridge, S3 External)
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
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .m_ar_i       (xbar_m_ar),
    .m_ar_ready_o (xbar_m_ar_ready),
    .m_r_o        (xbar_m_r),
    .m_r_ready_i  (xbar_m_r_ready),
    .m_aw_i       (xbar_m_aw),
    .m_aw_ready_o (xbar_m_aw_ready),
    .m_w_i        (xbar_m_w),
    .m_w_ready_o  (xbar_m_w_ready),
    .m_b_o        (xbar_m_b),
    .m_b_ready_i  (xbar_m_b_ready),
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

  // S0: Boot ROM
  assign s_rom_ar_o      = s_ar[0];
  assign s_ar_ready[0]   = s_rom_ar_ready_i;
  assign s_r[0]          = s_rom_r_i;
  assign s_rom_r_ready_o = s_r_ready[0];
  assign s_rom_aw_o      = s_aw[0];
  assign s_aw_ready[0]   = s_rom_aw_ready_i;
  assign s_rom_w_o       = s_w[0];
  assign s_w_ready[0]    = s_rom_w_ready_i;
  assign s_b[0]          = s_rom_b_i;
  assign s_rom_b_ready_o = s_b_ready[0];

  // S1: SRAM
  assign s_sram_ar_o      = s_ar[1];
  assign s_ar_ready[1]    = s_sram_ar_ready_i;
  assign s_r[1]           = s_sram_r_i;
  assign s_sram_r_ready_o = s_r_ready[1];
  assign s_sram_aw_o      = s_aw[1];
  assign s_aw_ready[1]    = s_sram_aw_ready_i;
  assign s_sram_w_o       = s_w[1];
  assign s_w_ready[1]     = s_sram_w_ready_i;
  assign s_b[1]           = s_sram_b_i;
  assign s_sram_b_ready_o = s_b_ready[1];

  // S2: APB Bridge
  apb_req_t  bridge_apb_req;
  apb_resp_t bridge_apb_resp;

  axi_to_apb_bridge u_axi_to_apb (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
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

  apb_crossbar #(
    .NUM_PERIPHS(7)
  ) u_apb_crossbar (
    .m_req_i  (bridge_apb_req),
    .m_resp_o (bridge_apb_resp),
    .p_req_o  (p_req_o),
    .p_resp_i (p_resp_i)
  );

  // S3: External Memory AXI Port
  assign s_ext_ar_o      = s_ar[3];
  assign s_ar_ready[3]   = s_ext_ar_ready_i;
  assign s_r[3]          = s_ext_r_i;
  assign s_ext_r_ready_o = s_r_ready[3];
  assign s_ext_aw_o      = s_aw[3];
  assign s_aw_ready[3]   = s_ext_aw_ready_i;
  assign s_ext_w_o       = s_w[3];
  assign s_w_ready[3]    = s_ext_w_ready_i;
  assign s_b[3]          = s_ext_b_i;
  assign s_ext_b_ready_o = s_b_ready[3];

endmodule : moon_sys_fabric

`endif // MOON_SYS_FABRIC_SV
