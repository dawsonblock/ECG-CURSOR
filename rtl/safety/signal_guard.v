module signal_guard #(
    parameter LIMIT = 30000,
    parameter HOLD  = 1000
)(
    input  wire clk,
    input  wire rst,
    input  wire signed [15:0] signal,
    output reg freeze
);

reg [15:0] timer;

always @(posedge clk) begin
    if (rst) begin
        freeze <= 0;
        timer <= 0;
    end else begin
        if (signal > LIMIT || signal < -LIMIT) begin
            freeze <= 1;
            timer <= HOLD;
        end else if (timer > 0) begin
            timer <= timer - 1;
        end else begin
            freeze <= 0;
        end
    end
end

endmodule
