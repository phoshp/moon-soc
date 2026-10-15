.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300
    li   a1, 0x80000320
    li   t0, 20
    sw   t0, 0(a0)
    li   t0, -20
    sw   t0, 4(a0)
    li   t0, 19
    sw   t0, 8(a0)
    li   t0, 9
    sw   t0, 12(a0)
    li   t0, 3
    sw   t0, 0(a1)
    sw   t0, 4(a1)
    sw   zero, 8(a1)
    sw   zero, 12(a1)

    vsetivli t0, 4, e32, m1, tu, mu
    vle32.v v1, (a0)
    vle32.v v2, (a1)

    vdiv.vv v3, v1, v2
    vse32.v v3, (a1)
    lw   t1, 0(a1)
    li   t2, 6
    bne  t1, t2, fail1
    lw   t1, 4(a1)
    li   t2, -6
    bne  t1, t2, fail2
    lw   t1, 8(a1)
    li   t2, -1
    bne  t1, t2, fail3

    vrem.vv v3, v1, v2
    vse32.v v3, (a1)
    lw   t1, 0(a1)
    li   t2, 2
    bne  t1, t2, fail4
    lw   t1, 4(a1)
    li   t2, -2
    bne  t1, t2, fail5
    lw   t1, 8(a1)
    li   t2, 19
    bne  t1, t2, fail6
    lw   t1, 12(a1)
    li   t2, 9
    bne  t1, t2, fail7

    vdivu.vv v3, v1, v2
    vse32.v v3, (a1)
    lw   t1, 4(a1)
    li   t2, 0x5555554e
    bne  t1, t2, fail8
    lw   t1, 8(a1)
    li   t2, -1
    bne  t1, t2, fail9

    vremu.vv v3, v1, v2
    vse32.v v3, (a1)
    lw   t1, 4(a1)
    li   t2, 2
    bne  t1, t2, fail10
    lw   t1, 8(a1)
    li   t2, 19
    bne  t1, t2, fail11

    li   t0, 3
    vdiv.vx v3, v1, t0
    vse32.v v3, (a1)
    lw   t1, 4(a1)
    li   t2, -6
    bne  t1, t2, fail12
    vrem.vx v3, v1, t0
    vse32.v v3, (a1)
    lw   t1, 4(a1)
    li   t2, -2
    bne  t1, t2, fail13
    vdivu.vx v3, v1, t0
    vse32.v v3, (a1)
    lw   t1, 4(a1)
    li   t2, 0x5555554e
    bne  t1, t2, fail14
    vremu.vx v3, v1, t0
    vse32.v v3, (a1)
    lw   t1, 4(a1)
    li   t2, 2
    bne  t1, t2, fail15

    # Signed minimum divided by -1 returns the minimum; the remainder is zero.
    li   t0, 0x80000000
    sw   t0, 12(a0)
    li   t0, -1
    sw   t0, 12(a1)
    vle32.v v1, (a0)
    vle32.v v2, (a1)
    vdiv.vv v3, v1, v2
    vse32.v v3, (a1)
    lwu  t1, 12(a1)
    li   t2, 0x80000000
    bne  t1, t2, fail16
    li   t0, -1
    sw   t0, 12(a1)
    vle32.v v2, (a1)
    vrem.vv v3, v1, v2
    vse32.v v3, (a1)
    lw   t1, 12(a1)
    bnez t1, fail17

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
1:  j    1b

fail1:  li t0, 0xDEAD0001
        j fail
fail2:  li t0, 0xDEAD0002
        j fail
fail3:  li t0, 0xDEAD0003
        j fail
fail4:  li t0, 0xDEAD0004
        j fail
fail5:  li t0, 0xDEAD0005
        j fail
fail6:  li t0, 0xDEAD0006
        j fail
fail7:  li t0, 0xDEAD0007
        j fail
fail8:  li t0, 0xDEAD0008
        j fail
fail9:  li t0, 0xDEAD0009
        j fail
fail10: li t0, 0xDEAD000a
        j fail
fail11: li t0, 0xDEAD000b
        j fail
fail12: li t0, 0xDEAD000c
        j fail
fail13: li t0, 0xDEAD000d
        j fail
fail14: li t0, 0xDEAD000e
        j fail
fail15: li t0, 0xDEAD000f
        j fail
fail16: li t0, 0xDEAD0010
        j fail
fail17: li t0, 0xDEAD0011
fail:
    sd   t0, 0(s0)
2:  j    2b
