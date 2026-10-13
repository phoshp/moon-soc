// ============================================================================
// File: rtl/soc/periph/moon_plic.sv
// Description: Standard RISC-V Platform-Level Interrupt Controller (PLIC)
//              supporting up to 31 external interrupt sources and 1 Hart target.
// ============================================================================

`ifndef MOON_PLIC_SV
`define MOON_PLIC_SV

`include "axi_pkg.sv"

module moon_plic
  import axi_pkg::*;
#(
  parameter int NUM_SOURCES = 31,
  parameter logic [31:0] BASE_ADDR = 32'h0C00_0000
)(
  input  logic clk_i,
  input  logic rst_ni,

  // APB4 Slave Interface
  input  apb_req_t  req_i,
  output apb_resp_t resp_o,

  // External Peripheral Interrupt Lines (sources 1..NUM_SOURCES)
  input  logic [NUM_SOURCES:1] irq_sources_i,

  // Interrupt Output to CPU Core (MEIP)
  output logic      external_irq_o
);

  // PLIC Registers
  logic [2:0]  priorities_q [1:NUM_SOURCES];
  logic [31:0] enable_q;
  logic [2:0]  threshold_q;
  logic [31:0] pending_q;
  logic [4:0]  claimed_id_q;

  // Track pending interrupts from edge/level sources
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pending_q <= '0;
    end else begin
      for (int i = 1; i <= NUM_SOURCES; i++) begin
        if (irq_sources_i[i]) begin
          pending_q[i] <= 1'b1;
        end else if (claimed_id_q == 5'(i)) begin
          pending_q[i] <= 1'b0;
        end
      end
    end
  end

  // Arbitration & Best Target Evaluation
  logic [4:0] best_id;
  logic [2:0] max_priority;

  always_comb begin
    best_id      = 5'd0;
    max_priority = threshold_q;
    for (int i = 1; i <= NUM_SOURCES; i++) begin
      if (pending_q[i] && enable_q[i]) begin
        if (priorities_q[i] > max_priority) begin
          max_priority = priorities_q[i];
          best_id      = 5'(i);
        end
      end
    end
    external_irq_o = (best_id != 5'd0);
  end

  // APB Read/Write
  wire [23:0] offset = req_i.addr[23:0];
  wire [4:0]  src_idx = offset[6:2];
  logic [31:0] rdata;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int i = 1; i <= NUM_SOURCES; i++) priorities_q[i] <= 3'd1;
      enable_q     <= '0;
      threshold_q  <= 3'd0;
      claimed_id_q <= 5'd0;
    end else begin
      claimed_id_q <= 5'd0; // Auto-clear claim trigger

      if (req_i.sel && req_i.enable) begin
        if (req_i.write) begin
          // Writes
          if (offset >= 24'h000004 && offset <= 24'h00007C) begin
            if (src_idx != 5'd0 && int'(src_idx) <= NUM_SOURCES) begin
              priorities_q[src_idx] <= req_i.wdata[2:0];
            end
          end else if (offset == 24'h002000) begin
            enable_q <= req_i.wdata;
          end else if (offset == 24'h200000) begin
            threshold_q <= req_i.wdata[2:0];
          end else if (offset == 24'h200004) begin
            // Complete written by software: clear completion
          end
        end else begin
          // Reads
          if (offset == 24'h200004) begin
            // Claim read by software: acknowledge and claim current best ID
            claimed_id_q <= best_id;
          end
        end
      end
    end
  end

  always_comb begin
    rdata = 32'h0;
    if (offset >= 24'h000004 && offset <= 24'h00007C) begin
      if (src_idx != 5'd0 && int'(src_idx) <= NUM_SOURCES) begin
        rdata = {29'b0, priorities_q[src_idx]};
      end
    end else if (offset == 24'h001000) begin
      rdata = pending_q;
    end else if (offset == 24'h002000) begin
      rdata = enable_q;
    end else if (offset == 24'h200000) begin
      rdata = {29'b0, threshold_q};
    end else if (offset == 24'h200004) begin
      rdata = {27'b0, best_id};
    end
  end

  assign resp_o.ready  = req_i.sel && req_i.enable;
  assign resp_o.rdata  = rdata;
  assign resp_o.slverr = 1'b0;

endmodule : moon_plic

`endif // MOON_PLIC_SV
