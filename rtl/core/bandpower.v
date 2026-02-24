module bandpower(
    input  wire clk,
    input  wire rst,
    input  wire valid,
    input  wire signed [15:0] x_in,
    output reg  signed [15:0] power_out,
    output reg        done
);

reg signed [47:0] acc;
reg [7:0] count;

localparam WINDOW = 64;

always @(posedge clk) begin
    if (rst) begin
        count <= 0;
        acc <= 0;
        done <= 0;
        power_out <= 0;
    end else begin
        done <= 0; // Default

        if (valid) begin
            acc <= acc + x_in * x_in;

            if (count == WINDOW-1) begin
                power_out <= acc[27:12];
                acc <= 0;
                count <= 0;
                done <= 1;
            end else begin
                count <= count + 1;
            end
        end
    end
end

endmodule
