/*
 * RP2040 UART-to-USB-HID Mouse Bridge Firmware (v2.0)
 *
 * Improvements:
 * - Exponential Moving Average (EMA) smoothing for jitter reduction.
 * - Packet Watchdog: Zeros movement if FPGA stops sending data.
 */

#include "hardware/uart.h"
#include "pico/stdlib.h"
#include "tusb.h"
#include <stdint.h>

#define UART_ID uart0
#define BAUD_RATE 115200
#define UART_TX_PIN 0
#define UART_RX_PIN 1
#define PACKET_SIZE 5

uint8_t packet[PACKET_SIZE];
uint8_t idx = 0;
static uint32_t last_packet_time = 0;
static int8_t avg_dx = 0, avg_dy = 0;

void process_packet(uint8_t *p) {
  uint8_t buttons = p[1] & 0x03;
  int8_t raw_dx = (int8_t)p[2];
  int8_t raw_dy = (int8_t)p[3];

  // --- EMA Smoothing ---
  avg_dx = (int8_t)((avg_dx * 3 + raw_dx) / 4);
  avg_dy = (int8_t)((avg_dy * 3 + raw_dy) / 4);

  if (tud_hid_ready()) {
    tud_hid_mouse_report(REPORT_ID_MOUSE, buttons, avg_dx, avg_dy, 0, 0);
  }
}

int main() {
  stdio_init_all();

  uart_init(UART_ID, BAUD_RATE);
  gpio_set_function(UART_TX_PIN, GPIO_FUNC_UART);
  gpio_set_function(UART_RX_PIN, GPIO_FUNC_UART);

  tusb_init();

  while (1) {
    tud_task();

    // --- UART Parsing ---
    while (uart_is_readable(UART_ID)) {
      uint8_t byte = uart_getc(UART_ID);

      if (idx == 0 && byte != 0xAA)
        continue;

      packet[idx++] = byte;

      if (idx == PACKET_SIZE) {
        uint8_t checksum = packet[1] ^ packet[2] ^ packet[3];
        if (checksum == packet[4]) {
          process_packet(packet);
          last_packet_time = to_ms_since_boot(get_absolute_time());
        }
        idx = 0;
      }
    }

    // --- Packet Watchdog ---
    // If no valid packet in 500ms, zero out movement to prevent runaway
    if (to_ms_since_boot(get_absolute_time()) - last_packet_time > 500) {
      if (tud_hid_ready()) {
        tud_hid_mouse_report(REPORT_ID_MOUSE, 0, 0, 0, 0, 0);
      }
    }
  }

  return 0;
}
