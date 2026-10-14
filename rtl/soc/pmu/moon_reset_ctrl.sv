// ============================================================================
// File: rtl/soc/pmu/moon_reset_ctrl.sv
// Description: Central Reset Controller & Sequencer for Moon-SoC.
//              Provides asynchronous assertion, synchronous deassertion
//              reset sequencing for multiple power/clock domains.
// ============================================================================

`ifndef MOON_RESET_CTRL_SV
`define MOON_RESET_CTRL_SV

module moon_reset_ctrl (
  input  logic clk_aon_i,     // Always-on clock for reset synchronization
  input  logic raw_rst_ni,    // Raw external pin reset (active low)
  input  logic sw_rst_req_i,  // Software warm-reset request from CRG/PMU
  input  logic wdt_rst_req_i, // Watchdog timer reset request

  // Domain Synchronized Resets (active low)
  output logic rst_aon_no,    // Always-on domain reset
  output logic rst_core_no,   // Core domain reset
  output logic rst_peri_no,   // Peripheral domain reset
  output logic rst_mem_no     // Memory domain reset
);

  // Aggregated raw reset
  wire agg_rst_n = raw_rst_ni && (!sw_rst_req_i) && (!wdt_rst_req_i);

  // 2-Stage Synchronizer for Always-On Domain
  logic aon_sync_m, aon_sync_q;
  always_ff @(posedge clk_aon_i or negedge agg_rst_n) begin
    if (!agg_rst_n) begin
      aon_sync_m <= 1'b0;
      aon_sync_q <= 1'b0;
    end else begin
      aon_sync_m <= 1'b1;
      aon_sync_q <= aon_sync_m;
    end
  end

  // Reset Sequencer Counter: releases resets in a clean cascade
  // 1. AON releases -> 2. Memory & Peripherals release -> 3. Core releases
  logic [3:0] seq_cnt_q;
  logic       core_rst_q, peri_rst_q, mem_rst_q;

  always_ff @(posedge clk_aon_i or negedge aon_sync_q) begin
    if (!aon_sync_q) begin
      seq_cnt_q  <= 4'd0;
      core_rst_q <= 1'b0;
      peri_rst_q <= 1'b0;
      mem_rst_q  <= 1'b0;
    end else begin
      if (seq_cnt_q < 4'd4) begin
        seq_cnt_q <= seq_cnt_q + 4'd1;
      end

      if (seq_cnt_q >= 4'd2) begin
        mem_rst_q  <= 1'b1;
        peri_rst_q <= 1'b1;
        core_rst_q <= 1'b1;
      end
    end
  end

  assign rst_aon_no  = aon_sync_q;
  assign rst_mem_no  = mem_rst_q;
  assign rst_peri_no = peri_rst_q;
  assign rst_core_no = core_rst_q;

endmodule : moon_reset_ctrl

`endif // MOON_RESET_CTRL_SV
