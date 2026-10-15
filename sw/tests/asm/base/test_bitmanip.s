# ============================================================================
# File: sw/tests/asm/base/test_bitmanip.s
# Description: Self-checking directed test suite for RISC-V RVA23 Bitmanipulation
#              extensions: Zba (Address Generation), Zbb (Basic Bitmanip),
#              and Zbs (Single-Bit Operations).
# ============================================================================

.section .text
.globl _start

_start:
    # -------------------------------------------------------------------------
    # 1. Zba Extension Tests
    # -------------------------------------------------------------------------
    li   t0, 0x10
    li   t1, 0x05

    # sh1add: (0x10 << 1) + 0x05 = 0x25
    sh1add a0, t0, t1
    li   a1, 0x25
    bne  a0, a1, fail_sh1add

    # sh2add: (0x10 << 2) + 0x05 = 0x45
    sh2add a0, t0, t1
    li   a1, 0x45
    bne  a0, a1, fail_sh2add

    # sh3add: (0x10 << 3) + 0x05 = 0x85
    sh3add a0, t0, t1
    li   a1, 0x85
    bne  a0, a1, fail_sh3add

    # Test .uw word variants with upper 32 bits set
    li   t2, 0xFFFFFFFF00000010

    # sh1add.uw: (0x10 << 1) + 0x05 = 0x25
    sh1add.uw a0, t2, t1
    li   a1, 0x25
    bne  a0, a1, fail_sh1add_uw

    # sh2add.uw: (0x10 << 2) + 0x05 = 0x45
    sh2add.uw a0, t2, t1
    li   a1, 0x45
    bne  a0, a1, fail_sh2add_uw

    # sh3add.uw: (0x10 << 3) + 0x05 = 0x85
    sh3add.uw a0, t2, t1
    li   a1, 0x85
    bne  a0, a1, fail_sh3add_uw

    # add.uw: zero_extend(0x80000000) + 0x100 = 0x80000100
    li   t3, 0xFFFFFFFF80000000
    li   t4, 0x100
    add.uw a0, t3, t4
    li   a1, 0x80000100
    bne  a0, a1, fail_add_uw

    # slli.uw: zero_extend(0x1234) << 16 = 0x12340000
    li   t5, 0xFFFFFFFF00001234
    slli.uw a0, t5, 16
    li   a1, 0x12340000
    bne  a0, a1, fail_slli_uw

    # -------------------------------------------------------------------------
    # 2. Zbb Extension Tests: Counting & Extensions
    # -------------------------------------------------------------------------
    # clz: count leading zeros
    li   t0, 1
    clz  a0, t0
    li   a1, 63
    bne  a0, a1, fail_clz

    li   t0, 0x8000000000000000
    clz  a0, t0
    li   a1, 0
    bne  a0, a1, fail_clz_zero

    li   t0, 0
    clz  a0, t0
    li   a1, 64
    bne  a0, a1, fail_clz_all

    # ctz: count trailing zeros
    li   t0, 0x8000000000000000
    ctz  a0, t0
    li   a1, 63
    bne  a0, a1, fail_ctz

    li   t0, 1
    ctz  a0, t0
    li   a1, 0
    bne  a0, a1, fail_ctz_zero

    # cpop: population count
    li   t0, 0xF0F0F0F00F0F0F0F
    cpop a0, t0
    li   a1, 32
    bne  a0, a1, fail_cpop

    # 32-bit counting: clzw, ctzw, cpopw
    li   t0, 0xFFFFFFFF00000001
    clzw a0, t0
    li   a1, 31
    bne  a0, a1, fail_clzw

    ctzw a0, t0
    li   a1, 0
    bne  a0, a1, fail_ctzw

    li   t0, 0xFFFFFFFF000000FF
    cpopw a0, t0
    li   a1, 8
    bne  a0, a1, fail_cpopw

    # Min / Max
    li   t0, -10
    li   t1, 5
    min  a0, t0, t1
    bne  a0, t0, fail_min
    max  a0, t0, t1
    bne  a0, t1, fail_max

    minu a0, t0, t1
    bne  a0, t1, fail_minu
    maxu a0, t0, t1
    bne  a0, t0, fail_maxu

    # Sign / Zero extensions
    li   t0, 0x123485
    sext.b a0, t0
    li   a1, -123
    bne  a0, a1, fail_sext_b

    li   t0, 0x12348005
    sext.h a0, t0
    li   t1, 0xFFFFFFFFFFFF8005
    bne  a0, t1, fail_sext_h

    zext.h a0, t0
    li   t1, 0x8005
    bne  a0, t1, fail_zext_h

    # Rotate operations: rol, ror, rori
    li   t0, 0x123456789ABCDEF0
    li   t1, 4
    rol  a0, t0, t1
    li   t2, 0x23456789ABCDEF01
    bne  a0, t2, fail_rol

    ror  a0, t0, t1
    li   t3, 0x0123456789ABCDEF
    bne  a0, t3, fail_ror

    rori a0, t0, 4
    bne  a0, t3, fail_rori

    # 32-bit rotate: rolw, rorw, roriw
    li   t0, 0x12345678
    rolw a0, t0, t1
    li   t2, 0x23456781
    bne  a0, t2, fail_rolw

    rorw a0, t0, t1
    li   t3, 0xFFFFFFFF81234567
    bne  a0, t3, fail_rorw

    roriw a0, t0, 4
    bne  a0, t3, fail_roriw

    # rev8 (byte reverse)
    li   t0, 0x0123456789ABCDEF
    rev8 a0, t0
    li   t1, 0xEFCDAB8967452301
    bne  a0, t1, fail_rev8

    # orc.b (byte OR combine)
    li   t0, 0x0012003400560078
    orc.b a0, t0
    li   t1, 0x00FF00FF00FF00FF
    bne  a0, t1, fail_orc_b

    # Logic with negate: andn, orn, xnor
    li   t0, 0x0F
    li   t1, 0x03
    andn a0, t0, t1
    li   a1, 0x0C
    bne  a0, a1, fail_andn

    orn  a0, zero, t1
    li   a1, -4
    bne  a0, a1, fail_orn

    xnor a0, t0, t1
    li   a1, -13
    bne  a0, a1, fail_xnor

    # -------------------------------------------------------------------------
    # 3. Zbs Extension Tests: Single-Bit Operations
    # -------------------------------------------------------------------------
    # bset / bseti
    li   t0, 0
    li   t1, 10
    bset a0, t0, t1
    li   a1, 0x400
    bne  a0, a1, fail_bset

    bseti a0, t0, 10
    bne  a0, a1, fail_bseti

    # bclr / bclri
    li   t0, 0x400
    bclr a0, t0, t1
    bne  a0, zero, fail_bclr

    bclri a0, t0, 10
    bne  a0, zero, fail_bclri

    # binv / binvi
    li   t0, 0
    binv a0, t0, t1
    bne  a0, a1, fail_binv
    binv a0, a0, t1
    bne  a0, zero, fail_binv

    binvi a0, t0, 10
    bne  a0, a1, fail_binvi
    binvi a0, a0, 10
    bne  a0, zero, fail_binvi

    # bext / bexti
    li   t0, 0x400
    bext a0, t0, t1
    li   a1, 1
    bne  a0, a1, fail_bext

    li   t1, 9
    bext a0, t0, t1
    bne  a0, zero, fail_bext_zero

    bexti a0, t0, 10
    bne  a0, a1, fail_bexti

    bexti a0, t0, 9
    bne  a0, zero, fail_bexti_zero

    # -------------------------------------------------------------------------
    # All Bitmanipulation tests passed! Write CAFEBABE to 0x8000_1000
    # -------------------------------------------------------------------------
    lui  a2, 0x80001
    li   a3, 0xCAFEBABE
    sw   a3, 0(a2)

