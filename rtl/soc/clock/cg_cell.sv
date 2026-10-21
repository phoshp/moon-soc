// ============================================================================
// File: rtl/soc/clock/cg_cell.sv
// Description: Integrated Clock Gating (ICG) cell using latch-based glitch-free
//              clock gating conforming to industry standard ASIC/FPGA cells.
// ============================================================================

`ifndef CG_CELL_SV
`define CG_CELL_SV

module cg_cell (
  input  logic clk_i,
  input  logic enable_i,
  input  logic test_mode_i,
  output logic clk_gated_o
);

`ifdef SYNTHESIS
  // Native Sky130 Integrated Clock Gating (ICG) cell
  // Recognized directly by CTS / OpenSTA as a clock gating element,
  // ensuring proper clock tree balancing and eliminating hold timing loops.
  sky130_fd_sc_hd__dlclkp_1 u_icg (
    .CLK  (clk_i),
    .GATE (enable_i | test_mode_i),
    .GCLK (clk_gated_o)
  );
`else
  logic latch_en;

  // Level-sensitive latch: transparent when clk_i is low (0)
  always_latch begin
    if (!clk_i) begin
      latch_en = enable_i | test_mode_i;
    end
  end

  assign clk_gated_o = clk_i & latch_en;
`endif

endmodule : cg_cell

`endif // CG_CELL_SV
