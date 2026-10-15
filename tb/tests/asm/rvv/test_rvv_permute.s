.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300
    li   a1, 0x80000320
    li   t0, 10
    sw   t0, 0(a0)
    li   t0, 20
    sw   t0, 4(a0)
    li   t0, 30
    sw   t0, 8(a0)
    li   t0, 40
    sw   t0, 12(a0)
    li   t0, 3
    sw   t0, 0(a1)
    sw   zero, 4(a1)
    li   t0, 7
    sw   t0, 8(a1)
    li   t0, 2
    sw   t0, 12(a1)

    vsetivli t0, 4, e32, m1, tu, mu
    vle32.v v1, (a0)
    vle32.v v2, (a1)

    # Gather by vector, scalar, and immediate index. Out-of-range is zero.
    vrgather.vv v3, v1, v2
    vse32.v v3, (a1)
    lw   t1, 0(a1)
    li   t2, 40
    bne  t1, t2, fail1
    li   t2, 2
    vrgather.vx v3, v1, t2
    vse32.v v3, (a1)
    lw   t1, 0(a1)
    li   t2, 30
    bne  t1, t2, fail2
    vrgather.vi v3, v1, 1
    vse32.v v3, (a1)
    lw   t1, 0(a1)
    li   t2, 20
    bne  t1, t2, fail3
    vrgather.vi v3, v1, 7
    vse32.v v3, (a1)
    lw   t1, 0(a1)
    bnez t1, fail4

    # Slides use source elements over VLMAX; slideup preserves below offset.
    li   t0, 99
    vmv.v.x v4, t0
    vslideup.vi v4, v1, 1
    vse32.v v4, (a1)
    lw   t1, 0(a1)
    li   t2, 99
    bne  t1, t2, fail5
    lw   t1, 4(a1)
    li   t2, 10
    bne  t1, t2, fail6

    vslidedown.vi v4, v1, 1
    vse32.v v4, (a1)
    lw   t1, 0(a1)
    li   t2, 20
    bne  t1, t2, fail7
    lw   t1, 12(a1)
    bnez t1, fail8

    li   t0, 4
    vslidedown.vx v4, v1, t0
    vse32.v v4, (a1)
    lw   t1, 0(a1)
    bnez t1, fail12

    li   t0, 99
    vslide1up.vx v4, v1, t0
    vse32.v v4, (a1)
    lw   t1, 0(a1)
    li   t2, 99
    bne  t1, t2, fail9
    lw   t1, 12(a1)
    li   t2, 30
    bne  t1, t2, fail10

    vslide1down.vx v4, v1, t0
    vse32.v v4, (a1)
    lw   t1, 12(a1)
    li   t2, 99
    bne  t1, t2, fail11
    lw   t1, 0(a1)
    li   t2, 20
    bne  t1, t2, fail13

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
fail:
    sd   t0, 0(s0)
2:  j    2b
