/*
 * boreal_rr8.v
 *
 * Deterministic 8-channel round-robin scheduler.
 * Increments channel index on every 'tick' (usually adc_valid).
 */
module boreal_rr8 (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick,
    output reg  [2:0] ch
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch <= 0;
        end else if (tick) begin
            ch <= ch + 1;
        end
    end

endmodule
