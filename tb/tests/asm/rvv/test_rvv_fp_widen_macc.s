.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000200
    li   a1, 0x80000300
    li   a2, 0x80000400

    # -------------------------------------------------------------
    # 1. vfwmacc.vv: +(vs1 * vs2) + vd -> vd, vd+1
    # vs2 = [2.0, 3.0, -1.5, 4.0] (f32)
    # vs1 = [1.5, -2.0, 4.0, 2.5] (f32)
    # vd_in = [10.0, 20.0, 30.0, 40.0] (f64)
    # vd_out = [13.0, 14.0, 24.0, 50.0] (f64)
    # -------------------------------------------------------------
    li   t0, 0x40000000         # 2.0
    sw   t0, 0(a0)
    li   t0, 0x40400000         # 3.0
    sw   t0, 4(a0)
    li   t0, 0xbfc00000         # -1.5
    sw   t0, 8(a0)
    li   t0, 0x40800000         # 4.0
    sw   t0, 12(a0)

    li   t0, 0x3fc00000         # 1.5
    sw   t0, 0(a1)
    li   t0, 0xc0000000         # -2.0
    sw   t0, 4(a1)
    li   t0, 0x40800000         # 4.0
    sw   t0, 8(a1)
    li   t0, 0x40200000         # 2.5
    sw   t0, 12(a1)

    li   t0, 0x4024000000000000 # 10.0
    sd   t0, 0(a2)
    li   t0, 0x4034000000000000 # 20.0
    sd   t0, 8(a2)
    li   t0, 0x403e000000000000 # 30.0
    sd   t0, 16(a2)
    li   t0, 0x4044000000000000 # 40.0
    sd   t0, 24(a2)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a2)
    addi     t1, a2, 16
    vle64.v  v5, (t1)

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    vle32.v  v3, (a1)
    vfwmacc.vv v4, v3, v2

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    ld   t0, 0(a2)
    li   t2, 0x402a000000000000 # 13.0
    bne  t0, t2, fail_vfwmacc_vv
    ld   t0, 8(a2)
    li   t2, 0x402c000000000000 # 14.0
    bne  t0, t2, fail_vfwmacc_vv
    ld   t0, 16(a2)
    li   t2, 0x4038000000000000 # 24.0
    bne  t0, t2, fail_vfwmacc_vv
    ld   t0, 24(a2)
    li   t2, 0x4049000000000000 # 50.0
    bne  t0, t2, fail_vfwmacc_vv

    # -------------------------------------------------------------
    # 2. vfwmacc.vf: +(f[rs1] * vs2) + vd -> vd, vd+1
    # vs2 = [2.0, -3.0, 4.5, -5.0] (f32)
    # f[rs1] = 2.0 (f32)
    # vd_in = [5.0, 10.0, 15.0, 20.0] (f64)
    # vd_out = [9.0, 4.0, 24.0, 10.0] (f64)
    # -------------------------------------------------------------
    li   t0, 0x40000000         # 2.0
    sw   t0, 0(a0)
    li   t0, 0xc0400000         # -3.0
    sw   t0, 4(a0)
    li   t0, 0x40900000         # 4.5
    sw   t0, 8(a0)
    li   t0, 0xc0a00000         # -5.0
    sw   t0, 12(a0)

    li   t0, 0x4014000000000000 # 5.0
    sd   t0, 0(a2)
    li   t0, 0x4024000000000000 # 10.0
    sd   t0, 8(a2)
    li   t0, 0x402e000000000000 # 15.0
    sd   t0, 16(a2)
    li   t0, 0x4034000000000000 # 20.0
    sd   t0, 24(a2)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a2)
    addi     t1, a2, 16
    vle64.v  v5, (t1)

    li   t0, 0x40000000         # 2.0
    fmv.w.x fa0, t0

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    vfwmacc.vf v4, fa0, v2

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    ld   t0, 0(a2)
    li   t2, 0x4022000000000000 # 9.0
    bne  t0, t2, fail_vfwmacc_vf
    ld   t0, 8(a2)
    li   t2, 0x4010000000000000 # 4.0
    bne  t0, t2, fail_vfwmacc_vf
    ld   t0, 16(a2)
    li   t2, 0x4038000000000000 # 24.0
    bne  t0, t2, fail_vfwmacc_vf
    ld   t0, 24(a2)
    li   t2, 0x4024000000000000 # 10.0
    bne  t0, t2, fail_vfwmacc_vf

    # -------------------------------------------------------------
    # 3. vfwnmacc.vv: -(vs1 * vs2) - vd -> vd, vd+1
    # vs2 = [2.0, 4.0, 3.0, 5.0] (f32)
    # vs1 = [3.0, 2.0, -2.0, 1.0] (f32)
    # vd_in = [4.0, 2.0, 1.0, 5.0] (f64)
    # vd_out = [-10.0, -10.0, 5.0, -10.0] (f64)
    # -------------------------------------------------------------
    li   t0, 0x40000000         # 2.0
    sw   t0, 0(a0)
    li   t0, 0x40800000         # 4.0
    sw   t0, 4(a0)
    li   t0, 0x40400000         # 3.0
    sw   t0, 8(a0)
    li   t0, 0x40a00000         # 5.0
    sw   t0, 12(a0)

    li   t0, 0x40400000         # 3.0
    sw   t0, 0(a1)
    li   t0, 0x40000000         # 2.0
    sw   t0, 4(a1)
    li   t0, 0xc0000000         # -2.0
    sw   t0, 8(a1)
    li   t0, 0x3f800000         # 1.0
    sw   t0, 12(a1)

    li   t0, 0x4010000000000000 # 4.0
    sd   t0, 0(a2)
    li   t0, 0x4000000000000000 # 2.0
    sd   t0, 8(a2)
    li   t0, 0x3ff0000000000000 # 1.0
    sd   t0, 16(a2)
    li   t0, 0x4014000000000000 # 5.0
    sd   t0, 24(a2)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a2)
    addi     t1, a2, 16
    vle64.v  v5, (t1)

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    vle32.v  v3, (a1)
    vfwnmacc.vv v4, v3, v2

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    ld   t0, 0(a2)
    li   t2, 0xc024000000000000 # -10.0
    bne  t0, t2, fail_vfwnmacc_vv
    ld   t0, 8(a2)
    li   t2, 0xc024000000000000 # -10.0
    bne  t0, t2, fail_vfwnmacc_vv
    ld   t0, 16(a2)
    li   t2, 0x4014000000000000 # 5.0
    bne  t0, t2, fail_vfwnmacc_vv
    ld   t0, 24(a2)
    li   t2, 0xc024000000000000 # -10.0
    bne  t0, t2, fail_vfwnmacc_vv

    # -------------------------------------------------------------
    # 4. vfwnmacc.vf: -(f[rs1] * vs2) - vd -> vd, vd+1
    # vs2 = [3.0, -4.0, 2.0, 6.0] (f32)
    # f[rs1] = 2.0 (f32)
    # vd_in = [4.0, 2.0, 8.0, -2.0] (f64)
    # vd_out = [-10.0, 6.0, -12.0, -10.0] (f64)
    # -------------------------------------------------------------
    li   t0, 0x40400000         # 3.0
    sw   t0, 0(a0)
    li   t0, 0xc0800000         # -4.0
    sw   t0, 4(a0)
    li   t0, 0x40000000         # 2.0
    sw   t0, 8(a0)
    li   t0, 0x40c00000         # 6.0
    sw   t0, 12(a0)

    li   t0, 0x4010000000000000 # 4.0
    sd   t0, 0(a2)
    li   t0, 0x4000000000000000 # 2.0
    sd   t0, 8(a2)
    li   t0, 0x4020000000000000 # 8.0
    sd   t0, 16(a2)
    li   t0, 0xc000000000000000 # -2.0
    sd   t0, 24(a2)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a2)
    addi     t1, a2, 16
    vle64.v  v5, (t1)

    li   t0, 0x40000000         # 2.0
    fmv.w.x fa0, t0

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    vfwnmacc.vf v4, fa0, v2

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    ld   t0, 0(a2)
    li   t2, 0xc024000000000000 # -10.0
    bne  t0, t2, fail_vfwnmacc_vf
    ld   t0, 8(a2)
    li   t2, 0x4018000000000000 # 6.0
    bne  t0, t2, fail_vfwnmacc_vf
    ld   t0, 16(a2)
    li   t2, 0xc028000000000000 # -12.0
    bne  t0, t2, fail_vfwnmacc_vf
    ld   t0, 24(a2)
    li   t2, 0xc024000000000000 # -10.0
    bne  t0, t2, fail_vfwnmacc_vf

    # -------------------------------------------------------------
    # 5. vfwmsac.vv: +(vs1 * vs2) - vd -> vd, vd+1
    # vs2 = [4.0, 5.0, 6.0, 7.0] (f32)
    # vs1 = [3.0, 2.0, 2.0, 3.0] (f32)
    # vd_in = [2.0, 5.0, 4.0, 1.0] (f64)
    # vd_out = [10.0, 5.0, 8.0, 20.0] (f64)
    # -------------------------------------------------------------
    li   t0, 0x40800000         # 4.0
    sw   t0, 0(a0)
    li   t0, 0x40a00000         # 5.0
    sw   t0, 4(a0)
    li   t0, 0x40c00000         # 6.0
    sw   t0, 8(a0)
    li   t0, 0x40e00000         # 7.0
    sw   t0, 12(a0)

    li   t0, 0x40400000         # 3.0
    sw   t0, 0(a1)
    li   t0, 0x40000000         # 2.0
    sw   t0, 4(a1)
    li   t0, 0x40000000         # 2.0
    sw   t0, 8(a1)
    li   t0, 0x40400000         # 3.0
    sw   t0, 12(a1)

    li   t0, 0x4000000000000000 # 2.0
    sd   t0, 0(a2)
    li   t0, 0x4014000000000000 # 5.0
    sd   t0, 8(a2)
    li   t0, 0x4010000000000000 # 4.0
    sd   t0, 16(a2)
    li   t0, 0x3ff0000000000000 # 1.0
    sd   t0, 24(a2)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a2)
    addi     t1, a2, 16
    vle64.v  v5, (t1)

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    vle32.v  v3, (a1)
    vfwmsac.vv v4, v3, v2

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    ld   t0, 0(a2)
    li   t2, 0x4024000000000000 # 10.0
    bne  t0, t2, fail_vfwmsac_vv
    ld   t0, 8(a2)
    li   t2, 0x4014000000000000 # 5.0
    bne  t0, t2, fail_vfwmsac_vv
    ld   t0, 16(a2)
    li   t2, 0x4020000000000000 # 8.0
    bne  t0, t2, fail_vfwmsac_vv
    ld   t0, 24(a2)
    li   t2, 0x4034000000000000 # 20.0
    bne  t0, t2, fail_vfwmsac_vv

    # -------------------------------------------------------------
    # 6. vfwmsac.vf: +(f[rs1] * vs2) - vd -> vd, vd+1
    # vs2 = [4.0, 6.0, 8.0, 10.0] (f32)
    # f[rs1] = 2.5 (f32)
    # vd_in = [2.0, 5.0, 4.0, 5.0] (f64)
    # vd_out = [8.0, 10.0, 16.0, 20.0] (f64)
    # -------------------------------------------------------------
    li   t0, 0x40800000         # 4.0
    sw   t0, 0(a0)
    li   t0, 0x40c00000         # 6.0
    sw   t0, 4(a0)
    li   t0, 0x41000000         # 8.0
    sw   t0, 8(a0)
    li   t0, 0x41200000         # 10.0
    sw   t0, 12(a0)

    li   t0, 0x4000000000000000 # 2.0
    sd   t0, 0(a2)
    li   t0, 0x4014000000000000 # 5.0
    sd   t0, 8(a2)
    li   t0, 0x4010000000000000 # 4.0
    sd   t0, 16(a2)
    li   t0, 0x4014000000000000 # 5.0
    sd   t0, 24(a2)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a2)
    addi     t1, a2, 16
    vle64.v  v5, (t1)

    li   t0, 0x40200000         # 2.5
    fmv.w.x fa0, t0

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    vfwmsac.vf v4, fa0, v2

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    ld   t0, 0(a2)
    li   t2, 0x4020000000000000 # 8.0
    bne  t0, t2, fail_vfwmsac_vf
    ld   t0, 8(a2)
    li   t2, 0x4024000000000000 # 10.0
    bne  t0, t2, fail_vfwmsac_vf
    ld   t0, 16(a2)
    li   t2, 0x4030000000000000 # 16.0
    bne  t0, t2, fail_vfwmsac_vf
    ld   t0, 24(a2)
    li   t2, 0x4034000000000000 # 20.0
    bne  t0, t2, fail_vfwmsac_vf

    # -------------------------------------------------------------
    # 7. vfwnmsac.vv: -(vs1 * vs2) + vd -> vd, vd+1
    # vs2 = [2.0, 3.0, 4.0, 5.0] (f32)
    # vs1 = [1.5, 2.0, 2.5, 3.0] (f32)
    # vd_in = [10.0, 12.0, 15.0, 20.0] (f64)
    # vd_out = [7.0, 6.0, 5.0, 5.0] (f64)
    # -------------------------------------------------------------
    li   t0, 0x40000000         # 2.0
    sw   t0, 0(a0)
    li   t0, 0x40400000         # 3.0
    sw   t0, 4(a0)
    li   t0, 0x40800000         # 4.0
    sw   t0, 8(a0)
    li   t0, 0x40a00000         # 5.0
    sw   t0, 12(a0)

    li   t0, 0x3fc00000         # 1.5
    sw   t0, 0(a1)
    li   t0, 0x40000000         # 2.0
    sw   t0, 4(a1)
    li   t0, 0x40200000         # 2.5
    sw   t0, 8(a1)
    li   t0, 0x40400000         # 3.0
    sw   t0, 12(a1)

    li   t0, 0x4024000000000000 # 10.0
    sd   t0, 0(a2)
    li   t0, 0x4028000000000000 # 12.0
    sd   t0, 8(a2)
    li   t0, 0x402e000000000000 # 15.0
    sd   t0, 16(a2)
    li   t0, 0x4034000000000000 # 20.0
    sd   t0, 24(a2)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a2)
    addi     t1, a2, 16
    vle64.v  v5, (t1)

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    vle32.v  v3, (a1)
    vfwnmsac.vv v4, v3, v2

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    ld   t0, 0(a2)
    li   t2, 0x401c000000000000 # 7.0
    bne  t0, t2, fail_vfwnmsac_vv
    ld   t0, 8(a2)
    li   t2, 0x4018000000000000 # 6.0
    bne  t0, t2, fail_vfwnmsac_vv
    ld   t0, 16(a2)
    li   t2, 0x4014000000000000 # 5.0
    bne  t0, t2, fail_vfwnmsac_vv
    ld   t0, 24(a2)
    li   t2, 0x4014000000000000 # 5.0
    bne  t0, t2, fail_vfwnmsac_vv

    # -------------------------------------------------------------
    # 8. vfwnmsac.vf: -(f[rs1] * vs2) + vd -> vd, vd+1
    # vs2 = [2.0, 4.0, 6.0, 8.0] (f32)
    # f[rs1] = 1.5 (f32)
    # vd_in = [10.0, 10.0, 15.0, 20.0] (f64)
    # vd_out = [7.0, 4.0, 6.0, 8.0] (f64)
    # -------------------------------------------------------------
    li   t0, 0x40000000         # 2.0
    sw   t0, 0(a0)
    li   t0, 0x40800000         # 4.0
    sw   t0, 4(a0)
    li   t0, 0x40c00000         # 6.0
    sw   t0, 8(a0)
    li   t0, 0x41000000         # 8.0
    sw   t0, 12(a0)

    li   t0, 0x4024000000000000 # 10.0
    sd   t0, 0(a2)
    li   t0, 0x4024000000000000 # 10.0
    sd   t0, 8(a2)
    li   t0, 0x402e000000000000 # 15.0
    sd   t0, 16(a2)
    li   t0, 0x4034000000000000 # 20.0
    sd   t0, 24(a2)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a2)
    addi     t1, a2, 16
    vle64.v  v5, (t1)

    li   t0, 0x3fc00000         # 1.5
    fmv.w.x fa0, t0

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)
    vfwnmsac.vf v4, fa0, v2

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    ld   t0, 0(a2)
    li   t2, 0x401c000000000000 # 7.0
    bne  t0, t2, fail_vfwnmsac_vf
    ld   t0, 8(a2)
    li   t2, 0x4010000000000000 # 4.0
    bne  t0, t2, fail_vfwnmsac_vf
    ld   t0, 16(a2)
    li   t2, 0x4018000000000000 # 6.0
    bne  t0, t2, fail_vfwnmsac_vf
    ld   t0, 24(a2)
    li   t2, 0x4020000000000000 # 8.0
    bne  t0, t2, fail_vfwnmsac_vf

    # -------------------------------------------------------------
    # 9. Masked operation & tail-agnostic:
    # v0 mask = 0b1011 (elements 0, 1, 3 active, element 2 masked out)
    # vl = 3 (element 3 is tail)
    # vta=1 (tail agnostic -> 1s in tail), vma=1 (mask agnostic -> 1s in masked)
    # -------------------------------------------------------------
    li   t0, 0x0b               # mask: active lanes 0, 1, 3
    sw   t0, 0(a0)
    vsetivli t0, 4, e8, m1, ta, ma
    vle8.v   v0, (a0)

    # Initial vd: all 0s
    li   t0, 0
    sd   t0, 0(a2)
    sd   t0, 8(a2)
    sd   t0, 16(a2)
    sd   t0, 24(a2)
    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v  v4, (a2)
    addi     t1, a2, 16
    vle64.v  v5, (t1)

    # Operands: vs2 = [2.0, 2.0, 2.0, 2.0], vs1 = [3.0, 3.0, 3.0, 3.0]
    li   t0, 0x40000000         # 2.0
    sw   t0, 0(a0)
    sw   t0, 4(a0)
    sw   t0, 8(a0)
    sw   t0, 12(a0)
    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v  v2, (a0)

    li   t0, 0x40400000         # 3.0
    sw   t0, 0(a1)
    sw   t0, 4(a1)
    sw   t0, 8(a1)
    sw   t0, 12(a1)
    vle32.v  v3, (a1)

    # Run vfwmacc.vv with vl=3, v0.t mask, ta, ma
    vsetivli t0, 3, e32, m1, ta, ma
    vfwmacc.vv v4, v3, v2, v0.t

    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v  v4, (a2)
    addi     t1, a2, 16
    vse64.v  v5, (t1)

    # Lane 0: (3.0 * 2.0) + 0.0 = 6.0
    ld   t0, 0(a2)
    li   t2, 0x4018000000000000
    bne  t0, t2, fail_mask
    # Lane 1: (3.0 * 2.0) + 0.0 = 6.0
    ld   t0, 8(a2)
    li   t2, 0x4018000000000000
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

fail_vfwmacc_vv:
    li   t0, 0xDEAD0001
    sw   t0, 0(s0)
2:  j    2b

fail_vfwmacc_vf:
    li   t0, 0xDEAD0002
    sw   t0, 0(s0)
3:  j    3b

fail_vfwnmacc_vv:
    li   t0, 0xDEAD0003
    sw   t0, 0(s0)
4:  j    4b

fail_vfwnmacc_vf:
    li   t0, 0xDEAD0004
    sw   t0, 0(s0)
5:  j    5b

fail_vfwmsac_vv:
    li   t0, 0xDEAD0005
    sw   t0, 0(s0)
6:  j    6b

fail_vfwmsac_vf:
    li   t0, 0xDEAD0006
    sw   t0, 0(s0)
7:  j    7b

fail_vfwnmsac_vv:
    li   t0, 0xDEAD0007
    sw   t0, 0(s0)
8:  j    8b

fail_vfwnmsac_vf:
    li   t0, 0xDEAD0008
    sw   t0, 0(s0)
9:  j    9b

fail_mask:
    li   t0, 0xDEAD0009
    sw   t0, 0(s0)
10: j    10b
