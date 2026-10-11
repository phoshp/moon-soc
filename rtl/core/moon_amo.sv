// ============================================================================
// File: rtl/core/moon_amo.sv
// Description: RV64A Atomic Memory Operations (AMO) ALU and LR/SC reservation
//              monitor for multi-core synchronization.
// ============================================================================

`ifndef MOON_AMO_SV
`define MOON_AMO_SV

`include "moon_pkg.sv"

module moon_amo
  import moon_pkg::*;
(
  input  logic             clk_i,
  input  logic             rst_ni,

  // AMO Arithmetic Control
  input  amo_op_e          amo_op_i,
  input  logic             is_word_i,      // 1 = 32-bit (.W), 0 = 64-bit (.D)
  input  logic [XLEN-1:0]  mem_data_i,     // Value read from memory (*addr)
  input  logic [XLEN-1:0]  rs2_data_i,     // Operand from register rs2
  output logic [XLEN-1:0]  amo_result_o,   // Value to write back to memory

  // LR/SC Reservation Interface
  input  logic             lr_valid_i,     // Core is executing LR
  input  logic [XLEN-1:0]  lr_addr_i,      // Reservation address
  input  logic             sc_valid_i,     // Core is executing SC
  input  logic [XLEN-1:0]  sc_addr_i,      // SC target address
  input  logic             inv_valid_i,    // Invalidation from other cores / bus
  input  logic [XLEN-1:0]  inv_addr_i,     // Invalidated address
  output logic             sc_success_o    // 1 if SC succeeds, 0 if fails
);

  // --------------------------------------------------------------------------
  // AMO Arithmetic Computation
  // --------------------------------------------------------------------------
  logic signed [31:0] mem32_s;
  logic signed [31:0] rs2_32_s;
  logic [31:0]        mem32_u;
  logic [31:0]        rs2_32_u;

  assign mem32_s  = mem_data_i[31:0];
  assign rs2_32_s = rs2_data_i[31:0];
  assign mem32_u  = mem_data_i[31:0];
  assign rs2_32_u = rs2_data_i[31:0];

  logic [31:0] amo_res32;
  logic [63:0] amo_res64;

  always_comb begin
    case (amo_op_i)
      AMO_SWAP: begin
        amo_res32 = rs2_32_u;
        amo_res64 = rs2_data_i;
      end
      AMO_ADD: begin
        amo_res32 = mem32_u + rs2_32_u;
        amo_res64 = mem_data_i + rs2_data_i;
      end
      AMO_XOR: begin
        amo_res32 = mem32_u ^ rs2_32_u;
        amo_res64 = mem_data_i ^ rs2_data_i;
      end
      AMO_AND: begin
        amo_res32 = mem32_u & rs2_32_u;
        amo_res64 = mem_data_i & rs2_data_i;
      end
      AMO_OR: begin
        amo_res32 = mem32_u | rs2_32_u;
        amo_res64 = mem_data_i | rs2_data_i;
      end
      AMO_MIN: begin
        amo_res32 = (mem32_s < rs2_32_s) ? mem32_s : rs2_32_s;
        amo_res64 = ($signed(mem_data_i) < $signed(rs2_data_i)) ? mem_data_i : rs2_data_i;
      end
      AMO_MAX: begin
        amo_res32 = (mem32_s > rs2_32_s) ? mem32_s : rs2_32_s;
        amo_res64 = ($signed(mem_data_i) > $signed(rs2_data_i)) ? mem_data_i : rs2_data_i;
      end
      AMO_MINU: begin
        amo_res32 = (mem32_u < rs2_32_u) ? mem32_u : rs2_32_u;
        amo_res64 = (mem_data_i < rs2_data_i) ? mem_data_i : rs2_data_i;
      end
      AMO_MAXU: begin
        amo_res32 = (mem32_u > rs2_32_u) ? mem32_u : rs2_32_u;
        amo_res64 = (mem_data_i > rs2_data_i) ? mem_data_i : rs2_data_i;
      end
      default: begin
        amo_res32 = rs2_32_u;
        amo_res64 = rs2_data_i;
      end
    endcase
  end

  assign amo_result_o = is_word_i ? {{32{amo_res32[31]}}, amo_res32} : amo_res64;

  // --------------------------------------------------------------------------
  // LR/SC Reservation Set Monitor
  // Cache line aligned granularity: address bits [XLEN-1:6] (64-byte lines)
  // --------------------------------------------------------------------------
  logic             res_valid_q;
  logic [XLEN-1:6]  res_tag_q;

  wire match_sc  = res_valid_q && (res_tag_q == sc_addr_i[XLEN-1:6]);
  wire match_inv = res_valid_q && (res_tag_q == inv_addr_i[XLEN-1:6]);

  assign sc_success_o = match_sc;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      res_valid_q <= 1'b0;
      res_tag_q   <= '0;
    end else begin
      if (lr_valid_i) begin
        res_valid_q <= 1'b1;
        res_tag_q   <= lr_addr_i[XLEN-1:6];
      end else if (sc_valid_i || (inv_valid_i && match_inv)) begin
        res_valid_q <= 1'b0;
      end
    end
  end

endmodule : moon_amo

`endif // MOON_AMO_SV
