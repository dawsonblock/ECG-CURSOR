module bandpower(
    input  wire clk,
    input  wire rst,
    input  wire valid,
    input  wire signed [15:0] x_in,
    output reg  signed [15:0] power_out
);

reg signed [47:0] acc;
reg [7:0] count;

always @(posedge clk) begin
    if (rst) begin
        acc <= 0;
        count <= 0;
        power_out <= 0;
    end else if (valid) begin
        acc <= acc + x_in * x_in;
        count <= count + 1;

        if (count == 64) begin
            power_out <= acc[27:12]; // High-sensitivity slice for neural manifolds
            acc <= 0;
            count <= 0;
        end
    end
end

endmodule
