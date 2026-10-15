// ============================================================================
// File: rtl/core/moon_ex_stage.sv
// Description: Execution (EX) stage and EX/MEM pipeline register for Moon-SoC
//              RV64 core, instantiating ALU, Multiplier, and Divider.
// ============================================================================

`ifndef MOON_EX_STAGE_SV
`define MOON_EX_STAGE_SV

`include "moon_pkg.sv"
`include "moon_alu.sv"
`include "moon_mul.sv"
`include "moon_div.sv"
`include "moon_fpu_add.sv"
`include "moon_fpu_mul.sv"
`include "moon_fpu_cmp.sv"
`include "moon_fpu_div.sv"
`include "moon_fpu_cvt.sv"
`include "moon_fpu_intcvt.sv"
`include "moon_fpu_sqrt.sv"
`include "moon_fpu_fma.sv"
`include "moon_vector_unit.sv"

module moon_ex_stage
  import moon_pkg::*;
(
  input  logic             clk_i,
  input  logic             rst_ni,

  // Pipeline Flow Control
  input  logic             stall_mem_i,
  input  logic             flush_mem_i,

  // Inputs from ID Stage (ID/EX Register)
  input  logic             id_ex_valid_i,
  input  logic [XLEN-1:0]  id_ex_pc_i,
  input  logic [ILEN-1:0]  id_ex_instr_i,
  input  logic [4:0]       id_ex_rd_i,
  input  logic [4:0]       id_ex_rs1_i,
  input  logic [4:0]       id_ex_rs2_i,
  input  logic [XLEN-1:0]  id_ex_rs1_data_i,
  input  logic [XLEN-1:0]  id_ex_rs2_data_i,
  input  logic [FLEN-1:0]  id_ex_fp_rs3_data_i,
  input  logic [XLEN-1:0]  id_ex_imm_i,

  // Control Signals from ID Stage
  input  alu_op_e          id_ex_alu_op_i,
  input  logic             id_ex_alu_src_a_pc_i,
  input  logic             id_ex_alu_src_b_imm_i,
  input  muldiv_op_e       id_ex_muldiv_op_i,
  input  logic             id_ex_is_mul_i,
  input  logic             id_ex_is_div_i,
  input  amo_op_e          id_ex_amo_op_i,
  input  logic             id_ex_is_amo_i,
  input  logic             id_ex_is_lr_i,
  input  logic             id_ex_is_sc_i,
  input  logic             id_ex_is_branch_i,
  input  branch_type_e     id_ex_branch_type_i,
  input  logic             id_ex_is_jal_i,
  input  logic             id_ex_is_jalr_i,
  input  logic             id_ex_is_c_i,
  input  logic             id_ex_is_load_i,
  input  logic             id_ex_is_store_i,
  input  mem_width_e       id_ex_mem_width_i,
  input  logic             id_ex_regwrite_i,
  input  logic             id_ex_fp_we_i,
  input  logic [4:0]       id_ex_fp_rd_i,
  input  logic             id_ex_fp_word_i,
  input  logic             id_ex_fp_add_i,
  input  logic             id_ex_fp_sub_i,
  input  logic             id_ex_fp_mul_i,
  input  logic             id_ex_fp_div_i,
  input  logic             id_ex_fp_cvt_i,
  input  logic             id_ex_fp_class_i,
  input  logic             id_ex_fp_sign_i,
  input  logic [1:0]       id_ex_fp_sign_op_i,
  input  logic             id_ex_fp_cmp_i,
  input  logic [2:0]       id_ex_fp_cmp_op_i,
  input  logic [2:0]       id_ex_fp_rm_i,
  input  logic [2:0]       frm_i,
  input  logic             id_ex_is_csr_i,
  input  logic [2:0]       id_ex_csr_op_i,
  input  logic [11:0]      id_ex_csr_addr_i,
  input  logic             id_ex_is_mret_i,
  input  logic             id_ex_is_sret_i,
  input  logic             id_ex_is_ecall_i,
  input  logic             id_ex_is_ebreak_i,
  input  logic             id_ex_is_wfi_i,
  input  logic             id_ex_is_sfence_i,

  // Forwarding Inputs from Hazard Unit
  input  fwd_sel_e         fwd_a_i,
  input  fwd_sel_e         fwd_b_i,
  input  logic [XLEN-1:0]  fwd_ex_data_i,  // Data from EX/MEM stage
  input  logic [XLEN-1:0]  fwd_mem_data_i, // Data from MEM/WB stage
  input  logic             vector_mem_valid_i,
  input  logic [XLEN-1:0]  vector_mem_rdata_i,
  input  logic [XLEN-1:0]  vector_vstart_i,
  input  logic             vector_mem_fault_i,

  // Redirection Outputs to IF Stage
  output logic             branch_taken_o,
  output logic [XLEN-1:0]  branch_target_o,

  // Multi-cycle Busy Status to Hazard Unit
  output logic             busy_div_o,
  output logic             vector_mem_req_o,
  output logic             vector_mem_we_o,
  output logic [XLEN-1:0]  vector_mem_addr_o,
  output logic [XLEN-1:0]  vector_mem_wdata_o,
  output logic [7:0]       vector_mem_wstrb_o,
  output logic             vector_mem_busy_o,
  output logic [XLEN-1:0]  vector_vl_o,
  output logic [XLEN-1:0]  vector_vtype_o,
  output logic             vector_vstart_clear_o,
  output logic [XLEN-1:0]  vector_mem_vstart_o,

  // Outputs to MEM Stage (EX/MEM Pipeline Register)
  output logic             ex_mem_valid_o,
  output logic [XLEN-1:0]  ex_mem_pc_o,
  output logic [XLEN-1:0]  ex_mem_link_pc_o,
  output logic [ILEN-1:0]  ex_mem_instr_o,
  output logic [4:0]       ex_mem_rd_o,
  output logic [4:0]       ex_mem_rs2_o,
  output logic [XLEN-1:0]  ex_mem_alu_res_o,
  output logic [XLEN-1:0]  ex_mem_mul_res_o,
  output logic [XLEN-1:0]  ex_mem_div_res_o,
  output logic             ex_mem_is_mul_o,
  output logic             ex_mem_is_div_o,
  output logic [XLEN-1:0]  ex_mem_rs2_data_o,
  output logic             ex_mem_is_load_o,
  output logic             ex_mem_is_store_o,
  output mem_width_e       ex_mem_mem_width_o,
  output logic             ex_mem_is_amo_o,
  output amo_op_e          ex_mem_amo_op_o,
  output logic             ex_mem_is_lr_o,
  output logic             ex_mem_is_sc_o,
  output logic             ex_mem_is_jal_o,
  output logic             ex_mem_is_jalr_o,
  output logic             ex_mem_regwrite_o,
  output logic             ex_mem_fp_we_o,
  output logic [4:0]       ex_mem_fp_rd_o,
  output logic             ex_mem_fp_word_o,
  output logic [4:0]       ex_mem_fp_flags_o,
  output logic             ex_mem_fp_flags_we_o,
  output logic             ex_mem_is_csr_o,
  output logic [2:0]       ex_mem_csr_op_o,
  output logic [11:0]      ex_mem_csr_addr_o,
  output logic [XLEN-1:0]  ex_mem_csr_wdata_o,
  output logic             ex_mem_is_mret_o,
  output logic             ex_mem_is_sret_o,
  output logic             ex_mem_is_ecall_o,
  output logic             ex_mem_is_ebreak_o,
  output logic             ex_mem_is_wfi_o,
  output logic             ex_mem_is_sfence_o
);

  // --------------------------------------------------------------------------
  // Operand Forwarding Multiplexers
  // --------------------------------------------------------------------------
  logic [XLEN-1:0] operand_a_fwd;
  logic [XLEN-1:0] operand_b_fwd;

  always_comb begin
    case (fwd_a_i)
      FWD_EX:  operand_a_fwd = fwd_ex_data_i;
      FWD_MEM: operand_a_fwd = fwd_mem_data_i;
      default: operand_a_fwd = id_ex_rs1_data_i;
    endcase

    case (fwd_b_i)
      FWD_EX:  operand_b_fwd = fwd_ex_data_i;
      FWD_MEM: operand_b_fwd = fwd_mem_data_i;
      default: operand_b_fwd = id_ex_rs2_data_i;
    endcase
  end

  // --------------------------------------------------------------------------
  // ALU Operand Preparation
  // --------------------------------------------------------------------------
  logic [XLEN-1:0] alu_in_a;
  logic [XLEN-1:0] alu_in_b;
  logic [XLEN-1:0] alu_result;
  logic [XLEN-1:0] vector_scalar_result;
  logic            vector_scalar_result_valid;
  logic            vector_unit_mem_req;
  logic            vector_unit_mem_we;
  logic [XLEN-1:0] vector_unit_mem_addr;
  logic [XLEN-1:0] vector_unit_mem_wdata;
  logic [7:0]      vector_unit_mem_wstrb;
  logic            alu_zero;
  logic [FLEN-1:0] fp_add_result;
  logic [4:0]      fp_add_flags;
  logic [FLEN-1:0] fp_mul_result;
  logic [4:0]      fp_mul_flags;
  logic [FLEN-1:0] fp_cmp_result;
  logic [4:0]      fp_cmp_flags;
  logic [FLEN-1:0] fp_div_result;
  logic [4:0]      fp_div_flags;
  logic [FLEN-1:0] fp_sqrt_result;
  logic [4:0]      fp_sqrt_flags;
  logic            fp_sqrt_instruction;
  logic [FLEN-1:0] fp_fma_result;
  logic [4:0]      fp_fma_flags;
  logic            fp_fma_instruction;
  logic [FLEN-1:0] fp_result_selected;
  logic [4:0]      fp_flags_selected;
  logic [FLEN-1:0] fp_cvt_result;
  logic [4:0]      fp_cvt_flags;
  logic [FLEN-1:0] fp_int_cvt_result;
  logic [4:0]      fp_int_cvt_flags;
  logic            fp_int_cvt_instruction;
  logic [XLEN-1:0] fp_class_result;
  logic [FLEN-1:0] fp_sign_result;
  logic [2:0]      fp_rounding_mode;

  always_comb begin : fp_misc_comb
    logic sign_a, sign_b, sign_out;
    logic [10:0] exp_field;
    logic [51:0] fraction;
    logic [9:0] class_bits;

    sign_a = id_ex_fp_word_i ? id_ex_rs1_data_i[31] : id_ex_rs1_data_i[63];
    sign_b = id_ex_fp_word_i ? id_ex_rs2_data_i[31] : id_ex_rs2_data_i[63];
    case (id_ex_fp_sign_op_i)
      2'b00: sign_out = sign_b;
      2'b01: sign_out = ~sign_b;
      default: sign_out = sign_a ^ sign_b;
    endcase
    if (id_ex_fp_word_i) begin
      if ((id_ex_rs1_data_i[63:32] != 32'hffff_ffff) ||
          (id_ex_rs2_data_i[63:32] != 32'hffff_ffff))
        fp_sign_result = 64'hffff_ffff_7fc0_0000;
      else
        fp_sign_result = {32'hffff_ffff, sign_out, id_ex_rs1_data_i[30:0]};
    end else begin
      fp_sign_result = {sign_out, id_ex_rs1_data_i[62:0]};
    end

    exp_field = id_ex_fp_word_i ? {3'b0, id_ex_rs1_data_i[30:23]} : id_ex_rs1_data_i[62:52];
    fraction = id_ex_fp_word_i ? {29'b0, id_ex_rs1_data_i[22:0]} : id_ex_rs1_data_i[51:0];
    class_bits = '0;
    if (id_ex_fp_word_i && (id_ex_rs1_data_i[63:32] != 32'hffff_ffff)) begin
      class_bits[9] = 1'b1;
    end else if ((exp_field == (id_ex_fp_word_i ? 11'h0ff : 11'h7ff)) && (fraction == 0)) begin
      class_bits[sign_a ? 0 : 7] = 1'b1;
    end else if (exp_field == (id_ex_fp_word_i ? 11'h0ff : 11'h7ff)) begin
      class_bits[fraction[id_ex_fp_word_i ? 22 : 51] ? 9 : 8] = 1'b1;
    end else if (exp_field == 0) begin
      if (fraction == 0) class_bits[sign_a ? 3 : 4] = 1'b1;
      else class_bits[sign_a ? 2 : 5] = 1'b1;
    end else begin
      class_bits[sign_a ? 1 : 6] = 1'b1;
    end
    fp_class_result = {54'd0, class_bits};
  end

  assign fp_rounding_mode = (id_ex_fp_rm_i == 3'b111) ? frm_i : id_ex_fp_rm_i;

  moon_fpu_add u_fpu_add (
    .operand_a_i       (id_ex_rs1_data_i),
    .operand_b_i       (id_ex_rs2_data_i),
    .is_single_i       (id_ex_fp_word_i),
    .subtract_i        (id_ex_fp_sub_i),
    .rounding_mode_i   (fp_rounding_mode),
    .result_o          (fp_add_result),
    .flags_o           (fp_add_flags)
  );

  moon_fpu_mul u_fpu_mul (
    .operand_a_i       (id_ex_rs1_data_i),
    .operand_b_i       (id_ex_rs2_data_i),
    .is_single_i       (id_ex_fp_word_i),
    .rounding_mode_i   (fp_rounding_mode),
    .result_o          (fp_mul_result),
    .flags_o           (fp_mul_flags)
  );

  moon_fpu_cmp u_fpu_cmp (
    .operand_a_i (id_ex_rs1_data_i),
    .operand_b_i (id_ex_rs2_data_i),
    .is_single_i (id_ex_fp_word_i),
    .operation_i (id_ex_fp_cmp_op_i),
    .result_o    (fp_cmp_result),
    .flags_o     (fp_cmp_flags)
  );

  moon_fpu_div u_fpu_div (
    .operand_a_i       (id_ex_rs1_data_i),
    .operand_b_i       (id_ex_rs2_data_i),
    .is_single_i       (id_ex_fp_word_i),
    .rounding_mode_i   (fp_rounding_mode),
    .result_o          (fp_div_result),
    .flags_o           (fp_div_flags)
  );

  moon_fpu_sqrt u_fpu_sqrt (
    .operand_i       (id_ex_rs1_data_i),
    .is_single_i     (id_ex_fp_word_i),
    .rounding_mode_i (fp_rounding_mode),
    .result_o        (fp_sqrt_result),
    .flags_o         (fp_sqrt_flags)
  );

  moon_fpu_fma u_fpu_fma (
    .operand_a_i     (id_ex_rs1_data_i),
    .operand_b_i     (id_ex_rs2_data_i),
    .operand_c_i     (id_ex_fp_rs3_data_i),
    .format_i        (id_ex_instr_i[26:25]),
    .opcode_i        (id_ex_instr_i[6:0]),
    .rounding_mode_i (fp_rounding_mode),
    .result_o        (fp_fma_result),
    .flags_o         (fp_fma_flags)
  );

  assign fp_fma_instruction = (id_ex_instr_i[6:0] == 7'b1000011) ||
                              (id_ex_instr_i[6:0] == 7'b1000111) ||
                              (id_ex_instr_i[6:0] == 7'b1001011) ||
                              (id_ex_instr_i[6:0] == 7'b1001111);

  assign fp_sqrt_instruction = (id_ex_instr_i[31:25] == 7'b0101100) ||
                               (id_ex_instr_i[31:25] == 7'b0101101);

  moon_fpu_cvt u_fpu_cvt (
    .operand_i       (id_ex_rs1_data_i),
    .single_source_i (id_ex_instr_i[25]),
    .rounding_mode_i (fp_rounding_mode),
    .result_o        (fp_cvt_result),
    .flags_o         (fp_cvt_flags)
  );

  moon_fpu_intcvt u_fpu_intcvt (
    .operand_i       ((id_ex_instr_i[31:27] == 5'b11010) ? operand_a_fwd : id_ex_rs1_data_i),
    .instruction_i   (id_ex_instr_i),
    .rounding_mode_i (fp_rounding_mode),
    .result_o        (fp_int_cvt_result),
    .flags_o         (fp_int_cvt_flags)
  );

  assign fp_int_cvt_instruction = (id_ex_instr_i[31:27] == 5'b11000) ||
                                  (id_ex_instr_i[31:27] == 5'b11010);

  always_comb begin
    if (fp_fma_instruction) fp_result_selected = fp_fma_result;
    else if (id_ex_fp_cvt_i)
      fp_result_selected = fp_int_cvt_instruction ? fp_int_cvt_result : fp_cvt_result;
    else if (id_ex_fp_div_i)
      fp_result_selected = fp_sqrt_instruction ? fp_sqrt_result : fp_div_result;
    else if (id_ex_fp_mul_i) fp_result_selected = fp_mul_result;
    else if (id_ex_fp_add_i) fp_result_selected = fp_add_result;
    else if (id_ex_fp_cmp_i) fp_result_selected = fp_cmp_result;
    else if (id_ex_fp_sign_i) fp_result_selected = fp_sign_result;
    else if (id_ex_fp_class_i) fp_result_selected = fp_class_result;
    else if (vector_scalar_result_valid) fp_result_selected = vector_scalar_result;
    else fp_result_selected = alu_result;

    if (fp_fma_instruction) fp_flags_selected = fp_fma_flags;
    else if (id_ex_fp_cvt_i)
      fp_flags_selected = fp_int_cvt_instruction ? fp_int_cvt_flags : fp_cvt_flags;
    else if (id_ex_fp_div_i)
      fp_flags_selected = fp_sqrt_instruction ? fp_sqrt_flags : fp_div_flags;
    else if (id_ex_fp_mul_i) fp_flags_selected = fp_mul_flags;
    else if (id_ex_fp_cmp_i) fp_flags_selected = fp_cmp_flags;
    else fp_flags_selected = fp_add_flags;
  end

  assign alu_in_a = id_ex_alu_src_a_pc_i  ? id_ex_pc_i  : operand_a_fwd;
  assign alu_in_b = id_ex_alu_src_b_imm_i ? id_ex_imm_i : operand_b_fwd;

  moon_alu u_alu (
    .op_i        (id_ex_alu_op_i),
    .operand_a_i (alu_in_a),
    .operand_b_i (alu_in_b),
    .result_o    (alu_result),
    .zero_o      (alu_zero)
  );

  moon_vector_unit u_vector_unit (
    .clk_i                  (clk_i),
    .rst_ni                 (rst_ni),
    .valid_i                (id_ex_valid_i),
    .advance_i              (!stall_mem_i && !flush_mem_i),
    .instr_i                (id_ex_instr_i),
    .scalar_rs1_i           (operand_a_fwd),
    .scalar_rs2_i           (operand_b_fwd),
    .vector_vstart_i        (vector_vstart_i),
    .vector_mem_fault_i     (vector_mem_fault_i),
    .vector_vstart_clear_o  (vector_vstart_clear_o),
    .vector_mem_vstart_o    (vector_mem_vstart_o),
    .vector_vl_o            (vector_vl_o),
    .vector_vtype_o         (vector_vtype_o),
    .scalar_result_valid_o  (vector_scalar_result_valid),
    .scalar_result_o        (vector_scalar_result),
    .mem_req_o              (vector_unit_mem_req),
    .mem_we_o               (vector_unit_mem_we),
    .mem_addr_o             (vector_unit_mem_addr),
    .mem_wdata_o            (vector_unit_mem_wdata),
    .mem_wstrb_o             (vector_unit_mem_wstrb),
    .mem_valid_i             (vector_mem_valid_i),
    .mem_rdata_i             (vector_mem_rdata_i),
    .mem_busy_o              (vector_mem_busy_o)
  );

  assign vector_mem_req_o = vector_unit_mem_req;
  assign vector_mem_we_o = vector_unit_mem_we;
  assign vector_mem_addr_o = vector_unit_mem_addr;
  assign vector_mem_wdata_o = vector_unit_mem_wdata;
  assign vector_mem_wstrb_o = vector_unit_mem_wstrb;

  // --------------------------------------------------------------------------
  // Hardware Multiplier Instantiation (RV64M)
  // --------------------------------------------------------------------------
  wire is_mul_op = (id_ex_muldiv_op_i == MULDIV_MUL)    ||
                   (id_ex_muldiv_op_i == MULDIV_MULH)   ||
                   (id_ex_muldiv_op_i == MULDIV_MULHSU) ||
                   (id_ex_muldiv_op_i == MULDIV_MULHU)  ||
                   (id_ex_muldiv_op_i == MULDIV_MULW);

  logic [XLEN-1:0] mul_result;
  logic            mul_ready;

  moon_mul u_mul (
    .clk_i       (clk_i),
    .rst_ni      (rst_ni),
    .valid_i     (id_ex_valid_i && is_mul_op),
    .op_i        (id_ex_muldiv_op_i),
    .operand_a_i (operand_a_fwd),
    .operand_b_i (operand_b_fwd),
    .ready_o     (mul_ready),
    .result_o    (mul_result)
  );

  // --------------------------------------------------------------------------
  // Hardware Divider Instantiation (RV64M)
  // --------------------------------------------------------------------------
  wire is_div_op = (id_ex_muldiv_op_i == MULDIV_DIV)   ||
                   (id_ex_muldiv_op_i == MULDIV_DIVU)  ||
                   (id_ex_muldiv_op_i == MULDIV_REM)   ||
                   (id_ex_muldiv_op_i == MULDIV_REMU)  ||
                   (id_ex_muldiv_op_i == MULDIV_DIVW)  ||
                   (id_ex_muldiv_op_i == MULDIV_DIVUW) ||
                   (id_ex_muldiv_op_i == MULDIV_REMW)  ||
                   (id_ex_muldiv_op_i == MULDIV_REMUW);

  logic [XLEN-1:0] div_result;
  logic            div_ready;

  moon_div u_div (
    .clk_i       (clk_i),
    .rst_ni      (rst_ni),
    .valid_i     (id_ex_valid_i && is_div_op),
    .op_i        (id_ex_muldiv_op_i),
    .operand_a_i (operand_a_fwd),
    .operand_b_i (operand_b_fwd),
    .ready_o     (div_ready),
    .result_o    (div_result)
  );

  assign busy_div_o = id_ex_valid_i && is_div_op && !div_ready;

  // --------------------------------------------------------------------------
  // Branch & Jump Evaluation
  // --------------------------------------------------------------------------
  logic branch_cond_met;

  always_comb begin
    case (id_ex_branch_type_i)
      BRANCH_BEQ:  branch_cond_met = (operand_a_fwd == operand_b_fwd);
      BRANCH_BNE:  branch_cond_met = (operand_a_fwd != operand_b_fwd);
      BRANCH_BLT:  branch_cond_met = ($signed(operand_a_fwd) < $signed(operand_b_fwd));
      BRANCH_BGE:  branch_cond_met = ($signed(operand_a_fwd) >= $signed(operand_b_fwd));
      BRANCH_BLTU: branch_cond_met = (operand_a_fwd < operand_b_fwd);
      BRANCH_BGEU: branch_cond_met = (operand_a_fwd >= operand_b_fwd);
      default:     branch_cond_met = 1'b0;
    endcase
  end

  assign branch_taken_o = id_ex_valid_i &&
                          ((id_ex_is_branch_i && branch_cond_met) ||
                            id_ex_is_jal_i || id_ex_is_jalr_i);

  always_comb begin
    if (id_ex_is_jalr_i) begin
      branch_target_o = (operand_a_fwd + id_ex_imm_i) & ~64'd1;
    end else begin
      branch_target_o = id_ex_pc_i + id_ex_imm_i;
    end
  end

  // Link address for JAL / JALR (PC + 2 for compressed, PC + 4 for 32-bit)
  wire [XLEN-1:0] link_pc = id_ex_pc_i + (id_ex_is_c_i ? 64'd2 : 64'd4);

  // --------------------------------------------------------------------------
  // EX/MEM Pipeline Register
  // --------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ex_mem_valid_o     <= 1'b0;
      ex_mem_pc_o        <= '0;
      ex_mem_link_pc_o   <= '0;
      ex_mem_instr_o     <= 32'h0000_0013;
      ex_mem_rd_o        <= '0;
      ex_mem_rs2_o       <= '0;
      ex_mem_alu_res_o   <= '0;
      ex_mem_mul_res_o   <= '0;
      ex_mem_div_res_o   <= '0;
      ex_mem_is_mul_o    <= 1'b0;
      ex_mem_is_div_o    <= 1'b0;
      ex_mem_rs2_data_o  <= '0;
      ex_mem_is_load_o   <= 1'b0;
      ex_mem_is_store_o  <= 1'b0;
      ex_mem_mem_width_o <= MEM_WORD;
      ex_mem_is_amo_o    <= 1'b0;
      ex_mem_amo_op_o    <= AMO_ADD;
      ex_mem_is_lr_o     <= 1'b0;
      ex_mem_is_sc_o     <= 1'b0;
      ex_mem_is_jal_o    <= 1'b0;
      ex_mem_is_jalr_o   <= 1'b0;
      ex_mem_regwrite_o  <= 1'b0;
      ex_mem_fp_we_o     <= 1'b0;
      ex_mem_fp_rd_o     <= '0;
      ex_mem_fp_word_o   <= 1'b0;
      ex_mem_fp_flags_o  <= '0;
      ex_mem_fp_flags_we_o <= 1'b0;
      ex_mem_is_csr_o    <= 1'b0;
      ex_mem_csr_op_o    <= '0;
      ex_mem_csr_addr_o  <= '0;
      ex_mem_csr_wdata_o <= '0;
      ex_mem_is_mret_o   <= 1'b0;
      ex_mem_is_sret_o   <= 1'b0;
      ex_mem_is_ecall_o  <= 1'b0;
      ex_mem_is_ebreak_o <= 1'b0;
      ex_mem_is_wfi_o    <= 1'b0;
      ex_mem_is_sfence_o <= 1'b0;
    end else if (flush_mem_i) begin
      ex_mem_valid_o     <= 1'b0;
      ex_mem_pc_o        <= '0;
      ex_mem_link_pc_o   <= '0;
      ex_mem_instr_o     <= 32'h0000_0013;
      ex_mem_rd_o        <= '0;
      ex_mem_rs2_o       <= '0;
      ex_mem_alu_res_o   <= '0;
      ex_mem_mul_res_o   <= '0;
      ex_mem_div_res_o   <= '0;
      ex_mem_is_mul_o    <= 1'b0;
      ex_mem_is_div_o    <= 1'b0;
      ex_mem_rs2_data_o  <= '0;
      ex_mem_is_load_o   <= 1'b0;
      ex_mem_is_store_o  <= 1'b0;
      ex_mem_mem_width_o <= MEM_WORD;
      ex_mem_is_amo_o    <= 1'b0;
      ex_mem_amo_op_o    <= AMO_ADD;
      ex_mem_is_lr_o     <= 1'b0;
      ex_mem_is_sc_o     <= 1'b0;
      ex_mem_is_jal_o    <= 1'b0;
      ex_mem_is_jalr_o   <= 1'b0;
      ex_mem_regwrite_o  <= 1'b0;
      ex_mem_fp_we_o     <= 1'b0;
      ex_mem_fp_rd_o     <= '0;
      ex_mem_fp_word_o   <= 1'b0;
      ex_mem_fp_flags_o  <= '0;
      ex_mem_fp_flags_we_o <= 1'b0;
      ex_mem_is_csr_o    <= 1'b0;
      ex_mem_csr_op_o    <= '0;
      ex_mem_csr_addr_o  <= '0;
      ex_mem_csr_wdata_o <= '0;
      ex_mem_is_mret_o   <= 1'b0;
      ex_mem_is_sret_o   <= 1'b0;
      ex_mem_is_ecall_o  <= 1'b0;
      ex_mem_is_ebreak_o <= 1'b0;
      ex_mem_is_wfi_o    <= 1'b0;
      ex_mem_is_sfence_o <= 1'b0;
    end else if (!stall_mem_i) begin
      ex_mem_valid_o     <= id_ex_valid_i;
      ex_mem_pc_o        <= id_ex_pc_i;
      ex_mem_link_pc_o   <= link_pc;
      ex_mem_instr_o     <= id_ex_instr_i;
      ex_mem_rd_o        <= id_ex_rd_i;
      ex_mem_rs2_o       <= id_ex_rs2_i;
      ex_mem_alu_res_o   <= fp_result_selected;
      ex_mem_mul_res_o   <= mul_result;
      ex_mem_div_res_o   <= div_result;
      ex_mem_is_mul_o    <= id_ex_is_mul_i;
      ex_mem_is_div_o    <= id_ex_is_div_i;
      ex_mem_rs2_data_o  <= operand_b_fwd;
      ex_mem_is_load_o   <= id_ex_is_load_i;
      ex_mem_is_store_o  <= id_ex_is_store_i;
      ex_mem_mem_width_o <= id_ex_mem_width_i;
      ex_mem_is_amo_o    <= id_ex_is_amo_i;
      ex_mem_amo_op_o    <= id_ex_amo_op_i;
      ex_mem_is_lr_o     <= id_ex_is_lr_i;
      ex_mem_is_sc_o     <= id_ex_is_sc_i;
      ex_mem_is_jal_o    <= id_ex_is_jal_i;
      ex_mem_is_jalr_o   <= id_ex_is_jalr_i;
      ex_mem_regwrite_o  <= id_ex_regwrite_i;
      ex_mem_fp_we_o     <= id_ex_fp_we_i;
      ex_mem_fp_rd_o     <= id_ex_fp_rd_i;
      ex_mem_fp_word_o   <= id_ex_fp_word_i;
      ex_mem_fp_flags_o  <= fp_flags_selected;
      ex_mem_fp_flags_we_o <= id_ex_fp_add_i || id_ex_fp_mul_i ||
                              id_ex_fp_div_i || id_ex_fp_cvt_i || id_ex_fp_cmp_i ||
                              fp_fma_instruction;
      ex_mem_is_csr_o    <= id_ex_is_csr_i;
      ex_mem_csr_op_o    <= id_ex_csr_op_i;
      ex_mem_csr_addr_o  <= id_ex_csr_addr_i;
      ex_mem_csr_wdata_o <= id_ex_csr_op_i[2] ? id_ex_imm_i : operand_a_fwd;
      ex_mem_is_mret_o   <= id_ex_is_mret_i;
      ex_mem_is_sret_o   <= id_ex_is_sret_i;
      ex_mem_is_ecall_o  <= id_ex_is_ecall_i;
      ex_mem_is_ebreak_o <= id_ex_is_ebreak_i;
      ex_mem_is_wfi_o    <= id_ex_is_wfi_i;
      ex_mem_is_sfence_o <= id_ex_is_sfence_i;
    end
  end

endmodule : moon_ex_stage

`endif // MOON_EX_STAGE_SV
