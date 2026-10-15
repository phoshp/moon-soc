.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300
    li   a1, 0x80000320
    li   t0, 2
    sw   t0, 0(a0)
    li   t0, 3
    sw   t0, 4(a0)
    li   t0, 0x10000
    sw   t0, 8(a0)
    li   t0, -2
    sw   t0, 12(a0)
    li   t0, 4
    sw   t0, 0(a1)
    li   t0, 5
    sw   t0, 4(a1)
    li   t0, 2
    sw   t0, 8(a1)
    li   t0, 3
    sw   t0, 12(a1)

    vsetivli t0, 4, e32, m1, tu, mu
    vle32.v v1, (a0)
    vle32.v v2, (a1)
    vmul.vv v3, v1, v2
    vse32.v v3, (a1)
    lw   t1, 0(a1)
    li   t2, 8
    bne  t1, t2, fail1
    lw   t1, 4(a1)
    li   t2, 15
    bne  t1, t2, fail2
    lw   t1, 8(a1)
    li   t2, 0x20000
    bne  t1, t2, fail3
    lw   t1, 12(a1)
    li   t2, -6
    bne  t1, t2, fail4

    li   t0, 3
    vmul.vx v3, v1, t0
    vse32.v v3, (a1)
    lw   t1, 0(a1)
    li   t2, 6
    bne  t1, t2, fail5
    lw   t1, 4(a1)
    li   t2, 9
    bne  t1, t2, fail6
    lw   t1, 8(a1)
    li   t2, 0x30000
    bne  t1, t2, fail7
    lw   t1, 12(a1)
    li   t2, -6
    bne  t1, t2, fail8

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
        j fail
fail7: li t0, 0xDEAD0007
        j fail
fail8: li t0, 0xDEAD0008
fail:
    sd   t0, 0(s0)
2:  j    2b
