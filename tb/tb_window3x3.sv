// Unit test: window3x3. Random pixels, random valid gaps, 3 full frames + mid-frame reset + 2 more frames.
// Expected window is built from the pixels stored BY COORDINATE (independent of RTL line-buffer scheme).
`timescale 1ns/1ps
module tb_window3x3;
  localparam int W = 8, H = 6;
  logic clk = 0, rst_n = 0, pv = 0; logic [7:0] pix = 0;
  wire [71:0] win; wire wv;
  window3x3 #(.IMG_W(W), .IMG_H(H)) dut (.clk(clk), .rst_n(rst_n), .pixel_in(pix), .pixel_valid(pv),
                                          .win_flat(win), .win_valid(wv));
  always #5 clk = ~clk;

  logic [7:0] img [0:H-1][0:W-1];
  int er = 0, ec = 0, errors = 0, nvalid = 0, nexp_valid = 0;
  logic exp_v = 0; logic [71:0] exp_w; int exp_r, exp_c;

  task automatic step(input bit v, input [7:0] p);
    @(negedge clk);
    if (wv !== exp_v) begin errors++; $display("FAIL win_valid exp=%0b act=%0b t=%0t", exp_v, wv, $time); end
    else if (exp_v) begin
      nvalid++;
      if (win !== exp_w) begin errors++;
        $display("FAIL window centre(%0d,%0d) exp=%h act=%h t=%0t", exp_r, exp_c, exp_w, win, $time); end
    end
    pv = v; pix = p; exp_v = 0;
    if (v) begin
      img[er][ec] = p;
      if (er >= 2 && ec >= 2) begin
        exp_v = 1; exp_r = er-1; exp_c = ec-1; nexp_valid++;
        for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++)
          exp_w[(i*3+j)*8 +: 8] = img[er-2+i][ec-2+j];
      end
      if (ec == W-1) begin ec = 0; er = (er == H-1) ? 0 : er+1; end else ec++;
    end
  endtask

  task automatic frame(input int npix, input int gap_pct);
    for (int n = 0; n < npix; n++) begin
      while ($urandom_range(99) < gap_pct) step(0, $urandom);   // invalid cycles carry junk data
      step(1, $urandom);
    end
  endtask

  task automatic do_reset;
    @(negedge clk); rst_n = 0; pv = 0; exp_v = 0;
    repeat (2) @(negedge clk);
    if (wv !== 0) begin errors++; $display("FAIL win_valid not 0 in reset"); end
    rst_n = 1; er = 0; ec = 0;
  endtask

  initial begin
    repeat (3) @(negedge clk);
    rst_n = 1;
    frame(W*H, 0); frame(W*H, 30); frame(W*H, 60);   // back-to-back, then gappy frames
    frame(20, 20);                                    // partial frame
    step(0, 0);                                       // let last token be checked
    do_reset;                                         // reset mid-frame
    frame(W*H, 0); frame(W*H, 25);
    repeat (3) step(0, 0);
    if (nvalid != nexp_valid || nvalid != 5*(W-2)*(H-2) + 2) begin errors++;
      $display("FAIL valid count %0d (exp %0d, spec %0d)", nvalid, nexp_valid, 5*(W-2)*(H-2)); end
    if (errors == 0) $display("TEST PASSED tb_window3x3 (%0d windows checked)", nvalid);
    else $display("TEST FAILED tb_window3x3 errors=%0d", errors);
    $finish;
  end
  initial begin #5_000_000; $display("TEST FAILED tb_window3x3 TIMEOUT"); $finish; end
endmodule
