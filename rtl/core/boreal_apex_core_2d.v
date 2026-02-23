/*
 * Boreal Neuro-Core 2-D Active Inference Engine
 *
 * Update rule per axis:
 *   epsilon = filtered_sample - sigma(mu)
 *   delta   = (eta * epsilon * sigma') - (lambda * mu)
 *   mu_new  = sat16(mu + delta)
 *
 * Fixed-point notes:
 *   - ADC input: 24-bit signed
 *   - DC-block accumulator: 32-bit, output truncated to [15:0] (16-bit)
 *   - sigma'(mu) = 0.25 = 64 in Q8
 *   - eps * sigma' product is 32-bit; extract [21:6] for eta=1/4 scaling
 *   - lambda = 1/16: mu >>> 4
 */
module boreal_apex_core_2d #(
    parameter ADDR_WIDTH = 10,
    parameter CHANNELS   = 8,
    parameter ALPHA      = 16'h7EB8
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        emergency_halt_n,

    input  wire [23:0] raw_adc_in,
    input  wire [2:0]  adc_channel_sel,
    input  wire        adc_data_ready,

    output reg signed [15:0] mu_x,
    output reg signed [15:0] mu_y
);

    // =========================================================================
    // 1. DC-Blocking filter
    //    y[n] = (x[n] - x[n-1]) + alpha * y[n-1]
    //    alpha = 0.99 in Q15 = 0x7EB8
    //    Output: lower 16 bits of accumulator (not upper — values are small)
    // =========================================================================
    reg  signed [23:0] last_raw [0:CHANNELS-1];
    reg  signed [31:0] filter_acc [0:CHANNELS-1];
    wire signed [15:0] filtered_sample;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < CHANNELS; i = i + 1) begin
                last_raw[i]   <= 24'sd0;
                filter_acc[i] <= 32'sd0;
            end
        end else if (adc_data_ready) begin
            filter_acc[adc_channel_sel] <=
                ($signed(raw_adc_in) - last_raw[adc_channel_sel]) +
                ((filter_acc[adc_channel_sel] * $signed(ALPHA)) >>> 15);
            last_raw[adc_channel_sel] <= $signed(raw_adc_in);
        end
    end

    // Use [15:0] — the meaningful range for test and real ADC values
    assign filtered_sample = filter_acc[adc_channel_sel][15:0];

    // =========================================================================
    // 2. Prediction
    //    sigma(mu) ≈ mu/4, sigma'(mu) ≈ 0.25 constant
    // =========================================================================
    wire signed [15:0] sigma_x = mu_x >>> 2;
    wire signed [15:0] sigma_y = mu_y >>> 2;

    // =========================================================================
    // 3. Active Inference Engine (Pipelined)
    // =========================================================================
    wire signed [15:0] eps_x = filtered_sample - sigma_x;
    wire signed [15:0] eps_y = filtered_sample - sigma_y;

    localparam signed [15:0] SIGMA_DERIV = 16'sd64; // 0.25 in Q8

    // Pipeline Stage 1: Multiplication
    reg signed [31:0] grad_x_reg, grad_y_reg;
    reg signed [15:0] mu_x_r1, mu_y_r1;
    reg               adc_ready_r1;

    always @(posedge clk) begin
        if (!rst_n) begin
            grad_x_reg <= 0;
            grad_y_reg <= 0;
            mu_x_r1 <= 0;
            mu_y_r1 <= 0;
            adc_ready_r1 <= 0;
        end else begin
            grad_x_reg <= eps_x * SIGMA_DERIV;
            grad_y_reg <= eps_y * SIGMA_DERIV;
            mu_x_r1 <= mu_x;
            mu_y_r1 <= mu_y;
            adc_ready_r1 <= adc_data_ready;
        end
    end

    // Extract scaled gradient from piped reg
    wire signed [15:0] delta_x = grad_x_reg[25:10];
    wire signed [15:0] delta_y = grad_y_reg[25:10];

    // Decay
    wire signed [15:0] decay_x = mu_x_r1 >>> 4;
    wire signed [15:0] decay_y = mu_y_r1 >>> 4;

    // Saturated update
    wire signed [31:0] mu_x_next = $signed(mu_x_r1) + $signed(delta_x) - $signed(decay_x);
    wire signed [31:0] mu_y_next = $signed(mu_y_r1) + $signed(delta_y) - $signed(decay_y);

    function signed [15:0] sat16(input signed [31:0] v);
        if (v > 32'sd32767)       sat16 = 16'sd32767;
        else if (v < -32'sd32768) sat16 = -16'sd32768;
        else                      sat16 = v[15:0];
    endfunction

    always @(posedge clk) begin
        if (!emergency_halt_n || !rst_n) begin
            mu_x <= 16'sd0;
            mu_y <= 16'sd0;
        end else if (adc_ready_r1) begin
            mu_x <= sat16(mu_x_next);
            mu_y <= sat16(mu_y_next);
        end
    end

endmodule
