# ============================================================================
# File: sw/tests/asm/privileged/test_pmp.s
# Description: Self-checking directed test suite for Physical Memory Protection
#              (PMP & Smepmp):
#              - Configuration of pmpcfg0 and pmpaddr registers
#              - Read-only locked PMP entry enforcement (L=1, R=1, W=0)
#              - Verification of CAUSE_STORE_ACCESS_FAULT trap generation
#              - Verification of mtval reporting offending fault physical address
# ============================================================================

.section .text
.globl _start

_start:
    # -------------------------------------------------------------------------
    # 1. Setup PMP Entries
    # Entry 0: Read-Only Protected Region at 0x7000_0000 (TOR: 0x7000_0000..0x7000_1000)
    # Entry 0 top: 0x7000_0000. Entry 1 top: 0x7000_1000.
    # Entry 1: L=1, R=1, W=0, X=0, A=TOR (0x09 | 0x80 = 0x89)
    # Entry 2: Allow all remaining memory (NAPOT all 1s: R=1, W=1, X=1, A=NAPOT = 0x1F)
    # -------------------------------------------------------------------------
    # pmpaddr0 = 0x7000_0000 >> 2 = 0x1C00_0000
    li   t0, (0x70000000 >> 2)
    csrw pmpaddr0, t0
    csrr t1, pmpaddr0
    bne  t0, t1, fail_pmpaddr

    # pmpaddr1 = 0x7000_1000 >> 2 = 0x1C00_0400
    li   t0, (0x70001000 >> 2)
    csrw pmpaddr1, t0

    # pmpaddr2 = 0xFFFFFFFFFFFFFFFF (all 1s for full space NAPOT)
    li   t0, -1
    csrw pmpaddr2, t0

    # Setup trap handler for expected PMP store fault
    la   t0, pmp_trap_handler
    csrw mtvec, t0

    # Configure pmpcfg0:
    # Entry 0: OFF (0x00)
    # Entry 1: TOR, R=1, W=0, X=0, L=1 (Locked Read-Only: 0x89)
    # Entry 2: NAPOT, R=1, W=1, X=1, L=0 (Allow all elsewhere: 0x1F)
    # pmpcfg0 = (0x1F << 16) | (0x89 << 8) | 0x00 = 0x001F8900
    li   t0, 0x001F8900
    csrw pmpcfg0, t0

    # -------------------------------------------------------------------------
    # 2. Test Read Allowed in Locked Region
    # -------------------------------------------------------------------------
    li   s0, 0x70000500
    ld   s1, 0(s0)              # Read should succeed without fault!

    # -------------------------------------------------------------------------
    # 3. Test Write Fault in Locked Region (L=1, W=0)
    # -------------------------------------------------------------------------
    store_fault_pc:
    .option push
    .option norvc
    sd   s1, 0(s0)              # Store MUST trigger CAUSE_STORE_ACCESS_FAULT (7)!
    .option pop

    # Verify trap handler set success flag
    li   t2, 0x55AA
    bne  s2, t2, fail_no_trap

    # -------------------------------------------------------------------------
    # All PMP tests passed! Write CAFEBABE to 0x8000_1000
    # -------------------------------------------------------------------------
    lui  a2, 0x80001
    li   a3, 0xCAFEBABE
    sw   a3, 0(a2)

pass_loop:
    j    pass_loop

# -----------------------------------------------------------------------------
# PMP Trap Handler
# -----------------------------------------------------------------------------
.align 2
pmp_trap_handler:
    # Verify mcause is CAUSE_STORE_ACCESS_FAULT (7)
    csrr t3, mcause
    li   t4, 7                  # CAUSE_STORE_ACCESS_FAULT
    bne  t3, t4, fail_mcause

    # Verify mtval is 0x7000_0500
    csrr t5, mtval
    li   t6, 0x70000500
    bne  t5, t6, fail_mtval

    # Advance mepc past sd (+4)
    csrr t3, mepc
    addi t3, t3, 4
    csrw mepc, t3

    # Set success flag in s2
    li   s2, 0x55AA

    # Return from trap
    mret

# Failure Handlers
fail_pmpaddr:   li gp, 1;  j fail_loop
fail_no_trap:   li gp, 2;  j fail_loop
fail_mcause:    li gp, 3;  j fail_loop
fail_mtval:     li gp, 4;  j fail_loop

fail_loop:
    lui  a2, 0x80001
    lui  a4, 0xDEAD0
    or   a4, a4, gp
    sw   a4, 0(a2)
hang:
    j    hang
