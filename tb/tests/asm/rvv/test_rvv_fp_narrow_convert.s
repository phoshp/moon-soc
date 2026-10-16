.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   a0, 0x80000200
    li   a1, 0x80000300

    # Source doubles: 1.5, -2.5, 3.75, 4.5
    li   t0, 0x3ff8000000000000  # 1.5
    sd   t0, 0(a0)
    li   t0, 0xc004000000000000  # -2.5
    sd   t0, 8(a0)
    li   t0, 0x400e000000000000  # 3.75
    sd   t0, 16(a0)
    li   t0, 0x4012000000000000  # 4.5
    sd   t0, 24(a0)

    # 1. Narrow double to signed 32-bit int (RNE)
    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v v4, (a0)
    addi t1, a0, 16
    vle64.v v5, (t1)

    vsetivli t0, 4, e32, m1, ta, ma
    vfncvt.x.f.w v2, v4
    vse32.v v2, (a1)

    lw   t0, 0(a1)
    li   t2, 2
    bne  t0, t2, fail_signed
    lw   t0, 4(a1)
    li   t2, -2
    bne  t0, t2, fail_signed
    lw   t0, 8(a1)
    li   t2, 4
    bne  t0, t2, fail_signed
    lw   t0, 12(a1)
    li   t2, 4
    bne  t0, t2, fail_signed

    # 2. Narrow double to unsigned 32-bit int and check NV flag
    csrw fflags, zero
    vsetivli t0, 4, e32, m1, ta, ma
    vfncvt.xu.f.w v2, v4
    csrr t0, fflags
    andi t0, t0, 16
    beqz t0, fail_unsigned_flags

    vse32.v v2, (a1)
    lwu  t0, 0(a1)
    li   t2, 2
    bne  t0, t2, fail_unsigned
    lwu  t0, 4(a1)
    bnez t0, fail_unsigned
    lwu  t0, 8(a1)
    li   t2, 4
    bne  t0, t2, fail_unsigned
    lwu  t0, 12(a1)
    li   t2, 4
    bne  t0, t2, fail_unsigned

    # 3. RTZ conversions: 1.9, -2.9, 3.1, -4.1
    li   t0, 0x3ffe666666666666  # 1.9
    sd   t0, 0(a0)
    li   t0, 0xc007333333333333  # -2.9
    sd   t0, 8(a0)
    li   t0, 0x4008cccccccccccd  # 3.1
    sd   t0, 16(a0)
    li   t0, 0xc010666666666666  # -4.1
    sd   t0, 24(a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v v4, (a0)
    addi t1, a0, 16
    vle64.v v5, (t1)

    vsetivli t0, 4, e32, m1, ta, ma
    vfncvt.rtz.x.f.w v2, v4
    vse32.v v2, (a1)

    lw   t0, 0(a1)
    li   t2, 1
    bne  t0, t2, fail_rtz_signed
    lw   t0, 4(a1)
    li   t2, -2
    bne  t0, t2, fail_rtz_signed
    lw   t0, 8(a1)
    li   t2, 3
    bne  t0, t2, fail_rtz_signed
    lw   t0, 12(a1)
    li   t2, -4
    bne  t0, t2, fail_rtz_signed

    # 4. RTZ unsigned
    vsetivli t0, 4, e32, m1, ta, ma
    vfncvt.rtz.xu.f.w v2, v4
    vse32.v v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 1
    bne  t0, t2, fail_rtz_unsigned
    lwu  t0, 4(a1)
    bnez t0, fail_rtz_unsigned
    lwu  t0, 8(a1)
    li   t2, 3
    bne  t0, t2, fail_rtz_unsigned
    lwu  t0, 12(a1)
    bnez t0, fail_rtz_unsigned

    # 5. Narrow 64-bit signed int to 32-bit float
    li   t0, -3
    sd   t0, 0(a0)
    li   t0, 17
    sd   t0, 8(a0)
    li   t0, -7
    sd   t0, 16(a0)
    li   t0, 4
    sd   t0, 24(a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v v4, (a0)
    addi t1, a0, 16
    vle64.v v5, (t1)

    vsetivli t0, 4, e32, m1, ta, ma
    vfncvt.f.x.w v2, v4
    vse32.v v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0xc0400000  # -3.0f
    bne  t0, t2, fail_signed_fp
    lwu  t0, 4(a1)
    li   t2, 0x41880000  # 17.0f
    bne  t0, t2, fail_signed_fp
    lwu  t0, 8(a1)
    li   t2, 0xc0e00000  # -7.0f
    bne  t0, t2, fail_signed_fp
    lwu  t0, 12(a1)
    li   t2, 0x40800000  # 4.0f
    bne  t0, t2, fail_signed_fp

    # 6. Narrow 64-bit unsigned int to 32-bit float
    li   t0, -1
    srli t0, t0, 32
    sd   t0, 0(a0)
    li   t0, 0x01000001
    sd   t0, 8(a0)
    li   t0, 12
    sd   t0, 16(a0)
    li   t0, 3
    sd   t0, 24(a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v v4, (a0)
    addi t1, a0, 16
    vle64.v v5, (t1)

    vsetivli t0, 4, e32, m1, ta, ma
    vfncvt.f.xu.w v2, v4
    vse32.v v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x4f800000  # 4294967295.0f
    bne  t0, t2, fail_unsigned_fp
    lwu  t0, 4(a1)
    li   t2, 0x4b800000  # 16777217.0f rounds to 16777216.0f (RNE)
    bne  t0, t2, fail_unsigned_fp
    lwu  t0, 8(a1)
    li   t2, 0x41400000  # 12.0f
    bne  t0, t2, fail_unsigned_fp
    lwu  t0, 12(a1)
    li   t2, 0x40400000  # 3.0f
    bne  t0, t2, fail_unsigned_fp

    # 7. Narrow binary64 to binary32 with tail-agnostic VL=3
    li   t0, 0x3ff8000000000000  # 1.5
    sd   t0, 0(a0)
    li   t0, 0xc004000000000000  # -2.5
    sd   t0, 8(a0)
    li   t0, 0x400e000000000000  # 3.75
    sd   t0, 16(a0)
    li   t0, 0x4012000000000000  # 4.5
    sd   t0, 24(a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v v4, (a0)
    addi t1, a0, 16
    vle64.v v5, (t1)

    vsetivli t0, 3, e32, m1, ta, ma
    vfncvt.f.f.w v2, v4
    vsetivli t0, 4, e32, m1, ta, ma
    vse32.v v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x3fc00000  # 1.5f
    bne  t0, t2, fail_float_fp
    lwu  t0, 4(a1)
    li   t2, 0xc0200000  # -2.5f
    bne  t0, t2, fail_float_fp
    lwu  t0, 8(a1)
    li   t2, 0x40700000  # 3.75f
    bne  t0, t2, fail_float_fp
    lwu  t0, 12(a1)
    li   t2, 0xffffffff  # tail agnostic 0xffffffff
    bne  t0, t2, fail_float_fp

    # 8. Narrow binary64 to binary32 round-to-odd (jamming)
    # 1.0 + 2^(-24): bit 28 of double mantissa is set -> discarded bit sets LSB=1
    li   t0, 0x3ff0000010000000
    sd   t0, 0(a0)
    # 1.0 exact: no bits discarded -> LSB remains 0
    li   t0, 0x3ff0000000000000
    sd   t0, 8(a0)
    # 1.0 + 2^(-23): bit 29 of double mantissa is set -> already odd in float
    li   t0, 0x3ff0000020000000
    sd   t0, 16(a0)
    li   t0, 0x4000000000000000  # 2.0 exact
    sd   t0, 24(a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v v4, (a0)
    addi t1, a0, 16
    vle64.v v5, (t1)

    vsetivli t0, 4, e32, m1, ta, ma
    vfncvt.rod.f.f.w v2, v4
    vse32.v v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x3f800001  # LSB jammed to 1
    bne  t0, t2, fail_rod
    lwu  t0, 4(a1)
    li   t2, 0x3f800000  # exact, LSB=0
    bne  t0, t2, fail_rod
    lwu  t0, 8(a1)
    li   t2, 0x3f800001  # LSB=1
    bne  t0, t2, fail_rod
    lwu  t0, 12(a1)
    li   t2, 0x40000000  # 2.0f
    bne  t0, t2, fail_rod

    # 9. Masked narrowing conversion
    # Source doubles: 1.5, -2.5, 3.75, 4.5
    li   t0, 0x3ff8000000000000
    sd   t0, 0(a0)
    li   t0, 0xc004000000000000
    sd   t0, 8(a0)
    li   t0, 0x400e000000000000
    sd   t0, 16(a0)
    li   t0, 0x4012000000000000
    sd   t0, 24(a0)

    vsetivli t0, 2, e64, m1, ta, ma
    vle64.v v4, (a0)
    addi t1, a0, 16
    vle64.v v5, (t1)

    # Initialize destination with marker 0x55555555
    li   t0, 0x55555555
    sw   t0, 0(a1)
    sw   t0, 4(a1)
    sw   t0, 8(a1)
    sw   t0, 12(a1)
    vsetivli t0, 4, e32, m1, tu, mu
    vle32.v v2, (a1)

    # Set mask in v0: lanes 0 and 2 enabled (0b0101 = 5)
    li   t0, 5
    sb   t0, 0(a0)
    vlm.v v0, (a0)
    vsetivli t1, 4, e32, m1, tu, mu

    # Execute masked: vfncvt.f.f.w v2, v4, v0.t
    vfncvt.f.f.w v2, v4, v0.t
    vse32.v v2, (a1)

    lwu  t0, 0(a1)
    li   t2, 0x3fc00000  # 1.5f (active)
    bne  t0, t2, fail_masked
    lwu  t0, 4(a1)
    li   t2, 0x55555555  # undisturbed
    bne  t0, t2, fail_masked
    lwu  t0, 8(a1)
    li   t2, 0x40700000  # 3.75f (active)
    bne  t0, t2, fail_masked
    lwu  t0, 12(a1)
    li   t2, 0x55555555  # undisturbed
    bne  t0, t2, fail_masked

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
1:  j    1b

fail_signed:         li t0, 0xDEAD0001; j fail
fail_unsigned:       li t0, 0xDEAD0002; j fail
fail_unsigned_flags: li t0, 0xDEAD0003; j fail
fail_rtz_signed:     li t0, 0xDEAD0004; j fail
fail_rtz_unsigned:   li t0, 0xDEAD0005; j fail
fail_signed_fp:      li t0, 0xDEAD0006; j fail
fail_unsigned_fp:    li t0, 0xDEAD0007; j fail
fail_float_fp:       li t0, 0xDEAD0008; j fail
fail_rod:            li t0, 0xDEAD0009; j fail
fail_masked:         j fail
fail:
    sd   t0, 0(s0)
fail_loop:
2:  j    2b
