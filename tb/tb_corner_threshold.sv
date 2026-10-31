// Unit test: corner_threshold. Strict '>' ; invalid masking; signed 64-bit extremes; latency 1.
`timescale 1ns/1ps
module tb_corner_threshold;
  logic clk = 0, rst_n = 0, v = 0; logic signed [63:0] r = 0, t = 0;
  wire c, cv; wire signed [63:0] ro;
  corner_threshold #(.R_W(64)) dut (.clk(clk), .rst_n(rst_n), .resp(r), .thr(t), .in_valid(v),
                                    .corner_out(c), .corner_valid(cv), .resp_out(ro));
  always #5 clk = ~clk;
  int errors = 0, checked = 0, ncorner = 0; logic e_v = 0, e_c = 0; logic signed [63:0] e_r = 0;

  task automatic step(input bit vv, input logic signed [63:0] rr, input logic signed [63:0] tt);
    @(negedge clk);
    if (cv !== e_v || c !== e_c) begin errors++; $display("FAIL v/c exp %0b/%0b act %0b/%0b", e_v, e_c, cv, c); end
    else if (e_v) begin checked++; ncorner += c; if (ro !== e_r) begin errors++; $display("FAIL resp_out"); end end
    v = vv; r = rr; t = tt; e_v = vv; e_c = vv && (rr > tt); e_r = rr;
  endtask

  localparam logic signed [63:0] MAXV = 64'sh7FFF_FFFF_FFFF_FFFF, MINV = 64'sh8000_0000_0000_0000;
  initial begin
    repeat (3) @(negedge clk); rst_n = 1;
    step(1, 5, 5);            // equal -> NOT a corner (strict)
    step(1, 6, 5);            // greater -> corner
    step(1, 4, 5);
    step(1, -1, -2);          // negative thresholds: -1 > -2
    step(1, -2, -1);
    step(1, 0, 0); step(1, 1, 0); step(1, 0, 1);
    step(1, MAXV, MINV); step(1, MINV, MAXV); step(1, MAXV, MAXV); step(1, MINV, MINV);
    step(1, MAXV, MAXV-1); step(1, MINV+1, MINV);
    step(0, 100, 0);          // invalid but r > t : must be masked
    step(0, MAXV, MINV);
    for (int n = 0; n < 20000; n++) begin
      logic signed [63:0] a, b;
      a = {$urandom, $urandom}; b = {$urandom, $urandom};
      if ($urandom_range(3) == 0) b = a + 64'(int'($urandom_range(2)) - 1);   // near-equal
      if ($urandom_range(3) == 0) a = a >>> $urandom_range(62);
      step($urandom_range(3) != 0, a, b);
    end
    step(0, 0, 0); step(0, 0, 0);
    @(negedge clk); rst_n = 0; v = 1; r = 10; t = 0; e_v = 0; e_c = 0; @(negedge clk);
    if (cv !== 0 || c !== 0) begin errors++; $display("FAIL reset"); end
    if (ncorner == 0) begin errors++; $display("FAIL no corners seen"); end
    if (errors == 0) $display("TEST PASSED tb_corner_threshold (%0d vectors, %0d corners)", checked, ncorner);
    else $display("TEST FAILED tb_corner_threshold errors=%0d", errors);
    $finish;
  end
  initial begin #50_000_000; $display("TEST FAILED tb_corner_threshold TIMEOUT"); $finish; end
endmodule
