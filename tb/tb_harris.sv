// tb_harris_top.sv -- self-checking testbench for harris_top (streaming Harris corner detector)
//
// Self-contained: the golden model (Sobel -> products -> 5x5 box sums -> R_s -> threshold) is written in
// SystemVerilog inside this file, so no Python, vector files or $readmemh are needed.
//
// What is checked for every corner_valid pulse:
//   * resp_dbg  == exact model R_s = 2^K_FRAC*(Sxx*Syy - Sxy^2) - k_q*(Sxx+Syy)^2
//   * corner_out == (R_s > thr)   (strictly greater)
//   * order: outputs come out in raster order of the interior centres (rows 3..H-4, cols 3..W-4)
//   * latency: output appears exactly LAT=10 clocks after the bottom-right footprint pixel (r+3,c+3)
//   * no missing outputs, no extra/unexpected outputs, correct count per test
// Protocol checks every clock:
//   * corner_valid / corner_out are never X after reset
//   * corner_out is 0 whenever corner_valid is 0
//   * corner_valid and corner_out are 0 while reset is applied
//
// Tests: flat image, horizontal/vertical/diagonal edges, single bright pixel, square, 1px and 2px
// checkerboards, ramp, random, 0/255 noise, random input gaps (0/35/70 %), threshold equal to an actual
// response (strict '>' check), very low / very high thresholds, k_q = 0 and k_q = max, three different
// frames back-to-back, a long idle gap mid-frame, and a reset in the middle of a frame with tokens in flight.
//
// Compile / run (Icarus Verilog 11 or 12):
//   iverilog -g2012 -o tb_harris_top.vvp -s tb_harris_top rtl/*.sv tb_harris_top.sv
//   vvp tb_harris_top.vvp                       (+SEED=<n>  +VERBOSE  +VCD)
// Other image sizes: add  -P tb_harris_top.W=<w> -P tb_harris_top.H=<h>   (W,H >= 7)
`timescale 1ns/1ps

module tb_harris_top;
  // ------------------------------------------------------------------ parameters
  parameter  int W      = 13;          // image width  (>= 7). Default is deliberately not a power of 2.
  parameter  int H      = 11;          // image height (>= 7)
  localparam int K_FRAC = 10;
  localparam int R_W    = 54 + K_FRAC; // = 64; the model below uses 64-bit longint arithmetic
  localparam int LAT    = 10;          // pixel accept -> output, in clocks
  localparam int NPIX   = W * H;
  localparam int KQ_MAX = (1 << (K_FRAC + 1)) - 1;

  // test-pattern ids
  localparam int P_CONST = 0, P_HEDGE = 1, P_VEDGE = 2, P_DIAG = 3, P_SINGLE = 4, P_SQUARE = 5,
                 P_CHECK1 = 6, P_CHECK2 = 7, P_RAMP = 8, P_RANDOM = 9, P_NOISE = 10;
  // threshold modes
  localparam int T_ZERO = 0, T_MID = 1, T_MAX = 2, T_MIN = 3;

  // ------------------------------------------------------------------ DUT
  logic                  clk = 1'b0;
  logic                  rst_n = 1'b0;
  logic [7:0]            pixel_in = 8'h00;
  logic                  pixel_valid = 1'b0;
  logic [K_FRAC:0]       k_q = 11'd41;
  logic signed [R_W-1:0] thr = '0;
  wire                   corner_out, corner_valid;
  wire  signed [R_W-1:0] resp_dbg;

  harris_top #(.IMG_W(W), .IMG_H(H), .K_FRAC(K_FRAC), .R_W(R_W)) dut (
    .clk(clk), .rst_n(rst_n), .pixel_in(pixel_in), .pixel_valid(pixel_valid),
    .k_q(k_q), .thr(thr),
    .corner_out(corner_out), .corner_valid(corner_valid), .resp_dbg(resp_dbg));

  always #5 clk = ~clk;   // 100 MHz

  // ------------------------------------------------------------------ bookkeeping
  int     seed      = 1;
  bit     verbose   = 0;
  int     cyc       = 0;   // incremented every negedge
  int     errors    = 0;
  int     test_errs = 0;
  int     n_checked = 0, n_corners = 0;   // per test
  int     tot_checked = 0, tot_corners = 0, n_tests = 0;
  string  test_name = "";

  always @(negedge clk) cyc <= cyc + 1;

  // reset value seen by the DUT at the last rising edge
  logic rst_at_pos = 1'b0;
  always @(posedge clk) rst_at_pos <= rst_n;

  // ------------------------------------------------------------------ golden model
  int     img   [0:NPIX-1];     // current frame
  int     gx    [0:NPIX-1];
  int     gy    [0:NPIX-1];
  longint mdl_R [0:NPIX-1];     // R_s at each interior centre (r*W + c)

  function automatic int rnd(input int n);   // uniform 0..n-1, reproducible from +SEED
    rnd = $unsigned($random(seed)) % n;
  endfunction

  task automatic make_image(input int pat);
    int r, c, v;
    for (r = 0; r < H; r++)
      for (c = 0; c < W; c++) begin
        case (pat)
          P_CONST : v = 128;
          P_HEDGE : v = (r >= H/2) ? 255 : 0;
          P_VEDGE : v = (c >= W/2) ? 255 : 0;
          P_DIAG  : v = (c > r) ? 255 : 0;
          P_SINGLE: v = (r == H/2 && c == W/2) ? 255 : 0;
          P_SQUARE: v = (r >= H/3 && r < H - H/3 && c >= W/3 && c < W - W/3) ? 255 : 0;
          P_CHECK1: v = ((r + c) % 2) * 255;
          P_CHECK2: v = (((r / 2) + (c / 2)) % 2) * 255;
          P_RAMP  : v = (r * 17 + c * 23) % 256;
          P_RANDOM: v = rnd(256);
          P_NOISE : v = rnd(2) * 255;
          default : v = 0;
        endcase
        img[r*W + c] = v;
      end
  endtask

  // Computes mdl_R for the frame currently in img[] with the given k_q.
  task automatic run_model(input int kq);
    int r, c, i, j, p;
    longint sxx, syy, sxy, det, tr;
    for (p = 0; p < NPIX; p++) begin gx[p] = 0; gy[p] = 0; mdl_R[p] = 0; end
    // Sobel (correlation, row 0 = top): Gx = [-1 0 1; -2 0 2; -1 0 1], Gy = [-1 -2 -1; 0 0 0; 1 2 1]
    for (r = 1; r <= H-2; r++)
      for (c = 1; c <= W-2; c++) begin
        gx[r*W+c] = (img[(r-1)*W+c+1] + 2*img[r*W+c+1] + img[(r+1)*W+c+1])
                  - (img[(r-1)*W+c-1] + 2*img[r*W+c-1] + img[(r+1)*W+c-1]);
        gy[r*W+c] = (img[(r+1)*W+c-1] + 2*img[(r+1)*W+c] + img[(r+1)*W+c+1])
                  - (img[(r-1)*W+c-1] + 2*img[(r-1)*W+c] + img[(r-1)*W+c+1]);
      end
    // 5x5 box sums of the products, then the Harris response (exact 64-bit integer arithmetic)
    for (r = 3; r <= H-4; r++)
      for (c = 3; c <= W-4; c++) begin
        sxx = 0; syy = 0; sxy = 0;
        for (i = -2; i <= 2; i++)
          for (j = -2; j <= 2; j++) begin
            p = (r+i)*W + (c+j);
            sxx += longint'(gx[p]) * gx[p];
            syy += longint'(gy[p]) * gy[p];
            sxy += longint'(gx[p]) * gy[p];
          end
        det = sxx*syy - sxy*sxy;
        tr  = sxx + syy;
        mdl_R[r*W+c] = det * (longint'(1) << K_FRAC) - longint'(kq) * tr * tr;
      end
  endtask

  function automatic longint pick_thr(input int mode);
    longint mx; int r, c, n, mid;
    mx = mdl_R[3*W+3];
    for (r = 3; r <= H-4; r++) for (c = 3; c <= W-4; c++) if (mdl_R[r*W+c] > mx) mx = mdl_R[r*W+c];
    n   = (H-6) * (W-6);
    mid = n / 2;                                  // middle interior centre in raster order
    case (mode)
      T_ZERO : pick_thr = 0;
      T_MID  : pick_thr = mdl_R[(3 + mid/(W-6))*W + 3 + mid%(W-6)];   // equals a real response
      T_MAX  : pick_thr = mx;                     // nothing is strictly greater -> no corners
      T_MIN  : pick_thr = 64'sh8000_0000_0000_0000; // everything is greater -> all corners
      default: pick_thr = 0;
    endcase
  endfunction

  // ------------------------------------------------------------------ scoreboard (expected-output queue)
  int     q_frame [$];
  int     q_r     [$];
  int     q_c     [$];
  longint q_R     [$];
  int     q_cor   [$];
  int     q_cyc   [$];

  task automatic flush_expected;
    q_frame.delete(); q_r.delete(); q_c.delete(); q_R.delete(); q_cor.delete(); q_cyc.delete();
  endtask

  // remove the oldest expected output (written without void' casts so that Icarus 11 accepts it)
  int     junk_i;
  longint junk_l;
  bit     miss_done;
  task automatic pop_expected;
    junk_i = q_frame.pop_front(); junk_i = q_r.pop_front(); junk_i = q_c.pop_front();
    junk_l = q_R.pop_front();     junk_i = q_cor.pop_front(); junk_i = q_cyc.pop_front();
  endtask

  task automatic err(input string msg);
    errors++; test_errs++;
    if (test_errs <= 10) $display("  ERROR [%s] cyc=%0d: %s", test_name, cyc, msg);
    else if (test_errs == 11) $display("  ERROR [%s] ... further errors suppressed", test_name);
  endtask

  // ------------------------------------------------------------------ monitor (sampled at negedge)
  always @(negedge clk) begin
    if (rst_at_pos === 1'b0) begin
      // DUT saw reset at the last edge: outputs must be cleared (skip the very first edges, before any reset edge)
      if (cyc > 1 && (corner_valid !== 1'b0 || corner_out !== 1'b0))
        err($sformatf("corner_valid=%b corner_out=%b while reset is applied", corner_valid, corner_out));
    end else begin
      if (corner_valid === 1'bx || corner_out === 1'bx)
        err($sformatf("X on outputs: corner_valid=%b corner_out=%b", corner_valid, corner_out));
      if (corner_valid !== 1'b1 && corner_out !== 1'b0)
        err("corner_out=1 while corner_valid=0");
      if (corner_valid === 1'b1) begin
        if (q_r.size() == 0) begin
          err("unexpected corner_valid pulse (no output expected)");
        end else begin
          if (resp_dbg !== q_R[0] || corner_out !== (q_cor[0] != 0))
            err($sformatf("frame %0d centre (%0d,%0d): expected R=%0d corner=%0d, got R=%0d corner=%b",
                          q_frame[0], q_r[0], q_c[0], q_R[0], q_cor[0], resp_dbg, corner_out));
          if (cyc != q_cyc[0])
            err($sformatf("frame %0d centre (%0d,%0d): latency wrong, output at cyc %0d, expected cyc %0d",
                          q_frame[0], q_r[0], q_c[0], cyc, q_cyc[0]));
          if (verbose)
            $display("    out frame %0d (%0d,%0d) R=%0d corner=%b", q_frame[0], q_r[0], q_c[0], resp_dbg, corner_out);
          n_checked++;
          if (corner_out === 1'b1) n_corners++;
          pop_expected;
        end
      end
      // anything whose time has passed without appearing is missing.
      // (Written so that an empty queue is never indexed: Icarus 11 does not short-circuit '&&'.)
      miss_done = 0;
      while (!miss_done) begin
        if (q_cyc.size() == 0)    miss_done = 1;
        else if (q_cyc[0] >= cyc) miss_done = 1;
        else begin
          err($sformatf("missing output: frame %0d centre (%0d,%0d) was due at cyc %0d",
                        q_frame[0], q_r[0], q_c[0], q_cyc[0]));
          pop_expected;
        end
      end
    end
  end

  // ------------------------------------------------------------------ driver
  // Drives one pixel at the next negedge (accepted at the following posedge) and, if this pixel completes a
  // 7x7 footprint, queues the expected output for centre (r-3, c-3).
  task automatic drive_pixel(input int n, input int frame);
    int r, c, p;
    @(negedge clk);
    pixel_valid = 1'b1;
    pixel_in    = img[n][7:0];
    r = n / W; c = n % W;
    if (r >= 6 && c >= 6) begin
      p = (r-3)*W + (c-3);
      q_frame.push_back(frame); q_r.push_back(r-3); q_c.push_back(c-3);
      q_R.push_back(mdl_R[p]);
      q_cor.push_back(mdl_R[p] > thr);
      q_cyc.push_back(cyc + LAT);
    end
  endtask

  task automatic idle(input int n);   // pixel_valid low, pixel_in driven with junk (must be ignored)
    repeat (n) begin @(negedge clk); pixel_valid = 1'b0; pixel_in = rnd(256); end
  endtask

  // Streams pixels [first, last] of the current frame with random gaps of probability gap_pct.
  task automatic stream(input int first, input int last, input int frame, input int gap_pct);
    for (int n = first; n <= last; n++) begin
      while (rnd(100) < gap_pct) idle(1);
      drive_pixel(n, frame);
    end
  endtask

  task automatic drain;
    idle(LAT + 5);
    if (q_r.size() != 0) err($sformatf("%0d expected outputs never appeared", q_r.size()));
    flush_expected();
  endtask

  task automatic begin_test(input string name);
    test_name = name; test_errs = 0; n_checked = 0; n_corners = 0;
  endtask

  task automatic end_test(input int exp_outputs);
    n_tests++; tot_checked += n_checked; tot_corners += n_corners;
    if (n_checked != exp_outputs)
      err($sformatf("output count %0d, expected %0d", n_checked, exp_outputs));
    if (test_errs == 0)
      $display("PASS  %-34s outputs=%0d corners=%0d", test_name, n_checked, n_corners);
    else
      $display("FAIL  %-34s errors=%0d", test_name, test_errs);
  endtask

  // Standard single-configuration test: nframes frames of pattern pat, back-to-back.
  task automatic run_test(input string name, input int pat, input int gap_pct, input int kq,
                          input int thr_mode, input int nframes);
    begin_test(name);
    k_q = kq[K_FRAC:0];                   // k_q and thr only change while the pipeline is idle
    for (int f = 0; f < nframes; f++) begin
      make_image(pat);
      run_model(kq);
      if (f == 0) thr = pick_thr(thr_mode);
      stream(0, NPIX-1, f, gap_pct);
    end
    drain();
    end_test(nframes * (W-6) * (H-6));
  endtask

  // ------------------------------------------------------------------ test sequence
  initial begin
    int pats[3];
    if ($value$plusargs("SEED=%d", seed)) ;
    if ($test$plusargs("VERBOSE")) verbose = 1;
    if ($test$plusargs("VCD")) begin $dumpfile("tb_harris_top.vcd"); $dumpvars(0, tb_harris_top); end

    $display("=== tb_harris_top: IMG %0dx%0d, LAT=%0d, %0d interior outputs/frame, seed=%0d ===",
             W, H, LAT, (W-6)*(H-6), seed);
    if (W < 7 || H < 7) begin
      $display("TEST FAILED: W and H must be >= 7 for this testbench"); $finish;
    end

    // power-on reset
    rst_n = 1'b0; pixel_valid = 1'b0;
    repeat (5) @(negedge clk);
    rst_n = 1'b1;
    idle(3);

    // --- basic patterns, no gaps, k = 41/1024 (~0.04)
    run_test("flat image (R=0, thr=0 -> no corner)", P_CONST,  0, 41, T_ZERO, 1);
    run_test("horizontal edge",                      P_HEDGE,  0, 41, T_ZERO, 1);
    run_test("vertical edge",                        P_VEDGE,  0, 41, T_ZERO, 1);
    run_test("diagonal edge",                        P_DIAG,   0, 41, T_ZERO, 1);
    run_test("single bright pixel",                  P_SINGLE, 0, 41, T_ZERO, 1);
    run_test("bright square (4 corners)",            P_SQUARE, 0, 41, T_ZERO, 1);
    run_test("checkerboard 1px",                     P_CHECK1, 0, 41, T_ZERO, 1);
    run_test("checkerboard 2px",                     P_CHECK2, 0, 41, T_ZERO, 1);
    run_test("ramp",                                 P_RAMP,   0, 41, T_ZERO, 1);
    run_test("random",                               P_RANDOM, 0, 41, T_ZERO, 1);

    // --- input gaps (pixel_valid low, junk on pixel_in)
    run_test("random, 35% gaps",                     P_RANDOM, 35, 41, T_ZERO, 1);
    run_test("random, 70% gaps",                     P_RANDOM, 70, 41, T_ZERO, 1);
    run_test("square, 50% gaps",                     P_SQUARE, 50, 41, T_ZERO, 1);

    // --- threshold behaviour
    run_test("thr = an actual R (strict >)",         P_RANDOM, 0, 41, T_MID, 1);
    run_test("thr = max R (expect no corners)",      P_NOISE,  0, 41, T_MAX, 1);
    run_test("thr = most negative (all corners)",    P_NOISE, 35, 41, T_MIN, 1);

    // --- k_q extremes and large responses
    run_test("k_q = 0 (R = det*2^10)",               P_RANDOM, 0, 0,      T_ZERO, 1);
    run_test("k_q = max (2047)",                     P_NOISE,  0, KQ_MAX, T_ZERO, 1);
    run_test("0/255 noise (extreme sums)",           P_NOISE, 35, 41,     T_MID,  1);

    // --- multi-frame: 3 back-to-back frames of different content (counter wrap-around)
    begin_test("3 different frames back-to-back");
    pats[0] = P_SQUARE; pats[1] = P_RANDOM; pats[2] = P_DIAG;
    k_q = 41; thr = 0;
    for (int f = 0; f < 3; f++) begin
      make_image(pats[f]); run_model(41);
      stream(0, NPIX-1, f, 25);
    end
    drain();
    end_test(3 * (W-6) * (H-6));

    // --- long idle period in the middle of a frame (state must be held)
    begin_test("long idle (200 clk) mid-frame");
    make_image(P_RANDOM); run_model(41); k_q = 41; thr = 0;
    stream(0, NPIX/2, 0, 0);
    idle(200);
    stream(NPIX/2 + 1, NPIX-1, 0, 0);
    drain();
    end_test((W-6) * (H-6));

    // --- reset in the middle of a frame with tokens in flight, then a clean frame
    begin_test("reset mid-frame, then clean frame");
    make_image(P_RANDOM); run_model(41); k_q = 41; thr = 0;
    stream(0, NPIX - 2*W, 0, 0);          // most of a frame: outputs are in the pipeline
    begin
      @(negedge clk); pixel_valid = 1'b0; rst_n = 1'b0;
      flush_expected();                     // anything in flight is discarded by the reset
      idle(4);
      @(negedge clk); rst_n = 1'b1;
      idle(LAT + 3);                        // no output may appear after reset without new pixels
      n_checked = 0; n_corners = 0;         // count only the clean frame below
      make_image(P_SQUARE); run_model(41);
      stream(0, NPIX-1, 1, 20);
      drain();
    end
    end_test((W-6) * (H-6));

    // --- random regression: random pattern / gaps / k_q / threshold mode
    for (int t = 0; t < 6; t++) begin
      int pat, gap, kq, tm;
      pat = rnd(11); gap = rnd(60); kq = rnd(KQ_MAX + 1); tm = rnd(4);
      run_test($sformatf("random cfg %0d (pat=%0d gap=%0d%% k_q=%0d thr=%0d)", t, pat, gap, kq, tm),
               pat, gap, kq, tm, 2);
    end

    // ------------------------------------------------------------ summary
    $display("--------------------------------------------------------------------------");
    if (errors == 0)
      $display("TEST PASSED tb_harris_top %0dx%0d: %0d tests, %0d outputs checked, %0d corners",
               W, H, n_tests, tot_checked, tot_corners);
    else
      $display("TEST FAILED tb_harris_top %0dx%0d: %0d errors", W, H, errors);
    $finish;
  end

  // watchdog
  initial begin
    #(64'd2_000 * (NPIX + 200) * 60);
    $display("TEST FAILED tb_harris_top: TIMEOUT");
    $finish;
  end
endmodule
