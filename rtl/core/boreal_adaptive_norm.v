/*
 * boreal_adaptive_norm.v
 *
 * Implements online Z-score normalization: z = (x - mu) / sigma
 * Maintains running mean (mu) and variance (var) via EMA.
 * Processes 8 channels sequentially to conserve resources.
 */
module boreal_adaptive_norm #(
    parameter ALPHA_SHIFT = 6 // EMA weight = 1/64
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        valid,   // Pulse when new frame is ready
    input  wire [127:0] features_in, // 8 x 16-bit
    input  wire        lock,    // Freeze EMA updates (use during active control)

    output reg  [127:0] features_out,
    output reg         done
);

    reg [2:0]  state;
    reg [2:0]  ch_idx;
    reg signed [31:0] mu [0:7];
    reg signed [47:0] var_acc [0:7];
    reg signed [15:0] z_out [0:7];

    wire signed [15:0] x_current = features_in[ch_idx*16 +: 16];
    
    // Internal signals for math
    reg signed [31:0] diff;
    reg signed [47:0] sq_diff;
    reg signed [31:0] sigma;

    always @(posedge clk) begin
        integer i;
        if (rst) begin
            state <= 0;
            ch_idx <= 0;
            done <= 0;
            features_out <= 0;
            for (i=0; i<8; i=i+1) begin
                mu[i] <= 0;
                var_acc[i] <= 48'h0000_1000_0000; // Initial variance to avoid div-by-zero
                z_out[i] <= 0;
            end
        end else begin
            done <= 0;

            case (state)
                0: begin // Idle
                    if (valid) begin
                        state <= 1;
                        ch_idx <= 0;
                    end
                end

                1: begin // Calculate Diff
                    diff <= (x_current << 8) - mu[ch_idx];
                    state <= 2;
                end

                2: begin // Update Stats (if not locked)
                    sq_diff <= diff * diff;
                    if (!lock) begin
                        mu[ch_idx] <= mu[ch_idx] + (diff >>> ALPHA_SHIFT);
                    end
                    state <= 3;
                end

                3: begin // Update Var and Calculate Z
                    if (!lock) begin
                        var_acc[ch_idx] <= var_acc[ch_idx] + ((sq_diff - var_acc[ch_idx]) >>> ALPHA_SHIFT);
                    end
                    
                    // Simple Z calculation: z = diff / sigma
                    // For now, we use a fixed scale division approximation
                    // In a final build, a real iterative divider or LUT would be here.
                    z_out[ch_idx] <= diff[23:8]; // Placeholder for scaled normalization
                    
                    if (ch_idx == 7) begin
                        state <= 4;
                    end else begin
                        ch_idx <= ch_idx + 1;
                        state <= 1;
                    end
                end

                4: begin // Packing
                    features_out <= {z_out[7], z_out[6], z_out[5], z_out[4], 
                                     z_out[3], z_out[2], z_out[1], z_out[0]};
                    done <= 1;
                    state <= 0;
                end
            endcase
        end
    end

endmodule
