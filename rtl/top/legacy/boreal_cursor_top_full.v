/*
 * Boreal Cursor Top — Full Build Integration (Advanced EEG Version)
 *
 * This version implements a medical-grade processing chain:
 * 1. Signal Guard: Freezes on electrode noise/artifacts.
 * 2. 8-Channel Parallel Chain:
 *    - EEG IIR Filter: Bandpass (1-30Hz) conditioning.
 *    - Bandpower Extraction: Square-and-accumulate energy (64 sample window).
 *    - Adaptive Baseline: Removes slow drift and sensor bias.
 * 3. Serial Feature Extraction: Spatially weighted X/Y intent.
 * 4. 2D Apex Core: Active Inference on energy features.
 * 5. Jitter Intent Gate: Eliminates micro-noise for precise cursor control.
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
    input  wire        start_calibration,

    // UART OUT (Robust 0xAA Format)
    output wire uart_tx,
    output wire [31:0] cycle_count_debug,
    
    // USB HID OUT (Note: Placeholder/Transmitter only)
    output wire usb_dp_out,
    output wire usb_dn_out,
    output wire usb_dp_oe,
    output wire usb_dn_oe
);

    wire rst = !rst_n;
    wire halt = !emergency_halt_n;

    // =========================================================================
    // 0. Signal Guard (Artifact detection)
    // =========================================================================
    wire noise_freeze;
    signal_guard u_guard (
        .clk(clk),
        .rst(rst),
        .signal(raw_adc_in[23:8]),
        .freeze(noise_freeze)
    );

    // =========================================================================
    // 1. 8-Channel Processing Chains
    // =========================================================================
    wire signed [15:0] chan_feature [0:7];
    wire [7:0] chan_done_all;

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_chains
            wire signed [15:0] filtered, powered, centered;
            wire i_ready;
            
            // Only pulse the chain for the selected channel
            wire v = adc_data_ready && (adc_channel_sel == i);

            eeg_iir_filter u_iir (
                .clk(clk),
                .rst(rst),
                .valid(v),
                .x_in(raw_adc_in[23:8]),
                .y_out(filtered)
            );

            bandpower u_pow (
                .clk(clk),
                .rst(rst),
                .valid(v),
                .x_in(filtered),
                .power_out(powered),
                .done(i_ready)
            );

            adaptive_baseline u_base (
                .clk(clk),
                .rst(rst),
                .valid(i_ready),
                .x_in(powered),
                .centered(centered)
            );

            assign chan_feature[i] = centered;
            assign chan_done_all[i] = i_ready;
        end
    endgenerate

    // Frame Sync Barrier
    wire frame_ready;
    channel_frame_sync u_sync (.clk(clk), .rst(rst), .chan_done(chan_done_all), .frame_ready(frame_ready));

    // =========================================================================
    // 2. Serial Feature Extraction Burst
    // =========================================================================
    reg [2:0] burst_cnt;
    reg       bursting;
    wire      burst_trigger = frame_ready; // Chains are in-sync

    always @(posedge clk) begin
        if (rst) begin
            burst_cnt <= 0;
            bursting <= 0;
        end else if (burst_trigger) begin
            bursting <= 1;
            burst_cnt <= 0;
        end else if (bursting) begin
            if (burst_cnt == 7) bursting <= 0;
            else burst_cnt <= burst_cnt + 1;
        end
    end

    wire signed [15:0] feat_x_raw, feat_y_raw;
    boreal_feature_extract u_feat (
        .clk(clk),
        .rst(rst),
        .valid(bursting),
        .sample_in(chan_feature[burst_cnt]),
        .feature_x(feat_x_raw),
        .feature_y(feat_y_raw)
    );

    // 2a. Calibration Layer
    wire signed [15:0] offset_x, offset_y;
    wire cal_ready;
    calibration_controller u_cal (
        .clk(clk),
        .rst(rst),
        .start_cal(start_calibration),
        .valid(frame_ready),
        .feat_x(feat_x_raw),
        .feat_y(feat_y_raw),
        .offset_x(offset_x),
        .offset_y(offset_y),
        .calibrated(cal_ready)
    );

    wire signed [15:0] feat_x = feat_x_raw - offset_x;
    wire signed [15:0] feat_y = feat_y_raw - offset_y;

    // =========================================================================
    // 3. 2-D Active Inference Core
    // =========================================================================
    wire signed [15:0] mu_x, mu_y;
    // Core updates whenever the feature extractor finishes its 8-sample burst
    reg [2:0] last_burst;
    always @(posedge clk) last_burst <= burst_cnt;
    wire feat_complete = (burst_cnt == 0 && last_burst == 7);

    boreal_apex_core_2d u_core (
        .clk(clk),
        .rst(rst),
        .valid(feat_complete),
        .x_in(feat_x),
        .y_in(feat_y),
        .emergency_halt(halt),
        .mu_x(mu_x),
        .mu_y(mu_y)
    );

    // =========================================================================
    // 4. Smoothing Layer (Kalman Predictive)
    // =========================================================================
    wire signed [15:0] mu_x_k, mu_y_k;
    kalman_smoothing u_kal_x (.clk(clk), .rst(rst), .x_in(mu_x), .x_out(mu_x_k));
    kalman_smoothing u_kal_y (.clk(clk), .rst(rst), .x_in(mu_y), .x_out(mu_y_k));

    wire signed [15:0] mu_x_f, mu_y_f;
    cursor_smoothing u_smooth (.clk(clk), .rst_n(rst_n), .mu_x(mu_x_k), .mu_y(mu_y_k), .mu_x_f(mu_x_f), .mu_y_f(mu_y_f));

    wire signed [15:0] mu_x_c, mu_y_c;
    wire signed [7:0] dx_raw, dy_raw;
    cursor_map #(.DEAD(16'sd200), .GAIN(16'sd2), .VMAX(8'sd20)) u_map_raw (.clk(clk), .rst_n(rst_n), .mx(mu_x_f), .my(mu_y_f), .tier(safety_tier), .dx(dx_raw), .dy(dy_raw));
    
    cursor_recenter u_recenter (
        .clk(clk), .rst_n(rst_n), .recenter_pulse(recenter_pulse), .dx(dx_raw), .dy(dy_raw), 
        .mu_x_f(mu_x_f), .mu_y_f(mu_y_f), .mu_x_corrected(mu_x_c), .mu_y_corrected(mu_y_c)
    );

    // =========================================================================
    // 5. Adaptive Gain & Final Map
    // =========================================================================
    wire signed [15:0] adaptive_gain;
    reg left_click_pulse_r;
    cursor_adaptive_gain u_gain (.clk(clk), .rst_n(rst_n), .click_success(left_click_pulse_r), .dx(dx_raw), .dy(dy_raw), .gain_out(adaptive_gain));

    wire signed [31:0] sx = (mu_x_c * adaptive_gain) >>> 8;
    wire signed [31:0] sy = (mu_y_c * adaptive_gain) >>> 8;
    wire signed [15:0] mxf = (sx > 32'sd32767) ? 16'sd32767 : (sx < -32'sd32768) ? -16'sd32768 : sx[15:0];
    wire signed [15:0] myf = (sy > 32'sd32767) ? 16'sd32767 : (sy < -32'sd32768) ? -16'sd32768 : sy[15:0];

    wire signed [7:0] dx_m, dy_m;
    cursor_map u_map_final (.clk(clk), .rst_n(rst_n), .mx(mxf), .my(myf), .tier(safety_tier), .dx(dx_m), .dy(dy_m));

    // =========================================================================
    // 6. Jitter Suppression (Intent Gate)
    // =========================================================================
    wire signed [7:0] dx_g, dy_g;
    intent_gate u_gate (.clk(clk), .rst(rst), .dx_in(dx_m), .dy_in(dy_m), .dx_out(dx_g), .dy_out(dy_g));

    // Global Safety Mux
    wire signed [7:0] dx = noise_freeze ? 8'sd0 : dx_g;
    wire signed [7:0] dy = noise_freeze ? 8'sd0 : dy_g;

    // =========================================================================
    // 7. Click Detection & Output
    // =========================================================================
    wire left_state, right_state;
    dwell_click u_click (.clk(clk), .rst(rst), .dx(dx), .dy(dy), .left_btn_state(left_state), .right_btn_state(right_state));

    cursor_uart_tx u_uart (.clk(clk), .rst(rst), .send(send_packet_strobe), .buttons({right_state, left_state}), .dx(dx), .dy(dy), .tx(uart_tx));
    boreal_usb_hid u_usb (.clk(clk), .rst_n(rst_n), .dx(dx), .dy(dy), .left_click(left_state), .right_click(right_state), .tier(safety_tier), 
                          .dp_out(usb_dp_out), .dn_out(usb_dn_out), .dp_oe(usb_dp_oe), .dn_oe(usb_dn_oe));

    // Performance Audit: Cycle Counter
    reg [31:0] cycles;
    always @(posedge clk) begin
        if (rst) cycles <= 0;
        else cycles <= cycles + 1;
    end
    assign cycle_count_debug = cycles;

endmodule
