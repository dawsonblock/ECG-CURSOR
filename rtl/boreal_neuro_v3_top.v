/*
 * boreal_neuro_v3_top.v
 *
 * Consolidated Top-Level for Boreal Neuro-Core v3.
 * Final refinement with MMIO cross-wiring.
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

    // MMIO bus
    wire [9:0]   m_addr;
    wire [31:0]  m_din;
    wire         m_we;
    wire [31:0]  m_dout;

    ads1299_spi adc (
        .clk(clk_100m), .rst(!rst_n),
        .drdy(ads_drdy_n), .miso(ads_miso),
        .sclk(ads_sclk), .cs(ads_cs_n),
        .sample(raw8[23:0])
    );
    assign adc_valid = (ads_drdy_n == 0);

    boreal_rr8 sched (
        .clk(clk_100m), .rst_n(rst_n),
        .tick(adc_valid), .ch(ch)
    );

    boreal_apex_core_v3 core (
        .clk(clk_100m), .rst_n(rst_n),
        .bite_n(bite_n), .raw8(raw8),
        .adc_valid(adc_valid), .ch(ch),
        .phase_lock(phase_lock), .mu0(mu0), .low_conf(low_conf),
        .reg_addr(m_addr), .reg_din(m_din), .reg_we(m_we), .reg_dout(m_dout)
    );

    boreal_pll_tracker pll (
        .clk(clk_100m), .rst_n(rst_n),
        .signal_in(mu0), .data_ready(adc_valid),
        .phase_lock(phase_lock), .trigger_peak(trigger_peak)
    );
    assign stim_out = trigger_peak;

    boreal_velocity_pwm ctrl (
        .clk(clk_100m), .rst_n(rst_n),
        .enable(bite_n && !low_conf),
        .mu(mu0), .pwm(pwm_out)
    );

    boreal_uart_host host (
        .clk(clk_100m), .rst_n(rst_n),
        .rx(uart_rx), .tx(uart_tx),
        .mem_we(m_we), .mem_addr(m_addr), .mem_din(m_din), .mem_dout(m_dout)
    );

endmodule
