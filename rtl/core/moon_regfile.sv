// ============================================================================
// File: rtl/core/moon_regfile.sv
// Description: 32x64-bit Integer Register File for RV64I with x0 hardwired
//              to zero and transparent write-during-read forwarding.
// ============================================================================

`ifndef MOON_REGFILE_SV
`define MOON_REGFILE_SV

`include "moon_pkg.sv"

module moon_regfile
  import moon_pkg::*;
(
  input  logic             clk_i,
  input  logic             rst_ni,

  // Read Port 1
  input  logic [4:0]       rs1_addr_i,
  output logic [XLEN-1:0]  rs1_data_o,

  // Read Port 2
  input  logic [4:0]       rs2_addr_i,
  output logic [XLEN-1:0]  rs2_data_o,

  // Write Port
  input  logic             rd_we_i,
  input  logic [4:0]       rd_addr_i,
  input  logic [XLEN-1:0]  rd_data_i
);

  // 31 registers (x1 through x31); x0 is constant 0
  logic [XLEN-1:0] regs [1:31];

  // Synchronous Write (x0 hardwired to 0; x1..x31 do not require hardware reset)
  always_ff @(posedge clk_i) begin
    if (rd_we_i && (rd_addr_i != 5'd0)) begin
      regs[rd_addr_i] <= rd_data_i;
    end
  end

`ifndef SYNTHESIS
  // Zero-initialization for deterministic simulation without hardware reset overhead
  initial begin
    for (int i = 1; i < 32; i++) begin
      regs[i] = '0;
    end
  end
`endif

  // Asynchronous Read with transparent write-during-read forwarding
  always_comb begin
    if (rs1_addr_i == 5'd0) begin
      rs1_data_o = '0;
    end else if (rd_we_i && (rd_addr_i == rs1_addr_i)) begin
      rs1_data_o = rd_data_i;
    end else begin
      rs1_data_o = regs[rs1_addr_i];
    end
  end

  always_comb begin
    if (rs2_addr_i == 5'd0) begin
      rs2_data_o = '0;
    end else if (rd_we_i && (rd_addr_i == rs2_addr_i)) begin
      rs2_data_o = rd_data_i;
    end else begin
      rs2_data_o = regs[rs2_addr_i];
    end
  end

endmodule : moon_regfile

`endif // MOON_REGFILE_SV
