.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000200
    li   a1, 0x80000300

    # Source floats: 1.5, -2.5, 3.75, and 4.5.
    li   t0, 0x3fc00000
    sw   t0, 0(a0)
    li   t0, 0xc0200000
    sw   t0, 4(a0)
    li   t0, 0x40700000
    sw   t0, 8(a0)
    li   t0, 0x40900000
    sw   t0, 12(a0)

    # Widen float to signed 64-bit integer, round to nearest even.
    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v v2, (a0)
    vfwcvt.x.f.v v4, v2
    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v v4, (a1)
    addi t1, a1, 16
    vse64.v v5, (t1)
    ld   t0, 0(a1)
    li   t2, 2
    bne  t0, t2, fail_signed
    ld   t0, 8(a1)
    li   t2, -2
    bne  t0, t2, fail_signed
    ld   t0, 16(a1)
    li   t2, 4
    bne  t0, t2, fail_signed
    ld   t0, 24(a1)
    li   t2, 4
    bne  t0, t2, fail_signed

    # Widen float to unsigned 64-bit integer and report invalid values.
    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v v2, (a0)
    csrw fflags, zero
    vfwcvt.xu.f.v v4, v2
    csrr t0, fflags
    andi t0, t0, 16
    beqz t0, fail_unsigned_flags
    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v v4, (a1)
    addi t1, a1, 16
    vse64.v v5, (t1)
    ld   t0, 0(a1)
    li   t2, 2
    bne  t0, t2, fail_unsigned
    ld   t0, 8(a1)
    bnez t0, fail_unsigned
    ld   t0, 16(a1)
    li   t2, 4
    bne  t0, t2, fail_unsigned
    ld   t0, 24(a1)
    li   t2, 4
    bne  t0, t2, fail_unsigned

    # The RTZ conversions truncate positive and negative fractions.
    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v v2, (a0)
    vfwcvt.rtz.x.f.v v4, v2
    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v v4, (a1)
    addi t1, a1, 16
    vse64.v v5, (t1)
    ld   t0, 0(a1)
    li   t2, 1
    bne  t0, t2, fail_rtz_signed
    ld   t0, 8(a1)
    li   t2, -2
    bne  t0, t2, fail_rtz_signed
    ld   t0, 16(a1)
    li   t2, 3
    bne  t0, t2, fail_rtz_signed

    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v v2, (a0)
    vfwcvt.rtz.xu.f.v v4, v2
    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v v4, (a1)
    addi t1, a1, 16
    vse64.v v5, (t1)
    ld   t0, 0(a1)
    li   t2, 1
    bne  t0, t2, fail_rtz_unsigned
    ld   t0, 8(a1)
    bnez t0, fail_rtz_unsigned
    ld   t0, 16(a1)
    li   t2, 3
    bne  t0, t2, fail_rtz_unsigned

    # Widen narrow unsigned and signed integers to double precision.
    li   t0, 0xffffffff
    sw   t0, 0(a0)
    li   t0, 0x01000001
    sw   t0, 4(a0)
    li   t0, 12
    sw   t0, 8(a0)
    li   t0, 3
    sw   t0, 12(a0)
    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v v2, (a0)
    vfwcvt.f.xu.v v4, v2
    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v v4, (a1)
    addi t1, a1, 16
    vse64.v v5, (t1)
    ld   t0, 0(a1)
    li   t2, 0x41efffffffe00000  # 4294967295.0
    bne  t0, t2, fail_unsigned_fp
    ld   t0, 8(a1)
    li   t2, 0x4170000010000000  # 16777217.0
    bne  t0, t2, fail_unsigned_fp

    li   t0, -3
    sw   t0, 0(a0)
    li   t0, 17
    sw   t0, 4(a0)
    li   t0, -7
    sw   t0, 8(a0)
    li   t0, 4
    sw   t0, 12(a0)
    vsetivli t0, 4, e32, m1, ta, ma
    vle32.v v2, (a0)
    vfwcvt.f.x.v v4, v2
    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v v4, (a1)
    addi t1, a1, 16
    vse64.v v5, (t1)
    ld   t0, 0(a1)
    li   t2, 0xc008000000000000  # -3.0
    bne  t0, t2, fail_signed_fp
    ld   t0, 8(a1)
    li   t2, 0x4031000000000000  # 17.0
    bne  t0, t2, fail_signed_fp

    # Widen binary32 to binary64 exactly, including a tail-agnostic lane.
    li   t0, 0x3fc00000
    sw   t0, 0(a0)
    li   t0, 0xc0200000
    sw   t0, 4(a0)
    li   t0, 0x40700000
    sw   t0, 8(a0)
    li   t0, 0x40900000
    sw   t0, 12(a0)
    vsetivli t0, 3, e32, m1, ta, ma
    vle32.v v2, (a0)
    vfwcvt.f.f.v v4, v2
    vsetivli t0, 2, e64, m1, ta, ma
    vse64.v v4, (a1)
    addi t1, a1, 16
    vse64.v v5, (t1)
    ld   t0, 0(a1)
    li   t2, 0x3ff8000000000000  # 1.5
    bne  t0, t2, fail_float_fp
    ld   t0, 8(a1)
    li   t2, 0xc004000000000000  # -2.5
    bne  t0, t2, fail_float_fp
    ld   t0, 16(a1)
    li   t2, 0x400e000000000000  # 3.75
    bne  t0, t2, fail_float_fp
    ld   t0, 24(a1)
    li   t2, -1
    bne  t0, t2, fail_float_fp

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
1:  j    1b

fail_signed:         li t0, 0xDEAD0001; j fail
fail_unsigned:       li t0, 0xDEAD0002; j fail
fail_unsigned_flags: li t0, 0xDEAD0003; j fail
fail_rtz_signed:     li t0, 0xDEAD0004; j fail
fail_rtz_unsigned:   li t0, 0xDEAD0005; j fail
fail_unsigned_fp:    li t0, 0xDEAD0006; j fail
fail_signed_fp:      li t0, 0xDEAD0007; j fail
fail_float_fp:       li t0, 0xDEAD0008; j fail
fail:
    sd   t0, 0(s0)
fail_loop:
2:  j    2b
