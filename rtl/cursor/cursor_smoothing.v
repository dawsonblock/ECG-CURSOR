/*
 * 2-D IIR Cursor Smoothing Filter
 *
 * y[n] = y[n-1] + alpha * (x[n] - y[n-1])
 *
 * ALPHA is in Q8 fixed-point (e.g., 51 ≈ 0.2 = gentle smooth, 128 ≈ 0.5 = fast response).
 * Uses 32-bit intermediate arithmetic to avoid truncation-to-zero on small deltas.
 */
module cursor_smoothing #(
    parameter signed [15:0] ALPHA = 16'sd51  // ~0.2 in Q8: moderate smoothing
)(
    input  wire clk,
    input  wire rst_n,
    input  wire signed [15:0] mu_x,
    input  wire signed [15:0] mu_y,
    output reg  signed [15:0] mu_x_f,
    output reg  signed [15:0] mu_y_f
);

    // Use 32-bit intermediates to preserve precision during multiply+shift
    wire signed [31:0] diff_x = $signed(mu_x) - $signed(mu_x_f);
    wire signed [31:0] diff_y = $signed(mu_y) - $signed(mu_y_f);

    wire signed [31:0] step_x = (diff_x * ALPHA) >>> 8;
    wire signed [31:0] step_y = (diff_y * ALPHA) >>> 8;

    always @(posedge clk) begin
        if (!rst_n) begin
            mu_x_f <= 16'sd0;
            mu_y_f <= 16'sd0;
        end else begin
            mu_x_f <= mu_x_f + step_x[15:0];
            mu_y_f <= mu_y_f + step_y[15:0];
        end
    end

endmodule
