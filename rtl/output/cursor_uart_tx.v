module cursor_uart_tx #(
    parameter CLKS_PER_BIT = 868 // 100MHz / 115200 baud
)(
    input  wire clk,
    input  wire rst_n,
    input  wire send_strobe,
    input  wire right_click,
    input  wire left_click,
    input  wire signed [7:0] dx,
    input  wire signed [7:0] dy,
    output reg  tx
);

    // 3 bytes to send
    wire [7:0] byte0 = {6'b0, right_click, left_click};
    wire [7:0] byte1 = dx;
    wire [7:0] byte2 = dy;

    reg [23:0] shift_reg;
    reg [4:0]  bit_idx;
    reg [1:0]  byte_idx;
    reg [31:0] clk_cnt;
    reg        sending;

    always @(posedge clk) begin
        if (!rst_n) begin
            tx <= 1'b1;
            sending <= 1'b0;
            clk_cnt <= 0;
            bit_idx <= 0;
            byte_idx <= 0;
        end else begin
            if (send_strobe && !sending) begin
                sending <= 1'b1;
                clk_cnt <= 0;
                bit_idx <= 0;
                byte_idx <= 0;
                shift_reg <= {byte2, byte1, byte0};
            end

            if (sending) begin
                if (clk_cnt < CLKS_PER_BIT - 1) begin
                    clk_cnt <= clk_cnt + 1;
                end else begin
                    clk_cnt <= 0;
                    if (bit_idx == 0) begin
                        tx <= 1'b0; // start bit
                        bit_idx <= bit_idx + 1;
                    end else if (bit_idx <= 8) begin
                        tx <= shift_reg[0];
                        shift_reg <= {1'b0, shift_reg[23:1]};
                        bit_idx <= bit_idx + 1;
                    end else begin
                        tx <= 1'b1; // stop bit // Stop bit handling
                        
                        if (byte_idx < 2) begin
                            byte_idx <= byte_idx + 1;
                            bit_idx <= 0;
                        end else begin
                            sending <= 1'b0;
                        end
                    end
                end
            end
        end
    end
endmodule
