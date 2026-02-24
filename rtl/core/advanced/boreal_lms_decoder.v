/*
 * boreal_lms_decoder.v
 *
 * Adaptive Inference Engine (Least Mean Squares)
 *
 * Implements online gradient descent to adapt the projection weights 
 * based on an error signal. This allows the system to continuously "learn"
 * and personalize to the user's changing neural signatures over time.
 *
 * Update rule: w(t+1) = w(t) + eta * error * x(t)
 */
module boreal_lms_decoder (
    input  wire        clk,
    input  wire        rst,
    
    // Feature Input (e.g., from Kalman State)
    input  wire        valid_in,
    input  wire signed [23:0] x_in_0, // Latent feature 0
    input  wire signed [23:0] x_in_1, // Latent feature 1
    
    // Target / Error Signal (from external reward/gating)
    input  wire        error_valid,
    input  wire signed [23:0] error_signal,
    
    // Configuration
    input  wire [3:0]  eta_shift, // Learning rate divisor (2^-eta)
    input  wire        freeze,    // Stop learning
    
    // Decoded Output
    output reg         valid_out,
    output reg  signed [23:0] y_out
);

    // Adaptive Weights (Q15 format)
    reg signed [15:0] w0;
    reg signed [15:0] w1;
    
    // Pipeline Registers
    reg signed [40:0] acc;
    reg [1:0] p_state;
    
    // Gradient computation
    wire signed [47:0] grad_0 = error_signal * x_in_0;
    wire signed [47:0] grad_1 = error_signal * x_in_1;
    
    always @(posedge clk) begin
        if (rst) begin
            w0 <= 0;
            w1 <= 0;
            y_out <= 0;
            valid_out <= 0;
            p_state <= 0;
        end else begin
            valid_out <= 0;
            
            // 1. Inference Pipeline
            case (p_state)
                0: begin
                    if (valid_in) begin
                        acc <= (x_in_0 * w0) + (x_in_1 * w1);
                        p_state <= 1;
                    end
                end
                1: begin
                    y_out <= acc >>> 15; // Shift down from Q15 multiply
                    valid_out <= 1;
                    p_state <= 0;
                end
            endcase
            
            // 2. Adaptation logic (runs asynchronously to inference)
            if (error_valid && !freeze) begin
                // Update weights using LMS rule
                // We use eta_shift to divide the gradient (bitwise right shift)
                w0 <= w0 + (grad_0[39:24] >>> eta_shift);
                w1 <= w1 + (grad_1[39:24] >>> eta_shift);
            end
        end
    end

endmodule
