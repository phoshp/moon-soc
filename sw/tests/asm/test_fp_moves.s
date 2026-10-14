# Directed test for the first scalar F extension register-transfer operations.
.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80002000
    li   t0, 0xD2345678
    addiw t0, t0, 0
    fmv.w.x f1, t0
    fsw  f1, 0(s0)
    flw  f2, 0(s0)
    fmv.x.w t1, f2
    li   t2, 0xD2345678
    addiw t2, t2, 0
    bne  t2, t1, fail

    li   t1, 0x123456789abcdef0
    sd   t1, 8(s0)
    fld  f3, 8(s0)
    fsd  f3, 16(s0)
    ld   t2, 16(s0)
    bne  t1, t2, fail

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
