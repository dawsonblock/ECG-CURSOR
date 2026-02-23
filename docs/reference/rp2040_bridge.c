/*
 * RP2040 UART-to-USB-HID Mouse Bridge Firmware
 * 
 * Target: Raspberry Pi Pico or any RP2040 board.
 * Usage: Turns FPGA UART packets into a native USB Mouse.
 * 
 * FPGA Packet Format:
 *   [0xAA] [Buttons] [dx] [dy] [Checksum]
 *   Checksum = Buttons ^ dx ^ dy
 */

#include "pico/stdlib.h"
#include "hardware/uart.h"
#include "tusb.h"

#define UART_ID uart0
#define BAUD_RATE 115200
#define UART_TX_PIN 0
#define UART_RX_PIN 1
#define PACKET_SIZE 5

uint8_t packet[PACKET_SIZE];
uint8_t idx = 0;

void process_packet(uint8_t *p) {
    uint8_t buttons = p[1] & 0x03; // Mask for 2 buttons
    int8_t dx = (int8_t)p[2];
    int8_t dy = (int8_t)p[3];

    // Optional: Clamp velocity to prevent runaway
    // if (dx > 20) dx = 20; if (dx < -20) dx = -20;
    // if (dy > 20) dy = 20; if (dy < -20) dy = -20;

    if (tud_hid_ready()) {
        tud_hid_mouse_report(
            REPORT_ID_MOUSE, // Default ID
            buttons,
            dx,
            dy,
            0, // Wheel
            0  // Pan
        );
    }
}

int main() {
    stdio_init_all();

    // Initialize UART for FPGA communication
    uart_init(UART_ID, BAUD_RATE);
    gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
    gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);

    // Initialize USB stack
    tusb_init();

    while (1) {
        tud_task(); // tinyusb device task

        while (uart_is_readable(UART_ID)) {
            uint8_t byte = uart_getc(UART_ID);

            // Sync on start byte
            if (idx == 0 && byte != 0xAA)
                continue;

            packet[idx++] = byte;

            // Packet complete
            if (idx == PACKET_SIZE) {
                uint8_t checksum = packet[1] ^ packet[2] ^ packet[3];
                if (checksum == packet[4]) {
                    process_packet(packet);
                }
                idx = 0; // Reset for next sync
            }
        }
    }

    return 0;
}
