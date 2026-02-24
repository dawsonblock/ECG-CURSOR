// dwell_click.v
// Generates ONE-CYCLE pulses for left/right click

module dwell_click(
    input  wire clk,
    input  wire rst,
    input  wire signed [7:0] dx,
    input  wire signed [7:0] dy,
    output reg  left_btn_state,
    output reg  right_btn_state
);

    parameter HOLD_CYCLES = 20;
    parameter CLICK_DUR   = 5;   // Hold click for 5 frames to ensure host sees it
    parameter SPIKE_THR   = 50;

    reg [7:0] hold_cnt;
    reg [7:0] release_cnt_l;
    reg [7:0] release_cnt_r;
    reg spike_prev;

    wire stable = (dx == 0 && dy == 0);
    wire spike  = (dx > SPIKE_THR || dx < -SPIKE_THR ||
                   dy > SPIKE_THR || dy < -SPIKE_THR);

    always @(posedge clk) begin
        if (rst) begin
            hold_cnt <= 0;
            release_cnt_l <= 0;
            release_cnt_r <= 0;
            left_btn_state <= 0;
            right_btn_state <= 0;
            spike_prev <= 0;
        end else begin
            // 1. Dwell -> Left Click
            if (stable) begin
                if (hold_cnt < HOLD_CYCLES) begin
                    hold_cnt <= hold_cnt + 1;
                end else if (hold_cnt == HOLD_CYCLES) begin
                    left_btn_state <= 1;
                    release_cnt_l <= CLICK_DUR;
                    hold_cnt <= HOLD_CYCLES + 1; // Latch until movement
                end
            end else begin
                hold_cnt <= 0;
            end

            // 2. Spike -> Right Click
            if (spike_prev && !spike) begin
                right_btn_state <= 1;
                release_cnt_r <= CLICK_DUR;
            end

            // 3. Release Timers
            if (release_cnt_l > 0) begin
                release_cnt_l <= release_cnt_l - 1;
                if (release_cnt_l == 1) left_btn_state <= 0;
            end

            if (release_cnt_r > 0) begin
                release_cnt_r <= release_cnt_r - 1;
                if (release_cnt_r == 1) right_btn_state <= 0;
            end

            spike_prev <= spike;
        end
    end

endmodule
