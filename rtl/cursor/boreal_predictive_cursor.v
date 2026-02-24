/*
 * boreal_predictive_cursor.v
 *
 * Advanced Latency Compensation for BCI Cursor Control.
 * 
 * Model: Second-Order State-Space-ish Predictor
 * v_pred = v + (dv/dt * K1) + (d2v/dt2 * K2)
 *
 * Includes Adaptive Deadzone to suppress prediction noise at low velocities.
 */
module boreal_predictive_cursor (
    input  wire        clk,
    input  wire        rst,
    input  wire        valid,
    input  wire signed [23:0] vx_in,
    input  wire signed [23:0] vy_in,

    // Runtime Control (MMIO)
    input  wire [15:0] k1_gain,    // Primary acceleration lead
    input  wire [15:0] k2_gain,    // Jerk compensation
    input  wire [7:0]  deadzone,   // Noise floor threshold
    
    output reg  signed [23:0] vx_pred,
    output reg  signed [23:0] vy_pred
);

    // Filtered state members
    reg signed [23:0] vx_last, vy_last;
    reg signed [23:0] ax, ay;
    reg signed [23:0] ax_last, ay_last;
    reg signed [23:0] jx, jy;

    always @(posedge clk) begin
        if (rst) begin
            vx_last <= 0; vy_last <= 0;
            ax <= 0; ay <= 0;
            ax_last <= 0; ay_last <= 0;
            jx <= 0; jy <= 0;
            vx_pred <= 0; vy_pred <= 0;
        end else if (valid) begin
            // 1. Calculate derivatives
            ax <= vx_in - vx_last;            // acceleration
            ay <= vy_in - vy_last;
            
            jx <= ax - ax_last;               // jerk
            jy <= ay - ay_last;

            // 2. Deadzone logic (Zero-centered suppression)
            // Absolute value logic in signed math
            if ((vx_in > $signed({16'b0, deadzone})) || (vx_in < -$signed({16'b0, deadzone})) ||
                (vy_in > $signed({16'b0, deadzone})) || (vy_in < -$signed({16'b0, deadzone}))) 
            begin
                // 3. Second-Order Prediction: p = v + v' * K1 + v'' * K2
                vx_pred <= vx_in + ((ax * k1_gain) >>> 15) + ((jx * k2_gain) >>> 15);
                vy_pred <= vy_in + ((ay * k1_gain) >>> 15) + ((jy * k2_gain) >>> 15);
            end else begin
                // Suppress prediction noise in deadzone
                vx_pred <= 0;
                vy_pred <= 0;
            end

            // 4. Update memory
            vx_last <= vx_in;
            vy_last <= vy_in;
            ax_last <= ax;
            ay_last <= ay;
        end
    end

endmodule
