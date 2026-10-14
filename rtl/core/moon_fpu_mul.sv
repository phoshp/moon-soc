// ============================================================================
// File: rtl/core/moon_fpu_mul.sv
// Description: Combinational IEEE-754 binary32/binary64 multiplier.
// ============================================================================

`ifndef MOON_FPU_MUL_SV
`define MOON_FPU_MUL_SV

`include "moon_pkg.sv"

module moon_fpu_mul
  import moon_pkg::*;
(
  input  logic [FLEN-1:0] operand_a_i,
  input  logic [FLEN-1:0] operand_b_i,
  input  logic            is_single_i,
  input  logic [2:0]      rounding_mode_i,
  output logic [FLEN-1:0] result_o,
  output logic [4:0]      flags_o
);

  always_comb begin : fp_mul_comb
    integer frac_bits;
    integer exp_bits;
    integer bias;
    integer emin;
    integer emax;
    integer exp_a;
    integer exp_b;
    integer exp_result;
    integer top_product;
    integer shift_amount;
    integer exp_field;
    logic sign_a;
    logic sign_b;
    logic sign_result;
    logic [10:0] exp_field_a;
    logic [10:0] exp_field_b;
    logic [51:0] frac_a;
    logic [51:0] frac_b;
    logic [52:0] sig_a;
    logic [52:0] sig_b;
    logic [105:0] product;
    logic [106:0] shifted_product;
    logic [56:0] ext_product;
    logic [52:0] rounded_sig;
    logic is_nan_a;
    logic is_nan_b;
    logic is_snan_a;
    logic is_snan_b;
    logic is_inf_a;
    logic is_inf_b;
    logic is_zero_a;
    logic is_zero_b;
    logic boxing_error;
    logic invalid;
    logic overflow;
    logic underflow;
    logic inexact;
    logic guard_bit;
    logic round_bit;
    logic sticky_bit;
    logic discarded;
    logic round_up;
    logic found_top;
    logic lower_sticky;

    result_o = '0;
    flags_o = '0;
    frac_bits = is_single_i ? 23 : 52;
    exp_bits = is_single_i ? 8 : 11;
    bias = is_single_i ? 127 : 1023;
    emin = 1 - bias;
    emax = bias;
    sign_a = is_single_i ? operand_a_i[31] : operand_a_i[63];
    sign_b = is_single_i ? operand_b_i[31] : operand_b_i[63];
    sign_result = sign_a ^ sign_b;
    exp_field_a = is_single_i ? {3'b0, operand_a_i[30:23]} : operand_a_i[62:52];
    exp_field_b = is_single_i ? {3'b0, operand_b_i[30:23]} : operand_b_i[62:52];
    frac_a = is_single_i ? {29'b0, operand_a_i[22:0]} : operand_a_i[51:0];
    frac_b = is_single_i ? {29'b0, operand_b_i[22:0]} : operand_b_i[51:0];
    is_nan_a = (exp_field_a == ((1 << exp_bits) - 1)) && (frac_a != 0);
    is_nan_b = (exp_field_b == ((1 << exp_bits) - 1)) && (frac_b != 0);
    is_snan_a = is_nan_a && !frac_a[frac_bits-1];
    is_snan_b = is_nan_b && !frac_b[frac_bits-1];
    is_inf_a = (exp_field_a == ((1 << exp_bits) - 1)) && (frac_a == 0);
    is_inf_b = (exp_field_b == ((1 << exp_bits) - 1)) && (frac_b == 0);
    is_zero_a = (exp_field_a == 0) && (frac_a == 0);
    is_zero_b = (exp_field_b == 0) && (frac_b == 0);
    boxing_error = is_single_i &&
                   ((operand_a_i[63:32] != 32'hffff_ffff) ||
                    (operand_b_i[63:32] != 32'hffff_ffff));
    invalid = is_snan_a || is_snan_b;
    overflow = 1'b0;
    underflow = 1'b0;
    inexact = 1'b0;
    exp_a = (exp_field_a == 0) ? emin : (integer'(exp_field_a) - bias);
    exp_b = (exp_field_b == 0) ? emin : (integer'(exp_field_b) - bias);
    exp_result = 0;
    top_product = 0;
    shift_amount = 0;
    exp_field = 0;
    sig_a = '0;
    sig_b = '0;
    product = '0;
    shifted_product = '0;
    ext_product = '0;
    rounded_sig = '0;
    guard_bit = 1'b0;
    round_bit = 1'b0;
    sticky_bit = 1'b0;
    discarded = 1'b0;
    round_up = 1'b0;
    found_top = 1'b0;
    lower_sticky = 1'b0;

    if (is_single_i) begin
      sig_a[22:0] = frac_a[22:0];
      sig_b[22:0] = frac_b[22:0];
      if (exp_field_a != 0) sig_a[23] = 1'b1;
      if (exp_field_b != 0) sig_b[23] = 1'b1;
    end else begin
      sig_a[51:0] = frac_a;
      sig_b[51:0] = frac_b;
      if (exp_field_a != 0) sig_a[52] = 1'b1;
      if (exp_field_b != 0) sig_b[52] = 1'b1;
    end

    product = sig_a * sig_b;
    if (is_nan_a || is_nan_b || boxing_error) begin
      if (is_single_i) result_o = 64'hffff_ffff_7fc0_0000;
      else result_o = 64'h7ff8_0000_0000_0000;
    end else if ((is_inf_a && is_zero_b) || (is_inf_b && is_zero_a)) begin
      invalid = 1'b1;
      if (is_single_i) result_o = 64'hffff_ffff_7fc0_0000;
      else result_o = 64'h7ff8_0000_0000_0000;
    end else if (is_inf_a || is_inf_b) begin
      if (is_single_i) result_o = {32'hffff_ffff, sign_result, 8'hff, 23'd0};
      else result_o = {sign_result, 11'h7ff, 52'd0};
    end else if (is_zero_a || is_zero_b) begin
      if (is_single_i) result_o = {32'hffff_ffff, sign_result, 31'd0};
      else result_o = {sign_result, 63'd0};
    end else begin
      for (int i = 0; i < 106; i++) begin
        if (product[i]) begin
          top_product = i;
          found_top = 1'b1;
        end
      end
      if (!found_top) begin
        top_product = 0;
      end
      exp_result = exp_a + exp_b + top_product - (2 * frac_bits);
      shift_amount = top_product - (frac_bits + 3);
      if (shift_amount >= 0) begin
        shifted_product = {1'b0, product} >> shift_amount;
        ext_product = shifted_product[56:0];
        for (int i = 0; i < 106; i++) begin
          if (i < shift_amount) lower_sticky = lower_sticky | product[i];
        end
        ext_product[0] = ext_product[0] | lower_sticky;
      end else begin
        ext_product = ({1'b0, product} << (-shift_amount));
      end

      guard_bit = ext_product[2];
      round_bit = ext_product[1];
      sticky_bit = ext_product[0];
      discarded = guard_bit || round_bit || sticky_bit;
      case (rounding_mode_i)
        3'b000: round_up = guard_bit && (round_bit || sticky_bit || ext_product[3]);
        3'b001: round_up = 1'b0;
        3'b010: round_up = sign_result && discarded;
        3'b011: round_up = !sign_result && discarded;
        3'b100: round_up = guard_bit;
        default: round_up = 1'b0;
      endcase
      rounded_sig = ext_product[55:3] + round_up;
      if (rounded_sig[frac_bits+1]) begin
        rounded_sig = rounded_sig >> 1;
        exp_result = exp_result + 1;
      end
      inexact = discarded;

      if (exp_result > emax) begin
        overflow = 1'b1;
        inexact = 1'b1;
        if ((rounding_mode_i == 3'b001) ||
            ((rounding_mode_i == 3'b010) && !sign_result) ||
            ((rounding_mode_i == 3'b011) && sign_result)) begin
          if (is_single_i) result_o = {32'hffff_ffff, sign_result, 8'hfe, 23'h7fffff};
          else result_o = {sign_result, 11'h7fe, 52'hf_ffff_ffff_ffff};
        end else if (is_single_i) begin
          result_o = {32'hffff_ffff, sign_result, 8'hff, 23'd0};
        end else begin
          result_o = {sign_result, 11'h7ff, 52'd0};
        end
      end else if ((exp_result == emin) && !rounded_sig[frac_bits]) begin
        underflow = inexact;
        if (is_single_i)
          result_o = {32'hffff_ffff, sign_result, 8'd0, rounded_sig[22:0]};
        else
          result_o = {sign_result, 11'd0, rounded_sig[51:0]};
      end else if (is_single_i) begin
        exp_field = exp_result + bias;
        result_o = {32'hffff_ffff, sign_result, exp_field[7:0], rounded_sig[22:0]};
      end else begin
        exp_field = exp_result + bias;
        result_o = {sign_result, exp_field[10:0], rounded_sig[51:0]};
      end
    end

    flags_o = {invalid, 1'b0, overflow, underflow, inexact};
  end

endmodule : moon_fpu_mul

`endif // MOON_FPU_MUL_SV
