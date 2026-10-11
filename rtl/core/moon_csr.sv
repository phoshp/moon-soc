// ============================================================================
// File: rtl/core/moon_csr.sv
// Description: RISC-V Machine-Mode Control and Status Register (CSR) Unit
//              with interrupt/exception handling and parameterized mhartid.
// ============================================================================

`ifndef MOON_CSR_SV
`define MOON_CSR_SV

`include "moon_pkg.sv"

module moon_csr
  import moon_pkg::*;
#(
  parameter int HART_ID = 0
)(
  input  logic             clk_i,
  input  logic             rst_ni,

  // CSR Instruction Interface
  input  logic             csr_we_i,
  input  logic [11:0]      csr_addr_i,
  input  logic [2:0]       csr_op_i,       // funct3: 001=RW, 010=RS, 011=RC, 101=RWI, 110=RSI, 111=RCI
  input  logic [XLEN-1:0]  csr_wdata_i,
  output logic [XLEN-1:0]  csr_rdata_o,

  // Retired Instruction Count
  input  logic             instret_i,

  // External Hardware Interrupt Lines
  input  logic             timer_irq_i,    // from CLINT
  input  logic             software_irq_i, // from CLINT (IPI)
  input  logic             external_irq_i, // from PLIC

  // Trap and Return Interface
  input  logic             trap_enter_i,
  input  logic             is_interrupt_i,
  input  logic [62:0]      trap_cause_i,
  input  logic [XLEN-1:0]  trap_pc_i,
  input  logic [XLEN-1:0]  trap_val_i,
  input  logic             mret_i,

  // Trap Control Outputs
  output logic [XLEN-1:0]  trap_vector_o,
  output logic [XLEN-1:0]  mepc_o,
  output logic             interrupt_pending_o,
  output logic [62:0]      interrupt_cause_o,

  // Floating-Point Unit Status
  input  logic [4:0]       fpu_flags_i,
  input  logic             fpu_flags_we_i,
  output logic [2:0]       frm_o
);

  // --------------------------------------------------------------------------
  // CSR Register State
  // --------------------------------------------------------------------------
  // mstatus: [12:11]=MPP, [7]=MPIE, [3]=MIE, [14:13]=FS
  logic        mstatus_mie;
  logic        mstatus_mpie;
  logic [1:0]  mstatus_mpp;
  logic [1:0]  mstatus_fs;

  // mie & mip: [11]=MEI, [7]=MTI, [3]=MSI
  logic        mie_meie, mie_mtie, mie_msie;
  logic        mip_meip, mip_mtip, mip_msip;

  logic [XLEN-1:0] mtvec_q;
  logic [XLEN-1:0] mepc_q;
  logic [XLEN-1:0] mcause_q;
  logic [XLEN-1:0] mtval_q;
  logic [63:0]     mcycle_q;
  logic [63:0]     minstret_q;

  // fcsr: [7:5]=frm, [4:0]=fflags
  logic [2:0]  fcsr_frm;
  logic [4:0]  fcsr_fflags;

  assign frm_o = fcsr_frm;

  // MISA: 64-bit (MXL=2), Extensions: I, M, A, F, D
  // bit 0 = A, 3 = D, 5 = F, 8 = I, 12 = M
  localparam logic [XLEN-1:0] MISA_VAL = (2'b10 << 62) | (1 << 0) | (1 << 3) | (1 << 5) | (1 << 8) | (1 << 12);

  // Map MIP from hardware interrupt inputs
  assign mip_msip = software_irq_i;
  assign mip_mtip = timer_irq_i;
  assign mip_meip = external_irq_i;

  // Interrupt Evaluation
  wire irq_external_active = mie_meie && mip_meip;
  wire irq_software_active = mie_msie && mip_msip;
  wire irq_timer_active    = mie_mtie && mip_mtip;

  always_comb begin
    interrupt_pending_o = mstatus_mie && (irq_external_active || irq_software_active || irq_timer_active);
    if (irq_external_active) begin
      interrupt_cause_o = INT_EXTERNAL_M;
    end else if (irq_software_active) begin
      interrupt_cause_o = INT_SOFTWARE_M;
    end else begin
      interrupt_cause_o = INT_TIMER_M;
    end
  end

  assign trap_vector_o = mtvec_q;
  assign mepc_o        = mepc_q;

  // CSR Read Logic
  always_comb begin
    case (csr_addr_i)
      CSR_MSTATUS:  csr_rdata_o = {47'b0, mstatus_fs, 2'b0, mstatus_mpp, 3'b0, mstatus_mpie, 3'b0, mstatus_mie, 3'b0};
      CSR_MISA:     csr_rdata_o = MISA_VAL;
      CSR_MIE:      csr_rdata_o = {52'b0, mie_meie, 3'b0, mie_mtie, 3'b0, mie_msie, 3'b0};
      CSR_MIP:      csr_rdata_o = {52'b0, mip_meip, 3'b0, mip_mtip, 3'b0, mip_msip, 3'b0};
      CSR_MTVEC:    csr_rdata_o = mtvec_q;
      CSR_MEPC:     csr_rdata_o = mepc_q;
      CSR_MCAUSE:   csr_rdata_o = mcause_q;
      CSR_MTVAL:    csr_rdata_o = mtval_q;
      CSR_MHARTID:  csr_rdata_o = 64'(HART_ID);
      CSR_MCYCLE:   csr_rdata_o = mcycle_q;
      CSR_MINSTRET: csr_rdata_o = minstret_q;
      CSR_FFLAGS:   csr_rdata_o = {59'b0, fcsr_fflags};
      CSR_FRM:      csr_rdata_o = {61'b0, fcsr_frm};
      CSR_FCSR:     csr_rdata_o = {56'b0, fcsr_frm, fcsr_fflags};
      default:      csr_rdata_o = '0;
    endcase
  end

  // Calculate new write value based on CSR atomic operation
  logic [XLEN-1:0] next_csr_val;
  always_comb begin
    case (csr_op_i[1:0])
      2'b01: next_csr_val = csr_wdata_i;                   // RW: Replace
      2'b10: next_csr_val = csr_rdata_o | csr_wdata_i;     // RS: Set bits
      2'b11: next_csr_val = csr_rdata_o & ~csr_wdata_i;    // RC: Clear bits
      default: next_csr_val = csr_wdata_i;
    endcase
  end

  // CSR Register Update Logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mstatus_mie  <= 1'b0;
      mstatus_mpie <= 1'b0;
      mstatus_mpp  <= 2'b11; // M-mode
      mstatus_fs   <= 2'b01; // FP Initial
      mie_meie     <= 1'b0;
      mie_mtie     <= 1'b0;
      mie_msie     <= 1'b0;
      mtvec_q      <= 64'h0000_1000;
      mepc_q       <= '0;
      mcause_q     <= '0;
      mtval_q      <= '0;
      mcycle_q     <= '0;
      minstret_q   <= '0;
      fcsr_frm     <= 3'b000;
      fcsr_fflags  <= 5'b00000;
    end else begin
      // Cycle and Instruction Counters
      mcycle_q <= mcycle_q + 1'b1;
      if (instret_i) begin
        minstret_q <= minstret_q + 1'b1;
      end

      // Update FP flags from FPU
      if (fpu_flags_we_i) begin
        fcsr_fflags <= fcsr_fflags | fpu_flags_i;
        mstatus_fs  <= 2'b11; // Dirty
      end

      // Trap Entry
      if (trap_enter_i) begin
        mepc_q       <= trap_pc_i;
        mcause_q     <= {is_interrupt_i, trap_cause_i};
        mtval_q      <= trap_val_i;
        mstatus_mpie <= mstatus_mie;
        mstatus_mie  <= 1'b0;
        mstatus_mpp  <= 2'b11;
      end else if (mret_i) begin
        // Trap Return
        mstatus_mie  <= mstatus_mpie;
        mstatus_mpie <= 1'b1;
      end else if (csr_we_i) begin
        // Software CSR Write
        case (csr_addr_i)
          CSR_MSTATUS: begin
            mstatus_mie  <= next_csr_val[3];
            mstatus_mpie <= next_csr_val[7];
            mstatus_mpp  <= next_csr_val[12:11];
            mstatus_fs   <= next_csr_val[14:13];
          end
          CSR_MIE: begin
            mie_msie <= next_csr_val[3];
            mie_mtie <= next_csr_val[7];
            mie_meie <= next_csr_val[11];
          end
          CSR_MTVEC:  mtvec_q  <= next_csr_val;
          CSR_MEPC:   mepc_q   <= next_csr_val;
          CSR_MCAUSE: mcause_q <= next_csr_val;
          CSR_MTVAL:  mtval_q  <= next_csr_val;
          CSR_FFLAGS: begin
            fcsr_fflags <= next_csr_val[4:0];
            mstatus_fs  <= 2'b11;
          end
          CSR_FRM: begin
            fcsr_frm   <= next_csr_val[2:0];
            mstatus_fs <= 2'b11;
          end
          CSR_FCSR: begin
            fcsr_fflags <= next_csr_val[4:0];
            fcsr_frm    <= next_csr_val[7:5];
            mstatus_fs  <= 2'b11;
          end
          default: ;
        endcase
      end
    end
  end

endmodule : moon_csr

`endif // MOON_CSR_SV
