// ============================================================================
// File: rtl/soc/periph/moon_periph_subsystem.sv
// Description: Peripheral Subsystem Block (Southbridge / Low-Speed I/O Macro)
//              integrating CLINT, PLIC, UART 16550, SPI Master, and I2C Master.
//              Organized as a dedicated macro partition for hierarchical ASIC synthesis.
// ============================================================================

`ifndef MOON_PERIPH_SUBSYSTEM_SV
`define MOON_PERIPH_SUBSYSTEM_SV

`include "axi_pkg.sv"
`include "moon_clint.sv"
`include "moon_plic.sv"
`include "moon_uart.sv"
`include "moon_spi.sv"
`include "moon_i2c.sv"

module moon_periph_subsystem
  import axi_pkg::*;
(
  input  logic clk_i,
  input  logic rst_ni,

  // --------------------------------------------------------------------------
  // APB Interfaces (from System Fabric)
  // --------------------------------------------------------------------------
  input  apb_req_t  clint_req_i,
  output apb_resp_t clint_resp_o,

  input  apb_req_t  plic_req_i,
  output apb_resp_t plic_resp_o,

  input  apb_req_t  uart_req_i,
  output apb_resp_t uart_resp_o,

  input  apb_req_t  spi_req_i,
  output apb_resp_t spi_resp_o,

  input  apb_req_t  i2c_req_i,
  output apb_resp_t i2c_resp_o,

  // --------------------------------------------------------------------------
  // Peripheral Signals (to/from I/O PHY)
  // --------------------------------------------------------------------------
  input  logic        uart_rx_i,
  output logic        uart_tx_o,

  input  logic        spi_miso_i,
  output logic        spi_mosi_o,
  output logic        spi_sck_o,
  output logic        spi_cs_no,

  input  logic        i2c_sda_i,
  output logic        i2c_scl_o,
  output logic        i2c_sda_o,
  output logic        i2c_sda_oe_o,

  input  logic [30:0] ext_irq_i,

  // --------------------------------------------------------------------------
  // Core Interrupt Outputs (to CPU Tile & PMU)
  // --------------------------------------------------------------------------
  output logic        timer_irq_o,
  output logic        software_irq_o,
  output logic        external_irq_o,
  output logic        uart_irq_o
);

  // --------------------------------------------------------------------------
  // P0: Core-Local Interruptor (CLINT)
  // --------------------------------------------------------------------------
  moon_clint u_clint (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .req_i          (clint_req_i),
    .resp_o         (clint_resp_o),
    .timer_irq_o    (timer_irq_o),
    .software_irq_o (software_irq_o)
  );

  // --------------------------------------------------------------------------
  // P1: Platform-Level Interrupt Controller (PLIC)
  // --------------------------------------------------------------------------
  logic internal_uart_irq;
  assign uart_irq_o = internal_uart_irq;

  wire [31:1] plic_irq_sources = {ext_irq_i, internal_uart_irq};

  moon_plic #(
    .NUM_SOURCES(31)
  ) u_plic (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .req_i          (plic_req_i),
    .resp_o         (plic_resp_o),
    .irq_sources_i  (plic_irq_sources),
    .external_irq_o (external_irq_o)
  );

  // --------------------------------------------------------------------------
  // P2: UART 16550 Controller
  // --------------------------------------------------------------------------
  moon_uart u_uart (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .req_i      (uart_req_i),
    .resp_o     (uart_resp_o),
    .uart_rx_i  (uart_rx_i),
    .uart_tx_o  (uart_tx_o),
    .uart_irq_o (internal_uart_irq)
  );

  // --------------------------------------------------------------------------
  // P5: SPI Master Controller
  // --------------------------------------------------------------------------
  moon_spi u_spi (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .req_i      (spi_req_i),
    .resp_o     (spi_resp_o),
    .miso_i     (spi_miso_i),
    .mosi_o     (spi_mosi_o),
    .sck_o      (spi_sck_o),
    .cs_no      (spi_cs_no)
  );

  // --------------------------------------------------------------------------
  // P6: I2C Master Controller
  // --------------------------------------------------------------------------
  moon_i2c u_i2c (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .req_i      (i2c_req_i),
    .resp_o     (i2c_resp_o),
    .sda_i      (i2c_sda_i),
    .scl_o      (i2c_scl_o),
    .sda_o      (i2c_sda_o),
    .sda_oe_o   (i2c_sda_oe_o)
  );

endmodule : moon_periph_subsystem

`endif // MOON_PERIPH_SUBSYSTEM_SV
