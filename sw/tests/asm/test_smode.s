# ============================================================================
# File: sw/tests/asm/test_smode.s
# Description: Self-checking directed test suite for RISC-V RVA23 Privileged
#              Architecture & Supervisor Mode:
#              - S-mode CSR read/write (sstatus, stvec, sscratch, sepc, satp)
#              - Transition from M-mode to S-mode via mret (mstatus.MPP = 1)
#              - S-mode exception delegation via medeleg
#              - S-mode ecall trap vectoring to stvec and return via sret
#              - Verification of privilege level restoration
# ============================================================================

.section .text
.globl _start

_start:
    # -------------------------------------------------------------------------
    # 1. Verify M-mode CSRs & Delegation Register Setup
    # -------------------------------------------------------------------------
    # Write and read medeleg (delegate ECALL from S-mode: bit 9)
    li   t0, (1 << 9)           # Bit 9: CAUSE_ECALL_S_MODE
    csrw medeleg, t0
    csrr t1, medeleg
    bne  t0, t1, fail_medeleg

    # Write and read mideleg (delegate S-timer interrupt: bit 5)
    li   t0, (1 << 5)
    csrw mideleg, t0
    csrr t1, mideleg
    bne  t0, t1, fail_mideleg

    # -------------------------------------------------------------------------
    # 2. Setup Supervisor CSRs from M-mode
    # -------------------------------------------------------------------------
    # Set stvec to smode_trap_handler
    la   t0, smode_trap_handler
    csrw stvec, t0
    csrr t1, stvec
    bne  t0, t1, fail_stvec

    # Set sscratch
    li   t0, 0x123456789ABCDEF0
    csrw sscratch, t0
    csrr t1, sscratch
    bne  t0, t1, fail_sscratch

    # Set satp: Bare mode (MODE=0) with dummy PPN
    li   t0, 0x0000000000080000
    csrw satp, t0
    csrr t1, satp
    bne  t0, t1, fail_satp

    # Set sstatus bits: SUM (bit 18), MXR (bit 19)
    li   t0, (1 << 18) | (1 << 19)
    csrw sstatus, t0
    csrr t1, sstatus
    and  t2, t1, t0
    bne  t2, t0, fail_sstatus

    # -------------------------------------------------------------------------
    # 3. Transition from M-mode to S-mode via mret
    # -------------------------------------------------------------------------
    # Set mstatus.MPP = 2'b01 (S-mode, bits [12:11]): clear bit 12, set bit 11
    li   t0, (1 << 12)
    csrc mstatus, t0
    li   t0, (1 << 11) | (1 << 7)
    csrs mstatus, t0

    # Set mepc to smode_entry
    la   t1, smode_entry
    csrw mepc, t1

    # Execute MRET to drop privilege level from M-mode to S-mode!
    mret

    # If we didn't jump, fail
    j    fail_mret_drop

# -----------------------------------------------------------------------------
# Supervisor Mode Execution Environment (PRV_S)
# -----------------------------------------------------------------------------
smode_entry:
    # We are now in Supervisor Mode!
    # Verify sscratch is accessible and intact
    csrr a0, sscratch
    li   a1, 0x123456789ABCDEF0
    bne  a0, a1, fail_smode_scratch

    # Update sscratch in S-mode
    li   a2, 0xCAFEFEED00112233
    csrw sscratch, a2
    csrr a3, sscratch
    bne  a2, a3, fail_smode_scratch_rw

    # -------------------------------------------------------------------------
    # 4. Trigger Delegated ECALL Exception in S-mode
    # -------------------------------------------------------------------------
    # ECALL in S-mode triggers CAUSE_ECALL_S_MODE (9).
    # Since medeleg has bit 9 set, hardware should vector directly to stvec!
    ecall_instruction:
    ecall

    # After returning via sret:
    # Verify execution resumed at next instruction
    li   a4, 0x55AA
    bne  s1, a4, fail_trap_exec

    # -------------------------------------------------------------------------
    # All Supervisor Mode tests passed! Write CAFEBABE to 0x8000_1000
    # -------------------------------------------------------------------------
    lui  a2, 0x80001
    li   a3, 0xCAFEBABE
    sw   a3, 0(a2)

pass_loop:
    j    pass_loop

# -----------------------------------------------------------------------------
# Supervisor Mode Trap Handler (stvec)
# -----------------------------------------------------------------------------
.align 2
smode_trap_handler:
    # Verify scause is CAUSE_ECALL_S_MODE (9)
    csrr s2, scause
    li   s3, 9                  # CAUSE_ECALL_S_MODE
    bne  s2, s3, fail_scause

    # Verify sepc points to ecall_instruction
    csrr s4, sepc
    la   s5, ecall_instruction
    bne  s4, s5, fail_sepc

    # Advance sepc past ecall (+4)
    addi s4, s4, 4
    csrw sepc, s4

    # Record flag for main code
    li   s1, 0x55AA

    # Return from Supervisor trap back to smode_entry
    sret

# Failure Handlers
fail_medeleg:           li gp, 1;  j fail_loop
fail_mideleg:           li gp, 2;  j fail_loop
fail_stvec:             li gp, 3;  j fail_loop
fail_sscratch:          li gp, 4;  j fail_loop
fail_satp:              li gp, 5;  j fail_loop
fail_sstatus:           li gp, 6;  j fail_loop
fail_mret_drop:         li gp, 7;  j fail_loop
fail_smode_scratch:     li gp, 8;  j fail_loop
fail_smode_scratch_rw:  li gp, 9;  j fail_loop
fail_scause:            li gp, 10; j fail_loop
fail_sepc:              li gp, 11; j fail_loop
fail_trap_exec:         li gp, 12; j fail_loop

fail_loop:
    lui  a2, 0x80001
    lui  a4, 0xDEAD0
    or   a4, a4, gp
    sw   a4, 0(a2)
hang:
    j    hang
