/*
 * boreal_neuro_v3_top.v
 *
 * Consolidated Top-Level for Boreal Neuro-Core v3.
 * Instrument-Grade refinement with safety tiers and real filters.
 */
module boreal_neuro_v3_top (
    input  wire        clk_100m,
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

    wire [191:0] raw8;
    wire         adc_valid;
    wire [2:0]   ch;
    wire signed [15:0] mu0;
    wire         phase_lock;
    wire         low_conf;
    wire         trigger_peak;
    
    // Safety & Artifacts
    wire [3:0]   artifact_flags;
    wire [1:0]   safety_tier;
    reg  [7:0]   frame_id;
    reg          frame_valid;

    // MMIO bus
    wire [9:0]   m_addr;
    wire [31:0]  m_din;
    wire         m_we;
    wire [31:0]  m_dout;

    // 1. ADC SPI
    ads1299_spi adc (
        .clk(clk_100m), .rst(!rst_n),
        .drdy(ads_drdy_n), .miso(ads_miso),
        .sclk(ads_sclk), .cs(ads_cs_n),
        .sample(raw8[23:0])
    );
    // Mirror Ch0 to all other channels for TB/Verification baseline
    assign raw8[191:24] = {7{raw8[23:0]}};
    assign adc_valid = (ads_drdy_n == 0);

    // 2. Pre-processing: 60Hz Biquad Notch Filter (Coefficients for 250Hz sample rate)
    // b0=0.99, b1=-0.61, b2=0.99, a1=-0.61, a2=0.98
    wire signed [23:0] notch_out;
    boreal_biquad #(
        .B0(16'h7EB8), .B1(16'hB1E0), .B2(16'h7EB8),
        .A1(16'hB1E0), .A2(16'h7D70)
    ) notch_60hz (
        .clk(clk_100m), .rst(!rst_n),
        .valid(adc_valid),
        .x(raw8[23:0]),
        .y(notch_out)
    );

    // 3. Scheduler
    boreal_rr8 sched (
        .clk(clk_100m), .rst_n(rst_n),
        .tick(adc_valid), .ch(ch)
    );

    // 4. Adaptive Neural Core v3
    boreal_apex_core_v3 core (
        .clk(clk_100m), .rst_n(rst_n),
        .bite_n(bite_n && (safety_tier == 0)), 
        .raw8({168'b0, notch_out}), // Drive with notched input
        .adc_valid(adc_valid), .ch(ch),
        .phase_lock(phase_lock), .mu0(mu0), .low_conf(low_conf),
        .reg_addr(m_addr), .reg_din(m_din), .reg_we(m_we), .reg_dout(m_dout)
    );

    // 5. Calibration Controller (Clinical Baseline)
    wire signed [15:0] off_x, off_y;
    wire calibrated;
    calibration_controller u_cal (
        .clk(clk_100m), .rst(!rst_n),
        .start_cal(bite_n), // Start cal on activation
        .valid(frame_valid),
        .feat_x(mu0),
        .feat_y(16'b0),
        .offset_x(off_x), .offset_y(off_y),
        .calibrated(calibrated)
    );

    // 6. Safety Pipeline
    boreal_artifact_monitor art_mon (
        .clk(clk_100m), .rst(!rst_n),
        .valid(adc_valid),
        .x(notch_out),
        .flags(artifact_flags)
    );

    boreal_safety_tiers safety_ctrl (
        .clk(clk_100m), .rst(!rst_n),
        .artifact_flags(artifact_flags),
        .clear_latch(bite_n), 
        .tier(safety_tier)
    );

    // 7. Phase Tracker
    boreal_pll_tracker pll (
        .clk(clk_100m), .rst_n(rst_n),
        .signal_in(mu0), .data_ready(adc_valid),
        .phase_lock(phase_lock), .trigger_peak(trigger_peak)
    );
    assign stim_out = trigger_peak;

    // 8. Velocity & PWM
    boreal_velocity_pwm ctrl (
        .clk(clk_100m), .rst_n(rst_n),
        .enable(bite_n && (safety_tier < 2) && calibrated),
        .mu(mu0 - off_x), // Subtract clinical baseline
        .pwm(pwm_out)
    );

    // 9. Communication
    always @(posedge clk_100m) begin
        if (!rst_n) begin
            frame_id <= 0;
            frame_valid <= 0;
        end else begin
            frame_valid <= (adc_valid && ch == 7);
            if (adc_valid && ch == 7) frame_id <= frame_id + 1;
        end
    end

    cursor_uart_tx host_tx (
        .clk(clk_100m), .rst(!rst_n),
        .send(frame_valid),
        .buttons({bite_n, calibrated}),
        .dx((mu0 - off_x) >>> 8), 
        .dy(off_y[7:0]),
        .frame_id(frame_id),
        .safety_flags({artifact_flags[3:1], low_conf}),
        .tx(uart_tx),
        .tx_busy()
    );

endmodule
