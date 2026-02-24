/*
 * Boreal Cursor Top — Base Pipeline (Advanced EEG Version)
 *
 * Parallel EEG Path -> Serial Feature Extract -> 2D Core -> Smoothing -> Map -> Click -> UART
 */
module boreal_cursor_top (
    input  wire clk,
    input  wire rst_n,
    input  wire emergency_halt_n,
    
    // ADC IN
    input  wire [23:0] raw_adc_in,
    input  wire [2:0]  adc_channel_sel,
    input  wire        adc_data_ready,
    input  wire [1:0]  safety_tier,
    input  wire        send_packet_strobe,

    // UART OUT
    output wire        uart_tx
);

    wire rst = !rst_n;
    wire halt = !emergency_halt_n;

    // 0. Signal Guard
    wire noise_freeze;
    signal_guard u_guard (.clk(clk), .rst(rst), .signal(raw_adc_in[23:8]), .freeze(noise_freeze));

    // 1. 8-Channel Parallel Chains
    wire [127:0] chan_features_flat;
    wire [7:0]   chan_done_all;

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_chains
            wire signed [15:0] filtered, powered, centered;
            wire i_ready;
            wire v = adc_data_ready && (adc_channel_sel == i);

            eeg_iir_filter u_iir (.clk(clk), .rst(rst), .valid(v), .x_in(raw_adc_in[23:8]), .y_out(filtered));
            bandpower u_pow (.clk(clk), .rst(rst), .valid(v), .x_in(filtered), .power_out(powered));
            
            reg powered_r;
            always @(posedge clk) powered_r <= (u_pow.count == 64); 
            assign i_ready = (u_pow.count == 64 && !powered_r);

            adaptive_baseline u_base (.clk(clk), .rst(rst), .valid(i_ready), .x_in(powered), .centered(centered));
            assign chan_features_flat[i*16 +: 16] = centered;
            assign chan_done_all[i] = i_ready;
        end
    endgenerate

    // Frame Sync Barrier
    wire frame_ready;
    channel_frame_sync u_sync (.clk(clk), .rst(rst), .chan_done(chan_done_all), .frame_ready(frame_ready));

    // 2. Serial Feature Burst
    reg [2:0] burst_cnt;
    reg       bursting;
    wire      burst_trigger = frame_ready;

    always @(posedge clk) begin
        if (rst) begin burst_cnt <= 0; bursting <= 0; end
        else if (burst_trigger) begin bursting <= 1; burst_cnt <= 0; end
        else if (bursting) begin
            if (burst_cnt == 7) bursting <= 0;
            else burst_cnt <= burst_cnt + 1;
        end
    end

    wire signed [15:0] mux_feat = chan_features_flat[burst_cnt*16 +: 16];
    wire signed [15:0] feat_x, feat_y;
    boreal_feature_extract u_feat (.clk(clk), .rst(rst), .valid(bursting), .sample_in(mux_feat), .feature_x(feat_x), .feature_y(feat_y));

    // 3. 2D Core
    wire signed [15:0] mu_x, mu_y;
    reg [2:0] last_burst;
    always @(posedge clk) last_burst <= burst_cnt;
    wire feat_complete = (burst_cnt == 0 && last_burst == 7);

    boreal_apex_core_2d u_core (.clk(clk), .rst(rst), .valid(feat_complete), .x_in(feat_x), .y_in(feat_y), .emergency_halt(halt), .mu_x(mu_x), .mu_y(mu_y));

    // 4. Smoothing
    wire signed [15:0] mu_x_f, mu_y_f;
    cursor_smoothing u_smooth (.clk(clk), .rst_n(rst_n), .mu_x(mu_x), .mu_y(mu_y), .mu_x_f(mu_x_f), .mu_y_f(mu_y_f));

    // 5. Map
    wire signed [7:0] dx_m, dy_m;
    cursor_map u_map (.clk(clk), .rst_n(rst_n), .mx(mu_x_f), .my(mu_y_f), .tier(safety_tier), .dx(dx_m), .dy(dy_m));

    // 6. Intent & Safety
    wire signed [7:0] dx_g, dy_g;
    intent_gate u_gate (.clk(clk), .rst(rst), .dx_in(dx_m), .dy_in(dy_m), .dx_out(dx_g), .dy_out(dy_g));
    
    wire signed [7:0] dx = noise_freeze ? 8'sd0 : dx_g;
    wire signed [7:0] dy = noise_freeze ? 8'sd0 : dy_g;

    // 7. Click & UART
    wire left_state, right_state;
    dwell_click u_click (.clk(clk), .rst(rst), .dx(dx), .dy(dy), .left_btn_state(left_state), .right_btn_state(right_state));

    cursor_uart_tx u_uart (.clk(clk), .rst(rst), .send(send_packet_strobe), .buttons({right_state, left_state}), .dx(dx), .dy(dy), .tx(uart_tx));

endmodule
