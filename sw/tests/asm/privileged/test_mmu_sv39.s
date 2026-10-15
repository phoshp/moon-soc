# ============================================================================
# File: sw/tests/asm/privileged/test_mmu_sv39.s
# Description: Self-checking directed test suite for RISC-V RVA23 Sv39 Virtual
#              Memory Translation:
#              - Construction of 3-level Sv39 page tables in memory
#              - 1GB Gigapage and 2MB Megapage leaf PTEs
#              - Configuration of satp (MODE=8, PPN=Root Table)
#              - Transition to Supervisor Mode with Sv39 active
#              - Hardware Page Table Walker (PTW) execution
#              - Virtual-to-Physical translation and memory validation
#              - SFENCE.VMA TLB invalidation
# ============================================================================

.section .text
.globl _start

_start:
    # -------------------------------------------------------------------------
    # 1. Construct Sv39 Page Tables in System RAM (M-mode)
    # Root Page Table at 0x8000_4000
    # Level 1 Page Table at 0x8000_5000
    # -------------------------------------------------------------------------
    li   s0, 0x80004000         # Root Table base

    # Clear 4KB Root Table (512 x 8-byte entries)
    li   t0, 0
    li   t1, 512
clear_root:
    sd   zero, 0(s0)
    addi s0, s0, 8
    addi t0, t0, 1
    blt  t0, t1, clear_root

    li   s0, 0x80004000         # Restore Root Table base

    # Entry 0 (VPN[2] = 0: 0x0000_0000 .. 0x3FFF_FFFF):
    # Identity-map 1GB Gigapage to PA 0x0000_0000 (covers Boot ROM, CLINT, UART, PLIC)
    # PTE = (0x0000_0000 >> 12 << 10) | 0xCF = 0xCF (R,W,X,U,A,D,V)
    li   t2, 0xCF
    sd   t2, 0(s0)

    # Entry 2 (VPN[2] = 2: 0x8000_0000 .. 0xBFFF_FFFF) and Entry 510 (Sign-Extended):
    # Identity-map 1GB Gigapage to PA 0x8000_0000 (covers System RAM & test status)
    # PPN = 0x8000_0000 >> 12 = 0x80000.
    # PTE = (0x80000 << 10) | 0xCF = 0x200000CF
    li   t2, 0x200000CF
    sd   t2, 16(s0)             # Entry 2 = offset 16 (2 * 8 bytes)
    li   t3, 4080               # Entry 510 = offset 510 * 8 = 4080 (sign-extended VA)
    add  t3, s0, t3
    sd   t2, 0(t3)

    # Entry 1 (VPN[2] = 1: 0x4000_0000 .. 0x7FFF_FFFF):
    # Pointer to Level 1 Page Table at 0x8000_5000
    # PPN = 0x8000_5000 >> 12 = 0x80005.
    # PTE = (0x80005 << 10) | 0x01 (V=1, R=0, W=0, X=0 -> Next level pointer!)
    # PTE = 0x20001401
    li   t2, 0x20001401
    sd   t2, 8(s0)              # Entry 1 = offset 8

    # Setup Level 1 Page Table at 0x8000_5000
    li   s1, 0x80005000
    li   t0, 0
    li   t1, 512
clear_l1:
    sd   zero, 0(s1)
    addi s1, s1, 8
    addi t0, t0, 1
    blt  t0, t1, clear_l1

    li   s1, 0x80005000         # Restore L1 Table base

    # Map VA 0x4000_0000 (VPN[1] = 0 in L1 table) to PA 0x7000_0000 (On-Chip SRAM!)
    # PPN = 0x7000_0000 >> 12 = 0x70000.
    # Leaf 2MB Megapage: PTE = (0x70000 << 10) | 0xCF = 0x1C0000CF
    li   t2, 0x1C0000CF
    sd   t2, 0(s1)

    # -------------------------------------------------------------------------
    # 2. Configure satp & PMP
    # satp.MODE = 8 (Sv39), satp.PPN = 0x8000_4000 >> 12 = 0x80004
    # satp = (8 << 60) | 0x80004
    # -------------------------------------------------------------------------
    li   t0, 8
    slli t0, t0, 60
    li   t1, 0x80004
    or   t0, t0, t1
    csrw satp, t0

    # -------------------------------------------------------------------------
    # 3. Transition from M-mode to S-mode via mret
    # -------------------------------------------------------------------------
    # Clear MPP bit 12, set bit 11 (PRV_S) and MPIE (bit 7)
    li   t0, (1 << 12)
    csrc mstatus, t0
    li   t0, (1 << 11) | (1 << 7)
    csrs mstatus, t0

    la   t1, smode_mmu_test
    csrw mepc, t1

    # Enter Supervisor Mode with Sv39 translation active!
    mret

smode_mmu_test:
    # -------------------------------------------------------------------------
    # 4. S-mode Virtual Memory Execution & Access
    # We are executing in S-mode with satp.MODE = 8 (Sv39)!
    # -------------------------------------------------------------------------
    # Test 1: Write to virtual address 0x4000_0000 (mapped to physical SRAM 0x7000_0000)
    li   a0, 0x40000000
    li   a1, 0x12345678
    sd   a1, 0(a0)

    # Read back through virtual address 0x4000_0000
    ld   a2, 0(a0)
    bne  a2, a1, fail_vaddr_read

    # Test 2: Invalidate TLB with SFENCE.VMA
    sfence.vma zero, zero

    # Read back again (will trigger PTW refill into DTLB)
    ld   a3, 0(a0)
    bne  a3, a1, fail_sfence_refill

    # -------------------------------------------------------------------------
    # All Sv39 MMU tests passed! Write CAFEBABE to 0x8000_1000
    # (0x8000_1000 is identity-mapped via 1GB gigapage entry 2)
    # -------------------------------------------------------------------------
    .option push
    .option norvc
    li   a2, 0x80001000         # Keep the sentinel in the positive Sv39 low half
    li   a3, 0xCAFEBABE
    sw   a3, 0(a2)
    .option pop

pass_loop:
    j    pass_loop

# Failure Handlers
fail_vaddr_read:    li gp, 1; j fail_loop
fail_sfence_refill: li gp, 2; j fail_loop

fail_loop:
    li   a2, 0x80001000         # Keep the sentinel in the positive Sv39 low half
    lui  a4, 0xDEAD0
    or   a4, a4, gp
    sw   a4, 0(a2)
hang:
    j    hang
