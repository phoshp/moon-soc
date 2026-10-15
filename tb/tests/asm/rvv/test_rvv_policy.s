.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300

    # Tail and mask agnostic vector arithmetic writes all ones to inactive
    # elements, while active elements retain their computed values.
    vsetvli t0, zero, e32, m1, tu, mu
    li   t1, 42
    vmv.v.x v1, t1
    li   t1, 1
    vmv.v.x v0, t1
    vsetivli t0, 2, e32, m1, ta, ma
    vadd.vx v3, v1, t1, v0.t
    vsetvli t0, zero, e32, m1, tu, mu
    vse32.v v3, (a0)
    lw   t2, 0(a0)
    li   t3, 43
    bne  t2, t3, fail
    lw   t2, 4(a0)
    li   t3, -1
    bne  t2, t3, fail
    lw   t2, 8(a0)
    bne  t2, t3, fail
    lw   t2, 12(a0)
    bne  t2, t3, fail

    # Mask-undisturbed policy preserves masked-off destination elements.
    vsetvli t0, zero, e32, m1, tu, mu
    li   t1, 0x55555555
    vmv.v.x v4, t1
    li   t1, 1
    vmv.v.x v0, t1
    vadd.vx v4, v4, t1, v0.t
    vse32.v v4, (a0)
    lw   t2, 0(a0)
    li   t3, 0x55555556
    bne  t2, t3, fail
    lw   t2, 4(a0)
    li   t3, 0x55555555
    bne  t2, t3, fail
    lw   t2, 8(a0)
    bne  t2, t3, fail
    lw   t2, 12(a0)
    bne  t2, t3, fail

    # Tail-undisturbed policy preserves elements beyond VL.
    vsetivli t0, 2, e32, m1, tu, mu
    vadd.vx v4, v4, t1
    vsetvli t0, zero, e32, m1, tu, mu
    vse32.v v4, (a0)
    lw   t2, 0(a0)
    li   t3, 0x55555557
    bne  t2, t3, fail
    lw   t2, 4(a0)
    li   t3, 0x55555556
    bne  t2, t3, fail
    lw   t2, 8(a0)
    li   t3, 0x55555555
    bne  t2, t3, fail
    lw   t2, 12(a0)
    bne  t2, t3, fail

    # Mask- and tail-agnostic vector loads produce all-one inactive elements.
    li   a1, 0x80000340
    li   t1, 0x12345678
    sw   t1, 0(a1)
    li   t1, 0x23456789
    sw   t1, 4(a1)
    vsetvli t0, zero, e32, m1, tu, mu
    li   t1, 0x77777777
    vmv.v.x v5, t1
    li   t1, 1
    vmv.v.x v0, t1
    vsetivli t0, 2, e32, m1, ta, ma
    vle32.v v5, (a1), v0.t
    vsetvli t0, zero, e32, m1, tu, mu
    vse32.v v5, (a0)
    lw   t2, 0(a0)
    li   t3, 0x12345678
    bne  t2, t3, fail
    lw   t2, 4(a0)
    li   t3, -1
    bne  t2, t3, fail
    lw   t2, 8(a0)
    bne  t2, t3, fail
    lw   t2, 12(a0)
    bne  t2, t3, fail

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
1:  j    1b

fail:
    li   t0, 0xDEAD0001
    sd   t0, 0(s0)
2:  j    2b
