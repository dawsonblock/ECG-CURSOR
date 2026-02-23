module eeg_iir_filter(
    input  wire clk,
    input  wire rst,
    input  wire valid,
    input  wire signed [15:0] x_in,
    output reg  signed [15:0] y_out
);

// Simple cascaded HP + LP (bandpass ~1–30 Hz equivalent in scaled domain)
// Coefficients are safe placeholders; tune later

    reg signed [31:0] hp_z1; // HP state (leaky integrator of DC)
    reg signed [31:0] lp_z1; // LP state

    always @(posedge clk) begin
        if (rst) begin
            hp_z1 <= 0;
            lp_z1 <= 0;
            y_out <= 0;
        end else if (valid) begin
            // 1. High-pass stage (DC Blocker)
            // State tracks DC. hp_out is signal - DC.
            hp_z1 <= hp_z1 + x_in - (hp_z1 >>> 6);
            
            // 2. Low-pass stage (Anti-aliasing / smoothing)
            // Integrates the HP result. Settles at 16 * hp_out.
            lp_z1 <= lp_z1 + (x_in - (hp_z1 >>> 6)) - (lp_z1 >>> 4);

            y_out <= lp_z1[19:4]; // Unity gain slice (16 * hp_out >> 4)
        end
    end

endmodule
