// harris_top.sv -- streaming Harris corner detector (no NMS). See docs/interface_spec.md.
// Input: raster-order 8-bit pixels of IMG_W x IMG_H frames, frames back-to-back; pixel_valid gaps allowed
//        (all spatial state advances only on pixel_valid). No back-pressure.
// Output: corner_valid=1 only for interior centres (rows 3..H-4, cols 3..W-4), in raster order.
//   Input pixel (r,c) accepted at edge t <=> output for centre (r-3, c-3) visible after edge t+9
//   (10 register stages: window 1, sobel 1, products 1, boxsum 2, response 4, threshold 1).
module harris_top #(
  parameter int IMG_W  = 64,     // >= 7 to produce any output
  parameter int IMG_H  = 64,     // >= 7
  parameter int K_FRAC = 10,
  parameter int R_W    = 54 + K_FRAC
) (
  input  logic                           clk,
  input  logic                           rst_n,        // synchronous, active low
  input  logic [7:0]                     pixel_in,
  input  logic                           pixel_valid,
  input  logic [K_FRAC:0]                k_q,          // k = k_q/2^K_FRAC ; typical 41 (~0.04)
  input  logic signed [R_W-1:0]          thr,          // threshold in scaled units (R * 2^K_FRAC)
  output logic                           corner_out,
  output logic                           corner_valid,
  output logic signed [R_W-1:0]          resp_dbg      // scaled response aligned with corner_out
);
  // Parameter contract checks
`ifdef __ICARUS__
  // Icarus Verilog does not support elaboration-time $error inside generate
  // blocks, so the same checks are done at simulation time 0 instead.
  initial begin
    if (IMG_W < 7 || IMG_H < 7) begin
      $display("ERROR: harris_top: IMG_W and IMG_H must be >= 7 (7x7 footprint)");
      $finish;
    end
    if (R_W != 54 + K_FRAC) begin
      $display("ERROR: harris_top: R_W must equal 54+K_FRAC (see docs/arithmetic_analysis.md)");
      $finish;
    end
  end
`else
  // Elaboration-time contract checks (no hardware generated)
  if (IMG_W < 7 || IMG_H < 7) begin : g_dim_chk
    $error("harris_top: IMG_W and IMG_H must be >= 7 (7x7 footprint)");
  end
  if (R_W != 54 + K_FRAC) begin : g_rw_chk
    $error("harris_top: R_W must equal 54+K_FRAC (see docs/arithmetic_analysis.md)");
  end
`endif

  logic [71:0] win; logic win_v;
  logic signed [10:0] ix, iy; logic sob_v;
  logic [19:0] pxx, pyy; logic signed [20:0] pxy; logic prd_v;
  logic [24:0] sxx, syy; logic signed [25:0] sxy; logic box_v;
  logic signed [R_W-1:0] resp; logic rsp_v;

  window3x3 #(.IMG_W(IMG_W), .IMG_H(IMG_H)) u_win (
    .clk(clk), .rst_n(rst_n), .pixel_in(pixel_in), .pixel_valid(pixel_valid),
    .win_flat(win), .win_valid(win_v));
  sobel_grad u_sobel (.clk(clk), .rst_n(rst_n), .win_flat(win), .in_valid(win_v),
    .ix(ix), .iy(iy), .out_valid(sob_v));
  gradient_products u_prod (.clk(clk), .rst_n(rst_n), .ix(ix), .iy(iy), .in_valid(sob_v),
    .pxx(pxx), .pyy(pyy), .pxy(pxy), .out_valid(prd_v));
  boxsum5x5 #(.IMG_W(IMG_W-2), .IMG_H(IMG_H-2)) u_box (
    .clk(clk), .rst_n(rst_n), .pxx(pxx), .pyy(pyy), .pxy(pxy), .in_valid(prd_v),
    .sxx(sxx), .syy(syy), .sxy(sxy), .out_valid(box_v));
  harris_response #(.K_FRAC(K_FRAC), .R_W(R_W)) u_resp (
    .clk(clk), .rst_n(rst_n), .sxx(sxx), .syy(syy), .sxy(sxy), .k_q(k_q), .in_valid(box_v),
    .resp(resp), .out_valid(rsp_v));
  corner_threshold #(.R_W(R_W)) u_thr (
    .clk(clk), .rst_n(rst_n), .resp(resp), .thr(thr), .in_valid(rsp_v),
    .corner_out(corner_out), .corner_valid(corner_valid), .resp_out(resp_dbg));
endmodule
