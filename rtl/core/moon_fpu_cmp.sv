// ============================================================================
// File: rtl/core/moon_fpu_cmp.sv
// Description: Scalar F/D min, max, and ordered comparison operations.
// ============================================================================

`ifndef MOON_FPU_CMP_SV
`define MOON_FPU_CMP_SV

`include "moon_pkg.sv"

module moon_fpu_cmp
  import moon_pkg::*;
(
  input  logic [FLEN-1:0] operand_a_i,
  input  logic [FLEN-1:0] operand_b_i,
  input  logic            is_single_i,
  input  logic [2:0]      operation_i,
  output logic [FLEN-1:0] result_o,
  output logic [4:0]      flags_o
);

  always_comb begin
    logic sign_a, sign_b;
    logic [10:0] exp_a, exp_b;
    logic [51:0] frac_a, frac_b;
    logic nan_a, nan_b, snan_a, snan_b;
    logic zero_a, zero_b;
    logic magnitude_less;
    logic equal_value;
    logic less_value;
    logic choose_a;
    logic [31:0] single_result;

    sign_a = is_single_i ? operand_a_i[31] : operand_a_i[63];
    sign_b = is_single_i ? operand_b_i[31] : operand_b_i[63];
    exp_a = is_single_i ? {3'b0, operand_a_i[30:23]} : operand_a_i[62:52];
    exp_b = is_single_i ? {3'b0, operand_b_i[30:23]} : operand_b_i[62:52];
    frac_a = is_single_i ? {29'b0, operand_a_i[22:0]} : operand_a_i[51:0];
    frac_b = is_single_i ? {29'b0, operand_b_i[22:0]} : operand_b_i[51:0];
    nan_a = ((exp_a == (is_single_i ? 11'h0ff : 11'h7ff)) && (frac_a != 0)) ||
            (is_single_i && (operand_a_i[63:32] != 32'hffff_ffff));
    nan_b = ((exp_b == (is_single_i ? 11'h0ff : 11'h7ff)) && (frac_b != 0)) ||
            (is_single_i && (operand_b_i[63:32] != 32'hffff_ffff));
    snan_a = nan_a && !(is_single_i ? frac_a[22] : frac_a[51]);
    snan_b = nan_b && !(is_single_i ? frac_b[22] : frac_b[51]);
    zero_a = (exp_a == 0) && (frac_a == 0);
    zero_b = (exp_b == 0) && (frac_b == 0);
    magnitude_less = (exp_a < exp_b) || ((exp_a == exp_b) && (frac_a < frac_b));
    equal_value = (zero_a && zero_b) || ((sign_a == sign_b) && (exp_a == exp_b) && (frac_a == frac_b));
    less_value = (sign_a != sign_b) ? sign_a : (sign_a ? !magnitude_less && !equal_value : magnitude_less);
    choose_a = 1'b0;
    result_o = '0;
    flags_o = '0;
    single_result = '0;

    case (operation_i)
      3'd0, 3'd1: begin // FMIN / FMAX
        flags_o[4] = snan_a || snan_b;
        if (nan_a && nan_b) begin
          if (is_single_i) result_o = 64'hffff_ffff_7fc0_0000;
          else result_o = 64'h7ff8_0000_0000_0000;
        end else if (nan_a) begin
          result_o = operand_b_i;
        end else if (nan_b) begin
          result_o = operand_a_i;
        end else if (zero_a && zero_b) begin
          if (operation_i == 3'd0)
            single_result[31] = sign_a || sign_b;
          else
            single_result[31] = sign_a && sign_b;
          if (is_single_i) result_o = {32'hffff_ffff, single_result[31], 31'd0};
          else result_o = {(operation_i == 3'd0) ? (sign_a || sign_b) : (sign_a && sign_b), 63'd0};
        end else begin
          if (sign_a != sign_b) choose_a = (operation_i == 3'd0) ? sign_a : !sign_a;
          else if (operation_i == 3'd0) choose_a = sign_a ? !magnitude_less : magnitude_less;
          else choose_a = sign_a ? magnitude_less : !magnitude_less;
          result_o = choose_a ? operand_a_i : operand_b_i;
        end
      end
      3'd2, 3'd3, 3'd4: begin // FLE / FLT / FEQ
        if (nan_a || nan_b) begin
          if (operation_i != 3'd4) flags_o[4] = 1'b1;
          else flags_o[4] = snan_a || snan_b;
          result_o = '0;
        end else begin
          case (operation_i)
            3'd2: result_o = {63'd0, less_value || equal_value};
            3'd3: result_o = {63'd0, less_value};
            default: result_o = {63'd0, equal_value};
          endcase
        end
      end
      default: result_o = '0;
    endcase
  end

endmodule : moon_fpu_cmp

`endif // MOON_FPU_CMP_SV
