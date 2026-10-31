proc init_design_flow {} {
global init_lef_file
global init_verilog
global init_top_cell

#Read lef
set init_lef_file { /home/cadence/install/FOUNDRY/digital/90nm/dig/lef/gsclib090_translated.lef }
set init_verilog {../synthesis/netlists/harris_top_netlist_slow.v}
set init_top_cell harris_top_IMG_W64_IMG_H64
set ::init_pwr_net VDD
set ::init_gnd_net VSS

set ::init_mmmc_file mmmc.tcl

#Initialize design
init_design -setup slow_view -hold fast_view

setDesignMode -process 90

#Basic checks
checkDesign -all

#Save checkpoint
saveDesign 01_init

}

proc floorplan {} {
# restoreDesign ./01_init.dat harris_top_IMG_W64_IMG_H64
floorPlan -site gsclib090site -r 1 0.6 10.15 10.15 10.15 10.15
# editPin with -layer values only. Top/Bottom -> 2 (Metal2), Left/Right -> 3 (Metal3)
getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -side Top -layer 2 -spreadType center -spacing 1.0 -pin clk
setPinAssignMode -pinEditInBatch false
getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true
editPin -fixOverlap 1 -spreadDirection clockwise -edge 1 -layer 2 -spreadType side -pin {{k_q[0]} {k_q[1]} {k_q[2]} {k_q[3]} {k_q[4]} {k_q[5]} {k_q[6]} {k_q[7]} {k_q[8]} {k_q[9]} {k_q[10]}}
setPinAssignMode -pinEditInBatch false
zoomBox 29.43900 544.87550 1003.92550 1038.85750
fit
getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -edge 3 -layer 2 -spreadType center -spacing 1.0 -pin rst_n
setPinAssignMode -pinEditInBatch false
getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true
editPin -fixOverlap 1 -spreadDirection clockwise -edge 3 -layer 2 -spreadType side -pin {{thr[0]} {thr[1]} {thr[2]} {thr[3]} {thr[4]} {thr[5]} {thr[6]} {thr[7]} {thr[8]} {thr[9]} {thr[10]} {thr[11]} {thr[12]} {thr[13]} {thr[14]} {thr[15]} {thr[16]} {thr[17]} {thr[18]} {thr[19]} {thr[20]} {thr[21]} {thr[22]} {thr[23]} {thr[24]} {thr[25]} {thr[26]} {thr[27]} {thr[28]} {thr[29]} {thr[30]} {thr[31]} {thr[32]} {thr[33]} {thr[34]} {thr[35]} {thr[36]} {thr[37]} {thr[38]} {thr[39]} {thr[40]} {thr[41]} {thr[42]} {thr[43]} {thr[44]} {thr[45]} {thr[46]} {thr[47]} {thr[48]} {thr[49]} {thr[50]} {thr[51]} {thr[52]} {thr[53]} {thr[54]} {thr[55]} {thr[56]} {thr[57]} {thr[58]} {thr[59]} {thr[60]} {thr[61]} {thr[62]} {thr[63]}}
setPinAssignMode -pinEditInBatch false
getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -edge 0 -layer 3 -spreadType center -spacing 10 -pin {pixel_valid {pixel_in[0]} {pixel_in[1]} {pixel_in[2]} {pixel_in[3]} {pixel_in[4]} {pixel_in[5]} {pixel_in[6]} {pixel_in[7]}}
setPinAssignMode -pinEditInBatch false
getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true
editPin -fixOverlap 1 -unit MICRON -spreadDirection clockwise -edge 2 -layer 3 -spreadType center -spacing 10 -pin {corner_out {resp_dbg[0]} {resp_dbg[1]} {resp_dbg[2]} {resp_dbg[3]} {resp_dbg[4]} {resp_dbg[5]} {resp_dbg[6]} {resp_dbg[7]} {resp_dbg[8]} {resp_dbg[9]} {resp_dbg[10]} {resp_dbg[11]} {resp_dbg[12]} {resp_dbg[13]} {resp_dbg[14]} {resp_dbg[15]} {resp_dbg[16]} {resp_dbg[17]} {resp_dbg[18]} {resp_dbg[19]} {resp_dbg[20]} {resp_dbg[21]} {resp_dbg[22]} {resp_dbg[23]} {resp_dbg[24]} {resp_dbg[25]} {resp_dbg[26]} {resp_dbg[27]} {resp_dbg[28]} {resp_dbg[29]} {resp_dbg[30]} {resp_dbg[31]} {resp_dbg[32]} {resp_dbg[33]} {resp_dbg[34]} {resp_dbg[35]} {resp_dbg[36]} {resp_dbg[37]} {resp_dbg[38]} {resp_dbg[39]} {resp_dbg[40]} {resp_dbg[41]} {resp_dbg[42]} {resp_dbg[43]} {resp_dbg[44]} {resp_dbg[45]} {resp_dbg[46]} {resp_dbg[47]} {resp_dbg[48]} {resp_dbg[49]} {resp_dbg[50]} {resp_dbg[51]} {resp_dbg[52]} {resp_dbg[53]} {resp_dbg[54]} {resp_dbg[55]} {resp_dbg[56]} {resp_dbg[57]} {resp_dbg[58]} {resp_dbg[59]} {resp_dbg[60]} {resp_dbg[61]} {resp_dbg[62]} {resp_dbg[63]} corner_valid}
setPinAssignMode -pinEditInBatch false
saveDesign 02_floorplan
}

