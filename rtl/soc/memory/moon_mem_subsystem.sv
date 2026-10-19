// ============================================================================
// File: rtl/soc/memory/moon_mem_subsystem.sv
// Description: On-Chip Memory Subsystem Block integrating Boot ROM and On-Chip
//              SRAM controller with OpenRAM macro support.
//              Organized as a dedicated macro partition for hierarchical ASIC synthesis.
// ============================================================================

`ifndef MOON_MEM_SUBSYSTEM_SV
`define MOON_MEM_SUBSYSTEM_SV

`include "axi_pkg.sv"
`include "moon_bootrom.sv"
`include "moon_sram_ctrl.sv"

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

  // --------------------------------------------------------------------------
  // S0: Boot ROM AXI4 Slave Interface (from System Fabric)
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // S1: On-Chip SRAM AXI4 Slave Interface (from System Fabric)
  // --------------------------------------------------------------------------
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

  // S0: Boot ROM (0x0000_1000)
  moon_bootrom #(
    .ROM_SIZE_BYTES(ROM_SIZE_BYTES),
    .BASE_ADDR(ROM_BASE)
  ) u_bootrom (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .s_ar_i       (s_rom_ar_i),
    .s_ar_ready_o (s_rom_ar_ready_o),
    .s_r_o        (s_rom_r_o),
    .s_r_ready_i  (s_rom_r_ready_i),
    .s_aw_i       (s_rom_aw_i),
    .s_aw_ready_o (s_rom_aw_ready_o),
    .s_w_i        (s_rom_w_i),
    .s_w_ready_o  (s_rom_w_ready_o),
    .s_b_o        (s_rom_b_o),
    .s_b_ready_i  (s_rom_b_ready_i)
  );

  // S1: On-Chip SRAM (0x7000_0000)
  moon_sram_ctrl #(
    .SRAM_SIZE_BYTES(SRAM_SIZE_BYTES),
    .BASE_ADDR(SRAM_BASE)
  ) u_sram (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .s_ar_i       (s_sram_ar_i),
    .s_ar_ready_o (s_sram_ar_ready_o),
    .s_r_o        (s_sram_r_o),
    .s_r_ready_i  (s_sram_r_ready_i),
    .s_aw_i       (s_sram_aw_i),
    .s_aw_ready_o (s_sram_aw_ready_o),
    .s_w_i        (s_sram_w_i),
    .s_w_ready_o  (s_sram_w_ready_o),
    .s_b_o        (s_sram_b_o),
    .s_b_ready_i  (s_sram_b_ready_i)
  );

endmodule : moon_mem_subsystem

`endif // MOON_MEM_SUBSYSTEM_SV
