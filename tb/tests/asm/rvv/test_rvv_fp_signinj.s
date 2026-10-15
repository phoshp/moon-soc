.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300
    li   a1, 0x80000320
    li   a2, 0x80000340
    li   t0, 0x3fc00000
    sw   t0, 0(a0)
    li   t0, 0xc0000000
    sw   t0, 4(a0)
    li   t0, 0x3f000000
    sw   t0, 8(a0)
    li   t0, 0xbf800000
    sw   t0, 12(a0)
    li   t0, 0xbe800000
    sw   t0, 0(a1)
    li   t0, 0x40400000
    sw   t0, 4(a1)
    li   t0, 0xc0800000
    sw   t0, 8(a1)
    li   t0, 0x3f000000
    sw   t0, 12(a1)

    vsetivli t0, 4, e32, m1, tu, mu
    vle32.v v1, (a0)
    vle32.v v2, (a1)
    vfsgnj.vv v3, v1, v2
    vse32.v v3, (a2)
    lwu  t1, 0(a2)
    li   t2, 0xbfc00000
    bne  t1, t2, fail1
    lwu  t1, 4(a2)
    li   t2, 0x40000000
    bne  t1, t2, fail2
    lwu  t1, 8(a2)
    li   t2, 0xbf000000
    bne  t1, t2, fail3
    lwu  t1, 12(a2)
    li   t2, 0x3f800000
    bne  t1, t2, fail4

    vfsgnjn.vv v3, v1, v2
    vse32.v v3, (a2)
    lwu  t1, 0(a2)
    li   t2, 0x3fc00000
    bne  t1, t2, fail5
    lwu  t1, 4(a2)
    li   t2, 0xc0000000
    bne  t1, t2, fail6
    lwu  t1, 8(a2)
    li   t2, 0x3f000000
    bne  t1, t2, fail7
    lwu  t1, 12(a2)
    li   t2, 0xbf800000
    bne  t1, t2, fail8

    vfsgnjx.vv v3, v1, v2
    vse32.v v3, (a2)
    lwu  t1, 0(a2)
    li   t2, 0xbfc00000
    bne  t1, t2, fail9
    lwu  t1, 4(a2)
    li   t2, 0xc0000000
    bne  t1, t2, fail10
    lwu  t1, 8(a2)
    li   t2, 0xbf000000
    bne  t1, t2, fail11
    lwu  t1, 12(a2)
    li   t2, 0xbf800000
    bne  t1, t2, fail12

    nop
    nop
    nop
    nop
    csrr t1, fflags
    andi t1, t1, 31
    bnez t1, fail13

    li   a0, 0x80000380
    li   a1, 0x800003a0
    li   a2, 0x800003c0
    li   t0, 0x3ff80000
    slli t0, t0, 32
    sd   t0, 0(a0)
    li   t0, 0xbfe00000
    slli t0, t0, 32
    sd   t0, 0(a1)
    vsetivli t0, 1, e64, m1, tu, mu
    vle64.v v1, (a0)
    vle64.v v2, (a1)
    vfsgnj.vv v3, v1, v2
    vse64.v v3, (a2)
    ld   t1, 0(a2)
    li   t2, 0xbff80000
    slli t2, t2, 32
    bne  t1, t2, fail14

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
        j fail
fail9: li t0, 0xDEAD0009
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
fail:
    sd   t0, 0(s0)
2:  j    2b
