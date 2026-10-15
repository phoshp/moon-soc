.section .text
.globl _start
.option norvc

_start:
    # Root table identity-maps boot ROM and high RAM; add a two-page region
    # with only its first page initially mapped.
    li   s0, 0x80004000
    li   t0, 0xcf
    sd   t0, 0(s0)
    li   t0, 0x200000cf
    sd   t0, 16(s0)
    li   t1, 4080
    add  t1, s0, t1
    sd   t0, 0(t1)
    li   t0, 0x20001401
    sd   t0, 8(s0)

    li   s1, 0x80005000
    li   t0, 0x20001801
    sd   t0, 0(s1)

    li   s1, 0x80006000
    li   t0, 0x20001cc7       # VA 0x40000000 -> PA 0x80007000, leaf RWAD
    sd   t0, 0(s1)
    sd   zero, 8(s1)

    # Data for lanes zero and one are in the mapped page. Lanes two and three
    # are in the next physical page, which is mapped by the trap handler.
    li   a2, 0x80007ff8
    li   t0, 0x11111111
    sw   t0, 0(a2)
    li   t0, 0x22222222
    sw   t0, 4(a2)
    li   a2, 0x80008000
    li   t0, 0x33333333
    sw   t0, 0(a2)
    li   t0, 0x44444444
    sw   t0, 4(a2)

    # Enable Sv39 and enter S-mode with a machine-mode fault handler.
    li   t0, 8
    slli t0, t0, 60
    li   t1, 0x80004
    or   t0, t0, t1
    csrw satp, t0
    la   t0, trap_handler
    csrw mtvec, t0
    la   t0, supervisor_test
    csrw mepc, t0
    li   t0, (1 << 11) | (1 << 7)
    csrw mstatus, t0
    mret

supervisor_test:
    li   s1, 0
    li   a0, 0x40000ff8
    vsetvli t0, zero, e32, m1, ta, ma
vector_load:
    vle32.v v1, (a0)

    # The resumed instruction must finish all four lanes and clear vstart.
    li   t1, 1
    bne  s1, t1, fail
    csrr t0, vstart
    bne  t0, zero, fail
    li   a1, 0x40000000
    vse32.v v1, (a1)
    lwu  t0, 0(a1)
    li   t1, 0x11111111
    bne  t0, t1, fail
    lwu  t0, 4(a1)
    li   t1, 0x22222222
    bne  t0, t1, fail
    lwu  t0, 8(a1)
    li   t1, 0x33333333
    bne  t0, t1, fail
    lwu  t0, 12(a1)
    li   t1, 0x44444444
    bne  t0, t1, fail
    li   t0, 0x80001000
    li   t1, 0xCAFEBABE
    sd   t1, 0(t0)
4:  j    4b

trap_handler:
    csrr t0, mcause
    li   t1, 13
    bne  t0, t1, fail
    csrr t0, vstart
    li   t1, 2
    bne  t0, t1, fail
    csrr t0, mepc
    la   t1, vector_load
    bne  t0, t1, fail

    # Map the faulting page, flush the translation, and resume at the faulting
    # vector instruction. Its retained vstart skips lanes zero and one.
    li   t0, 0x200020c7       # VA 0x40001000 -> PA 0x80008000, leaf RWAD
    li   t1, 0x80006008
    sd   t0, 0(t1)
    sfence.vma zero, zero
    addi s1, s1, 1
    mret

fail:
    li   t0, 0x80001000
    li   t1, 0xDEAD0001
    sd   t1, 0(t0)
5:  j    5b
