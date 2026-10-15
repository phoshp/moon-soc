.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300
    li   a1, 0x80000340
    li   t0, 5
    sw   t0, 0(a0)
    li   t0, 1
    sw   t0, 4(a0)
    li   t0, 3
    sw   t0, 8(a0)
    li   t0, 2
    sw   t0, 12(a0)

    vsetivli t0, 4, e32, m1, tu, mu
    vle32.v v1, (a0)

    li   t1, 10
    vmv.v.x v2, t1
    vredsum.vs v3, v1, v2
    vmv.x.s t2, v3
    li   t3, 21
    bne  t2, t3, fail

    li   t1, 15
    vmv.v.x v2, t1
    vredand.vs v3, v1, v2
    vmv.x.s t2, v3
    bnez t2, fail

    vmv.v.x v2, zero
    vredor.vs v3, v1, v2
    vmv.x.s t2, v3
    li   t3, 7
    bne  t2, t3, fail
    vredxor.vs v3, v1, v2
    vmv.x.s t2, v3
    li   t3, 5
    bne  t2, t3, fail

    vredminu.vs v3, v1, v2
    vmv.x.s t2, v3
    bnez t2, fail
    vredmin.vs v3, v1, v2
    vmv.x.s t2, v3
    bnez t2, fail
    vredmaxu.vs v3, v1, v2
    vmv.x.s t2, v3
    li   t3, 5
    bne  t2, t3, fail
    vredmax.vs v3, v1, v2
    vmv.x.s t2, v3
    bne  t2, t3, fail

    # Only source elements zero and two contribute under v0.t.
    li   t0, 5
    sb   t0, 0(a1)
    vlm.v v0, (a1)
    li   t1, 10
    vmv.v.x v2, t1
    vredsum.vs v3, v1, v2, v0.t
    vmv.x.s t2, v3
    li   t3, 18
    bne  t2, t3, fail

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
1:  j    1b

fail:
    li   t0, 0xDEAD0001
    sd   t0, 0(s0)
2:  j    2b
