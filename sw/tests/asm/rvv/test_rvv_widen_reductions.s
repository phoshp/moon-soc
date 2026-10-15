.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000300
    li   a1, 0x80000320

    # e8 unsigned reduction into an e16 accumulator, with vta on the result.
    li   t0, 255
    sb   t0, 0(a0)
    li   t0, 2
    sb   t0, 1(a0)
    li   t0, 253
    sb   t0, 2(a0)
    li   t0, 4
    sb   t0, 3(a0)
    vsetivli t0, 4, e16, m1, tu, mu
    li   t1, 10
    vmv.v.x v2, t1
    vsetivli t0, 4, e8, ta, mu
    vle8.v v1, (a0)
    vwredsumu.vs v3, v1, v2
    vsetivli t0, 4, e16, m1, tu, mu
    vse16.v v3, (a1)
    lhu  t1, 0(a1)
    li   t2, 524
    bne  t1, t2, fail1
    lhu  t1, 2(a1)
    li   t2, 0xffff
    bne  t1, t2, fail2

    # Signed e8 source values accumulate into a signed e16 seed.
    li   t0, -1
    sb   t0, 0(a0)
    li   t0, 2
    sb   t0, 1(a0)
    li   t0, -3
    sb   t0, 2(a0)
    li   t0, 4
    sb   t0, 3(a0)
    vsetivli t0, 4, e16, m1, tu, mu
    li   t1, 5
    vmv.v.x v2, t1
    vsetivli t0, 4, e8, tu, mu
    vle8.v v1, (a0)
    vwredsum.vs v3, v1, v2
    vsetivli t0, 4, e16, m1, tu, mu
    vse16.v v3, (a1)
    lh   t1, 0(a1)
    li   t2, 7
    bne  t1, t2, fail3

    # Signed e16 to e32 widening reduction.
    li   t0, 1000
    sh   t0, 0(a0)
    li   t0, -20
    sh   t0, 2(a0)
    vsetivli t0, 2, e32, m1, tu, mu
    li   t1, 7
    vmv.v.x v2, t1
    vsetivli t0, 2, e16, m1, tu, mu
    vle16.v v1, (a0)
    vwredsum.vs v3, v1, v2
    vsetivli t0, 2, e32, m1, tu, mu
    vse32.v v3, (a1)
    lw   t1, 0(a1)
    li   t2, 987
    bne  t1, t2, fail4

    # Signed e32 to e64 widening reduction.
    li   t0, 0x7fffffff
    sw   t0, 0(a0)
    li   t0, 1
    sw   t0, 4(a0)
    vsetivli t0, 2, e64, m1, tu, mu
    li   t1, 1
    vmv.v.x v2, t1
    vsetivli t0, 2, e32, m1, tu, mu
    vle32.v v1, (a0)
    vwredsum.vs v3, v1, v2
    vsetivli t0, 2, e64, m1, tu, mu
    vse64.v v3, (a1)
    ld   t1, 0(a1)
    li   t2, 2147483649
    bne  t1, t2, fail5

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
1:  j    1b

fail1: li t0, 0xDEAD0001
        j fail
        j fail
fail2: li t0, 0xDEAD0002
        j fail
fail3: li t0, 0xDEAD0003
        j fail
fail4: li t0, 0xDEAD0004
        j fail
fail5: li t0, 0xDEAD0005
fail:
    sd   t0, 0(s0)
2:  j    2b
