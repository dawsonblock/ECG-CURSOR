/*
 * boreal_artifact_monitor.v
 *
 * detects non-physiological signal events and raises safety flags.
 * bits: [0] saturation, [1] variance spike (EMG), [2] flatline, [3] SPI drop
 */
module boreal_artifact_monitor #(
    parameter signed [23:0] SAT_TH = 24'sd8000000,
    parameter [31:0] VAR_TH = 32'd200000000,
    parameter [7:0] FLAT_LIMIT = 8'd50
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        valid,
    input  wire signed [23:0] x,
    output reg  [3:0]  flags
);

    reg signed [23:0] prev;
    reg [31:0]        var_acc;
    reg [7:0]         flat_cnt;

    always @(posedge clk) begin
        if (rst) begin
            flags <= 0;
            prev <= 0;
            var_acc <= 0;
            flat_cnt <= 0;
        end else if (valid) begin
            // 0: Saturation
            flags[0] <= (x > SAT_TH) || (x < -SAT_TH);

            // 1: Variance / EMG Spike
            var_acc <= var_acc - (var_acc >> 4) + (((x - prev) * (x - prev)) >> 4);
            flags[1] <= (var_acc > VAR_TH);

            // 2: Flatline Detection
            if (x == prev) begin
                if (flat_cnt < FLAT_LIMIT) flat_cnt <= flat_cnt + 1;
                else flags[2] <= 1;
            end else begin
                flat_cnt <= 0;
                flags[2] <= 0;
            end

            prev <= x;
        end
    end

endmodule
