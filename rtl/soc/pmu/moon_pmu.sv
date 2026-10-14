// ============================================================================
// File: rtl/soc/pmu/moon_pmu.sv
// Description: Power Management Unit (PMU) for Moon-SoC.
//              Manages RUN, WFI clock-gating, SLEEP, and DEEP-SLEEP states,
//              with wake-up interrupt routing and APB control interface.
// ============================================================================

`ifndef MOON_PMU_SV
`define MOON_PMU_SV

`include "axi_pkg.sv"

module moon_pmu
  import axi_pkg::*;
#(
  parameter logic [31:0] BASE_ADDR = 32'h1000_5080
)(
  input  logic clk_aon_i,     // Always-on clock
  input  logic rst_aon_ni,    // Always-on reset

  // APB4 Slave Interface
  input  apb_req_t  req_i,
  output apb_resp_t resp_o,

  // Hardware Status Inputs from Core & Interrupt Subsystems
  input  logic wfi_i,         // Pulse/level: Core executed WFI
  input  logic irq_pending_i, // Active interrupt pending (CLINT / PLIC)

  // Power & Clock Control Requests to CRG
  output logic core_clk_gate_req_o,
  output logic peri_clk_gate_req_o,
  output logic pll_pwr_down_req_o,
  output logic [1:0] current_state_o
);

  typedef enum logic [1:0] {
    STATE_RUN        = 2'd0,
    STATE_WFI        = 2'd1,
    STATE_SLEEP      = 2'd2,
    STATE_DEEP_SLEEP = 2'd3
  } pmu_state_e;

  pmu_state_e state_q, state_d;

  // Registers
  logic [1:0] sleep_target_q;   // 2: Sleep, 3: Deep Sleep
  logic       sleep_req_q;      // Software trigger
  logic       irq_wake_en_q;    // Enable interrupt wake-up

  assign current_state_o = state_q;

  // PMU State Machine
  always_ff @(posedge clk_aon_i or negedge rst_aon_ni) begin
    if (!rst_aon_ni) begin
      state_q <= STATE_RUN;
    end else begin
      state_q <= state_d;
    end
  end

  always_comb begin
    state_d               = state_q;
    core_clk_gate_req_o   = 1'b0;
    peri_clk_gate_req_o   = 1'b0;
    pll_pwr_down_req_o    = 1'b0;

    case (state_q)
      STATE_RUN: begin
        if (sleep_req_q) begin
          state_d = (sleep_target_q == 2'd3) ? STATE_DEEP_SLEEP : STATE_SLEEP;
        end else if (wfi_i && !irq_pending_i) begin
          state_d = STATE_WFI;
        end
      end

      STATE_WFI: begin
        core_clk_gate_req_o = 1'b1; // Gate core clock only
        if (irq_pending_i) begin
          state_d = STATE_RUN;      // Immediate wake-up on unmasked interrupt
        end
      end

      STATE_SLEEP: begin
        core_clk_gate_req_o = 1'b1;
        peri_clk_gate_req_o = 1'b1;
        if (irq_pending_i && irq_wake_en_q) begin
          state_d = STATE_RUN;
        end
      end

      STATE_DEEP_SLEEP: begin
        core_clk_gate_req_o = 1'b1;
        peri_clk_gate_req_o = 1'b1;
        pll_pwr_down_req_o  = 1'b1;
        if (irq_pending_i && irq_wake_en_q) begin
          state_d = STATE_RUN;
        end
      end

      default: state_d = STATE_RUN;
    endcase
  end

  // APB Read/Write
  wire [6:0] offset = req_i.addr[6:0];

  always_ff @(posedge clk_aon_i or negedge rst_aon_ni) begin
    if (!rst_aon_ni) begin
      sleep_target_q <= 2'd2;
      sleep_req_q    <= 1'b0;
      irq_wake_en_q  <= 1'b1;
    end else begin
      sleep_req_q <= 1'b0; // Auto-clear trigger
      if (req_i.sel && req_i.enable && req_i.write) begin
        case (offset)
          7'h00: begin // PMU_CTRL (offset 0x80 within CRG/PMU space)
            sleep_target_q <= req_i.wdata[1:0];
            sleep_req_q    <= req_i.wdata[2];
            irq_wake_en_q  <= req_i.wdata[3];
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
        7'h00: resp_o.rdata = {28'b0, irq_wake_en_q, 1'b0, sleep_target_q};
        7'h04: resp_o.rdata = {30'b0, state_q}; // PMU_STATUS
        default: resp_o.rdata = 32'h0;
      endcase
    end
  end

endmodule : moon_pmu

`endif // MOON_PMU_SV
