.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300
    li   a1, 0x80000320
    li   a2, 0x80000340
    li   a3, 0x80000360
    li   t0, 0x3fc00000
    sw   t0, 0(a0)
    li   t0, 0x40000000
    sw   t0, 0(a1)
    li   t0, 0x3f800000
    sw   t0, 0(a2)

    vsetivli t0, 1, e32, m1, tu, mu
    vle32.v v1, (a0)
    vle32.v v2, (a1)
    vle32.v v3, (a2)
    vfmacc.vv v3, v1, v2
    vse32.v v3, (a3)
    lwu  t1, 0(a3)
    li   t2, 0x40800000
    bne  t1, t2, fail1

    vle32.v v3, (a2)
    vfmsac.vv v3, v1, v2
    vse32.v v3, (a3)
    lwu  t1, 0(a3)
    li   t2, 0x40000000
    bne  t1, t2, fail2

    vle32.v v3, (a2)
    vfnmsac.vv v3, v1, v2
    vse32.v v3, (a3)
    lwu  t1, 0(a3)
    li   t2, 0xc0000000
    bne  t1, t2, fail3

    vle32.v v3, (a2)
    vfnmacc.vv v3, v1, v2
    vse32.v v3, (a3)
    lwu  t1, 0(a3)
    li   t2, 0xc0800000
    bne  t1, t2, fail4
    nop
    nop
    nop
    nop
    csrr t1, fflags
    andi t1, t1, 31
    bnez t1, fail5

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
1:  j    1b

fail1: li t0, 0xDEAD0001
        j fail
fail2: li t0, 0xDEAD0002
        j fail
fail3: li t0, 0xDEAD0003
        j fail
fail4: li t0, 0xDEAD0004
        j fail
fail5: li t0, 0xDEAD0005
fail:
    sd   t0, 0(s0)
2:  j    2b
