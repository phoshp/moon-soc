.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000200
    li   t0, 0xff800000
    sw   t0, 0(a0)              # -infinity
    li   t0, 0x3f800000
    sw   t0, 4(a0)              # +normal
    li   t0, 0x80000000
    sw   t0, 8(a0)              # -zero
    li   t0, 0x7fc00000
    sw   t0, 12(a0)             # quiet NaN

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v v1, (a0)
    vfclass.v v2, v1
    vse32.v v2, (a0)
    lwu  t0, 0(a0)
    li   t1, 1
    bne  t0, t1, fail
    lwu  t0, 4(a0)
    li   t1, 64
    bne  t0, t1, fail
    lwu  t0, 8(a0)
    li   t1, 8
    bne  t0, t1, fail
    lwu  t0, 12(a0)
    li   t1, 512
    bne  t0, t1, fail

    li   a0, 0x80000300
    li   t0, 0x8000000000000001
    sd   t0, 0(a0)              # -subnormal
    li   t0, 0x7ff0000000000001
    sd   t0, 8(a0)              # signaling NaN
    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v v1, (a0)
    vfclass.v v2, v1
    vse64.v v2, (a0)
    ld   t0, 0(a0)
    li   t1, 4
    bne  t0, t1, fail
    ld   t0, 8(a0)
    li   t1, 256
    bne  t0, t1, fail

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
1:  j    1b
fail:
    li   t0, 0xDEAD00FF
    sd   t0, 0(s0)
2:  j    2b
