// ============================================================================
// File: rtl/soc/adapter/moon_core_axi_adapter.sv
// Description: Bridges moon_core's imem and dmem interfaces to 64-bit AXI4
//              Master interfaces (M0: Fetch, M1: Data) with 64-bit prefetch buffer.
// ============================================================================

`ifndef MOON_CORE_AXI_ADAPTER_SV
`define MOON_CORE_AXI_ADAPTER_SV

`include "moon_pkg.sv"
`include "axi_pkg.sv"

module moon_core_axi_adapter
  import moon_pkg::*;
  import axi_pkg::*;
(
  input  logic clk_i,
  input  logic rst_ni,

  // --------------------------------------------------------------------------
  // Core Instruction Memory Interface
  // --------------------------------------------------------------------------
  input  logic             imem_req_i,
  input  logic [XLEN-1:0]  imem_addr_i,
  output logic             imem_valid_o,
  output logic [ILEN-1:0]  imem_rdata_o,

  // --------------------------------------------------------------------------
  // Core Data Memory Interface
  // --------------------------------------------------------------------------
  input  logic             dmem_req_i,
  input  logic             dmem_we_i,
  input  logic [XLEN-1:0]  dmem_addr_i,
  input  logic [XLEN-1:0]  dmem_wdata_i,
  input  logic [7:0]       dmem_wstrb_i,
  output logic             dmem_valid_o,
  output logic [XLEN-1:0]  dmem_rdata_o,

  // --------------------------------------------------------------------------
  // AXI4 Master 0: Instruction Fetch
  // --------------------------------------------------------------------------
  output axi_ar_t          m0_ar_o,
  input  logic             m0_ar_ready_i,
  input  axi_r_t           m0_r_i,
  output logic             m0_r_ready_o,

  // --------------------------------------------------------------------------
  // AXI4 Master 1: Data Load / Store
  // --------------------------------------------------------------------------
  output axi_ar_t          m1_ar_o,
  input  logic             m1_ar_ready_i,
  input  axi_r_t           m1_r_i,
  output logic             m1_r_ready_o,

  output axi_aw_t          m1_aw_o,
  input  logic             m1_aw_ready_i,
  output axi_w_t           m1_w_o,
  input  logic             m1_w_ready_i,
  input  axi_b_t           m1_b_i,
  output logic             m1_b_ready_o
);

  // --------------------------------------------------------------------------
  // Instruction Fetch Path (M0)
  // Simple 64-bit word prefetch buffer to eliminate stalls on sequential fetches
  // --------------------------------------------------------------------------
  typedef enum logic [1:0] {
    IF_IDLE = 2'd0,
    IF_AR   = 2'd1,
    IF_WAIT = 2'd2
  } if_state_e;

  if_state_e if_state_q, if_state_d;
  logic [XLEN-1:0] req_if_addr_q, req_if_addr_d;
  logic [XLEN-1:0] buf_pc_q;
  logic [63:0]     buf_data_q;
  logic            buf_valid_q;

  wire hit_in_buf = buf_valid_q && (imem_addr_i[XLEN-1:3] == buf_pc_q[XLEN-1:3]);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      if_state_q    <= IF_IDLE;
      req_if_addr_q <= '0;
      buf_pc_q      <= '0;
      buf_data_q    <= '0;
      buf_valid_q   <= 1'b0;
    end else begin
      if_state_q    <= if_state_d;
      req_if_addr_q <= req_if_addr_d;
      if (m0_r_i.valid && m0_r_ready_o) begin
        buf_pc_q    <= req_if_addr_q;
        buf_data_q  <= m0_r_i.data;
        buf_valid_q <= 1'b1;
      end
    end
  end

  always_comb begin
    if_state_d    = if_state_q;
    req_if_addr_d = req_if_addr_q;
    m0_ar_o       = '0;
    m0_r_ready_o  = 1'b1;
    imem_valid_o  = 1'b0;
    imem_rdata_o  = 32'h0000_0013; // NOP default

    if (hit_in_buf) begin
      imem_valid_o = 1'b1;
      imem_rdata_o = imem_addr_i[2] ? buf_data_q[63:32] : buf_data_q[31:0];
    end else begin
      case (if_state_q)
        IF_IDLE: begin
          if (imem_req_i) begin
            m0_ar_o.valid = 1'b1;
            m0_ar_o.id    = 4'd0;
            m0_ar_o.addr  = {imem_addr_i[XLEN-1:3], 3'b000};
            m0_ar_o.len   = 8'd0;
            m0_ar_o.size  = 3'b011; // 8 bytes
            m0_ar_o.burst = AXI_BURST_INCR;
            req_if_addr_d = m0_ar_o.addr;
            if (m0_ar_ready_i) begin
              if_state_d = IF_WAIT;
            end else begin
              if_state_d = IF_AR;
            end
          end
        end

        IF_AR: begin
          m0_ar_o.valid = 1'b1;
          m0_ar_o.id    = 4'd0;
          m0_ar_o.addr  = req_if_addr_q;
          m0_ar_o.len   = 8'd0;
          m0_ar_o.size  = 3'b011;
          m0_ar_o.burst = AXI_BURST_INCR;
          if (m0_ar_ready_i) begin
            if_state_d = IF_WAIT;
          end
        end

        IF_WAIT: begin
          if (m0_r_i.valid) begin
            if (imem_addr_i[XLEN-1:3] == req_if_addr_q[XLEN-1:3]) begin
              imem_valid_o = 1'b1;
              imem_rdata_o = imem_addr_i[2] ? m0_r_i.data[63:32] : m0_r_i.data[31:0];
            end
            if_state_d = IF_IDLE;
          end
        end

        default: if_state_d = IF_IDLE;
      endcase
    end
  end

  // --------------------------------------------------------------------------
  // Data Load / Store Path (M1)
  // --------------------------------------------------------------------------
  typedef enum logic [2:0] {
    D_IDLE    = 3'd0,
    D_RD_AR   = 3'd1,
    D_RD_WAIT = 3'd2,
    D_WR_AWW  = 3'd3,
    D_WR_B    = 3'd4
  } d_state_e;

  d_state_e d_state_q, d_state_d;
  logic [XLEN-1:0] rdata_captured_q, rdata_captured_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      d_state_q        <= D_IDLE;
      rdata_captured_q <= '0;
    end else begin
      d_state_q        <= d_state_d;
      rdata_captured_q <= rdata_captured_d;
    end
  end

  always_comb begin
    d_state_d        = d_state_q;
    rdata_captured_d = rdata_captured_q;

    m1_ar_o      = '0;
    m1_r_ready_o = 1'b0;
    m1_aw_o      = '0;
    m1_w_o       = '0;
    m1_b_ready_o = 1'b0;

    dmem_valid_o = 1'b0;
    dmem_rdata_o = rdata_captured_q;

    case (d_state_q)
      D_IDLE: begin
        if (dmem_req_i) begin
          if (dmem_we_i) begin
            m1_aw_o.valid = 1'b1;
            m1_aw_o.id    = 4'd1;
            m1_aw_o.addr  = dmem_addr_i;
            m1_aw_o.len   = 8'd0;
            m1_aw_o.size  = 3'b011;
            m1_aw_o.burst = AXI_BURST_INCR;

            m1_w_o.valid  = 1'b1;
            m1_w_o.data   = dmem_wdata_i;
            m1_w_o.strb   = dmem_wstrb_i;
            m1_w_o.last   = 1'b1;

            if (m1_aw_ready_i && m1_w_ready_i) begin
              d_state_d = D_WR_B;
            end else begin
              d_state_d = D_WR_AWW;
            end
          end else begin
            // Load request
            m1_ar_o.valid = 1'b1;
            m1_ar_o.id    = 4'd1;
            m1_ar_o.addr  = dmem_addr_i;
            m1_ar_o.len   = 8'd0;
            m1_ar_o.size  = 3'b011;
            m1_ar_o.burst = AXI_BURST_INCR;

            if (m1_ar_ready_i) begin
              d_state_d = D_RD_WAIT;
            end else begin
              d_state_d = D_RD_AR;
            end
          end
        end
      end

      D_RD_AR: begin
        m1_ar_o.valid = 1'b1;
        m1_ar_o.id    = 4'd1;
        m1_ar_o.addr  = dmem_addr_i;
        m1_ar_o.len   = 8'd0;
        m1_ar_o.size  = 3'b011;
        m1_ar_o.burst = AXI_BURST_INCR;

        if (m1_ar_ready_i) begin
          d_state_d = D_RD_WAIT;
        end
      end

      D_RD_WAIT: begin
        m1_r_ready_o = 1'b1;
        if (m1_r_i.valid) begin
          rdata_captured_d = m1_r_i.data;
          dmem_rdata_o     = m1_r_i.data;
          dmem_valid_o     = 1'b1;
          d_state_d        = D_IDLE;
        end
      end

      D_WR_AWW: begin
        m1_aw_o.valid = 1'b1;
        m1_aw_o.id    = 4'd1;
        m1_aw_o.addr  = dmem_addr_i;
        m1_aw_o.len   = 8'd0;
        m1_aw_o.size  = 3'b011;
        m1_aw_o.burst = AXI_BURST_INCR;

        m1_w_o.valid  = 1'b1;
        m1_w_o.data   = dmem_wdata_i;
        m1_w_o.strb   = dmem_wstrb_i;
        m1_w_o.last   = 1'b1;

        if (m1_aw_ready_i && m1_w_ready_i) begin
          d_state_d = D_WR_B;
        end
      end

      D_WR_B: begin
        m1_b_ready_o = 1'b1;
        if (m1_b_i.valid) begin
          dmem_valid_o = 1'b1;
          d_state_d    = D_IDLE;
        end
      end

      default: d_state_d = D_IDLE;
    endcase
  end

endmodule : moon_core_axi_adapter

`endif // MOON_CORE_AXI_ADAPTER_SV
