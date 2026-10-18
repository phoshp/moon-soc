// ============================================================================
// File: rtl/core/moon_vector_unit.sv
// Description: RVV 1.0 integer slice with VLEN=128 and LMUL=1.
// ============================================================================

`ifndef MOON_VECTOR_UNIT_SV
`define MOON_VECTOR_UNIT_SV

module moon_vector_unit #(
  parameter bit ENABLE_VECTOR_FP = 1'b1
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        valid_i,
  input  logic        advance_i,
  input  logic [31:0] instr_i,
  input  logic [63:0] scalar_rs1_i,
  input  logic [63:0] scalar_rs2_i,
  input  logic [2:0]  frm_i,
  input  logic [63:0] vector_vstart_i,
  input  logic        vector_mem_fault_i,
  output logic        vector_vstart_clear_o,
  output logic        vector_vxsat_set_o,
  output logic [4:0]  vector_fp_flags_o,
  output logic        vector_fp_flags_we_o,
  output logic [63:0] vector_mem_vstart_o,
  output logic [63:0] vector_vl_o,
  output logic [63:0] vector_vtype_o,
  output logic        scalar_result_valid_o,
  output logic [63:0] scalar_result_o,
  output logic        mem_req_o,
  output logic        mem_we_o,
  output logic [63:0] mem_addr_o,
  output logic [63:0] mem_wdata_o,
  output logic [7:0]  mem_wstrb_o,
  input  logic        mem_valid_i,
  input  logic [63:0] mem_rdata_i,
  output logic        mem_busy_o
);
  logic [127:0] vreg [0:31];
  logic [4:0]   vl_q;
  logic [4:0]   vl;
  logic [4:0]   vlmax;
  logic [2:0]   vsew_q;
  logic [63:0]  vtype_q;
  logic         vtype_legal;
  logic         is_vsetvli;
  logic         is_vsetivli;
  logic         is_vset_config;
  logic         is_vmv_x_s;
  logic         is_vmask_prefix;
  logic         is_vmask_query;
  logic         is_vmv_v_x;
  logic         is_vadd_vv;
  logic         is_vadd_vx;
  logic         is_vmul_vv;
  logic         is_vmul_vx;
  logic         is_vmulh_vv;
  logic         is_vmulh_vx;
  logic         is_vmulhu_vv;
  logic         is_vmulhu_vx;
  logic         is_vmulhsu_vv;
  logic         is_vmulhsu_vx;
  logic         is_vdivrem_vv;
  logic         is_vdivrem_vx;
  logic         is_vsat_vv;
  logic         is_vsat_vx;
  logic         is_vector_sat;
  logic         is_vector_fp_addsub;
  logic         is_vector_fp_mul;
  logic         is_vector_fp_div;
  logic         is_vector_fp_sqrt;
  logic         is_vector_fp_class;
  logic         is_vector_fp_int_cvt;
  logic         is_vector_fp_widen_cvt;
  logic         is_vector_fp_widen_float_cvt;
  logic         is_vector_fp_widen_addsub;
  logic         is_vector_fp_widen_mul;
  logic         is_vector_fp_widen_arith;
  logic         is_vector_fp_widen_mac;
  logic         is_vector_fp_widen_op;
  logic         is_vector_fp_narrow_cvt;
  logic         is_vector_fp_narrow_float_cvt;
  logic         is_vector_fp_narrow_op;
  logic         is_vector_fp_mac;
  logic         is_vector_fp_fma_dest_mult;
  logic         is_vector_fp_compare;
  logic         is_vector_fp_not_equal;
  logic         is_vector_fp_minmax;
  logic         is_vector_fp_signinj;
  logic         is_vector_fp_scalar_form;
  logic         is_vector_fp_op;
  logic         is_vsub_vv;
  logic         is_vsub_vx;
  logic         is_vlogic;
  logic         is_vshift;
  logic         is_vector_narrow_shift;
  logic         is_vcompare;
  logic         is_vminmax;
  logic         is_vmask_logic;
  logic         is_vector_reduction;
  logic         is_vector_widen_reduction;
  logic         is_vector_int_widen_arith;
  logic         is_vector_int_widen_macc;
  logic         is_vector_int_ext;
  logic         is_vslideup;
  logic         is_vslidedown;
  logic         is_vslide1up;
  logic         is_vslide1down;
  logic         is_vrgather;
  logic         is_vector_permute;
  logic         is_vector_data_op;
  logic         is_vector_mask_result_op;
  logic [4:0]   vd, vs1, vs2;
  logic         is_vle_v, is_vse_v;
  logic         is_vlm_v, is_vsm_v;
  logic         is_vector_mask_mem;
  logic         vector_mem_strided;
  logic         vector_mem_indexed;
  logic         vector_mem_active_q;
  logic         vector_mem_done_q;
  logic         vector_mem_store_q;
  logic         vector_mem_strided_q;
  logic         vector_mem_indexed_q;
  logic         vector_mem_mask_q;
  logic [63:0]  vector_mem_base_q;
  logic [63:0]  vector_mem_stride_q;
  logic [4:0]   vector_mem_index_reg_q;
  logic [4:0]   vector_mem_count_q;
  logic [4:0]   vector_mem_vl_q;
  logic [2:0]   vector_mem_sew_q;
  logic [2:0]   vector_mem_index_sew_q;
  logic [2:0]   vector_mem_eew;
  logic [4:0]   vector_mem_vd_q;
  logic [63:0]  vector_mem_addr;
  logic [2:0]   vector_mem_offset;
  logic [63:0]  vector_mem_element;
  logic [4:0]   mask_first_index;
  logic         mask_first_found;
  logic [63:0]  mask_query_result;
  logic [63:0]  vector_reduce_result;
  logic [63:0]  vector_reduce_accum;
  logic [63:0]  vector_widen_reduce_result;
  logic [63:0]  vector_perm_offset;
  logic [63:0]  vector_fp_operand_a [0:3];
  logic [63:0]  vector_fp_operand_b [0:3];
  logic [63:0]  vector_fp_result [0:3];
  logic [4:0]   vector_fp_lane_flags [0:3];
  logic [63:0]  vector_fp_mul_result [0:3];
  logic [4:0]   vector_fp_mul_flags [0:3];
  logic [63:0]  vector_fp_div_result [0:3];
  logic [4:0]   vector_fp_div_flags [0:3];
  logic [63:0]  vector_fp_sqrt_result [0:3];
  logic [4:0]   vector_fp_sqrt_flags [0:3];
  logic [63:0]  vector_fp_mac_result [0:3];
  logic [4:0]   vector_fp_mac_flags [0:3];
  logic [63:0]  vector_fp_operand_c [0:3];
  logic [6:0]   vector_fp_mac_opcode;
  logic [63:0]  vector_fp_compare_result [0:3];
  logic [4:0]   vector_fp_compare_flags [0:3];
  logic [31:0]  vector_fp_int_cvt_instr [0:3];
  logic [63:0]  vector_fp_int_cvt_result [0:3];
  logic [4:0]   vector_fp_int_cvt_flags [0:3];
  logic [63:0]  vector_fp_widen_float_result [0:3];
  logic [4:0]   vector_fp_widen_float_flags [0:3];
  logic [63:0]  vector_narrow_operand [0:3];
  logic [63:0]  vector_fp_narrow_float_result [0:3];
  logic [4:0]   vector_fp_narrow_float_flags [0:3];

  function automatic logic [9:0] classify_floating(
    input logic [63:0] value,
    input logic        single_precision
  );
    logic sign;
    logic [10:0] exponent;
    logic [51:0] fraction;
    logic exponent_all_ones;
    logic fraction_zero;
    begin
      sign = single_precision ? value[31] : value[63];
      exponent = single_precision ? {3'b0, value[30:23]} : value[62:52];
      fraction = single_precision ? {29'd0, value[22:0]} : value[51:0];
      exponent_all_ones = single_precision ? (exponent == 11'h0ff) : (exponent == 11'h7ff);
      fraction_zero = (fraction == 52'd0);
      classify_floating = 10'd0;
      if (exponent_all_ones) begin
        if (fraction_zero)
          classify_floating[sign ? 0 : 7] = 1'b1;
        else if (single_precision ? fraction[22] : fraction[51])
          classify_floating[9] = 1'b1;
        else
          classify_floating[8] = 1'b1;
      end else if (exponent == 11'd0) begin
        if (fraction_zero)
          classify_floating[sign ? 3 : 4] = 1'b1;
        else
          classify_floating[sign ? 2 : 5] = 1'b1;
      end else begin
        classify_floating[sign ? 1 : 6] = 1'b1;
      end
    end
  endfunction

  function automatic logic [31:0] make_scalar_int_cvt_instr(
    input logic [31:0] vector_instr,
    input logic [2:0]  sew
  );
    logic float_to_int;
    logic unsigned_conversion;
    logic widening;
    logic narrowing;
    logic integer_word;
    logic [6:0] scalar_funct7;
    logic [4:0] scalar_cvt_type;
    begin
      widening = (vector_instr[19:15] >= 5'd8) && (vector_instr[19:15] <= 5'd15);
      narrowing = (vector_instr[19:15] >= 5'd16) && (vector_instr[19:15] <= 5'd23) &&
                  (vector_instr[19:15] != 5'd20) && (vector_instr[19:15] != 5'd21);
      float_to_int = (vector_instr[19:15] == 5'd0) ||
                     (vector_instr[19:15] == 5'd1) ||
                     (vector_instr[19:15] == 5'd6) ||
                     (vector_instr[19:15] == 5'd7) ||
                     (vector_instr[19:15] == 5'd8) ||
                     (vector_instr[19:15] == 5'd9) ||
                     (vector_instr[19:15] == 5'd14) ||
                     (vector_instr[19:15] == 5'd15) ||
                     (vector_instr[19:15] == 5'd16) ||
                     (vector_instr[19:15] == 5'd17) ||
                     (vector_instr[19:15] == 5'd22) ||
                     (vector_instr[19:15] == 5'd23);
      unsigned_conversion = (vector_instr[19:15] == 5'd0) ||
                            (vector_instr[19:15] == 5'd2) ||
                            (vector_instr[19:15] == 5'd6) ||
                            (vector_instr[19:15] == 5'd8) ||
                            (vector_instr[19:15] == 5'd10) ||
                            (vector_instr[19:15] == 5'd14) ||
                            (vector_instr[19:15] == 5'd16) ||
                            (vector_instr[19:15] == 5'd18) ||
                            (vector_instr[19:15] == 5'd22);
      integer_word = narrowing ? float_to_int : (widening ? !float_to_int : (sew == 3'b010));
      scalar_funct7 = float_to_int ?
                      ((narrowing || (sew != 3'b010)) ? 7'b1100001 : 7'b1100000) :
                      ((widening || (sew != 3'b010)) ? 7'b1101001 : 7'b1101000);
      scalar_cvt_type = integer_word ?
                        (unsigned_conversion ? 5'd1 : 5'd0) :
                        (unsigned_conversion ? 5'd3 : 5'd2);
      make_scalar_int_cvt_instr = {scalar_funct7, scalar_cvt_type,
                                   5'd0, 3'd0, 5'd0, 7'b1010011};
    end
  endfunction

  always_comb begin
    case (instr_i[14:12])
      3'b000: vector_mem_eew = 3'b000;
      3'b101: vector_mem_eew = 3'b001;
      3'b110: vector_mem_eew = 3'b010;
      3'b111: vector_mem_eew = 3'b011;
      default: vector_mem_eew = 3'b100;
    endcase
  end

  assign is_vle_v = (instr_i[6:0] == 7'b0000111) &&
                    (instr_i[31:29] == 3'b000) &&
                    (instr_i[28] == 1'b0) &&
                    (((instr_i[27:26] == 2'b00) && (instr_i[24:20] == 5'b00000)) ||
                     (instr_i[27:26] == 2'b10) ||
                     (instr_i[27:26] == 2'b01) || (instr_i[27:26] == 2'b11)) &&
                    (vector_mem_indexed || (vector_mem_eew == vsew_q));
  assign is_vse_v = (instr_i[6:0] == 7'b0100111) &&
                    (instr_i[31:29] == 3'b000) &&
                    (instr_i[28] == 1'b0) &&
                    ((instr_i[27:26] == 2'b00) || (instr_i[27:26] == 2'b10) ||
                     (instr_i[27:26] == 2'b01) || (instr_i[27:26] == 2'b11)) &&
                    (vector_mem_indexed || (vector_mem_eew == vsew_q));
  assign is_vlm_v = (instr_i[6:0] == 7'b0000111) &&
                    (instr_i[31:28] == 4'b0000) &&
                    (instr_i[27:26] == 2'b00) && (instr_i[25]) &&
                    (instr_i[24:20] == 5'b01011) &&
                    (instr_i[14:12] == 3'b000);
  assign is_vsm_v = (instr_i[6:0] == 7'b0100111) &&
                    (instr_i[31:28] == 4'b0000) &&
                    (instr_i[27:26] == 2'b00) && (instr_i[25]) &&
                    (instr_i[24:20] == 5'b01011) &&
                    (instr_i[14:12] == 3'b000);
  assign is_vector_mask_mem = is_vlm_v || is_vsm_v;
  assign vector_mem_strided = (instr_i[27:26] == 2'b10);
  assign vector_mem_indexed = (instr_i[27:26] == 2'b01) || (instr_i[27:26] == 2'b11);
  always_comb begin
    if (vector_mem_indexed_q) begin
      case (vector_mem_index_sew_q)
        3'b000: vector_mem_addr = vector_mem_base_q +
                                  {56'd0, vreg[vector_mem_index_reg_q][int'(vector_mem_count_q) * 8 +: 8]};
        3'b001: vector_mem_addr = vector_mem_base_q +
                                  {48'd0, vreg[vector_mem_index_reg_q][int'(vector_mem_count_q) * 16 +: 16]};
        3'b010: vector_mem_addr = vector_mem_base_q +
                                  {32'd0, vreg[vector_mem_index_reg_q][int'(vector_mem_count_q) * 32 +: 32]};
        default: vector_mem_addr = vector_mem_base_q +
                                   vreg[vector_mem_index_reg_q][int'(vector_mem_count_q) * 64 +: 64];
      endcase
    end else if (vector_mem_strided_q)
      vector_mem_addr = vector_mem_base_q +
                        ($signed({59'd0, vector_mem_count_q}) * $signed(vector_mem_stride_q));
    else
      vector_mem_addr = vector_mem_base_q +
                        ({59'd0, vector_mem_count_q} << vector_mem_sew_q);
  end
  assign vector_mem_offset = vector_mem_addr[2:0];
  always_comb begin
    vector_mem_element = '0;
    case (vector_mem_sew_q)
      3'b000: vector_mem_element[7:0] = vreg[vector_mem_vd_q][int'(vector_mem_count_q) * 8 +: 8];
      3'b001: vector_mem_element[15:0] = vreg[vector_mem_vd_q][int'(vector_mem_count_q) * 16 +: 16];
      3'b010: vector_mem_element[31:0] = vreg[vector_mem_vd_q][int'(vector_mem_count_q) * 32 +: 32];
      default: vector_mem_element = vreg[vector_mem_vd_q][int'(vector_mem_count_q) * 64 +: 64];
    endcase
  end
  always_comb begin
    vector_vstart_clear_o = valid_i && advance_i &&
                            ((instr_i[6:0] == 7'b1010111) ||
                             ((is_vle_v || is_vse_v || is_vector_mask_mem) && vector_mem_done_q));
  end
  always_comb begin
    mem_req_o = vector_mem_active_q &&
                (vector_mem_count_q < vector_mem_vl_q) &&
                (vector_mem_mask_q || instr_i[25] || vreg[0][vector_mem_count_q]);
    mem_we_o = vector_mem_store_q;
    mem_addr_o = vector_mem_addr;
    mem_wdata_o = '0;
    mem_wstrb_o = '0;
    case (vector_mem_sew_q)
      3'b000: begin
        mem_wstrb_o = 8'b1 << vector_mem_offset;
        mem_wdata_o = {8{vector_mem_element[7:0]}} << (vector_mem_offset * 8);
      end
      3'b001: begin
        mem_wstrb_o = 8'b11 << vector_mem_offset;
        mem_wdata_o = {4{vector_mem_element[15:0]}} << (vector_mem_offset * 8);
      end
      3'b010: begin
        mem_wstrb_o = 8'h0f << vector_mem_offset;
        mem_wdata_o = {2{vector_mem_element[31:0]}} << (vector_mem_offset * 8);
      end
      default: begin
        mem_wstrb_o = 8'hff;
        mem_wdata_o = vector_mem_element;
      end
    endcase
    mem_busy_o = vector_mem_active_q ||
                 (valid_i && !vector_mem_done_q &&
                  (is_vle_v || is_vse_v || is_vector_mask_mem));
  end

  function automatic logic [63:0] vector_addsub(
    input logic [63:0] operand_a,
    input logic [63:0] operand_b,
    input logic [2:0] sew,
    input logic       subtract
  );
    case (sew)
      3'b000: vector_addsub = subtract ? {56'd0, (operand_a[7:0] - operand_b[7:0])} :
                                        {56'd0, (operand_a[7:0] + operand_b[7:0])};
      3'b001: vector_addsub = subtract ? {48'd0, (operand_a[15:0] - operand_b[15:0])} :
                                        {48'd0, (operand_a[15:0] + operand_b[15:0])};
      3'b010: vector_addsub = subtract ? {32'd0, (operand_a[31:0] - operand_b[31:0])} :
                                        {32'd0, (operand_a[31:0] + operand_b[31:0])};
      default: vector_addsub = subtract ? operand_a - operand_b : operand_a + operand_b;
    endcase
  endfunction

  function automatic logic [63:0] vector_mul_high(
    input logic [63:0] operand_a,
    input logic [63:0] operand_b,
    input logic [2:0] sew,
    input logic [5:0] operation
  );
    logic signed [127:0] signed_a;
    logic signed [127:0] signed_b;
    logic [127:0] unsigned_a;
    logic [127:0] unsigned_b;
    logic signed [127:0] product;
    logic signed_a_enable;
    logic signed_b_enable;
    begin
      case (sew)
        3'b000: begin
          signed_a = {{120{operand_a[7]}}, operand_a[7:0]};
          signed_b = {{120{operand_b[7]}}, operand_b[7:0]};
          unsigned_a = {120'd0, operand_a[7:0]};
          unsigned_b = {120'd0, operand_b[7:0]};
        end
        3'b001: begin
          signed_a = {{112{operand_a[15]}}, operand_a[15:0]};
          signed_b = {{112{operand_b[15]}}, operand_b[15:0]};
          unsigned_a = {112'd0, operand_a[15:0]};
          unsigned_b = {112'd0, operand_b[15:0]};
        end
        3'b010: begin
          signed_a = {{96{operand_a[31]}}, operand_a[31:0]};
          signed_b = {{96{operand_b[31]}}, operand_b[31:0]};
          unsigned_a = {96'd0, operand_a[31:0]};
          unsigned_b = {96'd0, operand_b[31:0]};
        end
        default: begin
          signed_a = {{64{operand_a[63]}}, operand_a};
          signed_b = {{64{operand_b[63]}}, operand_b};
          unsigned_a = {64'd0, operand_a};
          unsigned_b = {64'd0, operand_b};
        end
      endcase
      signed_a_enable = (operation == 6'b100111) || (operation == 6'b100110);
      signed_b_enable = (operation == 6'b100111);
      product = (signed_a_enable ? signed_a : $signed(unsigned_a)) *
                (signed_b_enable ? signed_b : $signed(unsigned_b));
      case (sew)
        3'b000: vector_mul_high = (operation == 6'b100100) ? (product >> 8) : (product >>> 8);
        3'b001: vector_mul_high = (operation == 6'b100100) ? (product >> 16) : (product >>> 16);
        3'b010: vector_mul_high = (operation == 6'b100100) ? (product >> 32) : (product >>> 32);
        default: vector_mul_high = (operation == 6'b100100) ? (product >> 64) : (product >>> 64);
      endcase
    end
  endfunction

  function automatic logic [63:0] vector_divrem(
    input logic [63:0] operand_a,
    input logic [63:0] operand_b,
    input logic [2:0] sew,
    input logic [5:0] operation
  );
    logic [63:0] result;
    begin
      case (sew)
        3'b000: begin
          logic signed [7:0] s_a, s_b, s_res;
          logic [7:0] u_a, u_b, u_res;
          s_a = operand_a[7:0];
          s_b = operand_b[7:0];
          u_a = operand_a[7:0];
          u_b = operand_b[7:0];
          if (operation[0]) begin
            if (s_b == 0) s_res = operation[1] ? s_a : 8'hff;
            else if (s_a == -8'sd128 && s_b == -8'sd1) s_res = operation[1] ? 8'd0 : -8'sd128;
            else s_res = operation[1] ? (s_a % s_b) : (s_a / s_b);
            result = {56'd0, s_res};
          end else begin
            if (u_b == 0) u_res = operation[1] ? u_a : 8'hff;
            else u_res = operation[1] ? (u_a % u_b) : (u_a / u_b);
            result = {56'd0, u_res};
          end
        end
        3'b001: begin
          logic signed [15:0] s_a, s_b, s_res;
          logic [15:0] u_a, u_b, u_res;
          s_a = operand_a[15:0];
          s_b = operand_b[15:0];
          u_a = operand_a[15:0];
          u_b = operand_b[15:0];
          if (operation[0]) begin
            if (s_b == 0) s_res = operation[1] ? s_a : 16'hffff;
            else if (s_a == -16'sd32768 && s_b == -16'sd1) s_res = operation[1] ? 16'd0 : -16'sd32768;
            else s_res = operation[1] ? (s_a % s_b) : (s_a / s_b);
            result = {48'd0, s_res};
          end else begin
            if (u_b == 0) u_res = operation[1] ? u_a : 16'hffff;
            else u_res = operation[1] ? (u_a % u_b) : (u_a / u_b);
            result = {48'd0, u_res};
          end
        end
        3'b010: begin
          logic signed [31:0] s_a, s_b, s_res;
          logic [31:0] u_a, u_b, u_res;
          s_a = operand_a[31:0];
          s_b = operand_b[31:0];
          u_a = operand_a[31:0];
          u_b = operand_b[31:0];
          if (operation[0]) begin
            if (s_b == 0) s_res = operation[1] ? s_a : 32'hffff_ffff;
            else if (s_a == -32'sd2147483648 && s_b == -32'sd1) s_res = operation[1] ? 32'd0 : -32'sd2147483648;
            else s_res = operation[1] ? (s_a % s_b) : (s_a / s_b);
            result = {32'd0, s_res};
          end else begin
            if (u_b == 0) u_res = operation[1] ? u_a : 32'hffff_ffff;
            else u_res = operation[1] ? (u_a % u_b) : (u_a / u_b);
            result = {32'd0, u_res};
          end
        end
        default: begin
          logic signed [63:0] s_a, s_b, s_res;
          logic [63:0] u_a, u_b, u_res;
          s_a = operand_a;
          s_b = operand_b;
          u_a = operand_a;
          u_b = operand_b;
          if (operation[0]) begin
            if (s_b == 0) s_res = operation[1] ? s_a : 64'hffff_ffff_ffff_ffff;
            else if (s_a == -64'sd9223372036854775808 && s_b == -64'sd1) s_res = operation[1] ? 64'd0 : -64'sd9223372036854775808;
            else s_res = operation[1] ? (s_a % s_b) : (s_a / s_b);
            result = s_res;
          end else begin
            if (u_b == 0) u_res = operation[1] ? u_a : 64'hffff_ffff_ffff_ffff;
            else u_res = operation[1] ? (u_a % u_b) : (u_a / u_b);
            result = u_res;
          end
        end
      endcase
      vector_divrem = result;
    end
  endfunction

  function automatic logic [64:0] vector_sat_result(
    input logic [63:0] operand_a,
    input logic [63:0] operand_b,
    input logic [2:0] sew,
    input logic [5:0] operation
  );
    logic signed [127:0] signed_a;
    logic signed [127:0] signed_b;
    logic signed [127:0] signed_result;
    logic [127:0] unsigned_a;
    logic [127:0] unsigned_b;
    logic [127:0] unsigned_result;
    logic signed [127:0] signed_max;
    logic signed [127:0] signed_min;
    logic [127:0] unsigned_max;
    logic signed_mode;
    logic subtract_mode;
    logic saturated;
    logic [63:0] result;
    begin
      case (sew)
        3'b000: begin
          signed_a = {{120{operand_a[7]}}, operand_a[7:0]};
          signed_b = {{120{operand_b[7]}}, operand_b[7:0]};
          unsigned_a = {120'd0, operand_a[7:0]};
          unsigned_b = {120'd0, operand_b[7:0]};
          signed_max = 127;
          signed_min = -128;
          unsigned_max = 255;
        end
        3'b001: begin
          signed_a = {{112{operand_a[15]}}, operand_a[15:0]};
          signed_b = {{112{operand_b[15]}}, operand_b[15:0]};
          unsigned_a = {112'd0, operand_a[15:0]};
          unsigned_b = {112'd0, operand_b[15:0]};
          signed_max = 32767;
          signed_min = -32768;
          unsigned_max = 65535;
        end
        3'b010: begin
          signed_a = {{96{operand_a[31]}}, operand_a[31:0]};
          signed_b = {{96{operand_b[31]}}, operand_b[31:0]};
          unsigned_a = {96'd0, operand_a[31:0]};
          unsigned_b = {96'd0, operand_b[31:0]};
          signed_max = 2147483647;
          signed_min = -128'sd2147483648;
          unsigned_max = 32'hffff_ffff;
        end
        default: begin
          signed_a = {{64{operand_a[63]}}, operand_a};
          signed_b = {{64{operand_b[63]}}, operand_b};
          unsigned_a = {64'd0, operand_a};
          unsigned_b = {64'd0, operand_b};
          signed_max = 128'h7fff_ffff_ffff_ffff;
          signed_min = -128'sd9223372036854775808;
          unsigned_max = 64'hffff_ffff_ffff_ffff;
        end
      endcase
      signed_mode = operation[0];
      subtract_mode = operation[1];
      saturated = 1'b0;
      result = 64'd0;
      if (signed_mode) begin
        signed_result = subtract_mode ? (signed_a - signed_b) : (signed_a + signed_b);
        if (signed_result > signed_max) begin
          result = signed_max[63:0];
          saturated = 1'b1;
        end else if (signed_result < signed_min) begin
          result = signed_min[63:0];
          saturated = 1'b1;
        end else begin
          result = signed_result[63:0];
        end
      end else if (subtract_mode && (unsigned_a < unsigned_b)) begin
        result = 64'd0;
        saturated = 1'b1;
      end else begin
        unsigned_result = subtract_mode ? (unsigned_a - unsigned_b) :
                                          (unsigned_a + unsigned_b);
        if (!subtract_mode && (unsigned_result > unsigned_max)) begin
          result = unsigned_max[63:0];
          saturated = 1'b1;
        end else begin
          result = unsigned_result[63:0];
        end
      end
      vector_sat_result = {saturated, result};
    end
  endfunction

  function automatic logic [63:0] vector_logic(
    input logic [63:0] operand_a,
    input logic [63:0] operand_b,
    input logic [2:0]  sew,
    input logic [5:0]  operation
  );
    case (sew)
      3'b000: begin
        case (operation)
          6'b001001: vector_logic = {56'd0, (operand_a[7:0] & operand_b[7:0])};
          6'b001010: vector_logic = {56'd0, (operand_a[7:0] | operand_b[7:0])};
          default:   vector_logic = {56'd0, (operand_a[7:0] ^ operand_b[7:0])};
        endcase
      end
      3'b001: begin
        case (operation)
          6'b001001: vector_logic = {48'd0, (operand_a[15:0] & operand_b[15:0])};
          6'b001010: vector_logic = {48'd0, (operand_a[15:0] | operand_b[15:0])};
          default:   vector_logic = {48'd0, (operand_a[15:0] ^ operand_b[15:0])};
        endcase
      end
      3'b010: begin
        case (operation)
          6'b001001: vector_logic = {32'd0, (operand_a[31:0] & operand_b[31:0])};
          6'b001010: vector_logic = {32'd0, (operand_a[31:0] | operand_b[31:0])};
          default:   vector_logic = {32'd0, (operand_a[31:0] ^ operand_b[31:0])};
        endcase
      end
      default: begin
        case (operation)
          6'b001001: vector_logic = operand_a & operand_b;
          6'b001010: vector_logic = operand_a | operand_b;
          default:   vector_logic = operand_a ^ operand_b;
        endcase
      end
    endcase
  endfunction

  function automatic logic [63:0] vector_shift(
    input logic [63:0] operand,
    input logic [5:0]  amount,
    input logic [2:0]  sew,
    input logic [5:0]  operation
  );
    case (sew)
      3'b000: begin
        case (operation)
          6'b100101: vector_shift = {56'd0, (operand[7:0] << amount[2:0])};
          6'b101000: vector_shift = {56'd0, (operand[7:0] >> amount[2:0])};
          default:   vector_shift = {56'd0, ($signed(operand[7:0]) >>> amount[2:0])};
        endcase
      end
      3'b001: begin
        case (operation)
          6'b100101: vector_shift = {48'd0, (operand[15:0] << amount[3:0])};
          6'b101000: vector_shift = {48'd0, (operand[15:0] >> amount[3:0])};
          default:   vector_shift = {48'd0, ($signed(operand[15:0]) >>> amount[3:0])};
        endcase
      end
      3'b010: begin
        case (operation)
          6'b100101: vector_shift = {32'd0, (operand[31:0] << amount[4:0])};
          6'b101000: vector_shift = {32'd0, (operand[31:0] >> amount[4:0])};
          default:   vector_shift = {32'd0, ($signed(operand[31:0]) >>> amount[4:0])};
        endcase
      end
      default: begin
        case (operation)
          6'b100101: vector_shift = operand << amount[5:0];
          6'b101000: vector_shift = operand >> amount[5:0];
          default:   vector_shift = $signed(operand) >>> amount[5:0];
        endcase
      end
    endcase
  endfunction

  function automatic logic [63:0] vector_narrow_shift(
    input logic [63:0] operand,
    input logic [5:0]  amount,
    input logic [2:0]  sew,
    input logic        is_arithmetic
  );
    case (sew)
      3'b000: begin
        if (is_arithmetic)
          vector_narrow_shift = {56'd0, 8'($signed(operand[15:0]) >>> amount[3:0])};
        else
          vector_narrow_shift = {56'd0, 8'(operand[15:0] >> amount[3:0])};
      end
      3'b001: begin
        if (is_arithmetic)
          vector_narrow_shift = {48'd0, 16'($signed(operand[31:0]) >>> amount[4:0])};
        else
          vector_narrow_shift = {48'd0, 16'(operand[31:0] >> amount[4:0])};
      end
      3'b010: begin
        if (is_arithmetic)
          vector_narrow_shift = {32'd0, 32'($signed(operand[63:0]) >>> amount[5:0])};
        else
          vector_narrow_shift = {32'd0, 32'(operand[63:0] >> amount[5:0])};
      end
      default: vector_narrow_shift = 64'd0;
    endcase
  endfunction

  function automatic logic [63:0] vector_widen_arith(
    input logic [63:0] op_a,
    input logic [63:0] op_b,
    input logic [2:0]  sew,
    input logic [5:0]  funct6
  );
    case (sew)
      3'b000: begin
        logic [15:0] a_u, b_u;
        logic signed [15:0] a_s, b_s;
        a_u = funct6[2] ? op_a[15:0] : {8'd0, op_a[7:0]};
        a_s = funct6[2] ? $signed(op_a[15:0]) : {{8{op_a[7]}}, op_a[7:0]};
        b_u = {8'd0, op_b[7:0]};
        b_s = {{8{op_b[7]}}, op_b[7:0]};

        case (funct6)
          6'b110000, 6'b110100: vector_widen_arith = {48'd0, 16'(a_u + b_u)};
          6'b110001, 6'b110101: vector_widen_arith = {48'd0, 16'($signed(a_s) + $signed(b_s))};
          6'b110010, 6'b110110: vector_widen_arith = {48'd0, 16'(a_u - b_u)};
          6'b110011, 6'b110111: vector_widen_arith = {48'd0, 16'($signed(a_s) - $signed(b_s))};
          6'b111000:            vector_widen_arith = {48'd0, 16'(op_a[7:0] * op_b[7:0])};
          6'b111010:            vector_widen_arith = {48'd0, 16'($signed(a_s) * $signed({1'b0, op_b[7:0]}))};
          6'b111011:            vector_widen_arith = {48'd0, 16'($signed(op_a[7:0]) * $signed(op_b[7:0]))};
          default:              vector_widen_arith = 64'd0;
        endcase
      end
      3'b001: begin
        logic [31:0] a_u, b_u;
        logic signed [31:0] a_s, b_s;
        a_u = funct6[2] ? op_a[31:0] : {16'd0, op_a[15:0]};
        a_s = funct6[2] ? $signed(op_a[31:0]) : {{16{op_a[15]}}, op_a[15:0]};
        b_u = {16'd0, op_b[15:0]};
        b_s = {{16{op_b[15]}}, op_b[15:0]};

        case (funct6)
          6'b110000, 6'b110100: vector_widen_arith = {32'd0, 32'(a_u + b_u)};
          6'b110001, 6'b110101: vector_widen_arith = {32'd0, 32'($signed(a_s) + $signed(b_s))};
          6'b110010, 6'b110110: vector_widen_arith = {32'd0, 32'(a_u - b_u)};
          6'b110011, 6'b110111: vector_widen_arith = {32'd0, 32'($signed(a_s) - $signed(b_s))};
          6'b111000:            vector_widen_arith = {32'd0, 32'(32'(op_a[15:0]) * 32'(op_b[15:0]))};
          6'b111010:            vector_widen_arith = {32'd0, 32'($signed(a_s) * $signed({1'b0, op_b[15:0]}))};
          6'b111011:            vector_widen_arith = {32'd0, 32'($signed(32'($signed(op_a[15:0]))) * $signed(32'($signed(op_b[15:0]))))};
          default:              vector_widen_arith = 64'd0;
        endcase
      end
      3'b010: begin
        logic [63:0] a_u, b_u;
        logic signed [63:0] a_s, b_s;
        a_u = funct6[2] ? op_a : {32'd0, op_a[31:0]};
        a_s = funct6[2] ? $signed(op_a) : {{32{op_a[31]}}, op_a[31:0]};
        b_u = {32'd0, op_b[31:0]};
        b_s = {{32{op_b[31]}}, op_b[31:0]};

        case (funct6)
          6'b110000, 6'b110100: vector_widen_arith = a_u + b_u;
          6'b110001, 6'b110101: vector_widen_arith = 64'($signed(a_s) + $signed(b_s));
          6'b110010, 6'b110110: vector_widen_arith = a_u - b_u;
          6'b110011, 6'b110111: vector_widen_arith = 64'($signed(a_s) - $signed(b_s));
          6'b111000:            vector_widen_arith = 64'(op_a[31:0]) * 64'(op_b[31:0]);
          6'b111010:            vector_widen_arith = 64'($signed(a_s) * $signed({1'b0, op_b[31:0]}));
          6'b111011:            vector_widen_arith = 64'($signed(64'($signed(op_a[31:0]))) * $signed(64'($signed(op_b[31:0]))));
          default:              vector_widen_arith = 64'd0;
        endcase
      end
      default: vector_widen_arith = 64'd0;
    endcase
  endfunction

  function automatic logic [63:0] vector_widen_macc(
    input logic [63:0] op_acc,
    input logic [63:0] op_vs2,
    input logic [63:0] op_vs1,
    input logic [2:0]  sew,
    input logic [5:0]  funct6,
    input logic        is_vx
  );
    case (sew)
      3'b000: begin
        logic signed [15:0] vs2_s, vs1_s;
        logic signed [15:0] vs2_u, vs1_u;
        vs2_s = {{8{op_vs2[7]}}, op_vs2[7:0]};
        vs1_s = {{8{op_vs1[7]}}, op_vs1[7:0]};
        vs2_u = {8'd0, op_vs2[7:0]};
        vs1_u = {8'd0, op_vs1[7:0]};
        case (funct6)
          6'b111100: vector_widen_macc = {48'd0, 16'(op_acc[15:0] + 16'(op_vs2[7:0] * op_vs1[7:0]))};
          6'b111101: vector_widen_macc = {48'd0, 16'(op_acc[15:0] + 16'(vs2_s * vs1_s))};
          6'b111110: vector_widen_macc = {48'd0, 16'(op_acc[15:0] + 16'(vs1_s * vs2_u))};
          6'b111111: vector_widen_macc = {48'd0, 16'(op_acc[15:0] + 16'(vs2_s * vs1_u))};
          default:   vector_widen_macc = 64'd0;
        endcase
      end
      3'b001: begin
        logic signed [31:0] vs2_s, vs1_s;
        logic signed [31:0] vs2_u, vs1_u;
        vs2_s = {{16{op_vs2[15]}}, op_vs2[15:0]};
        vs1_s = {{16{op_vs1[15]}}, op_vs1[15:0]};
        vs2_u = {16'd0, op_vs2[15:0]};
        vs1_u = {16'd0, op_vs1[15:0]};
        case (funct6)
          6'b111100: vector_widen_macc = {32'd0, 32'(op_acc[31:0] + 32'(32'(op_vs2[15:0]) * 32'(op_vs1[15:0])))};
          6'b111101: vector_widen_macc = {32'd0, 32'(op_acc[31:0] + 32'(vs2_s * vs1_s))};
          6'b111110: vector_widen_macc = {32'd0, 32'(op_acc[31:0] + 32'(vs1_s * vs2_u))};
          6'b111111: vector_widen_macc = {32'd0, 32'(op_acc[31:0] + 32'(vs2_s * vs1_u))};
          default:   vector_widen_macc = 64'd0;
        endcase
      end
      3'b010: begin
        logic signed [63:0] vs2_s, vs1_s;
        logic signed [63:0] vs2_u, vs1_u;
        vs2_s = {{32{op_vs2[31]}}, op_vs2[31:0]};
        vs1_s = {{32{op_vs1[31]}}, op_vs1[31:0]};
        vs2_u = {32'd0, op_vs2[31:0]};
        vs1_u = {32'd0, op_vs1[31:0]};
        case (funct6)
          6'b111100: vector_widen_macc = op_acc + (64'(op_vs2[31:0]) * 64'(op_vs1[31:0]));
          6'b111101: vector_widen_macc = op_acc + 64'(vs2_s * vs1_s);
          6'b111110: vector_widen_macc = op_acc + 64'(vs1_s * vs2_u);
          6'b111111: vector_widen_macc = op_acc + 64'(vs2_s * vs1_u);
          default:   vector_widen_macc = 64'd0;
        endcase
      end
      default: vector_widen_macc = 64'd0;
    endcase
  endfunction

  function automatic logic [63:0] vector_int_ext_source(
    input logic [127:0] source,
    input integer       index,
    input logic [2:0]   sew,
    input logic [4:0]   ext_type
  );
    case (ext_type[2:1])
      2'b11: begin // vf2
        case (sew)
          3'b001: vector_int_ext_source = {56'd0, source[index*8 +: 8]};
          3'b010: vector_int_ext_source = {48'd0, source[index*16 +: 16]};
          default: vector_int_ext_source = {32'd0, source[index*32 +: 32]};
        endcase
      end
      2'b10: begin // vf4
        case (sew)
          3'b010: vector_int_ext_source = {56'd0, source[index*8 +: 8]};
          default: vector_int_ext_source = {48'd0, source[index*16 +: 16]};
        endcase
      end
      default: begin // vf8
        vector_int_ext_source = {56'd0, source[index*8 +: 8]};
      end
    endcase
  endfunction

  function automatic logic [63:0] vector_int_ext(
    input logic [63:0] op_source,
    input logic [2:0]  sew,
    input logic [4:0]  ext_type
  );
    logic is_signed;
    is_signed = ext_type[0];
    case (sew)
      3'b001: begin // e16 (vf2: source is e8)
        vector_int_ext = is_signed ?
          {48'd0, 16'($signed(op_source[7:0]))} :
          {48'd0, 16'(op_source[7:0])};
      end
      3'b010: begin // e32
        if (ext_type[2:1] == 2'b11) begin // vf2: source is e16
          vector_int_ext = is_signed ?
            {32'd0, 32'($signed(op_source[15:0]))} :
            {32'd0, 32'(op_source[15:0])};
        end else begin // vf4: source is e8
          vector_int_ext = is_signed ?
            {32'd0, 32'($signed(op_source[7:0]))} :
            {32'd0, 32'(op_source[7:0])};
        end
      end
      3'b011: begin // e64
        if (ext_type[2:1] == 2'b11) begin // vf2: source is e32
          vector_int_ext = is_signed ?
            64'($signed(op_source[31:0])) :
            64'(op_source[31:0]);
        end else if (ext_type[2:1] == 2'b10) begin // vf4: source is e16
          vector_int_ext = is_signed ?
            64'($signed(op_source[15:0])) :
            64'(op_source[15:0]);
        end else begin // vf8: source is e8
          vector_int_ext = is_signed ?
            64'($signed(op_source[7:0])) :
            64'(op_source[7:0]);
        end
      end
      default: vector_int_ext = 64'd0;
    endcase
  endfunction

  function automatic logic vector_compare(
    input logic [63:0] operand_a,
    input logic [63:0] operand_b,
    input logic [2:0]  sew,
    input logic [5:0]  operation
  );
    logic [63:0] unsigned_a;
    logic [63:0] unsigned_b;
    logic signed [63:0] signed_a;
    logic signed [63:0] signed_b;
    begin
      case (sew)
        3'b000: begin
          unsigned_a = {56'd0, operand_a[7:0]};
          unsigned_b = {56'd0, operand_b[7:0]};
          signed_a = {{56{operand_a[7]}}, operand_a[7:0]};
          signed_b = {{56{operand_b[7]}}, operand_b[7:0]};
        end
        3'b001: begin
          unsigned_a = {48'd0, operand_a[15:0]};
          unsigned_b = {48'd0, operand_b[15:0]};
          signed_a = {{48{operand_a[15]}}, operand_a[15:0]};
          signed_b = {{48{operand_b[15]}}, operand_b[15:0]};
        end
        3'b010: begin
          unsigned_a = {32'd0, operand_a[31:0]};
          unsigned_b = {32'd0, operand_b[31:0]};
          signed_a = {{32{operand_a[31]}}, operand_a[31:0]};
          signed_b = {{32{operand_b[31]}}, operand_b[31:0]};
        end
        default: begin
          unsigned_a = operand_a;
          unsigned_b = operand_b;
          signed_a = operand_a;
          signed_b = operand_b;
        end
      endcase
      case (operation)
        6'b011000: vector_compare = unsigned_a == unsigned_b;
        6'b011001: vector_compare = unsigned_a != unsigned_b;
        6'b011010: vector_compare = unsigned_a < unsigned_b;
        6'b011011: vector_compare = signed_a < signed_b;
        6'b011100: vector_compare = unsigned_a <= unsigned_b;
        6'b011101: vector_compare = signed_a <= signed_b;
        6'b011110: vector_compare = unsigned_a > unsigned_b;
        default:   vector_compare = signed_a > signed_b;
      endcase
    end
  endfunction

  function automatic logic [63:0] vector_minmax(
    input logic [63:0] operand_a,
    input logic [63:0] operand_b,
    input logic [2:0]  sew,
    input logic [5:0]  operation
  );
    logic choose_a;
    begin
      case (sew)
        3'b000: begin
          case (operation)
            6'b000100: choose_a = operand_a[7:0] < operand_b[7:0];
            6'b000101: choose_a = $signed(operand_a[7:0]) < $signed(operand_b[7:0]);
            6'b000110: choose_a = operand_a[7:0] > operand_b[7:0];
            default:   choose_a = $signed(operand_a[7:0]) > $signed(operand_b[7:0]);
          endcase
          vector_minmax = choose_a ? {56'd0, operand_a[7:0]} : {56'd0, operand_b[7:0]};
        end
        3'b001: begin
          case (operation)
            6'b000100: choose_a = operand_a[15:0] < operand_b[15:0];
            6'b000101: choose_a = $signed(operand_a[15:0]) < $signed(operand_b[15:0]);
            6'b000110: choose_a = operand_a[15:0] > operand_b[15:0];
            default:   choose_a = $signed(operand_a[15:0]) > $signed(operand_b[15:0]);
          endcase
          vector_minmax = choose_a ? {48'd0, operand_a[15:0]} : {48'd0, operand_b[15:0]};
        end
        3'b010: begin
          case (operation)
            6'b000100: choose_a = operand_a[31:0] < operand_b[31:0];
            6'b000101: choose_a = $signed(operand_a[31:0]) < $signed(operand_b[31:0]);
            6'b000110: choose_a = operand_a[31:0] > operand_b[31:0];
            default:   choose_a = $signed(operand_a[31:0]) > $signed(operand_b[31:0]);
          endcase
          vector_minmax = choose_a ? {32'd0, operand_a[31:0]} : {32'd0, operand_b[31:0]};
        end
        default: begin
          case (operation)
            6'b000100: choose_a = operand_a < operand_b;
            6'b000101: choose_a = $signed(operand_a) < $signed(operand_b);
            6'b000110: choose_a = operand_a > operand_b;
            default:   choose_a = $signed(operand_a) > $signed(operand_b);
          endcase
          vector_minmax = choose_a ? operand_a : operand_b;
        end
      endcase
    end
  endfunction

  function automatic logic [63:0] vector_element(
    input logic [127:0] source,
    input logic [4:0]   index,
    input logic [2:0]   sew
  );
    case (sew)
      3'b000: vector_element = {56'd0, source[int'(index) * 8 +: 8]};
      3'b001: vector_element = {48'd0, source[int'(index) * 16 +: 16]};
      3'b010: vector_element = {32'd0, source[int'(index) * 32 +: 32]};
      default: vector_element = source[int'(index) * 64 +: 64];
    endcase
  endfunction

  function automatic logic [63:0] vector_fp_int_cvt_operand(
    input logic [127:0] source,
    input logic [4:0]   index,
    input logic [2:0]   sew,
    input logic         box_single
  );
    logic [63:0] element;
    begin
      element = vector_element(source, index, sew);
      vector_fp_int_cvt_operand = (box_single && (sew == 3'b010)) ?
                                  {32'hffff_ffff, element[31:0]} : element;
    end
  endfunction

  function automatic logic [63:0] f32_to_f64(input logic [31:0] f32_val);
    logic sign;
    logic [7:0] exp32;
    logic [22:0] frac32;
    logic is_nan;
    logic is_inf;
    logic is_zero;
    integer source_top;
    integer source_exponent;
    logic [23:0] shifted_frac;
    logic [10:0] exp_field;
    begin
      sign = f32_val[31];
      exp32 = f32_val[30:23];
      frac32 = f32_val[22:0];
      is_nan = (exp32 == 8'hff) && (frac32 != 23'd0);
      is_inf = (exp32 == 8'hff) && (frac32 == 23'd0);
      is_zero = (exp32 == 8'd0) && (frac32 == 23'd0);
      source_top = 0;
      shifted_frac = 24'd0;

      if (is_nan) begin
        f32_to_f64 = {sign, 11'h7ff, 1'b1, frac32[21:0], 29'd0};
      end else if (is_inf) begin
        f32_to_f64 = {sign, 11'h7ff, 52'd0};
      end else if (is_zero) begin
        f32_to_f64 = {sign, 63'd0};
      end else if (exp32 == 8'd0) begin
        for (int i = 0; i < 23; i++) begin
          if (frac32[i]) source_top = i;
        end
        source_exponent = source_top - 149;
        shifted_frac = {1'b0, frac32} << (23 - source_top);
        exp_field = source_exponent + 1023;
        f32_to_f64 = {sign, exp_field, shifted_frac[22:0], 29'd0};
      end else begin
        source_exponent = integer'(exp32) - 127;
        exp_field = source_exponent + 1023;
        f32_to_f64 = {sign, exp_field, frac32, 29'd0};
      end
    end
  endfunction

  function automatic logic [63:0] vector_permute_element(
    input logic [127:0] source,
    input logic [127:0] indices,
    input logic [4:0] destination_index,
    input logic [4:0] active_length,
    input logic [2:0] sew,
    input logic [5:0] funct6,
    input logic [2:0] funct3,
    input logic [63:0] scalar,
    input logic [4:0] immediate
  );
    integer source_index;
    integer vlmax_value;
    logic [63:0] gather_index;
    begin
      vlmax_value = 16 >> sew;
      source_index = 0;
      gather_index = 64'd0;
      vector_permute_element = 64'd0;
      if (funct6 == 6'b001100) begin
        case (funct3)
          3'b000: gather_index = vector_element(indices, destination_index, sew);
          3'b100: gather_index = scalar;
          default: gather_index = {59'd0, immediate};
        endcase
        if (gather_index < vlmax_value)
          vector_permute_element = vector_element(source, gather_index[4:0], sew);
      end else if (funct6 == 6'b001110) begin
        if (funct3 == 3'b110) begin
          if (destination_index == 0)
            vector_permute_element = scalar;
          else
            vector_permute_element = vector_element(source, destination_index - 1'b1, sew);
        end else begin
          source_index = int'(destination_index) - int'(scalar[4:0]);
          if (funct3 == 3'b011)
            source_index = int'(destination_index) - int'(immediate);
          if (source_index >= 0 && source_index < vlmax_value)
            vector_permute_element = vector_element(source, source_index[4:0], sew);
        end
      end else if (funct6 == 6'b001111) begin
        if (funct3 == 3'b110) begin
          if (destination_index == (active_length - 1'b1))
            vector_permute_element = scalar;
          else if (destination_index + 1 < vlmax_value)
            vector_permute_element = vector_element(source, destination_index + 1'b1, sew);
        end else begin
          source_index = int'(destination_index) + int'(scalar[4:0]);
          if (funct3 == 3'b100 && scalar >= vlmax_value)
            source_index = vlmax_value;
          else if (funct3 == 3'b011)
            source_index = int'(destination_index) + int'(immediate);
          if (source_index >= 0 && source_index < vlmax_value)
            vector_permute_element = vector_element(source, source_index[4:0], sew);
        end
      end
    end
  endfunction

  assign is_vsetvli = (instr_i[6:0] == 7'b1010111) && (instr_i[14:12] == 3'b111);
  assign is_vsetivli = (instr_i[6:0] == 7'b1010111) && (instr_i[14:12] == 3'b111) &&
                       (instr_i[31:30] == 2'b11);
  assign is_vset_config = is_vsetivli || (is_vsetvli && !instr_i[31]);
  assign is_vmv_x_s = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b010000) &&
                      instr_i[25] && (instr_i[14:12] == 3'b010) && (instr_i[19:15] == 5'd0);
  assign is_vmask_prefix = (instr_i[6:0] == 7'b1010111) &&
                           (instr_i[31:26] == 6'b010100) &&
                           (instr_i[14:12] == 3'b010) &&
                           ((instr_i[19:15] == 5'd1) ||
                            (instr_i[19:15] == 5'd2) ||
                            (instr_i[19:15] == 5'd3));
  assign is_vmask_query = (instr_i[6:0] == 7'b1010111) &&
                          (instr_i[31:26] == 6'b010000) &&
                          (instr_i[14:12] == 3'b010) &&
                          ((instr_i[19:15] == 5'b10000) ||
                           (instr_i[19:15] == 5'b10001));
  assign is_vmv_v_x = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b010111) &&
                      instr_i[25] && (instr_i[14:12] == 3'b100) && (instr_i[24:20] == 5'd0);
  assign is_vadd_vv = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b000000) &&
                      (instr_i[14:12] == 3'b000);
  assign is_vadd_vx = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b000000) &&
                      ((instr_i[14:12] == 3'b100) || (instr_i[14:12] == 3'b011));
  assign is_vmul_vv = (instr_i[6:0] == 7'b1010111) &&
                      (instr_i[31:26] == 6'b100101) && (instr_i[14:12] == 3'b010);
  assign is_vmul_vx = (instr_i[6:0] == 7'b1010111) &&
                      (instr_i[31:26] == 6'b100101) && (instr_i[14:12] == 3'b110);
  assign is_vmulh_vv = (instr_i[6:0] == 7'b1010111) &&
                       (instr_i[31:26] == 6'b100111) && (instr_i[14:12] == 3'b010);
  assign is_vmulh_vx = (instr_i[6:0] == 7'b1010111) &&
                       (instr_i[31:26] == 6'b100111) && (instr_i[14:12] == 3'b110);
  assign is_vmulhu_vv = (instr_i[6:0] == 7'b1010111) &&
                        (instr_i[31:26] == 6'b100100) && (instr_i[14:12] == 3'b010);
  assign is_vmulhu_vx = (instr_i[6:0] == 7'b1010111) &&
                        (instr_i[31:26] == 6'b100100) && (instr_i[14:12] == 3'b110);
  assign is_vmulhsu_vv = (instr_i[6:0] == 7'b1010111) &&
                         (instr_i[31:26] == 6'b100110) && (instr_i[14:12] == 3'b010);
  assign is_vmulhsu_vx = (instr_i[6:0] == 7'b1010111) &&
                         (instr_i[31:26] == 6'b100110) && (instr_i[14:12] == 3'b110);
  assign is_vdivrem_vv = (instr_i[6:0] == 7'b1010111) &&
                         (instr_i[31:28] == 4'b1000) && (instr_i[14:12] == 3'b010);
  assign is_vdivrem_vx = (instr_i[6:0] == 7'b1010111) &&
                         (instr_i[31:28] == 4'b1000) && (instr_i[14:12] == 3'b110);
  assign is_vsat_vv = (instr_i[6:0] == 7'b1010111) &&
                      (instr_i[31:28] == 4'b1000) && (instr_i[14:12] == 3'b000);
  assign is_vsat_vx = (instr_i[6:0] == 7'b1010111) &&
                      (instr_i[31:28] == 4'b1000) && (instr_i[14:12] == 3'b100);
  assign is_vector_sat = is_vsat_vv || is_vsat_vx;
  assign is_vsub_vv = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b000010) &&
                      (instr_i[14:12] == 3'b000);
  assign is_vsub_vx = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b000010) &&
                      (instr_i[14:12] == 3'b100);
  assign is_vlogic = (instr_i[6:0] == 7'b1010111) &&
                     ((instr_i[31:26] == 6'b001001) ||
                      (instr_i[31:26] == 6'b001010) ||
                      (instr_i[31:26] == 6'b001011)) &&
                     ((instr_i[14:12] == 3'b000) || (instr_i[14:12] == 3'b100) ||
                      (instr_i[14:12] == 3'b011));
  assign is_vshift = (instr_i[6:0] == 7'b1010111) &&
                     ((instr_i[31:26] == 6'b100101) ||
                      (instr_i[31:26] == 6'b101000) ||
                      (instr_i[31:26] == 6'b101001)) &&
                     ((instr_i[14:12] == 3'b000) || (instr_i[14:12] == 3'b100) ||
                      (instr_i[14:12] == 3'b011));
  assign is_vector_narrow_shift = (instr_i[6:0] == 7'b1010111) &&
                                  ((instr_i[31:26] == 6'b101100) ||
                                   (instr_i[31:26] == 6'b101101)) &&
                                  ((instr_i[14:12] == 3'b000) ||
                                   (instr_i[14:12] == 3'b100) ||
                                   (instr_i[14:12] == 3'b011)) &&
                                  (vsew_q != 3'b011);
  assign is_vcompare = (instr_i[6:0] == 7'b1010111) &&
                       ((instr_i[31:26] == 6'b011000) ||
                        (instr_i[31:26] == 6'b011001) ||
                        (instr_i[31:26] == 6'b011010) ||
                        (instr_i[31:26] == 6'b011011)) &&
                       ((instr_i[14:12] == 3'b000) || (instr_i[14:12] == 3'b100)) ||
                       ((instr_i[6:0] == 7'b1010111) &&
                        ((instr_i[31:26] == 6'b011100) ||
                         (instr_i[31:26] == 6'b011101)) &&
                        ((instr_i[14:12] == 3'b000) || (instr_i[14:12] == 3'b100))) ||
                       ((instr_i[6:0] == 7'b1010111) &&
                        ((instr_i[31:26] == 6'b011110) ||
                         (instr_i[31:26] == 6'b011111)) &&
                        ((instr_i[14:12] == 3'b100) || (instr_i[14:12] == 3'b011)));
  assign is_vector_fp_scalar_form = instr_i[14:12] == 3'b101;
  assign is_vector_fp_compare = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                                ((instr_i[31:26] == 6'b011000) ||
                                 (instr_i[31:26] == 6'b011001) ||
                                 (instr_i[31:26] == 6'b011011) ||
                                 (instr_i[31:26] == 6'b011100)) &&
                                ((instr_i[14:12] == 3'b001) || is_vector_fp_scalar_form) &&
                                ((vsew_q == 3'b010) || (vsew_q == 3'b011));
  assign is_vector_fp_not_equal = instr_i[31:26] == 6'b011100;
  assign is_vector_fp_minmax = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                               ((instr_i[31:26] == 6'b000100) ||
                                (instr_i[31:26] == 6'b000110)) &&
                               ((instr_i[14:12] == 3'b001) || is_vector_fp_scalar_form) &&
                               ((vsew_q == 3'b010) || (vsew_q == 3'b011));
  assign is_vector_fp_signinj = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                                ((instr_i[31:26] == 6'b001000) ||
                                 (instr_i[31:26] == 6'b001001) ||
                                 (instr_i[31:26] == 6'b001010)) &&
                                ((instr_i[14:12] == 3'b001) || is_vector_fp_scalar_form) &&
                                ((vsew_q == 3'b010) || (vsew_q == 3'b011));
  assign is_vminmax = (instr_i[6:0] == 7'b1010111) &&
                      ((instr_i[31:26] == 6'b000100) ||
                       (instr_i[31:26] == 6'b000101) ||
                       (instr_i[31:26] == 6'b000110) ||
                       (instr_i[31:26] == 6'b000111)) &&
                      ((instr_i[14:12] == 3'b000) || (instr_i[14:12] == 3'b100));
  assign is_vmask_logic = (instr_i[6:0] == 7'b1010111) && (instr_i[25]) &&
                          (instr_i[14:12] == 3'b010) &&
                          ((instr_i[31:26] == 6'b011000) ||
                           (instr_i[31:26] == 6'b011001) ||
                           (instr_i[31:26] == 6'b011010) ||
                           (instr_i[31:26] == 6'b011011) ||
                           (instr_i[31:26] == 6'b011100) ||
                           (instr_i[31:26] == 6'b011101) ||
                           (instr_i[31:26] == 6'b011110) ||
                           (instr_i[31:26] == 6'b011111));
  assign is_vector_reduction = (instr_i[6:0] == 7'b1010111) &&
                               (instr_i[14:12] == 3'b010) &&
                               (instr_i[31:29] == 3'b000);
  assign is_vector_widen_reduction = (instr_i[6:0] == 7'b1010111) &&
                                     (instr_i[14:12] == 3'b000) &&
                                     ((instr_i[31:26] == 6'b110000) ||
                                      (instr_i[31:26] == 6'b110001));
  assign is_vector_int_widen_arith = (instr_i[6:0] == 7'b1010111) &&
                                     ((instr_i[14:12] == 3'b010) || (instr_i[14:12] == 3'b110)) &&
                                     ((instr_i[31:26] == 6'b110000) ||
                                      (instr_i[31:26] == 6'b110001) ||
                                      (instr_i[31:26] == 6'b110010) ||
                                      (instr_i[31:26] == 6'b110011) ||
                                      (instr_i[31:26] == 6'b110100) ||
                                      (instr_i[31:26] == 6'b110101) ||
                                      (instr_i[31:26] == 6'b110110) ||
                                      (instr_i[31:26] == 6'b110111) ||
                                      (instr_i[31:26] == 6'b111000) ||
                                      (instr_i[31:26] == 6'b111010) ||
                                      (instr_i[31:26] == 6'b111011)) &&
                                     (vsew_q != 3'b011);
  assign is_vector_int_widen_macc = (instr_i[6:0] == 7'b1010111) &&
                                    (((instr_i[14:12] == 3'b010) &&
                                      ((instr_i[31:26] == 6'b111100) ||
                                       (instr_i[31:26] == 6'b111101) ||
                                       (instr_i[31:26] == 6'b111111))) ||
                                     ((instr_i[14:12] == 3'b110) &&
                                      ((instr_i[31:26] == 6'b111100) ||
                                       (instr_i[31:26] == 6'b111101) ||
                                       (instr_i[31:26] == 6'b111110) ||
                                       (instr_i[31:26] == 6'b111111)))) &&
                                    (vsew_q != 3'b011);
  assign is_vector_int_ext = (instr_i[6:0] == 7'b1010111) &&
                             (instr_i[31:26] == 6'b010010) &&
                             (instr_i[14:12] == 3'b010) &&
                             ((((instr_i[19:15] == 5'b00110) || (instr_i[19:15] == 5'b00111)) && (vsew_q != 3'b000)) ||
                              (((instr_i[19:15] == 5'b00100) || (instr_i[19:15] == 5'b00101)) && ((vsew_q == 3'b010) || (vsew_q == 3'b011))) ||
                              (((instr_i[19:15] == 5'b00010) || (instr_i[19:15] == 5'b00011)) && (vsew_q == 3'b011)));
  assign is_vector_fp_addsub = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                               ((instr_i[31:26] == 6'b000000) ||
                                (instr_i[31:26] == 6'b000010)) &&
                               ((instr_i[14:12] == 3'b001) || is_vector_fp_scalar_form) &&
                               ((vsew_q == 3'b010) || (vsew_q == 3'b011));
  assign is_vector_fp_mul = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                            (instr_i[31:26] == 6'b100100) &&
                            ((instr_i[14:12] == 3'b001) || is_vector_fp_scalar_form) &&
                            ((vsew_q == 3'b010) || (vsew_q == 3'b011));
  assign is_vector_fp_div = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                            (instr_i[31:26] == 6'b100000) &&
                            ((instr_i[14:12] == 3'b001) || is_vector_fp_scalar_form) &&
                            ((vsew_q == 3'b010) || (vsew_q == 3'b011));
  assign is_vector_fp_sqrt = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                             (instr_i[31:26] == 6'b010011) &&
                             (instr_i[19:15] == 5'b00000) &&
                             (instr_i[14:12] == 3'b001) &&
                             ((vsew_q == 3'b010) || (vsew_q == 3'b011));
  assign is_vector_fp_class = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                              (instr_i[31:26] == 6'b010011) &&
                              (instr_i[19:15] == 5'b10000) &&
                              (instr_i[14:12] == 3'b001) &&
                              ((vsew_q == 3'b010) || (vsew_q == 3'b011));
  assign is_vector_fp_int_cvt = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                                (instr_i[31:26] == 6'b010010) &&
                                (instr_i[14:12] == 3'b001) &&
                                ((((instr_i[19:15] == 5'd0) ||
                                   (instr_i[19:15] == 5'd1) ||
                                   (instr_i[19:15] == 5'd2) ||
                                   (instr_i[19:15] == 5'd3) ||
                                   (instr_i[19:15] == 5'd6) ||
                                   (instr_i[19:15] == 5'd7)) &&
                                  ((vsew_q == 3'b010) || (vsew_q == 3'b011))) ||
                                 (((instr_i[19:15] == 5'd8) ||
                                   (instr_i[19:15] == 5'd9) ||
                                   (instr_i[19:15] == 5'd10) ||
                                   (instr_i[19:15] == 5'd11) ||
                                   (instr_i[19:15] == 5'd14) ||
                                   (instr_i[19:15] == 5'd15)) &&
                                  (vsew_q == 3'b010)) ||
                                 (((instr_i[19:15] == 5'd16) ||
                                   (instr_i[19:15] == 5'd17) ||
                                   (instr_i[19:15] == 5'd18) ||
                                   (instr_i[19:15] == 5'd19) ||
                                   (instr_i[19:15] == 5'd22) ||
                                   (instr_i[19:15] == 5'd23)) &&
                                  (vsew_q == 3'b010)));
  assign is_vector_fp_widen_cvt = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                                  (instr_i[31:26] == 6'b010010) &&
                                  ((instr_i[19:15] == 5'd8) ||
                                   (instr_i[19:15] == 5'd9) ||
                                   (instr_i[19:15] == 5'd10) ||
                                   (instr_i[19:15] == 5'd11) ||
                                   (instr_i[19:15] == 5'd14) ||
                                   (instr_i[19:15] == 5'd15)) &&
                                  (instr_i[14:12] == 3'b001) &&
                                  (vsew_q == 3'b010);
  assign is_vector_fp_widen_float_cvt = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                                        (instr_i[31:26] == 6'b010010) &&
                                        (instr_i[19:15] == 5'd12) &&
                                        (instr_i[14:12] == 3'b001) &&
                                        (vsew_q == 3'b010);
  assign is_vector_fp_widen_addsub = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                                     ((instr_i[14:12] == 3'b001) || is_vector_fp_scalar_form) &&
                                     ((instr_i[31:26] == 6'b110000) ||
                                      (instr_i[31:26] == 6'b110010) ||
                                      (instr_i[31:26] == 6'b110100) ||
                                      (instr_i[31:26] == 6'b110110)) &&
                                     (vsew_q == 3'b010);
  assign is_vector_fp_widen_mul = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                                  ((instr_i[14:12] == 3'b001) || is_vector_fp_scalar_form) &&
                                  (instr_i[31:26] == 6'b111000) &&
                                  (vsew_q == 3'b010);
  assign is_vector_fp_widen_arith = is_vector_fp_widen_addsub || is_vector_fp_widen_mul;
  assign is_vector_fp_widen_mac = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                                  ((instr_i[14:12] == 3'b001) || is_vector_fp_scalar_form) &&
                                  ((instr_i[31:26] == 6'b111100) ||
                                   (instr_i[31:26] == 6'b111101) ||
                                   (instr_i[31:26] == 6'b111110) ||
                                   (instr_i[31:26] == 6'b111111)) &&
                                  (vsew_q == 3'b010);
  assign is_vector_fp_widen_op = is_vector_fp_widen_cvt || is_vector_fp_widen_float_cvt || is_vector_fp_widen_arith || is_vector_fp_widen_mac;
  assign is_vector_fp_narrow_cvt = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                                   (instr_i[31:26] == 6'b010010) &&
                                   ((instr_i[19:15] == 5'd16) ||
                                    (instr_i[19:15] == 5'd17) ||
                                    (instr_i[19:15] == 5'd18) ||
                                    (instr_i[19:15] == 5'd19) ||
                                    (instr_i[19:15] == 5'd22) ||
                                    (instr_i[19:15] == 5'd23)) &&
                                   (instr_i[14:12] == 3'b001) &&
                                   (vsew_q == 3'b010);
  assign is_vector_fp_narrow_float_cvt = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                                         (instr_i[31:26] == 6'b010010) &&
                                         ((instr_i[19:15] == 5'd20) ||
                                          (instr_i[19:15] == 5'd21)) &&
                                         (instr_i[14:12] == 3'b001) &&
                                         (vsew_q == 3'b010);
  assign is_vector_fp_narrow_op = is_vector_fp_narrow_cvt || is_vector_fp_narrow_float_cvt;
  assign is_vector_fp_mac = ENABLE_VECTOR_FP && (instr_i[6:0] == 7'b1010111) &&
                            ((instr_i[31:26] == 6'b101000) ||
                             (instr_i[31:26] == 6'b101001) ||
                             (instr_i[31:26] == 6'b101010) ||
                             (instr_i[31:26] == 6'b101011) ||
                             (instr_i[31:26] == 6'b101100) ||
                             (instr_i[31:26] == 6'b101101) ||
                             (instr_i[31:26] == 6'b101110) ||
                             (instr_i[31:26] == 6'b101111)) &&
                            ((instr_i[14:12] == 3'b001) || is_vector_fp_scalar_form) &&
                            ((vsew_q == 3'b010) || (vsew_q == 3'b011));
  assign is_vector_fp_fma_dest_mult = (instr_i[31:29] == 3'b101) &&
                                      !instr_i[28];
  always_comb begin
    case (instr_i[31:26])
      6'b101010, 6'b101110, 6'b111110: vector_fp_mac_opcode = 7'b1000111;
      6'b101001, 6'b101111, 6'b111111: vector_fp_mac_opcode = 7'b1001011;
      6'b101011, 6'b101101, 6'b111101: vector_fp_mac_opcode = 7'b1001111;
      default:                         vector_fp_mac_opcode = 7'b1000011;
    endcase
  end
  assign is_vector_fp_op = is_vector_fp_addsub || is_vector_fp_mul ||
                           is_vector_fp_div || is_vector_fp_sqrt || is_vector_fp_mac;
  assign is_vslideup = (instr_i[6:0] == 7'b1010111) &&
                       (instr_i[31:26] == 6'b001110) &&
                       ((instr_i[14:12] == 3'b100) || (instr_i[14:12] == 3'b011));
  assign is_vslidedown = (instr_i[6:0] == 7'b1010111) &&
                         (instr_i[31:26] == 6'b001111) &&
                         ((instr_i[14:12] == 3'b100) || (instr_i[14:12] == 3'b011));
  assign is_vslide1up = (instr_i[6:0] == 7'b1010111) &&
                        (instr_i[31:26] == 6'b001110) &&
                        (instr_i[14:12] == 3'b110);
  assign is_vslide1down = (instr_i[6:0] == 7'b1010111) &&
                          (instr_i[31:26] == 6'b001111) &&
                          (instr_i[14:12] == 3'b110);
  assign is_vrgather = (instr_i[6:0] == 7'b1010111) &&
                       (instr_i[31:26] == 6'b001100) &&
                       ((instr_i[14:12] == 3'b000) ||
                        (instr_i[14:12] == 3'b100) ||
                        (instr_i[14:12] == 3'b011));
  assign is_vector_permute = is_vslideup || is_vslidedown || is_vslide1up ||
                             is_vslide1down || is_vrgather;
  assign vector_perm_offset = (instr_i[14:12] == 3'b011) ?
                              {59'd0, instr_i[19:15]} : scalar_rs1_i;
  assign is_vector_data_op = is_vmv_v_x || is_vadd_vv || is_vadd_vx ||
                             is_vmul_vv || is_vmul_vx ||
                             is_vmulh_vv || is_vmulh_vx || is_vmulhu_vv ||
                             is_vmulhu_vx || is_vmulhsu_vv || is_vmulhsu_vx ||
                             is_vdivrem_vv || is_vdivrem_vx ||
                             is_vector_sat || is_vector_fp_op || is_vector_fp_class ||
                             is_vector_fp_int_cvt || is_vector_fp_minmax ||
                             is_vector_fp_widen_op || is_vector_fp_narrow_op ||
                             is_vector_fp_signinj ||
                             is_vsub_vv || is_vsub_vx || is_vlogic ||
                             is_vshift || is_vector_narrow_shift || is_vector_int_ext || is_vminmax || is_vector_permute;
  assign is_vector_mask_result_op = is_vmask_logic || is_vcompare || is_vector_fp_compare;
  assign vd  = instr_i[11:7];
  assign vs1 = instr_i[19:15];
  assign vs2 = instr_i[24:20];

  if (ENABLE_VECTOR_FP) begin : gen_vector_fp
  for (genvar fp_lane = 0; fp_lane < 4; fp_lane++) begin : gen_vector_fp_add
    moon_fpu_add u_vector_fpu_add (
      .operand_a_i      (vector_fp_operand_a[fp_lane]),
      .operand_b_i      (vector_fp_operand_b[fp_lane]),
      .is_single_i      ((vsew_q == 3'b010) && !is_vector_fp_widen_arith),
      .subtract_i       ((instr_i[31:26] == 6'b000010) ||
                         (instr_i[31:26] == 6'b110010) ||
                         (instr_i[31:26] == 6'b110110)),
      .rounding_mode_i  (frm_i),
      .result_o         (vector_fp_result[fp_lane]),
      .flags_o          (vector_fp_lane_flags[fp_lane])
    );
    moon_fpu_mul u_vector_fpu_mul (
      .operand_a_i      (vector_fp_operand_a[fp_lane]),
      .operand_b_i      (vector_fp_operand_b[fp_lane]),
      .is_single_i      ((vsew_q == 3'b010) && !is_vector_fp_widen_arith),
      .rounding_mode_i  (frm_i),
      .result_o         (vector_fp_mul_result[fp_lane]),
      .flags_o          (vector_fp_mul_flags[fp_lane])
    );
    moon_fpu_div u_vector_fpu_div (
      .operand_a_i      (vector_fp_operand_a[fp_lane]),
      .operand_b_i      (vector_fp_operand_b[fp_lane]),
      .is_single_i      (vsew_q == 3'b010),
      .rounding_mode_i  (frm_i),
      .result_o         (vector_fp_div_result[fp_lane]),
      .flags_o          (vector_fp_div_flags[fp_lane])
    );
    moon_fpu_sqrt u_vector_fpu_sqrt (
      .operand_i        (vector_fp_operand_a[fp_lane]),
      .is_single_i      (vsew_q == 3'b010),
      .rounding_mode_i  (frm_i),
      .result_o         (vector_fp_sqrt_result[fp_lane]),
      .flags_o          (vector_fp_sqrt_flags[fp_lane])
    );
    moon_fpu_fma u_vector_fpu_mac (
      .operand_a_i      (vector_fp_operand_a[fp_lane]),
      .operand_b_i      (vector_fp_operand_b[fp_lane]),
      .operand_c_i      (vector_fp_operand_c[fp_lane]),
      .format_i         (((vsew_q == 3'b010) && !is_vector_fp_widen_mac) ? 2'b00 : 2'b01),
      .opcode_i         (vector_fp_mac_opcode),
      .rounding_mode_i  (frm_i),
      .result_o         (vector_fp_mac_result[fp_lane]),
      .flags_o          (vector_fp_mac_flags[fp_lane])
    );
    moon_fpu_cmp u_vector_fpu_compare (
      .operand_a_i      (vector_fp_operand_a[fp_lane]),
      .operand_b_i      (vector_fp_operand_b[fp_lane]),
      .is_single_i      (vsew_q == 3'b010),
      .operation_i      (is_vector_fp_minmax ?
                         ((instr_i[31:26] == 6'b000100) ? 3'd0 : 3'd1) :
                         ((instr_i[31:26] == 6'b011001) ? 3'd2 :
                          ((instr_i[31:26] == 6'b011011) ? 3'd3 : 3'd4))),
      .result_o         (vector_fp_compare_result[fp_lane]),
      .flags_o          (vector_fp_compare_flags[fp_lane])
    );
    moon_fpu_intcvt u_vector_fpu_int_cvt (
      .operand_i        (is_vector_fp_narrow_cvt ? vector_narrow_operand[fp_lane] :
                         vector_fp_int_cvt_operand(
                         vreg[vs2],
                         (vsew_q == 3'b010) ? fp_lane : (fp_lane % 2),
                         vsew_q,
                         (instr_i[19:15] == 5'd0) ||
                         (instr_i[19:15] == 5'd1) ||
                         (instr_i[19:15] == 5'd6) ||
                         (instr_i[19:15] == 5'd7) ||
                         (instr_i[19:15] == 5'd8) ||
                         (instr_i[19:15] == 5'd9) ||
                         (instr_i[19:15] == 5'd14) ||
                         (instr_i[19:15] == 5'd15))),
      .instruction_i    (make_scalar_int_cvt_instr(instr_i, vsew_q)),
      .rounding_mode_i  (((instr_i[19:15] == 5'd6) ||
                          (instr_i[19:15] == 5'd7) ||
                          (instr_i[19:15] == 5'd14) ||
                          (instr_i[19:15] == 5'd15) ||
                          (instr_i[19:15] == 5'd22) ||
                          (instr_i[19:15] == 5'd23)) ? 3'b001 : frm_i),
      .result_o         (vector_fp_int_cvt_result[fp_lane]),
      .flags_o          (vector_fp_int_cvt_flags[fp_lane])
    );
    moon_fpu_cvt u_vector_fpu_widen_float_cvt (
      .operand_i        (vector_fp_int_cvt_operand(vreg[vs2], fp_lane, 3'b010, 1'b1)),
      .single_source_i  (1'b1),
      .rounding_mode_i  (frm_i),
      .result_o         (vector_fp_widen_float_result[fp_lane]),
      .flags_o          (vector_fp_widen_float_flags[fp_lane])
    );
    moon_fpu_cvt u_vector_fpu_narrow_float_cvt (
      .operand_i        (vector_narrow_operand[fp_lane]),
      .single_source_i  (1'b0),
      .rounding_mode_i  ((instr_i[19:15] == 5'd21) ? 3'b101 : frm_i),
      .result_o         (vector_fp_narrow_float_result[fp_lane]),
      .flags_o          (vector_fp_narrow_float_flags[fp_lane])
    );
  end
  end else begin : gen_no_vector_fp
    assign vector_fp_result = '0;
    assign vector_fp_mul_result = '0;
    assign vector_fp_div_result = '0;
    assign vector_fp_sqrt_result = '0;
    assign vector_fp_mac_result = '0;
    assign vector_fp_compare_result = '0;
    assign vector_fp_int_cvt_result = '0;
    assign vector_fp_widen_float_result = '0;
    assign vector_fp_narrow_float_result = '0;
    assign vector_fp_lane_flags = '0;
    assign vector_fp_mul_flags = '0;
    assign vector_fp_div_flags = '0;
    assign vector_fp_sqrt_flags = '0;
    assign vector_fp_mac_flags = '0;
    assign vector_fp_compare_flags = '0;
    assign vector_fp_int_cvt_flags = '0;
    assign vector_fp_widen_float_flags = '0;
    assign vector_fp_narrow_float_flags = '0;
  end

  always_comb begin : prepare_vector_narrow_operands
    for (int lane = 0; lane < 4; lane++) begin
      if (lane < 2)
        vector_narrow_operand[lane] = vreg[vs2][lane*64 +: 64];
      else
        vector_narrow_operand[lane] = vreg[vs2 + 5'd1][(lane - 2)*64 +: 64];
    end
  end

  always_comb begin : prepare_vector_fp_add
    for (int i = 0; i < 4; i++) begin
      vector_fp_operand_a[i] = 64'd0;
      vector_fp_operand_b[i] = 64'd0;
      vector_fp_operand_c[i] = 64'd0;
      if (is_vector_fp_widen_mac) begin
        if (is_vector_fp_scalar_form) begin
          vector_fp_operand_a[i] = (scalar_rs1_i[63:32] != 32'hffff_ffff) ?
                                   64'h7ff8_0000_0000_0000 : f32_to_f64(scalar_rs1_i[31:0]);
        end else begin
          vector_fp_operand_a[i] = f32_to_f64(vreg[vs1][i*32 +: 32]);
        end
        vector_fp_operand_b[i] = f32_to_f64(vreg[vs2][i*32 +: 32]);
        if (i < 2)
          vector_fp_operand_c[i] = vreg[vd][i*64 +: 64];
        else
          vector_fp_operand_c[i] = vreg[vd + 5'd1][(i-2)*64 +: 64];
      end else if (is_vector_fp_widen_arith) begin
        if (instr_i[28]) begin
          if (i < 2)
            vector_fp_operand_a[i] = vreg[vs2][i*64 +: 64];
          else
            vector_fp_operand_a[i] = vreg[vs2 + 5'd1][(i-2)*64 +: 64];
        end else begin
          vector_fp_operand_a[i] = f32_to_f64(vreg[vs2][i*32 +: 32]);
        end
        if (is_vector_fp_scalar_form) begin
          vector_fp_operand_b[i] = (scalar_rs1_i[63:32] != 32'hffff_ffff) ?
                                   64'h7ff8_0000_0000_0000 : f32_to_f64(scalar_rs1_i[31:0]);
        end else begin
          vector_fp_operand_b[i] = f32_to_f64(vreg[vs1][i*32 +: 32]);
        end
      end else if (vsew_q == 3'b010) begin
        if (is_vector_fp_fma_dest_mult) begin
          vector_fp_operand_a[i] = {32'hffff_ffff, vreg[vd][i*32 +: 32]};
          vector_fp_operand_b[i] = is_vector_fp_scalar_form ? scalar_rs1_i :
                                   {32'hffff_ffff, vreg[vs1][i*32 +: 32]};
          vector_fp_operand_c[i] = {32'hffff_ffff, vreg[vs2][i*32 +: 32]};
        end else begin
          vector_fp_operand_a[i] = {32'hffff_ffff, vreg[vs2][i*32 +: 32]};
          vector_fp_operand_b[i] = is_vector_fp_scalar_form ? scalar_rs1_i :
                                   {32'hffff_ffff, vreg[vs1][i*32 +: 32]};
          vector_fp_operand_c[i] = {32'hffff_ffff, vreg[vd][i*32 +: 32]};
        end
      end else if ((vsew_q == 3'b011) && (i < 2)) begin
        if (is_vector_fp_fma_dest_mult) begin
          vector_fp_operand_a[i] = vreg[vd][i*64 +: 64];
          vector_fp_operand_b[i] = is_vector_fp_scalar_form ? scalar_rs1_i :
                                   vreg[vs1][i*64 +: 64];
          vector_fp_operand_c[i] = vreg[vs2][i*64 +: 64];
        end else begin
          vector_fp_operand_a[i] = vreg[vs2][i*64 +: 64];
          vector_fp_operand_b[i] = is_vector_fp_scalar_form ? scalar_rs1_i :
                                   vreg[vs1][i*64 +: 64];
          vector_fp_operand_c[i] = vreg[vd][i*64 +: 64];
        end
      end
    end
  end

  always_comb begin : collect_vector_fp_flags
    vector_fp_flags_o = 5'd0;
    vector_fp_flags_we_o = valid_i && advance_i &&
                           (is_vector_fp_op || is_vector_fp_compare || is_vector_fp_minmax ||
                            is_vector_fp_int_cvt || is_vector_fp_widen_float_cvt ||
                            is_vector_fp_narrow_float_cvt || is_vector_fp_widen_arith ||
                            is_vector_fp_widen_mac);
    for (int i = 0; i < 4; i++) begin
      if (valid_i && advance_i &&
          (is_vector_fp_op || is_vector_fp_compare || is_vector_fp_minmax ||
           is_vector_fp_int_cvt || is_vector_fp_widen_float_cvt ||
           is_vector_fp_narrow_float_cvt || is_vector_fp_widen_arith ||
           is_vector_fp_widen_mac) &&
          (i < vl_q) &&
          (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i]) &&
          ((vsew_q == 3'b010) || (i < 2))) begin
        if (is_vector_fp_widen_mac)
          vector_fp_flags_o = vector_fp_flags_o | vector_fp_mac_flags[i];
        else if (is_vector_fp_widen_arith)
          vector_fp_flags_o = vector_fp_flags_o | (is_vector_fp_widen_mul ? vector_fp_mul_flags[i] : vector_fp_lane_flags[i]);
        else if (is_vector_fp_widen_float_cvt)
          vector_fp_flags_o = vector_fp_flags_o | vector_fp_widen_float_flags[i];
        else if (is_vector_fp_narrow_float_cvt)
          vector_fp_flags_o = vector_fp_flags_o | vector_fp_narrow_float_flags[i];
        else if (is_vector_fp_int_cvt)
          vector_fp_flags_o = vector_fp_flags_o | vector_fp_int_cvt_flags[i];
        else if (is_vector_fp_compare || is_vector_fp_minmax)
          vector_fp_flags_o = vector_fp_flags_o | vector_fp_compare_flags[i];
        else if (is_vector_fp_mul)
          vector_fp_flags_o = vector_fp_flags_o | vector_fp_mul_flags[i];
        else if (is_vector_fp_div)
          vector_fp_flags_o = vector_fp_flags_o | vector_fp_div_flags[i];
        else if (is_vector_fp_sqrt)
          vector_fp_flags_o = vector_fp_flags_o | vector_fp_sqrt_flags[i];
        else if (is_vector_fp_mac)
          vector_fp_flags_o = vector_fp_flags_o | vector_fp_mac_flags[i];
        else
          vector_fp_flags_o = vector_fp_flags_o | vector_fp_lane_flags[i];
      end
    end
  end

  assign vector_vl_o = {59'd0, vl_q};
  assign vector_vtype_o = vtype_q;
  assign vector_mem_vstart_o = {59'd0, vector_mem_count_q};

  always_comb begin
    mask_first_index = 5'd0;
    mask_first_found = 1'b0;
    mask_query_result = (instr_i[19:15] == 5'b10001) ? 64'hffff_ffff_ffff_ffff : 64'd0;
    for (int i = 0; i < 16; i++) begin
      if ((i < vl_q) && (instr_i[25] || vreg[0][i]) && vreg[vs2][i]) begin
        if (!mask_first_found) begin
          mask_first_index = i[4:0];
          mask_first_found = 1'b1;
        end
        if (instr_i[19:15] == 5'b10000)
          mask_query_result = mask_query_result + 64'd1;
        else if (mask_query_result == 64'hffff_ffff_ffff_ffff)
          mask_query_result = {59'd0, i[4:0]};
      end
    end
  end

  always_comb begin
    vector_reduce_accum = '0;
    case (vsew_q)
      3'b000: vector_reduce_accum[7:0] = vreg[vs1][7:0];
      3'b001: vector_reduce_accum[15:0] = vreg[vs1][15:0];
      3'b010: vector_reduce_accum[31:0] = vreg[vs1][31:0];
      default: vector_reduce_accum = vreg[vs1][63:0];
    endcase
    for (int i = 0; i < 16; i++) begin
      if ((i < vl_q) && (instr_i[25] || vreg[0][i])) begin
        case (instr_i[31:26])
          6'b000000: vector_reduce_accum = vector_addsub(
                        vector_reduce_accum,
                        vector_element(vreg[vs2], i[4:0], vsew_q),
                        vsew_q, 1'b0);
          6'b000001: vector_reduce_accum = vector_reduce_accum &
                        vector_element(vreg[vs2], i[4:0], vsew_q);
          6'b000010: vector_reduce_accum = vector_reduce_accum |
                        vector_element(vreg[vs2], i[4:0], vsew_q);
          6'b000011: vector_reduce_accum = vector_reduce_accum ^
                        vector_element(vreg[vs2], i[4:0], vsew_q);
          6'b000100, 6'b000101, 6'b000110, 6'b000111:
            vector_reduce_accum = vector_minmax(
                        vector_reduce_accum,
                        vector_element(vreg[vs2], i[4:0], vsew_q),
                        vsew_q, instr_i[31:26]);
          default: vector_reduce_accum = vector_reduce_accum;
        endcase
      end
    end
    vector_reduce_result = vector_reduce_accum;
  end

  always_comb begin : calculate_vector_widen_reduction
    logic signed [127:0] signed_accumulator;
    logic signed [127:0] signed_element;
    logic [127:0] unsigned_accumulator;
    logic [127:0] unsigned_element;
    signed_accumulator = 128'd0;
    signed_element = 128'd0;
    unsigned_accumulator = 128'd0;
    unsigned_element = 128'd0;
    vector_widen_reduce_result = 64'd0;
    if (is_vector_widen_reduction && (vsew_q != 3'b011)) begin
      case (vsew_q)
        3'b000: begin
          if (instr_i[26]) signed_accumulator = $signed(vreg[vs1][15:0]);
          else unsigned_accumulator = {112'd0, vreg[vs1][15:0]};
        end
        3'b001: begin
          if (instr_i[26]) signed_accumulator = $signed(vreg[vs1][31:0]);
          else unsigned_accumulator = {96'd0, vreg[vs1][31:0]};
        end
        default: begin
          if (instr_i[26]) signed_accumulator = $signed(vreg[vs1][63:0]);
          else unsigned_accumulator = {64'd0, vreg[vs1][63:0]};
        end
      endcase
      for (int i = 0; i < 16; i++) begin
        if ((i < vl_q) && (instr_i[25] || vreg[0][i])) begin
          case (vsew_q)
            3'b000: begin
              signed_element = {{120{vreg[vs2][i*8+7]}}, vreg[vs2][i*8 +: 8]};
              unsigned_element = {120'd0, vreg[vs2][i*8 +: 8]};
            end
            3'b001: begin
              signed_element = {{112{vreg[vs2][i*16+15]}}, vreg[vs2][i*16 +: 16]};
              unsigned_element = {112'd0, vreg[vs2][i*16 +: 16]};
            end
            default: begin
              signed_element = {{96{vreg[vs2][i*32+31]}}, vreg[vs2][i*32 +: 32]};
              unsigned_element = {96'd0, vreg[vs2][i*32 +: 32]};
            end
          endcase
          if (instr_i[26]) signed_accumulator = signed_accumulator + signed_element;
          else unsigned_accumulator = unsigned_accumulator + unsigned_element;
        end
      end
      case (vsew_q)
        3'b000: vector_widen_reduce_result = instr_i[26] ? signed_accumulator[15:0] :
                                                              unsigned_accumulator[15:0];
        3'b001: vector_widen_reduce_result = instr_i[26] ? signed_accumulator[31:0] :
                                                              unsigned_accumulator[31:0];
        default: vector_widen_reduce_result = instr_i[26] ? signed_accumulator[63:0] :
                                                               unsigned_accumulator[63:0];
      endcase
    end
  end

  always_comb begin : detect_vector_saturation
    logic [64:0] saturated_element;
    saturated_element = 65'd0;
    vector_vxsat_set_o = 1'b0;
    if (valid_i && advance_i && is_vector_sat) begin
      for (int i = 0; i < 16; i++) begin
        if ((i < vl_q) && (i >= vector_vstart_i) &&
            (instr_i[25] || vreg[0][i])) begin
          saturated_element = vector_sat_result(
            vector_element(vreg[vs2], i[4:0], vsew_q),
            is_vsat_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
            vsew_q, instr_i[31:26]);
          vector_vxsat_set_o = vector_vxsat_set_o | saturated_element[64];
        end
      end
    end
  end

  always_comb begin
    vl = vl_q;
    vlmax = 5'd0;
    vtype_legal = 1'b0;
    if (is_vset_config) begin
      if ((instr_i[22:20] == 3'b000) && (instr_i[25:23] <= 3'b011) &&
          (is_vsetivli ? (instr_i[29:28] == 2'b00) : (instr_i[30:28] == 3'b000))) begin
        vtype_legal = 1'b1;
        vlmax = 5'd16 >> instr_i[25:23];
        if (is_vsetivli) begin
          if (instr_i[19:15] == 5'd0) vl = 5'd0;
          else if (instr_i[19:15] >= vlmax) vl = vlmax;
          else vl = instr_i[19:15];
        end else if (instr_i[19:15] == 5'd0) begin
          vl = (instr_i[11:7] == 5'd0) ? vl_q : vlmax;
        end else if (scalar_rs1_i == 64'd0) begin
          vl = 5'd0;
        end else if (scalar_rs1_i >= vlmax) begin
          vl = vlmax;
        end else begin
          vl = scalar_rs1_i[4:0];
        end
      end else begin
        vl = 5'd0;
      end
    end
  end

  always_comb begin
    scalar_result_valid_o = 1'b0;
    scalar_result_o = '0;
    if (valid_i && is_vset_config) begin
      scalar_result_valid_o = 1'b1;
      scalar_result_o = {61'd0, vl};
    end else if (valid_i && is_vmv_x_s) begin
      scalar_result_valid_o = 1'b1;
      case (vsew_q)
        3'b000: scalar_result_o = {{56{vreg[vs2][7]}}, vreg[vs2][7:0]};
        3'b001: scalar_result_o = {{48{vreg[vs2][15]}}, vreg[vs2][15:0]};
        3'b010: scalar_result_o = {{32{vreg[vs2][31]}}, vreg[vs2][31:0]};
        default: scalar_result_o = vreg[vs2][63:0];
      endcase
    end else if (valid_i && is_vmask_query) begin
      scalar_result_valid_o = 1'b1;
      scalar_result_o = mask_query_result;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      vl_q <= '0;
      vsew_q <= 3'b010;
      vtype_q <= 64'h8000_0000_0000_0000;
      vector_mem_active_q <= 1'b0;
      vector_mem_done_q <= 1'b0;
      vector_mem_store_q <= 1'b0;
      vector_mem_strided_q <= 1'b0;
      vector_mem_indexed_q <= 1'b0;
      vector_mem_mask_q <= 1'b0;
      vector_mem_base_q <= '0;
      vector_mem_stride_q <= '0;
      vector_mem_index_reg_q <= '0;
      vector_mem_count_q <= '0;
      vector_mem_vl_q <= '0;
      vector_mem_sew_q <= '0;
      vector_mem_index_sew_q <= '0;
      vector_mem_vd_q <= '0;
      for (int i = 0; i < 32; i++) vreg[i] <= '0;
    end else begin
      if (vector_mem_fault_i) begin
        vector_mem_active_q <= 1'b0;
        vector_mem_done_q <= 1'b0;
      end else if (vector_mem_done_q && valid_i && advance_i) begin
        vector_mem_active_q <= 1'b0;
        vector_mem_done_q <= 1'b0;
      end else if (!valid_i || !(is_vle_v || is_vse_v || is_vector_mask_mem)) begin
        vector_mem_active_q <= 1'b0;
        vector_mem_done_q <= 1'b0;
      end else if (!vector_mem_active_q && !vector_mem_done_q) begin
        vector_mem_active_q <= 1'b1;
        vector_mem_store_q <= is_vse_v || is_vsm_v;
        vector_mem_strided_q <= is_vector_mask_mem ? 1'b0 : vector_mem_strided;
        vector_mem_indexed_q <= is_vector_mask_mem ? 1'b0 : vector_mem_indexed;
        vector_mem_mask_q <= is_vector_mask_mem;
        vector_mem_base_q <= scalar_rs1_i;
        vector_mem_stride_q <= scalar_rs2_i;
        vector_mem_index_reg_q <= instr_i[24:20];
        vector_mem_count_q <= vector_vstart_i[4:0];
        vector_mem_vl_q <= is_vector_mask_mem ? ((vl_q + 5'd7) >> 3) : vl_q;
        vector_mem_sew_q <= is_vector_mask_mem ? 3'b000 :
                             (vector_mem_indexed ? vsew_q : vector_mem_eew);
        vector_mem_index_sew_q <= vector_mem_eew;
        vector_mem_vd_q <= instr_i[11:7];
        if ((vl_q == 0) || (vector_vstart_i >=
            {59'd0, (is_vector_mask_mem ? ((vl_q + 5'd7) >> 3) : vl_q)})) begin
          vector_mem_active_q <= 1'b0;
          vector_mem_done_q <= 1'b1;
        end
      end else if (vector_mem_active_q && vector_mem_count_q < vector_mem_vl_q &&
                   !instr_i[25] && !vreg[0][vector_mem_count_q]) begin
        if (vector_mem_count_q + 1'b1 >= vector_mem_vl_q) begin
          vector_mem_active_q <= 1'b0;
          vector_mem_done_q <= 1'b1;
        end else begin
          vector_mem_count_q <= vector_mem_count_q + 1'b1;
        end
      end else if (vector_mem_active_q && mem_valid_i && mem_req_o) begin
        if (!vector_mem_store_q) begin
          case (vector_mem_sew_q)
            3'b000: vreg[vector_mem_vd_q][int'(vector_mem_count_q) * 8 +: 8] <=
                      mem_rdata_i[vector_mem_offset * 8 +: 8];
            3'b001: vreg[vector_mem_vd_q][int'(vector_mem_count_q) * 16 +: 16] <=
                      mem_rdata_i[vector_mem_offset * 8 +: 16];
            3'b010: vreg[vector_mem_vd_q][int'(vector_mem_count_q) * 32 +: 32] <=
                      mem_rdata_i[vector_mem_offset * 8 +: 32];
            default: vreg[vector_mem_vd_q][int'(vector_mem_count_q) * 64 +: 64] <=
                       mem_rdata_i[63:0];
          endcase
        end
        if (vector_mem_count_q + 1'b1 >= vector_mem_vl_q) begin
          vector_mem_active_q <= 1'b0;
          vector_mem_done_q <= 1'b1;
        end else begin
          vector_mem_count_q <= vector_mem_count_q + 1'b1;
        end
      end

      if (vector_mem_active_q && !vector_mem_store_q &&
          vector_mem_count_q < vector_mem_vl_q && !instr_i[25] &&
          !vreg[0][vector_mem_count_q] && vtype_q[7]) begin
        case (vector_mem_sew_q)
          3'b000: vreg[vector_mem_vd_q][int'(vector_mem_count_q) * 8 +: 8] <= 8'hff;
          3'b001: vreg[vector_mem_vd_q][int'(vector_mem_count_q) * 16 +: 16] <= 16'hffff;
          3'b010: vreg[vector_mem_vd_q][int'(vector_mem_count_q) * 32 +: 32] <= 32'hffff_ffff;
          default: vreg[vector_mem_vd_q][int'(vector_mem_count_q) * 64 +: 64] <= 64'hffff_ffff_ffff_ffff;
        endcase
      end

      if (valid_i && advance_i && vector_mem_done_q && !vector_mem_store_q && vtype_q[6]) begin
        for (int i = 0; i < 16; i++) begin
          if (i >= vector_mem_vl_q) begin
            case (vector_mem_sew_q)
              3'b000: vreg[vector_mem_vd_q][i*8 +: 8] <= 8'hff;
              3'b001: if (i < 8) vreg[vector_mem_vd_q][i*16 +: 16] <= 16'hffff;
              3'b010: if (i < 4) vreg[vector_mem_vd_q][i*32 +: 32] <= 32'hffff_ffff;
              default: if (i < 2) vreg[vector_mem_vd_q][i*64 +: 64] <= 64'hffff_ffff_ffff_ffff;
            endcase
          end
        end
      end

      if (valid_i && advance_i) begin
      if (is_vset_config) begin
        vl_q <= vl;
        if (vtype_legal) begin
          vsew_q <= instr_i[25:23];
          vtype_q <= {1'b0, 55'd0, instr_i[27:20]};
        end else begin
          vtype_q <= 64'h8000_0000_0000_0000;
        end
      end else if (is_vmv_v_x) begin
        case (vsew_q)
          3'b000: for (int i = 0; i < 16; i++) if ((i < vl_q) && (i >= vector_vstart_i)) vreg[vd][i*8 +: 8] <= scalar_rs1_i[7:0];
          3'b001: for (int i = 0; i < 8; i++) if ((i < vl_q) && (i >= vector_vstart_i)) vreg[vd][i*16 +: 16] <= scalar_rs1_i[15:0];
          3'b010: for (int i = 0; i < 4; i++) if ((i < vl_q) && (i >= vector_vstart_i)) vreg[vd][i*32 +: 32] <= scalar_rs1_i[31:0];
          default: for (int i = 0; i < 2; i++) if ((i < vl_q) && (i >= vector_vstart_i)) vreg[vd][i*64 +: 64] <= scalar_rs1_i;
        endcase
      end else if (is_vmask_logic) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i)) begin
            case (instr_i[31:26])
              6'b011000: vreg[vd][i] <= vreg[vs2][i] & ~vreg[vs1][i];
              6'b011001: vreg[vd][i] <= vreg[vs2][i] & vreg[vs1][i];
              6'b011010: vreg[vd][i] <= vreg[vs2][i] | vreg[vs1][i];
              6'b011011: vreg[vd][i] <= vreg[vs2][i] ^ vreg[vs1][i];
              6'b011100: vreg[vd][i] <= ~(vreg[vs2][i] ^ vreg[vs1][i]);
              6'b011101: vreg[vd][i] <= ~(vreg[vs2][i] & vreg[vs1][i]);
              6'b011110: vreg[vd][i] <= ~(vreg[vs2][i] | vreg[vs1][i]);
              default:   vreg[vd][i] <= vreg[vs2][i] | ~vreg[vs1][i];
            endcase
          end
        end
      end else if (is_vmask_prefix) begin
        for (int i = 0; i < 16; i++) begin
          if (i < vl_q) begin
            if (instr_i[25] || vreg[0][i]) begin
              case (instr_i[19:15])
                5'd1: vreg[vd][i] <= !mask_first_found || (i < mask_first_index);
                5'd2: vreg[vd][i] <= mask_first_found && (i == mask_first_index);
                default: vreg[vd][i] <= !mask_first_found || (i <= mask_first_index);
              endcase
            end else if (vtype_q[7]) begin
              vreg[vd][i] <= 1'b1;
            end
          end else begin
            // Mask-manipulation tails follow vta; with tu they are preserved.
            if (vtype_q[6]) vreg[vd][i] <= 1'b1;
          end
        end
      end else if (is_vector_reduction) begin
        case (vsew_q)
          3'b000: begin
            vreg[vd][7:0] <= vector_reduce_result[7:0];
            if (vtype_q[6])
              for (int i = 1; i < 16; i++) vreg[vd][i*8 +: 8] <= 8'hff;
          end
          3'b001: begin
            vreg[vd][15:0] <= vector_reduce_result[15:0];
            if (vtype_q[6])
              for (int i = 1; i < 8; i++) vreg[vd][i*16 +: 16] <= 16'hffff;
          end
          3'b010: begin
            vreg[vd][31:0] <= vector_reduce_result[31:0];
            if (vtype_q[6])
              for (int i = 1; i < 4; i++) vreg[vd][i*32 +: 32] <= 32'hffff_ffff;
          end
          default: begin
            vreg[vd][63:0] <= vector_reduce_result;
            if (vtype_q[6]) vreg[vd][127:64] <= 64'hffff_ffff_ffff_ffff;
          end
        endcase
      end else if (is_vector_widen_reduction && (vsew_q != 3'b011)) begin
        case (vsew_q)
          3'b000: begin
            vreg[vd][15:0] <= vector_widen_reduce_result[15:0];
            if (vtype_q[6])
              for (int i = 1; i < 8; i++) vreg[vd][i*16 +: 16] <= 16'hffff;
          end
          3'b001: begin
            vreg[vd][31:0] <= vector_widen_reduce_result[31:0];
            if (vtype_q[6])
              for (int i = 1; i < 4; i++) vreg[vd][i*32 +: 32] <= 32'hffff_ffff;
          end
          default: begin
            vreg[vd][63:0] <= vector_widen_reduce_result;
            if (vtype_q[6]) vreg[vd][127:64] <= 64'hffff_ffff_ffff_ffff;
          end
        endcase
      end else if (is_vector_fp_class) begin
        for (int i = 0; i < 4; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) &&
              (instr_i[25] || vreg[0][i])) begin
            if (vsew_q == 3'b010)
              vreg[vd][i*32 +: 32] <= {22'd0, classify_floating(
                {32'd0, vreg[vs2][i*32 +: 32]}, 1'b1)};
            else if ((vsew_q == 3'b011) && (i < 2))
              vreg[vd][i*64 +: 64] <= {54'd0, classify_floating(
                vreg[vs2][i*64 +: 64], 1'b0)};
          end
        end
      end else if (is_vector_fp_widen_op) begin
        for (int i = 0; i < 4; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) &&
              (instr_i[25] || vreg[0][i])) begin
            if (i < 2) begin
              vreg[vd][i*64 +: 64] <= is_vector_fp_widen_mac ? vector_fp_mac_result[i] :
                (is_vector_fp_widen_arith ?
                  (is_vector_fp_widen_mul ? vector_fp_mul_result[i] : vector_fp_result[i]) :
                  (is_vector_fp_widen_float_cvt ? vector_fp_widen_float_result[i] : vector_fp_int_cvt_result[i]));
            end else begin
              vreg[vd + 5'd1][(i-2)*64 +: 64] <= is_vector_fp_widen_mac ? vector_fp_mac_result[i] :
                (is_vector_fp_widen_arith ?
                  (is_vector_fp_widen_mul ? vector_fp_mul_result[i] : vector_fp_result[i]) :
                  (is_vector_fp_widen_float_cvt ? vector_fp_widen_float_result[i] : vector_fp_int_cvt_result[i]));
            end
          end
        end
      end else if (is_vector_fp_narrow_float_cvt) begin
        for (int i = 0; i < 4; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) &&
              (instr_i[25] || vreg[0][i])) begin
            vreg[vd][i*32 +: 32] <= vector_fp_narrow_float_result[i][31:0];
          end
        end
      end else if (is_vector_fp_int_cvt) begin
        for (int i = 0; i < 4; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) &&
              (instr_i[25] || vreg[0][i])) begin
            if (vsew_q == 3'b010)
              vreg[vd][i*32 +: 32] <= vector_fp_int_cvt_result[i][31:0];
            else if ((vsew_q == 3'b011) && (i < 2))
              vreg[vd][i*64 +: 64] <= vector_fp_int_cvt_result[i];
          end
        end
      end else if (is_vector_fp_minmax) begin
        for (int i = 0; i < 4; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) &&
              (instr_i[25] || vreg[0][i])) begin
            if (vsew_q == 3'b010)
              vreg[vd][i*32 +: 32] <= vector_fp_compare_result[i][31:0];
            else if ((vsew_q == 3'b011) && (i < 2))
              vreg[vd][i*64 +: 64] <= vector_fp_compare_result[i];
          end
        end
      end else if (is_vector_fp_signinj) begin
        for (int i = 0; i < 4; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) &&
              (instr_i[25] || vreg[0][i])) begin
            if (vsew_q == 3'b010) begin
              case (instr_i[31:26])
                6'b001000: vreg[vd][i*32 +: 32] <=
                  {is_vector_fp_scalar_form ? scalar_rs1_i[31] : vreg[vs1][i*32+31],
                   vreg[vs2][i*32+30 -: 31]};
                6'b001001: vreg[vd][i*32 +: 32] <=
                  {~(is_vector_fp_scalar_form ? scalar_rs1_i[31] : vreg[vs1][i*32+31]),
                   vreg[vs2][i*32+30 -: 31]};
                default: vreg[vd][i*32 +: 32] <=
                  {vreg[vs2][i*32+31] ^
                   (is_vector_fp_scalar_form ? scalar_rs1_i[31] : vreg[vs1][i*32+31]),
                   vreg[vs2][i*32+30 -: 31]};
              endcase
            end else if ((vsew_q == 3'b011) && (i < 2)) begin
              case (instr_i[31:26])
                6'b001000: vreg[vd][i*64 +: 64] <=
                  {is_vector_fp_scalar_form ? scalar_rs1_i[63] : vreg[vs1][i*64+63],
                   vreg[vs2][i*64+62 -: 63]};
                6'b001001: vreg[vd][i*64 +: 64] <=
                  {~(is_vector_fp_scalar_form ? scalar_rs1_i[63] : vreg[vs1][i*64+63]),
                   vreg[vs2][i*64+62 -: 63]};
                default: vreg[vd][i*64 +: 64] <=
                  {vreg[vs2][i*64+63] ^
                   (is_vector_fp_scalar_form ? scalar_rs1_i[63] : vreg[vs1][i*64+63]),
                   vreg[vs2][i*64+62 -: 63]};
              endcase
            end
          end
        end
      end else if (is_vector_fp_op) begin
        for (int i = 0; i < 4; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) &&
              (instr_i[25] || vreg[0][i])) begin
            if (vsew_q == 3'b010)
              vreg[vd][i*32 +: 32] <= is_vector_fp_mac ?
                                       vector_fp_mac_result[i][31:0] :
                                       (is_vector_fp_sqrt ?
                                       vector_fp_sqrt_result[i][31:0] :
                                       (is_vector_fp_div ?
                                       vector_fp_div_result[i][31:0] :
                                       (is_vector_fp_mul ?
                                       vector_fp_mul_result[i][31:0] :
                                       vector_fp_result[i][31:0])));
            else if ((vsew_q == 3'b011) && (i < 2))
              vreg[vd][i*64 +: 64] <= is_vector_fp_mac ?
                                       vector_fp_mac_result[i] :
                                       (is_vector_fp_sqrt ?
                                       vector_fp_sqrt_result[i] :
                                       (is_vector_fp_div ?
                                       vector_fp_div_result[i] :
                                       (is_vector_fp_mul ?
                                        vector_fp_mul_result[i] : vector_fp_result[i])));
          end
        end
      end else if (is_vector_permute) begin : blk_vpermute
        logic [127:0] permute_vd;
        permute_vd = vreg[vd];
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) &&
              (instr_i[25] || vreg[0][i]) &&
              !(is_vslideup &&
                (i < ((instr_i[14:12] == 3'b011) ? instr_i[19:15] : scalar_rs1_i)))) begin
            case (vsew_q)
              3'b000: permute_vd[i*8 +: 8] = vector_permute_element(
                vreg[vs2], vreg[vs1], i[4:0], vl_q, vsew_q,
                instr_i[31:26], instr_i[14:12], scalar_rs1_i, instr_i[19:15]);
              3'b001: if (i < 8) permute_vd[i*16 +: 16] = vector_permute_element(
                vreg[vs2], vreg[vs1], i[4:0], vl_q, vsew_q,
                instr_i[31:26], instr_i[14:12], scalar_rs1_i, instr_i[19:15]);
              3'b010: if (i < 4) permute_vd[i*32 +: 32] = vector_permute_element(
                vreg[vs2], vreg[vs1], i[4:0], vl_q, vsew_q,
                instr_i[31:26], instr_i[14:12], scalar_rs1_i, instr_i[19:15]);
              default: if (i < 2) permute_vd[i*64 +: 64] = vector_permute_element(
                vreg[vs2], vreg[vs1], i[4:0], vl_q, vsew_q,
                instr_i[31:26], instr_i[14:12], scalar_rs1_i, instr_i[19:15]);
            endcase
          end
        end
        vreg[vd] <= permute_vd;
      end else if (is_vector_sat) begin : blk_vsat
        logic [127:0] sat_vd;
        sat_vd = vreg[vd];
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: sat_vd[i*8 +: 8] = vector_sat_result(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vsat_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              3'b001: if (i < 8) sat_vd[i*16 +: 16] = vector_sat_result(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vsat_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              3'b010: if (i < 4) sat_vd[i*32 +: 32] = vector_sat_result(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vsat_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              default: if (i < 2) sat_vd[i*64 +: 64] = vector_sat_result(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vsat_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
            endcase
          end
        end
        vreg[vd] <= sat_vd;
      end else if (is_vdivrem_vv || is_vdivrem_vx) begin : blk_vdivrem
        logic [127:0] divrem_vd;
        divrem_vd = vreg[vd];
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: divrem_vd[i*8 +: 8] = vector_divrem(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vdivrem_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              3'b001: if (i < 8) divrem_vd[i*16 +: 16] = vector_divrem(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vdivrem_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              3'b010: if (i < 4) divrem_vd[i*32 +: 32] = vector_divrem(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vdivrem_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              default: if (i < 2) divrem_vd[i*64 +: 64] = vector_divrem(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vdivrem_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
            endcase
          end
        end
        vreg[vd] <= divrem_vd;
      end else if (is_vmulh_vv || is_vmulh_vx || is_vmulhu_vv ||
                   is_vmulhu_vx || is_vmulhsu_vv || is_vmulhsu_vx) begin : blk_vmulh
        logic [127:0] mulh_vd;
        mulh_vd = vreg[vd];
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: mulh_vd[i*8 +: 8] = vector_mul_high(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                (instr_i[14:12] == 3'b010) ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              3'b010: if (i < 4) mulh_vd[i*32 +: 32] = vector_mul_high(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                (instr_i[14:12] == 3'b010) ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              3'b001: if (i < 8) mulh_vd[i*16 +: 16] = vector_mul_high(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                (instr_i[14:12] == 3'b010) ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              default: if (i < 2) mulh_vd[i*64 +: 64] = vector_mul_high(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                (instr_i[14:12] == 3'b010) ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
            endcase
          end
        end
        vreg[vd] <= mulh_vd;
      end else if (is_vmul_vv || is_vmul_vx) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_element(vreg[vs2], i[4:0], vsew_q) *
                ((is_vmul_vv) ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i);
              3'b001: if (i < 8) vreg[vd][i*16 +: 16] <= vector_element(vreg[vs2], i[4:0], vsew_q) *
                ((is_vmul_vv) ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i);
              3'b010: if (i < 4) vreg[vd][i*32 +: 32] <= vector_element(vreg[vs2], i[4:0], vsew_q) *
                ((is_vmul_vv) ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i);
              default: if (i < 2) vreg[vd][i*64 +: 64] <= vector_element(vreg[vs2], i[4:0], vsew_q) *
                ((is_vmul_vv) ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i);
            endcase
          end
        end
      end else if (is_vadd_vv || is_vadd_vx) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_addsub(vreg[vs2][i*8 +: 8],
                  is_vadd_vv ? vreg[vs1][i*8 +: 8] : ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} : scalar_rs1_i), vsew_q, 1'b0);
              3'b001: vreg[vd][i*16 +: 16] <= vector_addsub(vreg[vs2][i*16 +: 16],
                  is_vadd_vv ? vreg[vs1][i*16 +: 16] : ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} : scalar_rs1_i), vsew_q, 1'b0);
              3'b010: vreg[vd][i*32 +: 32] <= vector_addsub(vreg[vs2][i*32 +: 32],
                  is_vadd_vv ? vreg[vs1][i*32 +: 32] : ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} : scalar_rs1_i), vsew_q, 1'b0);
              default: if (i < 2) vreg[vd][i*64 +: 64] <= vector_addsub(vreg[vs2][i*64 +: 64],
                  is_vadd_vv ? vreg[vs1][i*64 +: 64] : ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} : scalar_rs1_i), vsew_q, 1'b0);
            endcase
          end
        end
      end else if (is_vsub_vv || is_vsub_vx) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_addsub(vreg[vs2][i*8 +: 8], is_vsub_vv ? vreg[vs1][i*8 +: 8] : scalar_rs1_i, vsew_q, 1'b1);
              3'b001: vreg[vd][i*16 +: 16] <= vector_addsub(vreg[vs2][i*16 +: 16], is_vsub_vv ? vreg[vs1][i*16 +: 16] : scalar_rs1_i, vsew_q, 1'b1);
              3'b010: vreg[vd][i*32 +: 32] <= vector_addsub(vreg[vs2][i*32 +: 32], is_vsub_vv ? vreg[vs1][i*32 +: 32] : scalar_rs1_i, vsew_q, 1'b1);
              default: if (i < 2) vreg[vd][i*64 +: 64] <= vector_addsub(vreg[vs2][i*64 +: 64], is_vsub_vv ? vreg[vs1][i*64 +: 64] : scalar_rs1_i, vsew_q, 1'b1);
            endcase
          end
        end
      end else if (is_vlogic) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_logic(vreg[vs2][i*8 +: 8],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i :
                  ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} : vreg[vs1][i*8 +: 8]), vsew_q, instr_i[31:26]);
              3'b001: vreg[vd][i*16 +: 16] <= vector_logic(vreg[vs2][i*16 +: 16],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i :
                  ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} : vreg[vs1][i*16 +: 16]), vsew_q, instr_i[31:26]);
              3'b010: vreg[vd][i*32 +: 32] <= vector_logic(vreg[vs2][i*32 +: 32],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i :
                  ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} : vreg[vs1][i*32 +: 32]), vsew_q, instr_i[31:26]);
              default: if (i < 2) vreg[vd][i*64 +: 64] <= vector_logic(vreg[vs2][i*64 +: 64],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i :
                  ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} : vreg[vs1][i*64 +: 64]), vsew_q, instr_i[31:26]);
            endcase
          end
        end
      end else if (is_vshift) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_shift(vreg[vs2][i*8 +: 8],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i[5:0] :
                  ((instr_i[14:12] == 3'b011) ? {1'b0, instr_i[19:15]} : vreg[vs1][i*8 +: 6]), vsew_q, instr_i[31:26]);
              3'b001: vreg[vd][i*16 +: 16] <= vector_shift(vreg[vs2][i*16 +: 16],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i[5:0] :
                  ((instr_i[14:12] == 3'b011) ? {1'b0, instr_i[19:15]} : vreg[vs1][i*16 +: 6]), vsew_q, instr_i[31:26]);
              3'b010: vreg[vd][i*32 +: 32] <= vector_shift(vreg[vs2][i*32 +: 32],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i[5:0] :
                  ((instr_i[14:12] == 3'b011) ? {1'b0, instr_i[19:15]} : vreg[vs1][i*32 +: 6]), vsew_q, instr_i[31:26]);
              default: if (i < 2) vreg[vd][i*64 +: 64] <= vector_shift(vreg[vs2][i*64 +: 64],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i[5:0] :
                  ((instr_i[14:12] == 3'b011) ? {1'b0, instr_i[19:15]} : vreg[vs1][i*64 +: 6]), vsew_q, instr_i[31:26]);
            endcase
          end
        end
      end else if (is_vector_narrow_shift) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_narrow_shift(
                (i < 8) ? {48'd0, vreg[vs2][i*16 +: 16]} : {48'd0, vreg[vs2 + 5'd1][(i-8)*16 +: 16]},
                (instr_i[14:12] == 3'b100) ? scalar_rs1_i[5:0] :
                ((instr_i[14:12] == 3'b011) ? {1'b0, instr_i[19:15]} : {2'b00, vreg[vs1][i*8 +: 4]}),
                vsew_q,
                (instr_i[31:26] == 6'b101101)
              );
              3'b001: if (i < 8) vreg[vd][i*16 +: 16] <= vector_narrow_shift(
                (i < 4) ? {32'd0, vreg[vs2][i*32 +: 32]} : {32'd0, vreg[vs2 + 5'd1][(i-4)*32 +: 32]},
                (instr_i[14:12] == 3'b100) ? scalar_rs1_i[5:0] :
                ((instr_i[14:12] == 3'b011) ? {1'b0, instr_i[19:15]} : {1'b0, vreg[vs1][i*16 +: 5]}),
                vsew_q,
                (instr_i[31:26] == 6'b101101)
              );
              3'b010: if (i < 4) vreg[vd][i*32 +: 32] <= vector_narrow_shift(
                (i < 2) ? vreg[vs2][i*64 +: 64] : vreg[vs2 + 5'd1][(i-2)*64 +: 64],
                (instr_i[14:12] == 3'b100) ? scalar_rs1_i[5:0] :
                ((instr_i[14:12] == 3'b011) ? {1'b0, instr_i[19:15]} : vreg[vs1][i*32 +: 6]),
                vsew_q,
                (instr_i[31:26] == 6'b101101)
              );
              default: ;
            endcase
          end
        end
      end else if (is_vector_int_widen_arith) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: begin
                if (i < 8)
                  vreg[vd][i*16 +: 16] <= vector_widen_arith(
                    (instr_i[28]) ? {48'd0, vreg[vs2][i*16 +: 16]} : {56'd0, vreg[vs2][i*8 +: 8]},
                    (instr_i[14:12] == 3'b110) ? {56'd0, scalar_rs1_i[7:0]} : {56'd0, vreg[vs1][i*8 +: 8]},
                    vsew_q,
                    instr_i[31:26]
                  );
                else
                  vreg[vd + 5'd1][(i-8)*16 +: 16] <= vector_widen_arith(
                    (instr_i[28]) ? {48'd0, vreg[vs2 + 5'd1][(i-8)*16 +: 16]} : {56'd0, vreg[vs2][i*8 +: 8]},
                    (instr_i[14:12] == 3'b110) ? {56'd0, scalar_rs1_i[7:0]} : {56'd0, vreg[vs1][i*8 +: 8]},
                    vsew_q,
                    instr_i[31:26]
                  );
              end
              3'b001: if (i < 8) begin
                if (i < 4)
                  vreg[vd][i*32 +: 32] <= vector_widen_arith(
                    (instr_i[28]) ? {32'd0, vreg[vs2][i*32 +: 32]} : {48'd0, vreg[vs2][i*16 +: 16]},
                    (instr_i[14:12] == 3'b110) ? {48'd0, scalar_rs1_i[15:0]} : {48'd0, vreg[vs1][i*16 +: 16]},
                    vsew_q,
                    instr_i[31:26]
                  );
                else
                  vreg[vd + 5'd1][(i-4)*32 +: 32] <= vector_widen_arith(
                    (instr_i[28]) ? {32'd0, vreg[vs2 + 5'd1][(i-4)*32 +: 32]} : {48'd0, vreg[vs2][i*16 +: 16]},
                    (instr_i[14:12] == 3'b110) ? {48'd0, scalar_rs1_i[15:0]} : {48'd0, vreg[vs1][i*16 +: 16]},
                    vsew_q,
                    instr_i[31:26]
                  );
              end
              3'b010: if (i < 4) begin
                if (i < 2)
                  vreg[vd][i*64 +: 64] <= vector_widen_arith(
                    (instr_i[28]) ? vreg[vs2][i*64 +: 64] : {32'd0, vreg[vs2][i*32 +: 32]},
                    (instr_i[14:12] == 3'b110) ? {32'd0, scalar_rs1_i[31:0]} : {32'd0, vreg[vs1][i*32 +: 32]},
                    vsew_q,
                    instr_i[31:26]
                  );
                else
                  vreg[vd + 5'd1][(i-2)*64 +: 64] <= vector_widen_arith(
                    (instr_i[28]) ? vreg[vs2 + 5'd1][(i-2)*64 +: 64] : {32'd0, vreg[vs2][i*32 +: 32]},
                    (instr_i[14:12] == 3'b110) ? {32'd0, scalar_rs1_i[31:0]} : {32'd0, vreg[vs1][i*32 +: 32]},
                    vsew_q,
                    instr_i[31:26]
                  );
              end
              default: ;
            endcase
          end
        end
      end else if (is_vector_int_widen_macc) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: begin
                if (i < 8)
                  vreg[vd][i*16 +: 16] <= vector_widen_macc(
                    {48'd0, vreg[vd][i*16 +: 16]},
                    {56'd0, vreg[vs2][i*8 +: 8]},
                    (instr_i[14:12] == 3'b110) ? {56'd0, scalar_rs1_i[7:0]} : {56'd0, vreg[vs1][i*8 +: 8]},
                    vsew_q,
                    instr_i[31:26],
                    instr_i[14:12] == 3'b110
                  );
                else
                  vreg[vd + 5'd1][(i-8)*16 +: 16] <= vector_widen_macc(
                    {48'd0, vreg[vd + 5'd1][(i-8)*16 +: 16]},
                    {56'd0, vreg[vs2][i*8 +: 8]},
                    (instr_i[14:12] == 3'b110) ? {56'd0, scalar_rs1_i[7:0]} : {56'd0, vreg[vs1][i*8 +: 8]},
                    vsew_q,
                    instr_i[31:26],
                    instr_i[14:12] == 3'b110
                  );
              end
              3'b001: if (i < 8) begin
                if (i < 4)
                  vreg[vd][i*32 +: 32] <= vector_widen_macc(
                    {32'd0, vreg[vd][i*32 +: 32]},
                    {48'd0, vreg[vs2][i*16 +: 16]},
                    (instr_i[14:12] == 3'b110) ? {48'd0, scalar_rs1_i[15:0]} : {48'd0, vreg[vs1][i*16 +: 16]},
                    vsew_q,
                    instr_i[31:26],
                    instr_i[14:12] == 3'b110
                  );
                else
                  vreg[vd + 5'd1][(i-4)*32 +: 32] <= vector_widen_macc(
                    {32'd0, vreg[vd + 5'd1][(i-4)*32 +: 32]},
                    {48'd0, vreg[vs2][i*16 +: 16]},
                    (instr_i[14:12] == 3'b110) ? {48'd0, scalar_rs1_i[15:0]} : {48'd0, vreg[vs1][i*16 +: 16]},
                    vsew_q,
                    instr_i[31:26],
                    instr_i[14:12] == 3'b110
                  );
              end
              3'b010: if (i < 4) begin
                if (i < 2)
                  vreg[vd][i*64 +: 64] <= vector_widen_macc(
                    vreg[vd][i*64 +: 64],
                    {32'd0, vreg[vs2][i*32 +: 32]},
                    (instr_i[14:12] == 3'b110) ? {32'd0, scalar_rs1_i[31:0]} : {32'd0, vreg[vs1][i*32 +: 32]},
                    vsew_q,
                    instr_i[31:26],
                    instr_i[14:12] == 3'b110
                  );
                else
                  vreg[vd + 5'd1][(i-2)*64 +: 64] <= vector_widen_macc(
                    vreg[vd + 5'd1][(i-2)*64 +: 64],
                    {32'd0, vreg[vs2][i*32 +: 32]},
                    (instr_i[14:12] == 3'b110) ? {32'd0, scalar_rs1_i[31:0]} : {32'd0, vreg[vs1][i*32 +: 32]},
                    vsew_q,
                    instr_i[31:26],
                    instr_i[14:12] == 3'b110
                  );
              end
              default: ;
            endcase
          end
        end
      end else if (is_vector_int_ext) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b001: if (i < 8)
                vreg[vd][i*16 +: 16] <= vector_int_ext(
                  vector_int_ext_source(vreg[vs2], i, vsew_q, instr_i[19:15]),
                  vsew_q,
                  instr_i[19:15]
                );
              3'b010: if (i < 4)
                vreg[vd][i*32 +: 32] <= vector_int_ext(
                  vector_int_ext_source(vreg[vs2], i, vsew_q, instr_i[19:15]),
                  vsew_q,
                  instr_i[19:15]
                );
              3'b011: if (i < 2)
                vreg[vd][i*64 +: 64] <= vector_int_ext(
                  vector_int_ext_source(vreg[vs2], i, vsew_q, instr_i[19:15]),
                  vsew_q,
                  instr_i[19:15]
                );
              default: ;
            endcase
          end
        end
      end else if (is_vector_fp_compare) begin
        for (int i = 0; i < 4; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) &&
              (instr_i[25] || vreg[0][i]) &&
              ((vsew_q == 3'b010) || (i < 2)))
            vreg[vd][i] <= is_vector_fp_not_equal ?
                           !vector_fp_compare_result[i][0] :
                           vector_fp_compare_result[i][0];
        end
      end else if (is_vcompare) begin : blk_vcompare
        logic [127:0] compare_vd;
        compare_vd = vreg[vd];
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: compare_vd[i] = vector_compare(
                  vector_element(vreg[vs2], i[4:0], vsew_q),
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i :
                  ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} :
                   vector_element(vreg[vs1], i[4:0], vsew_q)), vsew_q, instr_i[31:26]);
              3'b001: if (i < 8) compare_vd[i] = vector_compare(
                  vector_element(vreg[vs2], i[4:0], vsew_q),
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i :
                  ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} :
                   vector_element(vreg[vs1], i[4:0], vsew_q)), vsew_q, instr_i[31:26]);
              3'b010: if (i < 4) compare_vd[i] = vector_compare(
                  vector_element(vreg[vs2], i[4:0], vsew_q),
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i :
                  ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} :
                   vector_element(vreg[vs1], i[4:0], vsew_q)), vsew_q, instr_i[31:26]);
              default: if (i < 2) compare_vd[i] = vector_compare(
                  vector_element(vreg[vs2], i[4:0], vsew_q),
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i :
                  ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} :
                   vector_element(vreg[vs1], i[4:0], vsew_q)), vsew_q, instr_i[31:26]);
            endcase
          end
        end
        vreg[vd] <= compare_vd;
      end else if (is_vminmax) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_minmax(vreg[vs2][i*8 +: 8],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i : vreg[vs1][i*8 +: 8], vsew_q, instr_i[31:26]);
              3'b001: vreg[vd][i*16 +: 16] <= vector_minmax(vreg[vs2][i*16 +: 16],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i : vreg[vs1][i*16 +: 16], vsew_q, instr_i[31:26]);
              3'b010: vreg[vd][i*32 +: 32] <= vector_minmax(vreg[vs2][i*32 +: 32],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i : vreg[vs1][i*32 +: 32], vsew_q, instr_i[31:26]);
              default: if (i < 2) vreg[vd][i*64 +: 64] <= vector_minmax(vreg[vs2][i*64 +: 64],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i : vreg[vs1][i*64 +: 64], vsew_q, instr_i[31:26]);
            endcase
          end
        end
      end

      if (vtype_q[7:6] != 2'b00 && (is_vector_fp_widen_op || is_vector_int_widen_arith || is_vector_int_widen_macc)) begin
        for (int i = 0; i < 16; i++) begin
          if (i >= vector_vstart_i) begin
            case (vsew_q)
              3'b000: begin
                if ((i >= vl_q) && vtype_q[6]) begin
                  if (i < 8) vreg[vd][i*16 +: 16] <= 16'hffff;
                  else       vreg[vd + 5'd1][(i-8)*16 +: 16] <= 16'hffff;
                end else if ((i < vl_q) && !instr_i[25] && !vreg[0][i] && vtype_q[7]) begin
                  if (i < 8) vreg[vd][i*16 +: 16] <= 16'hffff;
                  else       vreg[vd + 5'd1][(i-8)*16 +: 16] <= 16'hffff;
                end
              end
              3'b001: if (i < 8) begin
                if ((i >= vl_q) && vtype_q[6]) begin
                  if (i < 4) vreg[vd][i*32 +: 32] <= 32'hffff_ffff;
                  else       vreg[vd + 5'd1][(i-4)*32 +: 32] <= 32'hffff_ffff;
                end else if ((i < vl_q) && !instr_i[25] && !vreg[0][i] && vtype_q[7]) begin
                  if (i < 4) vreg[vd][i*32 +: 32] <= 32'hffff_ffff;
                  else       vreg[vd + 5'd1][(i-4)*32 +: 32] <= 32'hffff_ffff;
                end
              end
              3'b010: if (i < 4) begin
                if ((i >= vl_q) && vtype_q[6]) begin
                  if (i < 2) vreg[vd][i*64 +: 64] <= 64'hffff_ffff_ffff_ffff;
                  else       vreg[vd + 5'd1][(i-2)*64 +: 64] <= 64'hffff_ffff_ffff_ffff;
                end else if ((i < vl_q) && !instr_i[25] && !vreg[0][i] && vtype_q[7]) begin
                  if (i < 2) vreg[vd][i*64 +: 64] <= 64'hffff_ffff_ffff_ffff;
                  else       vreg[vd + 5'd1][(i-2)*64 +: 64] <= 64'hffff_ffff_ffff_ffff;
                end
              end
              default: ;
            endcase
          end
        end
      end else if (vtype_q[7:6] != 2'b00 && (is_vector_data_op || is_vector_mask_result_op)) begin
        if (is_vector_mask_result_op) begin
          for (int i = 0; i < 16; i++) begin
            if ((i >= vector_vstart_i) &&
                ((vsew_q == 3'b000) ||
                 ((vsew_q == 3'b001) && (i < 8)) ||
                 ((vsew_q == 3'b010) && (i < 4)) ||
                 ((vsew_q == 3'b011) && (i < 2)))) begin
              if ((i >= vl_q) && vtype_q[6]) vreg[vd][i] <= 1'b1;
              else if ((i < vl_q) && !instr_i[25] && !vreg[0][i] && vtype_q[7])
                vreg[vd][i] <= 1'b1;
            end
          end
        end else begin
          for (int i = 0; i < 16; i++) begin
            if (i >= vector_vstart_i) begin
              case (vsew_q)
                3'b000: begin
                  if ((i >= vl_q) && vtype_q[6]) vreg[vd][i*8 +: 8] <= 8'hff;
                  else if ((i < vl_q) && !instr_i[25] && !vreg[0][i] && vtype_q[7] &&
                           !(is_vslideup && (i < vector_perm_offset)))
                    vreg[vd][i*8 +: 8] <= 8'hff;
                end
                3'b001: if (i < 8) begin
                  if ((i >= vl_q) && vtype_q[6]) vreg[vd][i*16 +: 16] <= 16'hffff;
                  else if ((i < vl_q) && !instr_i[25] && !vreg[0][i] && vtype_q[7] &&
                           !(is_vslideup && (i < vector_perm_offset)))
                    vreg[vd][i*16 +: 16] <= 16'hffff;
                end
                3'b010: if (i < 4) begin
                  if ((i >= vl_q) && vtype_q[6]) vreg[vd][i*32 +: 32] <= 32'hffff_ffff;
                  else if ((i < vl_q) && !instr_i[25] && !vreg[0][i] && vtype_q[7] &&
                           !(is_vslideup && (i < vector_perm_offset)))
                    vreg[vd][i*32 +: 32] <= 32'hffff_ffff;
                end
                default: if (i < 2) begin
                  if ((i >= vl_q) && vtype_q[6]) vreg[vd][i*64 +: 64] <= 64'hffff_ffff_ffff_ffff;
                  else if ((i < vl_q) && !instr_i[25] && !vreg[0][i] && vtype_q[7] &&
                           !(is_vslideup && (i < vector_perm_offset)))
                    vreg[vd][i*64 +: 64] <= 64'hffff_ffff_ffff_ffff;
                end
              endcase
            end
          end
        end
      end
      end
    end
  end
endmodule

`endif // MOON_VECTOR_UNIT_SV
