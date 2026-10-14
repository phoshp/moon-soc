// ============================================================================
// File: rtl/core/moon_fpu_fma.sv
// Description: IEEE-754 binary32/binary64 fused multiply-add operations.
// ============================================================================

`ifndef MOON_FPU_FMA_SV
`define MOON_FPU_FMA_SV

`include "moon_pkg.sv"

module moon_fpu_fma
  import moon_pkg::*;
(
  input  logic [FLEN-1:0] operand_a_i,
  input  logic [FLEN-1:0] operand_b_i,
  input  logic [FLEN-1:0] operand_c_i,
  input  logic [1:0]      format_i,
  input  logic [6:0]      opcode_i,
  input  logic [2:0]      rounding_mode_i,
  output logic [FLEN-1:0] result_o,
  output logic [4:0]      flags_o
);
  function automatic logic [127:0] shift_right_jam128(
      input logic [127:0] value, input integer amount);
    logic sticky;
    begin
      if (amount <= 0) begin
        shift_right_jam128 = value;
      end else if (amount >= 128) begin
        shift_right_jam128 = {127'd0, (value != 0)};
      end else begin
        shift_right_jam128 = value >> amount;
        sticky = |(value << (128 - amount));
        shift_right_jam128[0] = shift_right_jam128[0] | sticky;
      end
    end
  endfunction

  function automatic logic [55:0] shift_right_jam56(
      input logic [55:0] value, input integer amount);
    logic sticky;
    begin
      if (amount <= 0) begin
        shift_right_jam56 = value;
      end else if (amount >= 56) begin
        shift_right_jam56 = {55'd0, (value != 0)};
      end else begin
        shift_right_jam56 = value >> amount;
        sticky = |(value << (56 - amount));
        shift_right_jam56[0] = shift_right_jam56[0] | sticky;
      end
    end
  endfunction

  always_comb begin : fp_fma_comb
    integer frac_bits, bias, emin, emax;
    integer exp_a, exp_b, exp_c, exp_prod_top, common_top, exp_result;
    integer top_a, top_b, top_c, top_result, shift_amount, exp_field;
    logic sign_a, sign_b, sign_c, sign_prod, sign_c_eff, sign_result;
    logic [10:0] exp_field_a, exp_field_b, exp_field_c;
    logic [51:0] frac_a, frac_b, frac_c;
    logic [52:0] sig_a, sig_b, sig_c;
    logic [105:0] product;
    logic [127:0] product_norm, c_norm, term_product, term_c, result_mag;
    logic [55:0] ext_sig;
    logic [53:0] rounded_sig;
    logic nan_a, nan_b, nan_c, snan_a, snan_b, snan_c;
    logic inf_a, inf_b, inf_c, zero_a, zero_b, zero_c;
    logic invalid_product, invalid_inf_sum, invalid;
    logic overflow, underflow, inexact;
    logic boxing_error, box_a_error, box_b_error, box_c_error, negate_product, negate_c;
    logic same_sign, result_is_zero;
    logic sticky_from_norm, guard_bit, round_bit, sticky_bit, discarded, round_up;

    frac_bits = (format_i == 2'b00) ? 23 : 52;
    bias = (format_i == 2'b00) ? 127 : 1023;
    emin = 1 - bias;
    emax = bias;
    negate_product = (opcode_i == 7'b1001011) || (opcode_i == 7'b1001111);
    negate_c = (opcode_i == 7'b1000111) || (opcode_i == 7'b1001111);
    sign_a = (format_i == 2'b00) ? operand_a_i[31] : operand_a_i[63];
    sign_b = (format_i == 2'b00) ? operand_b_i[31] : operand_b_i[63];
    sign_c = (format_i == 2'b00) ? operand_c_i[31] : operand_c_i[63];
    sign_prod = sign_a ^ sign_b ^ negate_product;
    sign_c_eff = sign_c ^ negate_c;
    exp_field_a = (format_i == 2'b00) ? {3'b0, operand_a_i[30:23]} : operand_a_i[62:52];
    exp_field_b = (format_i == 2'b00) ? {3'b0, operand_b_i[30:23]} : operand_b_i[62:52];
    exp_field_c = (format_i == 2'b00) ? {3'b0, operand_c_i[30:23]} : operand_c_i[62:52];
    frac_a = (format_i == 2'b00) ? {29'b0, operand_a_i[22:0]} : operand_a_i[51:0];
    frac_b = (format_i == 2'b00) ? {29'b0, operand_b_i[22:0]} : operand_b_i[51:0];
    frac_c = (format_i == 2'b00) ? {29'b0, operand_c_i[22:0]} : operand_c_i[51:0];
    nan_a = (exp_field_a == ((format_i == 2'b00) ? 11'h0ff : 11'h7ff)) && (frac_a != 0);
    nan_b = (exp_field_b == ((format_i == 2'b00) ? 11'h0ff : 11'h7ff)) && (frac_b != 0);
    nan_c = (exp_field_c == ((format_i == 2'b00) ? 11'h0ff : 11'h7ff)) && (frac_c != 0);
    snan_a = nan_a && !frac_a[frac_bits-1];
    snan_b = nan_b && !frac_b[frac_bits-1];
    snan_c = nan_c && !frac_c[frac_bits-1];
    inf_a = (exp_field_a == ((format_i == 2'b00) ? 11'h0ff : 11'h7ff)) && (frac_a == 0);
    inf_b = (exp_field_b == ((format_i == 2'b00) ? 11'h0ff : 11'h7ff)) && (frac_b == 0);
    inf_c = (exp_field_c == ((format_i == 2'b00) ? 11'h0ff : 11'h7ff)) && (frac_c == 0);
    zero_a = (exp_field_a == 0) && (frac_a == 0);
    zero_b = (exp_field_b == 0) && (frac_b == 0);
    zero_c = (exp_field_c == 0) && (frac_c == 0);
    box_a_error = (format_i == 2'b00) && (operand_a_i[63:32] != 32'hffff_ffff);
    box_b_error = (format_i == 2'b00) && (operand_b_i[63:32] != 32'hffff_ffff);
    box_c_error = (format_i == 2'b00) && (operand_c_i[63:32] != 32'hffff_ffff);
    boxing_error = box_a_error || box_b_error || box_c_error;
    invalid_product = ((inf_a && zero_b) && !box_a_error && !box_b_error) ||
                      ((inf_b && zero_a) && !box_a_error && !box_b_error);
    invalid_inf_sum = (inf_a || inf_b) && inf_c && !boxing_error &&
                      (sign_prod != sign_c_eff);
    invalid = (snan_a && !box_a_error) || (snan_b && !box_b_error) ||
              (snan_c && !box_c_error) || invalid_product || invalid_inf_sum;
    overflow = 1'b0;
    underflow = 1'b0;
    inexact = 1'b0;
    exp_a = (exp_field_a == 0) ? emin : (integer'(exp_field_a) - bias);
    exp_b = (exp_field_b == 0) ? emin : (integer'(exp_field_b) - bias);
    exp_c = (exp_field_c == 0) ? emin : (integer'(exp_field_c) - bias);
    sig_a = {1'b0, frac_a};
    sig_b = {1'b0, frac_b};
    sig_c = {1'b0, frac_c};
    if (exp_field_a != 0) sig_a[frac_bits] = 1'b1;
    if (exp_field_b != 0) sig_b[frac_bits] = 1'b1;
    if (exp_field_c != 0) sig_c[frac_bits] = 1'b1;
    top_a = 0;
    top_b = 0;
    top_c = 0;
    for (int i = 0; i <= 52; i++) begin
      if (sig_a[i]) top_a = i;
      if (sig_b[i]) top_b = i;
      if (sig_c[i]) top_c = i;
    end
    if ((exp_field_a == 0) && !zero_a) begin
      sig_a = sig_a << (frac_bits - top_a);
      exp_a = exp_a - (frac_bits - top_a);
    end
    if ((exp_field_b == 0) && !zero_b) begin
      sig_b = sig_b << (frac_bits - top_b);
      exp_b = exp_b - (frac_bits - top_b);
    end
    if ((exp_field_c == 0) && !zero_c) begin
      sig_c = sig_c << (frac_bits - top_c);
      exp_c = exp_c - (frac_bits - top_c);
    end
    product = sig_a * sig_b;
    top_a = 0;
    for (int i = 0; i < 106; i++) if (product[i]) top_a = i;
    exp_prod_top = exp_a + exp_b + top_a - (2 * frac_bits);
    product_norm = '0;
    c_norm = '0;
    if (!(zero_a || zero_b)) product_norm = {22'd0, product} << (120 - top_a);
    if (!zero_c) c_norm = {75'd0, sig_c} << (120 - frac_bits);
    term_product = '0;
    term_c = '0;
    common_top = 0;
    if (zero_a || zero_b) begin
      common_top = exp_c;
      term_c = c_norm;
    end else if (zero_c) begin
      common_top = exp_prod_top;
      term_product = product_norm;
    end else if (exp_prod_top >= exp_c) begin
      common_top = exp_prod_top;
      term_product = product_norm;
      term_c = shift_right_jam128(c_norm, exp_prod_top - exp_c);
    end else begin
      common_top = exp_c;
      term_product = shift_right_jam128(product_norm, exp_c - exp_prod_top);
      term_c = c_norm;
    end
    same_sign = (sign_prod == sign_c_eff);
    result_mag = '0;
    sign_result = sign_prod;
    if (same_sign) begin
      result_mag = term_product + term_c;
    end else if (term_product > term_c) begin
      result_mag = term_product - term_c;
      sign_result = sign_prod;
    end else if (term_c > term_product) begin
      result_mag = term_c - term_product;
      sign_result = sign_c_eff;
    end else begin
      sign_result = rounding_mode_i == 3'b010;
    end
    top_result = 0;
    result_is_zero = result_mag == 0;
    for (int i = 0; i < 128; i++) if (result_mag[i]) top_result = i;
    exp_result = common_top + top_result - 120;
    shift_amount = top_result - (frac_bits + 3);
    ext_sig = '0;
    sticky_from_norm = 1'b0;
    if (!result_is_zero) begin
      if (shift_amount > 0) begin
        ext_sig = result_mag >> shift_amount;
        for (int i = 0; i < 128; i++) if (i < shift_amount) sticky_from_norm |= result_mag[i];
      end else begin
        ext_sig = result_mag << (-shift_amount);
      end
      if (exp_result < emin) begin
        ext_sig = shift_right_jam56(ext_sig, emin - exp_result);
        exp_result = emin;
      end
    end
    guard_bit = ext_sig[2];
    round_bit = ext_sig[1];
    sticky_bit = ext_sig[0] || sticky_from_norm;
    discarded = guard_bit || round_bit || sticky_bit;
    case (rounding_mode_i)
      3'b000: round_up = guard_bit && (round_bit || sticky_bit || ext_sig[3]);
      3'b001: round_up = 1'b0;
      3'b010: round_up = sign_result && discarded;
      3'b011: round_up = !sign_result && discarded;
      3'b100: round_up = guard_bit;
      default: round_up = 1'b0;
    endcase
    rounded_sig = {1'b0, ext_sig[55:3]} + round_up;
    if (rounded_sig[frac_bits+1]) begin
      rounded_sig = rounded_sig >> 1;
      exp_result = exp_result + 1;
    end

    result_o = '0;
    flags_o = '0;
    exp_field = 0;
    if (boxing_error || nan_a || nan_b || nan_c || invalid_product || invalid_inf_sum) begin
      if (format_i == 2'b00) result_o = 64'hffff_ffff_7fc0_0000;
      else result_o = 64'h7ff8_0000_0000_0000;
    end else if (inf_a || inf_b || inf_c) begin
      if (inf_a || inf_b) begin
        if (format_i == 2'b00) result_o = {32'hffff_ffff, sign_prod, 8'hff, 23'd0};
        else result_o = {sign_prod, 11'h7ff, 52'd0};
      end else begin
        if (format_i == 2'b00) result_o = {32'hffff_ffff, sign_c_eff, 8'hff, 23'd0};
        else result_o = {sign_c_eff, 11'h7ff, 52'd0};
      end
    end else if (result_is_zero) begin
      if (format_i == 2'b00) result_o = {32'hffff_ffff, sign_result, 31'd0};
      else result_o = {sign_result, 63'd0};
    end else if (exp_result > emax) begin
      overflow = 1'b1;
      inexact = 1'b1;
      if ((rounding_mode_i == 3'b001) ||
          ((rounding_mode_i == 3'b010) && !sign_result) ||
          ((rounding_mode_i == 3'b011) && sign_result)) begin
        if (format_i == 2'b00) result_o = {32'hffff_ffff, sign_result, 8'hfe, 23'h7fffff};
        else result_o = {sign_result, 11'h7fe, 52'hf_ffff_ffff_ffff};
      end else if (format_i == 2'b00) begin
        result_o = {32'hffff_ffff, sign_result, 8'hff, 23'd0};
      end else begin
        result_o = {sign_result, 11'h7ff, 52'd0};
      end
    end else if ((exp_result == emin) && !rounded_sig[frac_bits]) begin
      underflow = discarded;
      inexact = discarded;
      if (format_i == 2'b00) result_o = {32'hffff_ffff, sign_result, 8'd0, rounded_sig[22:0]};
      else result_o = {sign_result, 11'd0, rounded_sig[51:0]};
    end else if (format_i == 2'b00) begin
      exp_field = exp_result + bias;
      result_o = {32'hffff_ffff, sign_result, exp_field[7:0], rounded_sig[22:0]};
      inexact = discarded;
    end else begin
      exp_field = exp_result + bias;
      result_o = {sign_result, exp_field[10:0], rounded_sig[51:0]};
      inexact = discarded;
    end
    flags_o = {invalid, 1'b0, overflow, underflow, inexact};
  end
endmodule

`endif // MOON_FPU_FMA_SV
