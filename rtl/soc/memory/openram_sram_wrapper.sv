// ============================================================================
// File: rtl/soc/memory/openram_sram_wrapper.sv
// Description: OpenRAM-compatible synchronous SRAM macro wrapper.
//              Provides standard OpenRAM 1RW / 1R1W interface with active-low
//              chip select and write enable, byte write-mask strobes, and
//              1-cycle synchronous read latency.
// ============================================================================

`ifndef OPENRAM_SRAM_WRAPPER_SV
`define OPENRAM_SRAM_WRAPPER_SV

module openram_sram_wrapper #(
  parameter int DATA_WIDTH  = 64,
  parameter int ADDR_WIDTH  = 14, // 16384 words = 128 KB for 64-bit data
  parameter int WMASK_WIDTH = DATA_WIDTH / 8
)(
  input  logic                   clk0,
  input  logic                   csb0,   // Active-low chip select
  input  logic                   web0,   // Active-low write enable (0 = write, 1 = read)
  input  logic [WMASK_WIDTH-1:0] wmask0, // Active-high byte write mask
  input  logic [ADDR_WIDTH-1:0]  addr0,
  input  logic [DATA_WIDTH-1:0]  din0,
  output logic [DATA_WIDTH-1:0]  dout0,

  // Optional second port (Port 1: dedicated read for 1R1W / 1RW1R OpenRAM configurations)
  input  logic                   clk1,
  input  logic                   csb1,   // Active-low read chip select
  input  logic [ADDR_WIDTH-1:0]  addr1,
  output logic [DATA_WIDTH-1:0]  dout1
);

  localparam int NUM_WORDS = 1 << ADDR_WIDTH;

  // Synthesis ram_style attribute ensures mapping to BRAM/SRAM macros
  (* syn_ramstyle = "block", ram_style = "block" *)
  logic [7:0] sram_block [0:NUM_WORDS-1][WMASK_WIDTH-1:0];

  logic [DATA_WIDTH-1:0] dout0_reg;
  logic [DATA_WIDTH-1:0] dout1_reg;

  // Port 0: Write (or Read/Write)
  always_ff @(posedge clk0) begin
    if (!csb0) begin
      if (!web0) begin
        for (int b = 0; b < WMASK_WIDTH; b++) begin
          if (wmask0[b]) begin
            sram_block[addr0][b] <= din0[b*8 +: 8];
          end
        end
      end
      for (int b = 0; b < WMASK_WIDTH; b++) begin
        dout0_reg[b*8 +: 8] <= sram_block[addr0][b];
      end
    end
  end

  // Port 1: Synchronous Read (1-cycle latency)
  always_ff @(posedge clk1) begin
    if (!csb1) begin
      for (int b = 0; b < WMASK_WIDTH; b++) begin
        dout1_reg[b*8 +: 8] <= sram_block[addr1][b];
      end
    end
  end

  assign dout0 = dout0_reg;
  assign dout1 = dout1_reg;

endmodule : openram_sram_wrapper

`endif // OPENRAM_SRAM_WRAPPER_SV
