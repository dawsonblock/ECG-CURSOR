module dwell_click #(
    parameter HOLD_CYCLES = 40_000_000, // ~400 ms @100 MHz
    parameter SMALL       = 8'sd1,
    parameter SPIKE_VAL   = 8'sd12,     // Higher threshold for right-click spike
    parameter SPIKE_DUR   = 100_000     // Spike must disappear quickly (e.g. 1ms) to not be movement
)(
    input  wire clk,
    input  wire rst_n,
    input  wire signed [7:0] dx,
    input  wire signed [7:0] dy,
    input  wire [1:0] tier,
    output reg  left_click,
    output reg  right_click
);
    reg [31:0] hold_cnt;
    reg [19:0] spike_timer;

    wire small_motion = (dx <= SMALL && dx >= -SMALL && dy <= SMALL && dy >= -SMALL);
    wire is_spike     = (dx > SPIKE_VAL || dy > SPIKE_VAL || dx < -SPIKE_VAL || dy < -SPIKE_VAL);

    always @(posedge clk) begin
        if (!rst_n || tier >= 2) begin
            hold_cnt <= 0; 
            spike_timer <= 0;
            left_click <= 0; 
            right_click <= 0;
        end else begin
            // left click by dwell
            if (small_motion) hold_cnt <= hold_cnt + 1;
            else hold_cnt <= 0;

            left_click <= (hold_cnt >= HOLD_CYCLES);

            // Right click: Trigger on transition to spike then back to small_motion within 1ms
            if (is_spike) begin
                if (spike_timer < SPIKE_DUR) spike_timer <= spike_timer + 1;
            end else if (spike_timer > 0) begin
                right_click <= 1; // Success!
                spike_timer <= 0;
            end else begin
                right_click <= 0;
            end
        end
    end
endmodule
