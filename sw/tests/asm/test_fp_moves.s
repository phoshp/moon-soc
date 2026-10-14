# Directed test for the first scalar F extension register-transfer operations.
.section .text
.globl _start
.option norvc

_start:
    li   t0, 0xD2345678
    addiw t0, t0, 0
    fmv.w.x f1, t0
    fmv.x.w t1, f1
    bne  t0, t1, fail

    li   t0, 0x80001000
    li   t1, 0xCAFEBABE
    sw   t1, 0(t0)
pass:
    j    pass

fail:
    li   t0, 0x80001000
    li   t1, 0xDEAD0001
    sw   t1, 0(t0)
hang:
    j    hang
