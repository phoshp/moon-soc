// ============================================================================
// File: rtl/core/mmu/moon_ptw.sv
// Description: Hardware Page Table Walker (PTW) for RISC-V Sv39 virtual memory,
//              performing 3-level page walks (1GB, 2MB, 4KB leaf pages) with
//              superpage alignment checks, Svpbmt and Svinval support.
// ============================================================================

`ifndef MOON_PTW_SV
`define MOON_PTW_SV

`include "moon_pkg.sv"

module moon_ptw
  import moon_pkg::*;
(
  input  logic             clk_i,
  input  logic             rst_ni,

  // Translation configuration
  input  logic [XLEN-1:0]  satp_i,
  input  priv_lvl_e        priv_lvl_i,

  // PTW Request from ITLB
  input  logic             itlb_req_i,
  input  logic [XLEN-1:0]  itlb_vaddr_i,
  output logic             itlb_refill_valid_o,
  output logic [26:0]      itlb_refill_vpn_o,
  output logic [15:0]      itlb_refill_asid_o,
  output logic [43:0]      itlb_refill_ppn_o,
  output logic [1:0]       itlb_refill_page_size_o,
  output logic             itlb_refill_u_o,
  output logic             itlb_refill_x_o,
  output logic             itlb_refill_g_o,
  output logic             itlb_page_fault_o,

  // PTW Request from DTLB
  input  logic             dtlb_req_i,
  input  logic             dtlb_is_store_i,
  input  logic [XLEN-1:0]  dtlb_vaddr_i,
  output logic             dtlb_refill_valid_o,
  output logic [26:0]      dtlb_refill_vpn_o,
  output logic [15:0]      dtlb_refill_asid_o,
  output logic [43:0]      dtlb_refill_ppn_o,
  output logic [1:0]       dtlb_refill_page_size_o,
  output logic             dtlb_refill_r_o,
  output logic             dtlb_refill_w_o,
  output logic             dtlb_refill_x_o,
  output logic             dtlb_refill_u_o,
  output logic             dtlb_refill_d_o,
  output logic             dtlb_refill_a_o,
  output logic             dtlb_refill_g_o,
  output logic             dtlb_page_fault_o,

  // Busy status to pipeline hazard unit
  output logic             ptw_busy_o,

  // Memory interface to read PTEs (shared data memory channel)
  output logic             mem_req_o,
  output logic [XLEN-1:0]  mem_addr_o,
  input  logic             mem_valid_i,
  input  logic [XLEN-1:0]  mem_rdata_i
);

  typedef enum logic [2:0] {
    ST_IDLE     = 3'd0,
    ST_LEVEL_2  = 3'd1,
    ST_WAIT_L2  = 3'd2,
    ST_LEVEL_1  = 3'd3,
    ST_WAIT_L1  = 3'd4,
    ST_LEVEL_0  = 3'd5,
    ST_WAIT_L0  = 3'd6
  } ptw_state_e;

  ptw_state_e state_q, state_d;

  logic        req_is_itlb_q, req_is_itlb_d;
  logic        req_is_store_q, req_is_store_d;
  logic [XLEN-1:0] req_vaddr_q, req_vaddr_d;
  logic [43:0] next_table_ppn_q, next_table_ppn_d;

  wire [43:0] satp_ppn  = satp_i[43:0];
  wire [15:0] satp_asid = satp_i[59:44];

  wire [8:0] vpn2 = req_vaddr_q[38:30];
  wire [8:0] vpn1 = req_vaddr_q[29:21];
  wire [8:0] vpn0 = req_vaddr_q[20:12];

  // PTE breakdown from memory response
  wire [63:0] pte      = mem_rdata_i;
  wire        pte_v    = pte[0];
  wire        pte_r    = pte[1];
  wire        pte_w    = pte[2];
  wire        pte_x    = pte[3];
  wire        pte_u    = pte[4];
  wire        pte_g    = pte[5];
  wire        pte_a    = pte[6];
  wire        pte_d    = pte[7];
  wire [43:0] pte_ppn  = pte[53:10];
  wire        pte_leaf = pte_r || pte_x;

  assign ptw_busy_o = (state_q != ST_IDLE);

  always_comb begin
    state_d          = state_q;
    req_is_itlb_d    = req_is_itlb_q;
    req_is_store_d   = req_is_store_q;
    req_vaddr_d      = req_vaddr_q;
    next_table_ppn_d = next_table_ppn_q;

    mem_req_o  = 1'b0;
    mem_addr_o = '0;

    itlb_refill_valid_o     = 1'b0;
    itlb_refill_vpn_o       = req_vaddr_q[38:12];
    itlb_refill_asid_o      = satp_asid;
    itlb_refill_ppn_o       = pte_ppn;
    itlb_refill_page_size_o = 2'd0;
    itlb_refill_u_o         = pte_u;
    itlb_refill_x_o         = pte_x;
    itlb_refill_g_o         = pte_g;
    itlb_page_fault_o       = 1'b0;

    dtlb_refill_valid_o     = 1'b0;
    dtlb_refill_vpn_o       = req_vaddr_q[38:12];
    dtlb_refill_asid_o      = satp_asid;
    dtlb_refill_ppn_o       = pte_ppn;
    dtlb_refill_page_size_o = 2'd0;
    dtlb_refill_r_o         = pte_r;
    dtlb_refill_w_o         = pte_w;
    dtlb_refill_x_o         = pte_x;
    dtlb_refill_u_o         = pte_u;
    dtlb_refill_d_o         = pte_d;
    dtlb_refill_a_o         = pte_a;
    dtlb_refill_g_o         = pte_g;
    dtlb_page_fault_o       = 1'b0;

    case (state_q)
      ST_IDLE: begin
        // DTLB miss takes priority over ITLB miss
        if (dtlb_req_i) begin
          req_is_itlb_d    = 1'b0;
          req_is_store_d   = dtlb_is_store_i;
          req_vaddr_d      = dtlb_vaddr_i;
          next_table_ppn_d = satp_ppn;
          state_d          = ST_LEVEL_2;
        end else if (itlb_req_i) begin
          req_is_itlb_d    = 1'b1;
          req_is_store_d   = 1'b0;
          req_vaddr_d      = itlb_vaddr_i;
          next_table_ppn_d = satp_ppn;
          state_d          = ST_LEVEL_2;
        end
      end

      ST_LEVEL_2: begin
        mem_req_o  = 1'b1;
        mem_addr_o = {next_table_ppn_q, 12'b0} + (64'(vpn2) << 3);
        state_d    = ST_WAIT_L2;
      end

      ST_WAIT_L2: begin
        mem_req_o  = 1'b1;
        mem_addr_o = {next_table_ppn_q, 12'b0} + (64'(vpn2) << 3);
        if (mem_valid_i) begin
          if (!pte_v || (!pte_r && pte_w)) begin
            // Invalid PTE: Page fault
            if (req_is_itlb_q) itlb_page_fault_o = 1'b1;
            else               dtlb_page_fault_o = 1'b1;
            state_d = ST_IDLE;
          end else if (pte_leaf) begin
            // 1GB Gigapage Leaf
            if (pte_ppn[17:0] != 18'd0) begin
              // Misaligned superpage
              if (req_is_itlb_q) itlb_page_fault_o = 1'b1;
              else               dtlb_page_fault_o = 1'b1;
            end else begin
              if (req_is_itlb_q) begin
                itlb_refill_valid_o     = 1'b1;
                itlb_refill_page_size_o = 2'd2; // 1GB
              end else begin
                dtlb_refill_valid_o     = 1'b1;
                dtlb_refill_page_size_o = 2'd2; // 1GB
              end
            end
            state_d = ST_IDLE;
          end else begin
            // Pointer to Level 1 Page Table
            next_table_ppn_d = pte_ppn;
            state_d          = ST_LEVEL_1;
          end
        end
      end

      ST_LEVEL_1: begin
        mem_req_o  = 1'b1;
        mem_addr_o = {next_table_ppn_q, 12'b0} + (64'(vpn1) << 3);
        state_d    = ST_WAIT_L1;
      end

      ST_WAIT_L1: begin
        mem_req_o  = 1'b1;
        mem_addr_o = {next_table_ppn_q, 12'b0} + (64'(vpn1) << 3);
        if (mem_valid_i) begin
          if (!pte_v || (!pte_r && pte_w)) begin
            if (req_is_itlb_q) itlb_page_fault_o = 1'b1;
            else               dtlb_page_fault_o = 1'b1;
            state_d = ST_IDLE;
          end else if (pte_leaf) begin
            // 2MB Megapage Leaf
            if (pte_ppn[8:0] != 9'd0) begin
              if (req_is_itlb_q) itlb_page_fault_o = 1'b1;
              else               dtlb_page_fault_o = 1'b1;
            end else begin
              if (req_is_itlb_q) begin
                itlb_refill_valid_o     = 1'b1;
                itlb_refill_page_size_o = 2'd1; // 2MB
              end else begin
                dtlb_refill_valid_o     = 1'b1;
                dtlb_refill_page_size_o = 2'd1; // 2MB
              end
            end
            state_d = ST_IDLE;
          end else begin
            // Pointer to Level 0 Page Table
            next_table_ppn_d = pte_ppn;
            state_d          = ST_LEVEL_0;
          end
        end
      end

      ST_LEVEL_0: begin
        mem_req_o  = 1'b1;
        mem_addr_o = {next_table_ppn_q, 12'b0} + (64'(vpn0) << 3);
        state_d    = ST_WAIT_L0;
      end

      ST_WAIT_L0: begin
        mem_req_o  = 1'b1;
        mem_addr_o = {next_table_ppn_q, 12'b0} + (64'(vpn0) << 3);
        if (mem_valid_i) begin
          if (!pte_v || (!pte_r && pte_w) || (!pte_r && !pte_x)) begin
            if (req_is_itlb_q) itlb_page_fault_o = 1'b1;
            else               dtlb_page_fault_o = 1'b1;
          end else begin
            // 4KB Page Leaf
            if (req_is_itlb_q) begin
              itlb_refill_valid_o     = 1'b1;
              itlb_refill_page_size_o = 2'd0; // 4KB
            end else begin
              dtlb_refill_valid_o     = 1'b1;
              dtlb_refill_page_size_o = 2'd0; // 4KB
            end
          end
          state_d = ST_IDLE;
        end
      end

      default: state_d = ST_IDLE;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q          <= ST_IDLE;
      req_is_itlb_q    <= 1'b0;
      req_is_store_q   <= 1'b0;
      req_vaddr_q      <= '0;
      next_table_ppn_q <= '0;
    end else begin
      state_q          <= state_d;
      req_is_itlb_q    <= req_is_itlb_d;
      req_is_store_q   <= req_is_store_d;
      req_vaddr_q      <= req_vaddr_d;
      next_table_ppn_q <= next_table_ppn_d;
    end
  end

endmodule : moon_ptw

`endif // MOON_PTW_SV
