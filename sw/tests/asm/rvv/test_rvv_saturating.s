.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300
    li   a1, 0x80000320
    # Signed values for saturated add and subtract.
    li   t0, 120
    sb   t0, 0(a0)
    li   t0, -120
    sb   t0, 1(a0)
    li   t0, 5
    sb   t0, 2(a0)
    li   t0, -5
    sb   t0, 3(a0)
    li   t0, 20
    sb   t0, 0(a1)
    li   t0, -20
    sb   t0, 1(a1)
    li   t0, 9
    sb   t0, 2(a1)
    li   t0, 3
    sb   t0, 3(a1)

    vsetivli t0, 4, e8, m1, tu, mu
    vle8.v v1, (a0)
    vle8.v v2, (a1)

    vsadd.vv v3, v1, v2
    vse8.v v3, (a1)
    lbu  t1, 0(a1)
    li   t2, 127
    bne  t1, t2, fail1
    lbu  t1, 1(a1)
    li   t2, 128
    bne  t1, t2, fail2
    csrr t1, vxsat
    li   t2, 1
    bne  t1, t2, fail3

    csrw vxsat, zero
    vsadd.vx v3, v1, t2
    vse8.v v3, (a1)
    lbu  t1, 0(a1)
    li   t2, 121
    bne  t1, t2, fail4
    csrr t1, vxsat
    bnez t1, fail5

    # Unsigned add clamps at 255; unsigned subtract clamps at zero.
    li   t0, 250
    sb   t0, 0(a0)
    li   t0, 10
    sb   t0, 0(a1)
    vle8.v v1, (a0)
    vle8.v v2, (a1)
    vsaddu.vv v3, v1, v2
    vse8.v v3, (a1)
    lbu  t1, 0(a1)
    li   t2, 255
    bne  t1, t2, fail6
    csrr t1, vxsat
    li   t2, 1
    bne  t1, t2, fail7

    csrw vxsat, zero
    li   t0, 5
    sb   t0, 0(a0)
    li   t0, 9
    sb   t0, 0(a1)
    vle8.v v1, (a0)
    vle8.v v2, (a1)
    vssubu.vv v3, v1, v2
    vse8.v v3, (a1)
    lbu  t1, 0(a1)
    bnez t1, fail8
    csrr t1, vxsat
    li   t2, 1
    bne  t1, t2, fail9

    csrw vxsat, zero
    li   t0, 120
    sb   t0, 0(a0)
    li   t0, -20
    sb   t0, 0(a1)
    vle8.v v1, (a0)
    vle8.v v2, (a1)
    vssub.vv v3, v1, v2
    vse8.v v3, (a1)
    lbu  t1, 0(a1)
    li   t2, 127
    bne  t1, t2, fail10
    csrr t1, vxsat
    li   t2, 1
    bne  t1, t2, fail11

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
fail:
    sd   t0, 0(s0)
2:  j    2b
