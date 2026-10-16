.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000200
    li   a1, 0x80000400

    # =========================================================================
    # Test 1: vzext.vf2 & vsext.vf2 (e8 -> e16)
    # vs2 (v4): 0x12, 0xff (-1), 0x80 (-128), 0x7f (127)
    # vzext expected: 0x0012, 0x00ff, 0x0080, 0x007f
    # vsext expected: 0x0012, 0xffff, 0xff80, 0x007f
    # =========================================================================
    li   t0, 0x7f80ff12
    sw   t0, 0(a0)

    # Load into v4 with e8
    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)

    # vzext.vf2 with dest sew=e16
    vsetivli t0, 4, e16, m1, ta, ma
    vzext.vf2 v2, v4
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x0012
    bne  t0, t2, fail_vzext_vf2_e16
    lhu  t0, 2(a1)
    li   t2, 0x00ff
    bne  t0, t2, fail_vzext_vf2_e16
    lhu  t0, 4(a1)
    li   t2, 0x0080
    bne  t0, t2, fail_vzext_vf2_e16
    lhu  t0, 6(a1)
    li   t2, 0x007f
    bne  t0, t2, fail_vzext_vf2_e16

    # vsext.vf2 with dest sew=e16
    vsext.vf2 v2, v4
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x0012
    bne  t0, t2, fail_vsext_vf2_e16
    lhu  t0, 2(a1)
    li   t2, 0xffff
    bne  t0, t2, fail_vsext_vf2_e16
    lhu  t0, 4(a1)
    li   t2, 0xff80
    bne  t0, t2, fail_vsext_vf2_e16
    lhu  t0, 6(a1)
    li   t2, 0x007f
    bne  t0, t2, fail_vsext_vf2_e16

    # =========================================================================
    # Test 2: vzext.vf2 & vsext.vf2 (e16 -> e32)
    # vs2 (v4): 0x1234, 0xffff (-1), 0x8000 (-32768), 0x7fff (32767)
    # vzext expected: 0x00001234, 0x0000ffff, 0x00008000, 0x00007fff
    # vsext expected: 0x00001234, 0xffffffff, 0xffff8000, 0x00007fff
    # =========================================================================
    li   t0, 0xffff1234
    sw   t0, 0(a0)
    li   t0, 0x7fff8000
    sw   t0, 4(a0)

    vsetivli t0, 4, e16, m1, ta, ma
    vle16.v  v4, (a0)

    vsetivli t0, 4, e32, m1, ta, ma
    vzext.vf2 v2, v4
    vse32.v  v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x00001234
    bne  t0, t2, fail_vzext_vf2_e32
    lwu  t0, 4(a1)
    li   t2, 0x0000ffff
    bne  t0, t2, fail_vzext_vf2_e32
    lwu  t0, 8(a1)
    li   t2, 0x00008000
    bne  t0, t2, fail_vzext_vf2_e32
    lwu  t0, 12(a1)
    li   t2, 0x00007fff
    bne  t0, t2, fail_vzext_vf2_e32

    vsext.vf2 v2, v4
    vse32.v  v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x00001234
    bne  t0, t2, fail_vsext_vf2_e32
    lwu  t0, 4(a1)
    li   t2, 0xffffffff
    bne  t0, t2, fail_vsext_vf2_e32
    lwu  t0, 8(a1)
    li   t2, 0xffff8000
    bne  t0, t2, fail_vsext_vf2_e32
    lwu  t0, 12(a1)
    li   t2, 0x00007fff
    bne  t0, t2, fail_vsext_vf2_e32

    # =========================================================================
    # Test 3: vzext.vf2 & vsext.vf2 (e32 -> e64)
    # vs2 (v4): 0x12345678, 0xffffffff (-1)
    # vzext expected: 0x0000000012345678, 0x00000000ffffffff
    # vsext expected: 0x0000000012345678, 0xffffffffffffffff
    # =========================================================================
    li   t0, 0x12345678
    sw   t0, 0(a0)
    li   t0, 0xffffffff
    sw   t0, 4(a0)

    vsetivli t0, 2, e32, m1, ta, ma
    vle32.v  v4, (a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vzext.vf2 v2, v4
    vse64.v  v2, (a1)

    ld   t0, 0(a1)
    li   t2, 0x12345678
    bne  t0, t2, fail_vzext_vf2_e64
    ld   t0, 8(a1)
    li   t2, 0xffffffff
    bne  t0, t2, fail_vzext_vf2_e64

    vsext.vf2 v2, v4
    vse64.v  v2, (a1)

    ld   t0, 0(a1)
    li   t2, 0x12345678
    bne  t0, t2, fail_vsext_vf2_e64
    ld   t0, 8(a1)
    li   t2, -1
    bne  t0, t2, fail_vsext_vf2_e64

    # =========================================================================
    # Test 4: vzext.vf4 & vsext.vf4 (e8 -> e32)
    # vs2 (v4): 0x05, 0xff (-1), 0x80 (-128), 0x7f (127)
    # vzext expected: 0x00000005, 0x000000ff, 0x00000080, 0x0000007f
    # vsext expected: 0x00000005, 0xffffffff, 0xffffff80, 0x0000007f
    # =========================================================================
    li   t0, 0x7f80ff05
    sw   t0, 0(a0)

    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)

    vsetivli t0, 4, e32, m1, ta, ma
    vzext.vf4 v2, v4
    vse32.v  v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x00000005
    bne  t0, t2, fail_vzext_vf4_e32
    lwu  t0, 4(a1)
    li   t2, 0x000000ff
    bne  t0, t2, fail_vzext_vf4_e32
    lwu  t0, 8(a1)
    li   t2, 0x00000080
    bne  t0, t2, fail_vzext_vf4_e32
    lwu  t0, 12(a1)
    li   t2, 0x0000007f
    bne  t0, t2, fail_vzext_vf4_e32

    vsext.vf4 v2, v4
    vse32.v  v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x00000005
    bne  t0, t2, fail_vsext_vf4_e32
    lwu  t0, 4(a1)
    li   t2, 0xffffffff
    bne  t0, t2, fail_vsext_vf4_e32
    lwu  t0, 8(a1)
    li   t2, 0xffffff80
    bne  t0, t2, fail_vsext_vf4_e32
    lwu  t0, 12(a1)
    li   t2, 0x0000007f
    bne  t0, t2, fail_vsext_vf4_e32

    # =========================================================================
    # Test 5: vzext.vf4 & vsext.vf4 (e16 -> e64)
    # vs2 (v4): 0x1000, 0xffff (-1)
    # vzext expected: 0x0000000000001000, 0x000000000000ffff
    # vsext expected: 0x0000000000001000, 0xffffffffffffffff
    # =========================================================================
    li   t0, 0xffff1000
    sw   t0, 0(a0)

    vsetivli t0, 2, e16, m1, ta, ma
    vle16.v  v4, (a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vzext.vf4 v2, v4
    vse64.v  v2, (a1)

    ld   t0, 0(a1)
    li   t2, 0x1000
    bne  t0, t2, fail_vzext_vf4_e64
    ld   t0, 8(a1)
    li   t2, 0xffff
    bne  t0, t2, fail_vzext_vf4_e64

    vsext.vf4 v2, v4
    vse64.v  v2, (a1)

    ld   t0, 0(a1)
    li   t2, 0x1000
    bne  t0, t2, fail_vsext_vf4_e64
    ld   t0, 8(a1)
    li   t2, -1
    bne  t0, t2, fail_vsext_vf4_e64

    # =========================================================================
    # Test 6: vzext.vf8 & vsext.vf8 (e8 -> e64)
    # vs2 (v4): 0x42, 0x80 (-128)
    # vzext expected: 0x0000000000000042, 0x0000000000000080
    # vsext expected: 0x0000000000000042, 0xffffffffffffff80
    # =========================================================================
    li   t0, 0x00008042
    sw   t0, 0(a0)

    vsetivli t0, 2, e8, m1, ta, ma
    vle8.v   v4, (a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vzext.vf8 v2, v4
    vse64.v  v2, (a1)

    ld   t0, 0(a1)
    li   t2, 0x42
    bne  t0, t2, fail_vzext_vf8_e64
    ld   t0, 8(a1)
    li   t2, 0x80
    bne  t0, t2, fail_vzext_vf8_e64

    vsext.vf8 v2, v4
    vse64.v  v2, (a1)

    ld   t0, 0(a1)
    li   t2, 0x42
    bne  t0, t2, fail_vsext_vf8_e64
    ld   t0, 8(a1)
    li   t2, 0xffffffffffffff80
    bne  t0, t2, fail_vsext_vf8_e64

    # =========================================================================
    # Test 7: Masked execution with v0.t (e8 -> e16)
    # v0 mask: 0b1010 (elements 1 and 3 active, 0 and 2 masked off)
    # vd initial: 0xaaaa, 0xbbbb, 0xcccc, 0xdddd
    # vs2 (v4):   0x01,   0xfe (-2), 0x03, 0x80 (-128)
    # Expected vsext.vf2: 0xaaaa, 0xfffe, 0xcccc, 0xff80
    # =========================================================================
    li   t0, 0xbbbbaaaa
    sw   t0, 0(a1)
    li   t0, 0xddddcccc
    sw   t0, 4(a1)
    vsetivli t0, 4, e16, m1, ta, mu
    vle16.v  v2, (a1)

    li   t0, 0x8003fe01
    sw   t0, 0(a0)
    vsetivli t0, 4, e8, m1, ta, mu
    vle8.v   v4, (a0)

    # v0 mask = 0b1010 (0x0a)
    li   t0, 0x0a
    sb   t0, 16(a0)
    addi t1, a0, 16
    vlm.v v0, (t1)

    vsetivli t0, 4, e16, m1, ta, mu
    vsext.vf2 v2, v4, v0.t
    vse16.v   v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0xaaaa
    bne  t0, t2, fail_mask
    lhu  t0, 2(a1)
    li   t2, 0xfffe
    bne  t0, t2, fail_mask
    lhu  t0, 4(a1)
    li   t2, 0xcccc
    bne  t0, t2, fail_mask
    lhu  t0, 6(a1)
    li   t2, 0xff80
    bne  t0, t2, fail_mask

    # =========================================================================
    # Test 8: Tail undisturbed (tu)
    # vd initial: 0x1111, 0x2222, 0x3333, 0x4444
    # vl = 2
    # vs2 (v4): 0x05, 0x06, 0x07, 0x08
    # Expected: 0x0005, 0x0006, 0x3333, 0x4444
    # =========================================================================
    li   t0, 0x22221111
    sw   t0, 0(a1)
    li   t0, 0x44443333
    sw   t0, 4(a1)
    vsetivli t0, 4, e16, m1, tu, ma
    vle16.v  v2, (a1)

    li   t0, 0x08070605
    sw   t0, 0(a0)
    vsetivli t0, 4, e8, m1, tu, ma
    vle8.v   v4, (a0)

    vsetivli t0, 2, e16, m1, tu, ma
    vzext.vf2 v2, v4

    vsetivli t0, 4, e16, m1, tu, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x0005
    bne  t0, t2, fail_tail
    lhu  t0, 2(a1)
    li   t2, 0x0006
    bne  t0, t2, fail_tail
    lhu  t0, 4(a1)
    li   t2, 0x3333
    bne  t0, t2, fail_tail
    lhu  t0, 6(a1)
    li   t2, 0x4444
    bne  t0, t2, fail_tail

    # =========================================================================
    # All tests passed!
    # =========================================================================
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
pass_loop:
    j    pass_loop

fail_vzext_vf2_e16:
    li   t0, 0xDEAD0001
    sd   t0, 0(s0)
fail_loop1:
    j    fail_loop1

fail_vsext_vf2_e16:
    li   t0, 0xDEAD0002
    sd   t0, 0(s0)
fail_loop2:
    j    fail_loop2

fail_vzext_vf2_e32:
    li   t0, 0xDEAD0003
    sd   t0, 0(s0)
fail_loop3:
    j    fail_loop3

fail_vsext_vf2_e32:
    li   t0, 0xDEAD0004
    sd   t0, 0(s0)
fail_loop4:
    j    fail_loop4

fail_vzext_vf2_e64:
    li   t0, 0xDEAD0005
    sd   t0, 0(s0)
fail_loop5:
    j    fail_loop5

fail_vsext_vf2_e64:
    li   t0, 0xDEAD0006
    sd   t0, 0(s0)
fail_loop6:
    j    fail_loop6

fail_vzext_vf4_e32:
    li   t0, 0xDEAD0007
    sd   t0, 0(s0)
fail_loop7:
    j    fail_loop7

fail_vsext_vf4_e32:
    li   t0, 0xDEAD0008
    sd   t0, 0(s0)
fail_loop8:
    j    fail_loop8

fail_vzext_vf4_e64:
    li   t0, 0xDEAD0009
    sd   t0, 0(s0)
fail_loop9:
    j    fail_loop9

fail_vsext_vf4_e64:
    li   t0, 0xDEAD000A
    sd   t0, 0(s0)
fail_loopA:
    j    fail_loopA

fail_vzext_vf8_e64:
    li   t0, 0xDEAD000B
    sd   t0, 0(s0)
fail_loopB:
    j    fail_loopB

fail_vsext_vf8_e64:
    li   t0, 0xDEAD000C
    sd   t0, 0(s0)
fail_loopC:
    j    fail_loopC

fail_mask:
    li   t0, 0xDEAD000D
    sd   t0, 0(s0)
fail_loopD:
    j    fail_loopD

fail_tail:
    li   t0, 0xDEAD000E
    sd   t0, 0(s0)
fail_loopE:
    j    fail_loopE
