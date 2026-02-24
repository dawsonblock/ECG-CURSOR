/*
 * boreal_envelope_ema.v
 *
 * Parallel envelope detector for spectral features.
 * Equation: env = env + ((x^2 - env) >> SHIFT)
 */
module boreal_envelope_ema #(
    parameter SHIFT = 6 // α = 1/64
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        valid,
    input  wire signed [23:0] x,
    output reg  [23:0] env
);

    wire signed [47:0] sq = x * x;

    always @(posedge clk) begin
        if (rst) begin
            env <= 0;
        end else if (valid) begin
            // EMA update on the squared magnitude
            env <= env + ((sq[39:16] - env) >>> SHIFT);
        end
    end

endmodule
