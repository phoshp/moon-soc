// ============================================================================
// File: rtl/core/moon_fpu_div.sv
// Description: Combinational IEEE-754 binary32/binary64 divider.
// ============================================================================

`ifndef MOON_FPU_DIV_SV
`define MOON_FPU_DIV_SV

`include "moon_pkg.sv"

module moon_fpu_div
  import moon_pkg::*;
(
  input  logic [FLEN-1:0] operand_a_i,
  input  logic [FLEN-1:0] operand_b_i,
  input  logic            is_single_i,
  input  logic [2:0]      rounding_mode_i,
  output logic [FLEN-1:0] result_o,
  output logic [4:0]      flags_o
);

  always_comb begin : fp_div_comb
    integer frac_bits, exp_bits, bias, emin, emax;
    integer exp_a, exp_b, exp_result, exp_field;
    logic sign_a, sign_b, sign_result;
    logic [10:0] exp_field_a, exp_field_b;
    logic [51:0] frac_a, frac_b;
    logic [52:0] sig_a, sig_b, rounded_sig;
    logic [109:0] numerator, quotient, remainder;
    logic [54:0] num32;
    logic [23:0] den32, rem32;
    logic [27:0] q32;
    logic [56:0] ext_quotient;
    logic nan_a, nan_b, snan_a, snan_b;
    logic inf_a, inf_b, zero_a, zero_b, boxing_error;
    logic invalid, div_by_zero, overflow, underflow, inexact;
    logic guard_bit, round_bit, sticky_bit, discarded, round_up;

    result_o = '0;
    flags_o = '0;
    num32 = '0;
    den32 = '0;
    rem32 = '0;
    q32 = '0;
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
    nan_a = (exp_field_a == ((1 << exp_bits) - 1)) && (frac_a != 0);
    nan_b = (exp_field_b == ((1 << exp_bits) - 1)) && (frac_b != 0);
    snan_a = nan_a && !(is_single_i ? frac_a[22] : frac_a[51]);
    snan_b = nan_b && !(is_single_i ? frac_b[22] : frac_b[51]);
    inf_a = (exp_field_a == ((1 << exp_bits) - 1)) && (frac_a == 0);
    inf_b = (exp_field_b == ((1 << exp_bits) - 1)) && (frac_b == 0);
    zero_a = (exp_field_a == 0) && (frac_a == 0);
    zero_b = (exp_field_b == 0) && (frac_b == 0);
    boxing_error = is_single_i &&
                   ((operand_a_i[63:32] != 32'hffff_ffff) ||
                    (operand_b_i[63:32] != 32'hffff_ffff));
    invalid = snan_a || snan_b;
    div_by_zero = 1'b0;
    overflow = 1'b0;
    underflow = 1'b0;
    inexact = 1'b0;
    exp_a = (exp_field_a == 0) ? emin : (integer'(exp_field_a) - bias);
    exp_b = (exp_field_b == 0) ? emin : (integer'(exp_field_b) - bias);
    exp_result = 0;
    exp_field = 0;
    sig_a = '0;
    sig_b = '0;
    rounded_sig = '0;
    numerator = '0;
    quotient = '0;
    remainder = '0;
    ext_quotient = '0;
    guard_bit = 1'b0;
    round_bit = 1'b0;
    sticky_bit = 1'b0;
    discarded = 1'b0;
    round_up = 1'b0;

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

    if (is_single_i && boxing_error) begin
      result_o = 64'hffff_ffff_7fc0_0000;
    end else if (nan_a || nan_b) begin
      if (is_single_i) result_o = 64'hffff_ffff_7fc0_0000;
      else result_o = 64'h7ff8_0000_0000_0000;
    end else if ((zero_a && zero_b) || (inf_a && inf_b)) begin
      invalid = 1'b1;
      if (is_single_i) result_o = 64'hffff_ffff_7fc0_0000;
      else result_o = 64'h7ff8_0000_0000_0000;
    end else if (inf_a || zero_b) begin
      if (zero_b && !inf_a) begin
        div_by_zero = 1'b1;
        if (is_single_i) result_o = {32'hffff_ffff, sign_result, 8'hff, 23'd0};
        else result_o = {sign_result, 11'h7ff, 52'd0};
      end else if (is_single_i) begin
        result_o = {32'hffff_ffff, sign_result, 8'hff, 23'd0};
      end else begin
        result_o = {sign_result, 11'h7ff, 52'd0};
      end
    end else if (inf_b || zero_a) begin
      if (is_single_i) result_o = {32'hffff_ffff, sign_result, 31'd0};
      else result_o = {sign_result, 63'd0};
    end else begin
      for (int i = 0; i < 52; i++) begin
        if ((i < frac_bits) && !sig_a[frac_bits]) begin
          sig_a = sig_a << 1;
          exp_a = exp_a - 1;
        end
        if ((i < frac_bits) && !sig_b[frac_bits]) begin
          sig_b = sig_b << 1;
          exp_b = exp_b - 1;
        end
      end
      if (is_single_i) begin
        num32 = {31'd0, sig_a[23:0]} << 27;
        den32 = sig_b[23:0];
        q32   = num32 / den32;
        rem32 = num32 % den32;
        quotient = {29'd0, q32};
        remainder = {29'd0, rem32};
      end else begin
        numerator = {{57{1'b0}}, sig_a} << 56;
        quotient = numerator / sig_b;
        remainder = numerator % sig_b;
      end
      quotient[0] = quotient[0] | (remainder != 0);
      if (quotient[frac_bits+4]) begin
        ext_quotient = quotient[56:0] >> 1;
        ext_quotient[0] = ext_quotient[0] | quotient[0];
        exp_result = exp_a - exp_b;
      end else begin
        ext_quotient = quotient[56:0];
        exp_result = exp_a - exp_b - 1;
      end

      guard_bit = ext_quotient[2];
      round_bit = ext_quotient[1];
      sticky_bit = ext_quotient[0];
      discarded = guard_bit || round_bit || sticky_bit;
      case (rounding_mode_i)
        3'b000: round_up = guard_bit && (round_bit || sticky_bit || ext_quotient[3]);
        3'b001: round_up = 1'b0;
        3'b010: round_up = sign_result && discarded;
        3'b011: round_up = !sign_result && discarded;
        3'b100: round_up = guard_bit;
        default: round_up = 1'b0;
      endcase
      rounded_sig = ext_quotient[55:3] + round_up;
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
        if (is_single_i) result_o = {32'hffff_ffff, sign_result, 8'd0, rounded_sig[22:0]};
        else result_o = {sign_result, 11'd0, rounded_sig[51:0]};
      end else if (is_single_i) begin
        exp_field = exp_result + bias;
        result_o = {32'hffff_ffff, sign_result, exp_field[7:0], rounded_sig[22:0]};
      end else begin
        exp_field = exp_result + bias;
        result_o = {sign_result, exp_field[10:0], rounded_sig[51:0]};
      end
    end

    flags_o = {invalid, div_by_zero, overflow, underflow, inexact};
  end

endmodule : moon_fpu_div

`endif // MOON_FPU_DIV_SV
