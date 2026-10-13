// ============================================================================
// File: rtl/soc/interconnect/axi_pkg.sv
// Description: Global types, enumerations, and structs for AXI4 & APB4
//              SoC Interconnect Subsystem.
// ============================================================================

`ifndef AXI_PKG_SV
`define AXI_PKG_SV

package axi_pkg;

  // --------------------------------------------------------------------------
  // AXI4 Configuration Constants
  // --------------------------------------------------------------------------
  localparam int AXI_ADDR_WIDTH = 64;
  localparam int AXI_DATA_WIDTH = 64;
  localparam int AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;
  localparam int AXI_ID_WIDTH   = 4;

  // APB4 Configuration Constants
  localparam int APB_ADDR_WIDTH = 32;
  localparam int APB_DATA_WIDTH = 32;
  localparam int APB_STRB_WIDTH = APB_DATA_WIDTH / 8;

  // --------------------------------------------------------------------------
  // AXI4 Burst Types (axburst[1:0])
  // --------------------------------------------------------------------------
  typedef enum logic [1:0] {
    AXI_BURST_FIXED = 2'b00,
    AXI_BURST_INCR  = 2'b01,
    AXI_BURST_WRAP  = 2'b10,
    AXI_BURST_RESV  = 2'b11
  } axi_burst_e;

  // --------------------------------------------------------------------------
  // AXI4 Response Types (rresp[1:0], bresp[1:0])
  // --------------------------------------------------------------------------
  typedef enum logic [1:0] {
    AXI_RESP_OKAY   = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11
  } axi_resp_e;

  // --------------------------------------------------------------------------
  // AXI4 Master / Slave Channel Bundles (for clean port mapping)
  // --------------------------------------------------------------------------
  // Read Address Channel (AR)
  typedef struct packed {
    logic [AXI_ID_WIDTH-1:0]   id;
    logic [AXI_ADDR_WIDTH-1:0] addr;
    logic [7:0]                len;
    logic [2:0]                size;
    logic [1:0]                burst;
    logic [2:0]                prot;
    logic [3:0]                qos;
    logic                      valid;
  } axi_ar_t;

  // Read Data Channel (R)
  typedef struct packed {
    logic [AXI_ID_WIDTH-1:0]   id;
    logic [AXI_DATA_WIDTH-1:0] data;
    logic [1:0]                resp;
    logic                      last;
    logic                      valid;
  } axi_r_t;

  // Write Address Channel (AW)
  typedef struct packed {
    logic [AXI_ID_WIDTH-1:0]   id;
    logic [AXI_ADDR_WIDTH-1:0] addr;
    logic [7:0]                len;
    logic [2:0]                size;
    logic [1:0]                burst;
    logic [2:0]                prot;
    logic [3:0]                qos;
    logic                      valid;
  } axi_aw_t;

  // Write Data Channel (W)
  typedef struct packed {
    logic [AXI_DATA_WIDTH-1:0] data;
    logic [AXI_STRB_WIDTH-1:0] strb;
    logic                      last;
    logic                      valid;
  } axi_w_t;

  // Write Response Channel (B)
  typedef struct packed {
    logic [AXI_ID_WIDTH-1:0]   id;
    logic [1:0]                resp;
    logic                      valid;
  } axi_b_t;

  // --------------------------------------------------------------------------
  // APB4 Signal Bundle
  // --------------------------------------------------------------------------
  typedef struct packed {
    logic [APB_ADDR_WIDTH-1:0] addr;
    logic [2:0]                prot;
    logic                      sel;
    logic                      enable;
    logic                      write;
    logic [APB_DATA_WIDTH-1:0] wdata;
    logic [APB_STRB_WIDTH-1:0] strb;
  } apb_req_t;

  typedef struct packed {
    logic                      ready;
    logic [APB_DATA_WIDTH-1:0] rdata;
    logic                      slverr;
  } apb_resp_t;

endpackage : axi_pkg

`endif // AXI_PKG_SV
