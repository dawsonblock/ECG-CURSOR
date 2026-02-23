// cursor_uart_tx.v
// Packet: 0xAA, buttons, dx, dy, checksum

module cursor_uart_tx(
    input  wire clk,
    input  wire rst,
    input  wire send,
    input  wire [1:0] buttons,
    input  wire signed [7:0] dx,
    input  wire signed [7:0] dy,
    output reg  tx
);

    parameter CLKS_PER_BIT = 217; // 115200 @ 25MHz (tune as needed)

    reg [7:0] packet [0:4];
    reg [2:0] byte_idx;
    reg [3:0] bit_idx;
    reg [15:0] clk_cnt;
    reg sending;

    always @(posedge clk) begin
        if (rst) begin
            tx <= 1;
            sending <= 0;
        end else if (send && !sending) begin
            packet[0] <= 8'hAA;
            packet[1] <= {6'b0,buttons};
            packet[2] <= dx;
            packet[3] <= dy;
            packet[4] <= packet[1] ^ packet[2] ^ packet[3];

            byte_idx <= 0;
            bit_idx <= 0;
            clk_cnt <= 0;
            sending <= 1;
        end else if (sending) begin
            if (clk_cnt == CLKS_PER_BIT) begin
                clk_cnt <= 0;

                if (bit_idx == 0)
                    tx <= 0;  // start bit
                else if (bit_idx <= 8)
                    tx <= packet[byte_idx][bit_idx-1];
                else
                    tx <= 1;  // stop bit

                bit_idx <= bit_idx + 1;

                if (bit_idx == 9) begin
                    bit_idx <= 0;
                    byte_idx <= byte_idx + 1;
                    if (byte_idx == 4)
                        sending <= 0;
                end
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end
    end

endmodule
