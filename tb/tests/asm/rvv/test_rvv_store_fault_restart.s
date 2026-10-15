.section .text
.globl _start
.option norvc

_start:
    # Root table maps the first page of the vector store target only.
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

    # Prepare the destination locations in both physical pages.
    li   a2, 0x80007ff8
    sd   zero, 0(a2)
    li   a2, 0x80008000
    sd   zero, 0(a2)

    # Enable Sv39 and enter S-mode with the M-mode store-fault handler.
    li   t0, 8
    slli t0, t0, 60
    li   t1, 0x80004
    or   t0, t0, t1
    csrw satp, t0
    la   t0, trap_handler
    csrw mtvec, t0
    la   t0, supervisor_test
    csrw mepc, t0
    li   t0, (1 << 11) | (1 << 9) | (1 << 7)
    csrw mstatus, t0
    mret

supervisor_test:
    li   s1, 0
    li   a0, 0x40000ff8
    vsetvli t0, zero, e32, m1, ta, ma
    li   t1, 0x33333333
    vmv.v.x v1, t1
vector_store:
    vse32.v v1, (a0)

    # The retried store completes at element two and clears vstart.
    li   t1, 1
    bne  s1, t1, fail1
    csrr t0, vstart
    bne  t0, zero, fail2
    lwu  t0, 0(a0)
    li   t1, 0x33333333
    bne  t0, t1, fail3
    lwu  t0, 4(a0)
    bne  t0, t1, fail4
    lwu  t0, 8(a0)
    bne  t0, t1, fail5
    lwu  t0, 12(a0)
    bne  t0, t1, fail6
    li   t0, 0x80001000
    li   t1, 0xCAFEBABE
    sd   t1, 0(t0)
4:  j    4b

trap_handler:
    csrr t0, mcause
    li   t1, 15
    bne  t0, t1, fail7
    csrr t0, vstart
    li   t1, 2
    bne  t0, t1, fail8
    csrr t0, mepc
    la   t1, vector_store
    bne  t0, t1, fail9

    # Map the faulting page and retry the original store from element two.
    li   t0, 0x200020c7       # VA 0x40001000 -> PA 0x80008000, leaf RWAD
    li   t1, 0x80006008
    sd   t0, 0(t1)
    sfence.vma zero, zero
    addi s1, s1, 1
    mret

fail1: li t0, 0xDEAD0001
       j fail_common
fail2: li t0, 0xDEAD0002
       j fail_common
fail3: li t0, 0xDEAD0003
       j fail_common
fail4: li t0, 0xDEAD0004
       j fail_common
fail5: li t0, 0xDEAD0005
       j fail_common
fail6: li t0, 0xDEAD0006
       j fail_common
fail7: li t0, 0xDEAD0007
       j fail_common
fail8: li t0, 0xDEAD0008
       j fail_common
fail9: li t0, 0xDEAD0009
fail_common:
    li   t1, 0x80001000
    sd   t0, 0(t1)
5:  j    5b
