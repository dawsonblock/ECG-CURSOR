module adaptive_baseline(
    input  wire clk,
    input  wire rst,
    input  wire valid,
    input  wire signed [15:0] x_in,
    output reg  signed [15:0] centered
);

reg signed [31:0] baseline;

always @(posedge clk) begin
    if (rst) begin
        baseline <= 0;
        centered <= 0;
    end else if (valid) begin
        baseline <= baseline + ((x_in - (baseline >>> 8)) >>> 4);
        centered <= x_in - (baseline >>> 8);
    end
end

endmodule
