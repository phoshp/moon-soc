.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000

    csrr t0, misa
    srli t0, t0, 21
    andi t0, t0, 1
    li   t1, 1
    bne  t0, t1, fail

    csrr t0, vlenb
    li   t1, 16
    bne  t0, t1, fail

    vsetvli t0, zero, e32, m1, ta, ma
    li   t1, 4
    bne  t0, t1, fail
    csrr t0, vl
    bne  t0, t1, fail
    csrr t0, vtype
    li   t1, 0xd0
    bne  t0, t1, fail

    li   a0, 42
    vmv.v.x v1, a0
    li   t1, 2
    csrw vstart, t1
    li   a0, 7
    vmv.v.x v1, a0
    csrr t0, vstart
    bne  t0, zero, fail
    li   a1, 0x80000200
    vse32.v v1, (a1)
    lwu  t0, 0(a1)
    li   t1, 42
    bne  t0, t1, fail
    lwu  t0, 4(a1)
    bne  t0, t1, fail
    lwu  t0, 8(a1)
    li   t1, 7
    bne  t0, t1, fail
    lwu  t0, 12(a1)
    bne  t0, t1, fail

    li   t0, 0xdeadbeef
    sw   t0, 0(a1)
    sw   t0, 4(a1)
    sw   t0, 8(a1)
    sw   t0, 12(a1)
    li   t1, 2
    csrw vstart, t1
    vse32.v v1, (a1)
    csrr t0, vstart
    bne  t0, zero, fail
    lwu  t0, 0(a1)
    li   t1, 0xdeadbeef
    bne  t0, t1, fail
    lwu  t0, 4(a1)
    bne  t0, t1, fail
    lwu  t0, 8(a1)
    li   t1, 7
    bne  t0, t1, fail
    lwu  t0, 12(a1)
    bne  t0, t1, fail

    vsetivli t0, 3, e16, m1, tu, mu
    li   t1, 3
    bne  t0, t1, fail
    csrr t0, vl
    bne  t0, t1, fail
    csrr t0, vtype
    li   t1, 8
    bne  t0, t1, fail

    li   t1, 5
    csrw vstart, t1
    csrr t0, vstart
    bne  t0, t1, fail

    li   t1, 1
    csrw vxsat, t1
    csrr t0, vxsat
    bne  t0, t1, fail

    li   t1, 3
    csrw vxrm, t1
    csrr t0, vxrm
    bne  t0, t1, fail
    csrr t0, vcsr
    li   t1, 11
    bne  t0, t1, fail

    li   t1, 8
    csrw vcsr, t1
    csrr t0, vcsr
    bne  t0, t1, fail
    csrr t0, vxrm
    bne  t0, zero, fail
    csrr t0, vxsat
    li   t1, 1
    bne  t0, t1, fail

    # LMUL=2 is outside this VLEN=128, LMUL=1 implementation.
    vsetivli t0, 1, e32, m2, ta, ma
    bne  t0, zero, fail
    csrr t0, vl
    bne  t0, zero, fail
    csrr t0, vtype
    srli t0, t0, 63
    li   t1, 1
    bne  t0, t1, fail

    li   t1, 0
    csrw vstart, t1
    vsetvli t0, zero, e32, m1, ta, ma
    csrr t0, vtype
    li   t1, 0xd0
    bne  t0, t1, fail

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
1:  j    1b

fail:
    li   t0, 0xDEAD00FF
    sd   t0, 0(s0)
1:  j    1b
