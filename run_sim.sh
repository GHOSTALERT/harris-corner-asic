#!/usr/bin/env bash
# Runs every simulation that does not need Cadence tools:
#   1. the six unit testbenches (tb/tb_<module>.sv)
#   2. the self-checking integration testbench tb_harris_top (28 tests) at 13x11, 64x64, 256x20, 640x10, 7x7
#   3. sim/crosscheck.py: RTL vs Python reference model at 64x64 (needs numpy)
# Needs Icarus Verilog >= 11. Logs go to sim/logs/.
set -u
cd "$(dirname "$0")"
mkdir -p build sim/logs
fail=0
for m in window3x3 sobel_grad gradient_products boxsum5x5 harris_response corner_threshold; do
  log=sim/logs/tb_$m.log
  if iverilog -g2012 -o build/tb_$m.vvp -s tb_$m rtl/*.sv tb/tb_$m.sv > $log 2>&1 && vvp -n build/tb_$m.vvp >> $log 2>&1 \
     && grep -q "TEST PASSED" $log && ! grep -q "FAIL" $log; then
    grep "TEST PASSED" $log
  else echo "FAILED tb_$m (see $log)"; fail=1; fi
done
log=sim/logs/tb_harris_top.log
iverilog -g2012 -o build/tb_harris_top.vvp -s tb_harris_top rtl/*.sv tb/tb_harris.sv > $log 2>&1 \
  && vvp -n build/tb_harris_top.vvp +SEED=1 >> $log 2>&1
if grep -q "TEST PASSED" $log && ! grep -q "FAIL" $log; then grep "TEST PASSED" $log
else echo "FAILED tb_harris_top (see $log)"; fail=1; fi
# the same testbench at the synthesized size, wide lines and the 7x7 minimum
: > sim/logs/tb_harris_top_sizes.log
for wh in 64:64 256:20 640:10 7:7; do
  W=${wh%:*}; H=${wh#*:}
  iverilog -g2012 -P tb_harris_top.W=$W -P tb_harris_top.H=$H -o build/tb_harris_top_$W.vvp -s tb_harris_top \
    rtl/*.sv tb/tb_harris.sv >> sim/logs/tb_harris_top_sizes.log 2>&1 \
    && vvp -n build/tb_harris_top_$W.vvp +SEED=3 > build/sizes_$W.log 2>&1
  cat build/sizes_$W.log >> sim/logs/tb_harris_top_sizes.log
  if grep -q "TEST PASSED" build/sizes_$W.log && ! grep -q "FAIL" build/sizes_$W.log; then grep "TEST PASSED" build/sizes_$W.log
  else echo "FAILED tb_harris_top ${W}x${H}"; fail=1; fi
done
if python3 -c "import numpy" 2>/dev/null; then
  python3 sim/crosscheck.py > sim/logs/crosscheck_64x64.log 2>&1 || fail=1
  tail -1 sim/logs/crosscheck_64x64.log
else echo "numpy not found: skipping sim/crosscheck.py"; fi
[ $fail -eq 0 ] && echo "ALL SIMULATIONS PASS" || echo "SIMULATION FAILURES"
exit $fail
