/*
 * boreal_biquad.v
 *
 * Fixed-point Biquad Direct Form I Implementation.
 * Optimized for numerical stability in physiological signal processing.
 * 
 * Equation: y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
 * 
 * Coefficients: 16-bit Q15.
 * Dynamic loading supported via register interface.
 */
module boreal_biquad #(
    parameter signed [15:0] DEFAULT_B0 = 16'h7FFF, // 1.0 (Q15)
    parameter signed [15:0] DEFAULT_B1 = 0,
    parameter signed [15:0] DEFAULT_B2 = 0,
    parameter signed [15:0] DEFAULT_A1 = 0,
    parameter signed [15:0] DEFAULT_A2 = 0
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        valid,
    input  wire signed [23:0] x_in,
    output reg  signed [23:0] y_out,

    // Runtime Coefficient Loading
    input  wire [2:0]  reg_addr, // 0:b0, 1:b1, 2:b2, 3:a1, 4:a2
    input  wire [15:0] reg_din,
    input  wire        reg_we
);

    reg signed [15:0] b0, b1, b2, a1, a2;
    reg signed [23:0] x1, x2, y1, y2;

    // Loadable coefficients
    always @(posedge clk) begin
        if (rst) begin
            b0 <= DEFAULT_B0; b1 <= DEFAULT_B1; b2 <= DEFAULT_B2;
            a1 <= DEFAULT_A1; a2 <= DEFAULT_A2;
        end else if (reg_we) begin
            case (reg_addr)
                3'd0: b0 <= reg_din; // 0x00
                3'd1: b1 <= reg_din; // 0x04 (assuming lower bits of bus address)
                3'd2: b2 <= reg_din; // 0x08
                3'd3: a1 <= reg_din; // 0x0C
                3'd4: a2 <= reg_din; // 0x10
            endcase
        end
    end

    // Signal processing loop (Direct Form I)
    wire signed [47:0] term0 = b0 * x_in;
    wire signed [47:0] term1 = b1 * x1;
    wire signed [47:0] term2 = b2 * x2;
    wire signed [47:0] term3 = a1 * y1;
    wire signed [47:0] term4 = a2 * y2;

    wire signed [47:0] sum = term0 + term1 + term2 - term3 - term4;

    always @(posedge clk) begin
        if (rst) begin
            x1 <= 0; x2 <= 0;
            y1 <= 0; y2 <= 0;
            y_out <= 0;
        end else if (valid) begin
            y_out <= sum >>> 15; // Q15 scale correction
            
            // Shift registers
            x2 <= x1;
            x1 <= x_in;
            y2 <= y1;
            y1 <= sum >>> 15;
        end
    end

endmodule
