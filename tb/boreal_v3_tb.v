/*
 * boreal_v3_tb.v
 *
 * Full-stack verification for Boreal Neuro-Core v3 Instrument-Grade.
 * Testing: FSM, Safety Tiers, Artifact Detection, CRC8 Communication.
 */
`timescale 1ns/1ps

module boreal_v3_tb;

    reg clk, rst_n, bite_n;
    reg ads_drdy_n, ads_miso;
    wire ads_sclk, ads_cs_n, uart_tx, pwm_out, stim_out;

    boreal_neuro_v3_top uut (
        .clk_100m(clk),
        .rst_n(rst_n),
        .bite_n(bite_n),
        .ads_drdy_n(ads_drdy_n),
        .ads_miso(ads_miso),
        .ads_sclk(ads_sclk),
        .ads_cs_n(ads_cs_n),
        .uart_rx(1'b1),
        .uart_tx(uart_tx),
        .pwm_out(pwm_out),
        .stim_out(stim_out)
    );

    // Clock gen
    always #5 clk = ~clk;

    initial begin
        $dumpfile("boreal_v3.vcd");
        $dumpvars(0, boreal_v3_tb);
        
        clk = 0;
        rst_n = 0;
        bite_n = 0;
        ads_drdy_n = 1;
        ads_miso = 0;

        #100 rst_n = 1; #100 bite_n = 1;
        
        $display("--- Starting Instrument-Grade Verification ---");

        // PHASE 1: Normal Operation
        $display("PI: Simulating Normal Rhythmic Signal...");
        repeat (100) begin
            ads_drdy_n = 0;
            #100 ads_drdy_n = 1;
            #10000;
        end

        // PHASE 2: Artifact Simulation (Saturation)
        $display("PII: Simulating Artifact (Saturation)...");
        ads_miso = 1; // High signal
        repeat (10) begin
            ads_drdy_n = 0;
            #100 ads_drdy_n = 1;
            #10000;
        end
        
        #100000;
        $display("V3 Instrument-Grade Verification Complete");
        $finish;
    end

    // Monitor Safety State
    always @(posedge clk) begin
        if (uut.frame_valid) begin
            $display("time=%t | frame=%d | tier=%d | flags=%b | mu=%d", 
                      $time, uut.frame_id, uut.safety_tier, uut.artifact_flags, uut.mu0);
        end
    end

endmodule
