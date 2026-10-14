// ============================================================================
// File: rtl/core/mmu/moon_mmu.sv
// Description: Top-level Memory Management Unit (MMU) for Moon-SoC, integrating
//              Instruction TLB (ITLB), Data TLB (DTLB), and Hardware Page
//              Table Walker (PTW) for RISC-V Sv39 Virtual Memory Translation.
// ============================================================================

`ifndef MOON_MMU_SV
`define MOON_MMU_SV

`include "moon_pkg.sv"
`include "mmu/moon_itlb.sv"
`include "mmu/moon_dtlb.sv"
`include "mmu/moon_ptw.sv"

module moon_mmu
  import moon_pkg::*;
#(
  parameter int TLB_ENTRIES = 16
)(
  input  logic             clk_i,
  input  logic             rst_ni,

  // Translation configuration from CSR unit
  input  priv_lvl_e        priv_lvl_i,
  input  logic [XLEN-1:0]  satp_i,
  input  logic             sum_i, // sstatus.SUM
  input  logic             mxr_i, // sstatus.MXR

  // TLB Invalidation (SFENCE.VMA)
  input  logic             sfence_vma_i,
  input  logic [XLEN-1:0]  sfence_vaddr_i,
  input  logic [15:0]      sfence_asid_i,

  // Instruction Fetch Translation Interface (IF stage)
  input  logic             fetch_req_i,
  input  logic [XLEN-1:0]  fetch_vaddr_i,
  output logic             fetch_hit_o,
  output logic [XLEN-1:0]  fetch_paddr_o,
  output logic             fetch_page_fault_o,

  // Data Memory Translation Interface (MEM stage)
  input  logic             data_req_i,
  input  logic             data_we_i, // 1 = Store / AMO, 0 = Load
  input  logic [XLEN-1:0]  data_vaddr_i,
  output logic             data_hit_o,
  output logic [XLEN-1:0]  data_paddr_o,
  output logic             load_page_fault_o,
  output logic             store_page_fault_o,

  // PTW Status to Hazard Unit
  output logic             mmu_busy_o,

  // Memory interface for PTW page walks (to L1-D / bus fabric)
  output logic             ptw_mem_req_o,
  output logic [XLEN-1:0]  ptw_mem_addr_o,
  input  logic             ptw_mem_valid_i,
  input  logic [XLEN-1:0]  ptw_mem_rdata_i
);

  // Translation is enabled in S-mode and U-mode when satp.MODE == 8 (Sv39)
  wire translation_en = (priv_lvl_i < PRV_M) && (satp_i[63:60] == 4'd8);
  wire [15:0] curr_asid = satp_i[59:44];

  // Interconnect signals between PTW and TLBs
  logic        itlb_refill_valid;
  logic [26:0] itlb_refill_vpn;
  logic [15:0] itlb_refill_asid;
  logic [43:0] itlb_refill_ppn;
  logic [1:0]  itlb_refill_page_size;
  logic        itlb_refill_u, itlb_refill_x, itlb_refill_g;
  logic        itlb_ptw_page_fault;

  logic        dtlb_refill_valid;
  logic [26:0] dtlb_refill_vpn;
  logic [15:0] dtlb_refill_asid;
  logic [43:0] dtlb_refill_ppn;
  logic [1:0]  dtlb_refill_page_size;
  logic        dtlb_refill_r, dtlb_refill_w, dtlb_refill_x, dtlb_refill_u;
  logic        dtlb_refill_d, dtlb_refill_a, dtlb_refill_g;
  logic        dtlb_ptw_page_fault;

  logic itlb_hit, dtlb_hit;
  logic itlb_page_fault, dtlb_load_fault, dtlb_store_fault;

  // --------------------------------------------------------------------------
  // Instruction TLB
  // --------------------------------------------------------------------------
  moon_itlb #(
    .NUM_ENTRIES (TLB_ENTRIES)
  ) u_itlb (
    .clk_i               (clk_i),
    .rst_ni              (rst_ni),
    .translation_en_i    (translation_en),
    .priv_lvl_i          (priv_lvl_i),
    .asid_i              (curr_asid),
    .flush_i             (sfence_vma_i),
    .flush_all_i         (sfence_asid_i == 16'd0 && sfence_vaddr_i == '0),
    .flush_asid_i        (sfence_asid_i),
    .flush_vaddr_i       (sfence_vaddr_i),
    .req_i               (fetch_req_i),
    .vaddr_i             (fetch_vaddr_i),
    .hit_o               (itlb_hit),
    .paddr_o             (fetch_paddr_o),
    .page_fault_o        (itlb_page_fault),
    .refill_valid_i      (itlb_refill_valid),
    .refill_vpn_i        (itlb_refill_vpn),
    .refill_asid_i       (itlb_refill_asid),
    .refill_ppn_i        (itlb_refill_ppn),
    .refill_page_size_i  (itlb_refill_page_size),
    .refill_u_i          (itlb_refill_u),
    .refill_x_i          (itlb_refill_x),
    .refill_g_i          (itlb_refill_g)
  );

  assign fetch_hit_o        = itlb_hit;
  assign fetch_page_fault_o = itlb_page_fault || itlb_ptw_page_fault;

  // --------------------------------------------------------------------------
  // Data TLB
  // --------------------------------------------------------------------------
  moon_dtlb #(
    .NUM_ENTRIES (TLB_ENTRIES)
  ) u_dtlb (
    .clk_i               (clk_i),
    .rst_ni              (rst_ni),
    .translation_en_i    (translation_en),
    .priv_lvl_i          (priv_lvl_i),
    .asid_i              (curr_asid),
    .sum_i               (sum_i),
    .mxr_i               (mxr_i),
    .flush_i             (sfence_vma_i),
    .flush_all_i         (sfence_asid_i == 16'd0 && sfence_vaddr_i == '0),
    .flush_asid_i        (sfence_asid_i),
    .flush_vaddr_i       (sfence_vaddr_i),
    .req_i               (data_req_i),
    .is_store_i          (data_we_i),
    .vaddr_i             (data_vaddr_i),
    .hit_o               (dtlb_hit),
    .paddr_o             (data_paddr_o),
    .load_page_fault_o   (dtlb_load_fault),
    .store_page_fault_o  (dtlb_store_fault),
    .refill_valid_i      (dtlb_refill_valid),
    .refill_vpn_i        (dtlb_refill_vpn),
    .refill_asid_i       (dtlb_refill_asid),
    .refill_ppn_i        (dtlb_refill_ppn),
    .refill_page_size_i  (dtlb_refill_page_size),
    .refill_r_i          (dtlb_refill_r),
    .refill_w_i          (dtlb_refill_w),
    .refill_x_i          (dtlb_refill_x),
    .refill_u_i          (dtlb_refill_u),
    .refill_d_i          (dtlb_refill_d),
    .refill_a_i          (dtlb_refill_a),
    .refill_g_i          (dtlb_refill_g)
  );

  assign data_hit_o         = dtlb_hit;
  assign load_page_fault_o  = dtlb_load_fault || (!data_we_i && dtlb_ptw_page_fault);
  assign store_page_fault_o = dtlb_store_fault || (data_we_i && dtlb_ptw_page_fault);

  // --------------------------------------------------------------------------
  // Hardware Page Table Walker (PTW)
  // --------------------------------------------------------------------------
  wire itlb_ptw_req = translation_en && fetch_req_i && !itlb_hit && !itlb_page_fault;
  wire dtlb_ptw_req = translation_en && data_req_i && !dtlb_hit && !dtlb_load_fault && !dtlb_store_fault;

  moon_ptw u_ptw (
    .clk_i                   (clk_i),
    .rst_ni                  (rst_ni),
    .satp_i                  (satp_i),
    .priv_lvl_i              (priv_lvl_i),

    // ITLB Request & Refill
    .itlb_req_i              (itlb_ptw_req),
    .itlb_vaddr_i            (fetch_vaddr_i),
    .itlb_refill_valid_o     (itlb_refill_valid),
    .itlb_refill_vpn_o       (itlb_refill_vpn),
    .itlb_refill_asid_o      (itlb_refill_asid),
    .itlb_refill_ppn_o       (itlb_refill_ppn),
    .itlb_refill_page_size_o (itlb_refill_page_size),
    .itlb_refill_u_o         (itlb_refill_u),
    .itlb_refill_x_o         (itlb_refill_x),
    .itlb_refill_g_o         (itlb_refill_g),
    .itlb_page_fault_o       (itlb_ptw_page_fault),

    // DTLB Request & Refill
    .dtlb_req_i              (dtlb_ptw_req),
    .dtlb_is_store_i         (data_we_i),
    .dtlb_vaddr_i            (data_vaddr_i),
    .dtlb_refill_valid_o     (dtlb_refill_valid),
    .dtlb_refill_vpn_o       (dtlb_refill_vpn),
    .dtlb_refill_asid_o      (dtlb_refill_asid),
    .dtlb_refill_ppn_o       (dtlb_refill_ppn),
    .dtlb_refill_page_size_o (dtlb_refill_page_size),
    .dtlb_refill_r_o         (dtlb_refill_r),
    .dtlb_refill_w_o         (dtlb_refill_w),
    .dtlb_refill_x_o         (dtlb_refill_x),
    .dtlb_refill_u_o         (dtlb_refill_u),
    .dtlb_refill_d_o         (dtlb_refill_d),
    .dtlb_refill_a_o         (dtlb_refill_a),
    .dtlb_refill_g_o         (dtlb_refill_g),
    .dtlb_page_fault_o       (dtlb_ptw_page_fault),

    .ptw_busy_o              (mmu_busy_o),

    // Memory Channel
    .mem_req_o               (ptw_mem_req_o),
    .mem_addr_o              (ptw_mem_addr_o),
    .mem_valid_i             (ptw_mem_valid_i),
    .mem_rdata_i             (ptw_mem_rdata_i)
  );

endmodule : moon_mmu

`endif // MOON_MMU_SV
