// ============================================================================
// File: rtl/core/moon_div.sv
// Description: RV64M Hardware Divider implementing DIV, DIVU, REM, REMU,
//              DIVW, DIVUW, REMW, REMUW with RISC-V compliant corner cases.
// ============================================================================

`ifndef MOON_DIV_SV
`define MOON_DIV_SV

`include "moon_pkg.sv"

module moon_div
  import moon_pkg::*;
(
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic             valid_i,
  input  logic             advance_i,
  input  muldiv_op_e       op_i,
  input  logic [XLEN-1:0]  operand_a_i,
  input  logic [XLEN-1:0]  operand_b_i,
  output logic             ready_o,
  output logic [XLEN-1:0]  result_o
);

  typedef enum logic [1:0] {
    DIV_IDLE,
    DIV_CALC,
    DIV_DONE
  } div_state_e;

  div_state_e state_q, state_d;

  logic [5:0]  count_q, count_d;
  logic [63:0] dividend_abs;
  logic [63:0] divisor_abs;
  logic        sign_res_quot;
  logic        sign_res_rem;
  logic        is_word_op;
  logic        is_rem_op;
  logic        is_signed_op;

  logic [63:0] quotient_q, quotient_d;
  logic [64:0] remainder_q, remainder_d;
  logic [63:0] divisor_q, divisor_d;
  logic        res_sign_q, res_sign_d;
  logic        is_rem_q, is_rem_d;
  logic        is_word_q, is_word_d;
  logic [63:0] orig_a_q, orig_a_d;
  logic [63:0] orig_b_q, orig_b_d;
  logic        is_signed_q, is_signed_d;

  // Decode operation attributes
  always_comb begin
    is_word_op   = (op_i == MULDIV_DIVW)  || (op_i == MULDIV_DIVUW) ||
                   (op_i == MULDIV_REMW)  || (op_i == MULDIV_REMUW);
    is_rem_op    = (op_i == MULDIV_REM)   || (op_i == MULDIV_REMU) ||
                   (op_i == MULDIV_REMW)  || (op_i == MULDIV_REMUW);
    is_signed_op = (op_i == MULDIV_DIV)   || (op_i == MULDIV_REM) ||
                   (op_i == MULDIV_DIVW)  || (op_i == MULDIV_REMW);

    // Absolute value conversion
    if (is_word_op) begin
      if (is_signed_op) begin
        dividend_abs = operand_a_i[31] ? -{{32{operand_a_i[31]}}, operand_a_i[31:0]} : {{32{1'b0}}, operand_a_i[31:0]};
        divisor_abs  = operand_b_i[31] ? -{{32{operand_b_i[31]}}, operand_b_i[31:0]} : {{32{1'b0}}, operand_b_i[31:0]};
        sign_res_quot = (operand_a_i[31] ^ operand_b_i[31]) && (operand_b_i[31:0] != 32'd0);
        sign_res_rem  = operand_a_i[31];
      end else begin
        dividend_abs  = {{32{1'b0}}, operand_a_i[31:0]};
        divisor_abs   = {{32{1'b0}}, operand_b_i[31:0]};
        sign_res_quot = 1'b0;
        sign_res_rem  = 1'b0;
      end
    end else begin
      if (is_signed_op) begin
        dividend_abs  = operand_a_i[63] ? -operand_a_i : operand_a_i;
        divisor_abs   = operand_b_i[63] ? -operand_b_i : operand_b_i;
        sign_res_quot = (operand_a_i[63] ^ operand_b_i[63]) && (operand_b_i != 64'd0);
        sign_res_rem  = operand_a_i[63];
      end else begin
        dividend_abs  = operand_a_i;
        divisor_abs   = operand_b_i;
        sign_res_quot = 1'b0;
        sign_res_rem  = 1'b0;
      end
    end
  end

  // Shift and subtract non-restoring divider core
  logic [64:0] rem_shifted;
  logic [64:0] rem_sub;
  assign rem_shifted = {remainder_q[63:0], quotient_q[63]};
  assign rem_sub     = rem_shifted - {1'b0, divisor_q};

  always_comb begin
    state_d     = state_q;
    count_d     = count_q;
    quotient_d  = quotient_q;
    remainder_d = remainder_q;
    divisor_d   = divisor_q;
    res_sign_d  = res_sign_q;
    is_rem_d    = is_rem_q;
    is_word_d   = is_word_q;
    orig_a_d    = orig_a_q;
    orig_b_d    = orig_b_q;
    is_signed_d = is_signed_q;

    case (state_q)
      DIV_IDLE: begin
        if (valid_i) begin
          orig_a_d    = operand_a_i;
          orig_b_d    = operand_b_i;
          is_signed_d = is_signed_op;
          is_rem_d    = is_rem_op;
          is_word_d   = is_word_op;
          res_sign_d  = is_rem_op ? sign_res_rem : sign_res_quot;
          divisor_d   = divisor_abs;
          quotient_d  = dividend_abs;
          remainder_d = '0;
          count_d     = 6'd63;

          // Corner case check: Divisor == 0
          if (divisor_abs == '0) begin
            state_d = DIV_DONE;
          end else begin
            state_d = DIV_CALC;
          end
        end
      end

      DIV_CALC: begin
        if (rem_sub[64] == 1'b0) begin // Fits
          remainder_d = rem_sub;
          quotient_d  = {quotient_q[62:0], 1'b1};
        end else begin
          remainder_d = rem_shifted;
          quotient_d  = {quotient_q[62:0], 1'b0};
        end

        if (count_q == 6'd0) begin
          state_d = DIV_DONE;
        end else begin
          count_d = count_q - 1'b1;
        end
      end

      DIV_DONE: begin
        if (advance_i || !valid_i) begin
          state_d = DIV_IDLE;
        end
      end

      default: state_d = DIV_IDLE;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q     <= DIV_IDLE;
      count_q     <= '0;
      quotient_q  <= '0;
      remainder_q <= '0;
      divisor_q   <= '0;
      res_sign_q  <= '0;
      is_rem_q    <= '0;
      is_word_q   <= '0;
      orig_a_q    <= '0;
      orig_b_q    <= '0;
      is_signed_q <= '0;
    end else begin
      state_q     <= state_d;
      count_q     <= count_d;
      quotient_q  <= quotient_d;
      remainder_q <= remainder_d;
      divisor_q   <= divisor_d;
      res_sign_q  <= res_sign_d;
      is_rem_q    <= is_rem_d;
      is_word_q   <= is_word_d;
      orig_a_q    <= orig_a_d;
      orig_b_q    <= orig_b_d;
      is_signed_q <= is_signed_d;
    end
  end

  // Final Result Computation with RISC-V corner case handling
  logic [63:0] final_val;
  always_comb begin
    // Div by zero handling
    if (divisor_q == 64'd0) begin
      if (is_rem_q) begin
        final_val = is_word_q ? {{32{orig_a_q[31]}}, orig_a_q[31:0]} : orig_a_q;
      end else begin
        final_val = 64'hFFFFFFFF_FFFFFFFF;
      end
    end else begin
      // Overflow handling: signed -2^63 / -1
      if (!is_rem_q && is_signed_q && orig_a_q == 64'h80000000_00000000 && orig_b_q == 64'hFFFFFFFF_FFFFFFFF) begin
        final_val = 64'h80000000_00000000;
      end else if (is_rem_q && is_signed_q && orig_a_q == 64'h80000000_00000000 && orig_b_q == 64'hFFFFFFFF_FFFFFFFF) begin
        final_val = 64'd0;
      end else if (is_rem_q) begin
        final_val = res_sign_q ? -remainder_q[63:0] : remainder_q[63:0];
      end else begin
        final_val = res_sign_q ? -quotient_q : quotient_q;
      end
    end

    if (is_word_q) begin
      result_o = {{32{final_val[31]}}, final_val[31:0]};
    end else begin
      result_o = final_val;
    end
  end

  assign ready_o = (state_q == DIV_DONE);

endmodule : moon_div

`endif // MOON_DIV_SV
