# How to run

```bash
git clone https://github.com/GHOSTALERT/harris-corner-asic.git
cd harris-corner-asic
```

## Simulations (no Cadence tools needed)

Needs Icarus Verilog 11 or newer. `sim/crosscheck.py` also needs Python 3 with numpy, plus matplotlib for the plot.

```bash
./run_sim.sh        # or: make sim
```

This runs the six unit testbenches, the 28-test integration testbench at five image sizes, and the RTL-vs-Python crosscheck. Logs go to `sim/logs/`. Expected output (Icarus Verilog 12.0):

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

## Cadence flow

The Cadence steps need Genus, Conformal, Tempus and Innovus, plus the Cadence generic 90 nm PDK (gsclib090). The technology files are not in this repo. Each script is run from its own folder.

| Step | Script | Notes |
|---|---|---|
| Synthesis (Genus 21.14) | `synthesis/genus.tcl` | The reported run used `CLK_PERIOD=2.25`; the script default is now 4 ns |
| Equivalence (Conformal LEC) | `lec/LEC.tcl` | RTL (golden) vs Genus netlist (revised) |
| Pre-layout STA (Tempus 22.11) | `sta/tempus.tcl` | Logs for 2.25 ns and 3.8 ns runs are in `sta/` |
| Place and route (Innovus 21.15) | `pnr/innovus.tcl` + `pnr/mmmc.tcl` | One Tcl proc per stage, each saves a checkpoint |
