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
  logic [31:0] sha256_sig0, sha256_sig1, sha256_sum0, sha256_sum1;
  logic [63:0] sha512_sig0, sha512_sig1, sha512_sum0, sha512_sum1;
  logic [7:0] aes_byte0, aes_byte1, aes_byte2, aes_byte3;
  logic [31:0] aes_ks1_word, aes_rcon;
  logic [63:0] aes_state_fwd, aes_state_inv;

  function automatic logic [31:0] ror32(input logic [31:0] value, input integer amount);
    ror32 = (value >> amount) | (value << (32 - amount));
  endfunction

  function automatic logic [7:0] aes_gf_mul(input logic [7:0] lhs, input logic [7:0] rhs);
    logic [7:0] a, b, product;
    a = lhs;
    b = rhs;
    product = '0;
    for (int i = 0; i < 8; i++) begin
      if (b[0]) product ^= a;
      a = a[7] ? ((a << 1) ^ 8'h1b) : (a << 1);
      b >>= 1;
    end
    return product;
  endfunction

  function automatic logic [7:0] aes_gf_inverse(input logic [7:0] value);
    logic [7:0] x2, x4, x8, x16, x32, x64, x128;
    x2 = aes_gf_mul(value, value);
    x4 = aes_gf_mul(x2, x2);
    x8 = aes_gf_mul(x4, x4);
    x16 = aes_gf_mul(x8, x8);
    x32 = aes_gf_mul(x16, x16);
    x64 = aes_gf_mul(x32, x32);
    x128 = aes_gf_mul(x64, x64);
    return aes_gf_mul(aes_gf_mul(aes_gf_mul(aes_gf_mul(aes_gf_mul(aes_gf_mul(x2, x4), x8), x16), x32), x64), x128);
  endfunction

  function automatic logic [7:0] aes_sbox(input logic [7:0] value);
    logic [7:0] inv;
    inv = aes_gf_inverse(value);
    return inv ^ {inv[6:0], inv[7]} ^ {inv[5:0], inv[7:6]} ^
           {inv[4:0], inv[7:5]} ^ {inv[3:0], inv[7:4]} ^ 8'h63;
  endfunction

  function automatic logic [7:0] aes_sbox_inv(input logic [7:0] value);
    logic [7:0] affine_inverse;
    affine_inverse = {value[6:0], value[7]} ^ {value[4:0], value[7:5]} ^
                     {value[1:0], value[7:2]} ^ 8'h05;
    return aes_gf_inverse(affine_inverse);
  endfunction

  function automatic logic [63:0] aes_shiftrows_fwd(input logic [63:0] rs2, input logic [63:0] rs1);
    return {rs1[31:24], rs2[55:48], rs2[15:8], rs1[39:32],
            rs2[63:56], rs2[23:16], rs1[47:40], rs1[7:0]};
  endfunction

  function automatic logic [63:0] aes_shiftrows_inv(input logic [63:0] rs2, input logic [63:0] rs1);
    return {rs2[31:24], rs2[55:48], rs1[15:8], rs1[39:32],
            rs1[63:56], rs2[23:16], rs2[47:40], rs1[7:0]};
  endfunction

  function automatic logic [63:0] aes_apply_sbox64(input logic [63:0] value, input logic inverse);
    logic [63:0] result;
    for (int i = 0; i < 8; i++) begin
      result[i*8 +: 8] = inverse ? aes_sbox_inv(value[i*8 +: 8]) : aes_sbox(value[i*8 +: 8]);
    end
    return result;
  endfunction

  function automatic logic [31:0] aes_mixcolumn_fwd(input logic [31:0] x);
    logic [7:0] s0, s1, s2, s3, b0, b1, b2, b3;
    s0=x[7:0]; s1=x[15:8]; s2=x[23:16]; s3=x[31:24];
    b0=aes_gf_mul(s0,8'h02)^aes_gf_mul(s1,8'h03)^s2^s3;
    b1=s0^aes_gf_mul(s1,8'h02)^aes_gf_mul(s2,8'h03)^s3;
    b2=s0^s1^aes_gf_mul(s2,8'h02)^aes_gf_mul(s3,8'h03);
    b3=aes_gf_mul(s0,8'h03)^s1^s2^aes_gf_mul(s3,8'h02);
    return {b3,b2,b1,b0};
  endfunction

  function automatic logic [31:0] aes_mixcolumn_inv(input logic [31:0] x);
    logic [7:0] s0, s1, s2, s3, b0, b1, b2, b3;
    s0=x[7:0]; s1=x[15:8]; s2=x[23:16]; s3=x[31:24];
    b0=aes_gf_mul(s0,8'h0e)^aes_gf_mul(s1,8'h0b)^aes_gf_mul(s2,8'h0d)^aes_gf_mul(s3,8'h09);
    b1=aes_gf_mul(s0,8'h09)^aes_gf_mul(s1,8'h0e)^aes_gf_mul(s2,8'h0b)^aes_gf_mul(s3,8'h0d);
    b2=aes_gf_mul(s0,8'h0d)^aes_gf_mul(s1,8'h09)^aes_gf_mul(s2,8'h0e)^aes_gf_mul(s3,8'h0b);
    b3=aes_gf_mul(s0,8'h0b)^aes_gf_mul(s1,8'h0d)^aes_gf_mul(s2,8'h09)^aes_gf_mul(s3,8'h0e);
    return {b3,b2,b1,b0};
  endfunction

  function automatic logic [31:0] aes_rcon_lookup(input logic [3:0] round);
    case (round)
      4'd1: aes_rcon_lookup = 32'h01000000;
      4'd2: aes_rcon_lookup = 32'h02000000;
      4'd3: aes_rcon_lookup = 32'h04000000;
      4'd4: aes_rcon_lookup = 32'h08000000;
      4'd5: aes_rcon_lookup = 32'h10000000;
      4'd6: aes_rcon_lookup = 32'h20000000;
      4'd7: aes_rcon_lookup = 32'h40000000;
      4'd8: aes_rcon_lookup = 32'h80000000;
      4'd9: aes_rcon_lookup = 32'h1b000000;
      4'd10: aes_rcon_lookup = 32'h36000000;
      default: aes_rcon_lookup = '0;
    endcase
  endfunction

  assign sha256_sig0 = ror32(a32, 7) ^ ror32(a32, 18) ^ (a32 >> 3);
  assign sha256_sig1 = ror32(a32, 17) ^ ror32(a32, 19) ^ (a32 >> 10);
  assign sha256_sum0 = ror32(a32, 2) ^ ror32(a32, 13) ^ ror32(a32, 22);
  assign sha256_sum1 = ror32(a32, 6) ^ ror32(a32, 11) ^ ror32(a32, 25);
  assign sha512_sig0 = (operand_a_i >> 1 | operand_a_i << 63) ^
                       (operand_a_i >> 8 | operand_a_i << 56) ^ (operand_a_i >> 7);
  assign sha512_sig1 = (operand_a_i >> 19 | operand_a_i << 45) ^
                       (operand_a_i >> 61 | operand_a_i << 3) ^ (operand_a_i >> 6);
  assign sha512_sum0 = (operand_a_i >> 28 | operand_a_i << 36) ^
                       (operand_a_i >> 34 | operand_a_i << 30) ^
                       (operand_a_i >> 39 | operand_a_i << 25);
  assign sha512_sum1 = (operand_a_i >> 14 | operand_a_i << 50) ^
                       (operand_a_i >> 18 | operand_a_i << 46) ^
                       (operand_a_i >> 41 | operand_a_i << 23);
  assign aes_byte0 = aes_sbox(aes_ks1_word[7:0]);
  assign aes_byte1 = aes_sbox(aes_ks1_word[15:8]);
  assign aes_byte2 = aes_sbox(aes_ks1_word[23:16]);
  assign aes_byte3 = aes_sbox(aes_ks1_word[31:24]);
  assign aes_ks1_word = (operand_b_i[3:0] == 4'd10) ? operand_a_i[63:32] :
                       {operand_a_i[39:32], operand_a_i[63:40]};
  assign aes_rcon = aes_rcon_lookup(operand_b_i[3:0]);
  assign aes_state_fwd = aes_apply_sbox64(aes_shiftrows_fwd(operand_b_i, operand_a_i), 1'b0);
  assign aes_state_inv = aes_apply_sbox64(aes_shiftrows_inv(operand_b_i, operand_a_i), 1'b1);

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

      // Zknh SHA-256 word operations (RV64 results are sign-extended).
      ALU_SHA256SIG0: result_o = {{32{sha256_sig0[31]}}, sha256_sig0};
      ALU_SHA256SIG1: result_o = {{32{sha256_sig1[31]}}, sha256_sig1};
      ALU_SHA256SUM0: result_o = {{32{sha256_sum0[31]}}, sha256_sum0};
      ALU_SHA256SUM1: result_o = {{32{sha256_sum1[31]}}, sha256_sum1};
      ALU_SHA512SIG0: result_o = sha512_sig0;
      ALU_SHA512SIG1: result_o = sha512_sig1;
      ALU_SHA512SUM0: result_o = sha512_sum0;
      ALU_SHA512SUM1: result_o = sha512_sum1;
      ALU_AES64KS2: result_o = {
        (operand_a_i[63:32] ^ operand_b_i[31:0] ^ operand_b_i[63:32]),
        (operand_a_i[63:32] ^ operand_b_i[31:0])
      };
      ALU_AES64KS1I: result_o = {
        (aes_byte3 ^ aes_rcon[31:24]), (aes_byte2 ^ aes_rcon[23:16]),
        (aes_byte1 ^ aes_rcon[15:8]), (aes_byte0 ^ aes_rcon[7:0]),
        (aes_byte3 ^ aes_rcon[31:24]), (aes_byte2 ^ aes_rcon[23:16]),
        (aes_byte1 ^ aes_rcon[15:8]), (aes_byte0 ^ aes_rcon[7:0])
      };
      ALU_AES64IM: result_o = {aes_mixcolumn_inv(operand_a_i[63:32]),
                               aes_mixcolumn_inv(operand_a_i[31:0])};
      ALU_AES64ES: result_o = aes_apply_sbox64(aes_shiftrows_fwd(operand_b_i, operand_a_i), 1'b0);
      ALU_AES64ESM: result_o = {aes_mixcolumn_fwd(aes_state_fwd[63:32]),
                                aes_mixcolumn_fwd(aes_state_fwd[31:0])};
      ALU_AES64DS: result_o = aes_state_inv;
      ALU_AES64DSM: result_o = {aes_mixcolumn_inv(aes_state_inv[63:32]),
                                aes_mixcolumn_inv(aes_state_inv[31:0])};

      default:       result_o = '0;
    endcase
  end

  assign zero_o = (result_o == '0);

endmodule : moon_alu

`endif // MOON_ALU_SV
