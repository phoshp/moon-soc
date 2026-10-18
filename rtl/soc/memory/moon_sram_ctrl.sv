// ============================================================================
// File: rtl/soc/memory/moon_sram_ctrl.sv
// Description: 128 KB On-Chip SRAM Controller with 64-bit AXI4 Slave interface
//              and byte write-strobe masking.
// ============================================================================

`ifndef MOON_SRAM_CTRL_SV
`define MOON_SRAM_CTRL_SV

`include "axi_pkg.sv"
`include "openram_sram_wrapper.sv"

module moon_sram_ctrl
  import axi_pkg::*;
#(
  parameter int SRAM_SIZE_BYTES = 131072, // 128 KB
  parameter logic [AXI_ADDR_WIDTH-1:0] BASE_ADDR = 64'h7000_0000
)(
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
  input  logic    s_b_ready_i
);

  localparam int NUM_WORDS = SRAM_SIZE_BYTES / 8; // 64-bit words (16384 words)
  localparam int ADDR_W    = $clog2(NUM_WORDS);

  // --------------------------------------------------------------------------
  // Write Path
  // --------------------------------------------------------------------------
  typedef enum logic [1:0] {
    W_IDLE   = 2'd0,
    W_BURST  = 2'd1,
    W_RESP   = 2'd2
  } w_state_e;

  w_state_e w_state_q, w_state_d;
  logic [AXI_ID_WIDTH-1:0]   w_id_q,   w_id_d;
  logic [AXI_ADDR_WIDTH-1:0] w_addr_q, w_addr_d;
  logic [AXI_DATA_WIDTH-1:0] w_data_q, w_data_d;
  logic [AXI_STRB_WIDTH-1:0] w_strb_q, w_strb_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      w_state_q <= W_IDLE;
      w_id_q    <= '0;
      w_addr_q  <= '0;
      w_data_q  <= '0;
      w_strb_q  <= '0;
    end else begin
      w_state_q <= w_state_d;
      w_id_q    <= w_id_d;
      w_addr_q  <= w_addr_d;
      w_data_q  <= w_data_d;
      w_strb_q  <= w_strb_d;
    end
  end

  logic [AXI_ADDR_WIDTH-1:0] w_rel_addr;
  assign w_rel_addr = w_addr_q - BASE_ADDR;
  wire [ADDR_W-1:0] w_word_idx = w_rel_addr[ADDR_W+2:3];

  always_comb begin
    w_state_d    = w_state_q;
    w_id_d       = w_id_q;
    w_addr_d     = w_addr_q;
    w_data_d     = w_data_q;
    w_strb_d     = w_strb_q;
    s_aw_ready_o = 1'b0;
    s_w_ready_o  = 1'b0;
    s_b_o        = '0;

    case (w_state_q)
      W_IDLE: begin
        if (s_aw_i.valid) begin
          s_aw_ready_o = 1'b1;
          w_id_d       = s_aw_i.id;
          w_addr_d     = s_aw_i.addr;
          w_state_d    = W_BURST;
        end
      end

      W_BURST: begin
        s_w_ready_o = 1'b1;
        if (s_w_i.valid) begin
          w_data_d = s_w_i.data;
          w_strb_d = s_w_i.strb;
          w_addr_d = w_addr_q + 64'd8;
          if (s_w_i.last) begin
            w_state_d = W_RESP;
          end
        end
      end

      W_RESP: begin
        s_b_o.valid = 1'b1;
        s_b_o.id    = w_id_q;
        s_b_o.resp  = AXI_RESP_OKAY;
        if (s_b_ready_i) begin
          w_state_d = W_IDLE;
        end
      end

      default: w_state_d = W_IDLE;
    endcase
  end

  // --------------------------------------------------------------------------
  // Read Path
  // --------------------------------------------------------------------------
  typedef enum logic [1:0] {
    R_IDLE = 2'd0,
    R_READ = 2'd1,
    R_RESP = 2'd2
  } r_state_e;

  r_state_e r_state_q, r_state_d;
  logic [AXI_ID_WIDTH-1:0]   r_id_q,   r_id_d;
  logic [AXI_ADDR_WIDTH-1:0] r_addr_q, r_addr_d;
  logic [7:0]                r_len_q,  r_len_d;
  logic [7:0]                r_cnt_q,  r_cnt_d;
  logic                      r_valid_idx_q;

  logic [AXI_ADDR_WIDTH-1:0] r_rel_addr;
  assign r_rel_addr = r_addr_q - BASE_ADDR;
  wire [ADDR_W-1:0] r_word_idx = r_rel_addr[ADDR_W+2:3];
  wire is_last_rbeat = (r_cnt_q == r_len_q);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      r_state_q     <= R_IDLE;
      r_id_q        <= '0;
      r_addr_q      <= '0;
      r_len_q       <= '0;
      r_cnt_q       <= '0;
      r_valid_idx_q <= 1'b0;
    end else begin
      r_state_q     <= r_state_d;
      r_id_q        <= r_id_d;
      r_addr_q      <= r_addr_d;
      r_len_q       <= r_len_d;
      r_cnt_q       <= r_cnt_d;
      if (r_state_q == R_READ) begin
        r_valid_idx_q <= (r_rel_addr < SRAM_SIZE_BYTES);
      end
    end
  end

  // --------------------------------------------------------------------------
  // OpenRAM Macro Wrapper Instantiation
  // --------------------------------------------------------------------------
  logic [AXI_DATA_WIDTH-1:0] openram_rdata;
  wire sram_wr_en = (w_state_q == W_BURST) && s_w_i.valid && (w_rel_addr < SRAM_SIZE_BYTES);
  wire sram_rd_en = (r_state_q == R_READ) && (r_rel_addr < SRAM_SIZE_BYTES);

  openram_sram_wrapper #(
    .DATA_WIDTH  (AXI_DATA_WIDTH),
    .ADDR_WIDTH  (ADDR_W),
    .WMASK_WIDTH (AXI_STRB_WIDTH)
  ) u_openram (
    // Port 0: Synchronous Write
    .clk0   (clk_i),
    .csb0   (!sram_wr_en),
    .web0   (!sram_wr_en),
    .wmask0 (s_w_i.strb),
    .addr0  (w_word_idx),
    .din0   (s_w_i.data),
    .dout0  (),

    // Port 1: Synchronous Read
    .clk1   (clk_i),
    .csb1   (!sram_rd_en),
    .addr1  (r_word_idx),
    .dout1  (openram_rdata)
  );

  always_comb begin
    r_state_d    = r_state_q;
    r_id_d       = r_id_q;
    r_addr_d     = r_addr_q;
    r_len_d      = r_len_q;
    r_cnt_d      = r_cnt_q;
    s_ar_ready_o = 1'b0;
    s_r_o        = '0;

    case (r_state_q)
      R_IDLE: begin
        s_ar_ready_o = 1'b1;
        if (s_ar_i.valid) begin
          r_id_d    = s_ar_i.id;
          r_addr_d  = s_ar_i.addr;
          r_len_d   = s_ar_i.len;
          r_cnt_d   = 8'd0;
          r_state_d = R_READ;
        end
      end

      R_READ: begin
        r_state_d = R_RESP;
      end

      R_RESP: begin
        s_r_o.valid = 1'b1;
        s_r_o.id    = r_id_q;
        s_r_o.data  = r_valid_idx_q ? openram_rdata : '0;
        s_r_o.resp  = AXI_RESP_OKAY;
        s_r_o.last  = is_last_rbeat;
        if (s_r_ready_i) begin
          if (is_last_rbeat) begin
            r_state_d = R_IDLE;
          end else begin
            r_cnt_d   = r_cnt_q + 8'd1;
            r_addr_d  = r_addr_q + 64'd8;
            r_state_d = R_READ;
          end
        end
      end

      default: r_state_d = R_IDLE;
    endcase
  end

endmodule : moon_sram_ctrl

`endif // MOON_SRAM_CTRL_SV
