.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300
    li   a1, 0x80000340
    li   t0, 10
    sw   t0, 0(a0)
    li   t0, 20
    sw   t0, 4(a0)
    li   t0, 30
    sw   t0, 8(a0)
    li   t0, 40
    sw   t0, 12(a0)

    # e32 data uses byte-sized indices in v2: [4, 0, 0, 0].
    vsetivli t0, 4, e32, m1, tu, mu
    li   t1, 4
    vmv.v.x v2, t1
    vluxei8.v v3, (a0), v2
    vse32.v v3, (a1)
    lw   t2, 0(a1)
    li   t3, 20
    bne  t2, t3, fail1
    lw   t2, 4(a1)
    li   t3, 10
    bne  t2, t3, fail2
    lw   t2, 8(a1)
    bne  t2, t3, fail3
    lw   t2, 12(a1)
    bne  t2, t3, fail4

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
fail_common:
    sd   t0, 0(s0)
2:  j    2b
