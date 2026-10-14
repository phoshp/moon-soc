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

  logic latch_en;

  // Level-sensitive latch: transparent when clk_i is low (0)
  always_latch begin
    if (!clk_i) begin
      latch_en = enable_i | test_mode_i;
    end
  end

  assign clk_gated_o = clk_i & latch_en;

endmodule : cg_cell

`endif // CG_CELL_SV
