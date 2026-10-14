// ============================================================================
// File: rtl/soc/interconnect/apb_crossbar.sv
// Description: Demultiplexes APB4 transactions from bridge to peripherals:
//              P0: CLINT (0x0200_0000)
//              P1: PLIC  (0x0C00_0000)
//              P2: UART  (0x1000_0000)
//              P3: CRG   (0x1000_5000)
//              P4: PMU   (0x1000_5080), P5: SPI, P6: I2C
// ============================================================================

`ifndef APB_CROSSBAR_SV
`define APB_CROSSBAR_SV

`include "axi_pkg.sv"

module apb_crossbar
  import axi_pkg::*;
#(
  parameter int NUM_PERIPHS = 7
)(
  // Master input (from axi_to_apb_bridge)
  input  apb_req_t               m_req_i,
  output apb_resp_t              m_resp_o,

  // Peripherals outputs/inputs
  output apb_req_t  [NUM_PERIPHS-1:0] p_req_o,
  input  apb_resp_t [NUM_PERIPHS-1:0] p_resp_i
);

  // Address decoding
  int periph_sel;
  always_comb begin
    if (m_req_i.addr >= 32'h0200_0000 && m_req_i.addr <= 32'h0200_FFFF) begin
      periph_sel = 0; // CLINT
    end else if (m_req_i.addr >= 32'h0C00_0000 && m_req_i.addr <= 32'h0FFF_FFFF) begin
      periph_sel = 1; // PLIC
    end else if (m_req_i.addr >= 32'h1000_0000 && m_req_i.addr <= 32'h1000_0FFF) begin
      periph_sel = 2; // UART
    end else if (m_req_i.addr >= 32'h1000_5000 && m_req_i.addr <= 32'h1000_507F) begin
      periph_sel = 3; // CRG
    end else if (m_req_i.addr >= 32'h1000_5080 && m_req_i.addr <= 32'h1000_50FF) begin
      periph_sel = 4; // PMU
    end else if (m_req_i.addr >= 32'h1000_6000 && m_req_i.addr <= 32'h1000_6FFF) begin
      periph_sel = 5; // SPI
    end else if (m_req_i.addr >= 32'h1000_7000 && m_req_i.addr <= 32'h1000_7FFF) begin
      periph_sel = 6; // I2C
    end else begin
      periph_sel = -1; // Unmapped
    end
  end

  always_comb begin
    for (int p = 0; p < NUM_PERIPHS; p++) begin
      p_req_o[p]        = m_req_i;
      p_req_o[p].sel    = (m_req_i.sel && (periph_sel == p));
      p_req_o[p].enable = (m_req_i.enable && (periph_sel == p));
    end

    if (periph_sel >= 0 && periph_sel < NUM_PERIPHS) begin
      m_resp_o = p_resp_i[periph_sel];
    end else if (m_req_i.sel) begin
      // Unmapped access: acknowledge with error/zero
      m_resp_o.ready  = 1'b1;
      m_resp_o.rdata  = 32'hDEAD_BEEF;
      m_resp_o.slverr = 1'b1;
    end else begin
      m_resp_o = '0;
    end
  end

endmodule : apb_crossbar

`endif // APB_CROSSBAR_SV
