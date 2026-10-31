# Harris Corner Detection ASIC: RTL to GDSII

<p align="center">
  <img src="docs/images/layout_routed_crop.png" alt="Routed layout of harris_top in Cadence Innovus" width="520"><br>
  <em>Routed harris_top (64 × 64 configuration): 1017 × 1012 µm die, 54,154 cells, 250 MHz, DRC clean. Cadence Innovus, 90 nm gsclib090.</em>
</p>

A streaming Harris corner detector written in synthesizable SystemVerilog and taken through a complete Cadence flow in a 90 nm generic standard-cell library (gsclib090): Xcelium simulation, Genus synthesis, Conformal LEC, Tempus STA and Innovus place-and-route, ending in a DRC-clean GDSII.

Group project for **BEVD301L ASIC Design / BEVD301P ASIC Design Lab**, VIT Vellore, Fall Semester 2026–27.

## Results at a glance

| | |
|---|---|
| Function | 8-bit grayscale pixel stream in, corner flag and 64-bit Harris response out, 1 pixel per clock |
| Image size (synthesized) | 64 × 64 (`IMG_W`, `IMG_H` are parameters) |
| Clock | 4.0 ns / **250 MHz** → 250 Mpixel/s |
| Post-route timing | setup WNS **+0.307 ns**, hold WNS **+0.001 ns**, 0 violating paths, 0 DRVs |
| Die / core | 1017 × 1012 µm (1.029 mm²) / 997 × 992 µm (0.989 mm²) |
| Cell area / instances | 564,377 µm² / 54,154 at 57.1 % density |
| Power (default activity) | 127.3 mW at 0.9 V |
| Equivalence (RTL vs netlist) | 16,807 points equivalent, 0 non-equivalent, 0 aborted |
| Physical checks | DRC 0, connectivity 0, process antenna 0 |
| Verification | 28-test self-checking testbench (Xcelium and Icarus), 6 unit testbenches, bit-exact match with a Python reference model |

## Team

| Name | Registration No. |
|---|---|
| Saket Sodani | 24BVD0069 |
| Advay Gopalakrishnan | 24BVD0191 |
| Swajit Jain | 24BVD0022 |
| Krithik Sai | 24BVD0039 |
| Arrnav Trisal | 24BVD0064 |
| Ashmit Singh | 24BVD0027 |

## Architecture

![Block diagram](docs/images/block_diagram.png)

A linear pipeline of six modules. Only line buffers are stored, never a full frame, and a valid bit travels with the data. `pixel_valid` low stalls the whole pipeline.

| Module | What it does |
|---|---|
| `window3x3` | Row/column counters, two line buffers, builds the 3 × 3 window |
| `sobel_grad` | 3 × 3 Sobel Ix, Iy using shifts and adds only (signed 11-bit, ±1020) |
| `gradient_products` | Ix², Iy², Ix·Iy (the 4th term is skipped because M is symmetric) |
| `boxsum5x5` | Three `boxsum_ch` channels, each with 4 line buffers and a 5-tap horizontal sum |
| `harris_response` | R_s = 2¹⁰·(Sxx·Syy − Sxy²) − k_q·(Sxx + Syy)², exact, 64-bit, 4 pipeline stages |
| `corner_threshold` | `corner_out = R_s > thr`, border masking |

Every width comes from worst-case bounds for 8-bit input (see `docs/arithmetic_analysis.md` and `model/bounds.py`), so no stage can overflow, and the response is never truncated. `k = k_q / 1024` and `thr` are run-time inputs, so one netlist can be tuned without re-synthesis. Latency is a fixed 10 clocks. `corner_valid` is only asserted where the full 7 × 7 footprint lies inside the image.

## Repository layout

```
rtl/              7 SystemVerilog modules (harris_top.sv is the top)
tb/               tb_harris.sv (28-test integration TB, module tb_harris_top) + 6 unit TBs
model/            harris_reference.py (bit-exact Python model), bounds.py (worst-case width analysis)
sim/              crosscheck.py + tb_harris_dump.sv (RTL vs Python at 64x64), logs/, corners_64x64.png
synthesis/        genus.tcl, Genus reports (area, gates, timing, QoR, power), log, netlist + SDC
lec/              Conformal LEC script and log
sta/              Tempus script and logs (2.25 ns and 3.8 ns runs)
pnr/              innovus.tcl, mmmc.tcl, final reports, CTS reports, timing summaries, post-route netlist
docs/             architecture, interface spec, arithmetic analysis, verification plan/results, images/
report/           the submitted case study and the front-end / back-end lab reports (PDF)
run_sim.sh        runs every simulation that does not need Cadence tools
```

