// tb_harris_dump.sv -- streams one image file through harris_top and dumps every output.
// Used by sim/crosscheck.py to compare the RTL with the Python reference model
// (model/harris_reference.py) at the synthesized 64x64 configuration.
//   +IMG=<hex file, one pixel per line, raster order>  +OUT=<output file>
//   +KQ=<k_q>  +THR=<threshold, decimal>  +GAP=<percent of idle cycles>
`timescale 1ns/1ps
module tb_harris_dump;
  parameter int W = 64;
  parameter int H = 64;
  localparam int K_FRAC = 10;
  localparam int R_W = 54 + K_FRAC;

  logic clk = 1'b0, rst_n = 1'b0, pixel_valid = 1'b0;
  logic [7:0] pixel_in = '0;
  logic [K_FRAC:0] k_q = 11'd41;
  logic signed [R_W-1:0] thr = '0;
  wire corner_out, corner_valid;
  wire signed [R_W-1:0] resp_dbg;

  harris_top #(.IMG_W(W), .IMG_H(H), .K_FRAC(K_FRAC), .R_W(R_W)) dut (
    .clk, .rst_n, .pixel_in, .pixel_valid, .k_q, .thr,
    .corner_out, .corner_valid, .resp_dbg);

  always #5 clk = ~clk;

  logic [7:0] img [0:W*H-1];
  string img_file, out_file;
  int fd, kq, gap, n_out;
  longint thr_l;

  always @(posedge clk) if (rst_n && corner_valid) begin
    $fdisplay(fd, "%0d %0d", resp_dbg, corner_out);
    n_out++;
  end

  initial begin
    if (!$value$plusargs("IMG=%s", img_file)) $fatal(1, "+IMG required");
    if (!$value$plusargs("OUT=%s", out_file)) out_file = "rtl_out.txt";
    if ($value$plusargs("KQ=%d", kq)) k_q = kq[K_FRAC:0];
    if ($value$plusargs("THR=%d", thr_l)) thr = thr_l;
    if (!$value$plusargs("GAP=%d", gap)) gap = 0;
    $readmemh(img_file, img);
    fd = $fopen(out_file, "w");
    n_out = 0;
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    for (int i = 0; i < W*H; i++) begin
      while (gap > 0 && $urandom_range(99) < gap) begin
        @(negedge clk); pixel_valid = 1'b0;
      end
      @(negedge clk); pixel_in = img[i]; pixel_valid = 1'b1;
    end
    @(negedge clk); pixel_valid = 1'b0;
    repeat (20) @(negedge clk);
    $fclose(fd);
    $display("DUMP DONE %0dx%0d: %0d outputs", W, H, n_out);
    $finish;
  end
endmodule
