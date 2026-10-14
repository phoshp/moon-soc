.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   t0, 0x1122334455667788
    li   t1, 0x99aabbccddeeff00
    aes64ks2 t2, t0, t1
    li   t3, 0x55667788cccccc44
    bne  t2, t3, fail

pass:
    li   t0, 0xCAFEBABE
    sw   t0, 0(s0)
    j    pass

fail:
    li   t0, 0xDEAD0001
    sw   t0, 0(s0)
    j    fail