## Running the simulations

Needs Icarus Verilog 11 or newer; `sim/crosscheck.py` also needs numpy (and matplotlib for the plot).

```bash
./run_sim.sh        # or: make sim
```

Output on this machine (Icarus Verilog 12.0):

```
TEST PASSED tb_window3x3 (122 windows checked)
TEST PASSED tb_sobel_grad (27471 vectors, Ix in [-1020,1020], Iy in [-1020,1020])
TEST PASSED tb_gradient_products (124284 vectors; Pxx max 1040400, Pxy [-1040400,1040400])
TEST PASSED tb_boxsum5x5 (180 sums checked, extreme sums [-26010000,26010000])
TEST PASSED tb_harris_response (12599 vectors; R_s range [-5539346578800000000, 692756582400000000])
TEST PASSED tb_corner_threshold (14990 vectors, 7054 corners)
TEST PASSED tb_harris_top 13x11: 28 tests, 1260 outputs checked, 672 corners
TEST PASSED tb_harris_top 64x64: 28 tests, 121104 outputs checked, 41923 corners
TEST PASSED tb_harris_top 256x20: 28 tests, 126000 outputs checked, 49404 corners
TEST PASSED tb_harris_top 640x10: 28 tests, 91296 outputs checked, 28658 corners
TEST PASSED tb_harris_top 7x7: 28 tests, 36 outputs checked, 17 corners
CROSSCHECK PASS
ALL SIMULATIONS PASS
```

The 13 × 11 run gives exactly the same result the team got in Cadence Xcelium (28 tests, 1,260 outputs, 672 corners). The 28 tests cover edges, corner patterns, checkerboards, random input stalls (35 %, 70 %), a 200-cycle idle gap, extreme `k_q` and `thr`, 0/255 noise, back-to-back frames, reset mid-frame and random configurations.

`sim/crosscheck.py` streams a 64 × 64 scene through the RTL and compares every `resp_dbg` and `corner_out` with `model/harris_reference.py`: 3,364 outputs and 0 mismatches, with and without 35 % input stalls. There is no non-maximum suppression in this version, so each corner shows up as a small cluster:

![RTL corner output on a 64x64 scene](sim/corners_64x64.png)

## Cadence flow

The Cadence steps were run on the VIT Cadence server. The scripts and reports here are copied from that run; the technology files (Liberty, LEF, cell GDS) belong to the Cadence generic PDK and are not included.

### Synthesis (Genus 21.14)

`synthesis/genus.tcl`, slow corner, hierarchy kept (`auto_ungroup none`), elaborated with `IMG_W = IMG_H = 64` (Genus names the top `harris_top_IMG_W64_IMG_H64`).

- First run at **2.25 ns**: WNS **−1.465 ns**, 378 violating paths. The critical path is the 26 × 26-bit Sxy² multiplier in `harris_response` (3.57 ns of logic in one stage).
- The clock was relaxed to **4.0 ns** in the SDC used for STA and place-and-route (`synthesis/netlist/harris_top_slow.sdc`). The max-transition and max-fanout limits were relaxed from 0.15 ns / 4 to 0.5 ns / 32.
- Area 593,021 µm², 71,778 cells, 16,741 flip-flops. `boxsum5x5` is 76.7 % of the area: without SRAM macros every line-buffer bit is a flip-flop.

The reported run used `CLK_PERIOD=2.25`. The default in `genus.tcl` was later changed to 4 ns; run with `CLK_PERIOD=2.25` to reproduce the reports.

### Equivalence (Conformal LEC)

`lec/LEC.tcl`: RTL (golden) vs Genus netlist (revised), with `analyze_datapath -merge` for the large multipliers and automatic abort analysis. The first compare left 39 aborted points, which the abort analysis resolved. Final result: **16,807 equivalent, 0 non-equivalent, 0 aborted**. 519 constant or unloaded flip-flops removed by synthesis are reported as unreachable.

### Pre-layout STA (Tempus 22.11)

`sta/tempus.tcl`. At 3.8 ns: setup **+0.049 ns** (still the Sxy² path), hold **+0.054 ns** (`sta/tempus_3p8ns.log`). The 2.25 ns run is kept for comparison (`sta/tempus_2p25ns.log`, −1.501 ns).

