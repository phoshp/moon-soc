# ============================================================================
# File: tb/tests/asm/base/test_compressed.s
# Description: Self-checking directed test suite for RISC-V RVA23 Compressed
#              extensions: Zca (Standard 16-bit) and Zcb (Byte/Halfword & Bitops).
#              Verifies decompression, execution, and unaligned fetch buffering.
# ============================================================================

.section .text
.globl _start

_start:
    # -------------------------------------------------------------------------
    # 1. Zca: Immediate & Register Arithmetic
    # -------------------------------------------------------------------------
    c.nop

    # c.li: a0 = 25
    c.li   a0, 25
    li     a1, 25
    bne    a0, a1, fail_li

    # c.lui: a0 = 0x5000
    c.lui  a0, 5
    li     a1, 0x5000
    bne    a0, a1, fail_lui

    # c.addi: a0 = 25 + (-10) = 15
    c.li   a0, 25
    c.addi a0, -10
    li     a1, 15
    bne    a0, a1, fail_addi

    # c.addiw: a0 = -1 (word)
    c.li    a0, 0
    c.addiw a0, -1
    li      a1, -1
    bne     a0, a1, fail_addiw

    # c.mv: a1 = a0
    c.li   a0, 20
    c.mv   a1, a0
    li     a2, 20
    bne    a1, a2, fail_mv

    # c.add: a0 = a0 + a1 = 20 + 20 = 40
    c.add  a0, a1
    li     a2, 40
    bne    a0, a2, fail_add

    # c.sub: a0 = a0 - a1 = 40 - 20 = 20
    c.sub  a0, a1
    li     a2, 20
    bne    a0, a2, fail_sub

    # c.and, c.or, c.xor
    c.li   a0, 0x0F
    c.li   a1, 0x03
    c.and  a0, a1           # 0x0F & 0x03 = 0x03
    li     a2, 0x03
    bne    a0, a2, fail_and

    c.li   a0, 0x0C
    c.or   a0, a1           # 0x0C | 0x03 = 0x0F
    li     a2, 0x0F
    bne    a0, a2, fail_or

    c.xor  a0, a1           # 0x0F ^ 0x03 = 0x0C
    li     a2, 0x0C
    bne    a0, a2, fail_xor

    # c.andi: a0 = 0x0C & 4 = 4
    c.andi a0, 4
    li     a2, 4
    bne    a0, a2, fail_andi

    # Shifts: c.slli, c.srli, c.srai
    c.li   a0, 1
    c.slli a0, 5            # 1 << 5 = 32
    li     a1, 32
    bne    a0, a1, fail_slli

    c.srli a0, 2            # 32 >> 2 = 8
    li     a1, 8
    bne    a0, a1, fail_srli

    c.li   a0, -16
    c.srai a0, 2            # -16 >>> 2 = -4
    li     a1, -4
    bne    a0, a1, fail_srai

    # 32-bit Word Ops: c.addw, c.subw
    c.li   a0, 25
    c.li   a1, 10
    c.addw a0, a1           # 35
    li     a2, 35
    bne    a0, a2, fail_addw

    c.subw a0, a1           # 25
    li     a2, 25
    bne    a0, a2, fail_subw

    # -------------------------------------------------------------------------
    # 2. Zca: Memory Loads & Stores
    # -------------------------------------------------------------------------
    li   s0, 0x80000200
    li   s1, 0x12345678
    li   a1, 0x0123456789ABCDEF

    # c.sw / c.lw (word)
    c.sw s1, 4(s0)
    c.lw a0, 4(s0)
    bne  a0, s1, fail_sw_lw

    # c.sd / c.ld (dword)
    c.sd a1, 8(s0)
    c.ld a0, 8(s0)
    bne  a0, a1, fail_sd_ld

    # SP-relative: c.swsp, c.lwsp, c.sdsp, c.ldsp
    # Temporarily adjust sp
    li   sp, 0x80000300
    c.swsp s1, 4(sp)
    c.lwsp a0, 4(sp)
    bne  a0, s1, fail_swsp_lwsp

    c.sdsp a1, 8(sp)
    c.ldsp a0, 8(sp)
    bne  a0, a1, fail_sdsp_ldsp

    # -------------------------------------------------------------------------
    # 3. Zcb: Byte & Halfword Memory, Extensions, Multiply
    # -------------------------------------------------------------------------
    li   a1, 0x5A
    li   a2, 0x1234
    c.sb a1, 0(s0)
    c.lbu a0, 0(s0)
    bne  a0, a1, fail_zcb_byte

    c.sh a2, 2(s0)
    c.lhu a0, 2(s0)
    bne  a0, a2, fail_zcb_half

    # c.zext.b, c.sext.b
    li   a0, 0x123485
    c.zext.b a0
    li   a1, 0x85
    bne  a0, a1, fail_zcb_zext_b

    li   a0, 0x123485
    c.sext.b a0
    li   a1, -123
    bne  a0, a1, fail_zcb_sext_b

    # c.zext.h, c.sext.h
    li   a0, 0x12348005
    c.zext.h a0
    li   a1, 0x8005
    bne  a0, a1, fail_zcb_zext_h

    li   a0, 0x12348005
    c.sext.h a0
    li   t0, 0xFFFFFFFFFFFF8005
    bne  a0, t0, fail_zcb_sext_h

    # c.zext.w, c.not
    li   a0, 0xFFFFFFFF80000000
    c.zext.w a0
    li   t0, 0x0000000080000000
    bne  a0, t0, fail_zcb_zext_w

    li   a0, 0x0F
    c.not a0
    li   t0, -16
    bne  a0, t0, fail_zcb_not

    # c.mul: a0 * a1 = 7 * 6 = 42
    c.li a0, 7
    c.li a1, 6
    c.mul a0, a1
    li   a2, 42
    bne  a0, a2, fail_zcb_mul

    # -------------------------------------------------------------------------
    # 4. Control Flow & Unaligned Cross-Boundary Execution
    # -------------------------------------------------------------------------
    # c.beqz / c.bnez
    c.li   a0, 0
    c.beqz a0, target_beqz
    j fail_beqz
