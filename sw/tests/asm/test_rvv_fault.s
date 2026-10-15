.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    la   t0, trap_handler
    csrw mtvec, t0

    li   a0, 0x80000500
    li   t0, 0x11111111
    sw   t0, 0(a0)
    li   t0, 0x22222222
    sw   t0, 4(a0)
    li   t0, 0x33333333
    sw   t0, 8(a0)
    li   t0, 0x44444444
    sw   t0, 12(a0)

    # Deny exactly element two with a locked NA4 PMP entry.
    li   t0, 0x80000508
    srli t0, t0, 2
    csrw pmpaddr0, t0
    li   t0, 0x90
    csrw pmpcfg0, t0

    vsetvli t0, zero, e32, m1, ta, ma
vector_load:
    vle32.v v1, (a0)
    # Reaching here means the protected vector element did not fault.
    li   t0, 0xDEAD0001
    sd   t0, 0(s0)
1:  j    1b

trap_handler:
    csrr t0, mcause
    li   t1, 5
    bne  t0, t1, fail
    csrr t0, vstart
    li   t1, 2
    bne  t0, t1, fail
    csrr t0, mepc
    la   t1, vector_load
    bne  t0, t1, fail
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
2:  j    2b

fail:
    li   t0, 0xDEAD0002
    sd   t0, 0(s0)
3:  j    3b
