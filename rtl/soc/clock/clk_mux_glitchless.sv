// ============================================================================
// File: rtl/soc/clock/clk_mux_glitchless.sv
// Description: Dual-input glitchless clock multiplexer switching safely
//              between two asynchronous/unrelated clock domains (e.g. OSC and PLL).
// ============================================================================

`ifndef CLK_MUX_GLITCHLESS_SV
`define CLK_MUX_GLITCHLESS_SV

module clk_mux_glitchless (
  input  logic clk_0_i,
  input  logic clk_1_i,
  input  logic sel_i,    // 0: select clk_0, 1: select clk_1
  input  logic rst_ni,
  output logic clk_out_o
);

  // Synchronizer chain for clk_0 domain
  logic q0_meta, q0_sync;
  logic q0_en_neg;

  // Synchronizer chain for clk_1 domain
  logic q1_meta, q1_sync;
  logic q1_en_neg;

  // Domain 0: enable only when sel_i == 0 AND domain 1 has turned off
  wire d0_req = (!sel_i) && (!q1_en_neg);

  always_ff @(posedge clk_0_i or negedge rst_ni) begin
    if (!rst_ni) begin
      q0_meta <= 1'b1;
      q0_sync <= 1'b1;
    end else begin
      q0_meta <= d0_req;
      q0_sync <= q0_meta;
    end
  end

  // Negative edge register to ensure enable changes only when clk_0 is low
  always_ff @(negedge clk_0_i or negedge rst_ni) begin
    if (!rst_ni) begin
      q0_en_neg <= 1'b1;
    end else begin
      q0_en_neg <= q0_sync;
    end
  end

  // Domain 1: enable only when sel_i == 1 AND domain 0 has turned off
  wire d1_req = sel_i && (!q0_en_neg);

  always_ff @(posedge clk_1_i or negedge rst_ni) begin
    if (!rst_ni) begin
      q1_meta <= 1'b0;
      q1_sync <= 1'b0;
    end else begin
      q1_meta <= d1_req;
      q1_sync <= q1_meta;
    end
  end

  always_ff @(negedge clk_1_i or negedge rst_ni) begin
    if (!rst_ni) begin
      q1_en_neg <= 1'b0;
    end else begin
      q1_en_neg <= q1_sync;
    end
  end

  // Gated clock OR combination (one-hot guaranteed by cross-feedback)
  assign clk_out_o = (clk_0_i & q0_en_neg) | (clk_1_i & q1_en_neg);

endmodule : clk_mux_glitchless

`endif // CLK_MUX_GLITCHLESS_SV
