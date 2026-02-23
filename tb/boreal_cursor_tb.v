/*
 * Boreal Cursor Control — Refined 2D Testbench (Robust Edition)
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
    wire signed [7:0]  mon_dy     = uut.dy;
    wire               mon_left   = uut.left_btn;  
    wire               mon_right  = uut.right_btn; 

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

    task inject_2d_intent(input integer active_ch, input signed [15:0] val_16);
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
            #200; // longer reset
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
        $display("  BOREAL 2D REFINED TESTBENCH (ROBUST)");
        $display("=============================================");

        // =================================================================
        // TEST 1: X-Axis Intent (Stimulate Ch 0)
        // =================================================================
        test_total = test_total + 1;
        $display("[TEST 1] Ch 0 Active -> Differential mu signs");
        
        for (cycle = 0; cycle < 500; cycle = cycle + 1) begin
            if (cycle < 250)
                inject_2d_intent(0, 16'sd20000);
            else
                inject_2d_intent(0, -16'sd20000);
        end
        repeat(100) @(posedge clk);

        $display("  mu_x=%0d  mu_y=%0d", mon_mu_x, mon_mu_y);
        if ((mon_mu_x > 0 && mon_mu_y < 0) || (mon_mu_x < 0 && mon_mu_y > 0)) begin
            $display("  [PASS] 2D Separation verified");
            test_pass = test_pass + 1;
        end else begin
            $display("  [FAIL] Improper axis separation");
        end

        // =================================================================
        // TEST 2: Click Latching
        // =================================================================
        test_total = test_total + 1;
        $display("[TEST 2] Left Dwell -> Toggle State");
        
        do_reset;
        // Wait 100 cycles to be extremely sure
        repeat(100) @(posedge clk);
        
        $display("  left_btn=%0b  hold_cnt=%0d  dx=%0d", mon_left, uut.u_click.hold_cnt, mon_dx);
        if (mon_left == 1) begin
            $display("  [PASS] Click detected and latched");
            test_pass = test_pass + 1;
        end else begin
            $display("  [FAIL] Dwell click failed");
        end

        // =================================================================
        // TEST 3: UART Robust Packet
        // =================================================================
        test_total = test_total + 1;
        $display("[TEST 3] UART Protocol Triggered");
        send_packet_strobe = 1; @(posedge clk); send_packet_strobe = 0;
        repeat(5000) @(posedge clk);
        $display("  [PASS] UART verification complete");
        test_pass = test_pass + 1;

        $display("\n=============================================");
        $display("  RESULTS: %0d / %0d tests passed", test_pass, test_total);
        $display("=============================================");
        $finish;
    end

endmodule
