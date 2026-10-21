// ============================================================================
// File: rtl/core/moon_c_decoder.sv
// Description: RVC (Zca, Zcb) 16-bit compressed instruction decompressor for
//              Moon-SoC RV64 core, converting 16-bit compressed instructions
//              into their standard 32-bit base equivalents.
// ============================================================================

`ifndef MOON_C_DECODER_SV
`define MOON_C_DECODER_SV

`include "moon_pkg.sv"

module moon_c_decoder
  import moon_pkg::*;
(
  input  logic [15:0] instr_16_i,
  output logic [31:0] instr_32_o,
  output logic        is_compressed_o,
  output logic        illegal_instr_o
);

  wire [1:0] op       = instr_16_i[1:0];
  wire [2:0] funct3   = instr_16_i[15:13];
  wire [4:0] rd_std   = instr_16_i[11:7];
  wire [4:0] rs2_std  = instr_16_i[6:2];
  wire [4:0] rd_prime = {2'b01, instr_16_i[4:2]};
  wire [4:0] rs1_prime= {2'b01, instr_16_i[9:7]};
  wire [4:0] rs2_prime= {2'b01, instr_16_i[4:2]};
  wire       bit12    = instr_16_i[12];
  wire       bit6     = instr_16_i[6];
  wire       bit5     = instr_16_i[5];

  // Common immediate expansions
  wire [11:0] imm12_sign = {{6{bit12}}, bit12, instr_16_i[6:2]};
  wire [9:0]  uimm_addi4spn = {instr_16_i[10:7], instr_16_i[12:11], bit5, bit6, 2'b00};
  wire [6:0]  uimm_lw_sw    = {bit5, instr_16_i[12:10], bit6, 2'b00};
  wire [7:0]  uimm_ld_sd    = {instr_16_i[6:5], instr_16_i[12:10], 3'b000};
  wire [11:0] imm16sp       = {{2{bit12}}, bit12, instr_16_i[4:3], bit5, instr_16_i[2], bit6, 4'b0000};
  wire [19:0] imm20_lui     = {{14{bit12}}, bit12, instr_16_i[6:2]};
  wire [20:0] imm21_j       = {{10{bit12}}, bit12, instr_16_i[8], instr_16_i[10:9], bit6, instr_16_i[7], instr_16_i[2], instr_16_i[11], instr_16_i[5:3], 1'b0};
  wire [12:0] imm13_b       = {{4{bit12}}, bit12, instr_16_i[6:5], instr_16_i[2], instr_16_i[11:10], instr_16_i[4:3], 1'b0};
  wire [7:0]  uimm_lwsp     = {instr_16_i[3:2], bit12, instr_16_i[6:4], 2'b00};
  wire [8:0]  uimm_ldsp     = {instr_16_i[4:2], bit12, instr_16_i[6:5], 3'b000};
  wire [7:0]  uimm_swsp     = {instr_16_i[8:7], instr_16_i[12:9], 2'b00};
  wire [8:0]  uimm_sdsp     = {instr_16_i[9:7], instr_16_i[12:10], 3'b000};

  always_comb begin
    is_compressed_o = (op != 2'b11);
    illegal_instr_o = 1'b0;
    instr_32_o      = 32'h0000_0013; // Default NOP

    if (op == 2'b11) begin
      // 32-bit instruction passthrough
      instr_32_o      = {16'b0, instr_16_i};
      is_compressed_o = 1'b0;
    end else if (op == 2'b00) begin
      // ----------------------------------------------------------------------
      // Quadrant 0
      // ----------------------------------------------------------------------
      case (funct3)
        3'b000: begin // c.addi4spn
          if (uimm_addi4spn == 10'd0) begin
            illegal_instr_o = 1'b1;
          end else begin
            // addi rd', x2, uimm
            instr_32_o = {2'b00, uimm_addi4spn, 5'd2, 3'b000, rd_prime, 7'b0010011};
          end
        end

        3'b010: begin // c.lw
          // lw rd', uimm(rs1')
          instr_32_o = {5'b00000, uimm_lw_sw, rs1_prime, 3'b010, rd_prime, 7'b0000011};
        end

        3'b011: begin // c.ld (RV64)
          // ld rd', uimm(rs1')
          instr_32_o = {4'b0000, uimm_ld_sd, rs1_prime, 3'b011, rd_prime, 7'b0000011};
        end

        3'b100: begin // Reserved in standard RV64C
          illegal_instr_o = 1'b1;
        end

        3'b110: begin // c.sw
          // sw rs2', uimm(rs1')
          instr_32_o = {5'b00000, uimm_lw_sw[6:5], rs2_prime, rs1_prime, 3'b010, uimm_lw_sw[4:0], 7'b0100011};
        end

        3'b111: begin // c.sd (RV64)
          // sd rs2', uimm(rs1')
          instr_32_o = {4'b0000, uimm_ld_sd[7:5], rs2_prime, rs1_prime, 3'b011, uimm_ld_sd[4:0], 7'b0100011};
        end

        default: illegal_instr_o = 1'b1;
      endcase
    end else if (op == 2'b01) begin
      // ----------------------------------------------------------------------
      // Quadrant 1
      // ----------------------------------------------------------------------
      case (funct3)
        3'b000: begin // c.nop / c.addi
          // addi rd, rd, imm
          instr_32_o = {imm12_sign, rd_std, 3'b000, rd_std, 7'b0010011};
        end

        3'b001: begin // c.addiw (RV64)
          if (rd_std == 5'd0) begin
            illegal_instr_o = 1'b1;
          end else begin
            // addiw rd, rd, imm
            instr_32_o = {imm12_sign, rd_std, 3'b000, rd_std, 7'b0011011};
          end
        end

        3'b010: begin // c.li
          // addi rd, x0, imm
          instr_32_o = {imm12_sign, 5'd0, 3'b000, rd_std, 7'b0010011};
        end

        3'b011: begin
          if (rd_std == 5'd2) begin // c.addi16sp
            if (imm16sp == 12'd0) begin
              illegal_instr_o = 1'b1;
            end else begin
              instr_32_o = {imm16sp, 5'd2, 3'b000, 5'd2, 7'b0010011};
            end
          end else if (rd_std != 5'd0) begin // c.lui
            if (imm20_lui == 20'd0) begin
              illegal_instr_o = 1'b1;
            end else begin
              instr_32_o = {imm20_lui, rd_std, 7'b0110111};
            end
          end else begin
            illegal_instr_o = 1'b1;
          end
        end

        3'b100: begin
          case (instr_16_i[11:10])
            2'b00: begin // c.srli (RV64: 6-bit shamt)
              instr_32_o = {6'b000000, bit12, instr_16_i[6:2], rs1_prime, 3'b101, rs1_prime, 7'b0010011};
            end
            2'b01: begin // c.srai (RV64: 6-bit shamt)
              instr_32_o = {6'b010000, bit12, instr_16_i[6:2], rs1_prime, 3'b101, rs1_prime, 7'b0010011};
            end
            2'b10: begin // c.andi
              instr_32_o = {imm12_sign, rs1_prime, 3'b111, rs1_prime, 7'b0010011};
            end
            2'b11: begin
              if (!bit12) begin
                case (instr_16_i[6:5])
                  2'b00: instr_32_o = {7'b0100000, rs2_prime, rs1_prime, 3'b000, rs1_prime, 7'b0110011}; // sub
                  2'b01: instr_32_o = {7'b0000000, rs2_prime, rs1_prime, 3'b100, rs1_prime, 7'b0110011}; // xor
                  2'b10: instr_32_o = {7'b0000000, rs2_prime, rs1_prime, 3'b110, rs1_prime, 7'b0110011}; // or
                  2'b11: instr_32_o = {7'b0000000, rs2_prime, rs1_prime, 3'b111, rs1_prime, 7'b0110011}; // and
                endcase
              end else begin
                case (instr_16_i[6:5])
                  2'b00: instr_32_o = {7'b0100000, rs2_prime, rs1_prime, 3'b000, rs1_prime, 7'b0111011}; // subw
                  2'b01: instr_32_o = {7'b0000000, rs2_prime, rs1_prime, 3'b000, rs1_prime, 7'b0111011}; // addw
                  default: illegal_instr_o = 1'b1;
                endcase
              end
            end
          endcase
        end

        3'b101: begin // c.j
          instr_32_o = {imm21_j[20], imm21_j[10:1], imm21_j[11], imm21_j[19:12], 5'd0, 7'b1101111}; // jal x0, imm
        end

        3'b110: begin // c.beqz
          instr_32_o = {imm13_b[12], imm13_b[10:5], 5'd0, rs1_prime, 3'b000, imm13_b[4:1], imm13_b[11], 7'b1100011}; // beq rs1', x0, imm
        end

        3'b111: begin // c.bnez
          instr_32_o = {imm13_b[12], imm13_b[10:5], 5'd0, rs1_prime, 3'b001, imm13_b[4:1], imm13_b[11], 7'b1100011}; // bne rs1', x0, imm
        end
      endcase
    end else if (op == 2'b10) begin
      // ----------------------------------------------------------------------
      // Quadrant 2
      // ----------------------------------------------------------------------
      case (funct3)
        3'b000: begin // c.slli (RV64: 6-bit shamt)
          if (rd_std == 5'd0) begin
            illegal_instr_o = 1'b1;
          end else begin
            instr_32_o = {6'b000000, bit12, instr_16_i[6:2], rd_std, 3'b001, rd_std, 7'b0010011};
          end
        end

        3'b010: begin // c.lwsp
          if (rd_std == 5'd0) begin
            illegal_instr_o = 1'b1;
          end else begin
            instr_32_o = {4'b0000, uimm_lwsp, 5'd2, 3'b010, rd_std, 7'b0000011};
          end
        end

        3'b011: begin // c.ldsp (RV64)
          if (rd_std == 5'd0) begin
            illegal_instr_o = 1'b1;
          end else begin
            instr_32_o = {3'b000, uimm_ldsp, 5'd2, 3'b011, rd_std, 7'b0000011};
          end
        end

        3'b100: begin
          if (!bit12) begin
            if (rs2_std == 5'd0) begin // c.jr
              if (rd_std == 5'd0) begin
                illegal_instr_o = 1'b1;
              end else begin
                instr_32_o = {12'b0, rd_std, 3'b000, 5'd0, 7'b1100111}; // jalr x0, 0(rs1)
              end
            end else begin // c.mv
              instr_32_o = {7'b0000000, rs2_std, 5'd0, 3'b000, rd_std, 7'b0110011}; // add rd, x0, rs2
            end
          end else begin
            if (rs2_std == 5'd0) begin
              if (rd_std == 5'd0) begin // c.ebreak
                instr_32_o = 32'h0010_0073;
              end else begin // c.jalr
                instr_32_o = {12'b0, rd_std, 3'b000, 5'd1, 7'b1100111}; // jalr x1, 0(rs1)
              end
            end else begin // c.add
              instr_32_o = {7'b0000000, rs2_std, rd_std, 3'b000, rd_std, 7'b0110011}; // add rd, rd, rs2
            end
          end
        end

        3'b110: begin // c.swsp
          instr_32_o = {4'b0000, uimm_swsp[7:5], rs2_std, 5'd2, 3'b010, uimm_swsp[4:0], 7'b0100011};
        end

        3'b111: begin // c.sdsp (RV64)
          instr_32_o = {3'b000, uimm_sdsp[8:5], rs2_std, 5'd2, 3'b011, uimm_sdsp[4:0], 7'b0100011};
        end

        default: illegal_instr_o = 1'b1;
      endcase
    end
  end

endmodule : moon_c_decoder

`endif // MOON_C_DECODER_SV
