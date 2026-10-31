// boxsum5x5.sv -- streaming 5x5 box sums of Pxx, Pyy, Pxy.
// Input tokens are the INTERIOR product stream of an IMG_W x IMG_H image (raster order, gaps allowed).
// In harris_top IMG_W = W-2, IMG_H = H-2 (the interior image). Input token = pixel (r,c) of that image.
// Architecture: 4 line buffers/channel -> vertical 5-sum (stage A) -> 5-column shift + horizontal
// 5-sum (stage B). Latency 2 clocks. State advances only on tokens (in_valid), never stalls on gaps.
// out_valid=1 iff r>=4 && c>=4; the sum covers rows r-4..r, cols c-4..c, i.e. centre (r-2, c-2).
// Widths: Pxx,Pyy 20u -> 25u ; Pxy 21s -> 26s  (25*1040400 = 26,010,000 < 2^25 = 33,554,432)
module boxsum_ch #(
  parameter int IN_W  = 20,
  parameter bit SGN   = 1'b0,
  parameter int IMG_W = 8,
  parameter int CWID  = 3
) (
  input  logic              clk,
  input  logic              en_a,        // token enters stage A
  input  logic [CWID-1:0]   col_idx,
  input  logic [IN_W-1:0]   din,
  input  logic              en_b,        // token enters stage B (en_a delayed 1 clk)
  output logic [IN_W+4:0]   sum_out
);
  // Internal arithmetic is signed; unsigned channels get one extra bit so values never alias the sign bit.
  localparam int CS_W  = IN_W + 4;       // holds 5-term sum as signed
  localparam int OUT_W = IN_W + 6;       // holds 25-term sum as signed; output keeps low IN_W+5 bits (value range proven to fit)

  logic [IN_W-1:0] lb0 [0:IMG_W-1];
  logic [IN_W-1:0] lb1 [0:IMG_W-1];
  logic [IN_W-1:0] lb2 [0:IMG_W-1];
  logic [IN_W-1:0] lb3 [0:IMG_W-1];

  function automatic logic signed [CS_W-1:0] ext(input logic [IN_W-1:0] v);
    if (SGN) ext = $signed({{4{v[IN_W-1]}}, v});
    else     ext = $signed({4'b0000, v});
  endfunction

  logic signed [CS_W-1:0]  colsum_n, colsum_r;
  logic signed [CS_W-1:0]  cs0, cs1, cs2, cs3;
  logic signed [OUT_W-1:0] tot;

  assign colsum_n = ext(din) + ext(lb0[col_idx]) + ext(lb1[col_idx]) + ext(lb2[col_idx]) + ext(lb3[col_idx]);
  assign tot = OUT_W'(cs0) + OUT_W'(cs1) + OUT_W'(cs2) + OUT_W'(cs3) + OUT_W'(colsum_r);

  always_ff @(posedge clk) begin
    if (en_a) begin
      lb0[col_idx] <= din;
      lb1[col_idx] <= lb0[col_idx];
      lb2[col_idx] <= lb1[col_idx];
      lb3[col_idx] <= lb2[col_idx];
      colsum_r     <= colsum_n;
    end
    if (en_b) begin
      cs0 <= cs1; cs1 <= cs2; cs2 <= cs3; cs3 <= colsum_r;
      sum_out <= tot[IN_W+4:0];
    end
  end
endmodule

module boxsum5x5 #(
  parameter int IMG_W = 8,   // width of the image seen by this stage (>=5 to ever produce output)
  parameter int IMG_H = 8
) (
  input  logic               clk,
  input  logic               rst_n,
  input  logic        [19:0] pxx,
  input  logic        [19:0] pyy,
  input  logic signed [20:0] pxy,
  input  logic               in_valid,
  output logic        [24:0] sxx,
  output logic        [24:0] syy,
  output logic signed [25:0] sxy,
  output logic               out_valid
);
  localparam int CW = (IMG_W > 1) ? $clog2(IMG_W) : 1;
  localparam int RW = (IMG_H > 1) ? $clog2(IMG_H) : 1;

  logic [CW-1:0] col;
  logic [RW-1:0] row;
  logic tok1, ok1;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      col <= '0; row <= '0; tok1 <= 1'b0; ok1 <= 1'b0; out_valid <= 1'b0;
    end else begin
      tok1      <= in_valid;
      out_valid <= tok1 && ok1;
      if (in_valid) begin
        ok1 <= (row >= RW'(4)) && (col >= CW'(4));
        if (col == CW'(IMG_W-1)) begin
          col <= '0;
          row <= (row == RW'(IMG_H-1)) ? '0 : row + RW'(1);
        end else begin
          col <= col + CW'(1);
        end
      end
    end
  end

  boxsum_ch #(.IN_W(20), .SGN(1'b0), .IMG_W(IMG_W), .CWID(CW)) u_xx (
    .clk(clk), .en_a(in_valid), .col_idx(col), .din(pxx), .en_b(tok1), .sum_out(sxx));
  boxsum_ch #(.IN_W(20), .SGN(1'b0), .IMG_W(IMG_W), .CWID(CW)) u_yy (
    .clk(clk), .en_a(in_valid), .col_idx(col), .din(pyy), .en_b(tok1), .sum_out(syy));
  logic [25:0] sxy_u;
  boxsum_ch #(.IN_W(21), .SGN(1'b1), .IMG_W(IMG_W), .CWID(CW)) u_xy (
    .clk(clk), .en_a(in_valid), .col_idx(col), .din(pxy), .en_b(tok1), .sum_out(sxy_u));
  assign sxy = $signed(sxy_u);
endmodule
