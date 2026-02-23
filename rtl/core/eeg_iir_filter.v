module eeg_iir_filter(
    input  wire clk,
    input  wire rst,
    input  wire valid,
    input  wire signed [15:0] x_in,
    output reg  signed [15:0] y_out
);

// Simple cascaded HP + LP (bandpass ~1–30 Hz equivalent in scaled domain)
// Coefficients are safe placeholders; tune later

reg signed [31:0] hp_z1;
reg signed [31:0] lp_z1;

always @(posedge clk) begin
    if (rst) begin
        hp_z1 <= 0;
        lp_z1 <= 0;
        y_out <= 0;
    end else if (valid) begin
        // High-pass
        hp_z1 <= hp_z1 + x_in - (hp_z1 >>> 6);

        // Low-pass
        lp_z1 <= lp_z1 + (hp_z1 >>> 3) - (lp_z1 >>> 5);

        y_out <= lp_z1[23:8];
    end
end

endmodule
