# RV32I core OpenLane SDC
# STEP 09B: false-path debug-only observability ports.

create_clock -name clk_i -period 20.000 [get_ports clk_i]

# OpenSTA-compatible way to apply input delay to all input ports except clk_i.
set input_ports [all_inputs]
set clk_ports [get_ports clk_i]

foreach clk_port $clk_ports {
    set idx [lsearch -exact $input_ports $clk_port]
    if {$idx >= 0} {
        set input_ports [lreplace $input_ports $idx $idx]
    }
}

if {[llength $input_ports] > 0} {
    set_input_delay 4.000 -clock [get_clocks clk_i] $input_ports
}

# Apply output delay first, then false-path debug-only outputs.
set_output_delay 4.000 -clock [get_clocks clk_i] [all_outputs]

# Debug observability outputs are not functional timing endpoints.
set debug_ports [get_ports -quiet {debug_*}]
if {[llength $debug_ports] > 0} {
    set_false_path -to $debug_ports
}

# Reset is asynchronous/control-like; do not time it as normal synchronous data.
set reset_ports [get_ports -quiet {rst_ni rst_n_i rst_i reset_i reset_n_i}]
if {[llength $reset_ports] > 0} {
    set_false_path -from $reset_ports
}
