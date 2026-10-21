// ============================================================================
// File: rtl/core/moon_csr.sv
// Description: RISC-V Machine and Supervisor Mode Control and Status Register
//              (CSR) Unit supporting RVA23 privileged architecture (PRV_U,
//              PRV_S, PRV_M), exception/interrupt delegation (medeleg/mideleg),
//              Sstc timer extensions, and satp configuration.
// ============================================================================

`ifndef MOON_CSR_SV
`define MOON_CSR_SV

`include "moon_pkg.sv"

module moon_csr
  import moon_pkg::*;
#(
  parameter int HART_ID     = 0,
  parameter int PMP_ENTRIES = 8
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
  input  logic             sret_i,

  // Trap Control Outputs
  output logic [XLEN-1:0]  trap_vector_o,
  output logic [XLEN-1:0]  mepc_o,
  output logic [XLEN-1:0]  sepc_o,
  output logic             interrupt_pending_o,
  output logic [62:0]      interrupt_cause_o,

  // Privilege Level & Memory Management Outputs
  output priv_lvl_e        priv_lvl_o,
  output logic [XLEN-1:0]  satp_o,
  output logic             sum_o,
  output logic             mxr_o,
  output logic [7:0]       pmpcfg_o [0:PMP_ENTRIES-1],
  output logic [XLEN-1:0]  pmpaddr_o [0:PMP_ENTRIES-1],

  // Floating-Point Unit Status
  input  logic [4:0]       fpu_flags_i,
  input  logic             fpu_flags_we_i,
  output logic [2:0]       frm_o
);

  // --------------------------------------------------------------------------
  // Privilege Level Register
  // --------------------------------------------------------------------------
  priv_lvl_e priv_lvl_q;
  assign priv_lvl_o = priv_lvl_q;

  // --------------------------------------------------------------------------
  // CSR Register State
  // --------------------------------------------------------------------------
  // mstatus fields
  logic        mstatus_sie;
  logic        mstatus_mie;
  logic        mstatus_spie;
  logic        mstatus_mpie;
  logic        mstatus_spp;
  logic [1:0]  mstatus_mpp;
  logic [1:0]  mstatus_fs;
  logic        mstatus_sum;
  logic        mstatus_mxr;
  logic        mstatus_tvm;
  logic        mstatus_tw;
  logic        mstatus_tsr;
  wire  [1:0]  mstatus_uxl = 2'b10; // 64-bit
  wire  [1:0]  mstatus_sxl = 2'b10; // 64-bit
  wire         mstatus_sd  = (mstatus_fs == 2'b11);

  assign sum_o = mstatus_sum;
  assign mxr_o = mstatus_mxr;

  // Trap Delegation Registers
  logic [XLEN-1:0] medeleg_q;
  logic [XLEN-1:0] mideleg_q;

  // Interrupt Enable & Pending bits
  logic        mie_meie, mie_seie;
  logic        mie_mtie, mie_stie;
  logic        mie_msie, mie_ssie;

  logic        mip_meip, mip_seip;
  logic        mip_mtip, mip_stip;
  logic        mip_msip, mip_ssip;

  // Machine Mode Trap Registers
  logic [XLEN-1:0] mtvec_q;
  logic [XLEN-1:0] mepc_q;
  logic [XLEN-1:0] mcause_q;
  logic [XLEN-1:0] mtval_q;
  logic [63:0]     mcycle_q;
  logic [63:0]     minstret_q;

  // Supervisor Mode Trap Registers
  logic [XLEN-1:0] stvec_q;
  logic [XLEN-1:0] sscratch_q;
  logic [XLEN-1:0] sepc_q;
  logic [XLEN-1:0] scause_q;
  logic [XLEN-1:0] stval_q;
  logic [XLEN-1:0] satp_q;
  logic [63:0]     stimecmp_q;

  assign satp_o = satp_q;
  assign sepc_o = sepc_q;

  // Physical Memory Protection Registers
  logic [7:0]      pmpcfg_q [0:PMP_ENTRIES-1];
  logic [XLEN-1:0] pmpaddr_q [0:PMP_ENTRIES-1];
  for (genvar pmp_i = 0; pmp_i < PMP_ENTRIES; pmp_i++) begin : gen_pmp_out
    assign pmpcfg_o[pmp_i]  = pmpcfg_q[pmp_i];
    assign pmpaddr_o[pmp_i] = pmpaddr_q[pmp_i];
  end

  // fcsr: [7:5]=frm, [4:0]=fflags
  logic [2:0]  fcsr_frm;
  logic [4:0]  fcsr_fflags;
  assign frm_o = fcsr_frm;

  // MISA: 64-bit (MXL=2), Standard Extensions: A, C, D, F, I, M, S, U
  // bit 0=A, 2=C, 3=D, 5=F, 8=I, 12=M, 18=S, 20=U
  localparam logic [XLEN-1:0] MISA_VAL =
    (2'b10 << 62) | (1 << 0) | (1 << 2) | (1 << 3) |
    (1 << 5) | (1 << 8) | (1 << 12) | (1 << 18) | (1 << 20);

  // Map hardware interrupt inputs
  assign mip_msip = software_irq_i;
  assign mip_mtip = timer_irq_i;
  assign mip_meip = external_irq_i;

  // Sstc timer extension: automatic supervisor timer interrupt
  wire sstc_timer_match = (stimecmp_q != '0) && (mcycle_q >= stimecmp_q);
  wire eff_stip         = mip_stip || sstc_timer_match;

  // --------------------------------------------------------------------------
  // Interrupt Evaluation across M and S Privilege Levels
  // --------------------------------------------------------------------------
  wire m_enabled = (priv_lvl_q < PRV_M) || ((priv_lvl_q == PRV_M) && mstatus_mie);
  wire s_enabled = (priv_lvl_q < PRV_S) || ((priv_lvl_q == PRV_S) && mstatus_sie);

  wire irq_meip_active = mie_meie && mip_meip && !mideleg_q[11] && m_enabled;
  wire irq_msip_active = mie_msie && mip_msip && !mideleg_q[3]  && m_enabled;
  wire irq_mtip_active = mie_mtie && mip_mtip && !mideleg_q[7]  && m_enabled;

  wire irq_seip_active = mie_seie && mip_seip && mideleg_q[9]   && s_enabled;
  wire irq_ssip_active = mie_ssie && mip_ssip && mideleg_q[1]   && s_enabled;
  wire irq_stip_active = mie_stie && eff_stip && mideleg_q[5]   && s_enabled;

  always_comb begin
    interrupt_pending_o = irq_meip_active || irq_msip_active || irq_mtip_active ||
                          irq_seip_active || irq_ssip_active || irq_stip_active;

    if (irq_meip_active) begin
      interrupt_cause_o = INT_EXTERNAL_M;
    end else if (irq_msip_active) begin
      interrupt_cause_o = INT_SOFTWARE_M;
    end else if (irq_mtip_active) begin
      interrupt_cause_o = INT_TIMER_M;
    end else if (irq_seip_active) begin
      interrupt_cause_o = INT_EXTERNAL_S;
    end else if (irq_ssip_active) begin
      interrupt_cause_o = INT_SOFTWARE_S;
    end else begin
      interrupt_cause_o = INT_TIMER_S;
    end
  end

  // --------------------------------------------------------------------------
  // Trap Delegation Evaluation
  // --------------------------------------------------------------------------
  wire trap_to_smode = (priv_lvl_q < PRV_M) &&
    (is_interrupt_i ? (trap_cause_i < 63'd16 && mideleg_q[trap_cause_i[3:0]])
                    : (trap_cause_i < 63'd16 && medeleg_q[trap_cause_i[3:0]]));

  wire [XLEN-1:0] sel_tvec = trap_to_smode ? stvec_q : mtvec_q;
  assign trap_vector_o = (sel_tvec[0] && is_interrupt_i) ?
                         {sel_tvec[XLEN-1:2], 2'b00} + (trap_cause_i << 2) :
                         {sel_tvec[XLEN-1:2], 2'b00};
  assign mepc_o        = mepc_q;

  // --------------------------------------------------------------------------
  // CSR Read Logic (M-mode and S-mode)
  // --------------------------------------------------------------------------
  always_comb begin
    case (csr_addr_i)
      // Machine Mode CSRs
      CSR_MSTATUS:  csr_rdata_o = {mstatus_sd, 27'b0, mstatus_sxl, mstatus_uxl,
                                   9'b0, mstatus_tsr, mstatus_tw, mstatus_tvm, mstatus_mxr, mstatus_sum, 1'b0,
                                   mstatus_fs, mstatus_mpp, 2'b00, mstatus_spp, mstatus_mpie, 1'b0,
                                   mstatus_spie, 1'b0, mstatus_mie, 1'b0, mstatus_sie, 1'b0};
      CSR_MISA:     csr_rdata_o = MISA_VAL;
      CSR_MEDELEG:  csr_rdata_o = medeleg_q;
      CSR_MIDELEG:  csr_rdata_o = mideleg_q;
      CSR_MIE:      csr_rdata_o = {52'b0, mie_meie, 1'b0, mie_seie, 1'b0, mie_mtie, 1'b0, mie_stie, 1'b0, mie_msie, 1'b0, mie_ssie, 1'b0};
      CSR_MIP:      csr_rdata_o = {52'b0, mip_meip, 1'b0, mip_seip, 1'b0, mip_mtip, 1'b0, eff_stip, 1'b0, mip_msip, 1'b0, mip_ssip, 1'b0};
      CSR_MTVEC:    csr_rdata_o = mtvec_q;
      CSR_MEPC:     csr_rdata_o = mepc_q;
      CSR_MCAUSE:   csr_rdata_o = mcause_q;
      CSR_MTVAL:    csr_rdata_o = mtval_q;
      CSR_MHARTID:  csr_rdata_o = 64'(HART_ID);
      CSR_MCYCLE:   csr_rdata_o = mcycle_q;
      CSR_MINSTRET: csr_rdata_o = minstret_q;

      // Supervisor Mode CSRs
      CSR_SSTATUS:  csr_rdata_o = {mstatus_sd, 29'b0, mstatus_uxl, 12'b0, mstatus_mxr, mstatus_sum, 1'b0,
                                   2'b0, mstatus_fs, 2'b0, 2'b00, mstatus_spp, 2'b0, mstatus_spie, 3'b0, mstatus_sie, 1'b0};
      CSR_SIE:      csr_rdata_o = {54'b0, mie_seie, 3'b0, mie_stie, 3'b0, mie_ssie, 1'b0} & mideleg_q;
      CSR_SIP:      csr_rdata_o = {54'b0, mip_seip, 3'b0, eff_stip, 3'b0, mip_ssip, 1'b0} & mideleg_q;
      CSR_STVEC:    csr_rdata_o = stvec_q;
      CSR_SSCRATCH: csr_rdata_o = sscratch_q;
      CSR_SEPC:     csr_rdata_o = sepc_q;
      CSR_SCAUSE:   csr_rdata_o = scause_q;
      CSR_STVAL:    csr_rdata_o = stval_q;
      CSR_SATP:     csr_rdata_o = satp_q;
      CSR_STIMECMP: csr_rdata_o = stimecmp_q;

      // PMP Registers (Entries 0..7 implemented; 8..15 hardwired to 0 per spec)
      CSR_PMPCFG0:  csr_rdata_o = {pmpcfg_q[7], pmpcfg_q[6], pmpcfg_q[5], pmpcfg_q[4],
                                   pmpcfg_q[3], pmpcfg_q[2], pmpcfg_q[1], pmpcfg_q[0]};
      CSR_PMPCFG2:  csr_rdata_o = '0;
      CSR_PMPADDR0: csr_rdata_o = pmpaddr_q[0];
      CSR_PMPADDR1: csr_rdata_o = pmpaddr_q[1];
      CSR_PMPADDR2: csr_rdata_o = pmpaddr_q[2];
      CSR_PMPADDR3: csr_rdata_o = pmpaddr_q[3];
      CSR_PMPADDR4: csr_rdata_o = pmpaddr_q[4];
      CSR_PMPADDR5: csr_rdata_o = pmpaddr_q[5];
      CSR_PMPADDR6: csr_rdata_o = pmpaddr_q[6];
      CSR_PMPADDR7: csr_rdata_o = pmpaddr_q[7];
      CSR_PMPADDR8, CSR_PMPADDR9, CSR_PMPADDR10, CSR_PMPADDR11,
      CSR_PMPADDR12, CSR_PMPADDR13, CSR_PMPADDR14, CSR_PMPADDR15: csr_rdata_o = '0;

      // Floating-Point CSRs
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

  // --------------------------------------------------------------------------
  // CSR Register Update Logic
  // --------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      priv_lvl_q   <= PRV_M; // Core starts in Machine Mode
      mstatus_mie  <= 1'b0;
      mstatus_sie  <= 1'b0;
      mstatus_mpie <= 1'b0;
      mstatus_spie <= 1'b0;
      mstatus_mpp  <= 2'b11; // M-mode
      mstatus_spp  <= 1'b0;
      mstatus_fs   <= 2'b01; // FP Initial
      mstatus_sum  <= 1'b0;
      mstatus_mxr  <= 1'b0;
      mstatus_tvm  <= 1'b0;
      mstatus_tw   <= 1'b0;
      mstatus_tsr  <= 1'b0;
      medeleg_q    <= '0;
      mideleg_q    <= '0;
      mie_meie     <= 1'b0;
      mie_seie     <= 1'b0;
      mie_mtie     <= 1'b0;
      mie_stie     <= 1'b0;
      mie_msie     <= 1'b0;
      mie_ssie     <= 1'b0;
      mip_seip     <= 1'b0;
      mip_stip     <= 1'b0;
      mip_ssip     <= 1'b0;
      mtvec_q      <= 64'h0000_1000;
      mepc_q       <= '0;
      mcause_q     <= '0;
      mtval_q      <= '0;
      stvec_q      <= 64'h0000_1000;
      sscratch_q   <= '0;
      sepc_q       <= '0;
      scause_q     <= '0;
      stval_q      <= '0;
      satp_q       <= '0;
      stimecmp_q   <= '0;
      for (int i = 0; i < PMP_ENTRIES; i++) begin
        pmpcfg_q[i]  <= 8'd0;
        pmpaddr_q[i] <= '0;
      end
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
        if (trap_to_smode) begin
          // Delegated Trap to Supervisor Mode
          sepc_q       <= trap_pc_i;
          scause_q     <= {is_interrupt_i, trap_cause_i};
          stval_q      <= trap_val_i;
          mstatus_spie <= mstatus_sie;
          mstatus_sie  <= 1'b0;
          mstatus_spp  <= priv_lvl_q[0];
          priv_lvl_q   <= PRV_S;
        end else begin
          // Standard Trap to Machine Mode
          mepc_q       <= trap_pc_i;
          mcause_q     <= {is_interrupt_i, trap_cause_i};
          mtval_q      <= trap_val_i;
          mstatus_mpie <= mstatus_mie;
          mstatus_mie  <= 1'b0;
          mstatus_mpp  <= priv_lvl_q;
          priv_lvl_q   <= PRV_M;
        end
      end else if (mret_i) begin
        // Return from Machine Mode
        mstatus_mie  <= mstatus_mpie;
        mstatus_mpie <= 1'b1;
        priv_lvl_q   <= priv_lvl_e'(mstatus_mpp);
        mstatus_mpp  <= PRV_U;
      end else if (sret_i) begin
        // Return from Supervisor Mode
        mstatus_sie  <= mstatus_spie;
        mstatus_spie <= 1'b1;
        priv_lvl_q   <= mstatus_spp ? PRV_S : PRV_U;
        mstatus_spp  <= 1'b0;
      end else if (csr_we_i) begin
        // Software CSR Write
        case (csr_addr_i)
          CSR_MSTATUS: begin
            mstatus_sie  <= next_csr_val[1];
            mstatus_mie  <= next_csr_val[3];
            mstatus_spie <= next_csr_val[5];
            mstatus_mpie <= next_csr_val[7];
            mstatus_spp  <= next_csr_val[8];
            mstatus_mpp  <= next_csr_val[12:11];
            mstatus_fs   <= next_csr_val[14:13];
            mstatus_sum  <= next_csr_val[18];
            mstatus_mxr  <= next_csr_val[19];
            mstatus_tvm  <= next_csr_val[20];
            mstatus_tw   <= next_csr_val[21];
            mstatus_tsr  <= next_csr_val[22];
          end
          CSR_MEDELEG: medeleg_q <= next_csr_val;
          CSR_MIDELEG: mideleg_q <= next_csr_val;
          CSR_MIE: begin
            mie_ssie <= next_csr_val[1];
            mie_msie <= next_csr_val[3];
            mie_stie <= next_csr_val[5];
            mie_mtie <= next_csr_val[7];
            mie_seie <= next_csr_val[9];
            mie_meie <= next_csr_val[11];
          end
          CSR_MIP: begin
            mip_ssip <= next_csr_val[1];
            mip_stip <= next_csr_val[5];
            mip_seip <= next_csr_val[9];
          end
          CSR_MTVEC:    mtvec_q    <= next_csr_val;
          CSR_MEPC:     mepc_q     <= next_csr_val;
          CSR_MCAUSE:   mcause_q   <= next_csr_val;
          CSR_MTVAL:    mtval_q    <= next_csr_val;

          // Supervisor Mode CSR writes
          CSR_SSTATUS: begin
            mstatus_sie  <= next_csr_val[1];
            mstatus_spie <= next_csr_val[5];
            mstatus_spp  <= next_csr_val[8];
            mstatus_fs   <= next_csr_val[14:13];
            mstatus_sum  <= next_csr_val[18];
            mstatus_mxr  <= next_csr_val[19];
          end
          CSR_SIE: begin
            if (mideleg_q[1]) mie_ssie <= next_csr_val[1];
            if (mideleg_q[5]) mie_stie <= next_csr_val[5];
            if (mideleg_q[9]) mie_seie <= next_csr_val[9];
          end
          CSR_SIP: begin
            if (mideleg_q[1]) mip_ssip <= next_csr_val[1];
          end
          CSR_STVEC:    stvec_q    <= next_csr_val;
          CSR_SSCRATCH: sscratch_q <= next_csr_val;
          CSR_SEPC:     sepc_q     <= next_csr_val;
          CSR_SCAUSE:   scause_q   <= next_csr_val;
          CSR_STVAL:    stval_q    <= next_csr_val;
          CSR_SATP:     satp_q     <= next_csr_val;
          CSR_STIMECMP: stimecmp_q <= next_csr_val;

          // PMP Configuration and Address writes (Entries 0..7 implemented)
          CSR_PMPCFG0: begin
            for (int i = 0; i < 8; i++) begin
              if (!pmpcfg_q[i][7]) pmpcfg_q[i] <= next_csr_val[i*8 +: 8];
            end
          end
          CSR_PMPCFG2: ; // Unimplemented entries 8..15 ignore writes
          CSR_PMPADDR0: if (!pmpcfg_q[0][7]) pmpaddr_q[0] <= next_csr_val;
          CSR_PMPADDR1: if (!pmpcfg_q[1][7]) pmpaddr_q[1] <= next_csr_val;
          CSR_PMPADDR2: if (!pmpcfg_q[2][7]) pmpaddr_q[2] <= next_csr_val;
          CSR_PMPADDR3: if (!pmpcfg_q[3][7]) pmpaddr_q[3] <= next_csr_val;
          CSR_PMPADDR4: if (!pmpcfg_q[4][7]) pmpaddr_q[4] <= next_csr_val;
          CSR_PMPADDR5: if (!pmpcfg_q[5][7]) pmpaddr_q[5] <= next_csr_val;
          CSR_PMPADDR6: if (!pmpcfg_q[6][7]) pmpaddr_q[6] <= next_csr_val;
          CSR_PMPADDR7: if (!pmpcfg_q[7][7]) pmpaddr_q[7] <= next_csr_val;
          CSR_PMPADDR8, CSR_PMPADDR9, CSR_PMPADDR10, CSR_PMPADDR11,
          CSR_PMPADDR12, CSR_PMPADDR13, CSR_PMPADDR14, CSR_PMPADDR15: ; // Ignore writes

          // FP CSRs
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
