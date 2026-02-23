/*
 * Cursor Adaptive Gain Auto-Tuning
 * 
 * Dynamically adjusts the cursor velocity gain based on user performance.
 * - Successful dwell clicks (positive feedback) → increase gain toward cap.
 * - Rapid direction reversals (oscillation / overshoot) → decrease gain.
 * - Gain bounded between GAIN_MIN and GAIN_MAX.
 * - Uses fixed-point Q8.8 representation for sub-integer adjustments.
 */
module cursor_adaptive_gain #(
    parameter signed [15:0] GAIN_MIN   = 16'sd64,   // 0.25 in Q8.8
    parameter signed [15:0] GAIN_MAX   = 16'sd1024,  // 4.0  in Q8.8
    parameter signed [15:0] GAIN_INIT  = 16'sd256,   // 1.0  in Q8.8
    parameter signed [15:0] GAIN_UP    = 16'sd4,     // +0.015 per success
    parameter signed [15:0] GAIN_DOWN  = 16'sd8,     // -0.03  per reversal
    parameter REVERSAL_WINDOW          = 1_000_000   // 10 ms @100 MHz
)(
    input  wire clk,
    input  wire rst_n,
    
    // Feedback signals
    input  wire        click_success,    // Pulse: user completed a dwell click
    input  wire signed [7:0] dx,
    input  wire signed [7:0] dy,
    
    // Current adaptive gain output (Q8.8)
    output reg  signed [15:0] gain_out
);

    // --- Reversal detection ---
    reg signed [7:0] prev_dx, prev_dy;
    reg [19:0] reversal_timer; // ~10ms at 100MHz is 1M cycles (20 bits)
    reg [19:0] cooldown_timer;
    reg        reversal_detected;

    wire sign_flip_x = (dx[7] != prev_dx[7]) && (dx != 0) && (prev_dx != 0);
    wire sign_flip_y = (dy[7] != prev_dy[7]) && (dy != 0) && (prev_dy != 0);

    always @(posedge clk) begin
        if (!rst_n) begin
            prev_dx <= 0;
            prev_dy <= 0;
            reversal_timer <= 20'hF_FFFF;
            cooldown_timer <= 0;
            reversal_detected <= 0;
        end else begin
            reversal_detected <= 0;
            
            if (cooldown_timer > 0) begin
                cooldown_timer <= cooldown_timer - 1;
            end

            // Track sign flips within a short window → overshoot indicator
            if (sign_flip_x || sign_flip_y) begin
                if (reversal_timer < REVERSAL_WINDOW && cooldown_timer == 0) begin
                    reversal_detected <= 1; // rapid reversal = overshoot
                    cooldown_timer <= 5_000_000; // 50ms cooldown
                end
                reversal_timer <= 0;
            end else begin
                if (reversal_timer < 20'hF_FFFF)
                    reversal_timer <= reversal_timer + 1;
            end
            
            prev_dx <= dx;
            prev_dy <= dy;
        end
    end

    // --- Gain adaptation ---
    always @(posedge clk) begin
        if (!rst_n) begin
            gain_out <= GAIN_INIT;
        end else begin
            if (click_success) begin
                // Successful click → user is in control → increase gain
                if (gain_out + GAIN_UP <= GAIN_MAX)
                    gain_out <= gain_out + GAIN_UP;
                else
                    gain_out <= GAIN_MAX;
            end else if (reversal_detected) begin
                // Rapid reversal → overshoot → decrease gain
                if (gain_out - GAIN_DOWN >= GAIN_MIN)
                    gain_out <= gain_out - GAIN_DOWN;
                else
                    gain_out <= GAIN_MIN;
            end
        end
    end

endmodule
