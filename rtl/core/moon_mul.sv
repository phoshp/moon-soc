// ============================================================================
// File: rtl/core/moon_mul.sv
// Description: RV64M Hardware Multiplier supporting MUL, MULH, MULHU,
//              MULHSU, and MULW with single-cycle execution.
// ============================================================================

`ifndef MOON_MUL_SV
`define MOON_MUL_SV

`include "moon_pkg.sv"

module moon_mul
  import moon_pkg::*;
(
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic             valid_i,
  input  muldiv_op_e       op_i,
  input  logic [XLEN-1:0]  operand_a_i,
  input  logic [XLEN-1:0]  operand_b_i,
  output logic             ready_o,
  output logic [XLEN-1:0]  result_o
);

  // Sign extension bits for 65-bit signed multiplication
  logic [64:0] a_ext;
  logic [64:0] b_ext;
  logic signed [129:0] mult_comb;

  always_comb begin
    case (op_i)
      MULDIV_MUL: begin
        a_ext = {operand_a_i[XLEN-1], operand_a_i};
        b_ext = {operand_b_i[XLEN-1], operand_b_i};
      end
      MULDIV_MULH: begin
        a_ext = {operand_a_i[XLEN-1], operand_a_i};
        b_ext = {operand_b_i[XLEN-1], operand_b_i};
      end
      MULDIV_MULHU: begin
        a_ext = {1'b0, operand_a_i};
        b_ext = {1'b0, operand_b_i};
      end
      MULDIV_MULHSU: begin
        a_ext = {operand_a_i[XLEN-1], operand_a_i}; // signed
        b_ext = {1'b0, operand_b_i};               // unsigned
      end
      MULDIV_MULW: begin
        a_ext = {{33{operand_a_i[31]}}, operand_a_i[31:0]};
        b_ext = {{33{operand_b_i[31]}}, operand_b_i[31:0]};
      end
      default: begin
        a_ext = '0;
        b_ext = '0;
      end
    endcase
  end

  // 65-bit x 65-bit signed multiplication core
  assign mult_comb = $signed(a_ext) * $signed(b_ext);

  // Result selection
  logic [31:0] mulw_res;
  assign mulw_res = mult_comb[31:0];

  always_comb begin
    case (op_i)
      MULDIV_MUL:    result_o = mult_comb[63:0];
      MULDIV_MULH:   result_o = mult_comb[127:64];
      MULDIV_MULHU:  result_o = mult_comb[127:64];
      MULDIV_MULHSU: result_o = mult_comb[127:64];
      MULDIV_MULW:   result_o = {{32{mulw_res[31]}}, mulw_res};
      default:       result_o = '0;
    endcase
  end

  assign ready_o = 1'b1;

endmodule : moon_mul

`endif // MOON_MUL_SV
