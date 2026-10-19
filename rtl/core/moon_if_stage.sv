// ============================================================================
// File: rtl/core/moon_if_stage.sv
// Description: Instruction Fetch (IF) stage with RVC compressed instruction
//              decompressor (Zca, Zcb) and unaligned fetch buffer.
// ============================================================================

`ifndef MOON_IF_STAGE_SV
`define MOON_IF_STAGE_SV

`include "moon_pkg.sv"
`include "moon_c_decoder.sv"

module moon_if_stage
  import moon_pkg::*;
(
  input  logic             clk_i,
  input  logic             rst_ni,

  // Pipeline Flow Control
  input  logic             stall_if_i,
  input  logic             stall_id_i,
  input  logic             flush_id_i,

  // Redirection inputs from EX and Trap units
  input  logic             branch_taken_i,
  input  logic [XLEN-1:0]  branch_target_i,
  input  logic             trap_enter_i,
  input  logic [XLEN-1:0]  trap_vector_i,
  input  logic             mret_i,
  input  logic [XLEN-1:0]  mepc_i,
  input  logic             sret_i,
  input  logic [XLEN-1:0]  sepc_i,

  // Instruction Memory Interface (Fetch)
  output logic             imem_req_o,
  output logic [XLEN-1:0]  imem_addr_o,
  input  logic             imem_valid_i,
  input  logic [ILEN-1:0]  imem_rdata_i,

  // Output to ID Stage (IF/ID Pipeline Register)
  output logic [XLEN-1:0]  if_id_pc_o,
  output logic [ILEN-1:0]  if_id_instr_o,
  output logic             if_id_is_c_o,
  output logic             if_id_valid_o
);

  // Redirection detection
  wire redirect = trap_enter_i || mret_i || sret_i || branch_taken_i;
  logic [XLEN-1:0] redirect_target;

  always_comb begin
    if (trap_enter_i) begin
      redirect_target = trap_vector_i;
    end else if (mret_i) begin
      redirect_target = mepc_i;
    end else if (sret_i) begin
      redirect_target = sepc_i;
    end else begin
      redirect_target = branch_target_i;
    end
  end

  // Fetch buffer state
  logic [15:0]     q_data_q [0:3], q_data_d [0:3];
  logic [2:0]      q_count_q, q_count_d;
  logic [XLEN-1:0] pc_q, pc_d;
  logic [XLEN-1:0] fetch_addr_q, fetch_addr_d;
  logic            discard_hw_q, discard_hw_d;

  // Memory interface request (request new word whenever queue has room and not in reset)
  assign imem_addr_o = fetch_addr_q;
  assign imem_req_o  = rst_ni && (q_count_q <= 3'd2);

  // Available halfwords in current cycle (buffered + arriving)
  logic [15:0] avail_hw [0:5];
  logic [2:0]  avail_count;
  logic [1:0]  push_count;

  always_comb begin
    for (int i = 0; i < 4; i++) begin
      avail_hw[i] = q_data_q[i];
    end
    avail_hw[4] = 16'd0;
    avail_hw[5] = 16'd0;

    push_count = 2'd0;
    if (imem_valid_i && !redirect) begin
      if (discard_hw_q) begin
        avail_hw[q_count_q] = imem_rdata_i[31:16];
        push_count = 2'd1;
      end else begin
        avail_hw[q_count_q]        = imem_rdata_i[15:0];
        avail_hw[q_count_q + 3'd1] = imem_rdata_i[31:16];
        push_count = 2'd2;
      end
    end
    avail_count = q_count_q + {1'b0, push_count};
  end

  // Compressed instruction decoder
  logic [31:0] decomp_instr;
  logic        decomp_is_c;
  logic        decomp_illegal;

  moon_c_decoder u_c_decoder (
    .instr_16_i      (avail_hw[0]),
    .instr_32_o      (decomp_instr),
    .is_compressed_o (decomp_is_c),
    .illegal_instr_o (decomp_illegal)
  );

  // Instruction candidate formulation
  logic        instr_is_compressed;
  logic [31:0] current_instr;
  logic        current_valid;
  logic [1:0]  pop_count;
  logic [XLEN-1:0] pc_step;

  always_comb begin
    instr_is_compressed = (avail_hw[0][1:0] != 2'b11);

    if (instr_is_compressed) begin
      current_instr = decomp_instr;
      current_valid = (avail_count >= 3'd1);
      pop_count     = 2'd1;
      pc_step       = 64'd2;
    end else begin
      current_instr = {avail_hw[1], avail_hw[0]};
      current_valid = (avail_count >= 3'd2);
      pop_count     = 2'd2;
      pc_step       = 64'd4;
    end
  end

  wire consume = current_valid && !stall_id_i && !redirect;

  // Next-state evaluation
  always_comb begin
    if (redirect) begin
      q_count_d    = 3'd0;
      pc_d         = redirect_target;
      fetch_addr_d = {redirect_target[XLEN-1:2], 2'b00};
      discard_hw_d = redirect_target[1];
      for (int i = 0; i < 4; i++) begin
        q_data_d[i] = 16'd0;
      end
    end else begin
      discard_hw_d = discard_hw_q && !imem_valid_i;

      if (imem_req_o && imem_valid_i) begin
        fetch_addr_d = fetch_addr_q + 64'd4;
      end else begin
        fetch_addr_d = fetch_addr_q;
      end

      if (consume) begin
        pc_d = pc_q + pc_step;
        q_count_d = avail_count - {1'b0, pop_count};
        for (int i = 0; i < 4; i++) begin
          q_data_d[i] = avail_hw[i + pop_count];
        end
      end else begin
        pc_d = pc_q;
        q_count_d = (avail_count > 3'd4) ? 3'd4 : avail_count;
        for (int i = 0; i < 4; i++) begin
          q_data_d[i] = avail_hw[i];
        end
      end
    end
  end

  // State register update
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_q         <= 64'h0000_1000; // Reset vector (Boot ROM address)
      fetch_addr_q <= 64'h0000_1000;
      q_count_q    <= 3'd0;
      discard_hw_q <= 1'b0;
      for (int i = 0; i < 4; i++) begin
        q_data_q[i] <= 16'd0;
      end
    end else begin
      pc_q         <= pc_d;
      fetch_addr_q <= fetch_addr_d;
      q_count_q    <= q_count_d;
      discard_hw_q <= discard_hw_d;
      for (int i = 0; i < 4; i++) begin
        q_data_q[i] <= q_data_d[i];
      end
    end
  end

  // IF/ID Pipeline Register
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      if_id_pc_o    <= '0;
      if_id_instr_o <= 32'h0000_0013; // NOP (addi x0, x0, 0)
      if_id_is_c_o  <= 1'b0;
      if_id_valid_o <= 1'b0;
    end else if (flush_id_i || redirect) begin
      if_id_pc_o    <= '0;
      if_id_instr_o <= 32'h0000_0013; // Flush with NOP
      if_id_is_c_o  <= 1'b0;
      if_id_valid_o <= 1'b0;
    end else if (!stall_id_i) begin
      if (current_valid) begin
        if_id_pc_o    <= pc_q;
        if_id_instr_o <= current_instr;
        if_id_is_c_o  <= instr_is_compressed;
        if_id_valid_o <= 1'b1;
      end else begin
        if_id_pc_o    <= pc_q;
        if_id_instr_o <= 32'h0000_0013;
        if_id_is_c_o  <= 1'b0;
        if_id_valid_o <= 1'b0;
      end
    end
  end

endmodule : moon_if_stage

`endif // MOON_IF_STAGE_SV
