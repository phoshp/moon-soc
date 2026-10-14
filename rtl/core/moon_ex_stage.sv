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

  // Redirection Outputs to IF Stage
  output logic             branch_taken_o,
  output logic [XLEN-1:0]  branch_target_o,

  // Multi-cycle Busy Status to Hazard Unit
  output logic             busy_div_o,

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
  logic            alu_zero;

  assign alu_in_a = id_ex_alu_src_a_pc_i  ? id_ex_pc_i  : operand_a_fwd;
  assign alu_in_b = id_ex_alu_src_b_imm_i ? id_ex_imm_i : operand_b_fwd;

  moon_alu u_alu (
    .op_i        (id_ex_alu_op_i),
    .operand_a_i (alu_in_a),
    .operand_b_i (alu_in_b),
    .result_o    (alu_result),
    .zero_o      (alu_zero)
  );

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
      ex_mem_alu_res_o   <= alu_result;
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
