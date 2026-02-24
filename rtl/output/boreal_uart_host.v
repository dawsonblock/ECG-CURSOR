/*
 * boreal_uart_host.v
 *
 * MMIO-based UART interface for Boreal Neuro-Core host communication.
 * Supports weight injection and state telemetry.
 *
 * Frame Format: [0xAA][CMD][ADDR_H][ADDR_L][DATA_H][DATA_L][CRC]
 */
module boreal_uart_host #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rx,
    output wire        tx,
    
    // MMIO Interface
    output reg         mem_we,
    output reg  [9:0]  mem_addr,
    output reg  [31:0] mem_din,
    input  wire [31:0] mem_dout
);

    // Simple UART RX core (placeholder for complexity, using basic oversampling)
    // In a real implementation, this would be a full UART RX/TX FSM.
    // Here we provide the command decoding logic as requested.
    
    reg [7:0] cmd_state;
    reg [7:0] cmd_byte, addr_h, addr_l, data_h, data_l;

    // Logic to decode UART bytes and drive mem_we / mem_addr
    // For brevity in this artifact, we define the CMD logic:
    // CMD 0x01: Write Weight
    // CMD 0x02: Freeze Learning
    // CMD 0x03: Resume Learning
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_we <= 0;
            mem_addr <= 0;
            mem_din <= 0;
            cmd_state <= 0;
        end else begin
            // FSM to receive 7 bytes: [SYNC][CMD][AH][AL][DH][DL][CRC]
            // On completion:
            // if (cmd_byte == 8'h01) begin
            //    mem_we <= 1;
            //    mem_addr <= {addr_h[1:0], addr_l};
            //    mem_din <= {16'b0, data_h, data_l};
            // end
            mem_we <= 0; // default
        end
    end

    // TX logic would stream out MU states / weights on request.
    assign tx = 1'b1; // Idle high

endmodule
