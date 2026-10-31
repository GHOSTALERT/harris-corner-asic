// Unit test: boxsum5x5 (IMG 9x8 interior image). Random / extreme data, gaps, multi-frame, mid-frame reset.
// Expected sums are computed by direct 5x5 loops over data stored by coordinate.
`timescale 1ns/1ps
module tb_boxsum5x5;
  localparam int W = 9, H = 8;
  localparam int PMAX = 1040400;
  logic clk = 0, rst_n = 0, v = 0;
  logic [19:0] pxx = 0, pyy = 0; logic signed [20:0] pxy = 0;
  wire [24:0] sxx, syy; wire signed [25:0] sxy; wire ov;
  boxsum5x5 #(.IMG_W(W), .IMG_H(H)) dut (.clk(clk), .rst_n(rst_n), .pxx(pxx), .pyy(pyy), .pxy(pxy),
     .in_valid(v), .sxx(sxx), .syy(syy), .sxy(sxy), .out_valid(ov));
  always #5 clk = ~clk;

  int xx [0:H-1][0:W-1]; int yy [0:H-1][0:W-1]; int xy [0:H-1][0:W-1];
  int er = 0, ec = 0, errors = 0, nchk = 0, nexp = 0;
  // 2-deep expectation pipeline (latency 2): index 0 = driven last negedge
  logic e_v [0:1]; longint e_xx [0:1]; longint e_yy [0:1]; longint e_xy [0:1]; int e_r [0:1]; int e_c [0:1];
  longint smax = 0, smin = 0;

  task automatic step(input bit vv, input int a, input int b, input int c);
    longint sx, sy, sz;
    @(negedge clk);
    // check output (token driven 2 negedges ago appears now)
    if (ov !== e_v[1]) begin errors++; $display("FAIL out_valid exp=%0b act=%0b t=%0t", e_v[1], ov, $time); end
    else if (e_v[1]) begin
      nchk++;
      if (sxx !== e_xx[1][24:0] || syy !== e_yy[1][24:0] || sxy !== e_xy[1][25:0]) begin errors++;
        $display("FAIL centre(%0d,%0d) exp %0d %0d %0d act %0d %0d %0d", e_r[1]-2, e_c[1]-2,
                 e_xx[1], e_yy[1], e_xy[1], sxx, syy, sxy); end
    end
    e_v[1] = e_v[0]; e_xx[1] = e_xx[0]; e_yy[1] = e_yy[0]; e_xy[1] = e_xy[0]; e_r[1] = e_r[0]; e_c[1] = e_c[0];
    e_v[0] = 0;
    v = vv; pxx = a[19:0]; pyy = b[19:0]; pxy = c[20:0];
    if (vv) begin
      xx[er][ec] = a; yy[er][ec] = b; xy[er][ec] = c;
      if (er >= 4 && ec >= 4) begin
        sx = 0; sy = 0; sz = 0;
        for (int i = 0; i < 5; i++) for (int j = 0; j < 5; j++) begin
          sx += xx[er-i][ec-j]; sy += yy[er-i][ec-j]; sz += xy[er-i][ec-j]; end
        e_v[0] = 1; e_xx[0] = sx; e_yy[0] = sy; e_xy[0] = sz; e_r[0] = er; e_c[0] = ec; nexp++;
        if (sx > smax) smax = sx; if (sz > smax) smax = sz; if (sz < smin) smin = sz;
      end
      if (ec == W-1) begin ec = 0; er = (er == H-1) ? 0 : er+1; end else ec++;
    end
  endtask

  // mode: 0 random, 1 all max, 2 pxy all min, 3 alternating max/min pxy, 4 zeros
  task automatic frame(input int mode, input int gap_pct);
    for (int n = 0; n < W*H; n++) begin
      int a, b, c;
      while ($urandom_range(99) < gap_pct) step(0, $urandom, $urandom, $urandom);
      case (mode)
        0: begin a = $urandom_range(PMAX); b = $urandom_range(PMAX); c = int'($urandom_range(2*PMAX)) - PMAX; end
        1: begin a = PMAX; b = PMAX; c = PMAX; end
        2: begin a = PMAX; b = PMAX; c = -PMAX; end
        3: begin a = PMAX; b = 0; c = (n % 2) ? PMAX : -PMAX; end
        default: begin a = 0; b = 0; c = 0; end
      endcase
      step(1, a, b, c);
    end
  endtask

  task automatic do_reset;
    @(negedge clk); rst_n = 0; v = 0; e_v[0] = 0; e_v[1] = 0;
    repeat (3) @(negedge clk);
    if (ov !== 0) begin errors++; $display("FAIL out_valid in reset"); end
    rst_n = 1; er = 0; ec = 0; e_v[0] = 0; e_v[1] = 0;
  endtask

  initial begin
    e_v[0] = 0; e_v[1] = 0;
    repeat (3) @(negedge clk); rst_n = 1;
    frame(0, 0); frame(0, 40); frame(1, 0); frame(2, 0); frame(3, 10); frame(4, 0); frame(0, 70);
    for (int n = 0; n < 30; n++) begin int a = $urandom_range(PMAX); step(1, a, a, 0); end   // partial frame
    do_reset;
    frame(0, 0); frame(1, 30);
    repeat (6) step(0, 0, 0, 0);
    if (nchk != nexp || nexp != 9*(W-4)*(H-4)) begin errors++;
      $display("FAIL count chk=%0d exp=%0d spec=%0d", nchk, nexp, 9*(W-4)*(H-4)); end
    if (smax != 25*PMAX || smin != -25*PMAX) begin errors++; $display("FAIL extremes %0d %0d", smin, smax); end
    if (errors == 0) $display("TEST PASSED tb_boxsum5x5 (%0d sums checked, extreme sums [%0d,%0d])", nchk, smin, smax);
    else $display("TEST FAILED tb_boxsum5x5 errors=%0d", errors);
    $finish;
  end
  initial begin #20_000_000; $display("TEST FAILED tb_boxsum5x5 TIMEOUT"); $finish; end
endmodule
