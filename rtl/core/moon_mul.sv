// ============================================================================
// File: rtl/core/moon_mul.sv
// Description: RV64M Hardware Multiplier supporting MUL, MULH, MULHU,
//              MULHSU, and MULW using a compact multi-cycle 32x32-bit iterative
//              multiplier core.
//              Optimized for clean ASIC standard-cell synthesis and fast timing.
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
  input  logic             advance_i,
  input  muldiv_op_e       op_i,
  input  logic [XLEN-1:0]  operand_a_i,
  input  logic [XLEN-1:0]  operand_b_i,
  output logic             ready_o,
  output logic [XLEN-1:0]  result_o
);

  typedef enum logic [2:0] {
    MUL_IDLE,
    MUL_STEP1,
    MUL_STEP2,
    MUL_STEP3,
    MUL_DONE
  } mul_state_e;

  mul_state_e state_q, state_d;

  logic [XLEN-1:0]   a_q, a_d;
  logic [XLEN-1:0]   b_q, b_d;
  muldiv_op_e        op_q, op_d;

  logic [63:0]       p0_q, p0_d;
  logic [63:0]       p1_q, p1_d;
  logic [63:0]       p2_q, p2_d;
  logic [63:0]       p3_q, p3_d;
  logic [XLEN-1:0]   result_q, result_d;

  // Single 32x32 unsigned multiplier core
  logic [31:0] mul_src_a, mul_src_b;
  wire  [63:0] mul_core_prod = {32'd0, mul_src_a} * {32'd0, mul_src_b};

  // Intermediate summation nets
  wire [65:0] mid_sum_full = {34'd0, p0_q[63:32]} + {2'b0, p1_q} + {2'b0, p2_q};
  wire [63:0] high_unsigned = mul_core_prod + mid_sum_full[65:32];

  wire is_a_signed = (op_q == MULDIV_MULH) || (op_q == MULDIV_MULHSU);
  wire is_b_signed = (op_q == MULDIV_MULH);
  wire [63:0] adj_a = (is_a_signed && a_q[63]) ? b_q : 64'd0;
  wire [63:0] adj_b = (is_b_signed && b_q[63]) ? a_q : 64'd0;
  wire [63:0] high_signed = high_unsigned - adj_a - adj_b;

  always_comb begin
    logic [31:0] mid_32;
    mid_32    = 32'd0;
    state_d   = state_q;
    a_d       = a_q;
    b_d       = b_q;
    op_d      = op_q;
    p0_d      = p0_q;
    p1_d      = p1_q;
    p2_d      = p2_q;
    p3_d      = p3_q;
    result_d  = result_q;
    ready_o   = 1'b0;

    mul_src_a = 32'd0;
    mul_src_b = 32'd0;

    case (state_q)
      MUL_IDLE: begin
        if (valid_i) begin
          a_d  = operand_a_i;
          b_d  = operand_b_i;
          op_d = op_i;

          // Multiply A_lo * B_lo
          mul_src_a = operand_a_i[31:0];
          mul_src_b = operand_b_i[31:0];
          p0_d      = mul_core_prod;

          if (op_i == MULDIV_MULW) begin
            // 32-bit word multiply: lower 32 bits are ready in 1 cycle
            result_d = {{32{mul_core_prod[31]}}, mul_core_prod[31:0]};
            state_d  = MUL_DONE;
          end else begin
            state_d  = MUL_STEP1;
          end
        end
      end

      MUL_STEP1: begin
        // Multiply A_lo * B_hi
        mul_src_a = a_q[31:0];
        mul_src_b = b_q[63:32];
        p1_d      = mul_core_prod;
        state_d   = MUL_STEP2;
      end

      MUL_STEP2: begin
        // Multiply A_hi * B_lo
        mul_src_a = a_q[63:32];
        mul_src_b = b_q[31:0];
        p2_d      = mul_core_prod;

        if (op_q == MULDIV_MUL) begin
          // Standard 64-bit MUL only requires lower 64 bits:
          // Low 32 bits: p0_q[31:0]
          // High 32 bits: p0_q[63:32] + p1_q[31:0] + mul_core_prod[31:0]
          mid_32 = p0_q[63:32] + p1_q[31:0] + mul_core_prod[31:0];
          result_d = {mid_32, p0_q[31:0]};
          state_d  = MUL_DONE;
        end else begin
          state_d  = MUL_STEP3;
        end
      end

      MUL_STEP3: begin
        // Multiply A_hi * B_hi for upper 64 bits (MULH, MULHU, MULHSU)
        mul_src_a = a_q[63:32];
        mul_src_b = b_q[63:32];
        p3_d      = mul_core_prod;

        if (op_q == MULDIV_MULHU) begin
          result_d = high_unsigned;
        end else begin
          result_d = high_signed;
        end
        state_d = MUL_DONE;
      end

      MUL_DONE: begin
        ready_o = 1'b1;
        if (advance_i || !valid_i) begin
          state_d = MUL_IDLE;
        end
      end

      default: state_d = MUL_IDLE;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q  <= MUL_IDLE;
      a_q      <= '0;
      b_q      <= '0;
      op_q     <= MULDIV_NONE;
      p0_q     <= '0;
      p1_q     <= '0;
      p2_q     <= '0;
      p3_q     <= '0;
      result_q <= '0;
    end else begin
      state_q  <= state_d;
      a_q      <= a_d;
      b_q      <= b_d;
      op_q     <= op_d;
      p0_q     <= p0_d;
      p1_q     <= p1_d;
      p2_q     <= p2_d;
      p3_q     <= p3_d;
      result_q <= result_d;
    end
  end

  assign result_o = result_q;

endmodule : moon_mul

`endif // MOON_MUL_SV
