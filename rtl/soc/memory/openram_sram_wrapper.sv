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
  parameter int ADDR_WIDTH  = 9,  // 512 words = 4 KB for 64-bit data (matches Sky130 2x2KB macros)
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

`ifdef USE_OPENRAM_MACRO
  `define _USE_SRAM_MACRO_IMPL
`endif
`ifdef SYNTHESIS
  `define _USE_SRAM_MACRO_IMPL
`endif

`ifdef _USE_SRAM_MACRO_IMPL
  // Physical Sky130 1RW1R OpenRAM Macro instances (2x 32-bit macros for 64-bit AXI data width)
  // Each macro is 2 KB (512 words x 32 bits, 4 byte masks), combined = 4 KB (512 words x 64 bits)
  sky130_sram_2kbyte_1rw1r_32x512_8 u_sram_lo (
    .clk0   (clk0),
    .csb0   (csb0),
    .web0   (web0),
    .wmask0 (wmask0[3:0]),
    .addr0  (addr0[8:0]),
    .din0   (din0[31:0]),
    .dout0  (dout0[31:0]),
    .clk1   (clk1),
    .csb1   (csb1),
    .addr1  (addr1[8:0]),
    .dout1  (dout1[31:0])
  );

  sky130_sram_2kbyte_1rw1r_32x512_8 u_sram_hi (
    .clk0   (clk0),
    .csb0   (csb0),
    .web0   (web0),
    .wmask0 (wmask0[7:4]),
    .addr0  (addr0[8:0]),
    .din0   (din0[63:32]),
    .dout0  (dout0[63:32]),
    .clk1   (clk1),
    .csb1   (csb1),
    .addr1  (addr1[8:0]),
    .dout1  (dout1[63:32])
  );
`else
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
`endif
`undef _USE_SRAM_MACRO_IMPL

endmodule : openram_sram_wrapper

`endif // OPENRAM_SRAM_WRAPPER_SV
