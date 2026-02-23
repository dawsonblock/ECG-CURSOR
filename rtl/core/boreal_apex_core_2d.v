// boreal_apex_core_2d.v
// Real 2D adaptive core (separate X and Y inputs)

module boreal_apex_core_2d(
    input  wire              clk,
    input  wire              rst,
    input  wire              valid,
    input  wire signed [15:0] x_in,
    input  wire signed [15:0] y_in,
    input  wire              emergency_halt,
    output reg  signed [15:0] mu_x,
    output reg  signed [15:0] mu_y
);

    parameter signed ALPHA = 16'sd16; // Higher gain for faster convergence

    reg signed [31:0] mu_x_state;
    reg signed [31:0] mu_y_state;

    always @(posedge clk) begin
        if (rst || emergency_halt) begin
            mu_x_state <= 0;
            mu_y_state <= 0;
            mu_x <= 0;
            mu_y <= 0;
        end else if (valid) begin
            mu_x_state <= mu_x_state + ((x_in - (mu_x_state >>> 8)) * ALPHA >>> 4);
            mu_y_state <= mu_y_state + ((y_in - (mu_y_state >>> 8)) * ALPHA >>> 4);
            
            mu_x <= mu_x_state[23:8];
            mu_y <= mu_y_state[23:8];
        end
    end

endmodule
