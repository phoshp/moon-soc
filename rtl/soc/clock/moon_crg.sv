// ============================================================================
// File: rtl/soc/clock/moon_crg.sv
// Description: Clock & Reset Generator (CRG) for Moon-SoC integrating PLL model,
//              glitchless clock multiplexer, ICG clock gating cells, and APB registers.
// ============================================================================

`ifndef MOON_CRG_SV
`define MOON_CRG_SV

`include "axi_pkg.sv"
`include "cg_cell.sv"
`include "clk_mux_glitchless.sv"
`include "moon_pll_model.sv"

module moon_crg
  import axi_pkg::*;
(
  input  logic ref_clk_i,        // External reference clock
  input  logic rst_aon_ni,       // Always-on domain reset

  // APB4 Slave Interface
  input  apb_req_t  req_i,
  output apb_resp_t resp_o,

  // Hardware PMU Requests
  input  logic core_clk_gate_i,  // 1: Gate core clock (from PMU / WFI)
  input  logic peri_clk_gate_i,  // 1: Gate peripheral clock (from PMU)
  input  logic pll_pwr_down_i,   // 1: Power down PLL (deep sleep)

  // Generated Domain Clocks
  output logic clk_aon_o,        // Always-on clock (ungated reference clock)
  output logic clk_core_o,       // Dynamic gated core clock
  output logic clk_peri_o,       // Dynamic gated peripheral clock
  output logic clk_mem_o,        // Gated memory clock

  // Reset Request to Reset Controller
  output logic sw_rst_req_o
);

  assign clk_aon_o = ref_clk_i;

  // --------------------------------------------------------------------------
  // CRG Control Registers
  // --------------------------------------------------------------------------
  logic       pll_en_q;
  logic       pll_bypass_q;
  logic [3:0] div_core_q;
  logic [3:0] div_peri_q;
  logic [3:0] div_mem_q;

  logic       core_clk_en_q;
  logic       peri_clk_en_q;
  logic       mem_clk_en_q;

  logic       sw_rst_req_q;

  assign sw_rst_req_o = sw_rst_req_q;

  // --------------------------------------------------------------------------
  // PLL Model Instantiation
  // --------------------------------------------------------------------------
  logic pll_locked;
  logic clk_core_raw;
  logic clk_peri_raw;
  logic clk_mem_raw;

  wire pll_active = pll_en_q && (!pll_pwr_down_i);

  moon_pll_model #(
    .LOCK_CYCLES(16)
  ) u_pll (
    .ref_clk_i    (ref_clk_i),
    .rst_ni       (rst_aon_ni),
    .pll_enable_i (pll_active),
    .pll_bypass_i (pll_bypass_q),
    .div_core_i   (div_core_q),
    .div_peri_i   (div_peri_q),
    .div_mem_i    (div_mem_q),
    .pll_locked_o (pll_locked),
    .clk_core_o   (clk_core_raw),
    .clk_peri_o   (clk_peri_raw),
    .clk_mem_o    (clk_mem_raw)
  );

  // --------------------------------------------------------------------------
  // Glitchless Clock Multiplexer (Select Ref Clk or PLL)
  // --------------------------------------------------------------------------
  logic clk_core_muxed;

  clk_mux_glitchless u_mux_core (
    .clk_0_i   (ref_clk_i),
    .clk_1_i   (clk_core_raw),
    .sel_i     (pll_locked && !pll_bypass_q),
    .rst_ni    (rst_aon_ni),
    .clk_out_o (clk_core_muxed)
  );

  // --------------------------------------------------------------------------
  // Integrated Clock Gating Cells
  // --------------------------------------------------------------------------
  wire core_gate_en = core_clk_en_q && (!core_clk_gate_i);
  wire peri_gate_en = peri_clk_en_q && (!peri_clk_gate_i);
  wire mem_gate_en  = mem_clk_en_q;

  cg_cell u_cg_core (
    .clk_i       (clk_core_muxed),
    .enable_i    (core_gate_en),
    .test_mode_i (1'b0),
    .clk_gated_o (clk_core_o)
  );

  cg_cell u_cg_peri (
    .clk_i       (clk_peri_raw),
    .enable_i    (peri_gate_en),
    .test_mode_i (1'b0),
    .clk_gated_o (clk_peri_o)
  );

  cg_cell u_cg_mem (
    .clk_i       (clk_mem_raw),
    .enable_i    (mem_gate_en),
    .test_mode_i (1'b0),
    .clk_gated_o (clk_mem_o)
  );

  // --------------------------------------------------------------------------
  // APB Read/Write
  // --------------------------------------------------------------------------
  wire [7:0] offset = req_i.addr[7:0];

  always_ff @(posedge clk_aon_o or negedge rst_aon_ni) begin
    if (!rst_aon_ni) begin
      pll_en_q      <= 1'b1;
      pll_bypass_q  <= 1'b1; // Default to bypass for safe start
      div_core_q    <= 4'd0;
      div_peri_q    <= 4'd0;
      div_mem_q     <= 4'd0;
      core_clk_en_q <= 1'b1;
      peri_clk_en_q <= 1'b1;
      mem_clk_en_q  <= 1'b1;
      sw_rst_req_q  <= 1'b0;
    end else begin
      sw_rst_req_q <= 1'b0; // Auto-clear reset trigger pulse
      if (req_i.sel && req_i.enable && req_i.write) begin
        case (offset)
          8'h00: begin // CRG_PLL_CTRL
            pll_en_q     <= req_i.wdata[0];
            pll_bypass_q <= req_i.wdata[1];
            div_core_q   <= req_i.wdata[7:4];
            div_peri_q   <= req_i.wdata[11:8];
            div_mem_q    <= req_i.wdata[15:12];
          end
          8'h08: begin // CRG_CLK_GATE
            core_clk_en_q <= req_i.wdata[0];
            peri_clk_en_q <= req_i.wdata[1];
            mem_clk_en_q  <= req_i.wdata[2];
          end
          8'h0C: begin // CRG_RESET_REQ
            sw_rst_req_q  <= req_i.wdata[0];
          end
          default: ;
        endcase
      end
    end
  end

  always_comb begin
    resp_o.ready  = req_i.sel && req_i.enable;
    resp_o.slverr = 1'b0;
    resp_o.rdata  = '0;

    if (req_i.sel) begin
      case (offset)
        8'h00: resp_o.rdata = {16'b0, div_mem_q, div_peri_q, div_core_q, 2'b0, pll_bypass_q, pll_en_q};
        8'h04: resp_o.rdata = {31'b0, pll_locked}; // CRG_PLL_STATUS
        8'h08: resp_o.rdata = {29'b0, mem_clk_en_q, peri_clk_en_q, core_clk_en_q};
        8'h0C: resp_o.rdata = {31'b0, sw_rst_req_q};
        default: resp_o.rdata = 32'h0;
      endcase
    end
  end

  // Tie off unused bus request bits to satisfy lint
  wire _unused_ok = &{1'b0, req_i.addr[31:8], req_i.prot, req_i.strb, 1'b0};

endmodule : moon_crg

`endif // MOON_CRG_SV
