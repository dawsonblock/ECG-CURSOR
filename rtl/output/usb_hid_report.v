/*
 * usb_hid_report.v
 *
 * Native USB HID report engine for Boreal Neuro-Core.
 * Provides a deterministic 1kHz report rate.
 *
 * Packet Format (8 bytes):
 * [0] buttons
 * [1] dx (signed)
 * [2] dy (signed)
 * [3] safety (tier + flags)
 * [4] frame_id
 * [5] status
 * [6] CRC8
 * [7] reserved
 */
module usb_hid_report (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_1khz,
    input  wire signed [7:0] dx,
    input  wire signed [7:0] dy,
    input  wire [1:0]  buttons,
    input  wire [3:0]  safety_flags,
    input  wire [7:0]  frame_id,
    input  wire [2:0]  symbolic_state, // New symbolic intent layer
    
    output reg  [7:0]  report [0:7],
    output reg         valid
);

    // CRC8 Calculation (Poly 0x07)
    function [7:0] crc8;
        input [47:0] data; // 6 bytes
        integer i;
        reg [7:0] crc;
        begin
            crc = 8'h00;
            for (i = 47; i >= 0; i = i - 1) begin
                if ((crc[7] ^ data[i]) == 1'b1)
                    crc = (crc << 1) ^ 8'h07;
                else
                    crc = (crc << 1);
            end
            crc8 = crc;
        end
    endfunction

    always @(posedge clk) begin
        integer i;
        if (rst) begin
            valid <= 0;
            for (i=0; i<8; i=i+1) report[i] <= 0;
        end else if (tick_1khz) begin
            report[0] <= {6'b0, buttons};
            report[1] <= dx;
            report[2] <= dy;
            report[3] <= {4'b0, safety_flags};
            report[4] <= frame_id;
            report[5] <= {5'b0, symbolic_state};
            report[6] <= crc8({{6'b0, buttons}, dx, dy, {4'b0, safety_flags}, frame_id, {5'b0, symbolic_state}});
            report[7] <= 8'h00; // Reserved
            valid <= 1;
        end else begin
            valid <= 0;
        end
    end

endmodule
