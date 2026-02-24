/*
 * boreal_neuro_v3_top.v
 *
 * Consolidated Top-Level for Boreal Neuro-Core v3.
 * Unifies sensing, scheduling, adaptive inference, and velocity control.
 */
module boreal_neuro_v3_top (
    input  wire        clk_100m,
    input  wire        rst_n,
    input  wire        bite_n,        // Safety/Activation gate

    // ADS1299 SPI Interface (using bit-bang or hardware SPI)
    input  wire        ads_drdy_n,
    input  wire        ads_miso,
    output wire        ads_sclk,
    output wire        ads_cs_n,

    // UART Host Interface
    input  wire        uart_rx,
    output wire        uart_tx,

    // Outputs
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

    // 1. ADC SPI Controller
    ads1299_spi adc (
        .clk(clk_100m),
        .rst(!rst_n),
        .drdy(ads_drdy_n),
        .miso(ads_miso),
        .sclk(ads_sclk),
        .cs(ads_cs_n),
        .sample(raw8[23:0]) // Simplifying for v3 TB - normally gathers all 8
    );
    assign adc_valid = (ads_drdy_n == 0); // Simplified valid for integration

    // 2. Channel Scheduler
    boreal_rr8 sched (
        .clk(clk_100m),
        .rst_n(rst_n),
        .tick(adc_valid),
        .ch(ch)
    );

    // 3. Adaptive Neural Core v3
    boreal_apex_core_v3 core (
        .clk(clk_100m),
        .rst_n(rst_n),
        .bite_n(bite_n),
        .raw8(raw8),
        .adc_valid(adc_valid),
        .ch(ch),
        .phase_lock(phase_lock),
        .mu0(mu0),
        .low_conf(low_conf)
    );

    // 4. Phase Tracker (PLL)
    boreal_pll_tracker pll (
        .clk(clk_100m),
        .rst_n(rst_n),
        .signal_in(mu0),
        .data_ready(adc_valid),
        .estimated_period(),
        .phase_lock(phase_lock),
        .trigger_peak(trigger_peak),
        .trigger_anti()
    );
    assign stim_out = trigger_peak;

    // 5. Velocity Control & PWM Output
    boreal_velocity_pwm ctrl (
        .clk(clk_100m),
        .rst_n(rst_n),
        .enable(bite_n && !low_conf),
        .mu(mu0),
        .pwm(pwm_out)
    );

    // 6. UART Host MMIO
    boreal_uart_host host (
        .clk(clk_100m),
        .rst_n(rst_n),
        .rx(uart_rx),
        .tx(uart_tx),
        .mem_we(),   // Connect to core memory if needed
        .mem_addr(),
        .mem_din(),
        .mem_dout(32'b0)
    );

endmodule
