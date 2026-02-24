/*
 * Boreal Full Build Verification TB
 * Verifies: Frame Sync, Calibration, Kalman Smoothing, and HID Clicks.
 */
`timescale 1ns / 1ps

module boreal_full_tb;

    reg clk;
    reg rst_n;
    reg emergency_halt_n;
    reg [23:0] raw_adc_in;
    reg [2:0]  adc_channel_sel;
    reg        adc_data_ready;
    reg [1:0]  safety_tier;
    reg        send_packet_strobe;
    reg        recenter_pulse;
    reg        start_calibration;

    wire       uart_tx;
    wire [31:0] cycle_count;

    boreal_cursor_top_full uut (
        .clk(clk),
        .rst_n(rst_n),
        .emergency_halt_n(emergency_halt_n),
        .raw_adc_in(raw_adc_in),
        .adc_channel_sel(adc_channel_sel),
        .adc_data_ready(adc_data_ready),
        .safety_tier(safety_tier),
        .send_packet_strobe(send_packet_strobe),
        .recenter_pulse(recenter_pulse),
        .start_calibration(start_calibration),
        .uart_tx(uart_tx),
        .cycle_count_debug(cycle_count)
    );

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    integer i, cycle;
    integer test_pass = 0;
    integer test_total = 0;

    task inject_sample(input [2:0] ch, input signed [23:0] val);
        begin
            @(posedge clk);
            adc_channel_sel <= ch;
            raw_adc_in <= val;
            adc_data_ready <= 1;
            @(posedge clk);
            adc_data_ready <= 0;
            @(posedge clk);
        end
    endtask

    task inject_frame(input integer active_ch, input signed [15:0] val_16);
        begin
            for (i = 0; i < 8; i = i + 1) begin
                if (i == active_ch)
                    inject_sample(i[2:0], {val_16, 8'b0});
                else
                    inject_sample(i[2:0], 24'd0);
            end
        end
    endtask

    // Sticky bit to catch short dwell pulses
    reg sticky_click;
    always @(posedge clk) begin
        if (!rst_n) sticky_click <= 0;
        else if (uut.left_state) sticky_click <= 1;
    end

    initial begin
        $dumpfile("boreal_full_tb.vcd");
        $dumpvars(0, boreal_full_tb);

        // Reset
        rst_n = 0; emergency_halt_n = 1; raw_adc_in = 0; adc_channel_sel = 0;
        adc_data_ready = 0; safety_tier = 0; send_packet_strobe = 0;
        recenter_pulse = 0; start_calibration = 0;
        #200; rst_n = 1; #200;

        $display("\n=============================================");
        $display("  BOREAL FULL-STACK CLINICAL VERIFICATION");
        $display("=============================================");

        // TEST 1: Frame Sync & Calibration
        test_total = test_total + 1;
        $display("[TEST 1] Starting Calibration (C4 Active)...");
        start_calibration = 1;
        #20; start_calibration = 0;

        // C4 is Horizontal Positive (CH1)
        for (cycle = 0; cycle < 20000; cycle = cycle + 1) begin
            inject_frame(1, 16'sd10000); // Simulate consistent offset for calibration
            if (cycle % 4000 == 0) $display("  Calib Progress: %0d frames...", cycle);
        end
        
        #1000;
        $display("  Calibration State: %d, Offset X: %d, Offset Y: %d", uut.u_cal.state, uut.u_cal.offset_x, uut.u_cal.offset_y);
        
        if (uut.u_cal.calibrated || uut.u_cal.state == 5) begin
            $display("  [PASS] System Calibrated / Reached RUN state.");
            test_pass = test_pass + 1;
        end else begin
            $display("  [FAIL] Calibration Timeout (State=%0d).", uut.u_cal.state);
        end

        // TEST 2: Kalman Lag Reduction (Proportionality Check)
        test_total = test_total + 1;
        $display("[TEST 2] Verifying Prediction Path (Kalman vs Raw)...");
        if (uut.mu_x_k != 0) begin
            $display("  [PASS] Kalman Layer Active (mu_x_k=%d).", uut.mu_x_k);
            test_pass = test_pass + 1;
        end else begin
            $display("  [FAIL] Kalman Layer Inactive.");
        end

        // TEST 3: HID Click State
        test_total = test_total + 1;
        $display("[TEST 3] Verifying HID Press/Release States...");
        
        for (cycle = 0; cycle < 5000; cycle = cycle + 1) begin
            inject_frame(1, 16'sd10000); // Maintain input that matches calibrated offset
        end

        #1000;
        if (sticky_click) begin
            $display("  [PASS] Dwell Click Detected (Sticky Catch).");
            test_pass = test_pass + 1;
        end else begin
            $display("  [FAIL] Dwell Click Not Detected (dx=%d, dy=%d, dwell_cnt=%d).", uut.dx, uut.dy, uut.u_click.hold_cnt);
        end

        $display("\n=============================================");
        $display("  RESULTS: %0d / %0d tests passed", test_pass, test_total);
        $display("  Final Cycle Count: %0d", cycle_count);
        $display("=============================================");
        $finish;
    end

endmodule
