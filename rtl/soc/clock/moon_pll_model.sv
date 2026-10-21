// ============================================================================
// File: rtl/soc/clock/moon_pll_model.sv
// Description: Synthesizable / behavioral digital PLL model for Moon-SoC.
//              Generates high-speed core clock, peripheral clock, and memory
//              clock with lock detection and programmable dividers.
// ============================================================================

`ifndef MOON_PLL_MODEL_SV
`define MOON_PLL_MODEL_SV

module moon_pll_model #(
  parameter int LOCK_CYCLES = 32
)(
  input  logic       ref_clk_i,    // Reference clock input (e.g. 25MHz/50MHz)
  input  logic       rst_ni,

  // Control & Configuration
  input  logic       pll_enable_i, // 1: PLL active, 0: power-down
  input  logic       pll_bypass_i, // 1: pass ref_clk directly, 0: PLL mode
  input  logic [3:0] div_core_i,   // Core clock divider (0: div1, 1: div2, etc.)
  input  logic [3:0] div_peri_i,   // Peripheral clock divider
  input  logic [3:0] div_mem_i,    // Memory clock divider

  // Status & Generated Clocks
  output logic       pll_locked_o,
  output logic       clk_core_o,
  output logic       clk_peri_o,
  output logic       clk_mem_o
);

  // Lock Counter
  localparam int LOCK_CNT_W = $clog2(LOCK_CYCLES) + 1;
  logic [LOCK_CNT_W-1:0] lock_cnt_q;
  logic                  locked_q;

  always_ff @(posedge ref_clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      lock_cnt_q <= '0;
      locked_q   <= 1'b0;
    end else if (!pll_enable_i) begin
      lock_cnt_q <= '0;
      locked_q   <= 1'b0;
    end else if (lock_cnt_q < LOCK_CNT_W'(LOCK_CYCLES)) begin
      lock_cnt_q <= lock_cnt_q + 1'b1;
      locked_q   <= 1'b0;
    end else begin
      locked_q   <= 1'b1;
    end
  end

  assign pll_locked_o = pll_bypass_i ? 1'b1 : locked_q;

  // Clock Dividers / Prescalers
  logic [3:0] cnt_core_q;
  logic [3:0] cnt_peri_q;
  logic [3:0] cnt_mem_q;

  logic clk_core_div_q;
  logic clk_peri_div_q;
  logic clk_mem_div_q;

  always_ff @(posedge ref_clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cnt_core_q     <= '0;
      cnt_peri_q     <= '0;
      cnt_mem_q      <= '0;
      clk_core_div_q <= 1'b0;
      clk_peri_div_q <= 1'b0;
      clk_mem_div_q  <= 1'b0;
    end else begin
      // Core clock divider
      if (div_core_i == 4'd0) begin
        cnt_core_q     <= '0;
        clk_core_div_q <= 1'b0;
      end else begin
        if (cnt_core_q >= div_core_i) begin
          cnt_core_q     <= '0;
          clk_core_div_q <= ~clk_core_div_q;
        end else begin
          cnt_core_q     <= cnt_core_q + 4'd1;
        end
      end

      // Peripheral clock divider
      if (div_peri_i == 4'd0) begin
        cnt_peri_q     <= '0;
        clk_peri_div_q <= 1'b0;
      end else begin
        if (cnt_peri_q >= div_peri_i) begin
          cnt_peri_q     <= '0;
          clk_peri_div_q <= ~clk_peri_div_q;
        end else begin
          cnt_peri_q     <= cnt_peri_q + 4'd1;
        end
      end

      // Memory clock divider
      if (div_mem_i == 4'd0) begin
        cnt_mem_q     <= '0;
        clk_mem_div_q <= 1'b0;
      end else begin
        if (cnt_mem_q >= div_mem_i) begin
          cnt_mem_q     <= '0;
          clk_mem_div_q <= ~clk_mem_div_q;
        end else begin
          cnt_mem_q     <= cnt_mem_q + 4'd1;
        end
      end
    end
  end

  // Output multiplexing: if bypass or not locked, provide ref_clk_i
  assign clk_core_o = (pll_bypass_i || !locked_q) ? ref_clk_i :
                      (div_core_i == 4'd0 ? ref_clk_i : clk_core_div_q);

  assign clk_peri_o = (pll_bypass_i || !locked_q) ? ref_clk_i :
                      (div_peri_i == 4'd0 ? ref_clk_i : clk_peri_div_q);

  assign clk_mem_o  = (pll_bypass_i || !locked_q) ? ref_clk_i :
                      (div_mem_i == 4'd0 ? ref_clk_i : clk_mem_div_q);

endmodule : moon_pll_model

`endif // MOON_PLL_MODEL_SV
