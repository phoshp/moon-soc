// ============================================================================
// File: rtl/soc/interconnect/axi_crossbar.sv
// Description: Multi-Master, Multi-Slave 64-bit AXI4 Crossbar Switch.
//              Supports 2 Masters (M0: Fetch/I, M1: Data/D) and
//              4 Slaves (S0: Boot ROM, S1: SRAM, S2: APB Periphs, S3: Main Mem)
// ============================================================================

`ifndef AXI_CROSSBAR_SV
`define AXI_CROSSBAR_SV

`include "axi_pkg.sv"

module axi_crossbar
  import axi_pkg::*;
#(
  parameter int NUM_MASTERS = 2,
  parameter int NUM_SLAVES  = 4
)(
  input  logic clk_i,
  input  logic rst_ni,

  // --------------------------------------------------------------------------
  // Master Interfaces (Inputs from Core / DMA)
  // --------------------------------------------------------------------------
  // Read Address Channel
  input  axi_ar_t [NUM_MASTERS-1:0]  m_ar_i,
  output logic    [NUM_MASTERS-1:0]  m_ar_ready_o,

  // Read Data Channel
  output axi_r_t  [NUM_MASTERS-1:0]  m_r_o,
  input  logic    [NUM_MASTERS-1:0]  m_r_ready_i,

  // Write Address Channel
  input  axi_aw_t [NUM_MASTERS-1:0]  m_aw_i,
  output logic    [NUM_MASTERS-1:0]  m_aw_ready_o,

  // Write Data Channel
  input  axi_w_t  [NUM_MASTERS-1:0]  m_w_i,
  output logic    [NUM_MASTERS-1:0]  m_w_ready_o,

  // Write Response Channel
  output axi_b_t  [NUM_MASTERS-1:0]  m_b_o,
  input  logic    [NUM_MASTERS-1:0]  m_b_ready_i,

  // --------------------------------------------------------------------------
  // Slave Interfaces (Outputs to Memory / Peripherals)
  // --------------------------------------------------------------------------
  // Read Address Channel
  output axi_ar_t [NUM_SLAVES-1:0]   s_ar_o,
  input  logic    [NUM_SLAVES-1:0]   s_ar_ready_i,

  // Read Data Channel
  input  axi_r_t  [NUM_SLAVES-1:0]   s_r_i,
  output logic    [NUM_SLAVES-1:0]   s_r_ready_o,

  // Write Address Channel
  output axi_aw_t [NUM_SLAVES-1:0]   s_aw_o,
  input  logic    [NUM_SLAVES-1:0]   s_aw_ready_i,

  // Write Data Channel
  output axi_w_t  [NUM_SLAVES-1:0]   s_w_o,
  input  logic    [NUM_SLAVES-1:0]   s_w_ready_i,

  // Write Response Channel
  input  axi_b_t  [NUM_SLAVES-1:0]   s_b_i,
  output logic    [NUM_SLAVES-1:0]   s_b_ready_o
);

  // --------------------------------------------------------------------------
  // Slave Address Decoding Function
  // S0: Boot ROM    (0x0000_1000 - 0x0000_8FFF)
  // S1: SRAM        (0x7000_0000 - 0x7001_FFFF)
  // S2: APB Periphs (0x0200_0000 - 0x1FFF_FFFF)
  // S3: Main DRAM   (0x8000_0000 - 0xFFFF_FFFF)
  // --------------------------------------------------------------------------
  function automatic int get_slave_idx(input logic [AXI_ADDR_WIDTH-1:0] addr);
    if (addr >= 64'h0000_1000 && addr <= 64'h0000_8FFF) begin
      return 0; // S0: Boot ROM
    end else if (addr >= 64'h7000_0000 && addr <= 64'h7001_FFFF) begin
      return 1; // S1: SRAM
    end else if (addr >= 64'h0200_0000 && addr <= 64'h1FFF_FFFF) begin
      return 2; // S2: APB Peripherals (CLINT, PLIC, UART)
    end else if (addr >= 64'h8000_0000) begin
      return 3; // S3: Main DRAM / External RAM
    end else begin
      return 0; // Default fallback to S0
    end
  endfunction

  // --------------------------------------------------------------------------
  // Read Path Crossbar (Arbiter + Routing)
  // --------------------------------------------------------------------------
  // Master selection for read address: Priority to M1 (Data) over M0 (Instruction)
  // or round-robin
  logic [$clog2(NUM_MASTERS)-1:0] ar_grant_m;
  logic                           ar_valid_any;
  int                             ar_target_s;

  always_comb begin
    ar_valid_any = 1'b0;
    ar_grant_m   = '0;
    // Simple priority: M1 (Data) has priority to avoid CPU load stalls, then M0
    if (m_ar_i[1].valid) begin
      ar_valid_any = 1'b1;
      ar_grant_m   = 1;
    end else if (m_ar_i[0].valid) begin
      ar_valid_any = 1'b1;
      ar_grant_m   = 0;
    end
    ar_target_s = get_slave_idx(m_ar_i[ar_grant_m].addr);
  end

  // Register the outstanding read request's routing so response returns to the right master
  logic [$clog2(NUM_MASTERS)-1:0] r_route_m [NUM_SLAVES-1:0];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int i = 0; i < NUM_SLAVES; i++) r_route_m[i] <= '0;
    end else begin
      for (int s = 0; s < NUM_SLAVES; s++) begin
        if (s_ar_o[s].valid && s_ar_ready_i[s]) begin
          r_route_m[s] <= ar_grant_m;
        end
      end
    end
  end

  // Drive Slave AR channels
  always_comb begin
    for (int s = 0; s < NUM_SLAVES; s++) begin
      s_ar_o[s] = '0;
      if (ar_valid_any && (ar_target_s == s)) begin
        s_ar_o[s]       = m_ar_i[ar_grant_m];
        s_ar_o[s].valid = 1'b1;
      end
    end
  end

  // Drive Master AR ready
  always_comb begin
    for (int m = 0; m < NUM_MASTERS; m++) begin
      m_ar_ready_o[m] = 1'b0;
      if (ar_valid_any && (ar_grant_m == m)) begin
        m_ar_ready_o[m] = s_ar_ready_i[ar_target_s];
      end
    end
  end

  // Drive Master R channels (Read Data Return) with per-master slave arbitration
  always_comb begin
    for (int m = 0; m < NUM_MASTERS; m++) begin
      m_r_o[m] = '0;
    end
    for (int s = 0; s < NUM_SLAVES; s++) begin
      s_r_ready_o[s] = 1'b0;
      if (s_r_i[s].valid) begin
        automatic int m = r_route_m[s];
        if (!m_r_o[m].valid) begin
          m_r_o[m]       = s_r_i[s];
          s_r_ready_o[s] = m_r_ready_i[m];
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // Write Path Crossbar (AW, W, B)
  // Only Master 1 (Data) writes in a basic system (M0 is Instruction Fetch, read-only)
  // --------------------------------------------------------------------------
  int aw_target_s;
  always_comb begin
    aw_target_s = get_slave_idx(m_aw_i[1].addr);
  end

  // Track target slave for write response
  int b_target_s;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      b_target_s <= 0;
    end else if (m_aw_i[1].valid && m_aw_ready_o[1]) begin
      b_target_s <= aw_target_s;
    end
  end

  // Track active multi-beat write burst destination
  logic w_burst_busy_q;

  wire aw_fire     = m_aw_i[1].valid && m_aw_ready_o[1];
  wire w_last_fire = m_w_i[1].valid && m_w_ready_o[1] && m_w_i[1].last;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      w_burst_busy_q <= 1'b0;
    end else begin
      if (aw_fire && !w_last_fire) begin
        w_burst_busy_q <= 1'b1;
      end else if (w_last_fire) begin
        w_burst_busy_q <= 1'b0;
      end
    end
  end

  // Lock W channel routing to the active burst target until burst completes
  int cur_w_target_s;
  assign cur_w_target_s = (w_burst_busy_q || !m_aw_i[1].valid) ? b_target_s : aw_target_s;

  // Write Address routing (block new AW while previous burst is still transmitting beats)
  always_comb begin
    m_aw_ready_o[0] = 1'b0; // M0 never writes
    m_aw_ready_o[1] = !w_burst_busy_q ? s_aw_ready_i[aw_target_s] : 1'b0;
    for (int s = 0; s < NUM_SLAVES; s++) begin
      s_aw_o[s] = '0;
      if (!w_burst_busy_q && m_aw_i[1].valid && (aw_target_s == s)) begin
        s_aw_o[s]       = m_aw_i[1];
        s_aw_o[s].valid = 1'b1;
      end
    end
  end

  // Write Data routing
  always_comb begin
    m_w_ready_o[0] = 1'b0;
    m_w_ready_o[1] = s_w_ready_i[cur_w_target_s];
    for (int s = 0; s < NUM_SLAVES; s++) begin
      s_w_o[s] = '0;
      if (m_w_i[1].valid && (cur_w_target_s == s)) begin
        s_w_o[s]       = m_w_i[1];
        s_w_o[s].valid = 1'b1;
      end
    end
  end

  // Write Response routing
  always_comb begin
    m_b_o[0] = '0;
    m_b_o[1] = s_b_i[b_target_s];
    for (int s = 0; s < NUM_SLAVES; s++) begin
      s_b_ready_o[s] = 1'b0;
      if (s == b_target_s) begin
        s_b_ready_o[s] = m_b_ready_i[1];
      end
    end
  end

endmodule : axi_crossbar

`endif // AXI_CROSSBAR_SV
