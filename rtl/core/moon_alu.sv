// ============================================================================
// File: rtl/core/moon_alu.sv
// Description: RV64I 64-bit Arithmetic Logic Unit supporting standard 64-bit
//              operations, 32-bit word operations, and RVA23 Bitmanipulation
//              extensions (Zba, Zbb, Zbs).
// ============================================================================

`ifndef MOON_ALU_SV
`define MOON_ALU_SV

`include "moon_pkg.sv"

module moon_alu
  import moon_pkg::*;
(
  input  alu_op_e          op_i,
  input  logic [XLEN-1:0]  operand_a_i,
  input  logic [XLEN-1:0]  operand_b_i,
  output logic [XLEN-1:0]  result_o,
  output logic             zero_o
);

  logic [5:0]  shamt64;
  logic [4:0]  shamt32;
  logic [31:0] a32;
  logic [31:0] b32;

  logic [31:0] res_addw;
  logic [31:0] res_subw;
  logic [31:0] res_sllw;
  logic [31:0] res_srlw;
  logic [31:0] res_sraw;
  logic [31:0] res_rolw;
  logic [31:0] res_rorw;

  assign shamt64 = operand_b_i[5:0];
  assign shamt32 = operand_b_i[4:0];
  assign a32     = operand_a_i[31:0];
  assign b32     = operand_b_i[31:0];

  // 32-bit Word intermediate operations
  assign res_addw = a32 + b32;
  assign res_subw = a32 - b32;
  assign res_sllw = a32 << shamt32;
  assign res_srlw = a32 >> shamt32;
  assign res_sraw = $signed(a32) >>> shamt32;
  assign res_rolw = (shamt32 == 5'd0) ? a32 : ((a32 << shamt32) | (a32 >> (6'd32 - {1'b0, shamt32})));
  assign res_rorw = (shamt32 == 5'd0) ? a32 : ((a32 >> shamt32) | (a32 << (6'd32 - {1'b0, shamt32})));

  // Helper functions for Bitmanipulation (Zbb)
  function automatic logic [6:0] count_leading_zeros_64(input logic [63:0] val);
    logic [6:0] count;
    count = 7'd64;
    for (int i = 63; i >= 0; i--) begin
      if (val[i]) begin
        count = 7'(63 - i);
        break;
      end
    end
    return count;
  endfunction

  function automatic logic [6:0] count_trailing_zeros_64(input logic [63:0] val);
    logic [6:0] count;
    count = 7'd64;
    for (int i = 0; i < 64; i++) begin
      if (val[i]) begin
        count = 7'(i);
        break;
      end
    end
    return count;
  endfunction

  function automatic logic [6:0] count_population_64(input logic [63:0] val);
    logic [6:0] count;
    count = 7'd0;
    for (int i = 0; i < 64; i++) begin
      if (val[i]) count = count + 7'd1;
    end
    return count;
  endfunction

  function automatic logic [5:0] count_leading_zeros_32(input logic [31:0] val);
    logic [5:0] count;
    count = 6'd32;
    for (int i = 31; i >= 0; i--) begin
      if (val[i]) begin
        count = 6'(31 - i);
        break;
      end
    end
    return count;
  endfunction

  function automatic logic [5:0] count_trailing_zeros_32(input logic [31:0] val);
    logic [5:0] count;
    count = 6'd32;
    for (int i = 0; i < 32; i++) begin
      if (val[i]) begin
        count = 6'(i);
        break;
      end
    end
    return count;
  endfunction

  function automatic logic [5:0] count_population_32(input logic [31:0] val);
    logic [5:0] count;
    count = 6'd0;
    for (int i = 0; i < 32; i++) begin
      if (val[i]) count = count + 6'd1;
    end
    return count;
  endfunction

  always_comb begin
    case (op_i)
      // 64-bit Arithmetic
      ALU_ADD:       result_o = operand_a_i + operand_b_i;
      ALU_SUB:       result_o = operand_a_i - operand_b_i;

      // 64-bit Logical
      ALU_AND:       result_o = operand_a_i & operand_b_i;
      ALU_OR:        result_o = operand_a_i | operand_b_i;
      ALU_XOR:       result_o = operand_a_i ^ operand_b_i;

      // 64-bit Shifts
      ALU_SLL:       result_o = operand_a_i << shamt64;
      ALU_SRL:       result_o = operand_a_i >> shamt64;
      ALU_SRA:       result_o = $signed(operand_a_i) >>> shamt64;

      // Set Less Than
      ALU_SLT:       result_o = ($signed(operand_a_i) < $signed(operand_b_i)) ? 64'd1 : 64'd0;
      ALU_SLTU:      result_o = (operand_a_i < operand_b_i)                   ? 64'd1 : 64'd0;

      // 32-bit Word Operations (sign-extended to 64 bits per RV64 specification)
      ALU_ADDW:      result_o = {{32{res_addw[31]}}, res_addw};
      ALU_SUBW:      result_o = {{32{res_subw[31]}}, res_subw};
      ALU_SLLW:      result_o = {{32{res_sllw[31]}}, res_sllw};
      ALU_SRLW:      result_o = {{32{res_srlw[31]}}, res_srlw};
      ALU_SRAW:      result_o = {{32{res_sraw[31]}}, res_sraw};

      // Pass-through
      ALU_COPY_A:    result_o = operand_a_i;
      ALU_COPY_B:    result_o = operand_b_i;

      // ----------------------------------------------------------------------
      // Zba: Address Generation
      // ----------------------------------------------------------------------
      ALU_SH1ADD:    result_o = (operand_a_i << 1) + operand_b_i;
      ALU_SH2ADD:    result_o = (operand_a_i << 2) + operand_b_i;
      ALU_SH3ADD:    result_o = (operand_a_i << 3) + operand_b_i;
      ALU_SH1ADD_UW: result_o = ({32'd0, a32} << 1) + operand_b_i;
      ALU_SH2ADD_UW: result_o = ({32'd0, a32} << 2) + operand_b_i;
      ALU_SH3ADD_UW: result_o = ({32'd0, a32} << 3) + operand_b_i;
      ALU_ADD_UW:    result_o = {32'd0, a32} + operand_b_i;
      ALU_SLLI_UW:   result_o = {32'd0, a32} << shamt64;

      // ----------------------------------------------------------------------
      // Zbb: Basic Bitmanipulation
      // ----------------------------------------------------------------------
      ALU_CLZ:       result_o = {57'd0, count_leading_zeros_64(operand_a_i)};
      ALU_CTZ:       result_o = {57'd0, count_trailing_zeros_64(operand_a_i)};
      ALU_CPOP:      result_o = {57'd0, count_population_64(operand_a_i)};
      ALU_CLZW:      result_o = {58'd0, count_leading_zeros_32(a32)};
      ALU_CTZW:      result_o = {58'd0, count_trailing_zeros_32(a32)};
      ALU_CPOPW:     result_o = {58'd0, count_population_32(a32)};
      ALU_MIN:       result_o = ($signed(operand_a_i) < $signed(operand_b_i)) ? operand_a_i : operand_b_i;
      ALU_MAX:       result_o = ($signed(operand_a_i) > $signed(operand_b_i)) ? operand_a_i : operand_b_i;
      ALU_MINU:      result_o = (operand_a_i < operand_b_i)                   ? operand_a_i : operand_b_i;
      ALU_MAXU:      result_o = (operand_a_i > operand_b_i)                   ? operand_a_i : operand_b_i;
      ALU_SEXT_B:    result_o = {{56{operand_a_i[7]}}, operand_a_i[7:0]};
      ALU_SEXT_H:    result_o = {{48{operand_a_i[15]}}, operand_a_i[15:0]};
      ALU_ZEXT_H:    result_o = {48'd0, operand_a_i[15:0]};
      ALU_ROL:       result_o = (shamt64 == 6'd0) ? operand_a_i :
                                ((operand_a_i << shamt64) | (operand_a_i >> (7'd64 - {1'b0, shamt64})));
      ALU_ROR:       result_o = (shamt64 == 6'd0) ? operand_a_i :
                                ((operand_a_i >> shamt64) | (operand_a_i << (7'd64 - {1'b0, shamt64})));
      ALU_ROLW:      result_o = {{32{res_rolw[31]}}, res_rolw};
      ALU_RORW:      result_o = {{32{res_rorw[31]}}, res_rorw};
      ALU_REV8:      result_o = {operand_a_i[7:0], operand_a_i[15:8], operand_a_i[23:16], operand_a_i[31:24],
                                 operand_a_i[39:32], operand_a_i[47:40], operand_a_i[55:48], operand_a_i[63:56]};
      ALU_ORC_B:     result_o = {(operand_a_i[63:56] != 8'd0) ? 8'hFF : 8'h00,
                                 (operand_a_i[55:48] != 8'd0) ? 8'hFF : 8'h00,
                                 (operand_a_i[47:40] != 8'd0) ? 8'hFF : 8'h00,
                                 (operand_a_i[39:32] != 8'd0) ? 8'hFF : 8'h00,
                                 (operand_a_i[31:24] != 8'd0) ? 8'hFF : 8'h00,
                                 (operand_a_i[23:16] != 8'd0) ? 8'hFF : 8'h00,
                                 (operand_a_i[15:8]  != 8'd0) ? 8'hFF : 8'h00,
                                 (operand_a_i[7:0]   != 8'd0) ? 8'hFF : 8'h00};
      ALU_ANDN:      result_o = operand_a_i & ~operand_b_i;
      ALU_ORN:       result_o = operand_a_i | ~operand_b_i;
      ALU_XNOR:      result_o = ~(operand_a_i ^ operand_b_i);

      // ----------------------------------------------------------------------
      // Zbs: Single-Bit Operations
      // ----------------------------------------------------------------------
      ALU_BSET:      result_o = operand_a_i | (64'd1 << shamt64);
      ALU_BCLR:      result_o = operand_a_i & ~(64'd1 << shamt64);
      ALU_BINV:      result_o = operand_a_i ^ (64'd1 << shamt64);
      ALU_BEXT:      result_o = (operand_a_i >> shamt64) & 64'd1;

      default:       result_o = '0;
    endcase
  end

  assign zero_o = (result_o == '0);

endmodule : moon_alu

`endif // MOON_ALU_SV
