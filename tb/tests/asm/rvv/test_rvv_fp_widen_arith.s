.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000200
    li   a1, 0x80000300
    li   a2, 0x80000400

    # -------------------------------------------------------------
    # 1. vfwadd.vv: vs2 + vs1 -> vd, vd+1
    # vs2 = [1.5, 2.5, -4.0, 8.25]
    # vs1 = [0.5, -1.0, 2.0, 1.75]
    # vd  = [2.0, 1.5, -2.0, 10.0] (double precision)
    # -------------------------------------------------------------
    li   t0, 0x3fc00000         # 1.5
    sw   t0, 0(a0)
    li   t0, 0x40200000         # 2.5
    sw   t0, 4(a0)
    li   t0, 0xc0800000         # -4.0
    sw   t0, 8(a0)
    li   t0, 0x41040000         # 8.25
    sw   t0, 12(a0)

    li   t0, 0x3f000000         # 0.5
    sw   t0, 0(a1)
    li   t0, 0xbf800000         # -1.0
    sw   t0, 4(a1)
    li   t0, 0x40000000         # 2.0
    sw   t0, 8(a1)
    li   t0, 0x3fe00000         # 1.75
    sw   t0, 12(a1)

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    vle32.v  v3, (a1)
    vfwadd.vv v4, v2, v3

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    ld   t0, 0(a2)
    li   t2, 0x4000000000000000 # 2.0
    bne  t0, t2, fail_vfwadd_vv
    ld   t0, 8(a2)
    li   t2, 0x3ff8000000000000 # 1.5
    bne  t0, t2, fail_vfwadd_vv
    ld   t0, 16(a2)
    li   t2, 0xc000000000000000 # -2.0
    bne  t0, t2, fail_vfwadd_vv
    ld   t0, 24(a2)
    li   t2, 0x4024000000000000 # 10.0
    bne  t0, t2, fail_vfwadd_vv

    # -------------------------------------------------------------
    # 2. vfwadd.vf: vs2 + f[rs1] -> vd, vd+1
    # vs2 = [1.5, 2.5, -4.0, 8.0]
    # f[rs1] = 2.0
    # vd  = [3.5, 4.5, -2.0, 10.0] (double precision)
    # -------------------------------------------------------------
    li   t0, 0x41000000         # 8.0
    sw   t0, 12(a0)
    li   t0, 0x40000000         # 2.0
    fmv.w.x fa0, t0

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    vfwadd.vf v4, v2, fa0

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    ld   t0, 0(a2)
    li   t2, 0x400c000000000000 # 3.5
    bne  t0, t2, fail_vfwadd_vf
    ld   t0, 8(a2)
    li   t2, 0x4012000000000000 # 4.5
    bne  t0, t2, fail_vfwadd_vf
    ld   t0, 16(a2)
    li   t2, 0xc000000000000000 # -2.0
    bne  t0, t2, fail_vfwadd_vf
    ld   t0, 24(a2)
    li   t2, 0x4024000000000000 # 10.0
    bne  t0, t2, fail_vfwadd_vf

    # -------------------------------------------------------------
    # 3. vfwsub.vv: vs2 - vs1 -> vd, vd+1
    # vs2 = [3.5, 4.5, -2.0, 10.0] (e32)
    # vs1 = [1.5, 2.0, 3.0, 4.0] (e32)
    # vd  = [2.0, 2.5, -5.0, 6.0] (double precision)
    # -------------------------------------------------------------
    li   t0, 0x40600000         # 3.5
    sw   t0, 0(a0)
    li   t0, 0x40900000         # 4.5
    sw   t0, 4(a0)
    li   t0, 0xc0000000         # -2.0
    sw   t0, 8(a0)
    li   t0, 0x41200000         # 10.0
    sw   t0, 12(a0)

    li   t0, 0x3fc00000         # 1.5
    sw   t0, 0(a1)
    li   t0, 0x40000000         # 2.0
    sw   t0, 4(a1)
    li   t0, 0x40400000         # 3.0
    sw   t0, 8(a1)
    li   t0, 0x40800000         # 4.0
    sw   t0, 12(a1)

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    vle32.v  v3, (a1)
    vfwsub.vv v4, v2, v3

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    ld   t0, 0(a2)
    li   t2, 0x4000000000000000 # 2.0
    bne  t0, t2, fail_vfwsub_vv
    ld   t0, 8(a2)
    li   t2, 0x4004000000000000 # 2.5
    bne  t0, t2, fail_vfwsub_vv
    ld   t0, 16(a2)
    li   t2, 0xc014000000000000 # -5.0
    bne  t0, t2, fail_vfwsub_vv
    ld   t0, 24(a2)
    li   t2, 0x4018000000000000 # 6.0
    bne  t0, t2, fail_vfwsub_vv

    # -------------------------------------------------------------
    # 4. vfwsub.vf: vs2 - f[rs1] -> vd, vd+1
    # vs2 = [5.0, 7.5, 2.0, -3.0] (e32)
    # f[rs1] = 1.5
    # vd  = [3.5, 6.0, 0.5, -4.5] (double precision)
    # -------------------------------------------------------------
    li   t0, 0x40a00000         # 5.0
    sw   t0, 0(a0)
    li   t0, 0x40f00000         # 7.5
    sw   t0, 4(a0)
    li   t0, 0x40000000         # 2.0
    sw   t0, 8(a0)
    li   t0, 0xc0400000         # -3.0
    sw   t0, 12(a0)

    li   t0, 0x3fc00000         # 1.5
    fmv.w.x fa0, t0

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    vfwsub.vf v4, v2, fa0

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    ld   t0, 0(a2)
    li   t2, 0x400c000000000000 # 3.5
    bne  t0, t2, fail_vfwsub_vf
    ld   t0, 8(a2)
    li   t2, 0x4018000000000000 # 6.0
    bne  t0, t2, fail_vfwsub_vf
    ld   t0, 16(a2)
    li   t2, 0x3fe0000000000000 # 0.5
    bne  t0, t2, fail_vfwsub_vf
    ld   t0, 24(a2)
    li   t2, 0xc012000000000000 # -4.5
    bne  t0, t2, fail_vfwsub_vf

    # -------------------------------------------------------------
    # 5. vfwadd.wv: vs2 (wide) + vs1 (single) -> vd, vd+1
    # vs2 = [10.0, 20.0, 30.0, 40.0] (double in v4, v5)
    # vs1 = [1.5, 2.5, 3.5, 4.5] (single in v2)
    # vd  = [11.5, 22.5, 33.5, 44.5] (double in v6, v7)
    # -------------------------------------------------------------
    li   t0, 0x4024000000000000 # 10.0
    sd   t0, 0(a0)
    li   t0, 0x4034000000000000 # 20.0
    sd   t0, 8(a0)
    li   t0, 0x403e000000000000 # 30.0
    sd   t0, 16(a0)
    li   t0, 0x4044000000000000 # 40.0
    sd   t0, 24(a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a0)
    addi     t1, a0, 16
    vle64.v  v5, (t1)

    li   t0, 0x3fc00000         # 1.5
    sw   t0, 0(a1)
    li   t0, 0x40200000         # 2.5
    sw   t0, 4(a1)
    li   t0, 0x40600000         # 3.5
    sw   t0, 8(a1)
    li   t0, 0x40900000         # 4.5
    sw   t0, 12(a1)

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a1)
    vfwadd.wv v6, v4, v2

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v6, (a2)
    addi     t1, a2, 16
    vse64.v  v7, (t1)

    ld   t0, 0(a2)
    li   t2, 0x4027000000000000 # 11.5
    bne  t0, t2, fail_vfwadd_wv
    ld   t0, 8(a2)
    li   t2, 0x4036800000000000 # 22.5
    bne  t0, t2, fail_vfwadd_wv
    ld   t0, 16(a2)
    li   t2, 0x4040c00000000000 # 33.5
    bne  t0, t2, fail_vfwadd_wv
    ld   t0, 24(a2)
    li   t2, 0x4046400000000000 # 44.5
    bne  t0, t2, fail_vfwadd_wv

    # -------------------------------------------------------------
    # 6. vfwadd.wf: vs2 (wide) + f[rs1] (single) -> vd, vd+1
    # vs2 = [10.0, 20.0, 30.0, 40.0] (double in v4, v5)
    # f[rs1] = 2.5 (single)
    # vd  = [12.5, 22.5, 32.5, 42.5] (double in v6, v7)
    # -------------------------------------------------------------
    li   t0, 0x40200000         # 2.5
    fmv.w.x fa0, t0

    vsetivli t0, 4, e32, m1, ta, ma
    vfwadd.wf v6, v4, fa0

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v6, (a2)
    addi     t1, a2, 16
    vse64.v  v7, (t1)

    ld   t0, 0(a2)
    li   t2, 0x4029000000000000 # 12.5
    bne  t0, t2, fail_vfwadd_wf
    ld   t0, 8(a2)
    li   t2, 0x4036800000000000 # 22.5
    bne  t0, t2, fail_vfwadd_wf
    ld   t0, 16(a2)
    li   t2, 0x4040400000000000 # 32.5
    bne  t0, t2, fail_vfwadd_wf
    ld   t0, 24(a2)
    li   t2, 0x4045400000000000 # 42.5
    bne  t0, t2, fail_vfwadd_wf

    # -------------------------------------------------------------
    # 7. vfwsub.wv: vs2 (wide) - vs1 (single) -> vd, vd+1
    # vs2 = [15.0, 25.0, 35.0, 45.0] (double in v4, v5)
    # vs1 = [1.0, 2.0, 3.0, 4.0] (single in v2)
    # vd  = [14.0, 23.0, 32.0, 41.0] (double in v6, v7)
    # -------------------------------------------------------------
    li   t0, 0x402e000000000000 # 15.0
    sd   t0, 0(a0)
    li   t0, 0x4039000000000000 # 25.0
    sd   t0, 8(a0)
    li   t0, 0x4041800000000000 # 35.0
    sd   t0, 16(a0)
    li   t0, 0x4046800000000000 # 45.0
    sd   t0, 24(a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a0)
    addi     t1, a0, 16
    vle64.v  v5, (t1)

    li   t0, 0x3f800000         # 1.0
    sw   t0, 0(a1)
    li   t0, 0x40000000         # 2.0
    sw   t0, 4(a1)
    li   t0, 0x40400000         # 3.0
    sw   t0, 8(a1)
    li   t0, 0x40800000         # 4.0
    sw   t0, 12(a1)

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a1)
    vfwsub.wv v6, v4, v2

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v6, (a2)
    addi     t1, a2, 16
    vse64.v  v7, (t1)

    ld   t0, 0(a2)
    li   t2, 0x402c000000000000 # 14.0
    bne  t0, t2, fail_vfwsub_wv
    ld   t0, 8(a2)
    li   t2, 0x4037000000000000 # 23.0
    bne  t0, t2, fail_vfwsub_wv
    ld   t0, 16(a2)
    li   t2, 0x4040000000000000 # 32.0
    bne  t0, t2, fail_vfwsub_wv
    ld   t0, 24(a2)
    li   t2, 0x4044800000000000 # 41.0
    bne  t0, t2, fail_vfwsub_wv

    # -------------------------------------------------------------
    # 8. vfwsub.wf: vs2 (wide) - f[rs1] (single) -> vd, vd+1
    # vs2 = [15.0, 25.0, 35.0, 45.0] (double in v4, v5)
    # f[rs1] = 5.0 (single)
    # vd  = [10.0, 20.0, 30.0, 40.0] (double in v6, v7)
    # -------------------------------------------------------------
    li   t0, 0x40a00000         # 5.0
    fmv.w.x fa0, t0

    vsetivli t0, 4, e32, m1, ta, ma
    vfwsub.wf v6, v4, fa0

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v6, (a2)
    addi     t1, a2, 16
    vse64.v  v7, (t1)

    ld   t0, 0(a2)
    li   t2, 0x4024000000000000 # 10.0
    bne  t0, t2, fail_vfwsub_wf
    ld   t0, 8(a2)
    li   t2, 0x4034000000000000 # 20.0
    bne  t0, t2, fail_vfwsub_wf
    ld   t0, 16(a2)
    li   t2, 0x403e000000000000 # 30.0
    bne  t0, t2, fail_vfwsub_wf
    ld   t0, 24(a2)
    li   t2, 0x4044000000000000 # 40.0
    bne  t0, t2, fail_vfwsub_wf

    # -------------------------------------------------------------
    # 9. vfwmul.vv: vs2 * vs1 -> vd, vd+1
    # vs2 = [1.5, -2.0, 3.0, 0.5] (single)
    # vs1 = [2.0, 3.0, -4.0, 8.0] (single)
    # vd  = [3.0, -6.0, -12.0, 4.0] (double precision)
    # -------------------------------------------------------------
    li   t0, 0x3fc00000         # 1.5
    sw   t0, 0(a0)
    li   t0, 0xc0000000         # -2.0
    sw   t0, 4(a0)
    li   t0, 0x40400000         # 3.0
    sw   t0, 8(a0)
    li   t0, 0x3f000000         # 0.5
    sw   t0, 12(a0)

    li   t0, 0x40000000         # 2.0
    sw   t0, 0(a1)
    li   t0, 0x40400000         # 3.0
    sw   t0, 4(a1)
    li   t0, 0xc0800000         # -4.0
    sw   t0, 8(a1)
    li   t0, 0x41000000         # 8.0
    sw   t0, 12(a1)

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    vle32.v  v3, (a1)
    vfwmul.vv v4, v2, v3

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    ld   t0, 0(a2)
    li   t2, 0x4008000000000000 # 3.0
    bne  t0, t2, fail_vfwmul_vv
    ld   t0, 8(a2)
    li   t2, 0xc018000000000000 # -6.0
    bne  t0, t2, fail_vfwmul_vv
    ld   t0, 16(a2)
    li   t2, 0xc028000000000000 # -12.0
    bne  t0, t2, fail_vfwmul_vv
    ld   t0, 24(a2)
    li   t2, 0x4010000000000000 # 4.0
    bne  t0, t2, fail_vfwmul_vv

    # -------------------------------------------------------------
    # 10. vfwmul.vf: vs2 * f[rs1] -> vd, vd+1
    # vs2 = [2.0, -3.5, 4.0, 1.25] (single)
    # f[rs1] = -2.0 (single)
    # vd  = [-4.0, 7.0, -8.0, -2.5] (double precision)
    # -------------------------------------------------------------
    li   t0, 0x40000000         # 2.0
    sw   t0, 0(a0)
    li   t0, 0xc0600000         # -3.5
    sw   t0, 4(a0)
    li   t0, 0x40800000         # 4.0
    sw   t0, 8(a0)
    li   t0, 0x3fa00000         # 1.25
    sw   t0, 12(a0)

    li   t0, 0xc0000000         # -2.0
    fmv.w.x fa0, t0

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    vfwmul.vf v4, v2, fa0

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    ld   t0, 0(a2)
    li   t2, 0xc010000000000000 # -4.0
    bne  t0, t2, fail_vfwmul_vf
    ld   t0, 8(a2)
    li   t2, 0x401c000000000000 # 7.0
    bne  t0, t2, fail_vfwmul_vf
    ld   t0, 16(a2)
    li   t2, 0xc020000000000000 # -8.0
    bne  t0, t2, fail_vfwmul_vf
    ld   t0, 24(a2)
    li   t2, 0xc004000000000000 # -2.5
    bne  t0, t2, fail_vfwmul_vf

    # -------------------------------------------------------------
    # 11. Masked operation & tail-agnostic:
    # v0 mask = 0b1011 (elements 0, 1, 3 active, element 2 masked out)
    # vl = 3 (element 3 is tail)
    # vta=1 (tail agnostic -> 1s in tail), vma=1 (mask agnostic -> 1s in masked)
    # -------------------------------------------------------------
    li   t0, 0x0b               # mask: active lanes 0, 1, 3
    sw   t0, 0(a0)
    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v0, (a0)

    # Precharge destination registers with 0
    li   t0, 0
    sd   t0, 0(a2)
    sd   t0, 8(a2)
    sd   t0, 16(a2)
    sd   t0, 24(a2)
    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a2)
    addi     t1, a2, 16
    vle64.v  v5, (t1)

    # Operands: vs2 = [1.0, 2.0, 3.0, 4.0], vs1 = [1.0, 1.0, 1.0, 1.0]
    li   t0, 0x3f800000         # 1.0
    sw   t0, 0(a0)
    sw   t0, 4(a0)
    sw   t0, 8(a0)
    sw   t0, 12(a0)
    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    li   t0, 0x40000000         # 2.0
    sw   t0, 4(a0)
    li   t0, 0x40400000         # 3.0
    sw   t0, 8(a0)
    li   t0, 0x40800000         # 4.0
    sw   t0, 12(a0)
    vle32.v  v3, (a0)

    # Run vfwadd.vv with vl=3, v0.t mask, ta, ma
    vsetivli t0, 3, e32, m1, ta, ma
    vfwadd.vv v4, v3, v2, v0.t

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    # Lane 0: 1.0 + 1.0 = 2.0
    ld   t0, 0(a2)
    li   t2, 0x4000000000000000
    bne  t0, t2, fail_mask
    # Lane 1: 2.0 + 1.0 = 3.0
    ld   t0, 8(a2)
    li   t2, 0x4008000000000000
    bne  t0, t2, fail_mask
    # Lane 2: masked off with vma -> all 1s
    ld   t0, 16(a2)
    li   t2, -1
    bne  t0, t2, fail_mask
    # Lane 3: tail with vta -> all 1s
    ld   t0, 24(a2)
    li   t2, -1
    bne  t0, t2, fail_mask

    # Test Passed
    li   t0, 0xCAFEBABE
    sw   t0, 0(s0)
