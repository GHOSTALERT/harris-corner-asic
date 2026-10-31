// Unit test: harris_response. Directed extremes + random; k_q changed only while pipeline is empty.
// Expected: R_s = (Sxx*Syy - Sxy^2)*2^10 - K_Q*(Sxx+Syy)^2 in 64-bit signed (bounds proven in docs).
`timescale 1ns/1ps
module tb_harris_response;
  localparam int SMAX = 26010000;
  logic clk = 0, rst_n = 0, v = 0; logic [24:0] sxx = 0, syy = 0; logic signed [25:0] sxy = 0;
  logic [10:0] k_q = 41; wire signed [63:0] resp; wire ov;
  harris_response #(.K_FRAC(10)) dut (.clk(clk), .rst_n(rst_n), .sxx(sxx), .syy(syy), .sxy(sxy),
     .k_q(k_q), .in_valid(v), .resp(resp), .out_valid(ov));
  always #5 clk = ~clk;
  int errors = 0, checked = 0;
  logic e_v [0:3]; longint e_r [0:3]; int e_x [0:3]; int e_y [0:3]; int e_z [0:3]; int e_k [0:3];
  longint rmin = 0, rmax = 0;

  function automatic longint model(input longint x, input longint y, input longint z, input longint kq);
    longint det, tr;
    det = x*y - z*z; tr = x + y;
    model = (det <<< 10) - kq * tr * tr;
  endfunction

  task automatic step(input bit vv, input int x, input int y, input int z);
    @(negedge clk);
    if (ov !== e_v[3]) begin errors++; $display("FAIL out_valid exp=%0b act=%0b t=%0t", e_v[3], ov, $time); end
    else if (e_v[3]) begin
      checked++;
      if (resp !== e_r[3]) begin errors++; $display("FAIL x=%0d y=%0d z=%0d k=%0d exp=%0d act=%0d", e_x[3], e_y[3], e_z[3], e_k[3], e_r[3], resp); end
    end
    for (int i = 3; i > 0; i--) begin e_v[i] = e_v[i-1]; e_r[i] = e_r[i-1]; e_x[i]=e_x[i-1]; e_y[i]=e_y[i-1]; e_z[i]=e_z[i-1]; e_k[i]=e_k[i-1]; end
    v = vv; sxx = x[24:0]; syy = y[24:0]; sxy = z[25:0];
    e_v[0] = vv;
    e_r[0] = model(x, y, z, k_q); e_x[0]=x; e_y[0]=y; e_z[0]=z; e_k[0]=k_q;
    if (vv) begin if (e_r[0] > rmax) rmax = e_r[0]; if (e_r[0] < rmin) rmin = e_r[0]; end
  endtask

  task automatic drain; repeat (6) step(0, 0, 0, 0); endtask

  task automatic batch(input int kq);
    drain; k_q = kq[10:0]; drain;
    // directed
    step(1, 0, 0, 0);
    step(1, SMAX, SMAX, SMAX);  step(1, SMAX, SMAX, -SMAX);  step(1, SMAX, SMAX, 0);
    step(1, SMAX, 0, 0);        step(1, 0, SMAX, 0);        step(1, 0, 0, SMAX);   step(1, 0, 0, -SMAX);
    step(1, 1, 1, 1);           step(1, 1, 1, -1);          step(1, 12345678, 87654, -5555555);
    step(0, SMAX, SMAX, SMAX);
    step(1, SMAX, SMAX/2, -SMAX/3);
    // random, ranges random-scaled to exercise small/large magnitudes
    for (int n = 0; n < 3000; n++) begin
      int sh = $urandom_range(24);
      int x = $urandom_range(SMAX) >> sh, y = $urandom_range(SMAX) >> $urandom_range(24);
      int z = (int'($urandom_range(2*SMAX)) - SMAX) >>> $urandom_range(24);
      step($urandom_range(5) != 0, x, y, z);
    end
  endtask

  initial begin
    for (int i = 0; i < 4; i++) begin e_v[i] = 0; e_r[i] = 0; end
    repeat (3) @(negedge clk); rst_n = 1;
    batch(41); batch(0); batch(2047); batch(1); batch(1024);
    drain;
    if (rmin > -5500000000000000000 || rmax < 600000000000000000) begin errors++; $display("FAIL extremes not exercised min=%0d max=%0d", rmin, rmax); end
    if (errors == 0) $display("TEST PASSED tb_harris_response (%0d vectors; R_s range [%0d, %0d])", checked, rmin, rmax);
    else $display("TEST FAILED tb_harris_response errors=%0d", errors);
    $finish;
  end
  initial begin #50_000_000; $display("TEST FAILED tb_harris_response TIMEOUT"); $finish; end
endmodule
