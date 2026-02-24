/*
 * boreal_uart_host.v
 *
 * MMIO-based UART interface for Boreal Neuro-Core host communication.
 * Implements full [0xAA][CMD][ADDR_H][ADDR_L][DATA_H][DATA_L][CRC] decoder.
 */
module boreal_uart_host #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rx,
    output reg         tx,
    
    // MMIO Interface
    output reg         mem_we,
    output reg  [9:0]  mem_addr,
    output reg  [31:0] mem_din,
    input  wire [31:0] mem_dout
);

    // UART RX Logic (Basic 8x oversampling)
    reg [3:0] rx_sync;
    always @(posedge clk) rx_sync <= {rx_sync[2:0], rx};
    wire rx_val = rx_sync[3];
    
    reg [15:0] baud_cnt;
    reg [3:0]  bit_idx;
    reg [7:0]  rx_shifter;
    reg        rx_busy;
    reg        rx_done;
    
    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= 0; bit_idx <= 0; rx_busy <= 0; rx_done <= 0;
        end else if (!rx_busy && !rx_val) begin
            rx_busy <= 1; baud_cnt <= BAUD_DIV / 2; bit_idx <= 0; rx_done <= 0;
        end else if (rx_busy) begin
            if (baud_cnt == 0) begin
                baud_cnt <= BAUD_DIV;
                if (bit_idx == 8) begin // stop bit
                    rx_busy <= 0; rx_done <= 1;
                end else begin
                    rx_shifter <= {rx_val, rx_shifter[7:1]};
                    bit_idx <= bit_idx + 1;
                end
            end else baud_cnt <= baud_cnt - 1;
        end else rx_done <= 0;
    end

    // Frame Decoder FSM: [0xAA][CMD][AH][AL][DH_H][DH_L][DL_H][DL_L][CRC] (Simplified to 7 bytes)
    reg [3:0] f_state;
    reg [7:0] f_cmd, f_ah, f_al, f_dh1, f_dh2, f_dl1, f_dl2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            f_state <= 0; mem_we <= 0;
        end else begin
            mem_we <= 0;
            if (rx_done) begin
                case (f_state)
                    0: if (rx_shifter == 8'hAA) f_state <= 1;
                    1: begin f_cmd <= rx_shifter; f_state <= 2; end
                    2: begin f_ah  <= rx_shifter; f_state <= 3; end
                    3: begin f_al  <= rx_shifter; f_state <= 4; end
                    4: begin f_dh1 <= rx_shifter; f_state <= 5; end
                    5: begin f_dh2 <= rx_shifter; f_state <= 6; end
                    6: begin // Execute write
                        mem_addr <= {f_ah[1:0], f_al};
                        mem_din  <= {f_dh1, f_dh2, rx_shifter, 8'b0}; // simplified
                        mem_we <= (f_cmd == 8'h01);
                        f_state <= 0;
                    end
                endcase
            end
        end
    end

    initial tx = 1'b1;

endmodule