pass_loop:
    j    pass_loop

# Failure Handlers
fail_sh1add:     li gp, 1;  j fail_loop
fail_sh2add:     li gp, 2;  j fail_loop
fail_sh3add:     li gp, 3;  j fail_loop
fail_sh1add_uw:  li gp, 4;  j fail_loop
fail_sh2add_uw:  li gp, 5;  j fail_loop
fail_sh3add_uw:  li gp, 6;  j fail_loop
fail_add_uw:     li gp, 7;  j fail_loop
fail_slli_uw:    li gp, 8;  j fail_loop
fail_clz:        li gp, 9;  j fail_loop
fail_clz_zero:   li gp, 10; j fail_loop
fail_clz_all:    li gp, 11; j fail_loop
fail_ctz:        li gp, 12; j fail_loop
fail_ctz_zero:   li gp, 13; j fail_loop
fail_cpop:       li gp, 14; j fail_loop
fail_clzw:       li gp, 15; j fail_loop
fail_ctzw:       li gp, 16; j fail_loop
fail_cpopw:      li gp, 17; j fail_loop
fail_min:        li gp, 18; j fail_loop
fail_max:        li gp, 19; j fail_loop
fail_minu:       li gp, 20; j fail_loop
fail_maxu:       li gp, 21; j fail_loop
fail_sext_b:     li gp, 22; j fail_loop
fail_sext_h:     li gp, 23; j fail_loop
fail_zext_h:     li gp, 24; j fail_loop
fail_rol:        li gp, 25; j fail_loop
fail_ror:        li gp, 26; j fail_loop
fail_rori:       li gp, 27; j fail_loop
fail_rolw:       li gp, 28; j fail_loop
fail_rorw:       li gp, 29; j fail_loop
fail_roriw:      li gp, 30; j fail_loop
fail_rev8:       li gp, 31; j fail_loop
fail_orc_b:      li gp, 32; j fail_loop
fail_andn:       li gp, 33; j fail_loop
fail_orn:        li gp, 34; j fail_loop
fail_xnor:       li gp, 35; j fail_loop
fail_bset:       li gp, 36; j fail_loop
fail_bseti:      li gp, 37; j fail_loop
fail_bclr:       li gp, 38; j fail_loop
fail_bclri:      li gp, 39; j fail_loop
fail_binv:       li gp, 40; j fail_loop
fail_binvi:      li gp, 41; j fail_loop
fail_bext:       li gp, 42; j fail_loop
fail_bext_zero:  li gp, 43; j fail_loop
fail_bexti:      li gp, 44; j fail_loop
fail_bexti_zero: li gp, 45; j fail_loop

fail_loop:
    lui  a2, 0x80001
    lui  a4, 0xDEAD0
    or   a4, a4, gp
    sw   a4, 0(a2)
hang:
    j    hang
