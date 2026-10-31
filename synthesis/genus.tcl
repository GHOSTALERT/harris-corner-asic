#=============================================================================
# genus_syn.tcl -- Cadence Genus synthesis for the Harris corner detector
#
# Run from the harris/ folder:
#   genus -files scripts/genus_syn.tcl -log logs/genus_slow           (slow corner, default)
#   CORNER=fast    genus -files scripts/genus_syn.tcl -log logs/genus_fast
#   CORNER=typical genus -files scripts/genus_syn.tcl -log logs/genus_typical
# Optional overrides:  CLK_PERIOD=3.0  IMG_W=64  IMG_H=64
#
# Expected layout:
#   harris/rtl/*.sv                         RTL
#   harris/synthesis/{slow,fast,typical}.lib  liberty files
#   harris/netlists/                        output netlists (created)
#   harris/reports_<corner>/                output reports  (created)
#=============================================================================

#---------------------------------------------------------------- settings
proc env_or {name default} {
  if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
  return $default
}

set design     harris_top
set corner     [env_or CORNER     slow]      ;# slow | fast | typical
set clk_period [env_or CLK_PERIOD 4]      ;# ns
set img_w      [env_or IMG_W      64]
set img_h      [env_or IMG_H      64]

set lib_dir    ../synthesis
set rtl_dir    ../rtl
set rep_dir    reports_${corner}
set net_dir    netlists

# RTL in bottom-up order (harris_top last)
set rtl_files [list \
  ${rtl_dir}/window3x3.sv          \
  ${rtl_dir}/sobel_grad.sv         \
  ${rtl_dir}/gradient_products.sv  \
  ${rtl_dir}/boxsum5x5.sv          \
  ${rtl_dir}/harris_response.sv    \
  ${rtl_dir}/corner_threshold.sv   \
  ${rtl_dir}/harris_top.sv         ]

file mkdir $rep_dir $net_dir
puts "### Harris synthesis: corner=$corner  clk=${clk_period}ns  IMG=${img_w}x${img_h}"

#---------------------------------------------------------------- library + RTL
set_db init_lib_search_path $lib_dir
set_db init_hdl_search_path $rtl_dir
read_libs ../synthesis/${corner}.lib

# Keep the module hierarchy (u_win, u_box, u_resp, ...) so Innovus can place
# module guides on these instances, as planned in the floorplan.
set_db auto_ungroup none

read_hdl -sv $rtl_files

elaborate $design -parameters [list [list IMG_W $img_w] [list IMG_H $img_h]]

# Non-default parameters can make Genus rename the top (e.g. harris_top_IMG_W32...),
# so take whatever single top design was elaborated.
set top [get_db designs]
current_design $top
set dname [get_db $top .name]

check_design -unresolved > ./${rep_dir}/${design}_check_design.rpt
check_design -all       >> ./${rep_dir}/${design}_check_design.rpt

#---------------------------------------------------------------- constraints
create_clock -name clk -period $clk_period [get_ports clk]

# All inputs except the clock itself; all outputs.
set in_ports [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay  0.06 $in_ports      -clock [get_clocks clk]
set_output_delay 0.04 [all_outputs]  -clock [get_clocks clk]

set_max_transition 0.15  [current_design]
set_max_fanout     4.000 [current_design]

#---------------------------------------------------------------- synthesis
set_db syn_generic_effort high
set_db syn_map_effort     high
set_db syn_opt_effort     high

syn_generic
write_hdl > ./${net_dir}/${design}_ti_netlist_${corner}.v

syn_map
write_hdl > ./${net_dir}/${design}_tm_netlist_${corner}.v

syn_opt
write_hdl > ./${net_dir}/${design}_netlist_${corner}.v

#---------------------------------------------------------------- outputs
write_sdc > ./${net_dir}/${design}_${corner}.sdc
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge \
          > ./${net_dir}/${design}_${corner}.sdf       ;# for gate-level sim

#---------------------------------------------------------------- reports
report_area                > ./${rep_dir}/${design}_area_report.rpt
report_area -depth 3       > ./${rep_dir}/${design}_area_hier_report.rpt   ;# per instance: u_box, u_resp, ...
report_gates               > ./${rep_dir}/${design}_gates_report.rpt
report_power               > ./${rep_dir}/${design}_power_report.rpt
report_timing              > ./${rep_dir}/${design}_timing_report.rpt
report_timing -nworst 1 -max_paths 20 > ./${rep_dir}/${design}_timing_top20.rpt
report_qor                 > ./${rep_dir}/${design}_qor_report.rpt

puts "### Done: $dname, corner=$corner. Netlist: ${net_dir}/${design}_netlist_${corner}.v  Reports: ${rep_dir}/"
exit
