// ============================================================================
// File: rtl/core/moon_mem_stage.sv
// Description: Memory Access (MEM) stage and MEM/WB pipeline register for
//              Moon-SoC RV64 core, instantiating AMO and LR/SC reservation unit.
// ============================================================================

`ifndef MOON_MEM_STAGE_SV
`define MOON_MEM_STAGE_SV

`include "moon_pkg.sv"
`include "moon_amo.sv"

module moon_mem_stage
  import moon_pkg::*;
(
  input  logic             clk_i,
  input  logic             rst_ni,

  // Pipeline Flow Control
  input  logic             stall_mem_i,

  // Inputs from EX Stage (EX/MEM Register)
  input  logic             ex_mem_valid_i,
  input  logic [XLEN-1:0]  ex_mem_pc_i,
  input  logic [XLEN-1:0]  ex_mem_link_pc_i,
  input  logic [ILEN-1:0]  ex_mem_instr_i,
  input  logic [4:0]       ex_mem_rd_i,
  input  logic [4:0]       ex_mem_rs2_i,
  input  logic [XLEN-1:0]  ex_mem_alu_res_i,
  input  logic [XLEN-1:0]  ex_mem_mul_res_i,
  input  logic [XLEN-1:0]  ex_mem_div_res_i,
  input  logic             ex_mem_is_mul_i,
  input  logic             ex_mem_is_div_i,
  input  logic [XLEN-1:0]  ex_mem_rs2_data_i,
  input  logic             ex_mem_is_load_i,
  input  logic             ex_mem_is_store_i,
  input  mem_width_e       ex_mem_mem_width_i,
  input  logic             ex_mem_is_amo_i,
  input  amo_op_e          ex_mem_amo_op_i,
  input  logic             ex_mem_is_lr_i,
  input  logic             ex_mem_is_sc_i,
  input  logic             ex_mem_is_jal_i,
  input  logic             ex_mem_is_jalr_i,
  input  logic             ex_mem_regwrite_i,
  input  logic             ex_mem_is_csr_i,
  input  logic [2:0]       ex_mem_csr_op_i,
  input  logic [11:0]      ex_mem_csr_addr_i,
  input  logic [XLEN-1:0]  ex_mem_csr_wdata_i,
  input  logic             ex_mem_is_mret_i,
  input  logic             ex_mem_is_ecall_i,
  input  logic             ex_mem_is_ebreak_i,

  // Data Memory Bus Interface
  output logic             dmem_req_o,
  output logic             dmem_we_o,
  output logic [XLEN-1:0]  dmem_addr_o,
  output logic [XLEN-1:0]  dmem_wdata_o,
  output logic [7:0]       dmem_wstrb_o,
  input  logic             dmem_valid_i,
  input  logic [XLEN-1:0]  dmem_rdata_i,

  // Invalidation line from external coherence bus for LR/SC
  input  logic             inv_valid_i,
  input  logic [XLEN-1:0]  inv_addr_i,

  // Outputs to WB Stage (MEM/WB Pipeline Register)
  output logic             mem_wb_valid_o,
  output logic [XLEN-1:0]  mem_wb_pc_o,
  output logic [4:0]       mem_wb_rd_o,
  output logic [XLEN-1:0]  mem_wb_alu_res_o,
  output logic [XLEN-1:0]  mem_wb_mul_res_o,
  output logic [XLEN-1:0]  mem_wb_div_res_o,
  output logic             mem_wb_is_mul_o,
  output logic             mem_wb_is_div_o,
  output logic [XLEN-1:0]  mem_wb_mem_data_o,
  output logic [XLEN-1:0]  mem_wb_link_pc_o,
  output logic             mem_wb_is_load_o,
  output logic             mem_wb_is_jal_o,
  output logic             mem_wb_is_jalr_o,
  output logic             mem_wb_regwrite_o,
  output logic             mem_wb_is_csr_o,
  output logic [2:0]       mem_wb_csr_op_o,
  output logic [11:0]      mem_wb_csr_addr_o,
  output logic [XLEN-1:0]  mem_wb_csr_wdata_o,
  output logic             mem_wb_is_mret_o,
  output logic             mem_wb_is_ecall_o,
  output logic             mem_wb_is_ebreak_o,
  output logic             mem_wb_sc_success_o,
  output logic             mem_wb_is_sc_o,

  // Combinational Stage Outputs for Forwarding
  output logic             sc_success_o,
  output logic [XLEN-1:0]  aligned_load_data_o
);

  // --------------------------------------------------------------------------
  // Memory Address and Control Formatting
  // --------------------------------------------------------------------------
  assign dmem_addr_o = ex_mem_alu_res_i;

  wire [2:0] byte_offset = ex_mem_alu_res_i[2:0];
  logic [7:0]       store_wstrb;
  logic [XLEN-1:0]  store_wdata;

  always_comb begin
    case (ex_mem_mem_width_i)
      MEM_BYTE, MEM_BYTE_U: begin
        store_wstrb = 8'b0000_0001 << byte_offset;
        store_wdata = {8{ex_mem_rs2_data_i[7:0]}};
      end
      MEM_HALF, MEM_HALF_U: begin
        store_wstrb = 8'b0000_0011 << {byte_offset[2:1], 1'b0};
        store_wdata = {4{ex_mem_rs2_data_i[15:0]}};
      end
      MEM_WORD, MEM_WORD_U: begin
        store_wstrb = 8'b0000_1111 << {byte_offset[2], 2'b0};
        store_wdata = {2{ex_mem_rs2_data_i[31:0]}};
      end
      MEM_DWORD: begin
        store_wstrb = 8'b1111_1111;
        store_wdata = ex_mem_rs2_data_i;
      end
      default: begin
        store_wstrb = 8'b0000_0000;
        store_wdata = '0;
      end
    endcase
  end

  // --------------------------------------------------------------------------
  // Load Data Alignment and Sign/Zero Extension
  // --------------------------------------------------------------------------
  logic [7:0]   loaded_byte;
  logic [15:0]  loaded_half;
  logic [31:0]  loaded_word;
  logic [XLEN-1:0] aligned_load_data;

  assign loaded_byte = dmem_rdata_i[byte_offset*8 +: 8];
  assign loaded_half = dmem_rdata_i[{byte_offset[2:1], 1'b0}*8 +: 16];
  assign loaded_word = dmem_rdata_i[{byte_offset[2], 2'b0}*8 +: 32];

  always_comb begin
    case (ex_mem_mem_width_i)
      MEM_BYTE:   aligned_load_data = {{56{loaded_byte[7]}}, loaded_byte};
      MEM_BYTE_U: aligned_load_data = {56'b0, loaded_byte};
      MEM_HALF:   aligned_load_data = {{48{loaded_half[15]}}, loaded_half};
      MEM_HALF_U: aligned_load_data = {48'b0, loaded_half};
      MEM_WORD:   aligned_load_data = {{32{loaded_word[31]}}, loaded_word};
      MEM_WORD_U: aligned_load_data = {32'b0, loaded_word};
      MEM_DWORD:  aligned_load_data = dmem_rdata_i;
      default:    aligned_load_data = dmem_rdata_i;
    endcase
  end

  assign aligned_load_data_o = aligned_load_data;

  // --------------------------------------------------------------------------
  // AMO and LR/SC Reservation Unit
  // --------------------------------------------------------------------------
  logic [XLEN-1:0] amo_res;
  logic            sc_success;
  wire is_amo_word = (ex_mem_mem_width_i == MEM_WORD) || (ex_mem_mem_width_i == MEM_WORD_U);

  moon_amo u_amo (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .stall_i      (stall_mem_i),
    .amo_op_i     (ex_mem_amo_op_i),
    .is_word_i    (is_amo_word),
    .mem_data_i   (aligned_load_data),
    .rs2_data_i   (ex_mem_rs2_data_i),
    .amo_result_o (amo_res),
    .lr_valid_i   (ex_mem_valid_i && ex_mem_is_lr_i),
    .lr_addr_i    (ex_mem_alu_res_i),
    .sc_valid_i   (ex_mem_valid_i && ex_mem_is_sc_i),
    .sc_addr_i    (ex_mem_alu_res_i),
    .inv_valid_i  (inv_valid_i),
    .inv_addr_i   (inv_addr_i),
    .sc_success_o (sc_success)
  );

  assign sc_success_o = sc_success;

  // Store enable: regular store, or successful SC, or AMO write
  wire perform_store = ex_mem_valid_i &&
                       (ex_mem_is_store_i ||
                        (ex_mem_is_sc_i && sc_success) ||
                        (ex_mem_is_amo_i && !ex_mem_is_lr_i && !ex_mem_is_sc_i));

  wire perform_load  = ex_mem_valid_i &&
                       (ex_mem_is_load_i || ex_mem_is_lr_i || (ex_mem_is_amo_i && !ex_mem_is_sc_i));

  assign dmem_req_o   = perform_store || perform_load;
  assign dmem_we_o    = perform_store;
  assign dmem_wstrb_o = store_wstrb;
  assign dmem_wdata_o = (ex_mem_is_amo_i && !ex_mem_is_lr_i && !ex_mem_is_sc_i) ? (is_amo_word ? {2{amo_res[31:0]}} : amo_res) : store_wdata;

  // --------------------------------------------------------------------------
  // MEM/WB Pipeline Register
  // --------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mem_wb_valid_o      <= 1'b0;
      mem_wb_pc_o         <= '0;
      mem_wb_rd_o         <= '0;
      mem_wb_alu_res_o    <= '0;
      mem_wb_mul_res_o    <= '0;
      mem_wb_div_res_o    <= '0;
      mem_wb_is_mul_o     <= 1'b0;
      mem_wb_is_div_o     <= 1'b0;
      mem_wb_mem_data_o   <= '0;
      mem_wb_link_pc_o    <= '0;
      mem_wb_is_load_o    <= 1'b0;
      mem_wb_is_jal_o     <= 1'b0;
      mem_wb_is_jalr_o    <= 1'b0;
      mem_wb_regwrite_o   <= 1'b0;
      mem_wb_is_csr_o     <= 1'b0;
      mem_wb_csr_op_o     <= '0;
      mem_wb_csr_addr_o   <= '0;
      mem_wb_csr_wdata_o  <= '0;
      mem_wb_is_mret_o    <= 1'b0;
      mem_wb_is_ecall_o   <= 1'b0;
      mem_wb_is_ebreak_o  <= 1'b0;
      mem_wb_sc_success_o <= 1'b0;
      mem_wb_is_sc_o      <= 1'b0;
    end else if (!stall_mem_i) begin
      mem_wb_valid_o      <= ex_mem_valid_i;
      mem_wb_pc_o         <= ex_mem_pc_i;
      mem_wb_rd_o         <= ex_mem_rd_i;
      mem_wb_alu_res_o    <= ex_mem_alu_res_i;
      mem_wb_mul_res_o    <= ex_mem_mul_res_i;
      mem_wb_div_res_o    <= ex_mem_div_res_i;
      mem_wb_is_mul_o     <= ex_mem_is_mul_i;
      mem_wb_is_div_o     <= ex_mem_is_div_i;
      mem_wb_mem_data_o   <= aligned_load_data;
      mem_wb_link_pc_o    <= ex_mem_link_pc_i;
      mem_wb_is_load_o    <= ex_mem_is_load_i || ex_mem_is_lr_i || (ex_mem_is_amo_i && !ex_mem_is_sc_i);
      mem_wb_is_jal_o     <= ex_mem_is_jal_i;
      mem_wb_is_jalr_o    <= ex_mem_is_jalr_i;
      mem_wb_regwrite_o   <= ex_mem_regwrite_i;
      mem_wb_is_csr_o     <= ex_mem_is_csr_i;
      mem_wb_csr_op_o     <= ex_mem_csr_op_i;
      mem_wb_csr_addr_o   <= ex_mem_csr_addr_i;
      mem_wb_csr_wdata_o  <= ex_mem_csr_wdata_i;
      mem_wb_is_mret_o    <= ex_mem_is_mret_i;
      mem_wb_is_ecall_o   <= ex_mem_is_ecall_i;
      mem_wb_is_ebreak_o  <= ex_mem_is_ebreak_i;
      mem_wb_sc_success_o <= sc_success;
      mem_wb_is_sc_o      <= ex_mem_is_sc_i;
    end
  end

endmodule : moon_mem_stage

`endif // MOON_MEM_STAGE_SV
