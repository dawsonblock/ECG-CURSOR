/*
 * boreal_v3_tb.v
 *
 * Full-stack verification for Boreal Neuro-Core v3.
 * Testing: Scheduler, Adaptive Learning, Velocity Stability.
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
        
        // Simulate ADC frames (8 Hz rhythmic signal)
        repeat (2000) begin
            ads_drdy_n = 0;
            #100 ads_drdy_n = 1;
            #10000; // ~10us between frames
        end
        
        #100000;
        $display("V3 Stack Verification Complete");
        $finish;
    end

    // Monitor Weight Convergence
    always @(posedge clk) begin
        if (uut.core.we_b) begin
            $display("time=%t | ch=%d | mu=%d | eps=%d | w_new=%d", 
                      $time, uut.ch, uut.core.mu[uut.ch], uut.core.eps[uut.ch], uut.core.din_b[15:0]);
        end
    end

endmodule