### Place and route (Innovus 21.15)

`pnr/innovus.tcl` has one Tcl proc per stage, each saving a checkpoint; `pnr/mmmc.tcl` defines slow (setup), fast (hold) and typical views.

| Stage | Settings |
|---|---|
| Floorplan | Aspect ratio 1.0, 60 % utilization, 10.15 µm core-to-IO margin. Pixel inputs on the left, outputs on the right, `clk` centred on top, `thr` bus on the bottom |
| Power | VDD/VSS core ring (Metal3/Metal4, 1.8 µm), 60 µm stripe mesh on Metal3 and Metal4, `sroute` Metal1 rails |
| Placement | `placeDesign` + `optDesign -preCTS` (twice): WNS −0.001 ns, 0 DRVs, 0 % routing overflow |
| CTS | CCOpt, CLKBUF/CLKINV cells only, 0.2 ns target clock transition; 16,741 sinks |
| Route | NanoRoute, timing driven, Metal1 to Metal9 |
| Post-route | OCV + CPPR, setup then hold optimisation: setup **+0.307 ns**, hold **+0.001 ns** |
| Sign-off checks | `verify_drc`, `verifyConnectivity`, `verifyProcessAntenna`: all clean. Netlist, SDF and GDSII written |

| Floorplan | Power plan |
|---|---|
| ![](docs/images/floorplan.png) | ![](docs/images/powerplan.png) |
| **Placement** | **Module placement regions** |
| ![](docs/images/placement.png) | ![](docs/images/amoeba_view.png) |
| **Routed** | **Post-route timing** |
| ![](docs/images/routed.png) | ![](docs/images/postroute_timing.png) |

After layout the worst setup path moved from the Sxy² multiplier to the high-fanout column counter in `boxsum5x5`. That path meets timing with the help of 1.06 ns of clock skew. The worst hold path (input pin to the `window3x3` line buffer) was fixed with inserted delay cells.

Final area by block: `u_box` 77.2 %, `u_resp` 15.3 %, `u_win` 5.2 %, everything else under 2 %. Power is 127.3 mW: 62 % sequential, 27 % combinational, 10.6 % clock tree.

The 84 MB GDSII and the 39 MB post-route SDF are not in the repo. GitHub has file-size limits, and the GDS contains the PDK cell layouts. The post-route netlist is in `pnr/output/`.

## Known limitations

These are stated in the back-end report:

- **No filler cells.** `addFiller` was called, but the saved design has none. Innovus DRC passes, but fillers are needed for a sign-off DRC/LVS run.
- **Clock waveform.** When the period was changed to 4 ns, the SDC kept the falling edge at 1.125 ns (28 % duty cycle). Timing is unaffected because only the rising edge is used, but it should be `{0 2}`.
- **Thin margins.** Hold slack is +0.001 ns, and the worst setup path depends on clock skew.
- **No sign-off extraction or LVS.** No RC corner (QRC) in the MMMC setup, no crosstalk, IR-drop or EM analysis, power uses default switching activity, and no LVS was run.
- **Flip-flop line buffers.** They take 77 % of the area and 62 % of the power. SRAM macros or clock gating would cut both, and pipelining the Sxy² multiplier would let the clock go back toward 2.25 ns.

## Changes from the server copy

- `pnr/innovus.tcl`: a comment line in the `floorplan` proc had lost its `#`, which would stop the proc on a fresh run. Fixed. No commands were changed.
- `sta/tempus.tcl`: removed a stray `~` left at the end of the file by vim.
- The original `run_*.sh` scripts and Python vector generator were written for an earlier vector-file testbench that no longer exists. They are replaced by `run_sim.sh`, which runs the current testbenches.

## Reports

- `report/Harris_Case_Study.pdf`: literature survey (11 papers + MathWorks reference), problem statement and proposed architecture
- `report/Assignment_IX_Front_End_Report.pdf`: RTL, verification, synthesis, LEC, pre-layout STA
- `report/Assignment_X_Back_End_Report.pdf`: floorplan to GDSII

An earlier version of the RTL (v1: 16 × 16 image, compile-time k and threshold, coordinate outputs) is in [ashmitsingh7/ASIC_Proj](https://github.com/ashmitsingh7/ASIC_Proj).
