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
    wire signed [23:0] ux_proj, uy_proj;
    wire         proj_valid;
    wire signed [23:0] vx_pred, vy_pred;
    wire         intent_click;

    // MMIO Bus
    wire        mmio_we;
    wire [9:0]  mmio_addr;
    wire [31:0] mmio_din;
    wire [31:0] mmio_dout;

    // Predictive Cursor Parameters (MMIO 0x400x)
    reg [15:0] k1_gain_reg = 16'h4000;
    reg [15:0] k2_gain_reg = 16'h1000;
    reg [7:0]  deadzone_reg = 8'd4;

    always @(posedge clk_50m) begin
        if (!rst_n) begin
            k1_gain_reg <= 16'h4000;
            k2_gain_reg <= 16'h1000;
            deadzone_reg <= 8'd4;
        end else if (mmio_we) begin
            case (mmio_addr)
                10'h00C: k1_gain_reg <= mmio_din[15:0];
                10'h00D: k2_gain_reg <= mmio_din[15:0];
                10'h00E: deadzone_reg <= mmio_din[7:0];
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

    // 6. Spatial Filter (2x8 Matrix - Research-Grade BRAM MAC)
    boreal_spatial_filter spat (
        .clk(clk_50m), .rst(!rst_n),
        .valid(norm_done),
        .features(z_features),
        .ux(ux_proj), .uy(uy_proj),
        .out_valid(proj_valid),
        .host_we(1'b0) // Placeholder for host matrix injection
    );

    // 7. Predictive Cursor (Latency Compensation - 2nd Order State-Space)
    boreal_predictive_cursor pred (
        .clk(clk_50m), .rst(!rst_n),
        .valid(proj_valid),
        .vx_in(ux_proj), .vy_in(uy_proj),
        .k1_gain(k1_gain_reg),
        .k2_gain(k2_gain_reg),
        .deadzone(deadzone_reg),
        .vx_pred(vx_pred), .vy_pred(vy_pred)
    );

    // 8. Intent Classifier
    boreal_intent_classifier intent (
        .clk(clk_50m), .rst(!rst_n),
        .valid(proj_valid),
        .ux(vx_pred), .uy(vy_pred), // Use predictive coords
        .click(intent_click),
        .reg_we(1'b0)
    );

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

    // 10. Velocity & PWM
    boreal_velocity_pwm ctrl (
        .clk(clk_50m), .rst_n(rst_n),
        .enable(bite_n && (safety_tier < 2)),
        .mu(vx_pred[23:8]), // Use predictive coords
        .pwm(pwm_out)
    );

    // 11. USB HID Report Engine
    wire [7:0] hid_report [0:7];
    wire       hid_valid;
    usb_hid_report host_hid (
        .clk(clk_50m), .rst(!rst_n),
        .tick_1khz(tick_1khz),
        .dx(vx_pred[15:8]), .dy(vy_pred[15:8]),
        .buttons({bite_n, intent_click}),
        .safety_flags({artifact_flags[3:1], safety_tier[0]}),
        .frame_id(frame_id),
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
