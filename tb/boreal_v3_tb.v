/*
 * boreal_v3_tb.v
 *
 * Full-stack verification for Boreal Neuro-Core v3 Research-Grade Expansion.
 */
`timescale 1ns/1ps

module boreal_v3_tb;

    reg clk, rst_n, bite_n;
    reg ads_drdy_n, ads_miso;
    wire ads_sclk, ads_cs_n, uart_tx, pwm_out, stim_out;

    boreal_neuro_v3_top uut (
        .clk_100m(clk), .rst_n(rst_n), .bite_n(bite_n),
        .ads_drdy_n(ads_drdy_n), .ads_miso(ads_miso),
        .ads_sclk(ads_sclk), .ads_cs_n(ads_cs_n),
        .uart_rx(1'b1), .uart_tx(uart_tx),
        .pwm_out(pwm_out), .stim_out(stim_out)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Simulation Task: Simulate ADC Frame
    task send_adc_frame(input signed [23:0] val);
        integer i;
        begin
            ads_drdy_n = 1;
            #100;
            ads_drdy_n = 0; // Trigger ADC valid
            #10;
        end
    endtask

    initial begin
        $dumpfile("boreal_v3.vcd");
        $dumpvars(0, boreal_v3_tb);

        // Initialize
        clk = 0; rst_n = 0; bite_n = 0;
        ads_drdy_n = 1; ads_miso = 0;

        #100 rst_n = 1; #100;

        $display("V3 Research-Grade Verification Start");

        // 1. Initial Baseline (Normalize)
        $display("Phase 1: Baseline Normalization...");
        repeat (100) begin
            send_adc_frame(24'sd1000 + $random % 100);
            #10000; // wait 10us
        end

        // 2. Active Intent
        $display("Phase 2: Active Intent Detection...");
        bite_n = 1;
        repeat (50) begin
            send_adc_frame(24'sd5000 + $random % 200); // Shift signal for intent
            #10000;
        end

        // 3. Artifact Simulation
        $display("Phase 3: Artifact Injection (Saturation)...");
        send_adc_frame(24'sd9000000); // Saturated signal
        #50000;

        $display("V3 Expansion Verification Complete");
        $finish;
    end

    // Monitor HID reporting frequency
    realtime last_hid;
    always @(posedge uut.host_hid.valid) begin
        if (last_hid != 0) begin
            $display("time=%t | HID Report Detected | Sample Freq: %f Hz", $realtime, 1.0/($realtime-last_hid)*1e9);
        end
        last_hid = $realtime;
    end

endmodule
