# ==============================================================================
# SDC Constraints for moon_cpu_tile (PnR Implementation & Mid-PnR STA)
# ==============================================================================

# 1. Source default OpenLane/LibreLane base timing constraints
source $::env(FALLBACK_SDC)

# 2. Pre-CTS Ideal Clock Enforcement
# Mid-PnR STA (Stage 31) runs before Clock Tree Synthesis (Stage 32).
# Unpropagating the clock ensures OpenSTA treats clk_i as an ideal net
# rather than propagating delays through an unbuffered 8,000+ pin net.
unset_propagated_clock [all_clocks]
