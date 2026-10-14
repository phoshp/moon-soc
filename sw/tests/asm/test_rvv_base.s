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
    li   a0, 0x123
    vmv.v.x v6, a0
    vmv.x.s a2, v6
    li   t1, 0x23
    bne  a2, t1, fail

    vsetvli t0, zero, e16, m1, ta, ma
    li   t1, 8
    bne  t0, t1, fail
    li   a0, 0x8001
    vmv.v.x v6, a0
    vmv.x.s a2, v6
    li   t1, -32767
    bne  a2, t1, fail

    vsetvli t0, zero, e64, m1, ta, ma
    li   t1, 2
    bne  t0, t1, fail
    li   a0, 0x123456789abcdef0
    vmv.v.x v6, a0
    vmv.x.s a2, v6
    bne  a2, a0, fail

pass:
    li   t0, 0xCAFEBABE
    sw   t0, 0(s0)
    j    pass

fail:
    li   t0, 0xDEAD0001
    sw   t0, 0(s0)
    j    fail
