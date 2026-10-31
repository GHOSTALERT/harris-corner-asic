// sobel_grad.sv -- 3x3 Sobel, signed gradients. Latency 1 clock.
// Gx = [-1 0 1; -2 0 2; -1 0 1], Gy = [-1 -2 -1; 0 0 0; 1 2 1]  (correlation, window row 0 = top).
// Bounds: Ix,Iy in [-1020, +1020] -> 11-bit signed (exact, no truncation).
module sobel_grad (
  input  logic               clk,
  input  logic               rst_n,
  input  logic [71:0]        win_flat,   // see window3x3 for ordering
  input  logic               in_valid,
  output logic signed [10:0] ix,
  output logic signed [10:0] iy,
  output logic               out_valid
);
  logic [7:0] p00,p01,p02,p10,p11,p12,p20,p21,p22;
  assign {p22,p21,p20,p12,p11,p10,p02,p01,p00} = win_flat; // p<i><j> = flat[(i*3+j)*8+:8]

  // 12-bit signed intermediates (each side <= 1020 < 2048)
  logic signed [11:0] xp, xn, yp, yn, gx_full, gy_full;
  always_comb begin
    xp = $signed({4'b0,p02}) + $signed({3'b0,p12,1'b0}) + $signed({4'b0,p22});
    xn = $signed({4'b0,p00}) + $signed({3'b0,p10,1'b0}) + $signed({4'b0,p20});
    yp = $signed({4'b0,p20}) + $signed({3'b0,p21,1'b0}) + $signed({4'b0,p22});
    yn = $signed({4'b0,p00}) + $signed({3'b0,p01,1'b0}) + $signed({4'b0,p02});
    gx_full = xp - xn;
    gy_full = yp - yn;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) out_valid <= 1'b0;
    else        out_valid <= in_valid;
  end
  always_ff @(posedge clk) begin
    if (in_valid) begin
      ix <= gx_full[10:0];   // safe: |gx_full| <= 1020
      iy <= gy_full[10:0];
    end
  end
endmodule
