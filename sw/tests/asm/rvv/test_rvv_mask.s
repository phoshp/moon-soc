.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300
    li   t0, 0
    sb   t0, 0(a0)
    li   t0, 1
    sb   t0, 1(a0)
    sb   zero, 2(a0)
    sb   t0, 3(a0)

    # The source mask has set bits at elements 1 and 3.
    vsetivli t0, 4, e8, m1, tu, mu
    vle8.v v1, (a0)
    vmv.v.x v6, zero
    vmsne.vv v2, v1, v6

    vcpop.m t1, v2
    li   t2, 2
    bne  t1, t2, fail1
    vfirst.m t1, v2
    li   t2, 1
    bne  t1, t2, fail2

    vmsbf.m v3, v2
    vmv.x.s t1, v3
    li   t2, 1
    bne  t1, t2, fail3
    vmsif.m v3, v2
    vmv.x.s t1, v3
    li   t2, 3
    bne  t1, t2, fail4
    vmsof.m v3, v2
    vmv.x.s t1, v3
    li   t2, 2
    bne  t1, t2, fail5

    # Mask prefix destination tails follow vta.
    vsetivli t0, 4, e8, m1, ta, mu
    vmsbf.m v3, v2
    vmv.x.s t1, v3
    andi t1, t1, 0xff
    li   t2, 0xf1
    bne  t1, t2, fail6

    # A masked query counts and finds only selected active elements.
    vmsne.vv v0, v1, v6
    vcpop.m t1, v2, v0.t
    li   t2, 2
    bne  t1, t2, fail7
    vfirst.m t1, v2, v0.t
    li   t2, 1
    bne  t1, t2, fail8

    # No matching source bits gives all ones for vmsbf/vmsif, zero for vmsof,
    # zero population, and -1 for vfirst.
    vsetivli t0, 4, e8, m1, tu, mu
    li   t0, 7
    vmv.v.x v5, t0
    vmseq.vv v4, v1, v5
    vcpop.m t1, v4
    bnez t1, fail9
    vfirst.m t1, v4
    li   t2, -1
    bne  t1, t2, fail10
    vmsbf.m v3, v4
    vmv.x.s t1, v3
    andi t1, t1, 15
    li   t2, 15
    bne  t1, t2, fail11
    vmsif.m v3, v4
    vmv.x.s t1, v3
    andi t1, t1, 15
    li   t2, 15
    bne  t1, t2, fail12
    vmsof.m v3, v4
    vmv.x.s t1, v3
    andi t1, t1, 15
    bnez t1, fail13

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
1:  j    1b

fail1: li t0, 0xDEAD0001
        j fail_common
fail2: li t0, 0xDEAD0002
        j fail_common
fail3: li t0, 0xDEAD0003
        j fail_common
fail4: li t0, 0xDEAD0004
        j fail_common
fail5: li t0, 0xDEAD0005
        j fail_common
fail6: li t0, 0xDEAD0006
        j fail_common
fail7: li t0, 0xDEAD0007
        j fail_common
fail8: li t0, 0xDEAD0008
        j fail_common
fail9: li t0, 0xDEAD0009
        j fail_common
fail10: li t0, 0xDEAD000A
        j fail_common
fail11: li t0, 0xDEAD000B
        j fail_common
fail12: li t0, 0xDEAD000C
        j fail_common
fail13: li t0, 0xDEAD000D
        j fail_common
fail_common:
    sd   t0, 0(s0)
2:  j    2b
