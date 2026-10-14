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

pass:
    li   t0, 0xCAFEBABE
    sw   t0, 0(s0)
    j    pass

fail:
    li   t0, 0xDEAD0001
    sw   t0, 0(s0)
    j    fail
