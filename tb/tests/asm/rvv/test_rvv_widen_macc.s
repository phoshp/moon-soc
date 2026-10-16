.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000200
    li   a1, 0x80000400

    # =========================================================================
    # Test 1: vwmaccu.vv & vwmaccu.vx (e8 -> e16)
    # vd initial: 0x1000, 0x2000, 0x0010, 0x0000
    # vs2 (v4):   0x10,   0x20,   0xff,   0x03
    # vs1 (v6):   0x05,   0x04,   0x02,   0x10
    # Products:   0x0050, 0x0080, 0x01fe, 0x0030
    # Expected:   0x1050, 0x2080, 0x020e, 0x0030
    # =========================================================================
    # Prepare vd initial values
    li   t0, 0x20001000
    sw   t0, 0(a1)
    li   t0, 0x00000010
    sw   t0, 4(a1)
    vsetivli t0, 4, e16, m1, ta, ma
    vle16.v  v2, (a1)

    # Prepare vs2 and vs1
    li   t0, 0x03ff2010
    sw   t0, 0(a0)
    li   t0, 0x10020405
    sw   t0, 4(a0)

    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)
    addi     t1, a0, 4
    vle8.v   v6, (t1)

    # vwmaccu.vv vd, vs1, vs2
    vwmaccu.vv v2, v6, v4

    vsetivli t0, 4, e16, m1, ta, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x1050
    bne  t0, t2, fail_vwmaccu_vv
    lhu  t0, 2(a1)
    li   t2, 0x2080
    bne  t0, t2, fail_vwmaccu_vv
    lhu  t0, 4(a1)
    li   t2, 0x020e
    bne  t0, t2, fail_vwmaccu_vv
    lhu  t0, 6(a1)
    li   t2, 0x0030
    bne  t0, t2, fail_vwmaccu_vv

    # vwmaccu.vx with scalar rs1 = 0x03
    # vd currently: 0x1050, 0x2080, 0x020e, 0x0030
    # vs2 (v4):     0x10,   0x20,   0xff,   0x03
    # Products:     0x0030, 0x0060, 0x02fd, 0x0009
    # Expected:     0x1080, 0x20e0, 0x050b, 0x0039
    li   a2, 0x03
    vsetivli t0, 4, e8, m1, ta, ma
    vwmaccu.vx v2, a2, v4

    vsetivli t0, 4, e16, m1, ta, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x1080
    bne  t0, t2, fail_vwmaccu_vx
    lhu  t0, 2(a1)
    li   t2, 0x20e0
    bne  t0, t2, fail_vwmaccu_vx
    lhu  t0, 4(a1)
    li   t2, 0x050b
    bne  t0, t2, fail_vwmaccu_vx
    lhu  t0, 6(a1)
    li   t2, 0x0039
    bne  t0, t2, fail_vwmaccu_vx

    # =========================================================================
    # Test 2: vwmacc.vv & vwmacc.vx (signed e8 -> e16)
    # vd initial: 0x0000, 0x1000, 0xfffe (-2), 0x0050
    # vs2 (v4):   -10 (0xf6), 10 (0x0a), -128 (0x80), 5 (0x05)
    # vs1 (v6):   5 (0x05),   -2 (0xfe), -1 (0xff),   -10 (0xf6)
    # Products:   -50 (0xffce), -20 (0xffec), 128 (0x0080), -50 (0xffce)
    # Expected:   0xffce (-50), 0x0fec,       0x007e (126), 0x0000 (0)
    # =========================================================================
    li   t0, 0x10000000
    sw   t0, 0(a1)
    li   t0, 0x0032fffe  # 50 (0x32), -2 (0xfffe)
    sw   t0, 4(a1)
    vsetivli t0, 4, e16, m1, ta, ma
    vle16.v  v2, (a1)

    li   t0, 0x05800af6
    sw   t0, 0(a0)
    li   t0, 0xf6fffe05
    sw   t0, 4(a0)

    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)
    addi     t1, a0, 4
    vle8.v   v6, (t1)

    vwmacc.vv v2, v6, v4

    vsetivli t0, 4, e16, m1, ta, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0xffce
    bne  t0, t2, fail_vwmacc_vv
    lhu  t0, 2(a1)
    li   t2, 0x0fec
    bne  t0, t2, fail_vwmacc_vv
    lhu  t0, 4(a1)
    li   t2, 0x007e
    bne  t0, t2, fail_vwmacc_vv
    lhu  t0, 6(a1)
    bnez t0, fail_vwmacc_vv

    # vwmacc.vx with scalar rs1 = -2
    # vd initial: 0, 0, 0, 0
    # vs2 (v4):   10 (0x0a), -10 (0xf6), 127 (0x7f), -128 (0x80)
    # Products:   -20 (0xffec), 20 (0x0014), -254 (0xff02), 256 (0x0100)
    # Expected:   0xffec, 0x0014, 0xff02, 0x0100
    sw   zero, 0(a1)
    sw   zero, 4(a1)
    vsetivli t0, 4, e16, m1, ta, ma
    vle16.v  v2, (a1)

    li   t0, 0x807ff60a
    sw   t0, 0(a0)
    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)

    li   a2, -2
    vwmacc.vx v2, a2, v4

    vsetivli t0, 4, e16, m1, ta, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0xffec
    bne  t0, t2, fail_vwmacc_vx
    lhu  t0, 2(a1)
    li   t2, 0x0014
    bne  t0, t2, fail_vwmacc_vx
    lhu  t0, 4(a1)
    li   t2, 0xff02
    bne  t0, t2, fail_vwmacc_vx
    lhu  t0, 6(a1)
    li   t2, 0x0100
    bne  t0, t2, fail_vwmacc_vx

    # =========================================================================
    # Test 3: vwmaccsu.vv & vwmaccsu.vx (signed vs2 * unsigned vs1/rs1)
    # vd initial: 0x0100, 0x0200, 0x0000, 0x0000
    # vs2 (v4, signed):   -1 (0xff), -2 (0xfe), 5 (0x05),  -10 (0xf6)
    # vs1 (v6, unsigned): 200 (0xc8), 100 (0x64), 50 (0x32), 20 (0x14)
    # Products:           -200 (0xff38), -200 (0xff38), 250 (0x00fa), -200 (0xff38)
    # Expected:           56 (0x0038), 312 (0x0138), 250 (0x00fa), -200 (0xff38)
    # =========================================================================
    li   t0, 0x02000100
    sw   t0, 0(a1)
    sw   zero, 4(a1)
    vsetivli t0, 4, e16, m1, ta, ma
    vle16.v  v2, (a1)

    li   t0, 0xf605feff
    sw   t0, 0(a0)
    li   t0, 0x143264c8
    sw   t0, 4(a0)

    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)
    addi     t1, a0, 4
    vle8.v   v6, (t1)

    vwmaccsu.vv v2, v6, v4

    vsetivli t0, 4, e16, m1, ta, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x0038
    bne  t0, t2, fail_vwmaccsu_vv
    lhu  t0, 2(a1)
    li   t2, 0x0138
    bne  t0, t2, fail_vwmaccsu_vv
    lhu  t0, 4(a1)
    li   t2, 0x00fa
    bne  t0, t2, fail_vwmaccsu_vv
    lhu  t0, 6(a1)
    li   t2, 0xff38
    bne  t0, t2, fail_vwmaccsu_vv

    # vwmaccsu.vx with unsigned scalar rs1 = 20 (0x14)
    # vd initial: 0, 0, 0, 0
    # vs2 (v4, signed): -5 (0xfb), 10 (0x0a), -128 (0x80), 0
    # Products:         -100 (0xff9c), 200 (0x00c8), -2560 (0xf600), 0
    sw   zero, 0(a1)
    sw   zero, 4(a1)
    vsetivli t0, 4, e16, m1, ta, ma
    vle16.v  v2, (a1)

    li   t0, 0x00800afb
    sw   t0, 0(a0)
    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)

    li   a2, 20
    vwmaccsu.vx v2, a2, v4

    vsetivli t0, 4, e16, m1, ta, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0xff9c
    bne  t0, t2, fail_vwmaccsu_vx
    lhu  t0, 2(a1)
    li   t2, 0x00c8
    bne  t0, t2, fail_vwmaccsu_vx
    lhu  t0, 4(a1)
    li   t2, 0xf600
    bne  t0, t2, fail_vwmaccsu_vx
    lhu  t0, 6(a1)
    bnez t0, fail_vwmaccsu_vx

    # =========================================================================
    # Test 4: vwmaccus.vx (signed scalar rs1 * unsigned vs2)
    # rs1 (signed): -5
    # vs2 (unsigned): 200 (0xc8), 100 (0x64), 50 (0x32), 0
    # vd initial:     1000 (0x03e8), 500 (0x01f4), 0, 10 (0x000a)
    # Products:       -1000 (0xfc18), -500 (0xfe0c), -250 (0xff06), 0
    # Expected:       0, 0, -250 (0xff06), 10 (0x000a)
    # =========================================================================
    li   t0, 0x01f403e8
    sw   t0, 0(a1)
    li   t0, 0x000a0000
    sw   t0, 4(a1)
    vsetivli t0, 4, e16, m1, ta, ma
    vle16.v  v2, (a1)

    li   t0, 0x003264c8
    sw   t0, 0(a0)
    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v4, (a0)

    li   a2, -5
    vwmaccus.vx v2, a2, v4

    vsetivli t0, 4, e16, m1, ta, ma
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    bnez t0, fail_vwmaccus_vx
    lhu  t0, 2(a1)
    bnez t0, fail_vwmaccus_vx
    lhu  t0, 4(a1)
    li   t2, 0xff06
    bne  t0, t2, fail_vwmaccus_vx
    lhu  t0, 6(a1)
    li   t2, 0x000a
    bne  t0, t2, fail_vwmaccus_vx

    # =========================================================================
    # Test 5: e16 -> e32 widen macc (vwmaccu.vv, vwmacc.vv, vwmaccsu.vv)
    # =========================================================================
    # vwmaccu.vv e16 -> e32
    # vd initial: 0x00010000, 0x00020000
    # vs2 (v4):   0x1000,     0x0400
    # vs1 (v6):   0x0010,     0x0008
    # Products:   0x00010000, 0x00002000
    # Expected:   0x00020000, 0x00022000
    li   t0, 0x00010000
    sw   t0, 0(a1)
    li   t0, 0x00020000
    sw   t0, 4(a1)
    vsetivli t0, 2, e32, m1, ta, ma
    vle32.v  v2, (a1)

    li   t0, 0x04001000
    sw   t0, 0(a0)
    li   t0, 0x00080010
    sw   t0, 4(a0)

    vsetivli t0, 2, e16, m1, ta, ma
    vle16.v  v4, (a0)
    addi     t1, a0, 4
    vle16.v  v6, (t1)

    vwmaccu.vv v2, v6, v4

    vsetivli t0, 2, e32, m1, ta, ma
    vse32.v  v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x00020000
    bne  t0, t2, fail_vwmaccu_e16
    lwu  t0, 4(a1)
    li   t2, 0x00022000
    bne  t0, t2, fail_vwmaccu_e16

    # vwmacc.vv e16 -> e32 (signed)
    # vd initial: 0, 1000
    # vs2 (signed): -1000, 500
    # vs1 (signed): 20,    -10
    # Products:     -20000 (0xffffb1e0), -5000 (0xffffec78)
    # Expected:     -20000, -4000 (0xfffff060)
    sw   zero, 0(a1)
    li   t0, 1000
    sw   t0, 4(a1)
    vsetivli t0, 2, e32, m1, ta, ma
    vle32.v  v2, (a1)

    li   t0, -1000
    sh   t0, 0(a0)
    li   t0, 500
    sh   t0, 2(a0)
    li   t0, 20
    sh   t0, 4(a0)
    li   t0, -10
    sh   t0, 6(a0)

    vsetivli t0, 2, e16, m1, ta, ma
    vle16.v  v4, (a0)
    addi     t1, a0, 4
    vle16.v  v6, (t1)

    vwmacc.vv v2, v6, v4

    vsetivli t0, 2, e32, m1, ta, ma
    vse32.v  v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0xffffb1e0
    bne  t0, t2, fail_vwmacc_e16
    lwu  t0, 4(a1)
    li   t2, 0xfffff060
    bne  t0, t2, fail_vwmacc_e16

    # =========================================================================
    # Test 6: e32 -> e64 widen macc (vwmaccu.vv, vwmacc.vx)
    # =========================================================================
    # vwmaccu.vv e32 -> e64
    # vd initial: 0x100000000, 0x200000000
    # vs2:        0x80000000, 0x10000000
    # vs1:        2,          4
    # Products:   0x100000000, 0x40000000
    # Expected:   0x200000000, 0x240000000
    li   t0, 0x100000000
    sd   t0, 0(a1)
    li   t0, 0x200000000
    sd   t0, 8(a1)
    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v2, (a1)

    li   t0, 0x80000000
    sw   t0, 0(a0)
    li   t0, 0x10000000
    sw   t0, 4(a0)
    li   t0, 2
    sw   t0, 8(a0)
    li   t0, 4
    sw   t0, 12(a0)

    vsetivli t0, 2, e32, m1, ta, ma
    vle32.v  v4, (a0)
    addi     t1, a0, 8
    vle32.v  v6, (t1)

    vwmaccu.vv v2, v6, v4

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v2, (a1)

    ld   t0, 0(a1)
    li   t2, 0x200000000
    bne  t0, t2, fail_vwmaccu_e32
    ld   t0, 8(a1)
    li   t2, 0x240000000
    bne  t0, t2, fail_vwmaccu_e32

    # vwmacc.vx e32 -> e64 with signed scalar rs1 = -3
    # vd initial: 0, 0
    # vs2:        -1000000, 2000000
    # Products:   3000000, -6000000
    sd   zero, 0(a1)
    sd   zero, 8(a1)
    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v2, (a1)

    li   t0, -1000000
    sw   t0, 0(a0)
    li   t0, 2000000
    sw   t0, 4(a0)
    vsetivli t0, 2, e32, m1, ta, ma
    vle32.v  v4, (a0)

    li   a2, -3
    vwmacc.vx v2, a2, v4

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v2, (a1)

    ld   t0, 0(a1)
    li   t2, 3000000
    bne  t0, t2, fail_vwmacc_e32
    ld   t0, 8(a1)
    li   t2, -6000000
    bne  t0, t2, fail_vwmacc_e32

    # =========================================================================
    # Test 7: Masked execution with v0.t (e8 -> e16)
    # v0 mask: 0b1010 (elements 1 and 3 active, 0 and 2 masked off)
    # vd initial: 0x1111, 0x2222, 0x3333, 0x4444
    # vs2 (v4):   10,     20,     30,     40
    # rs1:        2
    # Products:   20,     40,     60,     80
    # Expected:   0x1111, 0x2222 + 40 = 0x224a, 0x3333, 0x4444 + 80 = 0x4494
    # =========================================================================
    li   t0, 0x22221111
    sw   t0, 0(a1)
    li   t0, 0x44443333
    sw   t0, 4(a1)
    vsetivli t0, 4, e16, m1, ta, mu
    vle16.v  v2, (a1)

    li   t0, 0x281e140a  # 40, 30, 20, 10
    sw   t0, 0(a0)
    vsetivli t0, 4, e8, m1, ta, mu
    vle8.v   v4, (a0)

    # v0 = 0b1010 (0x0a)
    li   t0, 0x0a
    sb   t0, 16(a0)
    addi t1, a0, 16
    vlm.v v0, (t1)

    li   a2, 2
    vwmaccu.vx v2, a2, v4, v0.t

    vsetivli t0, 4, e16, m1, ta, mu
    vse16.v  v2, (a1)

    lhu  t0, 0(a1)
    li   t2, 0x1111
    bne  t0, t2, fail_mask
    lhu  t0, 2(a1)
    li   t2, 0x224a
    bne  t0, t2, fail_mask
    lhu  t0, 4(a1)
    li   t2, 0x3333
    bne  t0, t2, fail_mask
    lhu  t0, 6(a1)
    li   t2, 0x4494
    bne  t0, t2, fail_mask

    # =========================================================================
    # Test 8: Register grouping across vd (v2) and vd+1 (v3)
    # e8 -> e16 with vl = 12 (8 elements in v2, 4 elements in v3)
    # vs2 (v4): 1..12
    # rs1 = 10
    # vd initial: 0
    # Expected: 10, 20, 30, 40, 50, 60, 70, 80 in v2; 90, 100, 110, 120 in v3
    # =========================================================================
    # Clear memory buffer for 16 halfwords
    addi t1, a1, 0
    sd   zero, 0(t1)
    sd   zero, 8(t1)
    sd   zero, 16(t1)
    sd   zero, 24(t1)

    # Clear v2 and v3
    vsetivli t0, 8, e16, m1, ta, ma
    vle16.v  v2, (a1)
    vle16.v  v3, (a1)

    # Setup vs2 with 12 bytes: 1..12
    li   t0, 0x04030201
    sw   t0, 0(a0)
    li   t0, 0x08070605
    sw   t0, 4(a0)
    li   t0, 0x0c0b0a09
    sw   t0, 8(a0)

    li   t0, 12
    vsetvli  t0, t0, e8, m1, ta, ma
    vle8.v   v4, (a0)

    li   a2, 10
    vwmaccu.vx v2, a2, v4

    # Store v2 (first 8 elements = 16 bytes)
    vsetivli t0, 8, e16, m1, ta, ma
    vse16.v  v2, (a1)
    # Store v3 (next 4 elements = 8 bytes)
    vsetivli t0, 4, e16, m1, ta, ma
    addi     t1, a1, 16
    vse16.v  v3, (t1)

    # Verify elements 0..7 from v2
    lhu  t0, 0(a1)
    li   t2, 10
    bne  t0, t2, fail_grouping
    lhu  t0, 2(a1)
    li   t2, 20
    bne  t0, t2, fail_grouping
    lhu  t0, 14(a1)
    li   t2, 80
    bne  t0, t2, fail_grouping

    # Verify elements 8..11 from v3
    lhu  t0, 16(a1)
    li   t2, 90
    bne  t0, t2, fail_grouping
    lhu  t0, 18(a1)
    li   t2, 100
    bne  t0, t2, fail_grouping
    lhu  t0, 20(a1)
    li   t2, 110
    bne  t0, t2, fail_grouping
    lhu  t0, 22(a1)
    li   t2, 120
    bne  t0, t2, fail_grouping

    # =========================================================================
    # All tests passed!
    # =========================================================================
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
pass_loop:
    j    pass_loop

