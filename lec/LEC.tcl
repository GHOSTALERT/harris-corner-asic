#=============================================================================
# lec.tcl -- Conformal LEC (Tcl mode): RTL (golden) vs Genus netlist (revised)
#
# Run from the harris/ folder after scripts/genus_syn.tcl has finished:
#   lec -xl -tclmode -nogui -dofile scripts/lec.tcl                 (slow corner, default)
#   CORNER=fast    lec -xl -tclmode -nogui -dofile scripts/lec.tcl
#   CORNER=typical lec -xl -tclmode -nogui -dofile scripts/lec.tcl
#
# Inputs:  rtl/*.sv, synthesis/<corner>.lib, netlists/harris_top_netlist_<corner>.v
# Output:  reports_<corner>/harris_top_lec.log
#=============================================================================

#---------------------------------------------------------------- settings
proc env_or {name default} {
  if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
  return $default
}

set design   harris_top
set corner   [env_or CORNER  slow]       ;# slow | fast | typical
set threads  [env_or THREADS 4]

set lib_dir  ../synthesis
set rtl_dir  ../rtl
set rep_dir  reports_${corner}
set net_dir  netlists

set lib_file ${lib_dir}/${corner}.lib
set netlist  ./${lib_dir}/${net_dir}/${design}_netlist_${corner}.v

# RTL in bottom-up order (harris_top last). Default parameters IMG_W = IMG_H = 64,
# the same as genus_syn.tcl's default.
set rtl_files [list \
  ${rtl_dir}/window3x3.sv          \
  ${rtl_dir}/sobel_grad.sv         \
  ${rtl_dir}/gradient_products.sv  \
  ${rtl_dir}/boxsum5x5.sv          \
  ${rtl_dir}/harris_response.sv    \
  ${rtl_dir}/corner_threshold.sv   \
  ${rtl_dir}/harris_top.sv         ]

foreach f [concat $lib_file $netlist $rtl_files] {
  if {![file exists $f]} { puts "ERROR: missing $f"; exit -force }
}
file mkdir $rep_dir

set_log_file ./${rep_dir}/${design}_lec.log -replace
set_parallel_option -threads $threads
puts "### Harris LEC: corner=$corner  golden=RTL  revised=$netlist"

#---------------------------------------------------------------- library
read_library -liberty -both $lib_file

#---------------------------------------------------------------- golden: RTL
read_design -systemverilog -golden -noelaborate {*}$rtl_files
elaborate_design -golden -root $design

#---------------------------------------------------------------- revised: netlist
read_design -verilog -revised -noelaborate $netlist
elaborate_design -revised -root harris_top_IMG_W64_IMG_H64

report_design_data

#---------------------------------------------------------------- setup
# Flops that synthesis removed because they are constant or unloaded (e.g. the
# unused upper bits in sobel_grad / boxsum5x5) are treated as constants.
set_flatten_model -seq_constant
set_flatten_model -seq_constant_x_to 0
set_flatten_model -gated_clock

# Lets Conformal pick the right strategy for hard points automatically.
set_analyze_option -auto

#---------------------------------------------------------------- compare
set_system_mode lec

# harris_response has 25x25 / 26x26 / 52x11 multipliers and gradient_products
# has three 11x11. Without datapath analysis these often end as ABORT points.
analyze_datapath -merge -verbose

add_compared_points -all
compare

#---------------------------------------------------------------- reports
report_verification
report_statistics
report_unmapped_points -summary
report_unmapped_points -notmapped
report_compare_data -class nonequivalent -class abort

puts "### Done: corner=$corner. Log: ${rep_dir}/${design}_lec.log"
exit -force
