// ============================================================================
// File: rtl/core/moon_pmp.sv
// Description: Physical Memory Protection (PMP) & Smepmp unit for Moon-SoC
//              supporting 16 programmable entries with TOR, NA4, and NAPOT
//              matching, lock bits, and fetch/load/store access validation.
// ============================================================================

`ifndef MOON_PMP_SV
`define MOON_PMP_SV

`include "moon_pkg.sv"

module moon_pmp
  import moon_pkg::*;
#(
  parameter int NUM_ENTRIES = 8
)(
  input  priv_lvl_e        priv_lvl_i,

  // PMP Configuration & Address Registers
  input  logic [7:0]       pmpcfg_i [0:NUM_ENTRIES-1],
  input  logic [XLEN-1:0]  pmpaddr_i [0:NUM_ENTRIES-1],

  // Instruction Fetch Check (from IF stage)
  input  logic [XLEN-1:0]  fetch_addr_i,
  input  logic             fetch_req_i,
  output logic             fetch_fault_o,

  // Data Memory Check (from MEM stage)
  input  logic [XLEN-1:0]  data_addr_i,
  input  logic             data_req_i,
  input  logic             data_we_i, // 1 = Store/AMO, 0 = Load
  output logic             load_fault_o,
  output logic             store_fault_o
);

  function automatic logic pmp_match(
    input logic [1:0]      mode,
    input logic [XLEN-1:0] curr_pmpaddr,
    input logic [XLEN-1:0] prev_pmpaddr,
    input logic [XLEN-1:0] paddr
  );
    logic [XLEN-1:0] base_paddr;
    logic [XLEN-1:0] top_paddr;
    logic [XLEN-1:0] mask;

    case (mode)
      2'b00: return 1'b0; // OFF

      2'b01: begin // TOR (Top of Range)
        base_paddr = prev_pmpaddr << 2;
        top_paddr  = curr_pmpaddr << 2;
        return (paddr >= base_paddr) && (paddr < top_paddr);
      end

      2'b10: begin // NA4 (4-byte range)
        return (paddr[XLEN-1:2] == curr_pmpaddr[XLEN-3:0]);
      end

      2'b11: begin // NAPOT
        // Naturally aligned power-of-two mask computation:
        // Trailing ones followed by a zero in curr_pmpaddr encode the size (2^(k+3) bytes).
        // curr_pmpaddr ^ (curr_pmpaddr + 1'b1) yields ones from bit 0 up to the first zero bit k.
        // Inverting this gives a mask with 0s for bits 0..k and 1s for bits k+1..XLEN-1.
        // This eliminates the 64-iteration procedural loop, break, and dynamic barrel shifter.
        mask = ~(curr_pmpaddr ^ (curr_pmpaddr + 1'b1));
        return ((curr_pmpaddr & mask) == ((paddr >> 2) & mask));
      end

      default: return 1'b0;
    endcase
  endfunction

  // --------------------------------------------------------------------------
  // Instruction Fetch PMP Check
  // --------------------------------------------------------------------------
  int fetch_matched_entry;
  logic fetch_entry_hit;
  logic [XLEN-1:0] fetch_prev_addr;
  logic fetch_lock, fetch_x_perm;
  logic fetch_any_active;

  always_comb begin
    fetch_fault_o       = 1'b0;
    fetch_matched_entry = 0;
    fetch_entry_hit     = 1'b0;
    fetch_prev_addr     = '0;
    fetch_lock          = 1'b0;
    fetch_x_perm        = 1'b0;
    fetch_any_active    = 1'b0;

    if (fetch_req_i) begin
      for (int i = 0; i < NUM_ENTRIES; i++) begin
        fetch_prev_addr = (i == 0) ? '0 : pmpaddr_i[i-1];
        if (!fetch_entry_hit && pmp_match(pmpcfg_i[i][4:3], pmpaddr_i[i], fetch_prev_addr, fetch_addr_i)) begin
          fetch_matched_entry = i;
          fetch_entry_hit     = 1'b1;
        end
      end

      if (fetch_entry_hit) begin
        fetch_lock   = pmpcfg_i[fetch_matched_entry][7];
        fetch_x_perm = pmpcfg_i[fetch_matched_entry][2];

        if (priv_lvl_i == PRV_M) begin
          if (fetch_lock && !fetch_x_perm) fetch_fault_o = 1'b1;
        end else begin
          if (!fetch_x_perm) fetch_fault_o = 1'b1;
        end
      end else begin
        // If no entry matches: M-mode succeeds, S/U-mode fails if any PMP is configured
        if (priv_lvl_i != PRV_M) begin
          for (int i = 0; i < NUM_ENTRIES; i++) begin
            if (pmpcfg_i[i][4:3] != 2'b00) fetch_any_active = 1'b1;
          end
          if (fetch_any_active) fetch_fault_o = 1'b1;
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // Data Memory PMP Check (Loads & Stores)
  // --------------------------------------------------------------------------
  int data_matched_entry;
  logic data_entry_hit;
  logic [XLEN-1:0] data_prev_addr;
  logic data_lock, data_r_perm, data_w_perm;
  logic data_any_active;

  always_comb begin
    load_fault_o       = 1'b0;
    store_fault_o      = 1'b0;
    data_matched_entry = 0;
    data_entry_hit     = 1'b0;
    data_prev_addr     = '0;
    data_lock          = 1'b0;
    data_r_perm        = 1'b0;
    data_w_perm        = 1'b0;
    data_any_active    = 1'b0;

    if (data_req_i) begin
      for (int i = 0; i < NUM_ENTRIES; i++) begin
        data_prev_addr = (i == 0) ? '0 : pmpaddr_i[i-1];
        if (!data_entry_hit && pmp_match(pmpcfg_i[i][4:3], pmpaddr_i[i], data_prev_addr, data_addr_i)) begin
          data_matched_entry = i;
          data_entry_hit     = 1'b1;
        end
      end

      if (data_entry_hit) begin
        data_lock   = pmpcfg_i[data_matched_entry][7];
        data_r_perm = pmpcfg_i[data_matched_entry][0];
        data_w_perm = pmpcfg_i[data_matched_entry][1];

        if (priv_lvl_i == PRV_M) begin
          if (data_lock) begin
            if (data_we_i && !data_w_perm)  store_fault_o = 1'b1;
            if (!data_we_i && !data_r_perm) load_fault_o  = 1'b1;
          end
        end else begin
          if (data_we_i && !data_w_perm)  store_fault_o = 1'b1;
          if (!data_we_i && !data_r_perm) load_fault_o  = 1'b1;
        end
      end else begin
        // If no entry matches: M-mode succeeds, S/U-mode fails if any PMP is configured
        if (priv_lvl_i != PRV_M) begin
          for (int i = 0; i < NUM_ENTRIES; i++) begin
            if (pmpcfg_i[i][4:3] != 2'b00) data_any_active = 1'b1;
          end
          if (data_any_active) begin
            if (data_we_i) store_fault_o = 1'b1;
            else           load_fault_o  = 1'b1;
          end
        end
      end
    end
  end

endmodule : moon_pmp

`endif // MOON_PMP_SV
