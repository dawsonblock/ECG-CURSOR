/*
 * kalman_smoothing.v
 *
 * Implements a predictive single-tap Kalman-style filter.
 * Reduce lag while maintaining noise rejection.
 * x_new = x_prev + K * (measurement - x_prev)
 */
module kalman_smoothing #(
    parameter GAIN_K = 51 // K = 0.2 in Q8 (51/256)
)(
    input  wire clk,
    input  wire rst,
    input  wire signed [15:0] x_in,
    output reg  signed [15:0] x_out
);

    reg signed [23:0] state; // Q8 internal precision

    always @(posedge clk) begin
        if (rst) begin
            state <= 0;
            x_out <= 0;
        end else begin
            // state = state + (x_in - state_val) * K
            // where state_val is state >>> 8
            state <= state + ((x_in - (state >>> 8)) * GAIN_K);
            x_out <= state[23:8];
        end
    end

endmodule