1:  j    1b

fail_vfwadd_vv:
    li   t0, 0xDEAD0001
    sw   t0, 0(s0)
2:  j    2b

fail_vfwadd_vf:
    li   t0, 0xDEAD0002
    sw   t0, 0(s0)
3:  j    3b

fail_vfwsub_vv:
    li   t0, 0xDEAD0003
    sw   t0, 0(s0)
4:  j    4b

fail_vfwsub_vf:
    li   t0, 0xDEAD0004
    sw   t0, 0(s0)
5:  j    5b

fail_vfwadd_wv:
    li   t0, 0xDEAD0005
    sw   t0, 0(s0)
6:  j    6b

fail_vfwadd_wf:
    li   t0, 0xDEAD0006
    sw   t0, 0(s0)
7:  j    7b

fail_vfwsub_wv:
    li   t0, 0xDEAD0007
    sw   t0, 0(s0)
8:  j    8b

fail_vfwsub_wf:
    li   t0, 0xDEAD0008
    sw   t0, 0(s0)
9:  j    9b

fail_vfwmul_vv:
    li   t0, 0xDEAD0009
    sw   t0, 0(s0)
10: j    10b

fail_vfwmul_vf:
    li   t0, 0xDEAD000A
    sw   t0, 0(s0)
11: j    11b

fail_mask:
    li   t0, 0xDEAD000B
    sw   t0, 0(s0)
12: j    12b
