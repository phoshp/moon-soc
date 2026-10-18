// ============================================================================
// File: rtl/core/moon_fpu_intcvt.sv
// Description: RV64 F/D conversions between binary floats and 32/64-bit ints.
// ============================================================================

`ifndef MOON_FPU_INTCVT_SV
`define MOON_FPU_INTCVT_SV

`include "moon_pkg.sv"

module moon_fpu_intcvt
  import moon_pkg::*;
(
  input  logic [FLEN-1:0] operand_i,
  input  logic [31:0]     instruction_i,
  input  logic [2:0]      rounding_mode_i,
  output logic [FLEN-1:0] result_o,
  output logic [4:0]      flags_o
);
  always_comb begin : fp_int_cvt_comb
    logic [6:0] funct7;
    logic [4:0] cvt_type;
    logic is_single;
    logic is_signed;
    logic is_word;
    logic int_to_fp;
    logic sign;
    logic [63:0] integer_value;
    logic [63:0] magnitude64;
    logic [52:0] significand;
    logic [55:0] extended_sig;
    logic [53:0] rounded_sig;
    logic [10:0] exp_field;
    logic [51:0] fraction;
    logic [127:0] magnitude;
    logic [127:0] max_value;
    logic [127:0] min_signed_magnitude;
    integer frac_bits;
    integer bias;
    integer emin;
    integer exponent;
    integer top_bit;
    integer shift_amount;
    integer exp_result;
    logic is_nan;
    logic is_inf;
    logic discarded;
    logic guard_bit;
    logic sticky_bit;
    logic round_up;
    logic invalid;
    logic too_large;

    funct7 = instruction_i[31:25];
    cvt_type = instruction_i[24:20];
    int_to_fp = (funct7 == 7'b1101000) || (funct7 == 7'b1101001);
    is_single = (funct7 == 7'b1100000) || (funct7 == 7'b1101000);
    is_signed = !cvt_type[0];
    is_word = !cvt_type[1];
    sign = 1'b0;
    integer_value = operand_i;
    magnitude64 = '0;
    significand = '0;
    extended_sig = '0;
    rounded_sig = '0;
    exp_field = '0;
    fraction = '0;
    magnitude = '0;
    max_value = '0;
    min_signed_magnitude = '0;
    frac_bits = is_single ? 23 : 52;
    bias = is_single ? 127 : 1023;
    emin = 1 - bias;
    exponent = 0;
    top_bit = 0;
    shift_amount = 0;
    exp_result = 0;
    is_nan = 1'b0;
    is_inf = 1'b0;
    discarded = 1'b0;
    guard_bit = 1'b0;
    sticky_bit = 1'b0;
    round_up = 1'b0;
    invalid = 1'b0;
    too_large = 1'b0;
    result_o = '0;
    flags_o = '0;

    if (int_to_fp) begin
      if (is_word) begin
        sign = is_signed && operand_i[31];
        integer_value = {32'd0, operand_i[31:0]};
        if (sign) magnitude64 = {32'd0, (~operand_i[31:0] + 32'd1)};
        else magnitude64 = integer_value;
      end else begin
        sign = is_signed && operand_i[63];
        if (sign) magnitude64 = ~operand_i + 64'd1;
        else magnitude64 = operand_i;
      end
      for (int i = 0; i < 64; i++) if (magnitude64[i]) top_bit = i;
      if (magnitude64 != 0) begin
        shift_amount = frac_bits + 3 - top_bit;
        if (shift_amount >= 0) extended_sig = {1'b0, magnitude64} << shift_amount;
        else begin
          shift_amount = -shift_amount;
          extended_sig = {1'b0, magnitude64} >> shift_amount;
          if (shift_amount >= 64) begin
            sticky_bit = |magnitude64;
          end else if (shift_amount > 0) begin
            sticky_bit = |(magnitude64 & ((64'd1 << shift_amount) - 64'd1));
          end
          extended_sig[0] |= sticky_bit;
        end
        discarded = |extended_sig[2:0];
        case (rounding_mode_i)
          3'b000: round_up = extended_sig[2] && (extended_sig[1] || extended_sig[0] || extended_sig[3]);
          3'b001: round_up = 1'b0;
          3'b010: round_up = sign && discarded;
          3'b011: round_up = !sign && discarded;
          3'b100: round_up = extended_sig[2];
          default: round_up = 1'b0;
        endcase
        rounded_sig = extended_sig[55:3] + round_up;
        exp_result = top_bit;
        if (rounded_sig[frac_bits+1]) begin
          rounded_sig >>= 1;
          exp_result++;
        end
        exp_field = exp_result + bias;
        if (is_single)
          result_o = {32'hffff_ffff, sign, exp_field[7:0], rounded_sig[22:0]};
        else
          result_o = {sign, exp_field[10:0], rounded_sig[51:0]};
        flags_o[0] = discarded;
      end else if (is_single) begin
        result_o = 64'hffff_ffff_0000_0000;
      end
    end else begin
      // Floating-point to integer conversion.
      frac_bits = is_single ? 23 : 52;
      bias = is_single ? 127 : 1023;
      emin = 1 - bias;
      sign = is_single ? operand_i[31] : operand_i[63];
      exp_field = is_single ? {3'b0, operand_i[30:23]} : operand_i[62:52];
      fraction = is_single ? {29'b0, operand_i[22:0]} : operand_i[51:0];
      is_nan = (exp_field == (is_single ? 11'h0ff : 11'h7ff)) && (fraction != 0);
      is_inf = (exp_field == (is_single ? 11'h0ff : 11'h7ff)) && (fraction == 0);
      if (is_single && (operand_i[63:32] != 32'hffff_ffff)) is_nan = 1'b1;
      significand = {1'b0, fraction};
      if (exp_field != 0) significand[frac_bits] = 1'b1;
      exponent = (exp_field == 0) ? emin : (integer'(exp_field) - bias);
      shift_amount = exponent - frac_bits;
      if (shift_amount >= 0) begin
        if (shift_amount > 74) too_large = 1'b1;
        else magnitude = {75'd0, significand} << shift_amount;
      end else begin
        shift_amount = -shift_amount;
        if (shift_amount > 53) begin
          magnitude = '0;
          sticky_bit = |significand;
          guard_bit = 1'b0;
        end else if (shift_amount == 53) begin
          magnitude = '0;
          guard_bit = significand[52];
          sticky_bit = |significand[51:0];
        end else begin
          magnitude = significand >> shift_amount;
          guard_bit = significand[shift_amount-1];
          if (shift_amount > 1) begin
            sticky_bit = |(significand & ((53'd1 << (shift_amount - 1)) - 53'd1));
          end
        end
        discarded = guard_bit || sticky_bit;
        case (rounding_mode_i)
          3'b000: round_up = guard_bit && (sticky_bit || magnitude[0]);
          3'b001: round_up = 1'b0;
          3'b010: round_up = sign && discarded;
          3'b011: round_up = !sign && discarded;
          3'b100: round_up = guard_bit;
          default: round_up = 1'b0;
        endcase
        magnitude += round_up;
      end
      if (!is_word) begin
        max_value = is_signed ? ((128'd1 << 63) - 1) : ((128'd1 << 64) - 1);
        min_signed_magnitude = 128'd1 << 63;
      end else begin
        max_value = is_signed ? ((128'd1 << 31) - 1) : ((128'd1 << 32) - 1);
        min_signed_magnitude = 128'd1 << 31;
      end
      if (is_nan || is_inf || too_large) begin
        invalid = 1'b1;
        if (is_signed) magnitude = sign ? min_signed_magnitude : max_value;
        else magnitude = sign ? 128'd0 : max_value;
      end else if (is_signed) begin
        if ((!sign && (magnitude > max_value)) ||
            (sign && (magnitude > min_signed_magnitude))) begin
          invalid = 1'b1;
          magnitude = sign ? min_signed_magnitude : max_value;
        end
      end else if (sign && (magnitude != 0)) begin
        invalid = 1'b1;
        magnitude = '0;
      end else if (magnitude > max_value) begin
        invalid = 1'b1;
        magnitude = max_value;
      end
      if (invalid) flags_o[4] = 1'b1;
      else flags_o[0] = discarded;
      if (sign && is_signed) magnitude = (~magnitude) + 1'b1;
      if (is_word) result_o = {{32{magnitude[31]}}, magnitude[31:0]};
      else result_o = magnitude[63:0];
    end
  end
endmodule

`endif // MOON_FPU_INTCVT_SV
