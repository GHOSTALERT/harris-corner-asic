read_lib ../synthesis/slow.lib
read_verilog ../synthesis/netlists/harris_top_netlist_slow.v

set_top_module harris_top_IMG_W64_IMG_H64
read_sdc ../synthesis/netlists/harris_top_slow.sdc

save_design -overwrite harris_top_demo

check_design -type timing -out_file ./reports_slow/design.rpt

check_library
check_timing
update_timing -full

report_timing
report_timing -late > ../sta/reports_slow/setup_tempus.rpt
report_timing -early > ../sta/reports_slow/hold_tempus.rpt
report_timing -max_slack 0
report_timing -early -max_slack 0 -max_paths 20
