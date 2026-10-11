// ============================================================================
// File: rtl/core/moon_if_stage.sv
// Description: Instruction Fetch (IF) stage and IF/ID pipeline register
//              for Moon-SoC RV64 core.
// ============================================================================

`ifndef MOON_IF_STAGE_SV
`define MOON_IF_STAGE_SV

`include "moon_pkg.sv"

module moon_if_stage
  import moon_pkg::*;
(
  input  logic             clk_i,
  input  logic             rst_ni,

  // Pipeline Flow Control
  input  logic             stall_if_i,
  input  logic             stall_id_i,
  input  logic             flush_id_i,

  // Redirection inputs from EX and Trap units
  input  logic             branch_taken_i,
  input  logic [XLEN-1:0]  branch_target_i,
  input  logic             trap_enter_i,
  input  logic [XLEN-1:0]  trap_vector_i,
  input  logic             mret_i,
  input  logic [XLEN-1:0]  mepc_i,

  // Instruction Memory Interface (Fetch)
  output logic             imem_req_o,
  output logic [XLEN-1:0]  imem_addr_o,
  input  logic             imem_valid_i,
  input  logic [ILEN-1:0]  imem_rdata_i,

  // Output to ID Stage (IF/ID Pipeline Register)
  output logic [XLEN-1:0]  if_id_pc_o,
  output logic [ILEN-1:0]  if_id_instr_o,
  output logic             if_id_valid_o
);

  logic [XLEN-1:0] pc_q, pc_d;
  logic [XLEN-1:0] pc_next;

  // Sequential PC calculation
  assign pc_next = pc_q + 64'd4;

  // Next PC multiplexer
  always_comb begin
    if (trap_enter_i) begin
      pc_d = trap_vector_i;
    end else if (mret_i) begin
      pc_d = mepc_i;
    end else if (branch_taken_i) begin
      pc_d = branch_target_i;
    end else if (!stall_if_i) begin
      pc_d = pc_next;
    end else begin
      pc_d = pc_q;
    end
  end

  // Instruction memory request
  assign imem_req_o  = 1'b1;
  assign imem_addr_o = pc_q;

  // Program Counter Register
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_q <= 64'h0000_1000; // Reset vector (Boot ROM address)
    end else begin
      pc_q <= pc_d;
    end
  end

  // IF/ID Pipeline Register
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      if_id_pc_o    <= '0;
      if_id_instr_o <= 32'h0000_0013; // NOP (addi x0, x0, 0)
      if_id_valid_o <= 1'b0;
    end else if (flush_id_i) begin
      if_id_pc_o    <= '0;
      if_id_instr_o <= 32'h0000_0013; // Flush with NOP
      if_id_valid_o <= 1'b0;
    end else if (!stall_id_i) begin
      if_id_pc_o    <= pc_q;
      if_id_instr_o <= imem_rdata_i;
      if_id_valid_o <= imem_valid_i;
    end
  end

endmodule : moon_if_stage

`endif // MOON_IF_STAGE_SV
