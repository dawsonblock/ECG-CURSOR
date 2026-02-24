/*
 * boreal_biquad.v
 *
 * Fixed-point Biquad Direct Form II Implementation.
 * b0, b1, b2, a1, a2 are 16-bit Q15 coefficients.
 * Internal precision is 32-bit.
 */
module boreal_biquad #(
    parameter signed [15:0] B0 = 16'h7FFF, // 1.0
    parameter signed [15:0] B1 = 0,
    parameter signed [15:0] B2 = 0,
    parameter signed [15:0] A1 = 0,
    parameter signed [15:0] A2 = 0
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        valid,
    input  wire signed [23:0] x,
    output reg  signed [23:0] y
);

    reg signed [31:0] z1, z2;

    always @(posedge clk) begin
        if (rst) begin
            z1 <= 0;
            z2 <= 0;
            y  <= 0;
        end else if (valid) begin
            // y[n] = b0*x[n] + z1[n-1]
            // z1[n] = b1*x[n] - a1*y[n] + z2[n-1]
            // z2[n] = b2*x[n] - a2*y[n]
            
            y <= (B0 * x + z1) >>> 15;
            z1 <= B1 * x - A1 * y + z2;
            z2 <= B2 * x - A2 * y;
        end
    end

endmodule
