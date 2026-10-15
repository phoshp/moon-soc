.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300
    li   a1, 0x80000320
    li   t0, 0x96
    sb   t0, 0(a0)
    li   t0, 0xa5
    sb   t0, 1(a0)
    sb   zero, 0(a1)
    sb   zero, 1(a1)

    # Ten active mask bits occupy two packed bytes.
    vsetivli t0, 10, e8, m1, tu, mu
    vlm.v v3, (a0)
    vsm.v v3, (a1)
    lbu  t1, 0(a1)
    li   t2, 0x96
    bne  t1, t2, fail1
    lbu  t1, 1(a1)
    li   t2, 0xa5
    bne  t1, t2, fail2

    # A zero-length packed mask transfer performs no memory access.
    vsetivli t0, 0, e8, m1, tu, mu
    vlm.v v4, (a0)
    vsm.v v4, (a1)
    lbu  t1, 0(a1)
    li   t2, 0x96
    bne  t1, t2, fail3

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
1:  j    1b

fail1: li t0, 0xDEAD0001
       j fail_common
fail2: li t0, 0xDEAD0002
       j fail_common
fail3: li t0, 0xDEAD0003
fail_common:
    sd   t0, 0(s0)
2:  j    2b
