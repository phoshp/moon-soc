// ============================================================================
// File: rtl/core/mmu/moon_dtlb.sv
// Description: Fully-associative Data Translation Lookaside Buffer (DTLB)
//              for Sv39 virtual memory translation in Moon-SoC MEM stage,
//              supporting SUM (Supervisor User Memory) and MXR (Make Executable Readable).
// ============================================================================

`ifndef MOON_DTLB_SV
`define MOON_DTLB_SV

`include "moon_pkg.sv"

module moon_dtlb
  import moon_pkg::*;
#(
  parameter int NUM_ENTRIES = 16
)(
  input  logic             clk_i,
  input  logic             rst_ni,

  // Translation Activation & Status
  input  logic             translation_en_i,
  input  priv_lvl_e        priv_lvl_i,
  input  logic [15:0]      asid_i,
  input  logic             sum_i, // sstatus.SUM
  input  logic             mxr_i, // sstatus.MXR

  // TLB Flush (SFENCE.VMA)
  input  logic             flush_i,
  input  logic             flush_all_i,
  input  logic [15:0]      flush_asid_i,
  input  logic [XLEN-1:0]  flush_vaddr_i,

  // Translation Request from MEM stage
  input  logic             req_i,
  input  logic             is_store_i, // 1 = Store / AMO, 0 = Load
  input  logic [XLEN-1:0]  vaddr_i,
  output logic             hit_o,
  output logic [XLEN-1:0]  paddr_o,
  output logic             load_page_fault_o,
  output logic             store_page_fault_o,

  // PTW Refill Interface
  input  logic             refill_valid_i,
  input  logic [26:0]      refill_vpn_i,
  input  logic [15:0]      refill_asid_i,
  input  logic [43:0]      refill_ppn_i,
  input  logic [1:0]       refill_page_size_i,
  input  logic             refill_r_i,
  input  logic             refill_w_i,
  input  logic             refill_x_i,
  input  logic             refill_u_i,
  input  logic             refill_d_i,
  input  logic             refill_a_i,
  input  logic             refill_g_i
);

  typedef struct packed {
    logic        valid;
    logic [26:0] vpn;
    logic [15:0] asid;
    logic [43:0] ppn;
    logic [1:0]  page_size;
    logic        r;
    logic        w;
    logic        x;
    logic        u;
    logic        d;
    logic        a;
    logic        g;
  } dtlb_entry_t;

  dtlb_entry_t entries_q [0:NUM_ENTRIES-1];
  logic [$clog2(NUM_ENTRIES)-1:0] lru_ptr_q;

  wire [26:0] req_vpn = vaddr_i[38:12];
  wire is_canonical = (vaddr_i[63:38] == {26{vaddr_i[38]}});

  // Translation Matching
  logic [NUM_ENTRIES-1:0] match_vec;
  logic                   hit_any;
  logic [$clog2(NUM_ENTRIES)-1:0] hit_idx;

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
          2'd0: vpn_match = (req_vpn == entries_q[i].vpn);
          2'd1: vpn_match = (req_vpn[26:9] == entries_q[i].vpn[26:9]);
          2'd2: vpn_match = (req_vpn[26:18] == entries_q[i].vpn[26:18]);
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
    load_page_fault_o  = 1'b0;
    store_page_fault_o = 1'b0;

    if (!req_i || !translation_en_i) begin
      // Inactive / Bare mode / M-mode: PA = VA
      hit_o   = 1'b1;
      paddr_o = vaddr_i;
    end else if (!is_canonical) begin
      hit_o   = 1'b1;
      paddr_o = vaddr_i;
      if (is_store_i) store_page_fault_o = 1'b1;
      else            load_page_fault_o  = 1'b1;
    end else if (hit_any) begin
      logic can_read, can_write;
      hit_o = 1'b1;

      case (entries_q[hit_idx].page_size)
        2'd0: paddr_o = {entries_q[hit_idx].ppn, vaddr_i[11:0]};
        2'd1: paddr_o = {entries_q[hit_idx].ppn[43:9], vaddr_i[20:0]};
        2'd2: paddr_o = {entries_q[hit_idx].ppn[43:18], vaddr_i[29:0]};
        default: paddr_o = vaddr_i;
      endcase

      // Read permission: PTE.R or (MXR && PTE.X)
      can_read  = entries_q[hit_idx].r || (mxr_i && entries_q[hit_idx].x);
      can_write = entries_q[hit_idx].w && entries_q[hit_idx].d; // Dirty bit required for write

      // Privilege check for user pages
      if (priv_lvl_i == PRV_U) begin
        if (!entries_q[hit_idx].u) begin
          can_read  = 1'b0;
          can_write = 1'b0;
        end
      end else if (priv_lvl_i == PRV_S) begin
        if (entries_q[hit_idx].u && !sum_i) begin
          // S-mode cannot access user pages unless sstatus.SUM == 1
          can_read  = 1'b0;
          can_write = 1'b0;
        end
      end

      if (is_store_i && !can_write) begin
        store_page_fault_o = 1'b1;
      end else if (!is_store_i && !can_read) begin
        load_page_fault_o  = 1'b1;
      end
    end else begin
      // TLB Miss
      hit_o   = 1'b0;
      paddr_o = vaddr_i;
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
      entries_q[lru_ptr_q].valid     <= 1'b1;
      entries_q[lru_ptr_q].vpn       <= refill_vpn_i;
      entries_q[lru_ptr_q].asid      <= refill_asid_i;
      entries_q[lru_ptr_q].ppn       <= refill_ppn_i;
      entries_q[lru_ptr_q].page_size <= refill_page_size_i;
      entries_q[lru_ptr_q].r         <= refill_r_i;
      entries_q[lru_ptr_q].w         <= refill_w_i;
      entries_q[lru_ptr_q].x         <= refill_x_i;
      entries_q[lru_ptr_q].u         <= refill_u_i;
      entries_q[lru_ptr_q].d         <= refill_d_i;
      entries_q[lru_ptr_q].a         <= refill_a_i;
      entries_q[lru_ptr_q].g         <= refill_g_i;

      lru_ptr_q <= lru_ptr_q + 1'b1;
    end
  end

endmodule : moon_dtlb

`endif // MOON_DTLB_SV
