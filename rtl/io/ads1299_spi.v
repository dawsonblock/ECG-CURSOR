module ads1299_spi(
    input  wire clk,
    input  wire rst,
    input  wire drdy,
    input  wire miso,
    output reg  sclk,
    output reg  cs,
    output reg  signed [23:0] sample
);

reg [7:0] bitcnt;
reg [23:0] shift;

always @(posedge clk) begin
    if (rst) begin
        cs <= 1;
        sclk <= 0;
        bitcnt <= 0;
    end else if (!drdy) begin
        cs <= 0;
        sclk <= ~sclk;

        if (sclk) begin
            shift <= {shift[22:0], miso};
            bitcnt <= bitcnt + 1;

            if (bitcnt == 23) begin
                sample <= shift;
                cs <= 1;
                bitcnt <= 0;
            end
        end
    end
end

endmodule
