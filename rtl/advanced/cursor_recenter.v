/*
 * Cursor Drift Compensation / Recenter Logic
 *
 * Detects slow persistent unidirectional bias in the smoothed mu values
 * when no deliberate motion is intended (dx/dy near zero for extended period).
 * Applies a counter-bias offset that accumulates slowly to recenter the
 * internal manifold, preventing the cursor from creeping off-screen over time.
 *
 * Also supports a manual recenter pulse to instantly zero the offset.
 */
module cursor_recenter #(
    parameter IDLE_THRESHOLD   = 8'sd1,
    parameter IDLE_CYCLES      = 50_000_000,  // 500 ms @100 MHz before correction starts
    parameter signed [15:0] DRIFT_RATE = 16'sd1, // correction step per cycle after idle
    parameter signed [15:0] OFFSET_MAX = 16'sd2000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire recenter_pulse,  // manual recenter trigger
    
    input  wire signed [7:0] dx,
    input  wire signed [7:0] dy,
    input  wire signed [15:0] mu_x_f,
    input  wire signed [15:0] mu_y_f,
    
    output reg  signed [15:0] mu_x_corrected,
    output reg  signed [15:0] mu_y_corrected
);

    reg [25:0] idle_counter; // 500ms at 100MHz is 50M (26 bits)
    reg signed [15:0] offset_x;
    reg signed [15:0] offset_y;
    
    wire is_idle = (dx <= IDLE_THRESHOLD && dx >= -IDLE_THRESHOLD &&
                    dy <= IDLE_THRESHOLD && dy >= -IDLE_THRESHOLD);

    // Saturating offset clamp
    function signed [15:0] sat_offset(input signed [15:0] val, input signed [15:0] delta);
        reg signed [31:0] result;
        begin
            result = $signed(val) + $signed(delta);
            if (result > $signed(OFFSET_MAX))       sat_offset = OFFSET_MAX;
            else if (result < $signed(-OFFSET_MAX)) sat_offset = -OFFSET_MAX;
            else                                    sat_offset = result[15:0];
        end
    endfunction

    always @(posedge clk) begin
        if (!rst_n || recenter_pulse) begin
            idle_counter <= 0;
            offset_x <= 0;
            offset_y <= 0;
        end else begin
            if (is_idle) begin
                if (idle_counter < 26'h3FF_FFFF)
                    idle_counter <= idle_counter + 1;
                    
                // After sustained idle, slowly pull offset toward current mu bias
                if (idle_counter >= IDLE_CYCLES) begin
                    // If mu is drifting positive, apply negative offset
                    // Added a bit more deadzone (150) to prevent hunting
                    if (mu_x_f > 16'sd150)
                        offset_x <= sat_offset(offset_x, -DRIFT_RATE);
                    else if (mu_x_f < -16'sd150)
                        offset_x <= sat_offset(offset_x, DRIFT_RATE);
                        
                    if (mu_y_f > 16'sd150)
                        offset_y <= sat_offset(offset_y, -DRIFT_RATE);
                    else if (mu_y_f < -16'sd150)
                        offset_y <= sat_offset(offset_y, DRIFT_RATE);
                end
            end else begin
                idle_counter <= 0;
            end
        end
    end

    // Apply correction
    always @(posedge clk) begin
        if (!rst_n) begin
            mu_x_corrected <= 0;
            mu_y_corrected <= 0;
        end else begin
            mu_x_corrected <= mu_x_f + offset_x;
            mu_y_corrected <= mu_y_f + offset_y;
        end
    end

endmodule
