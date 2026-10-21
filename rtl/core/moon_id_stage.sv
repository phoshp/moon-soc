// ============================================================================
// File: rtl/core/moon_id_stage.sv
// Description: Instruction Decode (ID) stage and ID/EX pipeline register
//              for Moon-SoC RV64 core, instantiating the Register File.
// ============================================================================

`ifndef MOON_ID_STAGE_SV
`define MOON_ID_STAGE_SV

`include "moon_pkg.sv"
`include "moon_regfile.sv"

module moon_id_stage
  import moon_pkg::*;
#(
  parameter bit ENABLE_FPU = 1'b0
)(
  input  logic             clk_i,
  input  logic             rst_ni,

  // Pipeline Flow Control
  input  logic             stall_ex_i,
  input  logic             flush_ex_i,

  // Inputs from IF Stage (IF/ID Register)
  input  logic [XLEN-1:0]  if_id_pc_i,
  input  logic [ILEN-1:0]  if_id_instr_i,
  input  logic             if_id_is_c_i,
  input  logic             if_id_valid_i,

  // Register File Writeback Interface from WB Stage
  input  logic             wb_regwrite_i,
  input  logic [4:0]       wb_rd_i,
  input  logic [XLEN-1:0]  wb_wdata_i,
  input  logic             wb_fp_we_i,
  input  logic [4:0]       wb_fp_rd_i,
  input  logic [FLEN-1:0]  wb_fp_wdata_i,

  // Outputs to Hazard Unit
  output logic [4:0]       id_rs1_o,
  output logic [4:0]       id_rs2_o,
  output logic [4:0]       id_fp_rs1_o,
  output logic             id_fp_rs1_en_o,
  output logic [4:0]       id_fp_rs2_o,
  output logic             id_fp_rs2_en_o,
  output logic [4:0]       id_fp_rs3_o,
  output logic             id_fp_rs3_en_o,

  // Outputs to EX Stage (ID/EX Pipeline Register)
  output logic             id_ex_valid_o,
  output logic [XLEN-1:0]  id_ex_pc_o,
  output logic [ILEN-1:0]  id_ex_instr_o,
  output logic [4:0]       id_ex_rd_o,
  output logic [4:0]       id_ex_rs1_o,
  output logic [4:0]       id_ex_rs2_o,
  output logic [XLEN-1:0]  id_ex_rs1_data_o,
  output logic [XLEN-1:0]  id_ex_rs2_data_o,
  output logic [FLEN-1:0]  id_ex_fp_rs3_data_o,
  output logic [XLEN-1:0]  id_ex_imm_o,

  // Control Signals to EX Stage
  output alu_op_e          id_ex_alu_op_o,
  output logic             id_ex_alu_src_a_pc_o,
  output logic             id_ex_alu_src_b_imm_o,
  output muldiv_op_e       id_ex_muldiv_op_o,
  output logic             id_ex_is_mul_o,
  output logic             id_ex_is_div_o,
  output amo_op_e          id_ex_amo_op_o,
  output logic             id_ex_is_amo_o,
  output logic             id_ex_is_lr_o,
  output logic             id_ex_is_sc_o,
  output logic             id_ex_is_branch_o,
  output branch_type_e     id_ex_branch_type_o,
  output logic             id_ex_is_jal_o,
  output logic             id_ex_is_jalr_o,
  output logic             id_ex_is_c_o,
  output logic             id_ex_is_load_o,
  output logic             id_ex_is_store_o,
  output mem_width_e       id_ex_mem_width_o,
  output logic             id_ex_regwrite_o,
  output logic             id_ex_fp_we_o,
  output logic [4:0]       id_ex_fp_rd_o,
  output logic             id_ex_fp_word_o,
  output logic             id_ex_fp_add_o,
  output logic             id_ex_fp_sub_o,
  output logic             id_ex_fp_mul_o,
  output logic             id_ex_fp_div_o,
  output logic             id_ex_fp_cvt_o,
  output logic             id_ex_fp_class_o,
  output logic             id_ex_fp_sign_o,
  output logic [1:0]       id_ex_fp_sign_op_o,
  output logic             id_ex_fp_cmp_o,
  output logic [2:0]       id_ex_fp_cmp_op_o,
  output logic [2:0]       id_ex_fp_rm_o,
  output logic             id_ex_is_csr_o,
  output logic [2:0]       id_ex_csr_op_o,
  output logic [11:0]      id_ex_csr_addr_o,
  output logic             id_ex_is_mret_o,
  output logic             id_ex_is_sret_o,
  output logic             id_ex_is_ecall_o,
  output logic             id_ex_is_ebreak_o,
  output logic             id_ex_is_wfi_o,
  output logic             id_ex_is_sfence_o,
  output logic             wfi_o
);

  // --------------------------------------------------------------------------
  // Instruction Field Decomposition
  // --------------------------------------------------------------------------
  logic [6:0]  opcode;
  logic [4:0]  rd;
  logic [2:0]  funct3;
  logic [4:0]  rs1;
  logic [4:0]  rs2;
  logic [6:0]  funct7;
  logic [11:0] csr_addr;

  assign opcode   = if_id_instr_i[6:0];
  assign rd       = if_id_instr_i[11:7];
  assign funct3   = if_id_instr_i[14:12];
  assign rs1      = if_id_instr_i[19:15];
  assign rs2      = if_id_instr_i[24:20];
  assign funct7   = if_id_instr_i[31:25];
  assign csr_addr = if_id_instr_i[31:20];
  wire is_fp_fma_opcode = (opcode == 7'b1000011) || (opcode == 7'b1000111) ||
                          (opcode == 7'b1001011) || (opcode == 7'b1001111);

  assign id_rs1_o = rs1;
  assign id_rs2_o = rs2;
  assign id_fp_rs1_o = rs1;
  assign id_fp_rs1_en_o = if_id_valid_i &&
                          (is_fp_fma_opcode ||
                           ((opcode == OPCODE_FP) &&
                            ((((funct7 == 7'b1110000) || (funct7 == 7'b1110001)) &&
                              (rs2 == 5'd0) && (funct3 <= 3'b001)) ||
                             ((funct7 == 7'b0010000) || (funct7 == 7'b0010001)) ||
                             ((funct7 == 7'b0010100) || (funct7 == 7'b0010101)) ||
                             ((funct7 == 7'b1010000) || (funct7 == 7'b1010001)) ||
                             ((funct7 == 7'b0100000) && (rs2 == 5'd1)) ||
                             ((funct7 == 7'b0100001) && (rs2 == 5'd0)) ||
                             (((funct7 == 7'b1100000) || (funct7 == 7'b1100001)) && (rs2 <= 5'd3)) ||
                             (((funct7 == 7'b0101100) || (funct7 == 7'b0101101)) && (rs2 == 5'd0)) ||
                             ((funct7 == 7'b0000000) || (funct7 == 7'b0000001) ||
                              (funct7 == 7'b0000100) || (funct7 == 7'b0000101) ||
                              (funct7 == 7'b0001000) || (funct7 == 7'b0001001) ||
                              (funct7 == 7'b0001100) || (funct7 == 7'b0001101)))));
  assign id_fp_rs2_o = rs2;
  assign id_fp_rs3_o = if_id_instr_i[31:27];
  assign id_fp_rs3_en_o = if_id_valid_i && is_fp_fma_opcode;
  assign id_fp_rs2_en_o = if_id_valid_i &&
                          (((opcode == OPCODE_STORE_FP) &&
                            ((funct3 == 3'b010) || (funct3 == 3'b011))) ||
                           is_fp_fma_opcode ||
                           ((opcode == OPCODE_FP) &&
                            ((funct7 == 7'b0000000) || (funct7 == 7'b0000001) ||
                             (funct7 == 7'b0000100) || (funct7 == 7'b0000101) ||
                             (funct7 == 7'b0001000) || (funct7 == 7'b0001001) ||
                             (funct7 == 7'b0001100) || (funct7 == 7'b0001101) ||
                             (funct7 == 7'b0010000) || (funct7 == 7'b0010001) ||
                             (funct7 == 7'b0010100) || (funct7 == 7'b0010101) ||
                             (funct7 == 7'b1010000) || (funct7 == 7'b1010001))));

  // --------------------------------------------------------------------------
  // Register File Instantiation
  // --------------------------------------------------------------------------
  logic [XLEN-1:0] rf_rs1_data;
  logic [XLEN-1:0] rf_rs2_data;
  logic [FLEN-1:0] fp_rs1_data;
  logic [FLEN-1:0] fp_rs2_data;
  logic [FLEN-1:0] fp_rs3_data;

  moon_regfile u_regfile (
    .clk_i       (clk_i),
    .rst_ni      (rst_ni),
    .rs1_addr_i  (rs1),
    .rs1_data_o  (rf_rs1_data),
    .rs2_addr_i  (rs2),
    .rs2_data_o  (rf_rs2_data),
    .rd_we_i     (wb_regwrite_i),
    .rd_addr_i   (wb_rd_i),
    .rd_data_i   (wb_wdata_i)
  );

  if (ENABLE_FPU) begin : gen_fregfile
    moon_fregfile u_fregfile (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .rs1_addr_i (rs1),
      .rs1_data_o (fp_rs1_data),
      .rs2_addr_i (rs2),
      .rs2_data_o (fp_rs2_data),
      .rs3_addr_i (if_id_instr_i[31:27]),
      .rs3_data_o (fp_rs3_data),
      .rd_we_i    (wb_fp_we_i),
      .rd_addr_i  (wb_fp_rd_i),
      .rd_data_i  (wb_fp_wdata_i)
    );
  end else begin : gen_no_fregfile
    assign fp_rs1_data = '0;
    assign fp_rs2_data = '0;
    assign fp_rs3_data = '0;
  end

  // --------------------------------------------------------------------------
  // Immediate Field Generation
  // --------------------------------------------------------------------------
  logic [XLEN-1:0] imm_i, imm_s, imm_b, imm_u, imm_j, imm_csr;
  logic [XLEN-1:0] selected_imm;

  assign imm_i   = {{52{if_id_instr_i[31]}}, if_id_instr_i[31:20]};
  assign imm_s   = {{52{if_id_instr_i[31]}}, if_id_instr_i[31:25], if_id_instr_i[11:7]};
  assign imm_b   = {{51{if_id_instr_i[31]}}, if_id_instr_i[31], if_id_instr_i[7], if_id_instr_i[30:25], if_id_instr_i[11:8], 1'b0};
  assign imm_u   = {{32{if_id_instr_i[31]}}, if_id_instr_i[31:12], 12'b0};
  assign imm_j   = {{43{if_id_instr_i[31]}}, if_id_instr_i[31], if_id_instr_i[19:12], if_id_instr_i[20], if_id_instr_i[30:21], 1'b0};
  assign imm_csr = {{59{1'b0}}, if_id_instr_i[19:15]};

  // --------------------------------------------------------------------------
  // Instruction Decode Logic
  // --------------------------------------------------------------------------
  alu_op_e      dec_alu_op;
  logic         dec_alu_src_a_pc;
  logic         dec_alu_src_b_imm;
  muldiv_op_e   dec_muldiv_op;
  amo_op_e      dec_amo_op;
  logic         dec_is_amo;
  logic         dec_is_lr;
  logic         dec_is_sc;
  logic         dec_is_branch;
  branch_type_e dec_branch_type;
  logic         dec_is_jal;
  logic         dec_is_jalr;
  logic         dec_is_load;
  logic         dec_is_store;
  mem_width_e   dec_mem_width;
  logic         dec_regwrite;
  logic         dec_fp_we;
  logic         dec_fp_word;
  logic         dec_fmv_x_w;
  logic         dec_fmv_x_d;
  logic         dec_fp_add;
  logic         dec_fp_sub;
  logic         dec_fp_mul;
  logic         dec_fp_div;
  logic         dec_fp_fma;
  logic         dec_fp_cvt;
  logic         dec_fp_cvt_src_fp;
  logic         dec_fp_class;
  logic         dec_fp_sign;
  logic         dec_fp_cmp;
  logic [2:0]   dec_fp_cmp_op;
  logic         dec_is_csr;
  logic [2:0]   dec_csr_op;
  logic         dec_is_mret;
  logic         dec_is_sret;
  logic         dec_is_ecall;
  logic         dec_is_ebreak;
  logic         dec_is_wfi;
  logic         dec_is_sfence;

  always_comb begin
    // Defaults
    dec_alu_op         = ALU_ADD;
    dec_alu_src_a_pc   = 1'b0;
    dec_alu_src_b_imm  = 1'b0;
    dec_muldiv_op      = MULDIV_NONE;
    dec_amo_op         = AMO_ADD;
    dec_is_amo         = 1'b0;
    dec_is_lr          = 1'b0;
    dec_is_sc          = 1'b0;
    dec_is_branch      = 1'b0;
    dec_branch_type    = BRANCH_BEQ;
    dec_is_jal         = 1'b0;
    dec_is_jalr        = 1'b0;
    dec_is_load        = 1'b0;
    dec_is_store       = 1'b0;
    dec_mem_width      = mem_width_e'(funct3);
    dec_regwrite       = 1'b0;
    dec_fp_we          = 1'b0;
    dec_fp_word        = 1'b0;
    dec_fmv_x_w        = 1'b0;
    dec_fmv_x_d        = 1'b0;
    dec_fp_add         = 1'b0;
    dec_fp_sub         = 1'b0;
    dec_fp_mul         = 1'b0;
    dec_fp_div         = 1'b0;
    dec_fp_fma         = 1'b0;
    dec_fp_cvt         = 1'b0;
    dec_fp_cvt_src_fp  = 1'b0;
    dec_fp_class       = 1'b0;
    dec_fp_sign        = 1'b0;
    dec_fp_cmp         = 1'b0;
    dec_fp_cmp_op      = '0;
    dec_is_csr         = 1'b0;
    dec_csr_op         = funct3;
    dec_is_mret        = 1'b0;
    dec_is_sret        = 1'b0;
    dec_is_ecall       = 1'b0;
    dec_is_ebreak      = 1'b0;
    dec_is_wfi         = 1'b0;
    dec_is_sfence      = 1'b0;
    selected_imm       = imm_i;

    case (opcode)
      7'b1000011, 7'b1000111, 7'b1001011, 7'b1001111: begin
        if ((if_id_instr_i[26:25] == 2'b00) || (if_id_instr_i[26:25] == 2'b01)) begin
          dec_fp_we  = 1'b1;
          dec_fp_fma = 1'b1;
          dec_fp_word = (if_id_instr_i[26:25] == 2'b00);
        end
      end

      // LUI
      OPCODE_LUI: begin
        dec_alu_op        = ALU_COPY_B;
        dec_alu_src_b_imm = 1'b1;
        selected_imm      = imm_u;
        dec_regwrite      = 1'b1;
      end

      // AUIPC
      OPCODE_AUIPC: begin
        dec_alu_op        = ALU_ADD;
        dec_alu_src_a_pc  = 1'b1;
        dec_alu_src_b_imm = 1'b1;
        selected_imm      = imm_u;
        dec_regwrite      = 1'b1;
      end

      // JAL
      OPCODE_JAL: begin
        dec_is_jal        = 1'b1;
        selected_imm      = imm_j;
        dec_regwrite      = 1'b1;
      end

      // JALR
      OPCODE_JALR: begin
        dec_is_jalr       = 1'b1;
        selected_imm      = imm_i;
        dec_regwrite      = 1'b1;
      end

      // BRANCH
      OPCODE_BRANCH: begin
        dec_is_branch     = 1'b1;
        dec_branch_type   = branch_type_e'(funct3);
        selected_imm      = imm_b;
      end

      // LOAD
      OPCODE_LOAD: begin
        dec_is_load       = 1'b1;
        dec_alu_op        = ALU_ADD;
        dec_alu_src_b_imm = 1'b1;
        selected_imm      = imm_i;
        dec_regwrite      = 1'b1;
      end

      // STORE
      OPCODE_STORE: begin
        dec_is_store      = 1'b1;
        dec_alu_op        = ALU_ADD;
        dec_alu_src_b_imm = 1'b1;
        selected_imm      = imm_s;
      end

      // OP-IMM (64-bit immediate)
      OPCODE_OP_IMM: begin
        dec_alu_src_b_imm = 1'b1;
        selected_imm      = imm_i;
        dec_regwrite      = 1'b1;
        case (funct3)
          3'b000: dec_alu_op = ALU_ADD; // ADDI
          3'b010: dec_alu_op = ALU_SLT; // SLTI
          3'b011: dec_alu_op = ALU_SLTU;// SLTIU
          3'b100: dec_alu_op = ALU_XOR; // XORI
          3'b110: dec_alu_op = ALU_OR;  // ORI
          3'b111: dec_alu_op = ALU_AND; // ANDI
          3'b001: begin
            dec_alu_op = ALU_SLL; // SLLI
          end
          3'b101: begin
            dec_alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL; // SRAI / SRLI
          end
          default: dec_alu_op = ALU_ADD;
        endcase
      end

      // OP-IMM-32 (32-bit word immediate)
      OPCODE_OP_IMM_32: begin
        dec_alu_src_b_imm = 1'b1;
        selected_imm      = imm_i;
        dec_regwrite      = 1'b1;
        case (funct3)
          3'b000: dec_alu_op = ALU_ADDW; // ADDIW
          3'b001: dec_alu_op = ALU_SLLW; // SLLIW
          3'b101: dec_alu_op = (funct7[5]) ? ALU_SRAW : ALU_SRLW; // SRAIW / SRLIW
          default: dec_alu_op = ALU_ADDW;
        endcase
      end

      // OP (64-bit register-register: RV64I, RV64M)
      OPCODE_OP: begin
        dec_regwrite = 1'b1;
        if (funct7 == 7'b0000001) begin // RV64M extension
          case (funct3)
            3'b000: dec_muldiv_op = MULDIV_MUL;
            3'b001: dec_muldiv_op = MULDIV_MULH;
            3'b010: dec_muldiv_op = MULDIV_MULHSU;
            3'b011: dec_muldiv_op = MULDIV_MULHU;
            3'b100: dec_muldiv_op = MULDIV_DIV;
            3'b101: dec_muldiv_op = MULDIV_DIVU;
            3'b110: dec_muldiv_op = MULDIV_REM;
            3'b111: dec_muldiv_op = MULDIV_REMU;
            default: ;
          endcase
        end else begin // RV64I Base
          case (funct3)
            3'b000: dec_alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
            3'b001: dec_alu_op = ALU_SLL;
            3'b010: dec_alu_op = ALU_SLT;
            3'b011: dec_alu_op = ALU_SLTU;
            3'b100: dec_alu_op = ALU_XOR;
            3'b101: dec_alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
            3'b110: dec_alu_op = ALU_OR;
            3'b111: dec_alu_op = ALU_AND;
            default: ;
          endcase
        end
      end

      // OP-32 (32-bit word register-register: RV64I, RV64M)
      OPCODE_OP_32: begin
        dec_regwrite = 1'b1;
        if (funct7 == 7'b0000001) begin // RV64M extension
          case (funct3)
            3'b000: dec_muldiv_op = MULDIV_MULW;
            3'b100: dec_muldiv_op = MULDIV_DIVW;
            3'b101: dec_muldiv_op = MULDIV_DIVUW;
            3'b110: dec_muldiv_op = MULDIV_REMW;
            3'b111: dec_muldiv_op = MULDIV_REMUW;
            default: ;
          endcase
        end else begin // RV64I Base 32-bit Word
          case (funct3)
            3'b000: dec_alu_op = (funct7[5]) ? ALU_SUBW : ALU_ADDW;
            3'b001: dec_alu_op = ALU_SLLW;
            3'b101: dec_alu_op = (funct7[5]) ? ALU_SRAW : ALU_SRLW;
            default: ;
          endcase
        end
      end

      // AMO (RV64A Atomic Extension)
      OPCODE_AMO: begin
        dec_is_amo   = 1'b1;
        dec_regwrite = 1'b1;
        dec_alu_op   = ALU_COPY_A; // Address is rs1
        dec_amo_op   = amo_op_e'(funct7[6:2]);
        if (funct7[6:2] == 5'b00010) begin // LR
          dec_is_lr = 1'b1;
        end else if (funct7[6:2] == 5'b00011) begin // SC
          dec_is_sc = 1'b1;
        end
      end

      // Scalar floating-point operations; unimplemented funct7 values remain
      // unrecognized until their Phase 5 execution slices are added.
      OPCODE_FP: begin
        if (((funct7 == 7'b1100000) || (funct7 == 7'b1100001)) && (rs2 <= 5'd3)) begin
          dec_regwrite      = 1'b1;
          dec_fp_cvt        = 1'b1;
          dec_fp_cvt_src_fp = 1'b1;
          dec_fp_word       = (funct7 == 7'b1100000);
        end else if (((funct7 == 7'b1101000) || (funct7 == 7'b1101001)) && (rs2 <= 5'd3)) begin
          dec_fp_we   = 1'b1;
          dec_fp_cvt  = 1'b1;
          dec_fp_word = (funct7 == 7'b1101000);
        end else if (((funct7 == 7'b0100000) && (rs2 == 5'd1)) ||
            ((funct7 == 7'b0100001) && (rs2 == 5'd0))) begin
          // FCVT.S.D and FCVT.D.S.
          dec_fp_we   = 1'b1;
          dec_fp_cvt  = 1'b1;
          dec_fp_cvt_src_fp = 1'b1;
          dec_fp_word = (funct7 == 7'b0100000);
        end else if ((funct7 == 7'b0000000) || (funct7 == 7'b0000001) ||
            (funct7 == 7'b0000100) || (funct7 == 7'b0000101) ||
            (funct7 == 7'b0001000) || (funct7 == 7'b0001001) ||
            (funct7 == 7'b0001100) || (funct7 == 7'b0001101)) begin
          // FADD/FSUB/FMUL/FDIV.S and FADD/FSUB/FMUL/FDIV.D.
          dec_fp_we   = 1'b1;
          dec_fp_word = (funct7 == 7'b0000000) || (funct7 == 7'b0000100) ||
                        (funct7 == 7'b0001000);
          dec_fp_word = dec_fp_word || (funct7 == 7'b0001100);
          dec_fp_add  = (funct7 == 7'b0000000) || (funct7 == 7'b0000001) ||
                        (funct7 == 7'b0000100) || (funct7 == 7'b0000101);
          dec_fp_sub  = (funct7 == 7'b0000100) || (funct7 == 7'b0000101);
          dec_fp_mul  = (funct7 == 7'b0001000) || (funct7 == 7'b0001001);
          dec_fp_div  = (funct7 == 7'b0001100) || (funct7 == 7'b0001101);
        end else if (((funct7 == 7'b0101100) || (funct7 == 7'b0101101)) &&
                     (rs2 == 5'd0) && (funct3 <= 3'b100)) begin
          dec_fp_we   = 1'b1;
          dec_fp_div  = 1'b1;
          dec_fp_word = (funct7 == 7'b0101100);
        end else if ((funct7 == 7'b1110000) && (rs2 == 5'd0) && (funct3 == 3'b000)) begin
          // FMV.X.W: move a single-precision bit pattern to an integer register.
          dec_regwrite = 1'b1;
          dec_alu_op   = ALU_COPY_A;
          dec_fmv_x_w  = 1'b1;
        end else if ((funct7 == 7'b1111000) && (rs2 == 5'd0) && (funct3 == 3'b000)) begin
          // FMV.W.X: move an integer word to a NaN-boxed FP register.
          dec_fp_we   = 1'b1;
          dec_fp_word = 1'b1;
          dec_alu_op  = ALU_COPY_A;
        end else if ((funct7 == 7'b1110001) && (rs2 == 5'd0) && (funct3 == 3'b000)) begin
          dec_regwrite = 1'b1;
          dec_alu_op   = ALU_COPY_A;
          dec_fmv_x_d  = 1'b1;
        end else if ((funct7 == 7'b1111001) && (rs2 == 5'd0) && (funct3 == 3'b000)) begin
          dec_fp_we  = 1'b1;
          dec_alu_op = ALU_COPY_A;
        end else if (((funct7 == 7'b1110000) || (funct7 == 7'b1110001)) &&
                     (rs2 == 5'd0) && (funct3 == 3'b001)) begin
          dec_regwrite = 1'b1;
          dec_fp_class = 1'b1;
          dec_fp_word  = (funct7 == 7'b1110000);
        end else if (((funct7 == 7'b0010000) || (funct7 == 7'b0010001)) &&
                     (funct3 <= 3'b010)) begin
          dec_fp_we   = 1'b1;
          dec_fp_sign = 1'b1;
          dec_fp_word = (funct7 == 7'b0010000);
        end else if (((funct7 == 7'b0010100) || (funct7 == 7'b0010101)) &&
                     (funct3 <= 3'b001)) begin
          dec_fp_we     = 1'b1;
          dec_fp_cmp    = 1'b1;
          dec_fp_word   = (funct7 == 7'b0010100);
          dec_fp_cmp_op = {2'b00, funct3[0]};
        end else if (((funct7 == 7'b1010000) || (funct7 == 7'b1010001)) &&
                     (funct3 <= 3'b010)) begin
          dec_regwrite = 1'b1;
          dec_fp_cmp   = 1'b1;
          dec_fp_word  = (funct7 == 7'b1010000);
          case (funct3)
            3'b000: dec_fp_cmp_op = 3'd2;
            3'b001: dec_fp_cmp_op = 3'd3;
            default: dec_fp_cmp_op = 3'd4;
          endcase
        end
      end

      OPCODE_LOAD_FP: begin
        if ((funct3 == 3'b010) || (funct3 == 3'b011)) begin
          dec_is_load  = 1'b1;
          dec_fp_we    = 1'b1;
          dec_fp_word  = (funct3 == 3'b010);
          dec_alu_op   = ALU_ADD;
          dec_alu_src_b_imm = 1'b1;
          selected_imm = imm_i;
          dec_mem_width = (funct3 == 3'b010) ? MEM_WORD_U : MEM_DWORD;
        end
      end

      OPCODE_STORE_FP: begin
        if ((funct3 == 3'b010) || (funct3 == 3'b011)) begin
          dec_is_store = 1'b1;
          dec_alu_op   = ALU_ADD;
          dec_alu_src_b_imm = 1'b1;
          selected_imm = imm_s;
          dec_mem_width = (funct3 == 3'b010) ? MEM_WORD : MEM_DWORD;
        end
      end

      // MISC-MEM (FENCE, FENCE.I treated as pipeline NOP / flush)
      OPCODE_MISC_MEM: begin
        dec_alu_op        = ALU_ADD;
        dec_alu_src_a_pc  = 1'b0;
        dec_alu_src_b_imm = 1'b0;
        dec_regwrite      = 1'b0;
      end

      // SYSTEM (CSR, ECALL, EBREAK, MRET, SRET, WFI, SFENCE.VMA)
      OPCODE_SYSTEM: begin
        if (funct3 == 3'b000) begin
          if (funct7 == 7'b0001001) begin
            dec_is_sfence = 1'b1;
          end else begin
            case (if_id_instr_i[31:20])
              12'h000: dec_is_ecall  = 1'b1;
              12'h001: dec_is_ebreak = 1'b1;
              12'h302: dec_is_mret   = 1'b1;
              12'h102: dec_is_sret   = 1'b1; // SRET (Supervisor Return)
              12'h105: dec_is_wfi    = 1'b1; // WFI (Wait For Interrupt)
              default: ;
            endcase
          end
        end else begin
          dec_is_csr   = 1'b1;
          dec_regwrite = 1'b1;
          if (funct3[2]) begin // Immediate CSR (CSRRWI, CSRRSI, CSRRCI)
            selected_imm = imm_csr;
          end
        end
      end

      default: ;
    endcase
  end

  assign wfi_o = if_id_valid_i && dec_is_wfi;

  // --------------------------------------------------------------------------
  // ID/EX Pipeline Register
  // --------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      id_ex_valid_o        <= 1'b0;
      id_ex_pc_o           <= '0;
      id_ex_instr_o        <= 32'h0000_0013;
      id_ex_rd_o           <= '0;
      id_ex_rs1_o          <= '0;
      id_ex_rs2_o          <= '0;
      id_ex_rs1_data_o     <= '0;
      id_ex_rs2_data_o     <= '0;
      id_ex_fp_rs3_data_o  <= '0;
      id_ex_imm_o          <= '0;
      id_ex_alu_op_o       <= ALU_ADD;
      id_ex_alu_src_a_pc_o <= 1'b0;
      id_ex_alu_src_b_imm_o<= 1'b0;
      id_ex_muldiv_op_o    <= MULDIV_NONE;
      id_ex_is_mul_o       <= 1'b0;
      id_ex_is_div_o       <= 1'b0;
      id_ex_amo_op_o       <= AMO_ADD;
      id_ex_is_amo_o       <= 1'b0;
      id_ex_is_lr_o        <= 1'b0;
      id_ex_is_sc_o        <= 1'b0;
      id_ex_is_branch_o    <= 1'b0;
      id_ex_branch_type_o  <= BRANCH_BEQ;
      id_ex_is_jal_o       <= 1'b0;
      id_ex_is_jalr_o      <= 1'b0;
      id_ex_is_c_o         <= 1'b0;
      id_ex_is_load_o      <= 1'b0;
      id_ex_is_store_o     <= 1'b0;
      id_ex_mem_width_o    <= MEM_WORD;
      id_ex_regwrite_o     <= 1'b0;
      id_ex_fp_we_o        <= 1'b0;
      id_ex_fp_rd_o        <= '0;
      id_ex_fp_word_o      <= 1'b0;
      id_ex_fp_add_o       <= 1'b0;
      id_ex_fp_sub_o       <= 1'b0;
      id_ex_fp_mul_o       <= 1'b0;
      id_ex_fp_div_o       <= 1'b0;
      id_ex_fp_cvt_o       <= 1'b0;
      id_ex_fp_class_o     <= 1'b0;
      id_ex_fp_sign_o      <= 1'b0;
      id_ex_fp_sign_op_o   <= '0;
      id_ex_fp_cmp_o      <= 1'b0;
      id_ex_fp_cmp_op_o   <= '0;
      id_ex_fp_rm_o        <= '0;
      id_ex_is_csr_o       <= 1'b0;
      id_ex_csr_op_o       <= '0;
      id_ex_csr_addr_o     <= '0;
      id_ex_is_mret_o      <= 1'b0;
      id_ex_is_sret_o      <= 1'b0;
      id_ex_is_ecall_o     <= 1'b0;
      id_ex_is_ebreak_o    <= 1'b0;
      id_ex_is_wfi_o       <= 1'b0;
      id_ex_is_sfence_o    <= 1'b0;
    end else if (flush_ex_i) begin
      id_ex_valid_o        <= 1'b0;
      id_ex_pc_o           <= '0;
      id_ex_instr_o        <= 32'h0000_0013;
      id_ex_rd_o           <= '0;
      id_ex_rs1_o          <= '0;
      id_ex_rs2_o          <= '0;
      id_ex_rs1_data_o     <= '0;
      id_ex_rs2_data_o     <= '0;
      id_ex_fp_rs3_data_o  <= '0;
      id_ex_imm_o          <= '0;
      id_ex_alu_op_o       <= ALU_ADD;
      id_ex_alu_src_a_pc_o <= 1'b0;
      id_ex_alu_src_b_imm_o<= 1'b0;
      id_ex_muldiv_op_o    <= MULDIV_NONE;
      id_ex_is_mul_o       <= 1'b0;
      id_ex_is_div_o       <= 1'b0;
      id_ex_amo_op_o       <= AMO_ADD;
      id_ex_is_amo_o       <= 1'b0;
      id_ex_is_lr_o        <= 1'b0;
      id_ex_is_sc_o        <= 1'b0;
      id_ex_is_branch_o    <= 1'b0;
      id_ex_branch_type_o  <= BRANCH_BEQ;
      id_ex_is_jal_o       <= 1'b0;
      id_ex_is_jalr_o      <= 1'b0;
      id_ex_is_c_o         <= 1'b0;
      id_ex_is_load_o      <= 1'b0;
      id_ex_is_store_o     <= 1'b0;
      id_ex_mem_width_o    <= MEM_WORD;
      id_ex_regwrite_o     <= 1'b0;
      id_ex_fp_we_o        <= 1'b0;
      id_ex_fp_rd_o        <= '0;
      id_ex_fp_word_o      <= 1'b0;
      id_ex_fp_add_o       <= 1'b0;
      id_ex_fp_sub_o       <= 1'b0;
      id_ex_fp_mul_o       <= 1'b0;
      id_ex_fp_div_o       <= 1'b0;
      id_ex_fp_cvt_o       <= 1'b0;
      id_ex_fp_class_o     <= 1'b0;
      id_ex_fp_sign_o      <= 1'b0;
      id_ex_fp_sign_op_o   <= '0;
      id_ex_fp_cmp_o      <= 1'b0;
      id_ex_fp_cmp_op_o   <= '0;
      id_ex_fp_rm_o        <= '0;
      id_ex_is_csr_o       <= 1'b0;
      id_ex_csr_op_o       <= '0;
      id_ex_csr_addr_o     <= '0;
      id_ex_is_mret_o      <= 1'b0;
      id_ex_is_sret_o      <= 1'b0;
      id_ex_is_ecall_o     <= 1'b0;
      id_ex_is_ebreak_o    <= 1'b0;
      id_ex_is_wfi_o       <= 1'b0;
      id_ex_is_sfence_o    <= 1'b0;
    end else if (!stall_ex_i) begin
      id_ex_valid_o        <= if_id_valid_i;
      id_ex_pc_o           <= if_id_pc_i;
      id_ex_instr_o        <= if_id_instr_i;
      id_ex_rd_o           <= rd;
      id_ex_rs1_o          <= rs1;
      id_ex_rs2_o          <= rs2;
      if (dec_fmv_x_w) begin
        id_ex_rs1_data_o <= {{32{fp_rs1_data[31]}}, fp_rs1_data[31:0]};
      end else if (dec_fmv_x_d) begin
        id_ex_rs1_data_o <= fp_rs1_data;
      end else if (dec_fp_add || dec_fp_mul || dec_fp_div || dec_fp_fma || dec_fp_sign || dec_fp_class || dec_fp_cmp ||
                   (dec_fp_cvt && dec_fp_cvt_src_fp)) begin
        id_ex_rs1_data_o <= fp_rs1_data;
      end else begin
        id_ex_rs1_data_o <= rf_rs1_data;
      end
      id_ex_fp_rs3_data_o  <= fp_rs3_data;
      id_ex_rs2_data_o     <= ((opcode == OPCODE_STORE_FP) || dec_fp_add || dec_fp_mul || dec_fp_div || dec_fp_fma ||
                               dec_fp_sign || dec_fp_cmp) ?
                              fp_rs2_data : rf_rs2_data;
      id_ex_imm_o          <= selected_imm;
      id_ex_alu_op_o       <= dec_alu_op;
      id_ex_alu_src_a_pc_o <= dec_alu_src_a_pc;
      id_ex_alu_src_b_imm_o<= dec_alu_src_b_imm;
      id_ex_muldiv_op_o    <= dec_muldiv_op;
      id_ex_is_mul_o       <= (dec_muldiv_op == MULDIV_MUL)    ||
                              (dec_muldiv_op == MULDIV_MULH)   ||
                              (dec_muldiv_op == MULDIV_MULHSU) ||
                              (dec_muldiv_op == MULDIV_MULHU)  ||
                              (dec_muldiv_op == MULDIV_MULW);
      id_ex_is_div_o       <= (dec_muldiv_op == MULDIV_DIV)   ||
                              (dec_muldiv_op == MULDIV_DIVU)  ||
                              (dec_muldiv_op == MULDIV_REM)   ||
                              (dec_muldiv_op == MULDIV_REMU)  ||
                              (dec_muldiv_op == MULDIV_DIVW)  ||
                              (dec_muldiv_op == MULDIV_DIVUW) ||
                              (dec_muldiv_op == MULDIV_REMW)  ||
                              (dec_muldiv_op == MULDIV_REMUW);
      id_ex_amo_op_o       <= dec_amo_op;
      id_ex_is_amo_o       <= dec_is_amo;
      id_ex_is_lr_o        <= dec_is_lr;
      id_ex_is_sc_o        <= dec_is_sc;
      id_ex_is_branch_o    <= dec_is_branch;
      id_ex_branch_type_o  <= dec_branch_type;
      id_ex_is_jal_o       <= dec_is_jal;
      id_ex_is_jalr_o      <= dec_is_jalr;
      id_ex_is_c_o         <= if_id_is_c_i;
      id_ex_is_load_o      <= dec_is_load || dec_is_lr || (dec_is_amo && !dec_is_sc);
      id_ex_is_store_o     <= dec_is_store;
      id_ex_mem_width_o    <= dec_mem_width;
      id_ex_regwrite_o     <= dec_regwrite;
      id_ex_fp_we_o        <= dec_fp_we;
      id_ex_fp_rd_o        <= rd;
      id_ex_fp_word_o      <= dec_fp_word;
      id_ex_fp_add_o       <= dec_fp_add;
      id_ex_fp_sub_o       <= dec_fp_sub;
      id_ex_fp_mul_o       <= dec_fp_mul;
      id_ex_fp_div_o       <= dec_fp_div;
      id_ex_fp_cvt_o       <= dec_fp_cvt;
      id_ex_fp_class_o     <= dec_fp_class;
      id_ex_fp_sign_o      <= dec_fp_sign;
      id_ex_fp_sign_op_o   <= funct3[1:0];
      id_ex_fp_cmp_o      <= dec_fp_cmp;
      id_ex_fp_cmp_op_o   <= dec_fp_cmp_op;
      id_ex_fp_rm_o        <= funct3;
      id_ex_is_csr_o       <= dec_is_csr;
      id_ex_csr_op_o       <= dec_csr_op;
      id_ex_csr_addr_o     <= csr_addr;
      id_ex_is_mret_o      <= dec_is_mret;
      id_ex_is_sret_o      <= dec_is_sret;
      id_ex_is_ecall_o     <= dec_is_ecall;
      id_ex_is_ebreak_o    <= dec_is_ebreak;
      id_ex_is_wfi_o       <= dec_is_wfi;
      id_ex_is_sfence_o    <= dec_is_sfence;
    end
  end

endmodule : moon_id_stage

`endif // MOON_ID_STAGE_SV
