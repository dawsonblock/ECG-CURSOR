/*
 * Boreal Cursor Top — Full Build Integration (Refined 2D)
 *
 * This version implements a true 2D pipeline:
 * 8-channel EEG -> Feature Extract (Spatially Weighted X/Y) -> 2D Apex Core 
 * -> Smoothing -> Drift Recenter -> Adaptive Gain -> Mapper -> Dwell Click
 * -> Latch Buttons -> UART (Robust 0xAA Packet)
 */
module boreal_cursor_top_full (
    input  wire clk,
    input  wire rst_n,
    input  wire emergency_halt_n,
    
    // ADC IN
    input  wire [23:0] raw_adc_in,
    input  wire [2:0]  adc_channel_sel,
    input  wire        adc_data_ready,
    input  wire [1:0]  safety_tier,
    input  wire        send_packet_strobe,
    input  wire        recenter_pulse,

    // UART OUT (Robust 0xAA Format)
    output wire uart_tx,
    
    // USB HID OUT (Note: Placeholder/Transmitter only, see docs)
    output wire usb_dp_out,
    output wire usb_dn_out,
    output wire usb_dp_oe,
    output wire usb_dn_oe
);

    // Internal resets (active high)
    wire rst = !rst_n;
    wire halt = !emergency_halt_n;

    // =========================================================================
    // 1. Feature Extraction (Corrected Accumulator)
    // =========================================================================
    wire signed [15:0] feat_x, feat_y;
    // We use bits [23:8] as the "filtered_sample" for now (placeholder for real bandpower)
    wire signed [15:0] adc_sample_16 = raw_adc_in[23:8];

    boreal_feature_extract u_feat (
        .clk(clk),
        .rst(rst),
        .valid(adc_data_ready),
        .sample_in(adc_sample_16),
        .feature_x(feat_x),
        .feature_y(feat_y)
    );

    // Feature valid pulse (fires every 8 channels)
    // In our feature extractor, feature_x/y update when ch == 7.
    // We can generate a 'feat_valid' pulse by detecting the ch rollover.
    // However, the feature extractor provided doesn't output 'valid'. 
    // Let's assume the core can run on every clk as long as it tracks features.
    // For simplicity, we'll pulse the core when ch == 0 (start of next cycle).
    reg [2:0] last_ch;
    always @(posedge clk) last_ch <= u_feat.ch;
    wire feat_ready = (u_feat.ch == 0 && last_ch == 7);

    // =========================================================================
    // 2. 2-D Active Inference Core (Separate X/Y Inputs)
    // =========================================================================
    wire signed [15:0] mu_x, mu_y;
    
    boreal_apex_core_2d u_core (
        .clk(clk),
        .rst(rst),
        .valid(feat_ready),
        .x_in(feat_x),
        .y_in(feat_y),
        .emergency_halt(halt),
        .mu_x(mu_x),
        .mu_y(mu_y)
    );

    // =========================================================================
    // 3. Smoothing
    // =========================================================================
    wire signed [15:0] mu_x_f, mu_y_f;
    
    cursor_smoothing u_smooth (
        .clk(clk),
        .rst_n(rst_n),
        .mu_x(mu_x),
        .mu_y(mu_y),
        .mu_x_f(mu_x_f),
        .mu_y_f(mu_y_f)
    );

    // =========================================================================
    // 4. Drift Compensation / Recenter
    // =========================================================================
    wire signed [15:0] mu_x_c, mu_y_c;
    wire signed [7:0] dx_raw, dy_raw;
    
    // Pre-gain map for drift detection
    cursor_map #(
        .DEAD(16'sd200),
        .GAIN(16'sd2),
        .VMAX(8'sd20)
    ) u_map_raw (
        .clk(clk),
        .mx(mu_x_f),
        .my(mu_y_f),
        .tier(safety_tier),
        .dx(dx_raw),
        .dy(dy_raw)
    );
    
    cursor_recenter u_recenter (
        .clk(clk),
        .rst_n(rst_n),
        .recenter_pulse(recenter_pulse),
        .dx(dx_raw),
        .dy(dy_raw),
        .mu_x_f(mu_x_f),
        .mu_y_f(mu_y_f),
        .mu_x_corrected(mu_x_c),
        .mu_y_corrected(mu_y_c)
    );

    // =========================================================================
    // 5. Adaptive Gain
    // =========================================================================
    wire signed [15:0] adaptive_gain;
    reg left_click_pulse_r; // pulse from click detector
    
    cursor_adaptive_gain u_gain (
        .clk(clk),
        .rst_n(rst_n),
        .click_success(left_click_pulse_r),
        .dx(dx_raw),
        .dy(dy_raw),
        .gain_out(adaptive_gain)
    );

    // =========================================================================
    // 6. Final Cursor Map
    // =========================================================================
    wire signed [31:0] scaled_x = (mu_x_c * adaptive_gain) >>> 8;
    wire signed [31:0] scaled_y = (mu_y_c * adaptive_gain) >>> 8;
    
    wire signed [15:0] mu_x_final = (scaled_x > 32'sd32767) ? 16'sd32767 :
                                    (scaled_x < -32'sd32768) ? -16'sd32768 :
                                    scaled_x[15:0];
    wire signed [15:0] mu_y_final = (scaled_y > 32'sd32767) ? 16'sd32767 :
                                    (scaled_y < -32'sd32768) ? -16'sd32768 :
                                    scaled_y[15:0];

    wire signed [7:0] dx, dy;
    cursor_map u_map_final (
        .clk(clk),
        .mx(mu_x_final),
        .my(mu_y_final),
        .tier(safety_tier),
        .dx(dx),
        .dy(dy)
    );

    // =========================================================================
    // 7. Click Detection & Latching
    // =========================================================================
    wire l_click_p, r_click_p;
    reg left_btn, right_btn;

    dwell_click u_click (
        .clk(clk),
        .rst(rst),
        .dx(dx),
        .dy(dy),
        .left_click_pulse(l_click_p),
        .right_click_pulse(r_click_p)
    );

    always @(posedge clk) begin
        if (rst) begin
            left_btn  <= 0;
            right_btn <= 0;
            left_click_pulse_r <= 0;
        end else begin
            left_click_pulse_r <= l_click_p;
            if (l_click_p)  left_btn  <= ~left_btn;
            if (r_click_p) right_btn <= ~right_btn;
        end
    end

    // =========================================================================
    // 8. Output Layers
    // =========================================================================
    cursor_uart_tx u_uart (
        .clk(clk),
        .rst(rst),
        .send(send_packet_strobe),
        .buttons({right_btn, left_btn}),
        .dx(dx),
        .dy(dy),
        .tx(uart_tx)
    );

    boreal_usb_hid u_usb (
        .clk(clk),
        .rst_n(rst_n),
        .dx(dx),
        .dy(dy),
        .left_click(left_btn),
        .right_click(right_btn),
        .tier(safety_tier),
        .dp_out(usb_dp_out),
        .dn_out(usb_dn_out),
        .dp_oe(usb_dp_oe),
        .dn_oe(usb_dn_oe)
    );

endmodule
