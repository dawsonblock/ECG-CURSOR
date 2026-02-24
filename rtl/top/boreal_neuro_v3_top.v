/*
 * boreal_neuro_v3_top.v
 *
 * Consolidated Top-Level for Boreal Neuro-Core v3 Research-Grade Expansion.
 * Complete BCI Front-End:
 * [ADC] -> [Notch] -> [Spectral Cube] -> [Adaptive Norm] -> [Spatial Filter] -> [Predictive Cursor] -> [HID]
 */
module boreal_neuro_v3_top (
    input  wire        clk_50m,    // Master 50MHz clock
    input  wire        rst_n,
    input  wire        bite_n,

    input  wire        ads_drdy_n,
    input  wire        ads_miso,
    output wire        ads_sclk,
    output wire        ads_cs_n,

    input  wire        uart_rx,
    output wire        uart_tx,

    output wire        pwm_out,
    output wire        stim_out
);

    // --- Clocking & Timing Discipline ---
    reg [15:0] tick_cnt;
    wire       tick_1khz = (tick_cnt == 50_000 - 1); 
    always @(posedge clk_50m) begin
        if (!rst_n) tick_cnt <= 0;
        else if (tick_1khz) tick_cnt <= 0;
        else tick_cnt <= tick_cnt + 1;
    end

    // --- Signal Chain Wires ---
    wire [191:0] raw8;
    wire         adc_valid;
    wire [2:0]   ch;
    wire signed [15:0] mu0;
    wire         phase_lock;
    wire         low_conf;
    wire         trigger_peak;
    
    wire [3:0]   artifact_flags;
    wire [1:0]   safety_tier;
    reg  [7:0]   frame_id;
    reg          frame_valid;

    // Research-Grade Features
    wire [383:0] spectral_vec;
    wire         spectral_valid;
    wire [127:0] z_features;
    wire         norm_done;
    
    // Feature & Filtering Wires
    wire         csp_valid;
    wire signed [23:0] csp_v0, csp_v1;
    wire         kalman_valid_0, kalman_valid_1;
    wire signed [23:0] kalman_est_0, kalman_est_1;
    wire         lms_valid;
    wire signed [23:0] intent_x, intent_y;
    wire         symbolic_valid;
    wire [2:0]   symbolic_state;

    // MMIO Bus
    wire        mmio_we;
    wire [9:0]  mmio_addr;
    wire [31:0] mmio_din;
    wire [31:0] mmio_dout;

    // Predictive Cursor Parameters (MMIO 0x400x)
    reg [15:0] k1_gain_reg = 16'h4000;
    reg [15:0] k2_gain_reg = 16'h1000;
    reg [7:0]  deadzone_reg = 8'd4;

    // Advanced Intelligence Configs (MMIO 0x401x)
    reg signed [15:0] kalman_A_reg = 16'h7000; // Persistence ~0.87
    reg signed [15:0] kalman_H_reg = 16'h7FFF; // Observation ~1.0
    reg signed [15:0] kalman_K_reg = 16'h2000; // Gain ~0.25
    reg [3:0]  lms_eta_shift_reg = 4'd4;      // Learning rate 2^-4
    reg signed [23:0] sym_thresh_move = 24'd10000;
    reg signed [23:0] sym_thresh_sel = 24'd30000;

    always @(posedge clk_50m) begin
        if (!rst_n) begin
            k1_gain_reg <= 16'h4000;
            k2_gain_reg <= 16'h1000;
            deadzone_reg <= 8'd4;
            kalman_A_reg <= 16'h7000;
            kalman_H_reg <= 16'h7FFF;
            kalman_K_reg <= 16'h2000;
            lms_eta_shift_reg <= 4'd4;
            sym_thresh_move <= 24'd10000;
            sym_thresh_sel <= 24'd30000;
        end else if (mmio_we) begin
            case (mmio_addr)
                10'h00C: k1_gain_reg <= mmio_din[15:0];
                10'h00D: k2_gain_reg <= mmio_din[15:0];
                10'h00E: deadzone_reg <= mmio_din[7:0];
                
                // Advanced Intelligence MMIO
                10'h014: kalman_A_reg <= mmio_din[15:0];
                10'h015: kalman_H_reg <= mmio_din[15:0];
                10'h016: kalman_K_reg <= mmio_din[15:0];
                10'h017: lms_eta_shift_reg <= mmio_din[3:0];
                10'h018: sym_thresh_move <= mmio_din[23:0];
                10'h019: sym_thresh_sel <= mmio_din[23:0];
            endcase
        end
    end

    // 1. ADC SPI
    ads1299_spi adc (
        .clk(clk_50m), .rst(!rst_n),
        .drdy(ads_drdy_n), .miso(ads_miso),
        .sclk(ads_sclk), .cs(ads_cs_n),
        .sample(raw8[23:0])
    );
    assign raw8[191:24] = {7{raw8[23:0]}};
    assign adc_valid = (ads_drdy_n == 0);

    // 2. Pre-processing: Biquad Notch
    wire signed [23:0] notch_out;
    boreal_biquad notch_60hz (
        .clk(clk_50m), .rst(!rst_n),
        .valid(adc_valid),
        .x_in(raw8[23:0]), .y_out(notch_out),
        .reg_we(1'b0)
    );

    // 3. Spectral Feature Cube (16-Band Bank)
    boreal_spectral_cube cube (
        .clk(clk_50m), .rst(!rst_n),
        .valid(adc_valid),
        .x_in(notch_out),
        .spectral_vector(spectral_vec),
        .out_valid(spectral_valid)
    );

    // 4. Adaptive Neural Core (Legacy Tracking)
    boreal_apex_core_v3 core (
        .clk(clk_50m), .rst_n(rst_n),
        .bite_n(bite_n && (safety_tier == 0)), 
        .raw8({168'b0, notch_out}),
        .adc_valid(adc_valid), .ch(ch),
        .mu0(mu0)
    );

    // 5. Adaptive Normalizer (Z-Score)
    boreal_adaptive_norm norm (
        .clk(clk_50m), .rst(!rst_n),
        .valid(frame_valid),
        .features_in({112'b0, mu0}), 
        .lock(bite_n && (safety_tier == 0)),
        .features_out(z_features),
        .done(norm_done)
    );

    // 6. Advanced Intelligence Layer 1: Common Spatial Pattern (CSP) Filter
    boreal_csp_filter csp (
        .clk(clk_50m), .rst(!rst_n),
        .valid(adc_valid), // Operating on raw synchronized data, not legacy z_features for now
        .ch0(raw8[23:8]), .ch1(raw8[47:32]), .ch2(raw8[71:56]), .ch3(raw8[95:80]),
        .ch4(raw8[119:104]), .ch5(raw8[143:128]), .ch6(raw8[167:152]), .ch7(raw8[191:176]),
        .host_we(mmio_we && (mmio_addr[9:4] == 6'h02)), // Write weights via MMIO 0x020+
        .host_addr(mmio_addr[3:0]),
        .host_weight(mmio_din[15:0]),
        .out_valid(csp_valid),
        .csp_v0(csp_v0), .csp_v1(csp_v1)
    );

    // 7. Advanced Intelligence Layer 2: Kalman Latent State Estimator
    boreal_kalman_state kalman_0 (
        .clk(clk_50m), .rst(!rst_n),
        .valid_in(csp_valid), .z_in(csp_v0),
        .A_mat(kalman_A_reg), .H_mat(kalman_H_reg), .K_mat(kalman_K_reg),
        .valid_out(kalman_valid_0), .x_est(kalman_est_0)
    );

    boreal_kalman_state kalman_1 (
        .clk(clk_50m), .rst(!rst_n),
        .valid_in(csp_valid), .z_in(csp_v1),
        .A_mat(kalman_A_reg), .H_mat(kalman_H_reg), .K_mat(kalman_K_reg),
        .valid_out(kalman_valid_1), .x_est(kalman_est_1)
    );

    // 8. Advanced Intelligence Layer 3: LMS Adaptive Decoder
    wire error_trigger = (safety_tier == 3); // Penalty signal if user triggers artifact safety
    boreal_lms_decoder lms (
        .clk(clk_50m), .rst(!rst_n),
        .valid_in(kalman_valid_0 && kalman_valid_1),
        .x_in_0(kalman_est_0), .x_in_1(kalman_est_1),
        .error_valid(error_trigger),
        .error_signal(24'd32000), // Fixed magnitude penalty currently
        .eta_shift(lms_eta_shift_reg),
        .freeze(bite_n == 0),
        .valid_out(lms_valid),
        .y_out(intent_x) // Single axis decoded for now, mirror to Y
    );
    assign intent_y = intent_x;

    // 9. Advanced Intelligence Layer 4: Symbolic Intent Mapper
    boreal_symbolic_decoder sym (
        .clk(clk_50m), .rst(!rst_n),
        .valid_in(lms_valid),
        .intent_x(intent_x), .intent_y(intent_y),
        .thresh_move(sym_thresh_move), .thresh_select(sym_thresh_sel),
        .valid_out(symbolic_valid),
        .state_id(symbolic_state)
    );
    
    wire intent_click = (symbolic_state == 3); // STATE_SELECT

    // 9. Safety & Artifacts
    boreal_artifact_monitor art_mon (
        .clk(clk_50m), .rst(!rst_n),
        .valid(adc_valid), .x(notch_out),
        .flags(artifact_flags)
    );

    boreal_safety_tiers safety_ctrl (
        .clk(clk_50m), .rst(!rst_n),
        .artifact_flags(artifact_flags),
        .clear_latch(bite_n), 
        .tier(safety_tier)
    );

    // 10. Velocity & PWM (Using continuously decoded Intent)
    boreal_velocity_pwm ctrl (
        .clk(clk_50m), .rst_n(rst_n),
        .enable(bite_n && (safety_tier < 2) && (symbolic_state != 0)),
        .mu(intent_x[23:8]), // Drive PWM based on adaptive intent
        .pwm(pwm_out)
    );

    // 11. USB HID Report Engine
    wire [7:0] hid_report [0:7];
    wire       hid_valid;
    usb_hid_report host_hid (
        .clk(clk_50m), .rst(!rst_n),
        .tick_1khz(tick_1khz),
        .dx(intent_x[15:8]), .dy(intent_y[15:8]), // Transmit decoded continuous vectors
        .buttons({bite_n, intent_click}),
        .safety_flags({artifact_flags[3:1], safety_tier[0]}),
        .frame_id(frame_id),
        .symbolic_state(symbolic_state),
        .valid(hid_valid)
    );

    // Synchronization logic
    always @(posedge clk_50m) begin
        if (!rst_n) begin
            frame_id <= 0;
            frame_valid <= 0;
        end else begin
            frame_valid <= (adc_valid && ch == 7);
            if (adc_valid && ch == 7) frame_id <= frame_id + 1;
        end
    end

    // 12. MMIO UART Host
    boreal_uart_host host (
        .clk(clk_50m), .rst_n(rst_n),
        .rx(uart_rx), .tx(uart_tx),
        .mem_we(mmio_we),
        .mem_addr(mmio_addr),
        .mem_din(mmio_din),
        .mem_dout(mmio_dout)
    );

endmodule
