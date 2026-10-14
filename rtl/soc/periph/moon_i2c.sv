// APB programmed, single-master open-drain I2C controller.
`ifndef MOON_I2C_SV
`define MOON_I2C_SV
`include "axi_pkg.sv"

module moon_i2c import axi_pkg::*; #(
  parameter logic [31:0] BASE_ADDR = 32'h1000_7000
)(
  input logic clk_i, rst_ni,
  input apb_req_t req_i,
  output apb_resp_t resp_o,
  input logic sda_i,
  output logic scl_o,
  output logic sda_o,
  output logic sda_oe_o
);
  localparam logic [7:0] REG_CTRL=8'h00, REG_DIV=8'h04,
                         REG_TX=8'h08, REG_RX=8'h0c, REG_STATUS=8'h10;
  typedef enum logic [2:0] {IDLE, START, SEND, ACK, RECEIVE, MASTER_ACK, STOP} state_e;
  state_e state_q;
  logic [15:0] div_q, div_cnt_q;
  logic [7:0] tx_q, rx_q;
  logic [3:0] bit_q;
  logic read_q, ack_q, phase_q, scl_q;
  wire tick = div_cnt_q >= (div_q == 0 ? 16'd1 : div_q);
  wire command = req_i.sel && req_i.enable && req_i.write && req_i.addr[7:0] == REG_CTRL;

  // Open-drain SDA: output enable means actively pull the line low.
  always_comb begin
    scl_o = scl_q;
    sda_o = 1'b0;
    sda_oe_o = 1'b0;
    case (state_q)
      START: sda_oe_o = 1'b1;
      SEND: sda_oe_o = !tx_q[7];
      MASTER_ACK: sda_oe_o = !read_q;
      STOP: sda_oe_o = 1'b1;
      default: ;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q<=IDLE; div_q<=16'd1; div_cnt_q<='0; tx_q<='0; rx_q<='0;
      bit_q<='0; read_q<=1'b0; ack_q<=1'b0; phase_q<=1'b0; scl_q<=1'b1;
    end else begin
      if (req_i.sel && req_i.enable && req_i.write) begin
        if (req_i.addr[7:0] == REG_DIV) div_q<=req_i.wdata[15:0];
        if (req_i.addr[7:0] == REG_TX) tx_q<=req_i.wdata[7:0];
      end
      if (command && state_q==IDLE) begin
        // CTRL[0]=start+write, CTRL[1]=start+read, CTRL[2]=stop.
        if (req_i.wdata[2]) begin state_q<=STOP; phase_q<=1'b0; scl_q<=1'b0; end
        else if (req_i.wdata[0] || req_i.wdata[1]) begin
          read_q<=req_i.wdata[1]; bit_q<='0; rx_q<='0; phase_q<=1'b0; scl_q<=1'b1; state_q<=START;
        end
      end else if (state_q != IDLE) begin
        if (tick) begin
          div_cnt_q<='0;
          case (state_q)
            START: begin
              // Hold SDA low while SCL is high for the START condition.
              state_q<=read_q ? RECEIVE : SEND; scl_q<=1'b0; phase_q<=1'b0;
            end
            SEND: begin
              if (!phase_q) begin scl_q<=1'b1; phase_q<=1'b1; end
              else begin
                scl_q<=1'b0; phase_q<=1'b0; tx_q<={tx_q[6:0],1'b0};
                if (bit_q==7) begin bit_q<='0; state_q<=ACK; end
                else bit_q<=bit_q+1'b1;
              end
            end
            ACK: begin
              if (!phase_q) begin scl_q<=1'b1; phase_q<=1'b1; end
              else begin ack_q<=!sda_i; scl_q<=1'b0; phase_q<=1'b0; state_q<=IDLE; end
            end
            RECEIVE: begin
              if (!phase_q) begin scl_q<=1'b1; phase_q<=1'b1; end
              else begin
                rx_q<={rx_q[6:0],sda_i}; scl_q<=1'b0; phase_q<=1'b0;
                if (bit_q==7) begin bit_q<='0; state_q<=MASTER_ACK; end
                else bit_q<=bit_q+1'b1;
              end
            end
            MASTER_ACK: begin scl_q<=1'b1; phase_q<=1'b0; state_q<=IDLE; end
            STOP: begin
              if (!phase_q) begin scl_q<=1'b1; phase_q<=1'b1; end
              else begin scl_q<=1'b1; phase_q<=1'b0; state_q<=IDLE; end
            end
            default: begin state_q<=IDLE; scl_q<=1'b1; end
          endcase
        end else div_cnt_q<=div_cnt_q+1'b1;
      end
    end
  end

  always_comb begin
    resp_o.ready=req_i.sel && req_i.enable;
    resp_o.slverr=1'b0;
    resp_o.rdata='0;
    case(req_i.addr[7:0])
      REG_CTRL: resp_o.rdata={29'b0,(state_q!=IDLE),2'b0};
      REG_DIV: resp_o.rdata={16'b0,div_q};
      REG_TX: resp_o.rdata={24'b0,tx_q};
      REG_RX: resp_o.rdata={24'b0,rx_q};
      REG_STATUS: resp_o.rdata={30'b0,ack_q,(state_q!=IDLE)};
      default: ;
    endcase
  end
endmodule
`endif
