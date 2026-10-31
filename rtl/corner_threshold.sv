// corner_threshold.sv -- corner = valid && (resp > thr). STRICTLY greater-than. Latency 1 clock.
// resp and thr are in the same scaled domain (R_s = R * 2^K_FRAC), signed R_W bits.
// Border masking: only tokens carrying in_valid (interior centres) ever produce corner_valid.
// resp_out is resp registered alongside corner_out (debug / verification alignment).
module corner_threshold #(
  parameter int R_W = 64
) (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic signed [R_W-1:0] resp,
  input  logic signed [R_W-1:0] thr,
  input  logic                  in_valid,
  output logic                  corner_out,
  output logic                  corner_valid,
  output logic signed [R_W-1:0] resp_out
);
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      corner_out   <= 1'b0;
      corner_valid <= 1'b0;
    end else begin
      corner_valid <= in_valid;
      corner_out   <= in_valid && (resp > thr);
    end
  end
  always_ff @(posedge clk) if (in_valid) resp_out <= resp;
endmodule
