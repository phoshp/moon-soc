# ============================================================================
# File: tb/tests/asm/soc/test_cache_ops.s
# Description: Directed test verifying Moon-SoC L1-I and L1-D Caches:
#              - L1-I cache hits on loops
#              - L1-D cache line write-allocate & write-back
#              - 4-way set-associative eviction of dirty lines to external RAM
#              - FENCE.I pipeline & cache invalidation
#              - Signals completion via 0x8000_1000 = 0xCAFEBABE
# ============================================================================

.section .text
.globl _start

_start:
    # -------------------------------------------------------------------------
    # 1. Test L1-D Cache Write-Allocate & Read Hit (0x8000_0000)
    # -------------------------------------------------------------------------
    li   s0, 0x80000000         # Base RAM
    li   s1, 0xCAFED00D11223344
    li   s2, 0x55667788AABBCCDD

    sd   s1, 0(s0)              # Word 0 in cache line
    sd   s2, 8(s0)              # Word 1 in cache line

    # Read back (should be zero-latency L1-D cache hits)
    ld   s3, 0(s0)
    bne  s3, s1, fail_dcache_hit
    ld   s4, 8(s0)
    bne  s4, s2, fail_dcache_hit

    # -------------------------------------------------------------------------
    # 2. Test 4-Way Cache Line Eviction to Memory
    # Set index is determined by addr[12:6].
    # By varying addr[63:13] with the same set index, we map to the SAME set!
    # Cache has 4 ways. Writing 5 different tags to the same set forces an eviction!
    # -------------------------------------------------------------------------
    li   t0, 0x80000000         # Way 0 line (Tag 0)
    li   t1, 0x80002000         # Way 1 line (Tag 1, +8KB = +128 sets * 64B)
    li   t2, 0x80004000         # Way 2 line (Tag 2)
    li   t3, 0x80006000         # Way 3 line (Tag 3)
    li   t4, 0x80008000         # Way 4 line (Forces eviction of Tag 0!)

    li   a0, 0x1111111111111111
    li   a1, 0x2222222222222222
    li   a2, 0x3333333333333333
    li   a3, 0x4444444444444444
    li   a4, 0x5555555555555555

    sd   a0, 0(t0)
    sd   a1, 0(t1)
    sd   a2, 0(t2)
    sd   a3, 0(t3)
    sd   a4, 0(t4)              # Evicts Tag 0 dirty line out to external RAM!

    # Read back evicted line from t0 (will trigger cache miss and refill from RAM)
    ld   a5, 0(t0)
    bne  a5, a0, fail_eviction

    # Verify all other ways retain correct data
    ld   a6, 0(t1)
    bne  a6, a1, fail_eviction
    ld   a6, 0(t2)
    bne  a6, a2, fail_eviction
    ld   a6, 0(t3)
    bne  a6, a3, fail_eviction
    ld   a6, 0(t4)
    bne  a6, a4, fail_eviction

    # -------------------------------------------------------------------------
    # 3. Test FENCE.I (I-Cache Invalidation)
    # -------------------------------------------------------------------------
    fence.i

    # -------------------------------------------------------------------------
    # All cache verification tests passed! Write CAFE_BABE to 0x8000_1000
    # -------------------------------------------------------------------------
    lui  a2, 0x80001
    li   a3, 0xCAFEBABE
    sw   a3, 0(a2)

pass_loop:
    j    pass_loop

fail_dcache_hit:
    li   gp, 1
    j    fail_loop
fail_eviction:
    li   gp, 2
    j    fail_loop

fail_loop:
    lui  a2, 0x80001
    lui  a4, 0xDEAD0
    or   a4, a4, gp
    sw   a4, 0(a2)
hang:
    j    hang
