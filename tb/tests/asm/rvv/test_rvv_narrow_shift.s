.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000200
    li   a1, 0x80000400

    # =========================================================================
    # Test 1: vncvt.x.x.w e64 -> e32 (SEW=32)
    # =========================================================================
    li   t0, 0x1122334455667788
    sd   t0, 0(a0)
    li   t0, 0x99aabbccddeeff00
    sd   t0, 8(a0)
    li   t0, 0x0123456789abcdef
    sd   t0, 16(a0)
    li   t0, 0xfedcba9876543210
    sd   t0, 24(a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a0)
    addi     t1, a0, 16
    vle64.v  v5, (t1)

    vsetivli t0, 4, e32, m1, ta, ma
    vncvt.x.x.w v2, v4
    vse32.v  v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x55667788
    bne  t0, t2, fail_vncvt_e32
    lwu  t0, 4(a1)
    li   t2, 0xddeeff00
    bne  t0, t2, fail_vncvt_e32
    lwu  t0, 8(a1)
    li   t2, 0x89abcdef
    bne  t0, t2, fail_vncvt_e32
    lwu  t0, 12(a1)
    li   t2, 0x76543210
    bne  t0, t2, fail_vncvt_e32

    # =========================================================================
    # Test 2: vncvt.x.x.w e32 -> e16 (SEW=16)
    # =========================================================================
    li   t0, 0x9abcdef012345678
    sd   t0, 0(a0)
    li   t0, 0xcafe0123deadbeef
    sd   t0, 8(a0)
    li   t0, 0x0fedcba943218765
    sd   t0, 16(a0)
    li   t0, 0x1230fecabeefdead
    sd   t0, 24(a0)

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v4, (a0)
    addi     t1, a0, 16
    vle32.v  v5, (t1)

    vsetivli t0, 8, e16, m1, ta, ma
    vncvt.x.x.w v2, v4
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x5678
    bne  t0, t2, fail_vncvt_e16
    lhu  t0, 2(a1)
    li   t2, 0xdef0
    bne  t0, t2, fail_vncvt_e16
    lhu  t0, 4(a1)
    li   t2, 0xbeef
    bne  t0, t2, fail_vncvt_e16
    lhu  t0, 6(a1)
    li   t2, 0x0123
    bne  t0, t2, fail_vncvt_e16
    lhu  t0, 8(a1)
    li   t2, 0x8765
    bne  t0, t2, fail_vncvt_e16
    lhu  t0, 10(a1)
    li   t2, 0xcba9
    bne  t0, t2, fail_vncvt_e16
    lhu  t0, 12(a1)
    li   t2, 0xdead
    bne  t0, t2, fail_vncvt_e16
    lhu  t0, 14(a1)
    li   t2, 0xfeca
    bne  t0, t2, fail_vncvt_e16

    # =========================================================================
    # Test 3: vncvt.x.x.w e16 -> e8 (SEW=8)
    # =========================================================================
    li   t0, 0x7788556633441122
    sd   t0, 0(a0)
    li   t0, 0x00ffeeddccbbaa99
    sd   t0, 8(a0)
    li   t0, 0x0708050603040102
    sd   t0, 16(a0)
    li   t0, 0x0f100d0e0b0c090a
    sd   t0, 24(a0)

    vsetivli t0, 8, e16, m1, ta, ma
    vle16.v  v4, (a0)
    addi     t1, a0, 16
    vle16.v  v5, (t1)

    vsetivli t0, 16, e8, m1, ta, ma
    vncvt.x.x.w v2, v4
    vse8.v   v2, (a1)

    lbu  t0, 0(a1)
    li   t2, 0x22
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 1(a1)
    li   t2, 0x44
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 2(a1)
    li   t2, 0x66
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 3(a1)
    li   t2, 0x88
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 4(a1)
    li   t2, 0x99
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 5(a1)
    li   t2, 0xbb
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 6(a1)
    li   t2, 0xdd
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 7(a1)
    li   t2, 0xff
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 8(a1)
    li   t2, 0x02
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 9(a1)
    li   t2, 0x04
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 10(a1)
    li   t2, 0x06
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 11(a1)
    li   t2, 0x08
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 12(a1)
    li   t2, 0x0a
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 13(a1)
    li   t2, 0x0c
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 14(a1)
    li   t2, 0x0e
    bne  t0, t2, fail_vncvt_e8
    lbu  t0, 15(a1)
    li   t2, 0x10
    bne  t0, t2, fail_vncvt_e8

    # =========================================================================
    # Test 4: vnsrl.wi (immediate logical right shift)
    # =========================================================================
    # e64 -> e32, shift by 16
    li   t0, 0x0123456789abcdef
    sd   t0, 0(a0)
    li   t0, 0xfedcba9876543210
    sd   t0, 8(a0)
    li   t0, 0x1122334455667788
    sd   t0, 16(a0)
    li   t0, 0x99aabbccddeeff00
    sd   t0, 24(a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a0)
    addi     t1, a0, 16
    vle64.v  v5, (t1)

    vsetivli t0, 4, e32, m1, ta, ma
    vnsrl.wi v2, v4, 16
    vse32.v  v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x456789ab
    bne  t0, t2, fail_vnsrl_wi_e32
    lwu  t0, 4(a1)
    li   t2, 0xba987654
    bne  t0, t2, fail_vnsrl_wi_e32
    lwu  t0, 8(a1)
    li   t2, 0x33445566
    bne  t0, t2, fail_vnsrl_wi_e32
    lwu  t0, 12(a1)
    li   t2, 0xbbccddee
    bne  t0, t2, fail_vnsrl_wi_e32

    # e16 -> e8, shift by 4
    li   t0, 0xdef09abc56781234
    sd   t0, 0(a0)
    li   t0, 0xfdb98ace13570246
    sd   t0, 8(a0)

    vsetivli t0, 8, e16, m1, ta, ma
    vle16.v  v4, (a0)

    vsetivli t0, 8, e8, m1, ta, ma
    vnsrl.wi v2, v4, 4
    vse8.v   v2, (a1)

    lbu  t0, 0(a1)
    li   t2, 0x23
    bne  t0, t2, fail_vnsrl_wi_e8
    lbu  t0, 1(a1)
    li   t2, 0x67
    bne  t0, t2, fail_vnsrl_wi_e8
    lbu  t0, 2(a1)
    li   t2, 0xab
    bne  t0, t2, fail_vnsrl_wi_e8
    lbu  t0, 3(a1)
    li   t2, 0xef
    bne  t0, t2, fail_vnsrl_wi_e8
    lbu  t0, 4(a1)
    li   t2, 0x24
    bne  t0, t2, fail_vnsrl_wi_e8
    lbu  t0, 5(a1)
    li   t2, 0x35
    bne  t0, t2, fail_vnsrl_wi_e8
    lbu  t0, 6(a1)
    li   t2, 0xac
    bne  t0, t2, fail_vnsrl_wi_e8
    lbu  t0, 7(a1)
    li   t2, 0xdb
    bne  t0, t2, fail_vnsrl_wi_e8

    # =========================================================================
    # Test 5: vnsra.wi (immediate arithmetic right shift)
    # =========================================================================
    # e64 -> e32, shift by 16 with negative numbers
    li   t0, 0x8000000012345678
    sd   t0, 0(a0)
    li   t0, 0xffffffff80000000
    sd   t0, 8(a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a0)

    vsetivli t0, 2, e32, m1, ta, ma
    vnsra.wi v2, v4, 16
    vse32.v  v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x00001234
    bne  t0, t2, fail_vnsra_wi_e32
    lwu  t0, 4(a1)
    li   t2, 0xffff8000
    bne  t0, t2, fail_vnsra_wi_e32

    # e32 -> e16, shift by 8
    li   t0, 0xffff800080001234
    sd   t0, 0(a0)
    li   t0, 0x001234567f005678
    sd   t0, 8(a0)

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v4, (a0)

    vsetivli t0, 4, e16, m1, ta, ma
    vnsra.wi v2, v4, 8
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x0012
    bne  t0, t2, fail_vnsra_wi_e16
    lhu  t0, 2(a1)
    li   t2, 0xff80
    bne  t0, t2, fail_vnsra_wi_e16
    lhu  t0, 4(a1)
    li   t2, 0x0056
    bne  t0, t2, fail_vnsra_wi_e16
    lhu  t0, 6(a1)
    li   t2, 0x1234
    bne  t0, t2, fail_vnsra_wi_e16

    # =========================================================================
    # Test 6: vnsrl.wx & vnsra.wx (scalar register shift amount)
    # =========================================================================
    li   t0, 0x123456789abcdef0
    sd   t0, 0(a0)
    li   t0, 0x89abcdef01234567
    sd   t0, 8(a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a0)

    li   a2, 32
    vsetivli t0, 2, e32, m1, ta, ma
    vnsrl.wx v2, v4, a2
    vse32.v  v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x12345678
    bne  t0, t2, fail_vnsrl_wx
    lwu  t0, 4(a1)
    li   t2, 0x89abcdef
    bne  t0, t2, fail_vnsrl_wx

    vnsra.wx v3, v4, a2
    vse32.v  v3, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x12345678
    bne  t0, t2, fail_vnsra_wx
    lwu  t0, 4(a1)
    li   t2, 0x89abcdef
    bne  t0, t2, fail_vnsra_wx

    # =========================================================================
    # Test 7: vnsrl.wv & vnsra.wv (vector shift amount)
    # =========================================================================
    # Source 32-bit: all 0x12345678
    li   t0, 0x1234567812345678
    sd   t0, 0(a0)
    sd   t0, 8(a0)
    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v4, (a0)

    # Shift amounts in v6 (e16): 0, 4, 8, 12
    li   t0, 0x000c000800040000
    sd   t0, 0(a0)
    vsetivli t0, 4, e16, m1, ta, ma
    vle16.v  v6, (a0)

    vnsrl.wv v2, v4, v6
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x5678
    bne  t0, t2, fail_vnsrl_wv
    lhu  t0, 2(a1)
    li   t2, 0x4567
    bne  t0, t2, fail_vnsrl_wv
    lhu  t0, 4(a1)
    li   t2, 0x3456
    bne  t0, t2, fail_vnsrl_wv
    lhu  t0, 6(a1)
    li   t2, 0x2345
    bne  t0, t2, fail_vnsrl_wv

    # =========================================================================
    # Test 8: Masked operation with v0.t and mask undisturbed (mu)
    # =========================================================================
    # Mask: 0b0101 (lanes 0, 2 active; lanes 1, 3 masked)
    li   t0, 0x05
    sd   t0, 0(a0)
    vlm.v v0, (a0)

    # Preset v2 with 0x55555555 in all lanes
    li   t0, 0x5555555555555555
    sd   t0, 0(a1)
    sd   t0, 8(a1)
    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a1)

    # Source 64-bit values in v4/v5:
    li   t0, 0x0123456789abcdef
    sd   t0, 0(a0)
    li   t0, 0x1111111122222222
    sd   t0, 8(a0)
    li   t0, 0xfedcba9876543210
    sd   t0, 16(a0)
    li   t0, 0x3333333344444444
    sd   t0, 24(a0)
    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a0)
    addi     t1, a0, 16
    vle64.v  v5, (t1)

    # Shift by 16 with mask and mask-undisturbed (mu)
    vsetivli t0, 4, e32, m1, ta, mu
    vnsrl.wi v2, v4, 16, v0.t

    # Store full 4 elements
    vsetivli t0, 4, e32, m1, ta, ma
    vse32.v  v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x456789ab  # Lane 0: active
    bne  t0, t2, fail_masked
    lwu  t0, 4(a1)
    li   t2, 0x55555555  # Lane 1: masked undisturbed
    bne  t0, t2, fail_masked
    lwu  t0, 8(a1)
    li   t2, 0xba987654  # Lane 2: active
    bne  t0, t2, fail_masked
    lwu  t0, 12(a1)
    li   t2, 0x55555555  # Lane 3: masked undisturbed
    bne  t0, t2, fail_masked

    # =========================================================================
    # Test 9: Tail undisturbed (tu)
    # =========================================================================
    # Preset v2 with 0x77777777 in all lanes
    li   t0, 0x7777777777777777
    sd   t0, 0(a1)
    sd   t0, 8(a1)
    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a1)

    # Run with vl=2, tu
    vsetivli t0, 2, e32, m1, tu, ma
    vnsrl.wi v2, v4, 16

    # Store full 4 elements
    vsetivli t0, 4, e32, m1, ta, ma
    vse32.v  v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x456789ab  # Lane 0: active
    bne  t0, t2, fail_tail
    lwu  t0, 4(a1)
    li   t2, 0x11112222  # Lane 1: active (0x1111111122222222 >> 16 = ...11112222)
    bne  t0, t2, fail_tail
    lwu  t0, 8(a1)
    li   t2, 0x77777777  # Lane 2: tail undisturbed
    bne  t0, t2, fail_tail
    lwu  t0, 12(a1)
    li   t2, 0x77777777  # Lane 3: tail undisturbed
    bne  t0, t2, fail_tail

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
1:  j    1b

fail_vncvt_e32:    li t0, 0xDEAD0001; j fail
fail_vncvt_e16:    li t0, 0xDEAD0002; j fail
fail_vncvt_e8:     li t0, 0xDEAD0003; j fail
fail_vnsrl_wi_e32: li t0, 0xDEAD0004; j fail
fail_vnsrl_wi_e8:  li t0, 0xDEAD0005; j fail
fail_vnsra_wi_e32: li t0, 0xDEAD0006; j fail
fail_vnsra_wi_e16: li t0, 0xDEAD0007; j fail
fail_vnsrl_wx:     li t0, 0xDEAD0008; j fail
fail_vnsra_wx:     li t0, 0xDEAD0009; j fail
fail_vnsrl_wv:     li t0, 0xDEAD000A; j fail
fail_masked:       li t0, 0xDEAD000B; j fail
fail_tail:         li t0, 0xDEAD000C; j fail

fail:
    sd   t0, 0(s0)
2:  j    2b
