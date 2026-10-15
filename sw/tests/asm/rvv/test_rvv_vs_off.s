.section .text
.globl _start
.option norvc

_start:
    li   s0, 0x80001000
    li   s1, 0
    la   t0, trap_handler
    csrw mtvec, t0

    # Turn vector state off, then check vector arithmetic, CSR, and memory use.
    csrr t0, mstatus
    li   t1, 0x600
    not  t1, t1
    and  t0, t0, t1
    csrw mstatus, t0
    csrr t0, mstatus
    srli t0, t0, 9
    andi t0, t0, 3
    bnez t0, fail_state
    vadd.vv v1, v2, v3
    csrr t0, vl
    vle32.v v1, (s0)

fail:
    li   t0, 0xDEAD00FF
    sd   t0, 0(s0)
1:  j    1b

trap_handler:
    csrr t0, mcause
    li   t1, 2
    bne  t0, t1, fail_cause
    csrr t2, mtval
    beqz s1, check_vadd
    li   t3, 0xc20022f3
    li   t0, 1
    beq  s1, t0, check_mtval
    li   t3, 0x02046087
    j    check_mtval
check_vadd:
    li   t3, 0x022180d7
check_mtval:
    bne  t2, t3, fail_tval
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    addi s1, s1, 1
    li   t0, 3
    bne  s1, t0, return_from_trap

pass:
    li   t0, 0xCAFEBABE
    sd   t0, 0(s0)
2:  j    2b

return_from_trap:
    mret

fail_state:
    li   t0, 0xDEAD0001
    j    fail_write
fail_cause:
    li   t0, 0xDEAD0002
    j    fail_write
fail_tval:
    li   t0, 0xDEAD0003
fail_write:
    sd   t0, 0(s0)
3:  j    3b
