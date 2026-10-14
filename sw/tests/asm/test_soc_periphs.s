# ============================================================================
# File: sw/tests/asm/test_soc_periphs.s
# Description: Self-checking test verifying Moon-SoC Top-Level Peripherals:
#              - UART 16550 Console Output (0x1000_0000)
#              - On-Chip SRAM read/write (0x7000_0000)
#              - CLINT mtime counter read (0x0200_BFF8)
#              - PLIC priority register write/read (0x0C00_0004)
#              - Signals completion via 0x8000_1000 = 0xCAFEBABE
# ============================================================================

.section .text
.globl _start

_start:
    # -------------------------------------------------------------------------
    # 1. Test UART 16550 Output (0x1000_0000)
    # -------------------------------------------------------------------------
    li   t0, 0x10000000         # UART Base
    li   t1, 0x4D               # 'M'
    sb   t1, 0(t0)
    li   t1, 0x4F               # 'O'
    sb   t1, 0(t0)
    li   t1, 0x4F               # 'O'
    sb   t1, 0(t0)
    li   t1, 0x4E               # 'N'
    sb   t1, 0(t0)
    li   t1, 0x2D               # '-'
    sb   t1, 0(t0)
    li   t1, 0x53               # 'S'
    sb   t1, 0(t0)
    li   t1, 0x4F               # 'O'
    sb   t1, 0(t0)
    li   t1, 0x43               # 'C'
    sb   t1, 0(t0)
    li   t1, 0x0A               # '\n'
    sb   t1, 0(t0)

    # -------------------------------------------------------------------------
    # 2. Test On-Chip 128 KB SRAM (0x7000_0000)
    # -------------------------------------------------------------------------
    li   s0, 0x70000000         # SRAM Base
    li   s1, 0x123456789ABCDEF0 # 64-bit test pattern
    sd   s1, 0(s0)
    ld   s2, 0(s0)
    bne  s2, s1, fail_sram

    # Test SRAM byte writes
    li   s3, 0xA5
    sb   s3, 8(s0)
    lbu  s4, 8(s0)
    bne  s4, s3, fail_sram_byte

    # -------------------------------------------------------------------------
    # 3. Test CLINT mtime Counter (0x0200_BFF8)
    # -------------------------------------------------------------------------
    li   t2, 0x0200BFF8         # CLINT mtime lower 32b
    lw   t3, 0(t2)
    # Busy delay to allow mtime to increment
    addi t4, zero, 100
delay_loop:
    addi t4, t4, -1
    bnez t4, delay_loop

    lw   t5, 0(t2)
    bleu t5, t3, fail_clint     # mtime must be strictly greater

    # -------------------------------------------------------------------------
    # 4. Test PLIC Source 1 Priority Register (0x0C00_0004)
    # -------------------------------------------------------------------------
    li   t6, 0x0C000004         # PLIC Priority 1
    li   a0, 5                  # Priority 5
    sw   a0, 0(t6)
    lw   a1, 0(t6)
    bne  a1, a0, fail_plic

    # -------------------------------------------------------------------------
    # 5. Test Clock & Reset Generator (CRG at 0x1000_5000)
    # -------------------------------------------------------------------------
    li   t6, 0x10005000         # CRG Base
    lw   a0, 4(t6)              # CRG_PLL_STATUS (offset 0x04)
    andi a1, a0, 1              # Check PLL locked bit
    beqz a1, fail_crg_lock

    li   a2, 7                  # CRG_CLK_GATE (offset 0x08)
    sw   a2, 8(t6)
    lw   a3, 8(t6)
    andi a3, a3, 7
    bne  a3, a2, fail_crg_gate

    # -------------------------------------------------------------------------
    # 6. Test Power Management Unit (PMU at 0x1000_5080)
    # -------------------------------------------------------------------------
    li   t6, 0x10005080         # PMU Base
    lw   a0, 4(t6)              # PMU_STATUS (offset 0x04)
    andi a1, a0, 3              # Check state is STATE_RUN (0)
    bnez a1, fail_pmu_status

    li   a2, 0x0A               # PMU_CTRL (offset 0x00): target=2, wake_en=1
    sw   a2, 0(t6)
    lw   a3, 0(t6)
    andi a3, a3, 0x0B
    bne  a3, a2, fail_pmu_ctrl

    # -------------------------------------------------------------------------
    # All peripheral, CRG, and PMU tests passed! Write CAFE_BABE to 0x8000_1000
    # -------------------------------------------------------------------------
    lui  a2, 0x80001
    li   a3, 0xCAFEBABE
    sw   a3, 0(a2)

pass_loop:
    j    pass_loop

fail_sram:
    li   gp, 1
    j    fail_loop
fail_sram_byte:
    li   gp, 2
    j    fail_loop
fail_clint:
    li   gp, 3
    j    fail_loop
fail_plic:
    li   gp, 4
    j    fail_loop
fail_crg_lock:
    li   gp, 5
    j    fail_loop
fail_crg_gate:
    li   gp, 6
    j    fail_loop
fail_pmu_status:
    li   gp, 7
    j    fail_loop
fail_pmu_ctrl:
    li   gp, 8
    j    fail_loop

fail_loop:
    lui  a2, 0x80001
    lui  a4, 0xDEAD0
    or   a4, a4, gp
    sw   a4, 0(a2)
hang:
    j    hang
