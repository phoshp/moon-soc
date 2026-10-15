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
