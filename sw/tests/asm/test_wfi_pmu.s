# ============================================================================
# File: sw/tests/asm/test_wfi_pmu.s
# Description: Self-checking test verifying WFI (Wait-For-Interrupt) execution,
#              PMU sleep transition, clock gating, and timer interrupt wake-up.
# ============================================================================

.section .text
.globl _start

_start:
    # -------------------------------------------------------------------------
    # 1. Setup Trap Handler Vector (mtvec)
    # -------------------------------------------------------------------------
    la   t0, trap_handler
    csrw mtvec, t0

    # Initialize interrupt serviced flag in x15
    li   x15, 0

    # -------------------------------------------------------------------------
    # 2. Configure CLINT Timer for future interrupt (mtimecmp = mtime + 50)
    # -------------------------------------------------------------------------
    li   t1, 0x0200BFF8         # CLINT mtime lower 32b
    lw   t2, 0(t1)
    addi t2, t2, 50             # Target compare in 50 cycles

    li   t3, 0x02004000         # CLINT mtimecmp lower 32b
    sw   t2, 0(t3)
    li   t4, 0x02004004         # CLINT mtimecmp upper 32b
    sw   zero, 0(t4)

    # -------------------------------------------------------------------------
    # 3. Enable Timer Interrupt (mie.MTIE = bit 7) & Global Interrupt (mstatus.MIE = bit 3)
    # -------------------------------------------------------------------------
    li   t5, 0x80               # MTIE (Machine Timer Interrupt Enable)
    csrs mie, t5

    csrsi mstatus, 0x8          # MIE (Machine Interrupt Enable) via CSRSI

    # -------------------------------------------------------------------------
    # 4. Execute WFI: CPU should sleep and PMU gate clock until timer interrupt
    # -------------------------------------------------------------------------
    wfi

    # -------------------------------------------------------------------------
    # 5. After wake-up and mret return: Verify interrupt was properly handled
    # -------------------------------------------------------------------------
    li   t0, 1
    bne  x15, t0, fail_wfi

    # Test Passed! Write CAFE_BABE to 0x8000_1000
    lui  a2, 0x80001
    li   a3, 0xCAFEBABE
    sw   a3, 0(a2)

pass_loop:
    j    pass_loop

fail_wfi:
    li   gp, 1
    lui  a2, 0x80001
    lui  a4, 0xDEAD0
    or   a4, a4, gp
    sw   a4, 0(a2)
hang:
    j    hang

# -----------------------------------------------------------------------------
# Trap Handler for Timer Interrupt
# -----------------------------------------------------------------------------
.align 4
trap_handler:
    # Disable timer interrupt by setting mtimecmp to max value
    li   t3, 0x02004000
    li   t4, -1
    sw   t4, 0(t3)
    li   t3, 0x02004004
    sw   t4, 0(t3)

    # Set handled flag in x15
    addi x15, x15, 1

    # Return to instruction following WFI
    mret
