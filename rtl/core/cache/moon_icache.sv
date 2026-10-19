// ============================================================================
// File: rtl/core/cache/moon_icache.sv
// Description: 32 KB 4-Way Set-Associative L1 Instruction Cache with 64-byte
//              cache lines, AXI4 burst refill (M0), and FENCE.I invalidation.
// ============================================================================

`ifndef MOON_ICACHE_SV
`define MOON_ICACHE_SV

`include "moon_pkg.sv"
`include "axi_pkg.sv"

module moon_icache
  import moon_pkg::*;
  import axi_pkg::*;
#(
  parameter int NUM_WAYS     = 4,
  parameter int NUM_SETS     = 128,
  parameter int LINE_BYTES   = 64
)(
  input  logic clk_i,
  input  logic rst_ni,

  // Core Instruction Fetch Interface
  input  logic             req_i,
  input  logic [XLEN-1:0]  addr_i,
  output logic             valid_o,
  output logic [ILEN-1:0]  rdata_o,
  input  logic             fence_i_i, // Invalidate all cache lines

  // AXI4 Master Interface (AR & R Channels)
  output axi_ar_t          m_ar_o,
  input  logic             m_ar_ready_i,
  input  axi_r_t           m_r_i,
  output logic             m_r_ready_o
);

  localparam int SET_BITS    = $clog2(NUM_SETS);     // 7 bits
  localparam int OFFSET_BITS = $clog2(LINE_BYTES);   // 6 bits
  localparam int TAG_BITS    = XLEN - SET_BITS - OFFSET_BITS; // 51 bits

  wire [SET_BITS-1:0]    req_set    = addr_i[SET_BITS+OFFSET_BITS-1 : OFFSET_BITS];
  wire [TAG_BITS-1:0]    req_tag    = addr_i[XLEN-1 : SET_BITS+OFFSET_BITS];
  wire [OFFSET_BITS-1:2] req_word   = addr_i[OFFSET_BITS-1 : 2]; // 16 words (32b each)

  // Cache Storage Arrays
  logic [TAG_BITS-1:0] tag_mem  [0:NUM_SETS-1][0:NUM_WAYS-1];
  logic                valid_mem[0:NUM_SETS-1][0:NUM_WAYS-1];
  logic [31:0]         data_mem [0:NUM_SETS-1][0:NUM_WAYS-1][0:15]; // 16 x 32b words per line
  logic [1:0]          lru_cnt  [0:NUM_SETS-1]; // Replacement pointer

  // Hit Detection
  logic [NUM_WAYS-1:0] way_hit;
  logic                hit_any;
  logic [$clog2(NUM_WAYS)-1:0] hit_way;

  always_comb begin
    hit_any = 1'b0;
    hit_way = '0;
    for (int w = 0; w < NUM_WAYS; w++) begin
      way_hit[w] = valid_mem[req_set][w] && (tag_mem[req_set][w] == req_tag);
      if (way_hit[w]) begin
        hit_any = 1'b1;
        hit_way = w[$clog2(NUM_WAYS)-1:0];
      end
    end
  end

  // Refill State Machine
  typedef enum logic [1:0] {
    ST_IDLE   = 2'd0,
    ST_AR     = 2'd1,
    ST_R_BURST= 2'd2
  } state_e;

  state_e state_q, state_d;
  logic [XLEN-1:0] miss_addr_q, miss_addr_d;
  logic [2:0]      beat_cnt_q,  beat_cnt_d; // 0..7 (8 beats of 64 bits = 64 bytes)
  logic [31:0]     refill_line_q [0:15];
  logic [31:0]     refill_line_d [0:15];

  wire [SET_BITS-1:0] miss_set = miss_addr_q[SET_BITS+OFFSET_BITS-1 : OFFSET_BITS];
  wire [TAG_BITS-1:0] miss_tag = miss_addr_q[XLEN-1 : SET_BITS+OFFSET_BITS];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q     <= ST_IDLE;
      miss_addr_q <= '0;
      beat_cnt_q  <= '0;
      for (int i = 0; i < 16; i++) refill_line_q[i] <= '0;
      for (int s = 0; s < NUM_SETS; s++) begin
        lru_cnt[s] <= '0;
        for (int w = 0; w < NUM_WAYS; w++) valid_mem[s][w] <= 1'b0;
      end
    end else begin
      state_q     <= state_d;
      miss_addr_q <= miss_addr_d;
      beat_cnt_q  <= beat_cnt_d;
      for (int i = 0; i < 16; i++) refill_line_q[i] <= refill_line_d[i];

      // FENCE.I: Invalidate entire cache
      if (fence_i_i) begin
        for (int s = 0; s < NUM_SETS; s++) begin
          for (int w = 0; w < NUM_WAYS; w++) valid_mem[s][w] <= 1'b0;
        end
      end

      // Write refilled line into cache on completion
      if (state_q == ST_R_BURST && m_r_i.valid && m_r_i.last) begin
        automatic int rep_way = int'(lru_cnt[miss_set]);
        tag_mem[miss_set][rep_way]   <= miss_tag;
        valid_mem[miss_set][rep_way] <= 1'b1;
        for (int i = 0; i < 16; i++) begin
          data_mem[miss_set][rep_way][i] <= refill_line_d[i];
        end
        lru_cnt[miss_set] <= lru_cnt[miss_set] + 2'd1; // Round-robin update
      end
    end
  end

  always_comb begin
    state_d       = state_q;
    miss_addr_d   = miss_addr_q;
    beat_cnt_d    = beat_cnt_q;
    for (int i = 0; i < 16; i++) refill_line_d[i] = refill_line_q[i];

    m_ar_o        = '0;
    m_r_ready_o   = 1'b0;
    valid_o       = 1'b0;
    rdata_o       = 32'h0000_0013; // NOP default

    if (!rst_ni) begin
      state_d = ST_IDLE;
    end else begin
      case (state_q)
        ST_IDLE: begin
        if (req_i) begin
          if (hit_any) begin
            valid_o = 1'b1;
            rdata_o = data_mem[req_set][hit_way][req_word];
          end else begin
            // Cache Miss: Initiate AXI4 64-byte burst read
            miss_addr_d = addr_i;
            beat_cnt_d  = '0;
            m_ar_o.valid = 1'b1;
            m_ar_o.id    = 4'd0;
            m_ar_o.addr  = {addr_i[XLEN-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
            m_ar_o.len   = 8'd7;   // 8 beats (8 x 8 = 64 bytes)
            m_ar_o.size  = 3'b011; // 8 bytes (64-bit bus)
            m_ar_o.burst = AXI_BURST_INCR;
            if (m_ar_ready_i) begin
              state_d = ST_R_BURST;
            end else begin
              state_d = ST_AR;
            end
          end
        end
      end

      ST_AR: begin
        m_ar_o.valid = 1'b1;
        m_ar_o.id    = 4'd0;
        m_ar_o.addr  = {miss_addr_q[XLEN-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
        m_ar_o.len   = 8'd7;
        m_ar_o.size  = 3'b011;
        m_ar_o.burst = AXI_BURST_INCR;
        if (m_ar_ready_i) begin
          state_d = ST_R_BURST;
        end
      end

      ST_R_BURST: begin
        m_r_ready_o = 1'b1;
        if (m_r_i.valid) begin
          // Each beat gives 64 bits = two 32-bit words
          refill_line_d[beat_cnt_q*2 + 0] = m_r_i.data[31:0];
          refill_line_d[beat_cnt_q*2 + 1] = m_r_i.data[63:32];
          beat_cnt_d = beat_cnt_q + 3'd1;

          if (m_r_i.last) begin
            state_d = ST_IDLE; // Line stored into cache array, hits on next cycle
          end
        end
      end

      default: state_d = ST_IDLE;
    endcase
    end
  end

endmodule : moon_icache

`endif // MOON_ICACHE_SV