target_beqz:
    c.li   a0, 1
    c.bnez a0, target_bnez
    j fail_bnez
target_bnez:

    # c.j (jump)
    c.j    target_j
    j fail_j
target_j:

    # c.jalr / c.jr
    la     t0, target_jr
    c.jr   t0
    j fail_jr
target_jr:

    la     t0, target_jalr
    c.jalr t0
return_from_jalr:
    # Verify return link was written to ra (x1)
    la     t1, return_from_jalr
    bne    ra, t1, fail_jalr_link

    # -------------------------------------------------------------------------
    # All Compressed (Zca, Zcb) tests passed! Write CAFEBABE to 0x8000_1000
    # -------------------------------------------------------------------------
    lui  a2, 0x80001
    li   a3, 0xCAFEBABE
    sw   a3, 0(a2)

pass_loop:
    j    pass_loop

target_jalr:
    c.jr ra

# Failure Handlers
fail_li:        li gp, 1;  j fail_loop
fail_lui:       li gp, 2;  j fail_loop
fail_addi:      li gp, 3;  j fail_loop
fail_addiw:     li gp, 4;  j fail_loop
fail_mv:        li gp, 5;  j fail_loop
fail_add:       li gp, 6;  j fail_loop
fail_sub:       li gp, 7;  j fail_loop
fail_and:       li gp, 8;  j fail_loop
fail_or:        li gp, 9;  j fail_loop
fail_xor:       li gp, 10; j fail_loop
fail_andi:      li gp, 11; j fail_loop
fail_slli:      li gp, 12; j fail_loop
fail_srli:      li gp, 13; j fail_loop
fail_srai:      li gp, 14; j fail_loop
fail_addw:      li gp, 15; j fail_loop
fail_subw:      li gp, 16; j fail_loop
fail_sw_lw:     li gp, 17; j fail_loop
fail_sd_ld:     li gp, 18; j fail_loop
fail_swsp_lwsp: li gp, 19; j fail_loop
fail_sdsp_ldsp: li gp, 20; j fail_loop
fail_zcb_byte:  li gp, 21; j fail_loop
fail_zcb_half:  li gp, 22; j fail_loop
fail_zcb_zext_b:li gp, 23; j fail_loop
fail_zcb_sext_b:li gp, 24; j fail_loop
fail_zcb_zext_h:li gp, 25; j fail_loop
fail_zcb_sext_h:li gp, 26; j fail_loop
fail_zcb_zext_w:li gp, 27; j fail_loop
fail_zcb_not:   li gp, 28; j fail_loop
fail_zcb_mul:   li gp, 29; j fail_loop
fail_beqz:      li gp, 30; j fail_loop
fail_bnez:      li gp, 31; j fail_loop
fail_j:         li gp, 32; j fail_loop
fail_jr:        li gp, 33; j fail_loop
fail_jalr_link: li gp, 34; j fail_loop

fail_loop:
    lui  a2, 0x80001
    lui  a4, 0xDEAD0
    or   a4, a4, gp
    sw   a4, 0(a2)
hang:
    j    hang
