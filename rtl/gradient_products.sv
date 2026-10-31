// gradient_products.sv -- Pxx=Ix*Ix, Pyy=Iy*Iy, Pxy=Ix*Iy. Latency 1 clock.
// |Ix|,|Iy| <= 1020  => Pxx,Pyy in [0,1040400] -> 20-bit UNSIGNED (2^20=1048576)
//                       Pxy in [-1040400,1040400] -> 21-bit SIGNED
// Full products are formed in 22-bit signed (exact), then the proven-safe low bits are kept.
module gradient_products (
  input  logic               clk,
  input  logic               rst_n,
  input  logic signed [10:0] ix,
  input  logic signed [10:0] iy,
  input  logic               in_valid,
  output logic        [19:0] pxx,
  output logic        [19:0] pyy,
  output logic signed [20:0] pxy,
  output logic               out_valid
);
  logic signed [21:0] xx_full, yy_full, xy_full;
  always_comb begin
    xx_full = ix * ix;   // operands sign-extended to 22 bits by the assignment context: exact
    yy_full = iy * iy;
    xy_full = ix * iy;
  end
  always_ff @(posedge clk) begin
    if (!rst_n) out_valid <= 1'b0;
    else        out_valid <= in_valid;
  end
  always_ff @(posedge clk) begin
    if (in_valid) begin
      pxx <= xx_full[19:0];
      pyy <= yy_full[19:0];
      pxy <= xy_full[20:0];
    end
  end
endmodule
