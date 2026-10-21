# ==============================================================================
# SDC Constraints for moon_sysctrl_subsystem
# ==============================================================================

# 1. Base Clock Definition
if {[info exists ::env(CLOCK_PERIOD)]} {
  set clk_period $::env(CLOCK_PERIOD)
} else {
  set clk_period 20.0
}

if {[info exists ::env(CLOCK_PORT)]} {
  set clk_port_name $::env(CLOCK_PORT)
} else {
  set clk_port_name "ref_clk_i"
}

set clk_port [get_ports $clk_port_name]
create_clock -name $clk_port_name -period $clk_period $clk_port
set_clock_uncertainty 0.25 [get_clocks $clk_port_name]

# 2. Input/Output Delays
set_input_delay 2.0 -clock [get_clocks $clk_port_name] [all_inputs -no_clocks]
set_output_delay 2.0 -clock [get_clocks $clk_port_name] [all_outputs]

# 3. Generated Clocks on Internal Behavioral PLL Divider Registers
# When dividers are active, clk_*_div_q divides ref_clk_i
create_generated_clock -name clk_core_div \
  -source $clk_port \
  -divide_by 2 \
  [get_pins -hierarchical -quiet *clk_core_div_q*/Q]

create_generated_clock -name clk_peri_div \
  -source $clk_port \
  -divide_by 2 \
  [get_pins -hierarchical -quiet *clk_peri_div_q*/Q]

create_generated_clock -name clk_mem_div \
  -source $clk_port \
  -divide_by 2 \
  [get_pins -hierarchical -quiet *clk_mem_div_q*/Q]

# 4. Asynchronous Clock Groups
# The generated divider clocks and reference clock are separate/multiplexed domains
set_clock_groups -asynchronous \
  -group [get_clocks $clk_port_name] \
  -group [get_clocks -quiet {clk_core_div clk_peri_div clk_mem_div}]

# 5. Cut False Timing Paths in Glitchless Clock Multiplexer (u_mux_core)
# The cross-coupled handshake between q0 (ref_clk domain) and q1 (core PLL domain)
# is an asynchronous CDC crossing with multi-stage synchronizers
set_false_path -through [get_pins -hierarchical -quiet *q0_en_neg*/Q] -to [get_pins -hierarchical -quiet *q1_meta*/D]
set_false_path -through [get_pins -hierarchical -quiet *q1_en_neg*/Q] -to [get_pins -hierarchical -quiet *q0_meta*/D]
set_false_path -from [get_pins -hierarchical -quiet *q0_en_neg*] -to [get_pins -hierarchical -quiet *q1_meta*]
set_false_path -from [get_pins -hierarchical -quiet *q1_en_neg*] -to [get_pins -hierarchical -quiet *q0_meta*]
