// ============================================================================
// File: rtl/core/mmu/moon_itlb.sv
// Description: Fully-associative Instruction Translation Lookaside Buffer (ITLB)
//              for Sv39 virtual memory translation in Moon-SoC IF stage.
// ============================================================================

`ifndef MOON_ITLB_SV
`define MOON_ITLB_SV

`include "moon_pkg.sv"

module moon_itlb
  import moon_pkg::*;
#(
  parameter int NUM_ENTRIES = 16
)(
  input  logic             clk_i,
  input  logic             rst_ni,

  // Translation Activation & Privilege
  input  logic             translation_en_i, // satp.MODE == 8 && priv_lvl < PRV_M
  input  priv_lvl_e        priv_lvl_i,
  input  logic [15:0]      asid_i,

  // TLB Flush (SFENCE.VMA)
  input  logic             flush_i,
  input  logic             flush_all_i,
  input  logic [15:0]      flush_asid_i,
  input  logic [XLEN-1:0]  flush_vaddr_i,

  // Translation Request from IF stage
  input  logic             req_i,
  input  logic [XLEN-1:0]  vaddr_i,
  output logic             hit_o,
  output logic [XLEN-1:0]  paddr_o,
  output logic             page_fault_o,

  // PTW Refill Interface
  input  logic             refill_valid_i,
  input  logic [26:0]      refill_vpn_i,
  input  logic [15:0]      refill_asid_i,
  input  logic [43:0]      refill_ppn_i,
  input  logic [1:0]       refill_page_size_i, // 0=4KB, 1=2MB, 2=1GB
  input  logic             refill_u_i,
  input  logic             refill_x_i,
  input  logic             refill_g_i
);

  typedef struct packed {
    logic        valid;
    logic [26:0] vpn;
    logic [15:0] asid;
    logic [43:0] ppn;
    logic [1:0]  page_size; // 0=4KB, 1=2MB, 2=1GB
    logic        u;         // User page
    logic        x;         // Executable
    logic        g;         // Global
  } itlb_entry_t;

  itlb_entry_t entries_q [0:NUM_ENTRIES-1];
  logic [$clog2(NUM_ENTRIES)-1:0] lru_ptr_q;

  wire [26:0] req_vpn = vaddr_i[38:12];

  // Canonical address check: bits [63:38] must be sign-extended
  wire is_canonical = (vaddr_i[63:38] == {26{vaddr_i[38]}});

  // Translation Matching
  logic [NUM_ENTRIES-1:0] match_vec;
  logic                   hit_any;
  int                     hit_idx;

  always_comb begin
    hit_any   = 1'b0;
    hit_idx   = 0;
    match_vec = '0;

    for (int i = 0; i < NUM_ENTRIES; i++) begin
      if (entries_q[i].valid) begin
        logic vpn_match;
        logic asid_match;

        asid_match = entries_q[i].g || (entries_q[i].asid == asid_i);

        case (entries_q[i].page_size)
          2'd0: vpn_match = (req_vpn == entries_q[i].vpn);                       // 4KB
          2'd1: vpn_match = (req_vpn[26:9] == entries_q[i].vpn[26:9]);          // 2MB
          2'd2: vpn_match = (req_vpn[26:18] == entries_q[i].vpn[26:18]);        // 1GB
          default: vpn_match = 1'b0;
        endcase

        if (vpn_match && asid_match) begin
          match_vec[i] = 1'b1;
          hit_any      = 1'b1;
          hit_idx      = i;
        end
      end
    end
  end

  // Physical Address Assembly & Permission Checks
  always_comb begin
    if (!req_i || !translation_en_i) begin
      // Inactive / Bare mode / M-mode: PA = VA
      hit_o        = 1'b1;
      paddr_o      = vaddr_i;
      page_fault_o = 1'b0;
    end else if (!is_canonical) begin
      // Non-canonical virtual address raises fetch page fault
      hit_o        = 1'b1;
      paddr_o      = vaddr_i;
      page_fault_o = 1'b1;
    end else if (hit_any) begin
      hit_o = 1'b1;

      // Assemble PADDR based on page size
      case (entries_q[hit_idx].page_size)
        2'd0: paddr_o = {entries_q[hit_idx].ppn, vaddr_i[11:0]};
        2'd1: paddr_o = {entries_q[hit_idx].ppn[43:9], vaddr_i[20:0]};
        2'd2: paddr_o = {entries_q[hit_idx].ppn[43:18], vaddr_i[29:0]};
        default: paddr_o = vaddr_i;
      endcase

      // Execute permission check
      // S-mode cannot execute user pages (PTE.U == 1)
      // U-mode can only execute user pages (PTE.U == 1)
      if (!entries_q[hit_idx].x) begin
        page_fault_o = 1'b1;
      end else if (priv_lvl_i == PRV_U && !entries_q[hit_idx].u) begin
        page_fault_o = 1'b1;
      end else if (priv_lvl_i == PRV_S && entries_q[hit_idx].u) begin
        page_fault_o = 1'b1;
      end else begin
        page_fault_o = 1'b0;
      end
    end else begin
      // TLB Miss: PTW walk needed
      hit_o        = 1'b0;
      paddr_o      = vaddr_i;
      page_fault_o = 1'b0;
    end
  end

  // TLB Storage Update & Invalidation Logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      lru_ptr_q <= '0;
      for (int i = 0; i < NUM_ENTRIES; i++) begin
        entries_q[i] <= '0;
      end
    end else if (flush_i) begin
      for (int i = 0; i < NUM_ENTRIES; i++) begin
        if (flush_all_i) begin
          entries_q[i].valid <= 1'b0;
        end else if (!entries_q[i].g && (entries_q[i].asid == flush_asid_i)) begin
          entries_q[i].valid <= 1'b0;
        end
      end
    end else if (refill_valid_i) begin
      // Fill entry at LRU replacement pointer
      entries_q[lru_ptr_q].valid     <= 1'b1;
      entries_q[lru_ptr_q].vpn       <= refill_vpn_i;
      entries_q[lru_ptr_q].asid      <= refill_asid_i;
      entries_q[lru_ptr_q].ppn       <= refill_ppn_i;
      entries_q[lru_ptr_q].page_size <= refill_page_size_i;
      entries_q[lru_ptr_q].u         <= refill_u_i;
      entries_q[lru_ptr_q].x         <= refill_x_i;
      entries_q[lru_ptr_q].g         <= refill_g_i;

      lru_ptr_q <= lru_ptr_q + 1'b1;
    end
  end

endmodule : moon_itlb

`endif // MOON_ITLB_SV
