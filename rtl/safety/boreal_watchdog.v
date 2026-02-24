/*
 * boreal_watchdog.v
 *
 * Hardware safety watchdog for Boreal Neuro-Core.
 * Monitors the 'valid' pulse frequency. If pulses stop for > TIMEOUT,
 * it raises a HALT flag for the safety controller.
 */
module boreal_watchdog #(
    parameter CLK_FREQ = 50_000_000,
    parameter TIMEOUT_MS = 500
)(
    input  wire clk,
    input  wire rst,
    input  wire heartbeat,
    output reg  stall
);

    localparam LIMIT = (CLK_FREQ / 1000) * TIMEOUT_MS;
    reg [31:0] counter;

    always @(posedge clk) begin
        if (rst || heartbeat) begin
            counter <= 0;
            stall <= 0;
        end else begin
            if (counter < LIMIT) begin
                counter <= counter + 1;
            end else begin
                stall <= 1;
            end
        end
    end

endmodule
