/*
 * boreal_predictive_cursor.v
 *
 * Latency compensation for BCI cursor control.
 * Uses a forward-prediction model to estimate future cursor position
 * based on current velocity and acceleration.
 *
 * Model: x_pred = x + v*dt + 0.5*a*dt^2
 * Simplified for velocity control: v_pred = v + a*dt
 */
module boreal_predictive_cursor #(
    parameter GAIN = 16'h4000 // 0.5 prediction weight
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        valid,
    input  wire signed [23:0] vx_in,
    input  wire signed [23:0] vy_in,
    
    output reg  signed [23:0] vx_pred,
    output reg  signed [23:0] vy_pred
);

    reg signed [23:0] vx_last, vy_last;
    reg signed [23:0] ax, ay;

    always @(posedge clk) begin
        if (rst) begin
            vx_last <= 0; vy_last <= 0;
            ax <= 0; ay <= 0;
            vx_pred <= 0; vy_pred <= 0;
        end else if (valid) begin
            // Estimate acceleration (dv/dt)
            ax <= vx_in - vx_last;
            ay <= vy_in - vy_last;
            
            // Predict future velocity: v_pred = v + gain * acceleration
            vx_pred <= vx_in + ((ax * GAIN) >>> 15);
            vy_pred <= vy_in + ((ay * GAIN) >>> 15);
            
            vx_last <= vx_in;
            vy_last <= vy_in;
        end
    end

endmodule
