// ============================================================================
// File: rtl/core/moon_alu.sv
// Description: RV64I 64-bit Arithmetic Logic Unit supporting standard 64-bit
//              operations and 32-bit word operations with sign extension.
// ============================================================================

`ifndef MOON_ALU_SV
`define MOON_ALU_SV

`include "moon_pkg.sv"

module moon_alu
  import moon_pkg::*;
(
  input  alu_op_e          op_i,
  input  logic [XLEN-1:0]  operand_a_i,
  input  logic [XLEN-1:0]  operand_b_i,
  output logic [XLEN-1:0]  result_o,
  output logic             zero_o
);

  logic [5:0]  shamt64;
  logic [4:0]  shamt32;
  logic [31:0] a32;
  logic [31:0] b32;

  logic [31:0] res_addw;
  logic [31:0] res_subw;
  logic [31:0] res_sllw;
  logic [31:0] res_srlw;
  logic [31:0] res_sraw;

  assign shamt64 = operand_b_i[5:0];
  assign shamt32 = operand_b_i[4:0];
  assign a32     = operand_a_i[31:0];
  assign b32     = operand_b_i[31:0];

  // 32-bit Word intermediate operations
  assign res_addw = a32 + b32;
  assign res_subw = a32 - b32;
  assign res_sllw = a32 << shamt32;
  assign res_srlw = a32 >> shamt32;
  assign res_sraw = $signed(a32) >>> shamt32;

  always_comb begin
    case (op_i)
      // 64-bit Arithmetic
      ALU_ADD:    result_o = operand_a_i + operand_b_i;
      ALU_SUB:    result_o = operand_a_i - operand_b_i;

      // 64-bit Logical
      ALU_AND:    result_o = operand_a_i & operand_b_i;
      ALU_OR:     result_o = operand_a_i | operand_b_i;
      ALU_XOR:    result_o = operand_a_i ^ operand_b_i;

      // 64-bit Shifts
      ALU_SLL:    result_o = operand_a_i << shamt64;
      ALU_SRL:    result_o = operand_a_i >> shamt64;
      ALU_SRA:    result_o = $signed(operand_a_i) >>> shamt64;

      // Set Less Than
      ALU_SLT:    result_o = ($signed(operand_a_i) < $signed(operand_b_i)) ? 64'd1 : 64'd0;
      ALU_SLTU:   result_o = (operand_a_i < operand_b_i)                   ? 64'd1 : 64'd0;

      // 32-bit Word Operations (sign-extended to 64 bits per RV64 specification)
      ALU_ADDW:   result_o = {{32{res_addw[31]}}, res_addw};
      ALU_SUBW:   result_o = {{32{res_subw[31]}}, res_subw};
      ALU_SLLW:   result_o = {{32{res_sllw[31]}}, res_sllw};
      ALU_SRLW:   result_o = {{32{res_srlw[31]}}, res_srlw};
      ALU_SRAW:   result_o = {{32{res_sraw[31]}}, res_sraw};

      // Pass-through
      ALU_COPY_A: result_o = operand_a_i;
      ALU_COPY_B: result_o = operand_b_i;

      default:    result_o = '0;
    endcase
  end

  assign zero_o = (result_o == '0);

endmodule : moon_alu

`endif // MOON_ALU_SV