fail_vwmaccu_vv:
    li   t0, 0xDEAD0001
    sd   t0, 0(s0)
fail_loop1:
    j    fail_loop1

fail_vwmaccu_vx:
    li   t0, 0xDEAD0002
    sd   t0, 0(s0)
fail_loop2:
    j    fail_loop2

fail_vwmacc_vv:
    li   t0, 0xDEAD0003
    sd   t0, 0(s0)
fail_loop3:
    j    fail_loop3

fail_vwmacc_vx:
    li   t0, 0xDEAD0004
    sd   t0, 0(s0)
fail_loop4:
    j    fail_loop4

fail_vwmaccsu_vv:
    li   t0, 0xDEAD0005
    sd   t0, 0(s0)
fail_loop5:
    j    fail_loop5

fail_vwmaccsu_vx:
    li   t0, 0xDEAD0006
    sd   t0, 0(s0)
fail_loop6:
    j    fail_loop6

fail_vwmaccus_vx:
    li   t0, 0xDEAD0007
    sd   t0, 0(s0)
fail_loop7:
    j    fail_loop7

fail_vwmaccu_e16:
    li   t0, 0xDEAD0008
    sd   t0, 0(s0)
fail_loop8:
    j    fail_loop8

fail_vwmacc_e16:
    li   t0, 0xDEAD0009
    sd   t0, 0(s0)
fail_loop9:
    j    fail_loop9

fail_vwmaccu_e32:
    li   t0, 0xDEAD000A
    sd   t0, 0(s0)
fail_loopA:
    j    fail_loopA

fail_vwmacc_e32:
    li   t0, 0xDEAD000B
    sd   t0, 0(s0)
fail_loopB:
    j    fail_loopB

fail_mask:
    li   t0, 0xDEAD000C
    sd   t0, 0(s0)
fail_loopC:
    j    fail_loopC

fail_grouping:
    li   t0, 0xDEAD000D
    sd   t0, 0(s0)
fail_loopD:
    j    fail_loopD
