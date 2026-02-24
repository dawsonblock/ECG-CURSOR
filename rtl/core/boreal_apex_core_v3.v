/*
 * boreal_apex_core_v3.v
 *
 * 8-Channel Systolic Adaptive Inference Engine.
 * Implements online gradient descent for weight adaptation.
 */
module boreal_apex_core_v3 (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         bite_n,        // Hardware activation gate
    input  wire [191:0] raw8,          // 8x24-bit input samples
    input  wire         adc_valid,
    input  wire [2:0]   ch,
    input  wire         phase_lock,    // From PLL
    output reg  signed [15:0] mu0,     // Primary channel output
    output wire         low_conf       // Confidence flag
);

    // ---------- DC-block per channel ----------
    reg signed [23:0] x1 [0:7];
    reg signed [31:0] y1 [0:7];
    localparam signed [15:0] ALPHA_DC = 16'h7EB8; // ~0.99

    wire signed [23:0] xin = raw8[ch*24 +: 24];
    wire signed [15:0] samp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i;
            for (i=0; i<8; i=i+1) begin
                x1[i] <= 0;
                y1[i] <= 0;
            end
        end else if (adc_valid) begin
            y1[ch] <= (xin - x1[ch]) + ((y1[ch] * ALPHA_DC) >>> 15);
            x1[ch] <= xin;
        end
    end
    assign samp = y1[ch][31:16];

    // ---------- Memory Interface ----------
    wire [31:0] mem_dout;
    reg  [9:0]  addr_a, addr_b;
    reg  [31:0] din_b;
    reg         we_b;

    boreal_memory #(10, 32) mem (
        .clk(clk),
        .addr_a(addr_a),
        .dout_a(mem_dout),
        .we_b(we_b),
        .addr_b(addr_b),
        .din_b(din_b),
        .dout_b()
    );

    // Addressing: Channel-segmented weight storage
    wire [9:0] w_base = {ch, 7'b0};
    always @(*) addr_a = w_base;

    wire signed [15:0] weight = mem_dout[15:0];
    wire signed [15:0] act    = mem_dout[15:0];   // Placeholder for activation LUT if needed
    wire signed [15:0] deriv  = mem_dout[31:16]; // Placeholder for derivative LUT if needed

    // ---------- State ----------
    reg signed [15:0] mu [0:7];
    reg signed [15:0] eps [0:7];

    // ---------- Learning Parameters ----------
    wire [2:0] lr_shift = phase_lock ? 3'd5 : 3'd7;
    localparam [2:0] decay_shift = 3'd4;

    // ---------- Saturation Utility ----------
    function signed [15:0] sat16;
        input signed [31:0] x;
        begin
            if (x > 32767) sat16 = 32767;
            else if (x < -32768) sat16 = -32768;
            else sat16 = x[15:0];
        end
    endfunction

    // ---------- Confidence Estimation ----------
    reg [31:0] pwr;
    always @(posedge clk) begin
        if (adc_valid)
            pwr <= pwr - (pwr >> 4) + ((samp * samp) >> 4);
    end
    assign low_conf = (pwr > 32'd200000000); // Noise floor threshold

    // ---------- Adaptive Update Logic ----------
    wire signed [31:0] g_mu = eps[ch] * deriv;
    wire signed [31:0] g_w  = eps[ch] * mu[ch];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i;
            for (i=0; i<8; i=i+1) mu[i] <= 0;
            we_b <= 0;
        end else if (adc_valid && bite_n) begin
            // Prediction Error
            eps[ch] <= samp - act;

            // State Update (Gradient + Decay)
            mu[ch] <= sat16(
                mu[ch] + (g_mu >>> lr_shift) - (mu[ch] >>> decay_shift)
            );

            // Weight Adaptation Writeback
            addr_b <= w_base;
            din_b  <= {mem_dout[31:16], 
                       sat16(weight + (g_w >>> lr_shift))};
            we_b   <= ~low_conf;
        end else begin
            we_b <= 0;
        end
    end

    always @(posedge clk) mu0 <= mu[0];

endmodule