proc powerplan {} {
	globalNetConnect VDD -type pgpin -pin VDD -all
	globalNetConnect VSS -type pgpin -pin VSS -all

addRing -nets {VSS VDD} -type core_rings -follow core -layer {top Metal3 bottom Metal3 left Metal4 right Metal4} -width {top 1.8 bottom 1.8 left 1.8 right 1.8} -spacing {top 1.8 bottom 1.8 left 1.8 right 1.8} -offset {top 1.8 bottom 1.8 left 1.8 right 1.8} -center 0 -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None

addStripe -nets {VSS VDD} -layer Metal3 -direction horizontal -width 1.8 -spacing 1.8 -set_to_set_distance 60 -start_from bottom -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit Metal9 -padcore_ring_bottom_layer_limit Metal1 -block_ring_top_layer_limit Metal9 -block_ring_bottom_layer_limit Metal1 -use_wire_group 0 -snap_wire_center_to_grid None

addStripe -nets {VSS VDD} -layer Metal4 -direction vertical -width 1.8 -spacing 1.8 -set_to_set_distance 60 -start_from left -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit Metal9 -padcore_ring_bottom_layer_limit Metal1 -block_ring_top_layer_limit Metal9 -block_ring_bottom_layer_limit Metal1 -use_wire_group 0 -snap_wire_center_to_grid None

#added sroute - creates the Metal1 standard-cell rails and connects them to ring/stripes
sroute -connect {corePin} -nets {VDD VSS} -corePinTarget {firstAfterRowEnd} -allowJogging 1 -allowLayerChange 1 -layerChangeRange {Metal1(1) Metal4(4)} -crossoverViaLayerRange {Metal1(1) Metal4(4)} -targetViaLayerRange {Metal1(1) Metal4(4)}

	saveDesign 03_power
}

proc placement {} {
	# restoreDesign ./03_power.dat harris_top_IMG_W64_IMG_H64

	placeDesign

	timeDesign -preCTS -pathReports -drvReports -slackReports -numPaths 50 -prefix ALU_unit_preCTS -outDir timingReports
	setOptMode -fixCap true -fixTran true -fixFanoutLoad false
	optDesign -preCTS
	optDesign -preCTS -incr


	saveDesign 04_placement
  }

proc cts {} {
	restoreDesign ./04_placement.dat harris_top_IMG_W64_IMG_H64

	set_ccopt_property target_max_trans 0.2
	
	set_ccopt_property buffer_cells { CLKBUFX2 CLKBUFX3 CLKBUFX4 CLKBUFX6 CLKBUFX8 CLKBUFX12 CLKBUFX16 CLKBUFX20 }
	set_ccopt_property inverter_cells { CLKINVX1 CLKINVX2 CLKINVX3 CLKINVX4 CLKINVX6 CLKINVX8 CLKINVX12 CLKINVX16 CLKINVX20 }

	#Run CTS
	ccopt_design -cts
	report_ccopt_clock_trees -file cts_clock_trees.rpt
	report_ccopt_skew_groups -file cts_skew_groups.rpt

	#post-CTS
	timeDesign -postCTS -prefix postCTS -outDir ./postCTS
	timeDesign -postCTS -hold -prefix postCTS_hold -outDir ./postCTS

	optDesign -postCTS -prefix postCTS_opt -outDir ./postCTS
	optDesign -postCTS -hold -prefix postCTS_hold_opt -outDir ./postCTS

	saveDesign 05_cts
}

proc route {} {
	# CHANGED: top cell name
	restoreDesign ./05_cts.dat harris_top_IMG_W64_IMG_H64
	setNanoRouteMode -quiet -routeWithTimingDriven true
	setNanoRouteMode -quiet -routeTdrEffort 1
	setNanoRouteMode -quiet -routeTopRoutingLayer 9
	setNanoRouteMode -quiet -routeBottomRoutingLayer 1
	# CHANGED: removed "-drouteEndIteration 1" - it stops detail routing after 1 pass and leaves DRC violations
	# CHANGED: removed duplicate routeWithTimingDriven line
	setNanoRouteMode -quiet -routeWithSiDriven false
	routeDesign -globalDetail

	saveDesign 06_route
}

proc postroute {} {
	restoreDesign ./06_route.dat harris_top_IMG_W64_IMG_H64
	setAnalysisMode -analysisType onChipVariation -cppr both
	optDesign -postRoute
	# CHANGED: added hold fixing after route
	optDesign -postRoute -hold
	timeDesign -postRoute
	# CHANGED: added hold report
	timeDesign -postRoute -hold

	# CHANGED: added filler cells (needed for continuous wells/rails, DRC/LVS)
	addFiller -cell {FILL64 FILL32 FILL16 FILL8 FILL4 FILL2 FILL1} -prefix FILLER

	saveDesign 07_postRoute
}

proc final {} {
	restoreDesign ./07_postRoute.dat harris_top_IMG_W64_IMG_H64

	file mkdir reports
	file mkdir output

	verify_drc -report ./reports/final_drc.rpt
	verifyConnectivity -type all -report ./reports/final_connectivity.rpt
	verifyProcessAntenna -report ./reports/final_antenna.rpt

	#final reports
	report_area > ./reports/final_area.rpt
	report_power > ./reports/final_power.rpt
	report_timing > ./reports/final_timing_setup.rpt
	#hold timing report
	report_timing -early > ./reports/final_timing_hold.rpt

	#post-layout netlist and SDF (for LVS / post-layout simulation)
	saveNetlist ./output/harris_top_postroute.v
	write_sdf ./output/harris_top_postroute.sdf

	#Stream out GDSII
	#harris_top names
	streamOut ./output/harris_top.gds \
	-libName harris_top \
	-merge /home/cadence/install/FOUNDRY/digital/90nm/dig/gds/gsclib090.gds \
	-units 1000 \
	-mode ALL

	saveDesign 08_final
}

#Main
#init_design_flow
#floorplan
#powerplan
#placement
#cts
#route
#postroute
final
