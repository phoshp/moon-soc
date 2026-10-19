// ============================================================================
// File: rtl/soc/memory/sky130_sram_2kbyte_1rw1r_32x512_8_bb.v
// Description: Blackbox stub for Sky130 OpenRAM 2KB (512x32) 1RW1R SRAM macro.
//              Used for synthesis and PnR (Yosys, Slang, OpenROAD) to avoid
//              unsynthesizable simulation delays.
// ============================================================================

(* blackbox *)
module sky130_sram_2kbyte_1rw1r_32x512_8 (
  input  wire        clk0,
  input  wire        csb0,
  input  wire        web0,
  input  wire [3:0]  wmask0,
  input  wire [8:0]  addr0,
  input  wire [31:0] din0,
  output wire [31:0] dout0,
  input  wire        clk1,
  input  wire        csb1,
  input  wire [8:0]  addr1,
  output wire [31:0] dout1
);
endmodule
