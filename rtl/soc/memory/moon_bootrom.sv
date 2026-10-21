// ============================================================================
// File: rtl/soc/memory/moon_bootrom.sv
// Description: 32 KB AXI4 Boot ROM containing primary reset vector (0x0000_1000)
//              and initial firmware image.
// ============================================================================

`ifndef MOON_BOOTROM_SV
`define MOON_BOOTROM_SV

`include "axi_pkg.sv"

module moon_bootrom
  import axi_pkg::*;
#(
  parameter int ROM_SIZE_BYTES = 4096, // 4 KB Boot ROM
  parameter logic [AXI_ADDR_WIDTH-1:0] BASE_ADDR = 64'h0000_1000
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

  localparam int NUM_WORDS = ROM_SIZE_BYTES / 4; // 32-bit words
  localparam int ADDR_W    = $clog2(NUM_WORDS);
  (* syn_ramstyle = "block", ram_style = "block" *)
  logic [31:0] rom_mem [0:NUM_WORDS-1];

  // Optional simulation firmware load
  initial begin
    reg [8*256-1:0] hex_file;
    if ($value$plusargs("bootrom_hex=%s", hex_file)) begin
      $readmemh(hex_file, rom_mem);
    end else if ($value$plusargs("hex_file=%s", hex_file)) begin
      $readmemh(hex_file, rom_mem);
    end else begin
      // Default: jump to self loop (addi x0, x0, 0 / jal x0, 0)
      for (int i = 0; i < NUM_WORDS; i++) begin
        rom_mem[i] = 32'h0000_0013; // nop
      end
    end
  end

  // Read state machine
  typedef enum logic [1:0] {
    R_IDLE = 2'd0,
    R_READ = 2'd1,
    R_RESP = 2'd2
  } r_state_e;

  r_state_e r_state_q, r_state_d;
  logic [AXI_ID_WIDTH-1:0]   r_id_q,   r_id_d;
  logic [AXI_ADDR_WIDTH-1:0] r_addr_q, r_addr_d;
  logic [AXI_DATA_WIDTH-1:0] r_data_q;
  logic [7:0]                r_len_q,  r_len_d;
  logic [7:0]                r_cnt_q,  r_cnt_d;

  // Address offset calculation
  logic [AXI_ADDR_WIDTH-1:0] rel_addr;
  assign rel_addr = r_addr_q - BASE_ADDR;
  wire [ADDR_W:0] word_idx_lo = {1'b0, rel_addr[ADDR_W+1:2]};
  wire [ADDR_W:0] word_idx_hi = word_idx_lo + 1'b1;

  wire is_last_beat = (r_cnt_q == r_len_q);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      r_state_q <= R_IDLE;
      r_id_q    <= '0;
      r_addr_q  <= '0;
      r_data_q  <= '0;
      r_len_q   <= '0;
      r_cnt_q   <= '0;
    end else begin
      r_state_q <= r_state_d;
      r_id_q    <= r_id_d;
      r_addr_q  <= r_addr_d;
      r_len_q   <= r_len_d;
      r_cnt_q   <= r_cnt_d;
      if (r_state_q == R_READ) begin
        r_data_q <= {(word_idx_hi < NUM_WORDS) ? rom_mem[word_idx_hi[ADDR_W-1:0]] : 32'h0,
                     (word_idx_lo < NUM_WORDS) ? rom_mem[word_idx_lo[ADDR_W-1:0]] : 32'h0};
      end
    end
  end

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
        s_r_o.data  = r_data_q;
        s_r_o.resp  = AXI_RESP_OKAY;
        s_r_o.last  = is_last_beat;
        if (s_r_ready_i) begin
          if (is_last_beat) begin
            r_state_d = R_IDLE;
          end else begin
            r_cnt_d   = r_cnt_q + 8'd1;
            r_addr_d  = r_addr_q + 64'd8; // Next doubleword
            r_state_d = R_READ;
          end
        end
      end

      default: r_state_d = R_IDLE;
    endcase
  end

  // ROM is read-only: reject writes with SLVERR
  always_comb begin
    s_aw_ready_o = s_aw_i.valid;
    s_w_ready_o  = s_w_i.valid;
    s_b_o.valid  = s_aw_i.valid && s_w_i.valid;
    s_b_o.id     = s_aw_i.id;
    s_b_o.resp   = AXI_RESP_SLVERR;
  end

endmodule : moon_bootrom

`endif // MOON_BOOTROM_SV
