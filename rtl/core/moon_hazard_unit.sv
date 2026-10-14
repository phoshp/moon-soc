// ============================================================================
// File: rtl/core/moon_hazard_unit.sv
// Description: Pipeline hazard detection, forwarding multiplexer control,
//              and stall/flush generation for Moon-SoC RV64 core.
// ============================================================================

`ifndef MOON_HAZARD_UNIT_SV
`define MOON_HAZARD_UNIT_SV

`include "moon_pkg.sv"

module moon_hazard_unit
  import moon_pkg::*;
(
  // Operand addresses in pipeline stages
  input  logic [4:0]  if_id_rs1_i,
  input  logic [4:0]  if_id_rs2_i,
  input  logic [4:0]  id_ex_rs1_i,
  input  logic [4:0]  id_ex_rs2_i,
  input  logic [4:0]  id_ex_rd_i,
  input  logic [4:0]  ex_mem_rd_i,
  input  logic [4:0]  mem_wb_rd_i,
  input  logic        if_id_fp_rs1_en_i,
  input  logic [4:0]  if_id_fp_rs1_i,
  input  logic        id_ex_fp_we_i,
  input  logic [4:0]  id_ex_fp_rd_i,
  input  logic        ex_mem_fp_we_i,
  input  logic [4:0]  ex_mem_fp_rd_i,

  // Control signals in pipeline stages
  input  logic        id_ex_is_load_i,
  input  logic        id_ex_is_csr_i,
  input  logic        ex_mem_is_csr_i,
  input  logic        ex_mem_regwrite_i,
  input  logic        mem_wb_regwrite_i,

  // Execution redirect and multi-cycle busy signals
  input  logic        branch_taken_i,
  input  logic        trap_flush_i,
  input  logic        busy_div_i,
  input  logic        busy_mem_i,
  input  logic        busy_mmu_i,

  // Forwarding outputs
  output fwd_sel_e    fwd_a_o,
  output fwd_sel_e    fwd_b_o,

  // Pipeline control outputs
  output logic        stall_if_o,
  output logic        stall_id_o,
  output logic        stall_ex_o,
  output logic        stall_mem_o,
  output logic        flush_id_o,
  output logic        flush_ex_o,
  output logic        flush_mem_o
);

  // --------------------------------------------------------------------------
  // Data Forwarding Logic (EX Stage Operands)
  // --------------------------------------------------------------------------
  always_comb begin
    // Operand A Forwarding
    if (ex_mem_regwrite_i && (ex_mem_rd_i != 5'd0) && (ex_mem_rd_i == id_ex_rs1_i)) begin
      fwd_a_o = FWD_EX;
    end else if (mem_wb_regwrite_i && (mem_wb_rd_i != 5'd0) && (mem_wb_rd_i == id_ex_rs1_i)) begin
      fwd_a_o = FWD_MEM;
    end else begin
      fwd_a_o = FWD_REG;
    end

    // Operand B Forwarding
    if (ex_mem_regwrite_i && (ex_mem_rd_i != 5'd0) && (ex_mem_rd_i == id_ex_rs2_i)) begin
      fwd_b_o = FWD_EX;
    end else if (mem_wb_regwrite_i && (mem_wb_rd_i != 5'd0) && (mem_wb_rd_i == id_ex_rs2_i)) begin
      fwd_b_o = FWD_MEM;
    end else begin
      fwd_b_o = FWD_REG;
    end
  end

  // --------------------------------------------------------------------------
  // Load-Use & CSR Hazard Detection
  // --------------------------------------------------------------------------
  wire load_use_hazard = id_ex_is_load_i && (id_ex_rd_i != 5'd0) &&
                         ((id_ex_rd_i == if_id_rs1_i) || (id_ex_rd_i == if_id_rs2_i));

  wire csr_hazard = id_ex_is_csr_i || ex_mem_is_csr_i;
  wire fp_hazard = if_id_fp_rs1_en_i &&
                   ((id_ex_fp_we_i && (id_ex_fp_rd_i == if_id_fp_rs1_i)) ||
                    (ex_mem_fp_we_i && (ex_mem_fp_rd_i == if_id_fp_rs1_i)));

  // --------------------------------------------------------------------------
  // Stall and Flush Control
  // --------------------------------------------------------------------------
  wire global_busy = busy_div_i || busy_mem_i || busy_mmu_i;

  always_comb begin
    stall_if_o  = 1'b0;
    stall_id_o  = 1'b0;
    stall_ex_o  = 1'b0;
    stall_mem_o = 1'b0;
    flush_id_o  = 1'b0;
    flush_ex_o  = 1'b0;
    flush_mem_o = 1'b0;

    if (trap_flush_i) begin
      // Trap flush clears entire pipeline
      flush_id_o  = 1'b1;
      flush_ex_o  = 1'b1;
      flush_mem_o = 1'b1;
    end else if (global_busy) begin
      // Multi-cycle operation stalls all stages
      stall_if_o  = 1'b1;
      stall_id_o  = 1'b1;
      stall_ex_o  = 1'b1;
      stall_mem_o = 1'b1;
    end else if (branch_taken_i) begin
      // Hold the redirect until older memory and MMU operations complete.
      flush_id_o  = 1'b1;
      flush_ex_o  = 1'b1;
    end else if (load_use_hazard || csr_hazard || fp_hazard) begin
      // Load-use or CSR serialization bubble
      stall_if_o  = 1'b1;
      stall_id_o  = 1'b1;
      flush_ex_o  = 1'b1;
    end
  end

endmodule : moon_hazard_unit

`endif // MOON_HAZARD_UNIT_SV
