module intent_gate(
    input  wire clk,
    input  wire rst,
    input  wire signed [7:0] dx_in,
    input  wire signed [7:0] dy_in,
    output reg  signed [7:0] dx_out,
    output reg  signed [7:0] dy_out
);

parameter THRESH = 3;

always @(posedge clk) begin
    if (rst) begin
        dx_out <= 0;
        dy_out <= 0;
    end else begin
        dx_out <= (dx_in > THRESH || dx_in < -THRESH) ? dx_in : 0;
        dy_out <= (dy_in > THRESH || dy_in < -THRESH) ? dy_in : 0;
    end
end

endmodule
