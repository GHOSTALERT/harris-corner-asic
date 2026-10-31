// Unit test: sobel_grad. Directed extremes + random windows; latency 1; valid hold.
`timescale 1ns/1ps
module tb_sobel_grad;
  logic clk = 0, rst_n = 0, v = 0; logic [71:0] win = 0;
  wire signed [10:0] ix, iy; wire ov;
  sobel_grad dut (.clk(clk), .rst_n(rst_n), .win_flat(win), .in_valid(v), .ix(ix), .iy(iy), .out_valid(ov));
  always #5 clk = ~clk;
  int errors = 0, checked = 0, gxmax = -9999, gxmin = 9999, gymax = -9999, gymin = 9999;
  int exp_ix, exp_iy; logic exp_v = 0;

  function automatic int px(input [71:0] w, input int i, input int j);
    return int'(w[(i*3+j)*8 +: 8]);
  endfunction

  task automatic step(input bit vv, input [71:0] w);
    @(negedge clk);
    if (ov !== exp_v) begin errors++; $display("FAIL out_valid exp=%0b act=%0b", exp_v, ov); end
    else if (exp_v) begin
      checked++;
      if (ix !== exp_ix[10:0] || iy !== exp_iy[10:0]) begin errors++;
        $display("FAIL win=%h exp ix=%0d iy=%0d act ix=%0d iy=%0d", win, exp_ix, exp_iy, ix, iy); end
    end
    v = vv; win = w; exp_v = vv;
    // independent expected value, 32-bit integer math with explicit Sobel coefficients
    exp_ix = -px(w,0,0) + px(w,0,2) - 2*px(w,1,0) + 2*px(w,1,2) - px(w,2,0) + px(w,2,2);
    exp_iy = -px(w,0,0) - 2*px(w,0,1) - px(w,0,2) + px(w,2,0) + 2*px(w,2,1) + px(w,2,2);
    if (vv) begin
      if (exp_ix > gxmax) gxmax = exp_ix; if (exp_ix < gxmin) gxmin = exp_ix;
      if (exp_iy > gymax) gymax = exp_iy; if (exp_iy < gymin) gymin = exp_iy;
    end
  endtask

  function automatic [71:0] mk(input [7:0] a00,a01,a02,a10,a11,a12,a20,a21,a22);
    mk = {a22,a21,a20,a12,a11,a10,a02,a01,a00};
  endfunction

  initial begin
    repeat (3) @(negedge clk); rst_n = 1;
    step(1, {72{1'b0}});                                       // zero
    step(1, {72{1'b1}});                                       // flat 255 -> 0,0
    step(1, mk(0,0,0, 0,0,255, 0,0,255) ^ 72'd0);              // partial
    step(1, mk(0,0,255, 0,0,255, 0,0,255));                    // Ix = +1020, Iy = 0
    step(1, mk(255,0,0, 255,0,0, 255,0,0));                    // Ix = -1020
    step(1, mk(0,0,0, 0,0,0, 255,255,255));                    // Iy = +1020
    step(1, mk(255,255,255, 0,0,0, 0,0,0));                    // Iy = -1020
    step(1, mk(0,0,0, 0,255,0, 0,0,0));                        // centre pixel ignored
    step(1, mk(255,0,0, 0,0,0, 0,0,255));                      // Ix=0, Iy=0 (cancel)
    step(0, {72{1'b1}});                                       // invalid input must not produce output
    for (int a = 0; a < 512; a++) step(1, mk(a[0]*255,a[1]*255,a[2]*255,a[3]*255,a[4]*255,a[5]*255,a[6]*255,a[7]*255,a[8]*255)); // all 512 binary windows
    for (int n = 0; n < 30000; n++) begin
      logic [71:0] w;
      for (int b = 0; b < 9; b++) w[b*8 +: 8] = $urandom;
      step($urandom_range(9) != 0, w);
    end
    step(0, 0); step(0, 0);
    // reset clears valid
    @(negedge clk); rst_n = 0; v = 1; win = 72'h1; exp_v = 0; @(negedge clk);
    if (ov !== 0) begin errors++; $display("FAIL out_valid during reset"); end
    // range check against the documented bounds
    if (gxmax != 1020 || gxmin != -1020 || gymax != 1020 || gymin != -1020) begin errors++;
      $display("FAIL extremes not reached gx[%0d,%0d] gy[%0d,%0d]", gxmin, gxmax, gymin, gymax); end
    if (errors == 0) $display("TEST PASSED tb_sobel_grad (%0d vectors, Ix in [%0d,%0d], Iy in [%0d,%0d])", checked, gxmin, gxmax, gymin, gymax);
    else $display("TEST FAILED tb_sobel_grad errors=%0d", errors);
    $finish;
  end
  initial begin #50_000_000; $display("TEST FAILED tb_sobel_grad TIMEOUT"); $finish; end
endmodule
