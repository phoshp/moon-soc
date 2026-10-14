# Directed tests for scalar F/D moves, memory transfers, and addition.
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

    fmv.d.x f4, t1
    fmv.x.d t2, f4
    bne  t1, t2, fail

    li   t0, 0x3fc00000
    fmv.w.x f1, t0
    li   t0, 0x40100000
    fmv.w.x f2, t0
    fadd.s f3, f1, f2, rne
    fmv.x.w t1, f3
    li   t2, 0x40700000
    bne  t1, t2, fail
    fmul.s f3, f1, f2, rne
    fmv.x.w t1, f3
    li   t2, 0x40580000
    bne  t1, t2, fail

    li   t0, 0x3ff8000000000000
    fmv.d.x f1, t0
    li   t0, 0x4002000000000000
    fmv.d.x f2, t0
    fadd.d f3, f1, f2, rne
    fmv.x.d t1, f3
    li   t2, 0x400e000000000000
    bne  t1, t2, fail
    fsub.d f3, f2, f1, rne
    fmv.x.d t1, f3
    li   t2, 0x3fe8000000000000
    bne  t1, t2, fail
    fmul.d f3, f1, f2, rne
    fmv.x.d t1, f3
    li   t2, 0x400b000000000000
    bne  t1, t2, fail

    li   t0, 0x3f800000
    fmv.w.x f1, t0
    li   t0, 0x33800000
    fmv.w.x f2, t0
    fadd.s f3, f1, f2, rne
    fmv.x.w t1, f3
    li   t2, 0x3f800000
    bne  t1, t2, fail
    li   t0, 0x3fc00000
    fmv.w.x f1, t0
    li   t0, 0x40100000
    fmv.w.x f2, t0
    fsub.s f3, f2, f1, rne
    fmv.x.w t1, f3
    li   t2, 0x3f400000
    bne  t1, t2, fail

    li   t0, 0x3f800000
    fmv.w.x f1, t0
    li   t0, 0x33800000
    fmv.w.x f2, t0
    li   t0, 3
    csrw frm, t0
    fadd.s f3, f1, f2, dyn
    fmv.x.w t1, f3
    li   t2, 0x3f800001
    bne  t1, t2, fail
    csrw frm, zero
    csrr t1, fflags
    andi t1, t1, 1
    li   t2, 1
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
