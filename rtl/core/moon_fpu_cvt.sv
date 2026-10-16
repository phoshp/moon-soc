// ============================================================================
// File: rtl/core/moon_fpu_cvt.sv
// Description: IEEE-754 binary32/binary64 precision conversion.
// ============================================================================

`ifndef MOON_FPU_CVT_SV
`define MOON_FPU_CVT_SV

`include "moon_pkg.sv"

module moon_fpu_cvt
  import moon_pkg::*;
(
  input  logic [FLEN-1:0] operand_i,
  input  logic            single_source_i,
  input  logic [2:0]      rounding_mode_i,
  output logic [FLEN-1:0] result_o,
  output logic [4:0]      flags_o
);

  always_comb begin : fp_cvt_comb
    integer source_exponent;
    integer target_exponent;
    integer source_top;
    integer shift_amount;
    integer exp_field;
    logic sign;
    logic [10:0] source_exp;
    logic [51:0] source_frac;
    logic [52:0] source_sig;
    logic [26:0] extended_sig;
    logic [24:0] rounded_sig;
    logic is_nan;
    logic is_snan;
    logic is_inf;
    logic is_zero;
    logic boxing_error;
    logic sticky;
    logic discarded;
    logic round_up;
    logic tiny;

    result_o = '0;
    flags_o = '0;
    sign = single_source_i ? operand_i[31] : operand_i[63];
    source_exp = single_source_i ? {3'b0, operand_i[30:23]} : operand_i[62:52];
    source_frac = single_source_i ? {29'b0, operand_i[22:0]} : operand_i[51:0];
    is_nan = (source_exp == (single_source_i ? 11'h0ff : 11'h7ff)) && (source_frac != 0);
    is_snan = is_nan && !source_frac[single_source_i ? 22 : 51];
    is_inf = (source_exp == (single_source_i ? 11'h0ff : 11'h7ff)) && (source_frac == 0);
    is_zero = (source_exp == 0) && (source_frac == 0);
    boxing_error = single_source_i && (operand_i[63:32] != 32'hffff_ffff);
    source_exponent = 0;
    target_exponent = 0;
    source_top = 0;
    shift_amount = 0;
    exp_field = 0;
    source_sig = '0;
    extended_sig = '0;
    rounded_sig = '0;
    sticky = 1'b0;
    discarded = 1'b0;
    round_up = 1'b0;
    tiny = 1'b0;

    if (boxing_error || is_nan) begin
      if (single_source_i)
        result_o = {sign, 11'h7ff, 1'b1, 51'd0};
      else
        result_o = {32'hffff_ffff, 1'b0, 8'hff, 1'b1, 22'd0};
      flags_o[4] = is_snan;
    end else if (is_inf) begin
      if (single_source_i) result_o = {sign, 11'h7ff, 52'd0};
      else result_o = {32'hffff_ffff, sign, 8'hff, 23'd0};
    end else if (is_zero) begin
      if (single_source_i) result_o = {sign, 63'd0};
      else result_o = {32'hffff_ffff, sign, 31'd0};
    end else if (single_source_i) begin
      // Every binary32 finite value is represented exactly in binary64.
      if (source_exp == 0) begin
        for (int i = 0; i < 23; i++) if (source_frac[i]) source_top = i;
        source_exponent = source_top - 149;
        source_sig[22:0] = source_frac[22:0] << (23 - source_top);
        source_sig[23] = 1'b1;
      end else begin
        source_exponent = integer'(source_exp) - 127;
        source_sig[23] = 1'b1;
        source_sig[22:0] = source_frac[22:0];
      end
      exp_field = source_exponent + 1023;
      result_o = {sign, exp_field[10:0], source_sig[22:0], 29'd0};
    end else begin
      // Normalize binary64, then retain binary32's 24 significant bits and GRS.
      if (source_exp == 0) begin
        for (int i = 0; i < 52; i++) if (source_frac[i]) source_top = i;
        source_exponent = source_top - 1074;
        source_sig = {1'b0, source_frac} << (52 - source_top);
      end else begin
        source_exponent = integer'(source_exp) - 1023;
        source_sig = {1'b1, source_frac};
      end
      extended_sig = source_sig >> 26;
      sticky = |source_sig[25:0];
      extended_sig[0] = extended_sig[0] | sticky;
      target_exponent = source_exponent;
      if (target_exponent < -126) begin
        tiny = 1'b1;
        shift_amount = -126 - target_exponent;
        sticky = 1'b0;
        for (int i = 0; i < 1100; i++) begin
          if (i < shift_amount) begin
            sticky = sticky | extended_sig[0];
            extended_sig = {1'b0, extended_sig[26:1]};
          end
        end
        extended_sig[0] = extended_sig[0] | sticky;
        target_exponent = -126;
      end
      discarded = |extended_sig[2:0];
      case (rounding_mode_i)
        3'b000: round_up = extended_sig[2] &&
                           (extended_sig[1] || extended_sig[0] || extended_sig[3]);
        3'b001: round_up = 1'b0;
        3'b010: round_up = sign && discarded;
        3'b011: round_up = !sign && discarded;
        3'b100: round_up = extended_sig[2];
        3'b101: round_up = 1'b0; // Round-to-odd (jamming)
        default: round_up = 1'b0;
      endcase
      rounded_sig = extended_sig[26:3] + round_up;
      if (rounding_mode_i == 3'b101 && discarded && !extended_sig[3])
        rounded_sig[0] = 1'b1;
      if (rounded_sig[24]) begin
        rounded_sig = rounded_sig >> 1;
        target_exponent = target_exponent + 1;
      end
      if (target_exponent > 127) begin
        flags_o[2] = 1'b1;
        flags_o[0] = 1'b1;
        if ((rounding_mode_i == 3'b001) ||
            (rounding_mode_i == 3'b101) ||
            ((rounding_mode_i == 3'b010) && !sign) ||
            ((rounding_mode_i == 3'b011) && sign))
          result_o = {32'hffff_ffff, sign, 8'hfe, 23'h7fffff};
        else
          result_o = {32'hffff_ffff, sign, 8'hff, 23'd0};
      end else if ((target_exponent == -126) && !rounded_sig[23]) begin
        result_o = {32'hffff_ffff, sign, 8'd0, rounded_sig[22:0]};
        flags_o[1] = tiny && discarded;
        flags_o[0] = discarded;
      end else begin
        exp_field = target_exponent + 127;
        result_o = {32'hffff_ffff, sign, exp_field[7:0], rounded_sig[22:0]};
        flags_o[0] = discarded;
      end
    end
  end
endmodule

`endif // MOON_FPU_CVT_SV
