.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    vsetvli t0, zero, e32, m1, ta, ma
    li   t1, 4
    bne  t0, t1, fail

    li   a0, 3
    li   a1, 4
    vmv.v.x v1, a0
    vmv.v.x v2, a1
    vadd.vv v3, v1, v2
    vmv.x.s a2, v3
    li   t1, 7
    bne  a2, t1, fail

    li   a0, 42
    vmv.v.x v3, a0
    li   a0, 0
    vmv.v.x v0, a0
    vadd.vv v3, v1, v2, v0.t
    vmv.x.s a2, v3
    li   t1, 42
    bne  a2, t1, fail
    li   a0, 1
    vmv.v.x v0, a0
    vadd.vv v3, v1, v2, v0.t
    vmv.x.s a2, v3
    li   t1, 7
    bne  a2, t1, fail

    li   a0, 2
    vadd.vx v3, v3, a0
    vmv.x.s a2, v3
    li   t1, 9
    bne  a2, t1, fail

    vsub.vv v4, v3, v2
    vmv.x.s a2, v4
    li   t1, 5
    bne  a2, t1, fail

    vand.vv v4, v3, v2
    vmv.x.s a2, v4
    li   t1, 0
    bne  a2, t1, fail

    vxor.vx v4, v3, a0
    vmv.x.s a2, v4
    li   t1, 11
    bne  a2, t1, fail

    li   a0, 3
    vmv.v.x v1, a0
    li   a1, 2
    vsll.vx v4, v1, a1
    vmv.x.s a2, v4
    li   t1, 12
    bne  a2, t1, fail
    vmv.v.x v2, a1
    vsll.vv v4, v1, v2
    vmv.x.s a2, v4
    li   t1, 12
    bne  a2, t1, fail
    vadd.vi v4, v1, 5
    vmv.x.s a2, v4
    li   t1, 8
    bne  a2, t1, fail
    vxor.vi v4, v1, -1
    vmv.x.s a2, v4
    li   t1, -4
    bne  a2, t1, fail
    vsll.vi v4, v1, 2
    vmv.x.s a2, v4
    li   t1, 12
    bne  a2, t1, fail

    li   a0, 0x80000000
    vmv.v.x v1, a0
    li   a1, 1
    vsrl.vx v4, v1, a1
    vmv.x.s a2, v4
    li   t1, 0x40000000
    bne  a2, t1, fail

    li   a0, -16
    vmv.v.x v1, a0
    li   a1, 2
    vsra.vx v4, v1, a1
    vmv.x.s a2, v4
    li   t1, -4
    bne  a2, t1, fail

    li   a0, 3
    vmv.v.x v1, a0
    li   a1, 3
    vmseq.vx v5, v1, a1
    vmv.x.s a2, v5
    li   t1, 15
    bne  a2, t1, fail
    li   a1, 4
    vmslt.vx v5, v1, a1
    vmv.x.s a2, v5
    bne  a2, t1, fail
    li   a1, 2
    vmv.v.x v2, a1
    vmsltu.vv v5, v1, v2
    vmv.x.s a2, v5
    li   t1, 0
    bne  a2, t1, fail

    li   a0, -1
    vmv.v.x v1, a0
    li   a1, 1
    vminu.vx v5, v1, a1
    vmv.x.s a2, v5
    bne  a2, a1, fail
    vmaxu.vx v5, v1, a1
    vmv.x.s a2, v5
    li   t1, -1
    bne  a2, t1, fail
    vmin.vx v5, v1, a1
    vmv.x.s a2, v5
    bne  a2, t1, fail
    vmax.vx v5, v1, a1
    vmv.x.s a2, v5
    bne  a2, a1, fail

    vsetvli t0, zero, e8, m1, ta, ma
    li   t1, 16
    bne  t0, t1, fail
    li   t1, 5
    vsetvli t0, t1, e8, m1, ta, ma
    bne  t0, t1, fail
    li   t1, 0
    vsetvli t0, t1, e8, m1, ta, ma
    bne  t0, t1, fail
    vsetivli t0, 5, e8, m1, ta, ma
    li   t1, 5
    bne  t0, t1, fail
    vsetvli t0, zero, e8, m1, ta, ma
    li   t1, 16
    bne  t0, t1, fail
    li   a0, 0x123
    vmv.v.x v6, a0
    vmv.x.s a2, v6
    li   t1, 0x23
    bne  a2, t1, fail
    li   a0, 250
    vmv.v.x v1, a0
    li   a1, 10
    vmv.v.x v2, a1
    vadd.vv v3, v1, v2
    vmv.x.s a2, v3
    li   t1, 4
    bne  a2, t1, fail
    vsub.vv v3, v2, v1
    vmv.x.s a2, v3
    li   t1, 16
    bne  a2, t1, fail
    li   a0, 0xf0
    vmv.v.x v1, a0
    li   a1, 0x3c
    vmv.v.x v2, a1
    vand.vv v3, v1, v2
    vmv.x.s a2, v3
    li   t1, 0x30
    bne  a2, t1, fail
    li   a0, 0x81
    vmv.v.x v1, a0
    vsrl.vi v3, v1, 1
    vmv.x.s a2, v3
    li   t1, 0x40
    bne  a2, t1, fail
    li   a0, 1
    vmv.v.x v1, a0
    li   a1, 2
    vmsltu.vx v5, v1, a1
    vmv.x.s a2, v5
    li   t1, -1
    bne  a2, t1, fail
    li   a0, 0x80
    vmv.v.x v1, a0
    li   a1, 1
    vmin.vx v3, v1, a1
    vmv.x.s a2, v3
    li   t1, -128
    bne  a2, t1, fail

    vsetvli t0, zero, e16, m1, ta, ma
    li   t1, 8
    bne  t0, t1, fail
    li   a0, 0x8001
    vmv.v.x v6, a0
    vmv.x.s a2, v6
    li   t1, -32767
    bne  a2, t1, fail
    li   a0, 0x7fff
    vmv.v.x v1, a0
    li   a1, 1
    vadd.vx v3, v1, a1
    vmv.x.s a2, v3
    li   t1, -32768
    bne  a2, t1, fail
    li   a0, 0x8000
    vmv.v.x v1, a0
    vsra.vi v3, v1, 1
    vmv.x.s a2, v3
    li   t1, -16384
    bne  a2, t1, fail
    li   a0, 0x8001
    vmv.v.x v1, a0
    li   a0, 0
    vmv.v.x v5, a0
    li   a1, 1
    vmslt.vx v5, v1, a1
    vmv.x.s a2, v5
    li   t1, 255
    bne  a2, t1, fail
    vmax.vx v3, v1, a1
    vmv.x.s a2, v3
    li   t1, 1
    bne  a2, t1, fail

    vsetvli t0, zero, e64, m1, ta, ma
    li   t1, 2
    bne  t0, t1, fail
    li   a0, 0x123456789abcdef0
    vmv.v.x v6, a0
    vmv.x.s a2, v6
    bne  a2, a0, fail
    li   a0, 0x7fffffffffffffff
    vmv.v.x v1, a0
    li   a1, 1
    vadd.vx v3, v1, a1
    vmv.x.s a2, v3
    li   t1, 0x8000000000000000
    bne  a2, t1, fail
    li   a0, -1
    vmv.v.x v1, a0
    li   a1, 1
    vminu.vx v3, v1, a1
    vmv.x.s a2, v3
    bne  a2, a1, fail
    li   a0, 0x1234
    vmv.v.x v1, a0
    li   a1, 0xff
    vxor.vx v3, v1, a1
    vmv.x.s a2, v3
    li   t1, 0x12cb
    bne  a2, t1, fail
    li   a0, 1
    vmv.v.x v1, a0
    li   a1, 63
    vsll.vx v3, v1, a1
    vmv.x.s a2, v3
    li   t1, 0x8000000000000000
    bne  a2, t1, fail

pass:
    li   t0, 0xCAFEBABE
    sw   t0, 0(s0)
    j    pass

fail:
    li   t0, 0xDEAD0001
    sw   t0, 0(s0)
    j    fail
