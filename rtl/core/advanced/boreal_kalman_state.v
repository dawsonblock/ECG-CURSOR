/*
 * boreal_kalman_state.v
 *
 * Fixed-Point Latent State Estimator (Simplified Kalman Filter)
 *
 * Models a latent "intent" state x_t using a standard discrete state-space update.
 * This handles temporal persistence of motor imagery, preventing the system from
 * reacting wildly to instantaneous energy spikes.
 *
 * Prediction: x(t|t-1) = A * x(t-1) + B * u(t)
 * Update:     y_err    = z(t) - H * x(t|t-1)
 *             x(t|t)   = x(t|t-1) + K * y_err
 *
 * For simplicity in hardware, matrices A, H, and K are treated as static scalars
 * configured via MMIO. The control input u(t) is assumed zero for basic BCI.
 */
module boreal_kalman_state (
    input  wire        clk,
    input  wire        rst,
    
    // Feature Input (e.g., from CSP filter)
    input  wire        valid_in,
    input  wire signed [23:0] z_in, // Observation
    
    // MMIO Configurable Matrices
    input  wire signed [15:0] A_mat, // State transition (persistence)
    input  wire signed [15:0] H_mat, // Observation model
    input  wire signed [15:0] K_mat, // Kalman Gain
    
    // Filtered Output
    output reg         valid_out,
    output reg  signed [23:0] x_est
);

    // Latent State Memory
    reg signed [23:0] x_prev;
    
    // Pipeline Registers
    reg signed [39:0] x_pred; // 24-bit * 16-bit = 40-bit
    reg signed [23:0] z_pred;
    reg signed [24:0] y_err;
    reg signed [40:0] correction;
    
    reg [2:0] p_state;
    
    always @(posedge clk) begin
        if (rst) begin
            x_prev <= 0;
            x_est <= 0;
            valid_out <= 0;
            p_state <= 0;
        end else begin
            valid_out <= 0;
            
            case (p_state)
                0: begin
                    if (valid_in) begin
                        // 1. Predict state: x(t|t-1) = A * x(t-1)
                        // A_mat is Q15 format. Shift down by 15.
                        x_pred <= (x_prev * A_mat) >>> 15;
                        p_state <= 1;
                    end
                end
                
                1: begin
                    // 2. Predict observation: z_pred = H * x(t|t-1)
                    // H_mat is Q15.
                    z_pred <= (x_pred[23:0] * H_mat) >>> 15;
                    p_state <= 2;
                end
                
                2: begin
                    // 3. Calculate Innovation (Error): y_err = z_in - z_pred
                    y_err <= z_in - z_pred;
                    p_state <= 3;
                end
                
                3: begin
                    // 4. Calculate Correction: K * y_err
                    // K_mat is Q15.
                    correction <= (y_err * K_mat) >>> 15;
                    p_state <= 4;
                end
                
                4: begin
                    // 5. Update State: x(t|t) = x(t|t-1) + correction
                    x_est <= x_pred[23:0] + correction[23:0];
                    x_prev <= x_pred[23:0] + correction[23:0];
                    valid_out <= 1;
                    p_state <= 0;
                end
            endcase
        end
    end

endmodule
