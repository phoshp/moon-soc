// ============================================================================
// File: rtl/core/moon_fpu_sqrt.sv
// Description: Combinational IEEE-754 binary32/binary64 square root.
// ============================================================================

`ifndef MOON_FPU_SQRT_SV
`define MOON_FPU_SQRT_SV

`include "moon_pkg.sv"

module moon_fpu_sqrt
  import moon_pkg::*;
(
  input  logic [FLEN-1:0] operand_i,
  input  logic            is_single_i,
  input  logic [2:0]      rounding_mode_i,
  output logic [FLEN-1:0] result_o,
  output logic [4:0]      flags_o
);
  function automatic logic [63:0] integer_sqrt(input logic [127:0] value);
    logic [129:0] remainder;
    logic [129:0] trial;
    logic [65:0] root;
    begin
      remainder = '0;
      root = '0;
      trial = '0;
      for (int i = 63; i >= 0; i--) begin
        remainder = (remainder << 2) | ((value >> (i * 2)) & 128'd3);
        root = root << 1;
        trial = (root << 1) | 130'd1;
        if (remainder >= trial) begin
          remainder = remainder - trial;
          root = root | 66'd1;
        end
      end
      integer_sqrt = root[63:0];
    end
  endfunction

  always_comb begin : fp_sqrt_comb
    integer frac_bits, bias, emin, exponent, exp_result, top_bit;
    logic sign, is_nan, is_snan, is_inf, is_zero, boxing_error;
    logic [10:0] exp_field;
    logic [51:0] fraction;
    logic [52:0] significand;
    logic [127:0] radicand;
    logic [127:0] root_wide;
    logic [63:0] root;
    logic [52:0] rounded_sig;
    logic [55:0] ext_sig;
    logic [129:0] square_remainder;
    logic guard_bit, round_bit, sticky_bit, discarded, round_up, invalid;
    integer exp_encoded;

    frac_bits = is_single_i ? 23 : 52;
    bias = is_single_i ? 127 : 1023;
    emin = 1 - bias;
    sign = is_single_i ? operand_i[31] : operand_i[63];
    exp_field = is_single_i ? {3'b0, operand_i[30:23]} : operand_i[62:52];
    fraction = is_single_i ? {29'b0, operand_i[22:0]} : operand_i[51:0];
    is_nan = (exp_field == (is_single_i ? 11'h0ff : 11'h7ff)) && (fraction != 0);
    is_snan = is_nan && !(is_single_i ? fraction[22] : fraction[51]);
    is_inf = (exp_field == (is_single_i ? 11'h0ff : 11'h7ff)) && (fraction == 0);
    is_zero = (exp_field == 0) && (fraction == 0);
    boxing_error = is_single_i && (operand_i[63:32] != 32'hffff_ffff);
    exponent = (exp_field == 0) ? emin : (integer'(exp_field) - bias);
    significand = {1'b0, fraction};
    if (exp_field != 0) significand[frac_bits] = 1'b1;
    top_bit = 0;
    for (int i = 0; i <= 52; i++) if (significand[i]) top_bit = i;
    if (!is_zero && !is_inf && !is_nan && top_bit < frac_bits) begin
      significand = significand << (frac_bits - top_bit);
      exponent = exponent - (frac_bits - top_bit);
    end
    exp_result = exponent >>> 1;
    exp_encoded = 0;
    radicand = {75'd0, significand} << (frac_bits + 6);
    if (exponent[0]) radicand = radicand << 1;
    root = integer_sqrt(radicand);
    ext_sig = root[55:0];
    root_wide = {64'd0, root};
    square_remainder = radicand - (root_wide * root_wide);
    guard_bit = ext_sig[2];
    round_bit = ext_sig[1];
    sticky_bit = ext_sig[0] || (square_remainder != 0);
    discarded = guard_bit || round_bit || sticky_bit;
    case (rounding_mode_i)
      3'b000: round_up = guard_bit && (round_bit || sticky_bit || ext_sig[3]);
      3'b001: round_up = 1'b0;
      3'b010: round_up = sign && discarded;
      3'b011: round_up = !sign && discarded;
      3'b100: round_up = guard_bit;
      default: round_up = 1'b0;
    endcase
    rounded_sig = ext_sig[55:3] + round_up;
    if (rounded_sig[frac_bits+1]) begin
      rounded_sig = rounded_sig >> 1;
      exp_result = exp_result + 1;
    end
    invalid = !boxing_error && (is_snan || (sign && !is_zero && !is_nan));
    result_o = '0;
    flags_o = '0;
    if (boxing_error) begin
      result_o = 64'hffff_ffff_7fc0_0000;
    end else if (is_nan) begin
      if (is_single_i) result_o = 64'hffff_ffff_7fc0_0000;
      else result_o = 64'h7ff8_0000_0000_0000;
    end else if (sign && !is_zero) begin
      if (is_single_i) result_o = 64'hffff_ffff_7fc0_0000;
      else result_o = 64'h7ff8_0000_0000_0000;
    end else if (is_inf || is_zero) begin
      if (is_single_i) result_o = {32'hffff_ffff, sign, 8'hff, 23'd0};
      else result_o = {sign, 11'h7ff, 52'd0};
      if (is_zero) begin
        if (is_single_i) result_o = {32'hffff_ffff, sign, 31'd0};
        else result_o = {sign, 63'd0};
      end
    end else if (is_single_i) begin
      exp_encoded = exp_result + bias;
      result_o = {32'hffff_ffff, 1'b0, exp_encoded[7:0], rounded_sig[22:0]};
    end else begin
      exp_encoded = exp_result + bias;
      result_o = {1'b0, exp_encoded[10:0], rounded_sig[51:0]};
    end
    flags_o[4] = invalid;
    if (!invalid && !is_nan && !is_inf && !is_zero && !boxing_error)
      flags_o[0] = discarded;
  end
endmodule

`endif // MOON_FPU_SQRT_SV
