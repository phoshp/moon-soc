.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000200
    li   a1, 0x80000240
    li   t0, 0x40300000          # 2.75
    sw   t0, 0(a0)
    li   t0, 0xc0200000          # -2.5
    sw   t0, 4(a0)
    li   t0, 0x40700000          # 3.75
    sw   t0, 8(a0)
    li   t0, 0xbf800000          # -1.0
    sw   t0, 12(a0)

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v v1, (a0)
    csrw fflags, zero
    vfcvt.xu.f.v v2, v1
    csrr t0, fflags
    andi t0, t0, 16
    beqz t0, fail_uint_flags
    vse32.v v2, (a1)
    lwu  t0, 0(a1)
    li   t1, 3
    bne  t0, t1, fail_uint_result
    lwu  t0, 4(a1)
    bnez t0, fail_uint_result
    lwu  t0, 8(a1)
    li   t1, 4
    bne  t0, t1, fail_uint_result

    vle32.v v1, (a0)
    vfcvt.x.f.v v2, v1
    vse32.v v2, (a1)
    lw   t0, 0(a1)
    li   t1, 3
    bne  t0, t1, fail_signed_result
    lw   t0, 4(a1)
    li   t1, -2
    bne  t0, t1, fail_signed_result
    lw   t0, 8(a1)
    li   t1, 4
    bne  t0, t1, fail_signed_result

    vle32.v v1, (a0)
    vfcvt.rtz.x.f.v v2, v1
    vse32.v v2, (a1)
    lw   t0, 0(a1)
    li   t1, 2
    bne  t0, t1, fail_rtz_result

    li   t0, -3
    sw   t0, 0(a0)
    li   t0, 0xffffffff
    sw   t0, 4(a0)
    li   t0, 17
    sw   t0, 8(a0)
    vle32.v v1, (a0)
    vfcvt.f.x.v v2, v1
    vse32.v v2, (a1)
    lwu  t0, 0(a1)
    li   t1, 0xc0400000          # -3.0
    bne  t0, t1, fail_int_to_float

    vle32.v v1, (a0)
    vfcvt.f.xu.v v2, v1
    vse32.v v2, (a1)
    lwu  t0, 4(a1)
    li   t1, 0x4f800000          # rounded 2^32
    bne  t0, t1, fail_uint_to_float

    li   a0, 0x80000300
    li   a1, 0x80000320
    li   t0, 0x400c000000000000  # 3.5
    sd   t0, 0(a0)
    vsetivli t0, 1, e64, m1, ta, ma
    vle64.v v1, (a0)
    vfcvt.x.f.v v2, v1
    vse64.v v2, (a1)
    ld   t0, 0(a1)
    li   t1, 4
    bne  t0, t1, fail_double_result
    vfcvt.f.x.v v2, v2
    vse64.v v2, (a1)
    ld   t0, 0(a1)
    li   t1, 0x4010000000000000  # 4.0
    bne  t0, t1, fail_double_result

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
1:  j    1b
fail:
    li   t0, 0xDEAD00FF
    j    fail_write
fail_uint_flags:
    li   t0, 0xDEAD0001
    j    fail_write
fail_uint_result:
    li   t0, 0xDEAD0002
    j    fail_write
fail_signed_result:
    li   t0, 0xDEAD0003
    j    fail_write
fail_rtz_result:
    li   t0, 0xDEAD0004
    j    fail_write
fail_int_to_float:
    li   t0, 0xDEAD0005
    j    fail_write
fail_uint_to_float:
    li   t0, 0xDEAD0006
    j    fail_write
fail_double_result:
    li   t0, 0xDEAD0007
fail_write:
    sd   t0, 0(s0)
2:  j    2b
