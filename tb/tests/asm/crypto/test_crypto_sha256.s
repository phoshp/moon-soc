.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   t0, 0xfedcba9812345678

    sha256sum0 t1, t0
    li   t2, 0x66146474
    bne  t1, t2, fail

    sha256sum1 t1, t0
    li   t2, 0x3561abda
    bne  t1, t2, fail

    sha256sig0 t1, t0
    li   t2, 0xffffffffe7fce6ee
    bne  t1, t2, fail

    sha256sig1 t1, t0
    li   t2, 0xffffffffa1f78649
    bne  t1, t2, fail

    li   t0, 0x0000000012345678
    sha256sig0 t1, t0
    li   t2, 0xffffffffe7fce6ee
    bne  t1, t2, fail

pass:
    li   t0, 0xCAFEBABE
    sw   t0, 0(s0)
    j    pass

fail:
    li   t0, 0xDEAD0001
    sw   t0, 0(s0)
    j    fail
