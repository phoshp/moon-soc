// ============================================================================
// File: rtl/soc/periph/moon_uart.sv
// Description: 16550-compatible UART with APB4 Slave interface, TX/RX buffers,
//              programmable baud rate generator, and simulation character sink.
// ============================================================================

`ifndef MOON_UART_SV
`define MOON_UART_SV

`include "axi_pkg.sv"

module moon_uart
  import axi_pkg::*;
#(
  parameter logic [31:0] BASE_ADDR = 32'h1000_0000
)(
  input  logic clk_i,
  input  logic rst_ni,

  // APB4 Slave Interface
  input  apb_req_t  req_i,
  output apb_resp_t resp_o,

  // External UART Serial Pins
  input  logic      uart_rx_i,
  output logic      uart_tx_o,

  // Interrupt Line to PLIC
  output logic      uart_irq_o
);

  // 16550 Standard Registers
  logic [7:0] dll_q, dlm_q;
  logic [7:0] ier_q;
  logic [7:0] fcr_q;
  logic [7:0] lcr_q;
  logic [7:0] mcr_q;
  logic [7:0] scr_q;
  logic [7:0] rx_buf_q;
  logic       rx_valid_q;

  // TX Shift Register and Baud Generator
  logic [15:0] baud_cnt_q;
  logic [3:0]  tx_bit_idx_q;
  logic [9:0]  tx_shift_q;
  logic        tx_busy_q;

  wire dlab = lcr_q[7];
  wire [15:0] divisor = {dlm_q, dll_q};

  // Line Status Register (LSR)
  // bit 0: DR (Data Ready)
  // bit 5: THRE (Transmitter Holding Register Empty)
  // bit 6: TEMT (Transmitter Empty)
  wire [7:0] lsr_val = {1'b0, !tx_busy_q, !tx_busy_q, 4'b0, rx_valid_q};

  // Interrupt Evaluation (IER bit 0 = RX data avail, bit 1 = TX empty)
  assign uart_irq_o = (ier_q[0] && rx_valid_q) || (ier_q[1] && !tx_busy_q);

  assign uart_tx_o = tx_shift_q[0];

  // Address offset within 4 KB block
  wire [7:0] offset = req_i.addr[7:0];

  // APB Write Handling
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dll_q         <= 8'd1;
      dlm_q         <= 8'd0;
      ier_q         <= 8'd0;
      fcr_q         <= 8'd0;
      lcr_q         <= 8'd0;
      mcr_q         <= 8'd0;
      scr_q         <= 8'd0;
      tx_busy_q     <= 1'b0;
      tx_shift_q    <= 10'h3FF;
      tx_bit_idx_q  <= 4'd0;
      baud_cnt_q    <= 16'd0;
      rx_buf_q      <= 8'd0;
      rx_valid_q    <= 1'b0;
    end else begin
      // Transmit bit shift engine
      if (tx_busy_q) begin
        if (baud_cnt_q >= (divisor == 0 ? 16'd1 : divisor)) begin
          baud_cnt_q <= 16'd0;
          tx_shift_q <= {1'b1, tx_shift_q[9:1]};
          if (tx_bit_idx_q == 4'd9) begin
            tx_busy_q    <= 1'b0;
            tx_bit_idx_q <= 4'd0;
          end else begin
            tx_bit_idx_q <= tx_bit_idx_q + 4'd1;
          end
        end else begin
          baud_cnt_q <= baud_cnt_q + 16'd1;
        end
      end

      // APB Register Writes
      if (req_i.sel && req_i.enable && req_i.write) begin
        case (offset)
          8'h00: begin
            if (dlab) begin
              dll_q <= req_i.wdata[7:0];
            end else begin
              // Write to THR: initiate serial transmission
              tx_shift_q   <= {1'b1, req_i.wdata[7:0], 1'b0}; // Stop bit (1), Data (8), Start bit (0)
              tx_busy_q    <= 1'b1;
              tx_bit_idx_q <= 4'd0;
              baud_cnt_q   <= 16'd0;
              // Immediate simulation character logging
              $write("%c", req_i.wdata[7:0]);
            end
          end
          8'h04: begin
            if (dlab) dlm_q <= req_i.wdata[7:0];
            else      ier_q <= req_i.wdata[7:0];
          end
          8'h08: fcr_q <= req_i.wdata[7:0];
          8'h0C: lcr_q <= req_i.wdata[7:0];
          8'h10: mcr_q <= req_i.wdata[7:0];
          8'h1C: scr_q <= req_i.wdata[7:0];
          default: ;
        endcase
      end

      // Reading RX buffer clears Data Ready
      if (req_i.sel && req_i.enable && !req_i.write && (offset == 8'h00) && !dlab) begin
        rx_valid_q <= 1'b0;
      end
    end
  end

  // APB Read Handling
  logic [31:0] rdata;
  always_comb begin
    rdata = 32'h0;
    case (offset)
      8'h00: rdata = dlab ? {24'b0, dll_q} : {24'b0, rx_buf_q};
      8'h04: rdata = dlab ? {24'b0, dlm_q} : {24'b0, ier_q};
      8'h08: rdata = {24'b0, 4'b0000, 4'b0001}; // IIR: No interrupt pending
      8'h0C: rdata = {24'b0, lcr_q};
      8'h10: rdata = {24'b0, mcr_q};
      8'h14: rdata = {24'b0, lsr_val};
      8'h18: rdata = 32'h0; // MSR
      8'h1C: rdata = {24'b0, scr_q};
      default: rdata = 32'h0;
    endcase
  end

  assign resp_o.ready  = req_i.sel && req_i.enable;
  assign resp_o.rdata  = rdata;
  assign resp_o.slverr = 1'b0;

endmodule : moon_uart

`endif // MOON_UART_SV
