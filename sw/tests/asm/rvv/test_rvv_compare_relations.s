.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300
    li   a1, 0x80000320
    li   t0, 0x80
    sb   t0, 0(a0)
    li   t0, 0x7f
    sb   t0, 1(a0)
    li   t0, 1
    sb   t0, 2(a0)
    li   t0, 0xff
    sb   t0, 3(a0)
    li   t0, 0x7f
    sb   t0, 0(a1)
    li   t0, 0x80
    sb   t0, 1(a1)
    li   t0, 2
    sb   t0, 2(a1)
    sb   zero, 3(a1)

    vsetivli t0, 4, e8, m1, tu, mu
    vle8.v v1, (a0)
    vle8.v v2, (a1)

    vmsleu.vv v3, v1, v2
    vcpop.m t1, v3
    li   t2, 2
    bne  t1, t2, fail1
    vfirst.m t1, v3
    li   t2, 1
    bne  t1, t2, fail2

    vmsle.vv v3, v1, v2
    vcpop.m t1, v3
    li   t2, 3
    bne  t1, t2, fail3
    vfirst.m t1, v3
    li   t2, 0
    bne  t1, t2, fail4

    li   t0, 1
    vmsleu.vx v3, v1, t0
    vcpop.m t1, v3
    li   t2, 1
    bne  t1, t2, fail5
    vmsle.vx v3, v1, t0
    vcpop.m t1, v3
    li   t2, 3
    bne  t1, t2, fail6

    li   t0, 127
    vmsgtu.vx v3, v1, t0
    vcpop.m t1, v3
    li   t2, 2
    bne  t1, t2, fail7
    vfirst.m t1, v3
    li   t2, 0
    bne  t1, t2, fail8
    li   t0, 0
    vmsgt.vx v3, v1, t0
    vcpop.m t1, v3
    li   t2, 2
    bne  t1, t2, fail9

    vmsgtu.vi v3, v1, 3
    vcpop.m t1, v3
    li   t2, 3
    bne  t1, t2, fail10
    vmsgt.vi v3, v1, -1
    vcpop.m t1, v3
    li   t2, 2
    bne  t1, t2, fail11
    vfirst.m t1, v3
    li   t2, 1
    bne  t1, t2, fail12

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
fail:
    sd   t0, 0(s0)
2:  j    2b
