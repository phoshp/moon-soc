// ============================================================================
// File: rtl/core/cache/moon_dcache.sv
// Description: 32 KB 4-Way Set-Associative L1 Data Cache with write-back,
//              write-allocate, AXI4 master interface, uncached I/O bypass,
//              and RVA23 Cache Block Operations (Zicbom / Zicboz).
// ============================================================================

`ifndef MOON_DCACHE_SV
`define MOON_DCACHE_SV

`include "moon_pkg.sv"
`include "axi_pkg.sv"

module moon_dcache
  import moon_pkg::*;
  import axi_pkg::*;
#(
  parameter int NUM_WAYS   = 4,
  parameter int NUM_SETS   = 128,
  parameter int LINE_BYTES = 64
)(
  input  logic clk_i,
  input  logic rst_ni,

  // Core Data Memory Interface
  input  logic             req_i,
  input  logic             we_i,
  input  logic [XLEN-1:0]  addr_i,
  input  logic [XLEN-1:0]  wdata_i,
  input  logic [7:0]       wstrb_i,
  output logic             valid_o,
  output logic [XLEN-1:0]  rdata_o,

  // RVA23 Cache Management Operations (Zicbom / Zicboz)
  input  logic             cbo_inval_i, // CBO.INVAL
  input  logic             cbo_clean_i, // CBO.CLEAN
  input  logic             cbo_flush_i, // CBO.FLUSH
  input  logic             cbo_zero_i,  // CBO.ZERO

  // AXI4 Master Interface (AR, R, AW, W, B Channels)
  output axi_ar_t          m_ar_o,
  input  logic             m_ar_ready_i,
  input  axi_r_t           m_r_i,
  output logic             m_r_ready_o,

  output axi_aw_t          m_aw_o,
  input  logic             m_aw_ready_i,
  output axi_w_t           m_w_o,
  input  logic             m_w_ready_i,
  input  axi_b_t           m_b_i,
  output logic             m_b_ready_o
);

  localparam int SET_BITS    = $clog2(NUM_SETS);     // 7 bits
  localparam int OFFSET_BITS = $clog2(LINE_BYTES);   // 6 bits
  localparam int TAG_BITS    = XLEN - SET_BITS - OFFSET_BITS; // 51 bits

  // Uncached I/O Region: Addresses below 0x7000_0000 (CLINT, PLIC, UART, CRG, PMU)
  // and simulation test status register at 0x8000_1000
  wire is_uncached_io = (addr_i < 64'h7000_0000) || (addr_i[31:12] == 20'h80001);

  wire [SET_BITS-1:0]    req_set  = addr_i[SET_BITS+OFFSET_BITS-1 : OFFSET_BITS];
  wire [TAG_BITS-1:0]    req_tag  = addr_i[XLEN-1 : SET_BITS+OFFSET_BITS];
  wire [OFFSET_BITS-1:3] req_word = addr_i[OFFSET_BITS-1 : 3]; // 8 doublewords (64b each)

  // Cache Storage Arrays
  logic [TAG_BITS-1:0] tag_mem   [0:NUM_SETS-1][0:NUM_WAYS-1];
  logic                valid_mem [0:NUM_SETS-1][0:NUM_WAYS-1];
  logic                dirty_mem [0:NUM_SETS-1][0:NUM_WAYS-1];
  logic [63:0]         data_mem  [0:NUM_SETS-1][0:NUM_WAYS-1][0:7]; // 8 x 64b words per line
  logic [1:0]          lru_cnt   [0:NUM_SETS-1];

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

  // State Machine
  typedef enum logic [3:0] {
    ST_IDLE         = 4'd0,
    ST_IO_READ_AR   = 4'd1,
    ST_IO_READ_R    = 4'd2,
    ST_IO_WRITE_AWW = 4'd3,
    ST_IO_WRITE_B   = 4'd4,
    ST_EVICT_AW     = 4'd5,
    ST_EVICT_W      = 4'd6,
    ST_EVICT_B      = 4'd7,
    ST_REFILL_AR    = 4'd8,
    ST_REFILL_R     = 4'd9
  } state_e;

  state_e state_q, state_d;

  logic [XLEN-1:0] miss_addr_q, miss_addr_d;
  logic [XLEN-1:0] miss_wdata_q, miss_wdata_d;
  logic [7:0]      miss_wstrb_q, miss_wstrb_d;
  logic            miss_we_q,    miss_we_d;
  logic [2:0]      beat_cnt_q,   beat_cnt_d; // 0..7
  logic [63:0]     refill_line_q [0:7];
  logic [63:0]     refill_line_d [0:7];
  logic [63:0]     io_rdata_q,   io_rdata_d;
  logic            aw_done_q,    aw_done_d;
  logic            w_done_q,     w_done_d;

  wire [SET_BITS-1:0] miss_set = miss_addr_q[SET_BITS+OFFSET_BITS-1 : OFFSET_BITS];
  wire [TAG_BITS-1:0] miss_tag = miss_addr_q[XLEN-1 : SET_BITS+OFFSET_BITS];
  int  victim_way;
  assign victim_way = int'(lru_cnt[miss_set]);
  wire victim_is_dirty = valid_mem[miss_set][victim_way] && dirty_mem[miss_set][victim_way];

  int  req_victim_way;
  assign req_victim_way = int'(lru_cnt[req_set]);
  wire req_victim_is_dirty = valid_mem[req_set][req_victim_way] && dirty_mem[req_set][req_victim_way];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q      <= ST_IDLE;
      miss_addr_q  <= '0;
      miss_wdata_q <= '0;
      miss_wstrb_q <= '0;
      miss_we_q    <= 1'b0;
      beat_cnt_q   <= '0;
      io_rdata_q   <= '0;
      aw_done_q    <= 1'b0;
      w_done_q     <= 1'b0;
      for (int i = 0; i < 8; i++) refill_line_q[i] <= '0;
      for (int s = 0; s < NUM_SETS; s++) begin
        lru_cnt[s] <= '0;
        for (int w = 0; w < NUM_WAYS; w++) begin
          valid_mem[s][w] <= 1'b0;
          dirty_mem[s][w] <= 1'b0;
        end
      end
    end else begin
      state_q      <= state_d;
      miss_addr_q  <= miss_addr_d;
      miss_wdata_q <= miss_wdata_d;
      miss_wstrb_q <= miss_wstrb_d;
      miss_we_q    <= miss_we_d;
      beat_cnt_q   <= beat_cnt_d;
      io_rdata_q   <= io_rdata_d;
      aw_done_q    <= aw_done_d;
      w_done_q     <= w_done_d;
      for (int i = 0; i < 8; i++) refill_line_q[i] <= refill_line_d[i];

      // Handle in-place write hits
      if (state_q == ST_IDLE && req_i && !is_uncached_io && hit_any && we_i) begin
        dirty_mem[req_set][hit_way] <= 1'b1;
        for (int b = 0; b < 8; b++) begin
          if (wstrb_i[b]) begin
            data_mem[req_set][hit_way][req_word][b*8 +: 8] <= wdata_i[b*8 +: 8];
          end
        end
      end

      // Handle CBO.ZERO (zero-fill entire block)
      if (cbo_zero_i && !is_uncached_io) begin
        if (hit_any) begin
          dirty_mem[req_set][hit_way] <= 1'b1;
          for (int i = 0; i < 8; i++) data_mem[req_set][hit_way][i] <= '0;
        end else begin
          valid_mem[req_set][victim_way] <= 1'b1;
          dirty_mem[req_set][victim_way] <= 1'b1;
          tag_mem[req_set][victim_way]   <= req_tag;
          for (int i = 0; i < 8; i++) data_mem[req_set][victim_way][i] <= '0;
          lru_cnt[req_set] <= lru_cnt[req_set] + 2'd1;
        end
      end

      // Handle CBO.INVAL
      if (cbo_inval_i && !is_uncached_io && hit_any) begin
        valid_mem[req_set][hit_way] <= 1'b0;
        dirty_mem[req_set][hit_way] <= 1'b0;
      end

      // Commit refilled line into cache on completion
      if (state_q == ST_REFILL_R && m_r_i.valid && m_r_i.last) begin
        tag_mem[miss_set][victim_way]   <= miss_tag;
        valid_mem[miss_set][victim_way] <= 1'b1;
        dirty_mem[miss_set][victim_way] <= miss_we_q;
        for (int i = 0; i < 8; i++) begin
          if (miss_we_q && (i == miss_addr_q[OFFSET_BITS-1:3])) begin
            // Apply write strobes on the target word
            for (int b = 0; b < 8; b++) begin
              data_mem[miss_set][victim_way][i][b*8 +: 8] <= miss_wstrb_q[b] ? miss_wdata_q[b*8 +: 8]
                                                                              : refill_line_d[i][b*8 +: 8];
            end
          end else begin
            data_mem[miss_set][victim_way][i] <= refill_line_d[i];
          end
        end
        lru_cnt[miss_set] <= lru_cnt[miss_set] + 2'd1;
      end
    end
  end

  always_comb begin
    state_d       = state_q;
    miss_addr_d   = miss_addr_q;
    miss_wdata_d  = miss_wdata_q;
    miss_wstrb_d  = miss_wstrb_q;
    miss_we_d     = miss_we_q;
    beat_cnt_d    = beat_cnt_q;
    io_rdata_d    = io_rdata_q;
    aw_done_d     = aw_done_q;
    w_done_d      = w_done_q;
    for (int i = 0; i < 8; i++) refill_line_d[i] = refill_line_q[i];

    m_ar_o      = '0;
    m_r_ready_o = 1'b0;
    m_aw_o      = '0;
    m_w_o       = '0;
    m_b_ready_o = 1'b0;

    valid_o = 1'b0;
    rdata_o = '0;

    if (!rst_ni) begin
      state_d = ST_IDLE;
    end else begin
      case (state_q)
        ST_IDLE: begin
        if (req_i) begin
          if (is_uncached_io) begin
            // Uncached I/O access
            miss_addr_d  = addr_i;
            miss_wdata_d = wdata_i;
            miss_wstrb_d = wstrb_i;
            miss_we_d    = we_i;
            aw_done_d    = 1'b0;
            w_done_d     = 1'b0;
            if (we_i) begin
              m_aw_o.valid = 1'b1;
              m_aw_o.id    = 4'd1;
              m_aw_o.addr  = addr_i;
              m_aw_o.len   = 8'd0;
              m_aw_o.size  = 3'b011;
              m_aw_o.burst = AXI_BURST_INCR;

              m_w_o.valid  = 1'b1;
              m_w_o.data   = wdata_i;
              m_w_o.strb   = wstrb_i;
              m_w_o.last   = 1'b1;

              if (m_aw_ready_i) aw_done_d = 1'b1;
              if (m_w_ready_i)  w_done_d  = 1'b1;

              if (m_aw_ready_i && m_w_ready_i) begin
                state_d = ST_IO_WRITE_B;
              end else begin
                state_d = ST_IO_WRITE_AWW;
              end
            end else begin
              m_ar_o.valid = 1'b1;
              m_ar_o.id    = 4'd1;
              m_ar_o.addr  = addr_i;
              m_ar_o.len   = 8'd0;
              m_ar_o.size  = 3'b011;
              m_ar_o.burst = AXI_BURST_INCR;
              if (m_ar_ready_i) state_d = ST_IO_READ_R;
              else state_d = ST_IO_READ_AR;
            end
          end else if (hit_any) begin
            // Cache Hit!
            valid_o = 1'b1;
            rdata_o = data_mem[req_set][hit_way][req_word];
          end else begin
            // Cacheable Miss: If victim is dirty, evict first; otherwise refill directly
            miss_addr_d  = addr_i;
            miss_wdata_d = wdata_i;
            miss_wstrb_d = wstrb_i;
            miss_we_d    = we_i;
            beat_cnt_d   = '0;

            if (req_victim_is_dirty) begin
              // Evict dirty line via AXI4 write burst
              m_aw_o.valid = 1'b1;
              m_aw_o.id    = 4'd1;
              m_aw_o.addr  = {tag_mem[req_set][req_victim_way], req_set, {OFFSET_BITS{1'b0}}};
              m_aw_o.len   = 8'd7;   // 8 beats
              m_aw_o.size  = 3'b011; // 64 bits
              m_aw_o.burst = AXI_BURST_INCR;

              m_w_o.valid  = 1'b1;
              m_w_o.data   = data_mem[req_set][req_victim_way][0];
              m_w_o.strb   = 8'hFF;
              m_w_o.last   = 1'b0;

              if (m_aw_ready_i) state_d = ST_EVICT_W;
              else state_d = ST_EVICT_AW;
            end else begin
              // Refill directly
              m_ar_o.valid = 1'b1;
              m_ar_o.id    = 4'd1;
              m_ar_o.addr  = {addr_i[XLEN-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
              m_ar_o.len   = 8'd7;
              m_ar_o.size  = 3'b011;
              m_ar_o.burst = AXI_BURST_INCR;
              if (m_ar_ready_i) state_d = ST_REFILL_R;
              else state_d = ST_REFILL_AR;
            end
          end
        end
      end

      // ----------------------------------------------------------------------
      // Uncached I/O Handling
      // ----------------------------------------------------------------------
      ST_IO_READ_AR: begin
        m_ar_o.valid = 1'b1;
        m_ar_o.id    = 4'd1;
        m_ar_o.addr  = miss_addr_q;
        m_ar_o.len   = 8'd0;
        m_ar_o.size  = 3'b011;
        m_ar_o.burst = AXI_BURST_INCR;
        if (m_ar_ready_i) state_d = ST_IO_READ_R;
      end

      ST_IO_READ_R: begin
        m_r_ready_o = 1'b1;
        if (m_r_i.valid) begin
          io_rdata_d = m_r_i.data;
          valid_o    = 1'b1;
          rdata_o    = m_r_i.data;
          state_d    = ST_IDLE;
        end
      end

      ST_IO_WRITE_AWW: begin
        m_aw_o.valid = !aw_done_q;
        m_aw_o.id    = 4'd1;
        m_aw_o.addr  = miss_addr_q;
        m_aw_o.len   = 8'd0;
        m_aw_o.size  = 3'b011;
        m_aw_o.burst = AXI_BURST_INCR;

        m_w_o.valid  = !w_done_q;
        m_w_o.data   = miss_wdata_q;
        m_w_o.strb   = miss_wstrb_q;
        m_w_o.last   = 1'b1;

        if (m_aw_ready_i) aw_done_d = 1'b1;
        if (m_w_ready_i)  w_done_d  = 1'b1;

        if ((aw_done_q || m_aw_ready_i) && (w_done_q || m_w_ready_i)) begin
          state_d   = ST_IO_WRITE_B;
          aw_done_d = 1'b0;
          w_done_d  = 1'b0;
        end
      end

      ST_IO_WRITE_B: begin
        m_b_ready_o = 1'b1;
        if (m_b_i.valid) begin
          valid_o = 1'b1;
          state_d = ST_IDLE;
        end
      end

      // ----------------------------------------------------------------------
      // Cacheable Eviction Handling
      // ----------------------------------------------------------------------
      ST_EVICT_AW: begin
        m_aw_o.valid = 1'b1;
        m_aw_o.id    = 4'd1;
        m_aw_o.addr  = {tag_mem[miss_set][victim_way], miss_set, {OFFSET_BITS{1'b0}}};
        m_aw_o.len   = 8'd7;
        m_aw_o.size  = 3'b011;
        m_aw_o.burst = AXI_BURST_INCR;
        if (m_aw_ready_i) state_d = ST_EVICT_W;
      end

      ST_EVICT_W: begin
        m_w_o.valid = 1'b1;
        m_w_o.data  = data_mem[miss_set][victim_way][beat_cnt_q];
        m_w_o.strb  = 8'hFF;
        m_w_o.last  = (beat_cnt_q == 3'd7);
        if (m_w_ready_i) begin
          if (beat_cnt_q == 3'd7) begin
            beat_cnt_d = '0;
            state_d    = ST_EVICT_B;
          end else begin
            beat_cnt_d = beat_cnt_q + 3'd1;
          end
        end
      end

      ST_EVICT_B: begin
        m_b_ready_o = 1'b1;
        if (m_b_i.valid) begin
          // Eviction completed, proceed to refill the requested line
          m_ar_o.valid = 1'b1;
          m_ar_o.id    = 4'd1;
          m_ar_o.addr  = {miss_addr_q[XLEN-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
          m_ar_o.len   = 8'd7;
          m_ar_o.size  = 3'b011;
          m_ar_o.burst = AXI_BURST_INCR;
          if (m_ar_ready_i) state_d = ST_REFILL_R;
          else state_d = ST_REFILL_AR;
        end
      end

      // ----------------------------------------------------------------------
      // Cacheable Refill Handling
      // ----------------------------------------------------------------------
      ST_REFILL_AR: begin
        m_ar_o.valid = 1'b1;
        m_ar_o.id    = 4'd1;
        m_ar_o.addr  = {miss_addr_q[XLEN-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
        m_ar_o.len   = 8'd7;
        m_ar_o.size  = 3'b011;
        m_ar_o.burst = AXI_BURST_INCR;
        if (m_ar_ready_i) state_d = ST_REFILL_R;
      end

      ST_REFILL_R: begin
        m_r_ready_o = 1'b1;
        if (m_r_i.valid) begin
          refill_line_d[beat_cnt_q] = m_r_i.data;
          beat_cnt_d = beat_cnt_q + 3'd1;
          if (m_r_i.last) begin
            state_d = ST_IDLE; // Line committed to data_mem array, hits on next cycle
          end
        end
      end

      default: state_d = ST_IDLE;
    endcase
    end
  end

endmodule : moon_dcache

`endif // MOON_DCACHE_SV
