// APB programmed, single-master SPI controller (8-bit transfers, modes 0-3).
`ifndef MOON_SPI_SV
`define MOON_SPI_SV
`include "axi_pkg.sv"

module moon_spi import axi_pkg::*; #(
  parameter logic [31:0] BASE_ADDR = 32'h1000_6000
)(
  input logic clk_i, rst_ni,
  input apb_req_t req_i,
  output apb_resp_t resp_o,
  input logic miso_i,
  output logic mosi_o, sck_o, cs_no
);
  localparam logic [7:0] REG_CTRL=8'h00, REG_DIV=8'h04,
                         REG_TXRX=8'h08, REG_STATUS=8'h0c;
  logic [31:0] ctrl_q;
  logic [15:0] div_q, div_cnt_q;
  logic [7:0] tx_q, rx_q;
  logic [3:0] bit_q;
  logic busy_q, sck_q;
  wire cpol = ctrl_q[1];
  wire cpha = ctrl_q[0];
  wire tick = div_cnt_q >= (div_q == 0 ? 16'd1 : div_q);
  wire start = req_i.sel && req_i.enable && req_i.write && req_i.addr[7:0] == REG_TXRX && !busy_q;
  assign mosi_o = tx_q[7];
  assign sck_o = busy_q ? sck_q : cpol;
  assign cs_no = !busy_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ctrl_q <= '0; div_q <= 16'd1; div_cnt_q <= '0;
      tx_q <= '0; rx_q <= '0; bit_q <= '0; busy_q <= 1'b0; sck_q <= 1'b0;
    end else begin
      if (req_i.sel && req_i.enable && req_i.write) begin
        case (req_i.addr[7:0])
          REG_CTRL: ctrl_q <= req_i.wdata;
          REG_DIV: div_q <= req_i.wdata[15:0];
          default: ;
        endcase
      end
      if (start) begin
        tx_q <= req_i.wdata[7:0]; rx_q <= '0; bit_q <= 4'd0;
        busy_q <= 1'b1; sck_q <= cpol; div_cnt_q <= '0;
      end else if (busy_q) begin
        if (tick) begin
          div_cnt_q <= '0;
          sck_q <= ~sck_q;
          // Sample on the edge opposite the idle level for CPHA=0,
          // and on the idle-level edge for CPHA=1.
          if ((sck_q == cpol) ^ cpha) begin
            rx_q <= {rx_q[6:0], miso_i};
            if (bit_q == 4'd7) busy_q <= 1'b0;
            else bit_q <= bit_q + 1'b1;
          end else begin
            tx_q <= {tx_q[6:0], 1'b0};
          end
        end else div_cnt_q <= div_cnt_q + 1'b1;
      end
    end
  end

  always_comb begin
    resp_o.ready = req_i.sel && req_i.enable;
    resp_o.slverr = 1'b0;
    resp_o.rdata = '0;
    case (req_i.addr[7:0])
      REG_CTRL: resp_o.rdata = ctrl_q;
      REG_DIV: resp_o.rdata = {16'b0, div_q};
      REG_TXRX: resp_o.rdata = {24'b0, rx_q};
      REG_STATUS: resp_o.rdata = {31'b0, busy_q};
      default: ;
    endcase
  end
endmodule
`endif
