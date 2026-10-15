.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   t0, 0x0706050403020100
    li   t1, 0x0f0e0d0c0b0a0908

    aes64es t2, t0, t1
    li   t3, 0x7bab01f276676b63
    bne  t2, t3, fail

    aes64esm t2, t0, t1
    li   t3, 0x51336d2c455c6a6a
    bne  t2, t3, fail

    aes64ds t2, t0, t1
    li   t3, 0x9ed7093038a3f352
    bne  t2, t3, fail

    aes64dsm t2, t0, t1
    li   t3, 0x6e29192e1c96a313
    bne  t2, t3, fail

    aes64im t2, t0
    li   t3, 0x090c0b0e0d080f0a
    bne  t2, t3, fail

pass:
    li   t0, 0xCAFEBABE
    sw   t0, 0(s0)
    j    pass

fail:
    li   t0, 0xDEAD0001
    sw   t0, 0(s0)
    j    fail
