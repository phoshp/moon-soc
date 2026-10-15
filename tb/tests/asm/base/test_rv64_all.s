# ============================================================================
# File: tb/tests/asm/base/test_rv64_all.s
# Description: Self-checking directed test suite for RV64I, RV64M, and RV64A
# ============================================================================

.section .text
.globl _start

_start:
    # -------------------------------------------------------------------------
    # 1. RV64I Base Integer Arithmetic & Logic
    # -------------------------------------------------------------------------
    # ADDI & LUI
    lui  x1, 0x12345            # x1 = 0x12345000 (sign-extended)
    addi x2, x0, 42             # x2 = 42
    add  x3, x1, x2             # x3 = 0x1234502A
    sub  x4, x3, x2             # x4 should equal x1
    bne  x4, x1, fail_addi

    # 64-bit Shifts
    addi x5, x0, 1
    slli x6, x5, 40             # x6 = 1 << 40 (0x0000_0100_0000_0000)
    srli x7, x6, 40             # x7 should equal 1
    bne  x7, x5, fail_shift

    # 32-bit Word Operations (RV64I W-instructions)
    lui   x8, 0x7FFFF           # 0x7FFFF000
    addi  x8, x8, 0x7FF         # x8 = 0x7FFFF7FF
    addiw x9, x8, 1             # x9 = 0x7FFFF800 (sign extended)
    subw  x10, x9, x8           # x10 should be 1
    bne   x10, x5, fail_w_op

    # Comparisons (SLT / SLTU)
    addi x11, x0, -1            # x11 = 0xFFFF_FFFF_FFFF_FFFF (-1 signed, largest unsigned)
    addi x12, x0, 1             # x12 = 1
    slt  x13, x11, x12          # -1 < 1 signed => 1
    beq  x13, x0, fail_slt
    sltu x14, x11, x12          # 0xFF..FF < 1 unsigned => 0
    bne  x14, x0, fail_sltu

    # -------------------------------------------------------------------------
    # 2. Memory Loads and Stores (SB, LB, SW, LW, SD, LD)
    # -------------------------------------------------------------------------
    lui  x15, 0x80000           # Base address 0x8000_0000
    addi x16, x0, 0x5A          # Byte 0x5A
    sb   x16, 8(x15)
    lb   x17, 8(x15)
    bne  x17, x16, fail_mem_byte

    # 64-bit Doubleword store and load
    addi x18, x0, 1
    slli x18, x18, 50           # Large 64-bit number
    ori  x18, x18, 0x3C
    sd   x18, 16(x15)
    ld   x19, 16(x15)
    bne  x19, x18, fail_mem_dword

    # -------------------------------------------------------------------------
    # 3. RV64M Hardware Multiplier & Divider
    # -------------------------------------------------------------------------
    # MUL: 123 * 456 = 56088
    addi x20, x0, 123
    addi x21, x0, 456
    mul  x22, x20, x21
    li   x23, 56088
    bne  x22, x23, fail_mul

    # MULW (32-bit word multiply)
    mulw x24, x20, x21
    bne  x24, x23, fail_mulw

    # DIV: 56088 / 123 = 456
    div  x25, x23, x20
    bne  x25, x21, fail_div

    # REM: 56093 % 123 = 5
    addi x26, x23, 5
    rem  x27, x26, x20
    addi x28, x0, 5
    bne  x27, x28, fail_rem

    # -------------------------------------------------------------------------
    # 4. RV64A Atomic Operations (LR/SC and AMO)
    # -------------------------------------------------------------------------
    # Test LR.D and SC.D
    addi x29, x15, 32           # Target address 0x8000_0020
    sd   x0, 0(x29)             # Clear memory
    lr.d x30, (x29)             # Reserve
    addi x31, x0, 99
    sc.d x4, x31, (x29)         # SC: should return 0 (success) in x4
    bne  x4, x0, fail_sc
    ld   x7, 0(x29)             # Verify memory contains 99
    bne  x7, x31, fail_sc_val

    # AMOADD.D: Atomically add 101 to memory (99 + 101 = 200)
    addi x6, x0, 101
    amoadd.d x8, x6, (x29)      # Returns old value (99) in x8
    bne  x8, x31, fail_amo_old
    ld   x9, 0(x29)             # Memory should now contain 200
    addi x10, x0, 200
    bne  x9, x10, fail_amo_new

    # -------------------------------------------------------------------------
    # 5. Machine Mode CSR Unit Test (mstatus)
    # -------------------------------------------------------------------------
    # Test writing and reading mstatus (MIE bit 3)
    csrwi mstatus, 8            # Set MIE (bit 3) via CSRRWI
    csrr  x12, mstatus
    andi  x13, x12, 8           # Check bit 3 is set
    beqz  x13, fail_csr
    fence                       # Test MISC_MEM decode

    # -------------------------------------------------------------------------
    # All tests passed! Write CAFE_BABE to test status address 0x8000_1000
    # -------------------------------------------------------------------------
    lui  x1, 0x80001
    li   x2, 0xCAFEBABE
    sw   x2, 0(x1)
pass_loop:
    j pass_loop

# -----------------------------------------------------------------------------
# Failure Handlers
# -----------------------------------------------------------------------------
fail_addi:
    addi x3, x0, 1
    j signal_fail
fail_shift:
    addi x3, x0, 2
    j signal_fail
fail_w_op:
    addi x3, x0, 3
    j signal_fail
fail_slt:
    addi x3, x0, 4
    j signal_fail
fail_sltu:
    addi x3, x0, 5
    j signal_fail
fail_mem_byte:
    addi x3, x0, 6
    j signal_fail
fail_mem_dword:
    addi x3, x0, 7
    j signal_fail
fail_mul:
    addi x3, x0, 8
    j signal_fail
fail_mulw:
    addi x3, x0, 9
    j signal_fail
fail_div:
    addi x3, x0, 10
    j signal_fail
fail_rem:
    addi x3, x0, 11
    j signal_fail
fail_sc:
    addi x3, x0, 12
    j signal_fail
fail_sc_val:
    addi x3, x0, 13
    j signal_fail
fail_amo_old:
    addi x3, x0, 14
    j signal_fail
fail_amo_new:
    addi x3, x0, 15
    j signal_fail
fail_csr:
    addi x3, x0, 16
    j signal_fail

signal_fail:
    lui  x1, 0x80001
    lui  x2, 0xDEAD0
    or   x2, x2, x3
    sw   x2, 0(x1)
fail_loop:
    j fail_loop
