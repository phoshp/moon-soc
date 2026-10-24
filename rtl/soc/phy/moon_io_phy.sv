// ============================================================================
// File: rtl/soc/phy/moon_io_phy.sv
// Description: Peripheral I/O PHY & Pad Ring Block handling chip I/O boundaries:
//              - UART, SPI, I2C pad drivers and tri-state control
//              - External interrupt synchronization and glitch filtering
//              - Parameterizable input synchronizers for ASIC pad cell integration
//              Organized as a dedicated macro partition for hierarchical ASIC synthesis.
// ============================================================================

`ifndef MOON_IO_PHY_SV
`define MOON_IO_PHY_SV

module moon_io_phy #(
  parameter bit ENABLE_INPUT_SYNC = 1'b0 // 1: 2-stage sync for ASIC pad cells, 0: direct for zero-latency RTL sim
)(
  input  logic clk_i,
  input  logic rst_ni,

  // --------------------------------------------------------------------------
  // Core-Side Peripheral Interfaces (to/from moon_periph_subsystem)
  // --------------------------------------------------------------------------
  output logic        core_uart_rx_o,
  input  logic        core_uart_tx_i,

  output logic        core_spi_miso_o,
  input  logic        core_spi_mosi_i,
  input  logic        core_spi_sck_i,
  input  logic        core_spi_cs_ni,

  output logic        core_i2c_sda_o,
  input  logic        core_i2c_scl_i,
  input  logic        core_i2c_sda_i,
  input  logic        core_i2c_sda_oe_i,

  output logic [29:0] core_ext_irq_o,

  // --------------------------------------------------------------------------
  // Pad-Side External Chip Pins (to/from Chip Pads / Board)
  // --------------------------------------------------------------------------
  input  logic        pad_uart_rx_i,
  output logic        pad_uart_tx_o,

  input  logic        pad_spi_miso_i,
  output logic        pad_spi_mosi_o,
  output logic        pad_spi_sck_o,
  output logic        pad_spi_cs_no,

  input  logic        pad_i2c_sda_i,
  output logic        pad_i2c_scl_o,
  output logic        pad_i2c_sda_o,
  output logic        pad_i2c_sda_oe_o,

  input  logic [29:0] pad_ext_irq_i
);

  // --------------------------------------------------------------------------
  // Output Drivers (core -> pad)
  // --------------------------------------------------------------------------
  assign pad_uart_tx_o    = core_uart_tx_i;
  assign pad_spi_mosi_o   = core_spi_mosi_i;
  assign pad_spi_sck_o    = core_spi_sck_i;
  assign pad_spi_cs_no    = core_spi_cs_ni;
  assign pad_i2c_scl_o    = core_i2c_scl_i;
  assign pad_i2c_sda_o    = core_i2c_sda_i;
  assign pad_i2c_sda_oe_o = core_i2c_sda_oe_i;

  // --------------------------------------------------------------------------
  // Input Receivers & Synchronizers (pad -> core)
  // --------------------------------------------------------------------------
  generate
    if (ENABLE_INPUT_SYNC) begin : gen_sync
      // 2-stage synchronizers for asynchronous external signals
      logic [1:0]  uart_rx_q;
      logic [1:0]  spi_miso_q;
      logic [1:0]  i2c_sda_q;
      logic [29:0] ext_irq_q1, ext_irq_q2;

      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
          uart_rx_q   <= 2'b11;
          spi_miso_q  <= 2'b00;
          i2c_sda_q   <= 2'b11;
          ext_irq_q1  <= '0;
          ext_irq_q2  <= '0;
        end else begin
          uart_rx_q   <= {uart_rx_q[0],  pad_uart_rx_i};
          spi_miso_q  <= {spi_miso_q[0], pad_spi_miso_i};
          i2c_sda_q   <= {i2c_sda_q[0],  pad_i2c_sda_i};
          ext_irq_q1  <= pad_ext_irq_i;
          ext_irq_q2  <= ext_irq_q1;
        end
      end

      assign core_uart_rx_o  = uart_rx_q[1];
      assign core_spi_miso_o = spi_miso_q[1];
      assign core_i2c_sda_o  = i2c_sda_q[1];
      assign core_ext_irq_o  = ext_irq_q2;
    end else begin : gen_direct
      // Direct pass-through for simulation and timing verification
      assign core_uart_rx_o  = pad_uart_rx_i;
      assign core_spi_miso_o = pad_spi_miso_i;
      assign core_i2c_sda_o  = pad_i2c_sda_i;
      assign core_ext_irq_o  = pad_ext_irq_i;

      // Tie off unused clock/reset in direct pass-through mode to avoid lint warnings
      logic _unused;
      assign _unused = &{1'b0, clk_i, rst_ni, 1'b0};
    end
  endgenerate

endmodule : moon_io_phy

`endif // MOON_IO_PHY_SV
