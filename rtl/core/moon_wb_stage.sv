// ============================================================================
// File: rtl/core/moon_wb_stage.sv
// Description: Writeback (WB) stage for Moon-SoC RV64 core, selecting final
//              destination data to commit to the Integer Register File.
// ============================================================================

`ifndef MOON_WB_STAGE_SV
`define MOON_WB_STAGE_SV

`include "moon_pkg.sv"

module moon_wb_stage
  import moon_pkg::*;
(
  // Inputs from MEM Stage (MEM/WB Register)
  input  logic             mem_wb_valid_i,
  input  logic [4:0]       mem_wb_rd_i,
  input  logic [XLEN-1:0]  mem_wb_alu_res_i,
  input  logic [XLEN-1:0]  mem_wb_mul_res_i,
  input  logic [XLEN-1:0]  mem_wb_div_res_i,
  input  logic             mem_wb_is_mul_i,
  input  logic             mem_wb_is_div_i,
  input  logic [XLEN-1:0]  mem_wb_mem_data_i,
  input  logic [XLEN-1:0]  mem_wb_link_pc_i,
  input  logic             mem_wb_is_load_i,
  input  logic             mem_wb_is_jal_i,
  input  logic             mem_wb_is_jalr_i,
  input  logic             mem_wb_regwrite_i,
  input  logic             mem_wb_is_sc_i,
  input  logic             mem_wb_sc_success_i,
  input  logic             mem_wb_is_csr_i,
  input  logic [XLEN-1:0]  csr_rdata_i,

  // Outputs to Register File and Forwarding
  output logic             wb_regwrite_o,
  output logic [4:0]       wb_rd_o,
  output logic [XLEN-1:0]  wb_wdata_o
);

  assign wb_regwrite_o = mem_wb_valid_i && mem_wb_regwrite_i;
  assign wb_rd_o       = mem_wb_rd_i;

  always_comb begin
    if (mem_wb_is_sc_i) begin
      // SC returns 0 on success, non-zero (1) on failure
      wb_wdata_o = mem_wb_sc_success_i ? 64'd0 : 64'd1;
    end else if (mem_wb_is_load_i) begin
      wb_wdata_o = mem_wb_mem_data_i;
    end else if (mem_wb_is_jal_i || mem_wb_is_jalr_i) begin
      wb_wdata_o = mem_wb_link_pc_i;
    end else if (mem_wb_is_csr_i) begin
      wb_wdata_o = csr_rdata_i;
    end else if (mem_wb_is_mul_i) begin
      wb_wdata_o = mem_wb_mul_res_i;
    end else if (mem_wb_is_div_i) begin
      wb_wdata_o = mem_wb_div_res_i;
    end else begin
      wb_wdata_o = mem_wb_alu_res_i;
    end
  end

endmodule : moon_wb_stage

`endif // MOON_WB_STAGE_SV
