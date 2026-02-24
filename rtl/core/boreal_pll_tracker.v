/*
 * boreal_pll_tracker.v
 *
 * Tracks the phase of a rhythmic signal (e.g. Alpha oscillation)
 * for phase-locked stimulation and adaptive learning rates.
 */
module boreal_pll_tracker (
    input  wire clk,
    input  wire rst_n,
    input  wire signed [15:0] signal_in,
    input  wire               data_ready,
    
    output reg  [15:0] estimated_period,
    output reg         phase_lock,
    output reg         trigger_peak,
    output reg         trigger_anti
);

    parameter MAX_PERIOD = 500; // ~0.5s @ 1kHz
    parameter MIN_PERIOD = 20;  // ~50Hz

    reg signed [15:0] signal_prev;
    reg [15:0]        period_cnt;
    reg [15:0]        last_period;

    wire rst = !rst_n;

    always @(posedge clk) begin
        if (rst) begin
            estimated_period <= 0;
            phase_lock <= 0;
            trigger_peak <= 0;
            trigger_anti <= 0;
            signal_prev <= 0;
            period_cnt <= 0;
            last_period <= 16'hFFFF;
        end else if (data_ready) begin
            period_cnt <= period_cnt + 1;
            
            // Zero-crossing detection (positive going)
            if (signal_prev <= 0 && signal_in > 0) begin
                last_period <= period_cnt;
                estimated_period <= (estimated_period >> 1) + (period_cnt >> 1); // Simple EMA
                period_cnt <= 0;
                
                // Stability check
                if (period_cnt < MAX_PERIOD && period_cnt > MIN_PERIOD) begin
                    if (period_cnt < last_period + 20 && period_cnt > last_period - 20)
                        phase_lock <= 1;
                    else
                        phase_lock <= 0;
                end else begin
                    phase_lock <= 0;
                end
            end
            
            // Trigger pulses
            trigger_peak <= (signal_prev < signal_in && signal_in > 0); // local peak approx
            trigger_anti <= (signal_prev > signal_in && signal_in < 0); // local trough approx
            
            signal_prev <= signal_in;
        end
    end

endmodule
