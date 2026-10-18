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

  localparam logic [7:0] AES_SBOX [0:255] = '{
    8'h63, 8'h7c, 8'h77, 8'h7b, 8'hf2, 8'h6b, 8'h6f, 8'hc5, 8'h30, 8'h01, 8'h67, 8'h2b, 8'hfe, 8'hd7, 8'hab, 8'h76,
    8'hca, 8'h82, 8'hc9, 8'h7d, 8'hfa, 8'h59, 8'h47, 8'hf0, 8'had, 8'hd4, 8'ha2, 8'haf, 8'h9c, 8'ha4, 8'h72, 8'hc0,
    8'hb7, 8'hfd, 8'h93, 8'h26, 8'h36, 8'h3f, 8'hf7, 8'hcc, 8'h34, 8'ha5, 8'he5, 8'hf1, 8'h71, 8'hd8, 8'h31, 8'h15,
    8'h04, 8'hc7, 8'h23, 8'hc3, 8'h18, 8'h96, 8'h05, 8'h9a, 8'h07, 8'h12, 8'h80, 8'he2, 8'heb, 8'h27, 8'hb2, 8'h75,
    8'h09, 8'h83, 8'h2c, 8'h1a, 8'h1b, 8'h6e, 8'h5a, 8'ha0, 8'h52, 8'h3b, 8'hd6, 8'hb3, 8'h29, 8'he3, 8'h2f, 8'h84,
    8'h53, 8'hd1, 8'h00, 8'hed, 8'h20, 8'hfc, 8'hb1, 8'h5b, 8'h6a, 8'hcb, 8'hbe, 8'h39, 8'h4a, 8'h4c, 8'h58, 8'hcf,
    8'hd0, 8'hef, 8'haa, 8'hfb, 8'h43, 8'h4d, 8'h33, 8'h85, 8'h45, 8'hf9, 8'h02, 8'h7f, 8'h50, 8'h3c, 8'h9f, 8'ha8,
    8'h51, 8'ha3, 8'h40, 8'h8f, 8'h92, 8'h9d, 8'h38, 8'hf5, 8'hbc, 8'hb6, 8'hda, 8'h21, 8'h10, 8'hff, 8'hf3, 8'hd2,
    8'hcd, 8'h0c, 8'h13, 8'hec, 8'h5f, 8'h97, 8'h44, 8'h17, 8'hc4, 8'ha7, 8'h7e, 8'h3d, 8'h64, 8'h5d, 8'h19, 8'h73,
    8'h60, 8'h81, 8'h4f, 8'hdc, 8'h22, 8'h2a, 8'h90, 8'h88, 8'h46, 8'hee, 8'hb8, 8'h14, 8'hde, 8'h5e, 8'h0b, 8'hdb,
    8'he0, 8'h32, 8'h3a, 8'h0a, 8'h49, 8'h06, 8'h24, 8'h5c, 8'hc2, 8'hd3, 8'hac, 8'h62, 8'h91, 8'h95, 8'he4, 8'h79,
    8'he7, 8'hc8, 8'h37, 8'h6d, 8'h8d, 8'hd5, 8'h4e, 8'ha9, 8'h6c, 8'h56, 8'hf4, 8'hea, 8'h65, 8'h7a, 8'hae, 8'h08,
    8'hba, 8'h78, 8'h25, 8'h2e, 8'h1c, 8'ha6, 8'hb4, 8'hc6, 8'he8, 8'hdd, 8'h74, 8'h1f, 8'h4b, 8'hbd, 8'h8b, 8'h8a,
    8'h70, 8'h3e, 8'hb5, 8'h66, 8'h48, 8'h03, 8'hf6, 8'h0e, 8'h61, 8'h35, 8'h57, 8'hb9, 8'h86, 8'hc1, 8'h1d, 8'h9e,
    8'he1, 8'hf8, 8'h98, 8'h11, 8'h69, 8'hd9, 8'h8e, 8'h94, 8'h9b, 8'h1e, 8'h87, 8'he9, 8'hce, 8'h55, 8'h28, 8'hdf,
    8'h8c, 8'ha1, 8'h89, 8'h0d, 8'hbf, 8'he6, 8'h42, 8'h68, 8'h41, 8'h99, 8'h2d, 8'h0f, 8'hb0, 8'h54, 8'hbb, 8'h16
  };

  localparam logic [7:0] AES_INV_SBOX [0:255] = '{
    8'h52, 8'h09, 8'h6a, 8'hd5, 8'h30, 8'h36, 8'ha5, 8'h38, 8'hbf, 8'h40, 8'ha3, 8'h9e, 8'h81, 8'hf3, 8'hd7, 8'hfb,
    8'h7c, 8'he3, 8'h39, 8'h82, 8'h9b, 8'h2f, 8'hff, 8'h87, 8'h34, 8'h8e, 8'h43, 8'h44, 8'hc4, 8'hde, 8'he9, 8'hcb,
    8'h54, 8'h7b, 8'h94, 8'h32, 8'ha6, 8'hc2, 8'h23, 8'h3d, 8'hee, 8'h4c, 8'h95, 8'h0b, 8'h42, 8'hfa, 8'hc3, 8'h4e,
    8'h08, 8'h2e, 8'ha1, 8'h66, 8'h28, 8'hd9, 8'h24, 8'hb2, 8'h76, 8'h5b, 8'ha2, 8'h49, 8'h6d, 8'h8b, 8'hd1, 8'h25,
    8'h72, 8'hf8, 8'hf6, 8'h64, 8'h86, 8'h68, 8'h98, 8'h16, 8'hd4, 8'ha4, 8'h5c, 8'hcc, 8'h5d, 8'h65, 8'hb6, 8'h92,
    8'h6c, 8'h70, 8'h48, 8'h50, 8'hfd, 8'hed, 8'hb9, 8'hda, 8'h5e, 8'h15, 8'h46, 8'h57, 8'ha7, 8'h8d, 8'h9d, 8'h84,
    8'h90, 8'hd8, 8'hab, 8'h00, 8'h8c, 8'hbc, 8'hd3, 8'h0a, 8'hf7, 8'he4, 8'h58, 8'h05, 8'hb8, 8'hb3, 8'h45, 8'h06,
    8'hd0, 8'h2c, 8'h1e, 8'h8f, 8'hca, 8'h3f, 8'h0f, 8'h02, 8'hc1, 8'haf, 8'hbd, 8'h03, 8'h01, 8'h13, 8'h8a, 8'h6b,
    8'h3a, 8'h91, 8'h11, 8'h41, 8'h4f, 8'h67, 8'hdc, 8'hea, 8'h97, 8'hf2, 8'hcf, 8'hce, 8'hf0, 8'hb4, 8'he6, 8'h73,
    8'h96, 8'hac, 8'h74, 8'h22, 8'he7, 8'had, 8'h35, 8'h85, 8'he2, 8'hf9, 8'h37, 8'he8, 8'h1c, 8'h75, 8'hdf, 8'h6e,
    8'h47, 8'hf1, 8'h1a, 8'h71, 8'h1d, 8'h29, 8'hc5, 8'h89, 8'h6f, 8'hb7, 8'h62, 8'h0e, 8'haa, 8'h18, 8'hbe, 8'h1b,
    8'hfc, 8'h56, 8'h3e, 8'h4b, 8'hc6, 8'hd2, 8'h79, 8'h20, 8'h9a, 8'hdb, 8'hc0, 8'hfe, 8'h78, 8'hcd, 8'h5a, 8'hf4,
    8'h1f, 8'hdd, 8'ha8, 8'h33, 8'h88, 8'h07, 8'hc7, 8'h31, 8'hb1, 8'h12, 8'h10, 8'h59, 8'h27, 8'h80, 8'hec, 8'h5f,
    8'h60, 8'h51, 8'h7f, 8'ha9, 8'h19, 8'hb5, 8'h4a, 8'h0d, 8'h2d, 8'he5, 8'h7a, 8'h9f, 8'h93, 8'hc9, 8'h9c, 8'hef,
    8'ha0, 8'he0, 8'h3b, 8'h4d, 8'hae, 8'h2a, 8'hf5, 8'hb0, 8'hc8, 8'heb, 8'hbb, 8'h3c, 8'h83, 8'h53, 8'h99, 8'h61,
    8'h17, 8'h2b, 8'h04, 8'h7e, 8'hba, 8'h77, 8'hd6, 8'h26, 8'he1, 8'h69, 8'h14, 8'h63, 8'h55, 8'h21, 8'h0c, 8'h7d
  };

  function automatic logic [7:0] aes_sbox(input logic [7:0] value);
    return AES_SBOX[value];
  endfunction

  function automatic logic [7:0] aes_sbox_inv(input logic [7:0] value);
    return AES_INV_SBOX[value];
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
