.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300
    li   a1, 0x80000320
    li   a2, 0x80000340
    li   a3, 0x80000360
    li   t0, 0x3f800000
    sw   t0, 0(a0)
    li   t0, 0x40000000
    sw   t0, 4(a0)
    li   t0, 0x40400000
    sw   t0, 8(a0)
    li   t0, 0x40800000
    sw   t0, 12(a0)
    li   t0, 0x40000000
    sw   t0, 0(a3)
    flw  ft0, 0(a3)
    nop
    nop
    nop
    nop

    vsetivli t0, 4, e32, m1, tu, mu
    vle32.v v1, (a0)
    vfadd.vf v2, v1, ft0
    vse32.v v2, (a1)
    lwu  t1, 0(a1)
    li   t2, 0x40400000
    bne  t1, t2, fail1
    lwu  t1, 12(a1)
    li   t2, 0x40c00000
    bne  t1, t2, fail2

    vfmul.vf v2, v1, ft0
    vse32.v v2, (a1)
    lwu  t1, 8(a1)
    li   t2, 0x40c00000
    bne  t1, t2, fail3

    vfdiv.vf v2, v1, ft0
    vse32.v v2, (a1)
    lwu  t1, 0(a1)
    li   t2, 0x3f000000
    bne  t1, t2, fail4
    lwu  t1, 12(a1)
    li   t2, 0x40000000
    bne  t1, t2, fail5

    vmfeq.vf v3, v1, ft0
    vsm.v v3, (a2)
    lbu  t1, 0(a2)
    andi t1, t1, 15
    li   t2, 2
    bne  t1, t2, fail6

    vfmin.vf v2, v1, ft0
    vse32.v v2, (a1)
    lwu  t1, 12(a1)
    li   t2, 0x40000000
    bne  t1, t2, fail7
    vfmax.vf v2, v1, ft0
    vse32.v v2, (a1)
    lwu  t1, 0(a1)
    li   t2, 0x40000000
    bne  t1, t2, fail8

    li   t0, 0xc0000000
    sw   t0, 0(a3)
    flw  ft0, 0(a3)
    nop
    nop
    nop
    nop
    vfsgnj.vf v2, v1, ft0
    vse32.v v2, (a1)
    lwu  t1, 0(a1)
    li   t2, 0xbf800000
    bne  t1, t2, fail9

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
fail:
    sd   t0, 0(s0)
2:  j    2b
