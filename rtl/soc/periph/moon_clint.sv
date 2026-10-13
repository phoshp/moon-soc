// ============================================================================
// File: rtl/soc/periph/moon_clint.sv
// Description: RISC-V Core-Local Interruptor (CLINT) providing mtime counter,
//              mtimecmp timer comparator, and msip software interrupt.
// ============================================================================

`ifndef MOON_CLINT_SV
`define MOON_CLINT_SV

`include "axi_pkg.sv"

module moon_clint
  import axi_pkg::*;
#(
  parameter logic [31:0] BASE_ADDR = 32'h0200_0000
)(
  input  logic clk_i,
  input  logic rst_ni,

  // APB4 Slave Interface
  input  apb_req_t  req_i,
  output apb_resp_t resp_o,

  // Hardware Interrupt Outputs to CPU Core
  output logic      timer_irq_o,
  output logic      software_irq_o
);

  // CLINT Registers
  logic [31:0] msip_q;
  logic [63:0] mtimecmp_q;
  logic [63:0] mtime_q;

  // Free-running 64-bit hardware timer
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mtime_q <= '0;
    end else begin
      mtime_q <= mtime_q + 64'd1;
    end
  end

  // Interrupt Evaluation
  assign timer_irq_o    = (mtime_q >= mtimecmp_q);
  assign software_irq_o = msip_q[0];

  // Address offset within 64 KB block
  wire [15:0] offset = req_i.addr[15:0];

  // APB Read and Write logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      msip_q     <= '0;
      mtimecmp_q <= 64'hFFFF_FFFF_FFFF_FFFF;
    end else if (req_i.sel && req_i.enable && req_i.write) begin
      case (offset)
        16'h0000: msip_q          <= req_i.wdata;
        16'h4000: mtimecmp_q[31:0]<= req_i.wdata;
        16'h4004: mtimecmp_q[63:32]<= req_i.wdata;
        default: ;
      endcase
    end
  end

  always_comb begin
    resp_o.ready  = req_i.sel && req_i.enable;
    resp_o.slverr = 1'b0;
    resp_o.rdata  = '0;

    if (req_i.sel) begin
      case (offset)
        16'h0000: resp_o.rdata = msip_q;
        16'h4000: resp_o.rdata = mtimecmp_q[31:0];
        16'h4004: resp_o.rdata = mtimecmp_q[63:32];
        16'hBFF8: resp_o.rdata = mtime_q[31:0];
        16'hBFFC: resp_o.rdata = mtime_q[63:32];
        default:  resp_o.rdata = 32'h0;
      endcase
    end
  end

endmodule : moon_clint

`endif // MOON_CLINT_SV
