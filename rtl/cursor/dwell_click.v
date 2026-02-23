// dwell_click.v
// Generates ONE-CYCLE pulses for left/right click

module dwell_click(
    input  wire clk,
    input  wire rst,
    input  wire signed [7:0] dx,
    input  wire signed [7:0] dy,
    output reg  left_click_pulse,
    output reg  right_click_pulse
);

    parameter HOLD_CYCLES = 20;
    parameter SPIKE_THR   = 50;

    reg [7:0] hold_cnt;
    reg spike_prev;

    wire stable = (dx == 0 && dy == 0);
    wire spike  = (dx > SPIKE_THR || dx < -SPIKE_THR ||
                   dy > SPIKE_THR || dy < -SPIKE_THR);

    always @(posedge clk) begin
        if (rst) begin
            hold_cnt <= 0;
            left_click_pulse <= 0;
            right_click_pulse <= 0;
            spike_prev <= 0;
        end else begin
            left_click_pulse <= 0;
            right_click_pulse <= 0;

            // dwell → left click pulse
            if (stable) begin
                hold_cnt <= hold_cnt + 1;
                if (hold_cnt == HOLD_CYCLES)
                    left_click_pulse <= 1;
            end else begin
                hold_cnt <= 0;
            end

            // spike release → right click pulse
            if (spike_prev && !spike)
                right_click_pulse <= 1;

            spike_prev <= spike;
        end
    end

endmodule
