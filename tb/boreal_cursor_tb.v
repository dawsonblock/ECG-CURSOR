/*
 * Boreal Cursor Control — Advanced EEG Verification TB (Settling Mix)
 */
`timescale 1ns / 1ps

module boreal_cursor_tb;

    reg clk;
    reg rst_n;
    reg emergency_halt_n;
    reg [23:0] raw_adc_in;
    reg [2:0]  adc_channel_sel;
    reg        adc_data_ready;
    reg [1:0]  safety_tier;
    reg        send_packet_strobe;
    wire       uart_tx;

    boreal_cursor_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .emergency_halt_n(emergency_halt_n),
        .raw_adc_in(raw_adc_in),
        .adc_channel_sel(adc_channel_sel),
        .adc_data_ready(adc_data_ready),
        .safety_tier(safety_tier),
        .send_packet_strobe(send_packet_strobe),
        .uart_tx(uart_tx)
    );

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Monitor
    wire signed [15:0] mon_mu_x   = uut.mu_x;
    wire signed [15:0] mon_mu_y   = uut.mu_y;
    wire signed [7:0]  mon_dx     = uut.dx;
    wire signed [7:0]  mon_dx_m   = uut.dx_m;
    wire signed [7:0]  mon_dx_g   = uut.dx_g;
    wire               mon_freeze = uut.noise_freeze;
    wire               mon_left   = uut.left_btn;  

    integer test_pass, test_total;
    integer i, cycle;

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

    // Pulse-based ADC frame
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

    task do_reset;
        begin
            rst_n = 0;
            emergency_halt_n = 1;
            raw_adc_in = 0;
            adc_channel_sel = 0;
            adc_data_ready = 0;
            safety_tier = 0;
            send_packet_strobe = 0;
            #200;
            rst_n = 1;
            #200;
        end
    endtask

    initial begin
        $dumpfile("boreal_cursor_tb.vcd");
        $dumpvars(0, boreal_cursor_tb);

        test_pass  = 0;
        test_total = 0;

        do_reset;

        $display("\n=============================================");
        $display("  BOREAL ADVANCED EEG TESTBENCH (LONG)");
        $display("=============================================");

        // =================================================================
        // TEST 1: Power Integration (Extended 5000 frames for 32-bit state)
        // =================================================================
        test_total = test_total + 1;
        $display("[TEST 1] Ch 0 Active -> Integrating Control Energy...");
        
        for (cycle = 0; cycle < 5000; cycle = cycle + 1) begin
            // Vigorous oscillator (e.g. 10Hz Alpha/Beta burst simulation)
            // Just below the 30000 safety limit to avoid freezing Test 1
            if (cycle % 20 == 0) 
                inject_frame(0, 16'sd24000); 
            else if (cycle % 10 == 0)
                inject_frame(0, -16'sd22000);
            else
                inject_frame(0, 16'sd2000 + (cycle % 1000)); 
            
            if (cycle % 1000 == 0) $display("  Progress: %0d frames...", cycle);
        end
        
        #5000; // Increased delay for EMA smoothing filter to settle
        $display("  Debug: mu_x=%0d, dx_m=%d, dx_g=%d, freeze=%b, dx=%d", mon_mu_x, mon_dx_m, mon_dx_g, mon_freeze, mon_dx);
        $display("  Steady-state mu_x=%0d mu_y=%0d", mon_mu_x, mon_mu_y);
        
        if (mon_mu_x > 100) begin
            $display("  [PASS] Control loop closed on energy features (mu_x=%0d)", mon_mu_x);
            test_pass = test_pass + 1;
        end else begin
            $display("  [FAIL] Insufficient deflection: mu_x=%0d", mon_mu_x);
        end

        // =================================================================
        // TEST 2: Intent Gate (Deadzone)
        // =================================================================
        test_total = test_total + 1;
        $display("[TEST 2] Intent Gate -> Noise filtering check");
        // mu_x should be above DEAD zone (200) to move dx
        if (mon_dx != 0) begin
            $display("  [PASS] Movement verified (dx=%0d)", mon_dx);
            test_pass = test_pass + 1;
        end else begin
            $display("  [FAIL] Zero movement (mu_x=%0d < deadzone?)", mon_mu_x);
        end

        // =================================================================
        // TEST 3: Signal Guard (Saturation Freeze)
        // =================================================================
        test_total = test_total + 1;
        $display("[TEST 3] Signal Guard -> Freeze on Saturation");
        inject_frame(0, 16'sd32767); // Saturation
        #100;
        if (uut.noise_freeze) begin
            $display("  [PASS] Saturation detected, system frozen");
            test_pass = test_pass + 1;
        end else begin
            $display("  [FAIL] No freeze on saturation");
        end

        $display("\n=============================================");
        $display("  RESULTS: %0d / %0d tests passed", test_pass, test_total);
        $display("=============================================");
        $finish;
    end

endmodule
