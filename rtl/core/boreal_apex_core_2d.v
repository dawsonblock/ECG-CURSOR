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

    parameter signed ALPHA = 16'sd3;

    always @(posedge clk) begin
        if (rst || emergency_halt) begin
            mu_x <= 0;
            mu_y <= 0;
        end else if (valid) begin
            mu_x <= mu_x + ((x_in - (mu_x >>> 2)) * ALPHA >>> 4);
            mu_y <= mu_y + ((y_in - (mu_y >>> 2)) * ALPHA >>> 4);
        end
    end

endmodule
