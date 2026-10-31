// Unit test: gradient_products. All Ix in [-1020,1020] x selected Iy, plus random pairs; latency 1.
`timescale 1ns/1ps
module tb_gradient_products;
  logic clk = 0, rst_n = 0, v = 0; logic signed [10:0] ix = 0, iy = 0;
  wire [19:0] pxx, pyy; wire signed [20:0] pxy; wire ov;
  gradient_products dut (.clk(clk), .rst_n(rst_n), .ix(ix), .iy(iy), .in_valid(v),
                         .pxx(pxx), .pyy(pyy), .pxy(pxy), .out_valid(ov));
  always #5 clk = ~clk;
  int errors = 0, checked = 0; int e_xx, e_yy, e_xy; logic exp_v = 0;
  int pxx_max = 0, pxy_max = -1, pxy_min = 1;

  task automatic step(input bit vv, input int a, input int b);
    @(negedge clk);
    if (ov !== exp_v) begin errors++; $display("FAIL out_valid"); end
    else if (exp_v) begin
      checked++;
      if ($signed({1'b0,pxx}) !== e_xx || $signed({1'b0,pyy}) !== e_yy || pxy !== e_xy) begin
        errors++; $display("FAIL ix=%0d iy=%0d exp xx=%0d yy=%0d xy=%0d act xx=%0d yy=%0d xy=%0d",
                           ix, iy, e_xx, e_yy, e_xy, pxx, pyy, pxy); end
    end
    v = vv; ix = a[10:0]; iy = b[10:0]; exp_v = vv;
    e_xx = a*a; e_yy = b*b; e_xy = a*b;
    if (vv) begin if (e_xx > pxx_max) pxx_max = e_xx; if (e_xy > pxy_max) pxy_max = e_xy; if (e_xy < pxy_min) pxy_min = e_xy; end
  endtask

  int ys [0:8];
  initial begin
    ys[0]=-1020; ys[1]=-1019; ys[2]=-1; ys[3]=0; ys[4]=1; ys[5]=2; ys[6]=511; ys[7]=1019; ys[8]=1020;
    repeat (3) @(negedge clk); rst_n = 1;
    for (int a = -1020; a <= 1020; a++) for (int k = 0; k < 9; k++) begin step(1, a, ys[k]); step(1, ys[k], a); end
    step(0, 1020, 1020);                       // invalid data must not appear
    for (int n = 0; n < 100000; n++)
      step($urandom_range(7) != 0, int'($urandom_range(2040)) - 1020, int'($urandom_range(2040)) - 1020);
    step(0,0,0); step(0,0,0);
    if (pxx_max != 1040400 || pxy_max != 1040400 || pxy_min != -1040400) begin errors++;
      $display("FAIL extremes pxx_max=%0d pxy[%0d,%0d]", pxx_max, pxy_min, pxy_max); end
    if (errors == 0) $display("TEST PASSED tb_gradient_products (%0d vectors; Pxx max %0d, Pxy [%0d,%0d])", checked, pxx_max, pxy_min, pxy_max);
    else $display("TEST FAILED tb_gradient_products errors=%0d", errors);
    $finish;
  end
  initial begin #200_000_000; $display("TEST FAILED tb_gradient_products TIMEOUT"); $finish; end
endmodule
