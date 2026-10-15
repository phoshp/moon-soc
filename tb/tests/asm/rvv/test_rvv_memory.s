.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   s1, 1
    li   a0, 0x80000200
    li   t0, 0x11223344
    sw   t0, 0(a0)
    li   t0, 0x55667788
    sw   t0, 4(a0)
    li   t0, 0x99aabbcc
    sw   t0, 8(a0)
    li   t0, 0xddeeff00
    sw   t0, 12(a0)

    vsetvli t0, zero, e32, m1, ta, ma
    li   a1, 4
    bne  t0, a1, fail
    vle32.v v1, (a0)

    # Unmasked unit-stride store round-trip.
    li   s1, 2
    li   a1, 0x80000220
    vse32.v v1, (a1)
    li   s1, 21
    lwu  t0, 0(a1)
    li   t1, 0x11223344
    bne  t0, t1, fail
    li   s1, 22
    lwu  t0, 4(a1)
    li   t1, 0x55667788
    bne  t0, t1, fail
    li   s1, 23
    lwu  t0, 8(a1)
    li   t1, 0x99aabbcc
    bne  t0, t1, fail
    li   s1, 24
    lwu  t0, 12(a1)
    li   t1, 0xddeeff00
    bne  t0, t1, fail

    # Masked load leaves masked-off destination elements unchanged.
    li   s1, 3
    vsetvli t0, zero, e32, m1, tu, mu
    li   t0, 0x5a5a5a5a
    vmv.v.x v2, t0
    li   t0, 5
    vmv.v.x v0, t0
    vle32.v v2, (a0), v0.t
    li   a1, 0x80000240
    vse32.v v2, (a1)
    li   s1, 31
    lwu  t0, 0(a1)
    li   t1, 0x11223344
    bne  t0, t1, fail
    li   s1, 32
    lwu  t0, 4(a1)
    li   t1, 0x5a5a5a5a
    bne  t0, t1, fail
    li   s1, 33
    lwu  t0, 8(a1)
    li   t1, 0x99aabbcc
    bne  t0, t1, fail
    li   s1, 34
    lwu  t0, 12(a1)
    li   t1, 0x5a5a5a5a
    bne  t0, t1, fail

    # Masked store updates only active elements.
    li   s1, 4
    li   t0, 0xdeadbeef
    sw   t0, 0(a1)
    sw   t0, 4(a1)
    sw   t0, 8(a1)
    sw   t0, 12(a1)
    vse32.v v1, (a1), v0.t
    lwu  t0, 0(a1)
    li   t1, 0x11223344
    bne  t0, t1, fail
    lwu  t0, 4(a1)
    li   t1, 0xdeadbeef
    bne  t0, t1, fail
    lwu  t0, 8(a1)
    li   t1, 0x99aabbcc
    bne  t0, t1, fail
    lwu  t0, 12(a1)
    li   t1, 0xdeadbeef
    bne  t0, t1, fail

    # Strided loads and stores support positive and negative byte strides.
    li   s1, 7
    li   a0, 0x80000300
    li   t0, 0x01020304
    sw   t0, 0(a0)
    li   t0, 0x11121314
    sw   t0, 8(a0)
    li   t0, 0x21222324
    sw   t0, 16(a0)
    li   t0, 0x31323334
    sw   t0, 24(a0)
    li   a2, 8
    vlse32.v v5, (a0), a2
    li   a1, 0x80000340
    vsse32.v v5, (a1), a2
    li   s1, 71
    lwu  t0, 0(a1)
    li   t1, 0x01020304
    bne  t0, t1, fail
    li   s1, 72
    lwu  t0, 8(a1)
    li   t1, 0x11121314
    bne  t0, t1, fail
    li   s1, 73
    lwu  t0, 16(a1)
    li   t1, 0x21222324
    bne  t0, t1, fail
    li   s1, 74
    lwu  t0, 24(a1)
    li   t1, 0x31323334
    bne  t0, t1, fail

    li   a0, 0x80000318
    li   a2, -8
    vlse32.v v6, (a0), a2
    li   a1, 0x80000380
    vse32.v v6, (a1)
    li   s1, 81
    lwu  t0, 0(a1)
    li   t1, 0x31323334
    bne  t0, t1, fail
    li   s1, 82
    lwu  t0, 4(a1)
    li   t1, 0x21222324
    bne  t0, t1, fail
    li   s1, 83
    lwu  t0, 8(a1)
    li   t1, 0x11121314
    bne  t0, t1, fail
    li   s1, 84
    lwu  t0, 12(a1)
    li   t1, 0x01020304
    bne  t0, t1, fail

    # Indexed loads and stores use byte offsets from a vector index register.
    li   s1, 9
    li   a2, 0x80000400
    li   t0, 0
    sw   t0, 0(a2)
    li   t0, 8
    sw   t0, 4(a2)
    li   t0, 16
    sw   t0, 8(a2)
    li   t0, 24
    sw   t0, 12(a2)
    vsetvli t0, zero, e32, m1, ta, ma
    vle32.v v7, (a2)
    li   a0, 0x80000300
    vluxei32.v v8, (a0), v7
    li   a1, 0x80000440
    vse32.v v8, (a1)
    li   t1, 0x01020304
    lwu  t0, 0(a1)
    bne  t0, t1, fail
    li   t1, 0x11121314
    lwu  t0, 4(a1)
    bne  t0, t1, fail
    li   t1, 0x21222324
    lwu  t0, 8(a1)
    bne  t0, t1, fail
    li   t1, 0x31323334
    lwu  t0, 12(a1)
    bne  t0, t1, fail
    li   a1, 0x80000480
    vsoxei32.v v8, (a1), v7
    li   t1, 0x01020304
    lwu  t0, 0(a1)
    bne  t0, t1, fail
    li   t1, 0x11121314
    lwu  t0, 8(a1)
    bne  t0, t1, fail
    li   t1, 0x21222324
    lwu  t0, 16(a1)
    bne  t0, t1, fail
    li   t1, 0x31323334
    lwu  t0, 24(a1)
    bne  t0, t1, fail

    # Byte-width vector memory transfers cover the full VLEN=128 register.
    li   s1, 5
    vsetvli t0, zero, e8, m1, ta, ma
    li   a1, 16
    bne  t0, a1, fail
    li   t0, 0x6d
    vmv.v.x v3, t0
    li   a1, 0x80000260
    vse8.v v3, (a1)
    li   t2, 16
    li   t3, 0
1:
    lbu  t0, 0(a1)
    li   t1, 0x6d
    bne  t0, t1, fail
    addi a1, a1, 1
    addi t3, t3, 1
    bltu t3, t2, 1b

    # Doubleword unit-stride load/store covers both VLEN lanes.
    li   s1, 6
    li   t0, 0x0123456789abcdef
    sd   t0, 0(a0)
    li   t0, 0xfedcba9876543210
    sd   t0, 8(a0)
    vsetvli t0, zero, e64, m1, ta, ma
    li   a1, 2
    bne  t0, a1, fail
    vle64.v v4, (a0)
    li   a1, 0x80000280
    vse64.v v4, (a1)
    ld   t0, 0(a1)
    li   t1, 0x0123456789abcdef
    bne  t0, t1, fail
    ld   t0, 8(a1)
    li   t1, 0xfedcba9876543210
    bne  t0, t1, fail

pass:
    li   t0, 0xCAFEBABE
    sw   t0, 0(s0)
    j    pass

fail:
    sw   s1, 0(s0)
    j    fail
