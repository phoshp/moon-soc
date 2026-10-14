// ============================================================================
// File: rtl/core/moon_fpu_add.sv
// Description: Combinational IEEE-754 binary32/binary64 add/subtract unit.
// ============================================================================

`ifndef MOON_FPU_ADD_SV
`define MOON_FPU_ADD_SV

`include "moon_pkg.sv"

module moon_fpu_add
  import moon_pkg::*;
(
  input  logic [FLEN-1:0] operand_a_i,
  input  logic [FLEN-1:0] operand_b_i,
  input  logic            is_single_i,
  input  logic            subtract_i,
  input  logic [2:0]      rounding_mode_i,
  output logic [FLEN-1:0] result_o,
  output logic [4:0]      flags_o
);

  function automatic logic [56:0] shift_right_jam(input logic [56:0] value,
                                                   input integer amount);
    logic sticky;
    begin
      if (amount <= 0) begin
        shift_right_jam = value;
      end else if (amount >= 57) begin
        shift_right_jam = {56'd0, |value};
      end else begin
        sticky = |(value << (57 - amount));
        shift_right_jam = value >> amount;
        shift_right_jam[0] = shift_right_jam[0] | sticky;
      end
    end
  endfunction

  always_comb begin : fp_add_comb
    integer frac_bits;
    integer exp_bits;
    integer bias;
    integer emin;
    integer emax;
    integer exp_a;
    integer exp_b;
    integer exp_large;
    integer exp_result;
    integer shift_amount;
    integer top_bit;
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
    logic [52:0] sig_large;
    logic [52:0] sig_small;
    logic [56:0] ext_large;
    logic [56:0] ext_small;
    logic [56:0] ext_result;
    logic [56:0] ext_tmp;
    logic [52:0] rounded_sig;
    logic guard_bit;
    logic round_bit;
    logic sticky_bit;
    logic discarded;
    logic round_up;
    logic is_nan_a;
    logic is_nan_b;
    logic is_snan_a;
    logic is_snan_b;
    logic is_inf_a;
    logic is_inf_b;
    logic is_zero_a;
    logic is_zero_b;
    logic invalid;
    logic overflow;
    logic underflow;
    logic inexact;
    logic single_boxing_error;

    result_o = '0;
    flags_o = '0;
    frac_bits = is_single_i ? 23 : 52;
    exp_bits = is_single_i ? 8 : 11;
    bias = is_single_i ? 127 : 1023;
    emin = 1 - bias;
    emax = bias;
    top_bit = frac_bits + 3;
    sign_a = is_single_i ? operand_a_i[31] : operand_a_i[63];
    sign_b = is_single_i ? operand_b_i[31] : operand_b_i[63];
    if (subtract_i) sign_b = ~sign_b;
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
    single_boxing_error = is_single_i &&
                          ((operand_a_i[63:32] != 32'hffff_ffff) ||
                           (operand_b_i[63:32] != 32'hffff_ffff));
    invalid = is_snan_a || is_snan_b;
    overflow = 1'b0;
    underflow = 1'b0;
    inexact = 1'b0;
    sig_a = '0;
    sig_b = '0;
    sig_large = '0;
    sig_small = '0;
    exp_a = (exp_field_a == 0) ? emin : (integer'(exp_field_a) - bias);
    exp_b = (exp_field_b == 0) ? emin : (integer'(exp_field_b) - bias);
    exp_large = 0;
    exp_result = 0;
    shift_amount = 0;
    exp_field = 0;
    ext_large = '0;
    ext_small = '0;
    ext_result = '0;
    ext_tmp = '0;
    rounded_sig = '0;
    guard_bit = 1'b0;
    round_bit = 1'b0;
    sticky_bit = 1'b0;
    discarded = 1'b0;
    round_up = 1'b0;
    sign_result = sign_a;

    if (is_single_i) begin
      if (exp_field_a != 0) sig_a[23] = 1'b1;
      if (exp_field_b != 0) sig_b[23] = 1'b1;
      sig_a[22:0] = frac_a[22:0];
      sig_b[22:0] = frac_b[22:0];
    end else begin
      if (exp_field_a != 0) sig_a[52] = 1'b1;
      if (exp_field_b != 0) sig_b[52] = 1'b1;
      sig_a = sig_a | {1'b0, frac_a};
      sig_b = sig_b | {1'b0, frac_b};
    end

    if (is_nan_a || is_nan_b || single_boxing_error) begin
      if (is_single_i) result_o = 64'hffff_ffff_7fc0_0000;
      else result_o = 64'h7ff8_0000_0000_0000;
    end else if (is_inf_a || is_inf_b) begin
      if (is_inf_a && is_inf_b && (sign_a != sign_b)) begin
        invalid = 1'b1;
        if (is_single_i) result_o = 64'hffff_ffff_7fc0_0000;
        else result_o = 64'h7ff8_0000_0000_0000;
      end else if (is_single_i) begin
        result_o = {32'hffff_ffff, sign_result, 8'hff, 23'd0};
      end else begin
        result_o = {sign_result, 11'h7ff, 52'd0};
      end
    end else if (is_zero_a && is_zero_b) begin
      sign_result = (sign_a == sign_b) ? sign_a : (rounding_mode_i == 3'b010);
      if (is_single_i) result_o = {32'hffff_ffff, sign_result, 31'd0};
      else result_o = {sign_result, 63'd0};
    end else begin
      if ((exp_a > exp_b) || ((exp_a == exp_b) && (sig_a >= sig_b))) begin
        sig_large = sig_a;
        sig_small = sig_b;
        exp_large = exp_a;
        sign_result = sign_a;
        shift_amount = exp_a - exp_b;
      end else begin
        sig_large = sig_b;
        sig_small = sig_a;
        exp_large = exp_b;
        sign_result = sign_b;
        shift_amount = exp_b - exp_a;
      end
      ext_large = {1'b0, sig_large, 3'b000};
      ext_small = shift_right_jam({1'b0, sig_small, 3'b000}, shift_amount);
      exp_result = exp_large;
      if (sign_a == sign_b) begin
        ext_result = ext_large + ext_small;
        if (ext_result[top_bit+1]) begin
          ext_result = shift_right_jam(ext_result, 1);
          exp_result = exp_result + 1;
        end
      end else begin
        ext_result = ext_large - ext_small;
        if (ext_result == 0) begin
          sign_result = (rounding_mode_i == 3'b010);
        end else begin
          for (int i = 0; i < 56; i++) begin
            if (!ext_result[top_bit] && (exp_result > emin)) begin
              ext_result = ext_result << 1;
              exp_result = exp_result - 1;
            end
          end
        end
      end

      guard_bit = ext_result[2];
      round_bit = ext_result[1];
      sticky_bit = ext_result[0];
      discarded = guard_bit || round_bit || sticky_bit;
      case (rounding_mode_i)
        3'b000: round_up = guard_bit && (round_bit || sticky_bit || ext_result[3]);
        3'b001: round_up = 1'b0;
        3'b010: round_up = sign_result && discarded;
        3'b011: round_up = !sign_result && discarded;
        3'b100: round_up = guard_bit;
        default: round_up = 1'b0;
      endcase
      rounded_sig = ext_result[55:3] + round_up;
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
          if (is_single_i)
            result_o = {32'hffff_ffff, sign_result, 8'hfe, 23'h7fffff};
          else
            result_o = {sign_result, 11'h7fe, 52'hf_ffff_ffff_ffff};
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

endmodule : moon_fpu_add

`endif // MOON_FPU_ADD_SV
