// ============================================================================
// File: rtl/soc/interconnect/axi_to_apb_bridge.sv
// Description: Converts 64-bit AXI4 transactions to 32-bit APB4 transactions.
// ============================================================================

`ifndef AXI_TO_APB_BRIDGE_SV
`define AXI_TO_APB_BRIDGE_SV

`include "axi_pkg.sv"

module axi_to_apb_bridge
  import axi_pkg::*;
(
  input  logic clk_i,
  input  logic rst_ni,

  // AXI4 Slave Interface
  input  axi_ar_t s_ar_i,
  output logic    s_ar_ready_o,
  output axi_r_t  s_r_o,
  input  logic    s_r_ready_i,

  input  axi_aw_t s_aw_i,
  output logic    s_aw_ready_o,
  input  axi_w_t  s_w_i,
  output logic    s_w_ready_o,
  output axi_b_t  s_b_o,
  input  logic    s_b_ready_i,

  // APB4 Master Interface
  output apb_req_t  apb_req_o,
  input  apb_resp_t apb_resp_i
);

  typedef enum logic [2:0] {
    ST_IDLE       = 3'd0,
    ST_READ_SETUP = 3'd1,
    ST_READ_ACC   = 3'd2,
    ST_READ_RESP  = 3'd3,
    ST_WRITE_SETUP= 3'd4,
    ST_WRITE_ACC  = 3'd5,
    ST_WRITE_RESP = 3'd6
  } state_e;

  state_e state_q, state_d;

  logic [AXI_ID_WIDTH-1:0]   req_id_q,   req_id_d;
  logic [AXI_ADDR_WIDTH-1:0] req_addr_q, req_addr_d;
  logic [AXI_DATA_WIDTH-1:0] req_wdata_q, req_wdata_d;
  logic [AXI_STRB_WIDTH-1:0] req_wstrb_q, req_wstrb_d;
  logic [AXI_DATA_WIDTH-1:0] rdata_q,     rdata_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q     <= ST_IDLE;
      req_id_q    <= '0;
      req_addr_q  <= '0;
      req_wdata_q <= '0;
      req_wstrb_q <= '0;
      rdata_q     <= '0;
    end else begin
      state_q     <= state_d;
      req_id_q    <= req_id_d;
      req_addr_q  <= req_addr_d;
      req_wdata_q <= req_wdata_d;
      req_wstrb_q <= req_wstrb_d;
      rdata_q     <= rdata_d;
    end
  end

  always_comb begin
    state_d      = state_q;
    req_id_d     = req_id_q;
    req_addr_d   = req_addr_q;
    req_wdata_d  = req_wdata_q;
    req_wstrb_d  = req_wstrb_q;
    rdata_d      = rdata_q;

    s_ar_ready_o = 1'b0;
    s_aw_ready_o = 1'b0;
    s_w_ready_o  = 1'b0;

    s_r_o        = '0;
    s_b_o        = '0;

    apb_req_o    = '0;

    case (state_q)
      ST_IDLE: begin
        if (s_aw_i.valid && s_w_i.valid) begin
          s_aw_ready_o = 1'b1;
          s_w_ready_o  = 1'b1;
          req_id_d     = s_aw_i.id;
          req_addr_d   = s_aw_i.addr;
          req_wdata_d  = s_w_i.data;
          req_wstrb_d  = s_w_i.strb;
          state_d      = ST_WRITE_SETUP;
        end else if (s_ar_i.valid) begin
          s_ar_ready_o = 1'b1;
          req_id_d     = s_ar_i.id;
          req_addr_d   = s_ar_i.addr;
          state_d      = ST_READ_SETUP;
        end
      end

      ST_READ_SETUP: begin
        apb_req_o.sel    = 1'b1;
        apb_req_o.enable = 1'b0;
        apb_req_o.write  = 1'b0;
        apb_req_o.addr   = req_addr_q[APB_ADDR_WIDTH-1:0];
        state_d          = ST_READ_ACC;
      end

      ST_READ_ACC: begin
        apb_req_o.sel    = 1'b1;
        apb_req_o.enable = 1'b1;
        apb_req_o.write  = 1'b0;
        apb_req_o.addr   = req_addr_q[APB_ADDR_WIDTH-1:0];
        if (apb_resp_i.ready) begin
          // Sign or zero extend 32-bit APB read data into 64-bit AXI data, replicated in upper/lower words
          if (req_addr_q[2]) begin
            rdata_d = {apb_resp_i.rdata, apb_resp_i.rdata};
          end else begin
            rdata_d = {32'b0, apb_resp_i.rdata};
          end
          state_d = ST_READ_RESP;
        end
      end

      ST_READ_RESP: begin
        s_r_o.valid = 1'b1;
        s_r_o.id    = req_id_q;
        s_r_o.data  = rdata_q;
        s_r_o.resp  = AXI_RESP_OKAY;
        s_r_o.last  = 1'b1;
        if (s_r_ready_i) begin
          state_d = ST_IDLE;
        end
      end

      ST_WRITE_SETUP: begin
        apb_req_o.sel    = 1'b1;
        apb_req_o.enable = 1'b0;
        apb_req_o.write  = 1'b1;
        apb_req_o.addr   = req_addr_q[APB_ADDR_WIDTH-1:0];
        apb_req_o.wdata  = req_addr_q[2] ? req_wdata_q[63:32] : req_wdata_q[31:0];
        apb_req_o.strb   = req_addr_q[2] ? req_wstrb_q[7:4]   : req_wstrb_q[3:0];
        state_d          = ST_WRITE_ACC;
      end

      ST_WRITE_ACC: begin
        apb_req_o.sel    = 1'b1;
        apb_req_o.enable = 1'b1;
        apb_req_o.write  = 1'b1;
        apb_req_o.addr   = req_addr_q[APB_ADDR_WIDTH-1:0];
        apb_req_o.wdata  = req_addr_q[2] ? req_wdata_q[63:32] : req_wdata_q[31:0];
        apb_req_o.strb   = req_addr_q[2] ? req_wstrb_q[7:4]   : req_wstrb_q[3:0];
        if (apb_resp_i.ready) begin
          state_d = ST_WRITE_RESP;
        end
      end

      ST_WRITE_RESP: begin
        s_b_o.valid = 1'b1;
        s_b_o.id    = req_id_q;
        s_b_o.resp  = AXI_RESP_OKAY;
        if (s_b_ready_i) begin
          state_d = ST_IDLE;
        end
      end

      default: state_d = ST_IDLE;
    endcase
  end

endmodule : axi_to_apb_bridge

`endif // AXI_TO_APB_BRIDGE_SV
