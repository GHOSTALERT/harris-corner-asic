# Verification results

## Simulation (reproducible with `./run_sim.sh`, Icarus Verilog 12.0)

| Testbench | Result |
|---|---|
| tb_window3x3 | PASS: 122 windows, gaps, 5 frames, mid-frame reset |
| tb_sobel_grad | PASS: 27,471 vectors including all 512 binary windows; Ix, Iy reach ±1020 |
| tb_gradient_products | PASS: 124,284 vectors; Pxx max 1,040,400, Pxy ±1,040,400 |
| tb_boxsum5x5 | PASS: 180 sums, random and extreme frames, gaps, reset; reached ±26,010,000 |
| tb_harris_response | PASS: 12,599 vectors, k_q in {0, 1, 41, 1024, 2047}, R_s in [-5.539e18, 6.93e17] |
| tb_corner_threshold | PASS: 14,990 vectors, strict `>`, 64-bit extremes, invalid masking |
| tb_harris_top (13×11) | PASS: 28 tests, 1,260 outputs checked, 672 corners, 0 mismatches |
| tb_harris_top at 64×64, 256×20, 640×10, 7×7 | PASS: 28 tests each; 121,104 / 126,000 / 91,296 / 36 outputs checked |
| sim/crosscheck.py (64×64) | PASS: 3,364 outputs, RTL `resp_dbg` and `corner_out` identical to `model/harris_reference.py`, with 0 % and 35 % input stalls |

The 28-test tb_harris_top result is the same one the team got in Cadence Xcelium (see `report/Assignment_IX_Front_End_Report.pdf`, Figure 3).

A bug found by the unit tests during development: the unsigned 5-row sum in boxsum5x5 overflowed a signed 23-bit intermediate (fixed with one guard bit).

## Cadence flow (run on the VIT Cadence server)

| Step | Result | Evidence |
|---|---|---|
| Genus synthesis, 2.25 ns | WNS −1.465 ns (Sxy² multiplier), 593,021 µm², 71,778 cells | `synthesis/reports/` |
| Conformal LEC, RTL vs netlist | PASS: 16,807 compare points equivalent, 0 non-equivalent, 0 aborts | `lec/harris_top_lec.log` |
| Tempus pre-layout, 3.8 ns | setup +0.049 ns, hold +0.054 ns | `sta/tempus_3p8ns.log` |
| Innovus post-route, 4.0 ns | setup WNS +0.307 ns, hold WNS +0.001 ns, 0 DRVs | `pnr/reports/`, `pnr/timing/` |
| verify_drc / verifyConnectivity / verifyProcessAntenna | 0 / 0 / 0 violations | `pnr/reports/final_*.rpt` |
