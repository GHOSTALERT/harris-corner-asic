// harris_response.sv -- R_s = 2^K_FRAC * (Sxx*Syy - Sxy^2) - K_Q * (Sxx+Syy)^2     (exact integer arithmetic)
// Equivalent to R = det(M) - k*trace(M)^2 with k = K_Q / 2^K_FRAC, scaled by 2^K_FRAC. The only
// quantisation is the representation of k itself (K_FRAC=10: step 1/1024); no rounding/truncation in the datapath.
// Latency 4 clocks (S1 products/trace, S2 det/trace^2, S3 scale/k*trace^2, S4 subtract).
// Widths (defaults K_FRAC=10): prod 50u, trace 26u, det 51s, trace^2 52u, det<<K 61s, K*tr^2 63u, R_s 64s.
module harris_response #(
  parameter int K_FRAC = 10,                 // k = k_q / 2^K_FRAC ; k_q is K_FRAC+1 bits (k < 2)
  parameter int K_W    = K_FRAC + 1,
  parameter int R_W    = 54 + K_FRAC         // = 64 for K_FRAC=10 (see docs/arithmetic_analysis.md)
) (
  input  logic                    clk,
  input  logic                    rst_n,
  input  logic        [24:0]      sxx,
  input  logic        [24:0]      syy,
  input  logic signed [25:0]      sxy,
  input  logic        [K_W-1:0]   k_q,
  input  logic                    in_valid,
  output logic signed [R_W-1:0]   resp,
  output logic                    out_valid
);
  localparam int KTR_W = 52 + K_W;
  localparam int DS_W  = 51 + K_FRAC;

  logic [3:0] vpipe;
  always_ff @(posedge clk) begin
    if (!rst_n) vpipe <= 4'b0;
    else        vpipe <= {vpipe[2:0], in_valid};
  end
  assign out_valid = vpipe[3];

  // S1
  logic [49:0] p_xy_yy, p_sxy2;      // Sxx*Syy ; Sxy^2
  logic [25:0] trace;
  logic [25:0] sxy_abs;
  assign sxy_abs = sxy[25] ? (~sxy + 26'd1) : sxy;   // |Sxy| <= 26,010,000 < 2^25
  always_ff @(posedge clk) begin
    if (in_valid) begin
      p_xy_yy <= sxx * syy;                      // 25x25 -> 50u exact (<= 6.76e14 < 2^50)
      p_sxy2  <= sxy_abs * sxy_abs;              // value <= 6.76e14 < 2^50: low 50 bits exact
      trace   <= {1'b0, sxx} + {1'b0, syy};      // 26u
    end
  end

  // S2
  logic signed [50:0] det;
  logic        [51:0] tr_sq;
  always_ff @(posedge clk) begin
    if (vpipe[0]) begin
      det   <= $signed({1'b0, p_xy_yy}) - $signed({1'b0, p_sxy2});   // 51s exact
      tr_sq <= trace * trace;                                        // 52u exact (<= 2.71e15 < 2^52)
    end
  end

  // S3
  logic signed [DS_W-1:0]  det_s;
  logic        [KTR_W-1:0] ktr;
  always_ff @(posedge clk) begin
    if (vpipe[1]) begin
      det_s <= {det, {K_FRAC{1'b0}}};                                       // det * 2^K_FRAC, exact
      ktr   <= {{(KTR_W-K_W){1'b0}}, k_q} * {{(KTR_W-52){1'b0}}, tr_sq};   // exact
    end
  end

  // S4
  logic signed [R_W-1:0] det_s_x, ktr_x;
  always_comb begin
    det_s_x = R_W'(det_s);                                   // sign-extend
    ktr_x   = $signed({{(R_W-KTR_W){1'b0}}, ktr});           // zero-extend (non-negative)
  end
  always_ff @(posedge clk) begin
    if (vpipe[2]) resp <= det_s_x - ktr_x;
  end
endmodule
