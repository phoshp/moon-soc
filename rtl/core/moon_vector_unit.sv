// ============================================================================
// File: rtl/core/moon_vector_unit.sv
// Description: Initial RVV 1.0 execution slice with VLEN=128 and e32,m1.
// ============================================================================

`ifndef MOON_VECTOR_UNIT_SV
`define MOON_VECTOR_UNIT_SV

module moon_vector_unit (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        valid_i,
  input  logic        advance_i,
  input  logic [31:0] instr_i,
  input  logic [63:0] scalar_rs1_i,
  output logic        scalar_result_valid_o,
  output logic [63:0] scalar_result_o
);
  logic [127:0] vreg [0:31];
  logic [2:0]   vl_q;
  logic [2:0]   vl;
  logic         is_vsetvli;
  logic         is_vmv_x_s;
  logic         is_vmv_v_x;
  logic         is_vadd_vv;
  logic         is_vadd_vx;
  logic         is_vsub_vv;
  logic [4:0]   vd, vs1, vs2;

  assign is_vsetvli = (instr_i[6:0] == 7'b1010111) && (instr_i[14:12] == 3'b111);
  assign is_vmv_x_s = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b010000) &&
                      instr_i[25] && (instr_i[14:12] == 3'b010) && (instr_i[19:15] == 5'd0);
  assign is_vmv_v_x = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b010111) &&
                      instr_i[25] && (instr_i[14:12] == 3'b100) && (instr_i[24:20] == 5'd0);
  assign is_vadd_vv = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b000000) &&
                      instr_i[25] && (instr_i[14:12] == 3'b000);
  assign is_vadd_vx = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b000000) &&
                      instr_i[25] && (instr_i[14:12] == 3'b100);
  assign is_vsub_vv = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b000010) &&
                      instr_i[25] && (instr_i[14:12] == 3'b000);
  assign vd  = instr_i[11:7];
  assign vs1 = instr_i[19:15];
  assign vs2 = instr_i[24:20];

  always_comb begin
    if (is_vsetvli) begin
      if ((instr_i[22:20] == 3'b000) && (instr_i[25:23] == 3'b010)) begin
        vl = (scalar_rs1_i == 64'd0) ? 3'd4 :
             (scalar_rs1_i >= 64'd4) ? 3'd4 : 3'(scalar_rs1_i[2:0]);
      end else begin
        vl = 3'd0;
      end
    end else begin
      vl = vl_q;
    end
  end

  always_comb begin
    scalar_result_valid_o = 1'b0;
    scalar_result_o = '0;
    if (valid_i && is_vsetvli) begin
      scalar_result_valid_o = 1'b1;
      scalar_result_o = {61'd0, vl};
    end else if (valid_i && is_vmv_x_s) begin
      scalar_result_valid_o = 1'b1;
      scalar_result_o = {{32{vreg[vs2][31]}}, vreg[vs2][31:0]};
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      vl_q <= '0;
      for (int i = 0; i < 32; i++) vreg[i] <= '0;
    end else if (valid_i && advance_i) begin
      if (is_vsetvli) begin
        vl_q <= vl;
      end else if (is_vmv_v_x) begin
        for (int i = 0; i < 4; i++) begin
          if (i < vl_q) vreg[vd][i*32 +: 32] <= scalar_rs1_i[31:0];
        end
      end else if (is_vadd_vv) begin
        for (int i = 0; i < 4; i++) begin
          if (i < vl_q) vreg[vd][i*32 +: 32] <= vreg[vs2][i*32 +: 32] + vreg[vs1][i*32 +: 32];
        end
      end else if (is_vadd_vx) begin
        for (int i = 0; i < 4; i++) begin
          if (i < vl_q) vreg[vd][i*32 +: 32] <= vreg[vs2][i*32 +: 32] + scalar_rs1_i[31:0];
        end
      end else if (is_vsub_vv) begin
        for (int i = 0; i < 4; i++) begin
          if (i < vl_q) vreg[vd][i*32 +: 32] <= vreg[vs2][i*32 +: 32] - vreg[vs1][i*32 +: 32];
        end
      end
    end
  end
endmodule

`endif // MOON_VECTOR_UNIT_SV
