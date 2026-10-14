// ============================================================================
// File: rtl/core/moon_core.sv
// Description: RV64IMA Pipelined CPU Core (`moon_core`) integrating 5-stage
//              pipeline, hazard unit, CSR unit, and parameterized hart ID.
// ============================================================================

`ifndef MOON_CORE_SV
`define MOON_CORE_SV

`include "moon_pkg.sv"
`include "moon_fregfile.sv"
`include "moon_fpu_add.sv"
`include "moon_fpu_mul.sv"
`include "moon_if_stage.sv"
`include "moon_id_stage.sv"
`include "moon_ex_stage.sv"
`include "moon_mem_stage.sv"
`include "moon_wb_stage.sv"
`include "moon_hazard_unit.sv"
`include "moon_csr.sv"
`include "moon_pmp.sv"
`include "mmu/moon_mmu.sv"

module moon_core
  import moon_pkg::*;
#(
  parameter int HART_ID = 0
)(
  input  logic             clk_i,
  input  logic             rst_ni,

  // Instruction Memory Bus Interface (L1-I Cache / Arbiter)
  output logic             imem_req_o,
  output logic [XLEN-1:0]  imem_addr_o,
  input  logic             imem_valid_i,
  input  logic [ILEN-1:0]  imem_rdata_i,

  // Data Memory Bus Interface (L1-D Cache / Arbiter)
  output logic             dmem_req_o,
  output logic             dmem_we_o,
  output logic [XLEN-1:0]  dmem_addr_o,
  output logic [XLEN-1:0]  dmem_wdata_o,
  output logic [7:0]       dmem_wstrb_o,
  input  logic             dmem_valid_i,
  input  logic [XLEN-1:0]  dmem_rdata_i,

  // Hardware Interrupt Lines
  input  logic             timer_irq_i,    // from CLINT
  input  logic             software_irq_i, // from CLINT (IPI)
  input  logic             external_irq_i, // from PLIC

  // Coherence Invalidation Line from Snooping / Shared L2
  input  logic             inv_valid_i,
  input  logic [XLEN-1:0]  inv_addr_i,

  // Power Management & Hardware Status Signals
  output logic             wfi_o,
  output logic             interrupt_pending_o
);

  // --------------------------------------------------------------------------
  // Inter-Stage Interconnect Signals
  // --------------------------------------------------------------------------
  // IF to ID
  logic [XLEN-1:0]  if_id_pc;
  logic [ILEN-1:0]  if_id_instr;
  logic             if_id_is_c;
  logic             if_id_valid;

  // ID to Hazard Unit & EX
  logic [4:0]       id_rs1;
  logic [4:0]       id_rs2;
  logic [4:0]       id_fp_rs1;
  logic             id_fp_rs1_en;
  logic [4:0]       id_fp_rs2;
  logic             id_fp_rs2_en;
  logic             id_ex_valid;
  logic [XLEN-1:0]  id_ex_pc;
  logic [ILEN-1:0]  id_ex_instr;
  logic             id_ex_is_c;
  logic [4:0]       id_ex_rd;
  logic [4:0]       id_ex_rs1;
  logic [4:0]       id_ex_rs2;
  logic [XLEN-1:0]  id_ex_rs1_data;
  logic [XLEN-1:0]  id_ex_rs2_data;
  logic [XLEN-1:0]  id_ex_imm;
  alu_op_e          id_ex_alu_op;
  logic             id_ex_alu_src_a_pc;
  logic             id_ex_alu_src_b_imm;
  muldiv_op_e       id_ex_muldiv_op;
  logic             id_ex_is_mul;
  logic             id_ex_is_div;
  amo_op_e          id_ex_amo_op;
  logic             id_ex_is_amo;
  logic             id_ex_is_lr;
  logic             id_ex_is_sc;
  logic             id_ex_is_branch;
  branch_type_e     id_ex_branch_type;
  logic             id_ex_is_jal;
  logic             id_ex_is_jalr;
  logic             id_ex_is_load;
  logic             id_ex_is_store;
  mem_width_e       id_ex_mem_width;
  logic             id_ex_regwrite;
  logic             id_ex_fp_we;
  logic [4:0]       id_ex_fp_rd;
  logic             id_ex_fp_word;
  logic             id_ex_fp_add;
  logic             id_ex_fp_sub;
  logic             id_ex_fp_mul;
  logic [2:0]       id_ex_fp_rm;
  logic             id_ex_is_csr;
  logic [2:0]       id_ex_csr_op;
  logic [11:0]      id_ex_csr_addr;
  logic             id_ex_is_mret;
  logic             id_ex_is_sret;
  logic             id_ex_is_ecall;
  logic             id_ex_is_ebreak;
  logic             id_ex_is_wfi;
  logic             id_ex_is_sfence;

  // EX to IF, Hazard, MEM
  logic             branch_taken;
  logic [XLEN-1:0]  branch_target;
  logic             busy_div;
  logic             ex_mem_valid;
  logic [XLEN-1:0]  ex_mem_pc;
  logic [XLEN-1:0]  ex_mem_link_pc;
  logic [ILEN-1:0]  ex_mem_instr;
  logic [4:0]       ex_mem_rd;
  logic [4:0]       ex_mem_rs2;
  logic [XLEN-1:0]  ex_mem_alu_res;
  logic [XLEN-1:0]  ex_mem_mul_res;
  logic [XLEN-1:0]  ex_mem_div_res;
  logic             ex_mem_is_mul;
  logic             ex_mem_is_div;
  logic [XLEN-1:0]  ex_mem_rs2_data;
  logic             ex_mem_is_load;
  logic             ex_mem_is_store;
  mem_width_e       ex_mem_mem_width;
  logic             ex_mem_is_amo;
  amo_op_e          ex_mem_amo_op;
  logic             ex_mem_is_lr;
  logic             ex_mem_is_sc;
  logic             ex_mem_is_jal;
  logic             ex_mem_is_jalr;
  logic             ex_mem_regwrite;
  logic             ex_mem_fp_we;
  logic [4:0]       ex_mem_fp_rd;
  logic             ex_mem_fp_word;
  logic [4:0]       ex_mem_fp_flags;
  logic             ex_mem_fp_flags_we;
  logic             ex_mem_is_csr;
  logic [2:0]       ex_mem_csr_op;
  logic [11:0]      ex_mem_csr_addr;
  logic [XLEN-1:0]  ex_mem_csr_wdata;
  logic             ex_mem_is_mret;
  logic             ex_mem_is_sret;
  logic             ex_mem_is_ecall;
  logic             ex_mem_is_ebreak;
  logic             ex_mem_is_wfi;
  logic             ex_mem_is_sfence;

  // MMU & Translation Signals
  logic             mmu_busy;
  logic             ptw_mem_req;
  logic [XLEN-1:0]  ptw_mem_addr;
  logic             ptw_mem_valid;
  logic [XLEN-1:0]  ptw_mem_rdata;
  logic             mmu_fetch_hit;
  logic [XLEN-1:0]  imem_vaddr;
  logic [XLEN-1:0]  mmu_fetch_paddr;
  logic             mmu_fetch_page_fault;
  logic             core_dmem_req;
  logic             core_dmem_we;
  logic [XLEN-1:0]  dmem_vaddr;
  logic [XLEN-1:0]  core_dmem_wdata;
  logic [7:0]       core_dmem_wstrb;
  logic             mmu_data_hit;
  logic [XLEN-1:0]  mmu_data_paddr;
  logic             mmu_load_page_fault;
  logic             mmu_store_page_fault;

  // MEM to WB
  logic             mem_wb_valid;
  logic [XLEN-1:0]  mem_wb_pc;
  logic [4:0]       mem_wb_rd;
  logic [XLEN-1:0]  mem_wb_alu_res;
  logic [XLEN-1:0]  mem_wb_mul_res;
  logic [XLEN-1:0]  mem_wb_div_res;
  logic             mem_wb_is_mul;
  logic             mem_wb_is_div;
  logic [XLEN-1:0]  mem_wb_mem_data;
  logic [XLEN-1:0]  mem_wb_link_pc;
  logic             mem_wb_is_load;

  logic             mem_sc_success;
  logic [XLEN-1:0]  mem_aligned_load_data;
  logic [XLEN-1:0]  ex_fwd_val;

  always_comb begin
    if (ex_mem_is_jal || ex_mem_is_jalr) begin
      ex_fwd_val = ex_mem_link_pc;
    end else if (ex_mem_is_mul) begin
      ex_fwd_val = ex_mem_mul_res;
    end else if (ex_mem_is_div) begin
      ex_fwd_val = ex_mem_div_res;
    end else if (ex_mem_is_sc) begin
      ex_fwd_val = mem_sc_success ? 64'd0 : 64'd1;
    end else if (ex_mem_is_load || ex_mem_is_lr || (ex_mem_is_amo && !ex_mem_is_sc)) begin
      ex_fwd_val = mem_aligned_load_data;
    end else begin
      ex_fwd_val = ex_mem_alu_res;
    end
  end
  logic             mem_wb_is_jal;
  logic             mem_wb_is_jalr;
  logic             mem_wb_regwrite;
  logic             mem_wb_fp_we;
  logic [4:0]       mem_wb_fp_rd;
  logic             mem_wb_fp_word;
  logic [4:0]       mem_wb_fp_flags;
  logic             mem_wb_fp_flags_we;
  logic             mem_wb_is_csr;
  logic [2:0]       mem_wb_csr_op;
  logic [11:0]      mem_wb_csr_addr;
  logic [XLEN-1:0]  mem_wb_csr_wdata;
  logic             mem_wb_is_mret;
  logic             mem_wb_is_ecall;
  logic             mem_wb_is_ebreak;
  logic             mem_wb_sc_success;
  logic             mem_wb_is_sc;

  // WB Outputs
  logic             wb_regwrite;
  logic [4:0]       wb_rd;
  logic [XLEN-1:0]  wb_wdata;
  logic [FLEN-1:0]  wb_fp_wdata;

  assign wb_fp_wdata = mem_wb_fp_word ? {32'hffff_ffff, wb_wdata[31:0]} : wb_wdata;

  // Hazard and Forwarding
  fwd_sel_e         fwd_a;
  fwd_sel_e         fwd_b;
  logic             stall_if, stall_id, stall_ex, stall_mem;
  logic             flush_id, flush_ex, flush_mem;

  // CSR & Trap Interface
  logic [XLEN-1:0]  trap_vector;
  logic [XLEN-1:0]  mepc;
  logic [XLEN-1:0]  sepc;
  priv_lvl_e        priv_lvl;
  logic [XLEN-1:0]  satp;
  logic             sum;
  logic             mxr;
  logic [7:0]       pmpcfg [0:15];
  logic [XLEN-1:0]  pmpaddr [0:15];
  logic             pmp_fetch_fault;
  logic             pmp_load_fault;
  logic             pmp_store_fault;
  logic             trap_enter;
  logic             is_interrupt;
  logic [62:0]      trap_cause;
  logic [XLEN-1:0]  trap_val;
  logic             interrupt_pending;
  logic [62:0]      interrupt_cause;
  logic [XLEN-1:0]  csr_rdata;

  // --------------------------------------------------------------------------
  // Trap Controller Logic
  // --------------------------------------------------------------------------
  logic [XLEN-1:0] trap_pc;

  always_comb begin
    trap_enter   = 1'b0;
    is_interrupt = 1'b0;
    trap_cause   = '0;
    trap_val     = '0;
    trap_pc      = ex_mem_pc;

    if (interrupt_pending) begin
      trap_enter   = 1'b1;
      is_interrupt = 1'b1;
      trap_cause   = interrupt_cause;
      // For interrupts, pick the PC of the oldest unretired valid instruction in pipeline
      // If taking an interrupt on WFI, mepc points to instruction after WFI (WFI PC + 4)
      if (ex_mem_valid && ex_mem_is_wfi) begin
        trap_pc = ex_mem_pc + 64'd4;
      end else if (id_ex_valid && id_ex_is_wfi) begin
        trap_pc = id_ex_pc + 64'd4;
      end else if (if_id_valid && if_id_instr == 32'h1050_0073) begin
        trap_pc = if_id_pc + 64'd4;
      end else if (ex_mem_valid) begin
        trap_pc = ex_mem_pc;
      end else if (id_ex_valid) begin
        trap_pc = id_ex_pc;
      end else if (if_id_valid) begin
        trap_pc = if_id_pc;
      end else begin
        trap_pc = imem_addr_o;
      end
      trap_val     = trap_pc;
    end else if (ex_mem_valid && ex_mem_is_ecall) begin
      trap_enter   = 1'b1;
      is_interrupt = 1'b0;
      if (priv_lvl == PRV_U) begin
        trap_cause = CAUSE_ECALL_U_MODE;
      end else if (priv_lvl == PRV_S) begin
        trap_cause = CAUSE_ECALL_S_MODE;
      end else begin
        trap_cause = CAUSE_ECALL_M_MODE;
      end
      trap_val     = '0;
      trap_pc      = ex_mem_pc;
    end else if (ex_mem_valid && ex_mem_is_ebreak) begin
      trap_enter   = 1'b1;
      is_interrupt = 1'b0;
      trap_cause   = CAUSE_BREAKPOINT;
      trap_val     = ex_mem_pc;
      trap_pc      = ex_mem_pc;
    end else if (core_dmem_req && mmu_load_page_fault) begin
      trap_enter   = 1'b1;
      is_interrupt = 1'b0;
      trap_cause   = CAUSE_PAGE_FAULT_LOAD;
      trap_val     = dmem_vaddr;
      trap_pc      = ex_mem_pc;
    end else if (core_dmem_req && mmu_store_page_fault) begin
      trap_enter   = 1'b1;
      is_interrupt = 1'b0;
      trap_cause   = CAUSE_PAGE_FAULT_STORE;
      trap_val     = dmem_vaddr;
      trap_pc      = ex_mem_pc;
    end else if (imem_req_o && mmu_fetch_page_fault) begin
      trap_enter   = 1'b1;
      is_interrupt = 1'b0;
      trap_cause   = CAUSE_PAGE_FAULT_FETCH;
      trap_val     = imem_vaddr;
      trap_pc      = if_id_pc;
    end else if (pmp_load_fault) begin
      trap_enter   = 1'b1;
      is_interrupt = 1'b0;
      trap_cause   = CAUSE_LOAD_ACCESS_FAULT;
      trap_val     = dmem_addr_o;
      trap_pc      = ex_mem_pc;
    end else if (pmp_store_fault) begin
      trap_enter   = 1'b1;
      is_interrupt = 1'b0;
      trap_cause   = CAUSE_STORE_ACCESS_FAULT;
      trap_val     = dmem_addr_o;
      trap_pc      = ex_mem_pc;
    end else if (pmp_fetch_fault) begin
      trap_enter   = 1'b1;
      is_interrupt = 1'b0;
      trap_cause   = CAUSE_FETCH_ACCESS_FAULT;
      trap_val     = imem_addr_o;
      trap_pc      = if_id_pc;
    end
  end

  // --------------------------------------------------------------------------
  // 1. IF Stage Instantiation
  // --------------------------------------------------------------------------
  moon_if_stage u_if_stage (
    .clk_i           (clk_i),
    .rst_ni          (rst_ni),
    .stall_if_i      (stall_if),
    .stall_id_i      (stall_id),
    .flush_id_i      (flush_id),
    .branch_taken_i  (branch_taken),
    .branch_target_i (branch_target),
    .trap_enter_i    (trap_enter),
    .trap_vector_i   (trap_vector),
    .mret_i          (ex_mem_is_mret),
    .mepc_i          (mepc),
    .sret_i          (ex_mem_is_sret),
    .sepc_i          (sepc),
    .imem_req_o      (imem_req_o),
    .imem_addr_o     (imem_vaddr),
    .imem_valid_i    (imem_valid_i && mmu_fetch_hit),
    .imem_rdata_i    (imem_rdata_i),
    .if_id_pc_o      (if_id_pc),
    .if_id_instr_o   (if_id_instr),
    .if_id_is_c_o    (if_id_is_c),
    .if_id_valid_o   (if_id_valid)
  );

  // --------------------------------------------------------------------------
  // 2. ID Stage Instantiation
  // --------------------------------------------------------------------------
  moon_id_stage u_id_stage (
    .clk_i                (clk_i),
    .rst_ni               (rst_ni),
    .stall_ex_i           (stall_ex),
    .flush_ex_i           (flush_ex),
    .if_id_pc_i           (if_id_pc),
    .if_id_instr_i        (if_id_instr),
    .if_id_is_c_i         (if_id_is_c),
    .if_id_valid_i        (if_id_valid),
    .wb_regwrite_i        (wb_regwrite),
    .wb_rd_i              (wb_rd),
    .wb_wdata_i           (wb_wdata),
    .wb_fp_we_i           (mem_wb_fp_we),
    .wb_fp_rd_i           (mem_wb_fp_rd),
    .wb_fp_wdata_i        (wb_fp_wdata),
    .id_rs1_o             (id_rs1),
    .id_rs2_o             (id_rs2),
    .id_fp_rs1_o          (id_fp_rs1),
    .id_fp_rs1_en_o       (id_fp_rs1_en),
    .id_fp_rs2_o          (id_fp_rs2),
    .id_fp_rs2_en_o       (id_fp_rs2_en),
    .id_ex_valid_o        (id_ex_valid),
    .id_ex_pc_o           (id_ex_pc),
    .id_ex_instr_o        (id_ex_instr),
    .id_ex_is_c_o         (id_ex_is_c),
    .id_ex_rd_o           (id_ex_rd),
    .id_ex_rs1_o          (id_ex_rs1),
    .id_ex_rs2_o          (id_ex_rs2),
    .id_ex_rs1_data_o     (id_ex_rs1_data),
    .id_ex_rs2_data_o     (id_ex_rs2_data),
    .id_ex_imm_o          (id_ex_imm),
    .id_ex_alu_op_o       (id_ex_alu_op),
    .id_ex_alu_src_a_pc_o (id_ex_alu_src_a_pc),
    .id_ex_alu_src_b_imm_o(id_ex_alu_src_b_imm),
    .id_ex_muldiv_op_o    (id_ex_muldiv_op),
    .id_ex_is_mul_o       (id_ex_is_mul),
    .id_ex_is_div_o       (id_ex_is_div),
    .id_ex_amo_op_o       (id_ex_amo_op),
    .id_ex_is_amo_o       (id_ex_is_amo),
    .id_ex_is_lr_o        (id_ex_is_lr),
    .id_ex_is_sc_o        (id_ex_is_sc),
    .id_ex_is_branch_o    (id_ex_is_branch),
    .id_ex_branch_type_o  (id_ex_branch_type),
    .id_ex_is_jal_o       (id_ex_is_jal),
    .id_ex_is_jalr_o      (id_ex_is_jalr),
    .id_ex_is_load_o      (id_ex_is_load),
    .id_ex_is_store_o     (id_ex_is_store),
    .id_ex_mem_width_o    (id_ex_mem_width),
    .id_ex_regwrite_o     (id_ex_regwrite),
    .id_ex_fp_we_o        (id_ex_fp_we),
    .id_ex_fp_rd_o        (id_ex_fp_rd),
    .id_ex_fp_word_o      (id_ex_fp_word),
    .id_ex_fp_add_o       (id_ex_fp_add),
    .id_ex_fp_sub_o       (id_ex_fp_sub),
    .id_ex_fp_mul_o       (id_ex_fp_mul),
    .id_ex_fp_rm_o        (id_ex_fp_rm),
    .id_ex_is_csr_o       (id_ex_is_csr),
    .id_ex_csr_op_o       (id_ex_csr_op),
    .id_ex_csr_addr_o     (id_ex_csr_addr),
    .id_ex_is_mret_o      (id_ex_is_mret),
    .id_ex_is_sret_o      (id_ex_is_sret),
    .id_ex_is_ecall_o     (id_ex_is_ecall),
    .id_ex_is_ebreak_o    (id_ex_is_ebreak),
    .id_ex_is_wfi_o       (id_ex_is_wfi),
    .id_ex_is_sfence_o    (id_ex_is_sfence),
    .wfi_o                ()
  );

  // --------------------------------------------------------------------------
  // 3. EX Stage Instantiation
  // --------------------------------------------------------------------------
  moon_ex_stage u_ex_stage (
    .clk_i                (clk_i),
    .rst_ni               (rst_ni),
    .stall_mem_i          (stall_mem),
    .flush_mem_i          (flush_mem),
    .id_ex_valid_i        (id_ex_valid),
    .id_ex_pc_i           (id_ex_pc),
    .id_ex_instr_i        (id_ex_instr),
    .id_ex_rd_i           (id_ex_rd),
    .id_ex_rs1_i          (id_ex_rs1),
    .id_ex_rs2_i          (id_ex_rs2),
    .id_ex_rs1_data_i     (id_ex_rs1_data),
    .id_ex_rs2_data_i     (id_ex_rs2_data),
    .id_ex_imm_i          (id_ex_imm),
    .id_ex_alu_op_i       (id_ex_alu_op),
    .id_ex_alu_src_a_pc_i (id_ex_alu_src_a_pc),
    .id_ex_alu_src_b_imm_i(id_ex_alu_src_b_imm),
    .id_ex_muldiv_op_i    (id_ex_muldiv_op),
    .id_ex_is_mul_i       (id_ex_is_mul),
    .id_ex_is_div_i       (id_ex_is_div),
    .id_ex_amo_op_i       (id_ex_amo_op),
    .id_ex_is_amo_i       (id_ex_is_amo),
    .id_ex_is_lr_i        (id_ex_is_lr),
    .id_ex_is_sc_i        (id_ex_is_sc),
    .id_ex_is_branch_i    (id_ex_is_branch),
    .id_ex_branch_type_i  (id_ex_branch_type),
    .id_ex_is_jal_i       (id_ex_is_jal),
    .id_ex_is_jalr_i      (id_ex_is_jalr),
    .id_ex_is_c_i         (id_ex_is_c),
    .id_ex_is_load_i      (id_ex_is_load),
    .id_ex_is_store_i     (id_ex_is_store),
    .id_ex_mem_width_i    (id_ex_mem_width),
    .id_ex_regwrite_i     (id_ex_regwrite),
    .id_ex_fp_we_i        (id_ex_fp_we),
    .id_ex_fp_rd_i        (id_ex_fp_rd),
    .id_ex_fp_word_i      (id_ex_fp_word),
    .id_ex_fp_add_i       (id_ex_fp_add),
    .id_ex_fp_sub_i       (id_ex_fp_sub),
    .id_ex_fp_mul_i       (id_ex_fp_mul),
    .id_ex_fp_rm_i        (id_ex_fp_rm),
    .frm_i                (frm),
    .id_ex_is_csr_i       (id_ex_is_csr),
    .id_ex_csr_op_i       (id_ex_csr_op),
    .id_ex_csr_addr_i     (id_ex_csr_addr),
    .id_ex_is_mret_i      (id_ex_is_mret),
    .id_ex_is_sret_i      (id_ex_is_sret),
    .id_ex_is_ecall_i     (id_ex_is_ecall),
    .id_ex_is_ebreak_i    (id_ex_is_ebreak),
    .id_ex_is_wfi_i       (id_ex_is_wfi),
    .id_ex_is_sfence_i    (id_ex_is_sfence),
    .fwd_a_i              (fwd_a),
    .fwd_b_i              (fwd_b),
    .fwd_ex_data_i        (ex_fwd_val),
    .fwd_mem_data_i       (wb_wdata),
    .branch_taken_o       (branch_taken),
    .branch_target_o      (branch_target),
    .busy_div_o           (busy_div),
    .ex_mem_valid_o       (ex_mem_valid),
    .ex_mem_pc_o          (ex_mem_pc),
    .ex_mem_link_pc_o     (ex_mem_link_pc),
    .ex_mem_instr_o       (ex_mem_instr),
    .ex_mem_rd_o          (ex_mem_rd),
    .ex_mem_rs2_o         (ex_mem_rs2),
    .ex_mem_alu_res_o     (ex_mem_alu_res),
    .ex_mem_mul_res_o     (ex_mem_mul_res),
    .ex_mem_div_res_o     (ex_mem_div_res),
    .ex_mem_is_mul_o      (ex_mem_is_mul),
    .ex_mem_is_div_o      (ex_mem_is_div),
    .ex_mem_rs2_data_o    (ex_mem_rs2_data),
    .ex_mem_is_load_o     (ex_mem_is_load),
    .ex_mem_is_store_o    (ex_mem_is_store),
    .ex_mem_mem_width_o   (ex_mem_mem_width),
    .ex_mem_is_amo_o      (ex_mem_is_amo),
    .ex_mem_amo_op_o      (ex_mem_amo_op),
    .ex_mem_is_lr_o       (ex_mem_is_lr),
    .ex_mem_is_sc_o       (ex_mem_is_sc),
    .ex_mem_is_jal_o      (ex_mem_is_jal),
    .ex_mem_is_jalr_o     (ex_mem_is_jalr),
    .ex_mem_regwrite_o    (ex_mem_regwrite),
    .ex_mem_fp_we_o       (ex_mem_fp_we),
    .ex_mem_fp_rd_o       (ex_mem_fp_rd),
    .ex_mem_fp_word_o     (ex_mem_fp_word),
    .ex_mem_fp_flags_o    (ex_mem_fp_flags),
    .ex_mem_fp_flags_we_o (ex_mem_fp_flags_we),
    .ex_mem_is_csr_o      (ex_mem_is_csr),
    .ex_mem_csr_op_o      (ex_mem_csr_op),
    .ex_mem_csr_addr_o    (ex_mem_csr_addr),
    .ex_mem_csr_wdata_o   (ex_mem_csr_wdata),
    .ex_mem_is_mret_o     (ex_mem_is_mret),
    .ex_mem_is_sret_o     (ex_mem_is_sret),
    .ex_mem_is_ecall_o    (ex_mem_is_ecall),
    .ex_mem_is_ebreak_o   (ex_mem_is_ebreak),
    .ex_mem_is_wfi_o      (ex_mem_is_wfi),
    .ex_mem_is_sfence_o   (ex_mem_is_sfence)
  );

  // --------------------------------------------------------------------------
  // 4. MEM Stage Instantiation
  // --------------------------------------------------------------------------
  moon_mem_stage u_mem_stage (
    .clk_i               (clk_i),
    .rst_ni              (rst_ni),
    .stall_mem_i         (stall_mem),
    .ex_mem_valid_i      (ex_mem_valid),
    .ex_mem_pc_i         (ex_mem_pc),
    .ex_mem_link_pc_i    (ex_mem_link_pc),
    .ex_mem_instr_i      (ex_mem_instr),
    .ex_mem_rd_i         (ex_mem_rd),
    .ex_mem_rs2_i        (ex_mem_rs2),
    .ex_mem_alu_res_i    (ex_mem_alu_res),
    .ex_mem_mul_res_i    (ex_mem_mul_res),
    .ex_mem_div_res_i    (ex_mem_div_res),
    .ex_mem_is_mul_i     (ex_mem_is_mul),
    .ex_mem_is_div_i     (ex_mem_is_div),
    .ex_mem_rs2_data_i   (ex_mem_rs2_data),
    .ex_mem_is_load_i    (ex_mem_is_load),
    .ex_mem_is_store_i   (ex_mem_is_store),
    .ex_mem_mem_width_i  (ex_mem_mem_width),
    .ex_mem_is_amo_i     (ex_mem_is_amo),
    .ex_mem_amo_op_i     (ex_mem_amo_op),
    .ex_mem_is_lr_i      (ex_mem_is_lr),
    .ex_mem_is_sc_i      (ex_mem_is_sc),
    .ex_mem_is_jal_i     (ex_mem_is_jal),
    .ex_mem_is_jalr_i    (ex_mem_is_jalr),
    .ex_mem_regwrite_i   (ex_mem_regwrite),
    .ex_mem_fp_we_i      (ex_mem_fp_we),
    .ex_mem_fp_rd_i      (ex_mem_fp_rd),
    .ex_mem_fp_word_i    (ex_mem_fp_word),
    .ex_mem_fp_flags_i   (ex_mem_fp_flags),
    .ex_mem_fp_flags_we_i(ex_mem_fp_flags_we),
    .ex_mem_is_csr_i     (ex_mem_is_csr),
    .ex_mem_csr_op_i     (ex_mem_csr_op),
    .ex_mem_csr_addr_i   (ex_mem_csr_addr),
    .ex_mem_csr_wdata_i  (ex_mem_csr_wdata),
    .ex_mem_is_mret_i    (ex_mem_is_mret),
    .ex_mem_is_ecall_i   (ex_mem_is_ecall),
    .ex_mem_is_ebreak_i  (ex_mem_is_ebreak),
    .dmem_req_o          (core_dmem_req),
    .dmem_we_o           (core_dmem_we),
    .dmem_addr_o         (dmem_vaddr),
    .dmem_wdata_o        (core_dmem_wdata),
    .dmem_wstrb_o        (core_dmem_wstrb),
    .dmem_valid_i        (dmem_valid_i && mmu_data_hit && !mmu_busy),
    .dmem_rdata_i        (dmem_rdata_i),
    .inv_valid_i         (inv_valid_i),
    .inv_addr_i          (inv_addr_i),
    .mem_wb_valid_o      (mem_wb_valid),
    .mem_wb_pc_o         (mem_wb_pc),
    .mem_wb_rd_o         (mem_wb_rd),
    .mem_wb_alu_res_o    (mem_wb_alu_res),
    .mem_wb_mul_res_o    (mem_wb_mul_res),
    .mem_wb_div_res_o    (mem_wb_div_res),
    .mem_wb_is_mul_o     (mem_wb_is_mul),
    .mem_wb_is_div_o     (mem_wb_is_div),
    .mem_wb_mem_data_o   (mem_wb_mem_data),
    .mem_wb_link_pc_o    (mem_wb_link_pc),
    .mem_wb_is_load_o    (mem_wb_is_load),
    .mem_wb_is_jal_o     (mem_wb_is_jal),
    .mem_wb_is_jalr_o    (mem_wb_is_jalr),
    .mem_wb_regwrite_o   (mem_wb_regwrite),
    .mem_wb_fp_we_o      (mem_wb_fp_we),
    .mem_wb_fp_rd_o      (mem_wb_fp_rd),
    .mem_wb_fp_word_o    (mem_wb_fp_word),
    .mem_wb_fp_flags_o   (mem_wb_fp_flags),
    .mem_wb_fp_flags_we_o(mem_wb_fp_flags_we),
    .mem_wb_is_csr_o     (mem_wb_is_csr),
    .mem_wb_csr_op_o     (mem_wb_csr_op),
    .mem_wb_csr_addr_o   (mem_wb_csr_addr),
    .mem_wb_csr_wdata_o  (mem_wb_csr_wdata),
    .mem_wb_is_mret_o    (mem_wb_is_mret),
    .mem_wb_is_ecall_o   (mem_wb_is_ecall),
    .mem_wb_is_ebreak_o  (mem_wb_is_ebreak),
    .mem_wb_sc_success_o (mem_wb_sc_success),
    .mem_wb_is_sc_o      (mem_wb_is_sc),
    .sc_success_o        (mem_sc_success),
    .aligned_load_data_o (mem_aligned_load_data)
  );

  // --------------------------------------------------------------------------
  // 5. WB Stage Instantiation
  // --------------------------------------------------------------------------
  moon_wb_stage u_wb_stage (
    .mem_wb_valid_i      (mem_wb_valid),
    .mem_wb_rd_i         (mem_wb_rd),
    .mem_wb_alu_res_i    (mem_wb_alu_res),
    .mem_wb_mul_res_i    (mem_wb_mul_res),
    .mem_wb_div_res_i    (mem_wb_div_res),
    .mem_wb_is_mul_i     (mem_wb_is_mul),
    .mem_wb_is_div_i     (mem_wb_is_div),
    .mem_wb_mem_data_i   (mem_wb_mem_data),
    .mem_wb_link_pc_i    (mem_wb_link_pc),
    .mem_wb_is_load_i    (mem_wb_is_load),
    .mem_wb_is_jal_i     (mem_wb_is_jal),
    .mem_wb_is_jalr_i    (mem_wb_is_jalr),
    .mem_wb_regwrite_i   (mem_wb_regwrite),
    .mem_wb_is_sc_i      (mem_wb_is_sc),
    .mem_wb_sc_success_i (mem_wb_sc_success),
    .mem_wb_is_csr_i     (mem_wb_is_csr),
    .csr_rdata_i         (csr_rdata),
    .wb_regwrite_o       (wb_regwrite),
    .wb_rd_o             (wb_rd),
    .wb_wdata_o          (wb_wdata)
  );

  // --------------------------------------------------------------------------
  // 6. Hazard and Forwarding Unit Instantiation
  // --------------------------------------------------------------------------
  moon_hazard_unit u_hazard_unit (
    .if_id_rs1_i        (id_rs1),
    .if_id_rs2_i        (id_rs2),
    .id_ex_rs1_i        (id_ex_rs1),
    .id_ex_rs2_i        (id_ex_rs2),
    .id_ex_rd_i         (id_ex_rd),
    .ex_mem_rd_i        (ex_mem_rd),
    .mem_wb_rd_i        (mem_wb_rd),
    .if_id_fp_rs1_en_i  (id_fp_rs1_en),
    .if_id_fp_rs1_i     (id_fp_rs1),
    .if_id_fp_rs2_en_i  (id_fp_rs2_en),
    .if_id_fp_rs2_i     (id_fp_rs2),
    .id_ex_fp_we_i      (id_ex_fp_we),
    .id_ex_fp_rd_i      (id_ex_fp_rd),
    .ex_mem_fp_we_i     (ex_mem_fp_we),
    .ex_mem_fp_rd_i     (ex_mem_fp_rd),
    .id_ex_is_load_i    (id_ex_is_load),
    .id_ex_is_csr_i     (id_ex_is_csr),
    .ex_mem_is_csr_i    (ex_mem_is_csr),
    .ex_mem_regwrite_i  (ex_mem_regwrite),
    .mem_wb_regwrite_i  (mem_wb_regwrite),
    .branch_taken_i     (branch_taken),
    .trap_flush_i       (trap_enter || ex_mem_is_mret || ex_mem_is_sret),
    .busy_div_i         (busy_div),
    .busy_mem_i         ((imem_req_o && !imem_valid_i) || (dmem_req_o && !dmem_valid_i)),
    .busy_mmu_i         (mmu_busy || (!mmu_fetch_hit && imem_req_o) || (!mmu_data_hit && core_dmem_req)),
    .fwd_a_o            (fwd_a),
    .fwd_b_o            (fwd_b),
    .stall_if_o         (stall_if),
    .stall_id_o         (stall_id),
    .stall_ex_o         (stall_ex),
    .stall_mem_o        (stall_mem),
    .flush_id_o         (flush_id),
    .flush_ex_o         (flush_ex),
    .flush_mem_o        (flush_mem)
  );

  logic [2:0] frm;

  // --------------------------------------------------------------------------
  // 7. CSR Unit Instantiation
  // --------------------------------------------------------------------------
  moon_csr #(
    .HART_ID (HART_ID)
  ) u_csr (
    .clk_i               (clk_i),
    .rst_ni              (rst_ni),
    .csr_we_i            (mem_wb_is_csr),
    .csr_addr_i          (mem_wb_csr_addr),
    .csr_op_i            (mem_wb_csr_op),
    .csr_wdata_i         (mem_wb_csr_wdata),
    .csr_rdata_o         (csr_rdata),
    .instret_i           (mem_wb_valid),
    .timer_irq_i         (timer_irq_i),
    .software_irq_i      (software_irq_i),
    .external_irq_i      (external_irq_i),
    .trap_enter_i        (trap_enter),
    .is_interrupt_i      (is_interrupt),
    .trap_cause_i        (trap_cause),
    .trap_pc_i           (trap_pc),
    .trap_val_i          (trap_val),
    .mret_i              (ex_mem_is_mret),
    .sret_i              (ex_mem_is_sret),
    .trap_vector_o       (trap_vector),
    .mepc_o              (mepc),
    .sepc_o              (sepc),
    .priv_lvl_o          (priv_lvl),
    .satp_o              (satp),
    .sum_o               (sum),
    .mxr_o               (mxr),
    .pmpcfg_o            (pmpcfg),
    .pmpaddr_o           (pmpaddr),
    .interrupt_pending_o (interrupt_pending),
    .interrupt_cause_o   (interrupt_cause),
    .fpu_flags_i         (mem_wb_fp_flags),
    .fpu_flags_we_i      (mem_wb_fp_flags_we),
    .frm_o               (frm)
  );

  // --------------------------------------------------------------------------
  // 8. Physical Memory Protection (PMP) Unit
  // --------------------------------------------------------------------------
  moon_pmp #(
    .NUM_ENTRIES (16)
  ) u_pmp (
    .priv_lvl_i    (priv_lvl),
    .pmpcfg_i      (pmpcfg),
    .pmpaddr_i     (pmpaddr),
    .fetch_addr_i  (imem_addr_o),
    .fetch_req_i   (imem_req_o),
    .fetch_fault_o (pmp_fetch_fault),
    .data_addr_i   (dmem_addr_o),
    .data_req_i    (dmem_req_o),
    .data_we_i     (dmem_we_o),
    .load_fault_o  (pmp_load_fault),
    .store_fault_o (pmp_store_fault)
  );

  // --------------------------------------------------------------------------
  // 9. Memory Management Unit (Sv39 MMU, ITLB, DTLB, PTW)
  // --------------------------------------------------------------------------
  moon_mmu #(
    .TLB_ENTRIES (16)
  ) u_mmu (
    .clk_i               (clk_i),
    .rst_ni              (rst_ni),
    .priv_lvl_i          (priv_lvl),
    .satp_i              (satp),
    .sum_i               (sum),
    .mxr_i               (mxr),
    .sfence_vma_i        (ex_mem_is_sfence),
    .sfence_vaddr_i      (ex_mem_alu_res),
    .sfence_asid_i       (ex_mem_rs2_data[15:0]),
    .fetch_req_i         (imem_req_o),
    .fetch_vaddr_i       (imem_vaddr),
    .fetch_hit_o         (mmu_fetch_hit),
    .fetch_paddr_o       (mmu_fetch_paddr),
    .fetch_page_fault_o  (mmu_fetch_page_fault),
    .data_req_i          (core_dmem_req),
    .data_we_i           (core_dmem_we),
    .data_vaddr_i        (dmem_vaddr),
    .data_hit_o          (mmu_data_hit),
    .data_paddr_o        (mmu_data_paddr),
    .load_page_fault_o   (mmu_load_page_fault),
    .store_page_fault_o  (mmu_store_page_fault),
    .mmu_busy_o          (mmu_busy),
    .ptw_mem_req_o       (ptw_mem_req),
    .ptw_mem_addr_o      (ptw_mem_addr),
    .ptw_mem_valid_i     (ptw_mem_valid),
    .ptw_mem_rdata_i     (ptw_mem_rdata)
  );

  // Memory Bus Multiplexing (PTW vs Core)
  assign dmem_req_o   = mmu_busy ? ptw_mem_req   : (core_dmem_req && mmu_data_hit);
  assign dmem_we_o    = mmu_busy ? 1'b0          : core_dmem_we;
  assign dmem_addr_o  = mmu_busy ? ptw_mem_addr  : mmu_data_paddr;
  assign dmem_wdata_o = mmu_busy ? '0            : core_dmem_wdata;
  assign dmem_wstrb_o = mmu_busy ? 8'hFF         : core_dmem_wstrb;

  assign ptw_mem_valid = mmu_busy && dmem_valid_i;
  assign ptw_mem_rdata = dmem_rdata_i;

  assign imem_addr_o  = mmu_fetch_paddr;

  assign interrupt_pending_o = interrupt_pending;
  assign wfi_o = (ex_mem_valid && ex_mem_is_wfi) || (id_ex_valid && id_ex_is_wfi) || (if_id_valid && if_id_instr == 32'h1050_0073);

endmodule : moon_core

`endif // MOON_CORE_SV
