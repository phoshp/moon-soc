.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300
    li   a2, 0x80000340
    li   t0, 0x40800000
    sw   t0, 0(a0)
    li   t0, 0x40100000
    sw   t0, 4(a0)
    li   t0, 0x3e800000
    sw   t0, 8(a0)
    li   t0, 0x41100000
    sw   t0, 12(a0)

    vsetivli t0, 4, e32, m1, tu, mu
    vle32.v v1, (a0)
    vfsqrt.v v2, v1
    vse32.v v2, (a2)
    lwu  t1, 0(a2)
    li   t2, 0x40000000
    bne  t1, t2, fail1
    lwu  t1, 4(a2)
    li   t2, 0x3fc00000
    bne  t1, t2, fail2
    lwu  t1, 8(a2)
    li   t2, 0x3f000000
    bne  t1, t2, fail3
    lwu  t1, 12(a2)
    li   t2, 0x40400000
    bne  t1, t2, fail4
    nop
    nop
    nop
    nop
    csrr t1, fflags
    andi t1, t1, 31
    bnez t1, fail5

    li   a0, 0x80000380
    li   a2, 0x800003c0
    li   t0, 0x40190000
    slli t0, t0, 32
    sd   t0, 0(a0)
    vsetivli t0, 2, e64, m1, tu, mu
    vle64.v v1, (a0)
    vfsqrt.v v2, v1
    vse64.v v2, (a2)
    ld   t1, 0(a2)
    li   t2, 0x40040000
    slli t2, t2, 32
    bne  t1, t2, fail6

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
        j fail
fail6: li t0, 0xDEAD0006
fail:
    sd   t0, 0(s0)
2:  j    2b
