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
  output logic        scalar_result_valid_o,
  output logic [63:0] scalar_result_o
);
  logic [127:0] vreg [0:31];
  logic [4:0]   vl_q;
  logic [4:0]   vl;
  logic [4:0]   vlmax;
  logic [2:0]   vsew_q;
  logic         is_vsetvli;
  logic         is_vsetivli;
  logic         is_vset_config;
  logic         is_vmv_x_s;
  logic         is_vmv_v_x;
  logic         is_vadd_vv;
  logic         is_vadd_vx;
  logic         is_vsub_vv;
  logic         is_vsub_vx;
  logic         is_vlogic;
  logic         is_vshift;
  logic         is_vcompare;
  logic         is_vminmax;
  logic [4:0]   vd, vs1, vs2;

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
    case (operation)
      6'b011000: begin
        case (sew)
          3'b000: vector_compare = operand_a[7:0] == operand_b[7:0];
          3'b001: vector_compare = operand_a[15:0] == operand_b[15:0];
          3'b010: vector_compare = operand_a[31:0] == operand_b[31:0];
          default: vector_compare = operand_a == operand_b;
        endcase
      end
      6'b011001: begin
        case (sew)
          3'b000: vector_compare = operand_a[7:0] != operand_b[7:0];
          3'b001: vector_compare = operand_a[15:0] != operand_b[15:0];
          3'b010: vector_compare = operand_a[31:0] != operand_b[31:0];
          default: vector_compare = operand_a != operand_b;
        endcase
      end
      default: begin
        case (sew)
          3'b000: vector_compare = (operation == 6'b011010) ? (operand_a[7:0] < operand_b[7:0]) :
                                                               ($signed(operand_a[7:0]) < $signed(operand_b[7:0]));
          3'b001: vector_compare = (operation == 6'b011010) ? (operand_a[15:0] < operand_b[15:0]) :
                                                               ($signed(operand_a[15:0]) < $signed(operand_b[15:0]));
          3'b010: vector_compare = (operation == 6'b011010) ? (operand_a[31:0] < operand_b[31:0]) :
                                                               ($signed(operand_a[31:0]) < $signed(operand_b[31:0]));
          default: vector_compare = (operation == 6'b011010) ? (operand_a < operand_b) :
                                                               ($signed(operand_a) < $signed(operand_b));
        endcase
      end
    endcase
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

  assign is_vsetvli = (instr_i[6:0] == 7'b1010111) && (instr_i[14:12] == 3'b111);
  assign is_vsetivli = (instr_i[6:0] == 7'b1010111) && (instr_i[14:12] == 3'b111) &&
                       (instr_i[31:30] == 2'b11);
  assign is_vset_config = is_vsetivli || (is_vsetvli && !instr_i[31]);
  assign is_vmv_x_s = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b010000) &&
                      instr_i[25] && (instr_i[14:12] == 3'b010) && (instr_i[19:15] == 5'd0);
  assign is_vmv_v_x = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b010111) &&
                      instr_i[25] && (instr_i[14:12] == 3'b100) && (instr_i[24:20] == 5'd0);
  assign is_vadd_vv = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b000000) &&
                      (instr_i[14:12] == 3'b000);
  assign is_vadd_vx = (instr_i[6:0] == 7'b1010111) && (instr_i[31:26] == 6'b000000) &&
                      ((instr_i[14:12] == 3'b100) || (instr_i[14:12] == 3'b011));
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
                       ((instr_i[14:12] == 3'b000) || (instr_i[14:12] == 3'b100));
  assign is_vminmax = (instr_i[6:0] == 7'b1010111) &&
                      ((instr_i[31:26] == 6'b000100) ||
                       (instr_i[31:26] == 6'b000101) ||
                       (instr_i[31:26] == 6'b000110) ||
                       (instr_i[31:26] == 6'b000111)) &&
                      ((instr_i[14:12] == 3'b000) || (instr_i[14:12] == 3'b100));
  assign vd  = instr_i[11:7];
  assign vs1 = instr_i[19:15];
  assign vs2 = instr_i[24:20];

  always_comb begin
    vl = vl_q;
    vlmax = 5'd0;
    if (is_vset_config) begin
      if ((instr_i[22:20] == 3'b000) && (instr_i[25:23] <= 3'b011)) begin
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
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      vl_q <= '0;
      vsew_q <= 3'b010;
      for (int i = 0; i < 32; i++) vreg[i] <= '0;
    end else if (valid_i && advance_i) begin
      if (is_vset_config) begin
        vl_q <= vl;
        if (vlmax != 0) vsew_q <= instr_i[25:23];
      end else if (is_vmv_v_x) begin
        case (vsew_q)
          3'b000: for (int i = 0; i < 16; i++) if (i < vl_q) vreg[vd][i*8 +: 8] <= scalar_rs1_i[7:0];
          3'b001: for (int i = 0; i < 8; i++) if (i < vl_q) vreg[vd][i*16 +: 16] <= scalar_rs1_i[15:0];
          3'b010: for (int i = 0; i < 4; i++) if (i < vl_q) vreg[vd][i*32 +: 32] <= scalar_rs1_i[31:0];
          default: for (int i = 0; i < 2; i++) if (i < vl_q) vreg[vd][i*64 +: 64] <= scalar_rs1_i;
        endcase
      end else if (is_vadd_vv) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (instr_i[25] || vreg[0][i])) begin
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
          if ((i < vl_q) && (instr_i[25] || vreg[0][i])) begin
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
          if ((i < vl_q) && (instr_i[25] || vreg[0][i])) begin
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
          if ((i < vl_q) && (instr_i[25] || vreg[0][i])) begin
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
          if ((i < vl_q) && (instr_i[25] || vreg[0][i])) begin
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
          if ((i < vl_q) && (instr_i[25] || vreg[0][i])) begin
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
          if ((i < vl_q) && (instr_i[25] || vreg[0][i])) begin
            case (vsew_q)
              3'b000: vreg[vd][i] <= vector_compare(vreg[vs2][i*8 +: 8],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i : vreg[vs1][i*8 +: 8], vsew_q, instr_i[31:26]);
              3'b001: vreg[vd][i] <= vector_compare(vreg[vs2][i*16 +: 16],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i : vreg[vs1][i*16 +: 16], vsew_q, instr_i[31:26]);
              3'b010: vreg[vd][i] <= vector_compare(vreg[vs2][i*32 +: 32],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i : vreg[vs1][i*32 +: 32], vsew_q, instr_i[31:26]);
              default: if (i < 2) vreg[vd][i] <= vector_compare(vreg[vs2][i*64 +: 64],
                  (instr_i[14:12] == 3'b100) ? scalar_rs1_i : vreg[vs1][i*64 +: 64], vsew_q, instr_i[31:26]);
            endcase
          end
        end
      end else if (is_vminmax) begin
        for (int i = 0; i < 16; i++) begin
          if ((i < vl_q) && (instr_i[25] || vreg[0][i])) begin
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
    end
  end
endmodule

`endif // MOON_VECTOR_UNIT_SV
