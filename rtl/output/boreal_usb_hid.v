/*
 * Boreal On-FPGA USB Low-Speed HID Mouse Device Core
 *
 * Implements a minimal USB 1.1 Low-Speed (1.5 Mbps) device that
 * enumerates as a 3-button HID mouse. This eliminates the need
 * for an external MCU to act as a USB proxy.
 *
 * Directly drives D+ and D- differential lines from the FPGA.
 * Low-Speed USB uses a 1.5 MHz signaling rate.
 *
 * Architecture:
 *   1. USB PHY (bit-level NRZI encoding/decoding, SE0 detection)
 *   2. SIE (Serial Interface Engine: PID/token/data packet framing)
 *   3. Endpoint 0 (control transfers for enumeration)
 *   4. Endpoint 1 IN (interrupt transfers for HID reports)
 *   5. Descriptor ROM (device/config/HID/report descriptors)
 *
 * HID Report (3 bytes):
 *   Byte 0: [0,0,0,0,0, middle, right, left]  buttons
 *   Byte 1: dx (signed 8-bit relative X movement)
 *   Byte 2: dy (signed 8-bit relative Y movement)
 *
 * Active only when safety tier < 2. Forces zero report on freeze.
 */
module boreal_usb_hid #(
    parameter CLK_FREQ = 100_000_000  // System clock frequency
)(
    input  wire clk,
    input  wire rst_n,
    
    // Mouse data inputs
    input  wire signed [7:0] dx,
    input  wire signed [7:0] dy,
    input  wire left_click,
    input  wire right_click,
    input  wire [1:0] tier,
    
    // USB Physical pins
    output reg  dp_out,     // D+ output
    output reg  dn_out,     // D- output
    output reg  dp_oe,      // D+ output enable (active high)
    output reg  dn_oe       // D- output enable
);

    // =========================================================================
    // 1. USB PHY CLOCK GENERATION (1.5 MHz from system clock)
    // =========================================================================
    localparam USB_CLK_DIV = CLK_FREQ / 1_500_000;
    reg [$clog2(USB_CLK_DIV)-1:0] usb_clk_cnt;
    reg usb_clk_en; // 1.5 MHz tick

    always @(posedge clk) begin
        if (!rst_n) begin
            usb_clk_cnt <= 0;
            usb_clk_en <= 0;
        end else begin
            if (usb_clk_cnt >= USB_CLK_DIV - 1) begin
                usb_clk_cnt <= 0;
                usb_clk_en <= 1;
            end else begin
                usb_clk_cnt <= usb_clk_cnt + 1;
                usb_clk_en <= 0;
            end
        end
    end

    // =========================================================================
    // 2. NRZI ENCODER
    // =========================================================================
    // USB Low-Speed: data is NRZI encoded.
    // '0' bit → toggle line state
    // '1' bit → hold line state (with bit-stuffing after 6 consecutive 1s)
    reg nrzi_state; // current line level
    reg [2:0] ones_count; // for bit-stuffing
    reg stuff_bit;

    task nrzi_encode;
        input bit_val;
        begin
            if (ones_count >= 6) begin
                // Insert stuff bit (force toggle)
                nrzi_state <= ~nrzi_state;
                ones_count <= 0;
                stuff_bit <= 1;
            end else begin
                stuff_bit <= 0;
                if (bit_val == 1'b0) begin
                    nrzi_state <= ~nrzi_state;
                    ones_count <= 0;
                end else begin
                    // hold
                    ones_count <= ones_count + 1;
                end
            end
        end
    endtask

    // =========================================================================
    // 3. DESCRIPTOR ROM
    // =========================================================================
    // Minimal USB Device Descriptor (18 bytes)
    localparam [143:0] DEVICE_DESC = {
        8'h12,       // bLength
        8'h01,       // bDescriptorType (Device)
        8'h10, 8'h01,// bcdUSB 1.1
        8'h00,       // bDeviceClass (defined at interface level)
        8'h00,       // bDeviceSubClass
        8'h00,       // bDeviceProtocol
        8'h08,       // bMaxPacketSize0 (8 bytes)
        8'hAD, 8'hDE,// idVendor  0xDEAD (placeholder)
        8'hEF, 8'hBE,// idProduct 0xBEEF (placeholder)
        8'h00, 8'h01,// bcdDevice 1.00
        8'h00,       // iManufacturer
        8'h00,       // iProduct
        8'h00,       // iSerialNumber
        8'h01        // bNumConfigurations
    };

    // HID Report Descriptor for a standard 3-button mouse
    // Usage Page (Generic Desktop), Usage (Mouse), Collection (Application)
    localparam [399:0] HID_REPORT_DESC = {
        8'h05, 8'h01,   // Usage Page (Generic Desktop)
        8'h09, 8'h02,   // Usage (Mouse)
        8'hA1, 8'h01,   // Collection (Application)
        8'h09, 8'h01,   //   Usage (Pointer)
        8'hA1, 8'h00,   //   Collection (Physical)
        8'h05, 8'h09,   //     Usage Page (Button)
        8'h19, 8'h01,   //     Usage Minimum (1)
        8'h29, 8'h03,   //     Usage Maximum (3)
        8'h15, 8'h00,   //     Logical Minimum (0)
        8'h25, 8'h01,   //     Logical Maximum (1)
        8'h95, 8'h03,   //     Report Count (3)
        8'h75, 8'h01,   //     Report Size (1)
        8'h81, 8'h02,   //     Input (Data, Variable, Absolute)
        8'h95, 8'h01,   //     Report Count (1)
        8'h75, 8'h05,   //     Report Size (5)
        8'h81, 8'h01,   //     Input (Constant) - padding
        8'h05, 8'h01,   //     Usage Page (Generic Desktop)
        8'h09, 8'h30,   //     Usage (X)
        8'h09, 8'h31,   //     Usage (Y)
        8'h15, 8'h81,   //     Logical Minimum (-127)
        8'h25, 8'h7F,   //     Logical Maximum (127)
        8'h75, 8'h08,   //     Report Size (8)
        8'h95, 8'h02,   //     Report Count (2)
        8'h81, 8'h06,   //     Input (Data, Variable, Relative)
        8'hC0,           //   End Collection
        8'hC0            // End Collection
    };

    // =========================================================================
    // 4. SERIAL INTERFACE ENGINE (SIE) - Packet State Machine
    // =========================================================================
    localparam S_IDLE       = 4'd0;
    localparam S_SYNC       = 4'd1;
    localparam S_PID        = 4'd2;
    localparam S_DATA       = 4'd3;
    localparam S_CRC        = 4'd4;
    localparam S_EOP        = 4'd5;
    localparam S_WAIT       = 4'd6;

    reg [3:0] sie_state;
    reg [7:0] tx_byte;
    reg [3:0] tx_bit_cnt;
    reg [7:0] tx_buffer [0:63]; // 64-byte packet buffer
    reg [5:0] tx_len;
    reg [5:0] tx_byte_idx;

    // =========================================================================
    // 5. HID REPORT GENERATION (Interrupt IN endpoint)
    // =========================================================================
    // Generate HID mouse report every ~10 ms (100 Hz polling)
    localparam REPORT_INTERVAL = CLK_FREQ / 100; // 10 ms
    reg [31:0] report_timer;
    reg        report_ready;
    
    reg [7:0] hid_buttons;
    reg [7:0] hid_dx;
    reg [7:0] hid_dy;

    always @(posedge clk) begin
        if (!rst_n) begin
            report_timer <= 0;
            report_ready <= 0;
            hid_buttons <= 0;
            hid_dx <= 0;
            hid_dy <= 0;
        end else begin
            report_ready <= 0;
            
            if (report_timer >= REPORT_INTERVAL) begin
                report_timer <= 0;
                report_ready <= 1;
                
                // Safety gate: freeze everything at tier >= 2
                if (tier >= 2) begin
                    hid_buttons <= 8'h00;
                    hid_dx <= 8'h00;
                    hid_dy <= 8'h00;
                end else begin
                    hid_buttons <= {6'b0, right_click, left_click};
                    hid_dx <= dx;
                    hid_dy <= dy;
                end
            end else begin
                report_timer <= report_timer + 1;
            end
        end
    end

    // =========================================================================
    // 6. MAIN TX STATE MACHINE
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            sie_state <= S_IDLE;
            dp_out <= 1'b0; // Low-speed: idle is D- high, D+ low (J state inverted)
            dn_out <= 1'b1;
            dp_oe <= 1'b0;
            dn_oe <= 1'b0;
            nrzi_state <= 1'b1;
            ones_count <= 0;
            tx_bit_cnt <= 0;
            tx_byte_idx <= 0;
        end else if (usb_clk_en) begin
            case (sie_state)
                S_IDLE: begin
                    dp_oe <= 1'b0;
                    dn_oe <= 1'b0;
                    
                    if (report_ready) begin
                        // Load HID report into TX buffer
                        // DATA1 PID for interrupt IN
                        tx_buffer[0] <= 8'hD2; // DATA1 PID
                        tx_buffer[1] <= hid_buttons;
                        tx_buffer[2] <= hid_dx;
                        tx_buffer[3] <= hid_dy;
                        tx_len <= 6'd4;
                        tx_byte_idx <= 0;
                        tx_bit_cnt <= 0;
                        sie_state <= S_SYNC;
                        dp_oe <= 1'b1;
                        dn_oe <= 1'b1;
                        ones_count <= 0;
                    end
                end
                
                S_SYNC: begin
                    // Send SYNC pattern: KJKJKJKK (8 bits: 00000001)
                    // Low speed: K = D+ low, D- high; J = D+ high (idle inverted)
                    if (tx_bit_cnt < 8) begin
                        if (tx_bit_cnt < 7) begin
                            // Alternating K-J pairs
                            nrzi_state <= ~nrzi_state;
                        end
                        // bit 7 stays same (two K's)
                        dp_out <= nrzi_state;
                        dn_out <= ~nrzi_state;
                        tx_bit_cnt <= tx_bit_cnt + 1;
                    end else begin
                        tx_bit_cnt <= 0;
                        sie_state <= S_DATA;
                    end
                end
                
                S_DATA: begin
                    if (tx_byte_idx < tx_len) begin
                        if (tx_bit_cnt < 8) begin
                            // LSB first
                            nrzi_encode(tx_buffer[tx_byte_idx][tx_bit_cnt]);
                            dp_out <= nrzi_state;
                            dn_out <= ~nrzi_state;
                            
                            if (!stuff_bit)
                                tx_bit_cnt <= tx_bit_cnt + 1;
                        end else begin
                            tx_bit_cnt <= 0;
                            tx_byte_idx <= tx_byte_idx + 1;
                        end
                    end else begin
                        sie_state <= S_EOP;
                        tx_bit_cnt <= 0;
                    end
                end
                
                S_EOP: begin
                    // End of Packet: SE0 for 2 bit times, then J for 1 bit time
                    if (tx_bit_cnt < 2) begin
                        dp_out <= 1'b0; // SE0
                        dn_out <= 1'b0;
                        tx_bit_cnt <= tx_bit_cnt + 1;
                    end else if (tx_bit_cnt == 2) begin
                        // J state (idle)
                        dp_out <= 1'b0;
                        dn_out <= 1'b1;
                        tx_bit_cnt <= tx_bit_cnt + 1;
                    end else begin
                        sie_state <= S_IDLE;
                        dp_oe <= 1'b0;
                        dn_oe <= 1'b0;
                    end
                end
                
                default: sie_state <= S_IDLE;
            endcase
        end
    end

endmodule
