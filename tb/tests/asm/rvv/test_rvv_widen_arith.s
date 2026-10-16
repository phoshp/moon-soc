.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000200
    li   a1, 0x80000400

    # =========================================================================
    # Test 1: vwaddu.vv & vwaddu.vx (e8 -> e16)
    # vs2: 0xff, 0xfe, 0x80, 0x12
    # vs1: 0x01, 0x02, 0x80, 0x34
    # Expected: 0x0100, 0x0100, 0x0100, 0x0046
    # =========================================================================
    li   t0, 0x1280feff
    sd   t0, 0(a0)
    li   t0, 0x34800201
    sd   t0, 8(a0)

    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)
    addi     t1, a0, 8
    vle8.v   v6, (t1)

    vwaddu.vv v2, v4, v6
    vsetivli t0, 4, e16, m1, ta, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x0100
    bne  t0, t2, fail_vwaddu_vv
    lhu  t0, 2(a1)
    li   t2, 0x0100
    bne  t0, t2, fail_vwaddu_vv
    lhu  t0, 4(a1)
    li   t2, 0x0100
    bne  t0, t2, fail_vwaddu_vv
    lhu  t0, 6(a1)
    li   t2, 0x0046
    bne  t0, t2, fail_vwaddu_vv

    # vwaddu.vx with scalar rs1 = 0x10
    li   a2, 0x10
    vsetivli t0, 4, e8, m1, ta, ma
    vwaddu.vx v2, v4, a2
    vsetivli t0, 4, e16, m1, ta, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x010f  # 0xff + 0x10
    bne  t0, t2, fail_vwaddu_vx
    lhu  t0, 2(a1)
    li   t2, 0x010e  # 0xfe + 0x10
    bne  t0, t2, fail_vwaddu_vx
    lhu  t0, 4(a1)
    li   t2, 0x0090  # 0x80 + 0x10
    bne  t0, t2, fail_vwaddu_vx
    lhu  t0, 6(a1)
    li   t2, 0x0022  # 0x12 + 0x10
    bne  t0, t2, fail_vwaddu_vx

    # =========================================================================
    # Test 2: vwadd.vv & vwadd.vx (signed e8 -> e16)
    # vs2: -1 (0xff), -128 (0x80), 127 (0x7f), -50 (0xce)
    # vs1: -1 (0xff), -1 (0xff),   1 (0x01),   50 (0x32)
    # Expected: -2 (0xfffe), -129 (0xff7f), 128 (0x0080), 0 (0x0000)
    # =========================================================================
    li   t0, 0xce7f80ff
    sd   t0, 0(a0)
    li   t0, 0x3201ffff
    sd   t0, 8(a0)

    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)
    addi     t1, a0, 8
    vle8.v   v6, (t1)

    vwadd.vv v2, v4, v6
    vsetivli t0, 4, e16, m1, ta, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0xfffe
    bne  t0, t2, fail_vwadd_vv
    lhu  t0, 2(a1)
    li   t2, 0xff7f
    bne  t0, t2, fail_vwadd_vv
    lhu  t0, 4(a1)
    li   t2, 0x0080
    bne  t0, t2, fail_vwadd_vv
    lhu  t0, 6(a1)
    bnez t0, fail_vwadd_vv

    # vwadd.vx with scalar rs1 = -1
    li   a2, -1
    vsetivli t0, 4, e8, m1, ta, ma
    vwadd.vx v2, v4, a2
    vsetivli t0, 4, e16, m1, ta, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0xfffe  # -1 + -1 = -2
    bne  t0, t2, fail_vwadd_vx
    lhu  t0, 2(a1)
    li   t2, 0xff7f  # -128 + -1 = -129
    bne  t0, t2, fail_vwadd_vx
    lhu  t0, 4(a1)
    li   t2, 0x007e  # 127 + -1 = 126
    bne  t0, t2, fail_vwadd_vx
    lhu  t0, 6(a1)
    li   t2, 0xffcd  # -50 + -1 = -51
    bne  t0, t2, fail_vwadd_vx

    # =========================================================================
    # Test 3: vwsubu.vv & vwsub.vv (e8 -> e16)
    # vs2: 5 (0x05), 0 (0x00), 100 (0x64), 200 (0xc8)
    # vs1: 10 (0x0a), 1 (0x01), 50 (0x32), 250 (0xfa)
    # Expected vwsubu: 0xfffb, 0xffff, 0x0032, 0xffce
    # =========================================================================
    li   t0, 0xc8640005
    sd   t0, 0(a0)
    li   t0, 0xfa32010a
    sd   t0, 8(a0)

    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)
    addi     t1, a0, 8
    vle8.v   v6, (t1)

    vwsubu.vv v2, v4, v6
    vsetivli  t0, 4, e16, m1, ta, ma
    vse16.v   v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0xfffb
    bne  t0, t2, fail_vwsubu_vv
    lhu  t0, 2(a1)
    li   t2, 0xffff
    bne  t0, t2, fail_vwsubu_vv
    lhu  t0, 4(a1)
    li   t2, 0x0032
    bne  t0, t2, fail_vwsubu_vv
    lhu  t0, 6(a1)
    li   t2, 0xffce
    bne  t0, t2, fail_vwsubu_vv

    # vwsub.vv signed
    # vs2: -128 (0x80), 127 (0x7f), 0 (0x00), -50 (0xce)
    # vs1: 1 (0x01), -1 (0xff), 100 (0x64), 50 (0x32)
    # Expected: -129 (0xff7f), 128 (0x0080), -100 (0xff9c), -100 (0xff9c)
    li   t0, 0xce007f80
    sd   t0, 0(a0)
    li   t0, 0x3264ff01
    sd   t0, 8(a0)

    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)
    addi     t1, a0, 8
    vle8.v   v6, (t1)

    vwsub.vv v2, v4, v6
    vsetivli t0, 4, e16, m1, ta, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0xff7f
    bne  t0, t2, fail_vwsub_vv
    lhu  t0, 2(a1)
    li   t2, 0x0080
    bne  t0, t2, fail_vwsub_vv
    lhu  t0, 4(a1)
    li   t2, 0xff9c
    bne  t0, t2, fail_vwsub_vv
    lhu  t0, 6(a1)
    li   t2, 0xff9c
    bne  t0, t2, fail_vwsub_vv

    # =========================================================================
    # Test 4: Wide source forms (.wv and .wx)
    # vwaddu.wv: wide vs2 (16-bit) + narrow vs1 (8-bit)
    # vs2 (16-bit): 0x0100, 0x0250
    # vs1 (8-bit):  0x20,   0xff
    # Expected: 0x0120, 0x034f
    # =========================================================================
    li   t0, 0x02500100
    sd   t0, 0(a0)
    li   t0, 0xff20
    sd   t0, 8(a0)

    vsetivli t0, 2, e16, m1, ta, ma
    vle16.v  v4, (a0)
    addi     t1, a0, 8
    vsetivli t0, 2, e8, m1, ta, ma
    vle8.v   v6, (t1)

    vwaddu.wv v2, v4, v6
    vsetivli  t0, 2, e16, m1, ta, ma
    vse16.v   v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x0120
    bne  t0, t2, fail_vwaddu_wv
    lhu  t0, 2(a1)
    li   t2, 0x034f
    bne  t0, t2, fail_vwaddu_wv

    # vwsub.wx: wide vs2 (16-bit) - narrow scalar rs1 (8-bit)
    # vs2 (16-bit): 100 (0x0064), -50 (0xffce)
    # rs1: 50 (0x32)
    # Expected: 50 (0x0032), -100 (0xff9c)
    li   t0, 0xffce0064
    sd   t0, 0(a0)
    vsetivli t0, 2, e16, m1, ta, ma
    vle16.v  v4, (a0)

    li   a2, 50
    vsetivli t0, 2, e8, m1, ta, ma
    vwsub.wx v2, v4, a2
    vsetivli t0, 2, e16, m1, ta, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x0032
    bne  t0, t2, fail_vwsub_wx
    lhu  t0, 2(a1)
    li   t2, 0xff9c
    bne  t0, t2, fail_vwsub_wx

    # =========================================================================
    # Test 5: vwmulu.vv & vwmulu.vx (e8 -> e16)
    # vs2: 255 (0xff), 16 (0x10), 200 (0xc8), 0 (0x00)
    # vs1: 255 (0xff), 16 (0x10), 2 (0x02), 255 (0xff)
    # Expected: 65025 (0xfe01), 256 (0x0100), 400 (0x0190), 0 (0x0000)
    # =========================================================================
    li   t0, 0x00c810ff
    sd   t0, 0(a0)
    li   t0, 0xff0210ff
    sd   t0, 8(a0)

    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)
    addi     t1, a0, 8
    vle8.v   v6, (t1)

    vwmulu.vv v2, v4, v6
    vsetivli  t0, 4, e16, m1, ta, ma
    vse16.v   v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0xfe01
    bne  t0, t2, fail_vwmulu_vv
    lhu  t0, 2(a1)
    li   t2, 0x0100
    bne  t0, t2, fail_vwmulu_vv
    lhu  t0, 4(a1)
    li   t2, 0x0190
    bne  t0, t2, fail_vwmulu_vv
    lhu  t0, 6(a1)
    bnez t0, fail_vwmulu_vv

    # vwmulu.vx with scalar rs1 = 3
    li   a2, 3
    vsetivli t0, 4, e8, m1, ta, ma
    vwmulu.vx v2, v4, a2
    vsetivli  t0, 4, e16, m1, ta, ma
    vse16.v   v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 765     # 255 * 3
    bne  t0, t2, fail_vwmulu_vx
    lhu  t0, 2(a1)
    li   t2, 48      # 16 * 3
    bne  t0, t2, fail_vwmulu_vx
    lhu  t0, 4(a1)
    li   t2, 600     # 200 * 3
    bne  t0, t2, fail_vwmulu_vx
    lhu  t0, 6(a1)
    bnez t0, fail_vwmulu_vx

    # =========================================================================
    # Test 6: vwmul.vv & vwmul.vx (signed e8 -> e16)
    # vs2: -128 (0x80), -1 (0xff), -10 (0xf6), 50 (0x32)
    # vs1: -128 (0x80), 127 (0x7f), -10 (0xf6), -2 (0xfe)
    # Expected: 16384 (0x4000), -127 (0xff81), 100 (0x0064), -100 (0xff9c)
    # =========================================================================
    li   t0, 0x32f6ff80
    sd   t0, 0(a0)
    li   t0, 0xfef67f80
    sd   t0, 8(a0)

    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)
    addi     t1, a0, 8
    vle8.v   v6, (t1)

    vwmul.vv v2, v4, v6
    vsetivli t0, 4, e16, m1, ta, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x4000
    bne  t0, t2, fail_vwmul_vv
    lhu  t0, 2(a1)
    li   t2, 0xff81
    bne  t0, t2, fail_vwmul_vv
    lhu  t0, 4(a1)
    li   t2, 0x0064
    bne  t0, t2, fail_vwmul_vv
    lhu  t0, 6(a1)
    li   t2, 0xff9c
    bne  t0, t2, fail_vwmul_vv

    # =========================================================================
    # Test 7: vwmulsu.vv & vwmulsu.vx (signed vs2 * unsigned vs1)
    # vs2: -1 (0xff), -128 (0x80), 127 (0x7f), -50 (0xce)
    # vs1: 255 (0xff), 255 (0xff), 255 (0xff), 2 (0x02)
    # Expected: -255 (0xff01), -32640 (0x8080), 32385 (0x7e81), -100 (0xff9c)
    # =========================================================================
    li   t0, 0xce7f80ff
    sd   t0, 0(a0)
    li   t0, 0x02ffffff
    sd   t0, 8(a0)

    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)
    addi     t1, a0, 8
    vle8.v   v6, (t1)

    vwmulsu.vv v2, v4, v6
    vsetivli   t0, 4, e16, m1, ta, ma
    vse16.v    v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0xff01
    bne  t0, t2, fail_vwmulsu_vv
    lhu  t0, 2(a1)
    li   t2, 0x8080
    bne  t0, t2, fail_vwmulsu_vv
    lhu  t0, 4(a1)
    li   t2, 0x7e81
    bne  t0, t2, fail_vwmulsu_vv
    lhu  t0, 6(a1)
    li   t2, 0xff9c
    bne  t0, t2, fail_vwmulsu_vv

    # vwmulsu.vx with unsigned scalar rs1 = 200
    li   a2, 200
    vsetivli t0, 4, e8, m1, ta, ma
    vwmulsu.vx v2, v4, a2
    vsetivli   t0, 4, e16, m1, ta, ma
    vse16.v    v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0xff38  # -1 * 200 = -200
    bne  t0, t2, fail_vwmulsu_vx
    lhu  t0, 2(a1)
    li   t2, 0x9c00  # -128 * 200 = -25600
    bne  t0, t2, fail_vwmulsu_vx
    lhu  t0, 4(a1)
    li   t2, 0x6338  # 127 * 200 = 25400
    bne  t0, t2, fail_vwmulsu_vx
    lhu  t0, 6(a1)
    li   t2, 0xd8f0  # -50 * 200 = -10000
    bne  t0, t2, fail_vwmulsu_vx

    # =========================================================================
    # Test 8: e32 -> e64 widening operations
    # =========================================================================
    # vwaddu.vv e32: 0xffffffff + 1 = 0x100000000
    li   t0, 0xffffffff
    sd   t0, 0(a0)
    li   t0, 1
    sd   t0, 8(a0)

    vsetivli t0, 1, e32, m1, ta, ma
    vle32.v  v4, (a0)
    addi     t1, a0, 8
    vle32.v  v6, (t1)

    vwaddu.vv v2, v4, v6
    vsetivli  t0, 1, e64, m1, ta, ma
    vse64.v   v2, (a1)

    ld   t0, 0(a1)
    li   t2, 0x100000000
    bne  t0, t2, fail_widen_e32

    # vwmulu.vv e32: 0xffffffff * 0xffffffff = 0xfffffffe00000001
    vsetivli t0, 1, e32, m1, ta, ma
    vwmulu.vv v2, v4, v4
    vsetivli  t0, 1, e64, m1, ta, ma
    vse64.v   v2, (a1)

    ld   t0, 0(a1)
    li   t2, 0xfffffffe00000001
    bne  t0, t2, fail_widen_e32

    # vwmul.vv e32: -2147483648 (0x80000000) * -1 (0xffffffff) = 2147483648
    li   t0, 0x80000000
    sd   t0, 0(a0)
    li   t0, 0xffffffff
    sd   t0, 8(a0)
    vsetivli t0, 1, e32, m1, ta, ma
    vle32.v  v4, (a0)
    addi     t1, a0, 8
    vle32.v  v6, (t1)

    vwmul.vv v2, v4, v6
    vsetivli t0, 1, e64, m1, ta, ma
    vse64.v  v2, (a1)

    ld   t0, 0(a1)
    li   t2, 0x80000000
    bne  t0, t2, fail_widen_e32

    # =========================================================================
    # Test 9: Masking (v0.t) with mu and Tail Undisturbed (tu)
    # =========================================================================
    # Mask: 0b0101 (lanes 0, 2 active; lanes 1, 3 masked)
    li   t0, 0x05
    sd   t0, 0(a0)
    vlm.v v0, (a0)

    # Preset v2 with 0x55555555_55555555
    li   t0, 0x5555555555555555
    sd   t0, 0(a1)
    sd   t0, 8(a1)
    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a1)

    # Load 4 16-bit elements into v4 and v6
    li   t0, 0x0004000300020001
    sd   t0, 0(a0)
    li   t0, 0x0010001000100010
    sd   t0, 8(a0)
    vsetivli t0, 4, e16, m1, ta, ma
    vle16.v  v4, (a0)
    addi     t1, a0, 8
    vle16.v  v6, (t1)

    # Widening add with mask and mask-undisturbed (mu)
    vsetivli t0, 4, e16, m1, ta, mu
    vwadd.vv v2, v4, v6, v0.t

    vsetivli t0, 4, e32, m1, ta, ma
    vse32.v  v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x0011      # Lane 0 active: 1 + 16 = 17
    bne  t0, t2, fail_masked
    lwu  t0, 4(a1)
    li   t2, 0x55555555  # Lane 1 masked undisturbed
    bne  t0, t2, fail_masked
    lwu  t0, 8(a1)
    li   t2, 0x0013      # Lane 2 active: 3 + 16 = 19
    bne  t0, t2, fail_masked
    lwu  t0, 12(a1)
    li   t2, 0x55555555  # Lane 3 masked undisturbed
    bne  t0, t2, fail_masked

    # Tail undisturbed (tu)
    li   t0, 0x7777777777777777
    sd   t0, 0(a1)
    sd   t0, 8(a1)
    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a1)

    vsetivli t0, 2, e16, m1, tu, ma
    vwadd.vv v2, v4, v6

    vsetivli t0, 4, e32, m1, ta, ma
    vse32.v  v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x0011      # Lane 0 active: 17
    bne  t0, t2, fail_tail
    lwu  t0, 4(a1)
    li   t2, 0x0012      # Lane 1 active: 18
    bne  t0, t2, fail_tail
    lwu  t0, 8(a1)
    li   t2, 0x77777777  # Lane 2 tail undisturbed
    bne  t0, t2, fail_tail
    lwu  t0, 12(a1)
    li   t2, 0x77777777  # Lane 3 tail undisturbed
    bne  t0, t2, fail_tail

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
1:  j    1b

fail_vwaddu_vv:    li t0, 0xDEAD0001; j fail
fail_vwaddu_vx:    li t0, 0xDEAD0002; j fail
fail_vwadd_vv:     li t0, 0xDEAD0003; j fail
fail_vwadd_vx:     li t0, 0xDEAD0004; j fail
fail_vwsubu_vv:    li t0, 0xDEAD0005; j fail
fail_vwsub_vv:     li t0, 0xDEAD0006; j fail
fail_vwaddu_wv:    li t0, 0xDEAD0007; j fail
fail_vwsub_wx:     li t0, 0xDEAD0008; j fail
fail_vwmulu_vv:    li t0, 0xDEAD0009; j fail
fail_vwmulu_vx:    li t0, 0xDEAD000A; j fail
fail_vwmul_vv:     li t0, 0xDEAD000B; j fail
fail_vwmulsu_vv:   li t0, 0xDEAD000C; j fail
fail_vwmulsu_vx:   li t0, 0xDEAD000D; j fail
fail_widen_e32:    li t0, 0xDEAD000E; j fail
fail_masked:       li t0, 0xDEAD000F; j fail
fail_tail:         li t0, 0xDEAD0010; j fail

fail:
    sd   t0, 0(s0)
2:  j    2b
