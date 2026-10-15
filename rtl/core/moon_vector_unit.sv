// ============================================================================
// File: rtl/core/moon_vector_unit.sv
// Description: RVV 1.0 integer slice with VLEN=128 and LMUL=1.
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
  input  logic [63:0] scalar_rs2_i,
  input  logic [63:0] vector_vstart_i,
  input  logic        vector_mem_fault_i,
  output logic        vector_vstart_clear_o,
  output logic        vector_vxsat_set_o,
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
  logic         is_vsub_vv;
  logic         is_vsub_vx;
  logic         is_vlogic;
  logic         is_vshift;
  logic         is_vcompare;
  logic         is_vminmax;
  logic         is_vmask_logic;
  logic         is_vector_reduction;
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
  logic [63:0]  vector_perm_offset;

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
    logic signed [63:0] signed_a;
    logic signed [63:0] signed_b;
    logic [63:0] unsigned_a;
    logic [63:0] unsigned_b;
    logic [63:0] result;
    logic [63:0] mask;
    begin
      case (sew)
        3'b000: begin
          signed_a = {{56{operand_a[7]}}, operand_a[7:0]};
          signed_b = {{56{operand_b[7]}}, operand_b[7:0]};
          unsigned_a = {56'd0, operand_a[7:0]};
          unsigned_b = {56'd0, operand_b[7:0]};
          mask = 64'hff;
        end
        3'b001: begin
          signed_a = {{48{operand_a[15]}}, operand_a[15:0]};
          signed_b = {{48{operand_b[15]}}, operand_b[15:0]};
          unsigned_a = {48'd0, operand_a[15:0]};
          unsigned_b = {48'd0, operand_b[15:0]};
          mask = 64'hffff;
        end
        3'b010: begin
          signed_a = {{32{operand_a[31]}}, operand_a[31:0]};
          signed_b = {{32{operand_b[31]}}, operand_b[31:0]};
          unsigned_a = {32'd0, operand_a[31:0]};
          unsigned_b = {32'd0, operand_b[31:0]};
          mask = 64'hffff_ffff;
        end
        default: begin
          signed_a = operand_a;
          signed_b = operand_b;
          unsigned_a = operand_a;
          unsigned_b = operand_b;
          mask = 64'hffff_ffff_ffff_ffff;
        end
      endcase
      if (operation[0]) begin
        if (signed_b == 0)
          result = operation[1] ? signed_a : mask;
        else
          result = operation[1] ? (signed_a % signed_b) : (signed_a / signed_b);
      end else begin
        if (unsigned_b == 0)
          result = operation[1] ? unsigned_a : mask;
        else
          result = operation[1] ? (unsigned_a % unsigned_b) : (unsigned_a / unsigned_b);
      end
      vector_divrem = result & mask;
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
          signed_min = -2147483648;
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
                             is_vector_sat ||
                             is_vsub_vv || is_vsub_vx || is_vlogic ||
                             is_vshift || is_vminmax || is_vector_permute;
  assign is_vector_mask_result_op = is_vmask_logic || is_vcompare;
  assign vd  = instr_i[11:7];
  assign vs1 = instr_i[19:15];
  assign vs2 = instr_i[24:20];

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
      end else if (is_vector_permute) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) &&
              (instr_i[25] || vreg[0][i]) &&
              !(is_vslideup &&
                (i < ((instr_i[14:12] == 3'b011) ? instr_i[19:15] : scalar_rs1_i)))) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_permute_element(
                vreg[vs2], vreg[vs1], i[4:0], vl_q, vsew_q,
                instr_i[31:26], instr_i[14:12], scalar_rs1_i, instr_i[19:15])[7:0];
              3'b001: if (i < 8) vreg[vd][i*16 +: 16] <= vector_permute_element(
                vreg[vs2], vreg[vs1], i[4:0], vl_q, vsew_q,
                instr_i[31:26], instr_i[14:12], scalar_rs1_i, instr_i[19:15])[15:0];
              3'b010: if (i < 4) vreg[vd][i*32 +: 32] <= vector_permute_element(
                vreg[vs2], vreg[vs1], i[4:0], vl_q, vsew_q,
                instr_i[31:26], instr_i[14:12], scalar_rs1_i, instr_i[19:15])[31:0];
              default: if (i < 2) vreg[vd][i*64 +: 64] <= vector_permute_element(
                vreg[vs2], vreg[vs1], i[4:0], vl_q, vsew_q,
                instr_i[31:26], instr_i[14:12], scalar_rs1_i, instr_i[19:15]);
            endcase
          end
        end
      end else if (is_vector_sat) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_sat_result(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vsat_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26])[7:0];
              3'b001: if (i < 8) vreg[vd][i*16 +: 16] <= vector_sat_result(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vsat_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26])[15:0];
              3'b010: if (i < 4) vreg[vd][i*32 +: 32] <= vector_sat_result(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vsat_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26])[31:0];
              default: if (i < 2) vreg[vd][i*64 +: 64] <= vector_sat_result(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vsat_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26])[63:0];
            endcase
          end
        end
      end else if (is_vdivrem_vv || is_vdivrem_vx) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_divrem(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vdivrem_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              3'b001: if (i < 8) vreg[vd][i*16 +: 16] <= vector_divrem(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vdivrem_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              3'b010: if (i < 4) vreg[vd][i*32 +: 32] <= vector_divrem(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vdivrem_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              default: if (i < 2) vreg[vd][i*64 +: 64] <= vector_divrem(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                is_vdivrem_vv ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
            endcase
          end
        end
      end else if (is_vmulh_vv || is_vmulh_vx || is_vmulhu_vv ||
                   is_vmulhu_vx || is_vmulhsu_vv || is_vmulhsu_vx) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_mul_high(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                (instr_i[14:12] == 3'b010) ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              3'b001: if (i < 8) vreg[vd][i*16 +: 16] <= vector_mul_high(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                (instr_i[14:12] == 3'b010) ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              3'b010: if (i < 4) vreg[vd][i*32 +: 32] <= vector_mul_high(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                (instr_i[14:12] == 3'b010) ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
              default: if (i < 2) vreg[vd][i*64 +: 64] <= vector_mul_high(
                vector_element(vreg[vs2], i[4:0], vsew_q),
                (instr_i[14:12] == 3'b010) ? vector_element(vreg[vs1], i[4:0], vsew_q) : scalar_rs1_i,
                vsew_q, instr_i[31:26]);
            endcase
          end
        end
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
      end else if (is_vadd_vv) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_addsub(vreg[vs2][i*8 +: 8], vreg[vs1][i*8 +: 8], vsew_q, 1'b0);
              3'b001: vreg[vd][i*16 +: 16] <= vector_addsub(vreg[vs2][i*16 +: 16], vreg[vs1][i*16 +: 16], vsew_q, 1'b0);
              3'b010: vreg[vd][i*32 +: 32] <= vector_addsub(vreg[vs2][i*32 +: 32], vreg[vs1][i*32 +: 32], vsew_q, 1'b0);
              default: if (i < 2) vreg[vd][i*64 +: 64] <= vector_addsub(vreg[vs2][i*64 +: 64], vreg[vs1][i*64 +: 64], vsew_q, 1'b0);
            endcase
          end
        end
      end else if (is_vadd_vx) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_addsub(vreg[vs2][i*8 +: 8],
                  (instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} : scalar_rs1_i, vsew_q, 1'b0);
              3'b001: vreg[vd][i*16 +: 16] <= vector_addsub(vreg[vs2][i*16 +: 16],
                  (instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} : scalar_rs1_i, vsew_q, 1'b0);
              3'b010: vreg[vd][i*32 +: 32] <= vector_addsub(vreg[vs2][i*32 +: 32],
                  (instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} : scalar_rs1_i, vsew_q, 1'b0);
              default: if (i < 2) vreg[vd][i*64 +: 64] <= vector_addsub(vreg[vs2][i*64 +: 64],
                  (instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} : scalar_rs1_i, vsew_q, 1'b0);
            endcase
          end
        end
      end else if (is_vsub_vv) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_addsub(vreg[vs2][i*8 +: 8], vreg[vs1][i*8 +: 8], vsew_q, 1'b1);
              3'b001: vreg[vd][i*16 +: 16] <= vector_addsub(vreg[vs2][i*16 +: 16], vreg[vs1][i*16 +: 16], vsew_q, 1'b1);
              3'b010: vreg[vd][i*32 +: 32] <= vector_addsub(vreg[vs2][i*32 +: 32], vreg[vs1][i*32 +: 32], vsew_q, 1'b1);
              default: if (i < 2) vreg[vd][i*64 +: 64] <= vector_addsub(vreg[vs2][i*64 +: 64], vreg[vs1][i*64 +: 64], vsew_q, 1'b1);
            endcase
          end
        end
      end else if (is_vsub_vx) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i*8 +: 8] <= vector_addsub(vreg[vs2][i*8 +: 8], scalar_rs1_i, vsew_q, 1'b1);
              3'b001: vreg[vd][i*16 +: 16] <= vector_addsub(vreg[vs2][i*16 +: 16], scalar_rs1_i, vsew_q, 1'b1);
              3'b010: vreg[vd][i*32 +: 32] <= vector_addsub(vreg[vs2][i*32 +: 32], scalar_rs1_i, vsew_q, 1'b1);
              default: if (i < 2) vreg[vd][i*64 +: 64] <= vector_addsub(vreg[vs2][i*64 +: 64], scalar_rs1_i, vsew_q, 1'b1);
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
      end else if (is_vcompare) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (i >= vector_vstart_i) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i] <= vector_compare(
                  vector_element(vreg[vs2], i[4:0], vsew_q),
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i :
                  ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} :
                   vector_element(vreg[vs1], i[4:0], vsew_q)), vsew_q, instr_i[31:26]);
              3'b001: if (i < 8) vreg[vd][i] <= vector_compare(
                  vector_element(vreg[vs2], i[4:0], vsew_q),
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i :
                  ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} :
                   vector_element(vreg[vs1], i[4:0], vsew_q)), vsew_q, instr_i[31:26]);
              3'b010: if (i < 4) vreg[vd][i] <= vector_compare(
                  vector_element(vreg[vs2], i[4:0], vsew_q),
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i :
                  ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} :
                   vector_element(vreg[vs1], i[4:0], vsew_q)), vsew_q, instr_i[31:26]);
              default: if (i < 2) vreg[vd][i] <= vector_compare(
                  vector_element(vreg[vs2], i[4:0], vsew_q),
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i :
                  ((instr_i[14:12] == 3'b011) ? {{59{instr_i[19]}}, instr_i[19:15]} :
                   vector_element(vreg[vs1], i[4:0], vsew_q)), vsew_q, instr_i[31:26]);
            endcase
          end
        end
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

      if (vtype_q[7:6] != 2'b00 && (is_vector_data_op || is_vector_mask_result_op)) begin
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
