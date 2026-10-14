.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   t0, 0x0123456789abcdef

    sha512sum0 t1, t0
    li   t2, 0xb7c57a100c7ec1ab
    bne  t1, t2, fail

    sha512sum1 t1, t0
    li   t2, 0x7703112333475567
    bne  t1, t2, fail

    sha512sig0 t1, t0
    li   t2, 0x6f92c77c6c4f1aa1
    bne  t1, t2, fail

    sha512sig1 t1, t0
    li   t2, 0x70a3460dbbd4317a
    bne  t1, t2, fail

pass:
    li   t0, 0xCAFEBABE
    sw   t0, 0(s0)
    j    pass

fail:
    li   t0, 0xDEAD0001
    sw   t0, 0(s0)
    j    fail
