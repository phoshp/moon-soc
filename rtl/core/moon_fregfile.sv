// ============================================================================
// File: rtl/core/moon_fregfile.sv
// Description: 32 x FLEN floating-point register file for the scalar F/D path.
// ============================================================================

`ifndef MOON_FREGFILE_SV
`define MOON_FREGFILE_SV

`include "moon_pkg.sv"

module moon_fregfile
  import moon_pkg::*;
(
  input  logic             clk_i,
  input  logic             rst_ni,

  input  logic [4:0]       rs1_addr_i,
  output logic [FLEN-1:0]   rs1_data_o,
  input  logic [4:0]       rs2_addr_i,
  output logic [FLEN-1:0]   rs2_data_o,

  input  logic             rd_we_i,
  input  logic [4:0]       rd_addr_i,
  input  logic [FLEN-1:0]   rd_data_i
);

  logic [FLEN-1:0] regs [0:31];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int i = 0; i < 32; i++) begin
        regs[i] <= '0;
      end
    end else if (rd_we_i) begin
      regs[rd_addr_i] <= rd_data_i;
    end
  end

  always_comb begin
    if (rd_we_i && (rd_addr_i == rs1_addr_i)) begin
      rs1_data_o = rd_data_i;
    end else begin
      rs1_data_o = regs[rs1_addr_i];
    end

    if (rd_we_i && (rd_addr_i == rs2_addr_i)) begin
      rs2_data_o = rd_data_i;
    end else begin
      rs2_data_o = regs[rs2_addr_i];
    end
  end

endmodule : moon_fregfile

`endif // MOON_FREGFILE_SV
