/*
 * boreal_velocity_pwm.v
 *
 * Stable 2nd-order (Proportional + Damping) controller for Boreal Neuro-Core.
 * v(t+1) = v + k*mu - damping
 * x(t+1) = x + v
 */
module boreal_velocity_pwm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire signed [15:0] mu,
    output reg         pwm
);

    reg signed [15:0] v;
    reg signed [15:0] x;
    reg [15:0]        acc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v <= 0;
            x <= 0;
        end else if (enable) begin
            // v = v + (mu/8) - (v/16)
            v <= v + (mu >>> 3) - (v >>> 4);
            x <= x + v;
        end
    end

    // Direct Digital Synthesis (DDS) PWM
    always @(posedge clk) begin
        acc <= acc + x;
        pwm <= acc[15];
    end

endmodule
