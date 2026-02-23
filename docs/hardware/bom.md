# Boreal 2D Neuro-Core: Bill of Materials (BOM)

This document specifies the "Gold Standard" hardware components for clinical-grade BCI research using the Boreal architecture.

## 1. Core Processing & ADC

| Item | Description | Quantity | Est. Price |
|------|-------------|----------|------------|
| **Digilent Arty A7-100T** | Xilinx Artix-7 FPGA (Primary Logic) | 1 | $249 |
| **TI ADS1299 PDK** | 8-Ch, 24-bit Analog Front-End | 1 | $199 |
| **RPi Pico (RP2040)** | USB HID / UART Bridge | 1 | $4 |

## 2. Neural Interface

| Item | Description | Quantity |
|------|-------------|----------|
| **Ag/AgCl Electrodes** | Passive surface electrodes for Mu/Beta | 16 |
| **Ten20 Conductive Paste** | High-conductivity adhesive gel | 1 |
| **Medical Isolation Hub** | Opto-isolated 5V/USB hub (Safety Critical) | 1 |

## 3. Wiring Specification (PMOD Header)

Connect the Arty A7 PMOD Port JA to the ADS1299 and Port JB to the RP2040.

### PMOD JA (ADS1299 SPI)

- PIN 1: CS (Data Ready)
- PIN 2: MOSI (DIN)
- PIN 3: MISO (DOUT)
- PIN 4: SCLK
- PIN 5-6: GND/VCC (3.3V)

### PMOD JB (RP2040 UART)

- PIN 1: FPGA_TX --> RP2040_RX
- PIN 2: FPGA_RX <-- RP2040_TX
- PIN 3: EMERGENCY_HALT <-- Bite Switch (N.C.)
- PIN 5-6: GND/VCC

## 4. Safety Interlock: The "Bite Switch"

Connect a Normally-Closed (N.C.) micro-switch to PMOD JB PIN 3.

- *Operation*: Clenching the jaw opens the circuit, triggering a non-maskable hardware halt in the FPGA fabric, zeroing all cursor movement.
