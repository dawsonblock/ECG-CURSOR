# Boreal Neuro-Core 2D | Advanced EEG Cursor

[![RTL Build](https://img.shields.io/badge/EEG--Pipeline-Verified-success.svg)]()
[![Hardware](https://img.shields.io/badge/Medical--Grade-Signal%20Chain-blue.svg)]()
[![Safety](https://img.shields.io/badge/Guard-Latching-red.svg)]()

> **Medical-grade EEG-to-Cursor processing for the Boreal Neuro-Core.**  
> Featuring parallel signal conditioning, energy-based intent extraction, and safety-critical artifact protection.

---

## 🌈 Architecture: The Medical-Grade Chain

```mermaid
graph TD
    A[8-ch EEG In] --> B[Signal Guard]
    B -- Freeze --| Saturation | C[Zero Velocity]
    
    subgraph Parallel Chains x8
        A --> D[Bandpass Filter]
        D --> E[Bandpower Extract]
        E --> F[Adaptive Baseline]
    end
    
    F --> G_Sync[Frame Sync Barrier]
    G_Sync --> G_Cal[Clinical Calibration]
    G_Cal --> G[Spatial Mixing C3/C4]
    G --> H[2D Active Inference]
    H --> H_Kal[Kalman Smoothing]
    H_Kal --> I[Cursor Mapping]
    I --> J[Intent Gate]
    J --> K[UART Packet Streamer]
    K --> L[RP2040 Bridge]
```

---

## ⚡ Core Features

### 1. Signal Processing (RTL)

* **8-Channel IIR Pipeline**: Parallel bandpass/notch filtering (1-30Hz).
* **Frame Barrier Sync**: Hardware-level mask ensures spatial features are phase-aligned across all 8 processing chains.
* **Energy Extraction**: Square-and-accumulate bandpower for stable intent decoding.
* **Clinical Calibration**: 6-state baseline normalization for user-specific biosignal offsets.
* **Physiological Mapping**: Spatial weights optimized for C3, C4, Cz, and CPz clinical electrode layouts.
* **Kalman Predictive Smoothing**: Single-tap predictive filter (K=0.2) to reduce control lag while maintaining noise rejection.
* **Precision Gating**: Deadzone intent logic to eliminate resting jitter.

### 2. Safety & Robustness

* **Latching Noise Guard**: Freezes all movement if any electrode saturates, with a configurable decay timer.
* **Checksum Verification**: XOR-protected packets ensure data integrity over long UART links.
* **Watchdog Safety**: Host-side bridge zeros movement if signal is lost.

### 3. Hardware Ready

* **ADS1299 SPI**: Native interface for standard biosignal front-ends.
* **UART 115200**: Standard link to all common MCUs.

---

## 🛠 Verification

Ensure the advanced pipeline is functional:

```bash
make test
```

### Passing Specs

* ✅ **Clinical Calibration**: RUN state and offset established for specific users.
* ✅ **Kalman Filter**: Predictive cursor path with minimized group delay.
* ✅ **Physiological Layout**: C3/C4 Horizontal, Cz/CPz Vertical confirmed.
* ✅ **HID Click Logic**: HID-standard press/release states for OS drivers.
* ✅ **Saturation Freeze**: Safety-critical artifact protection.

---

## 🛠 Hardware Deployment

The Boreal 2D Neuro-Core is optimized for the **Digilent Arty A7-100T** (Xilinx Artix-7 100T) research platform.

### Standard Build Stack

1. **FPGA**: Artix-7 100T (100MHz Fabric)
2. **ADC**: ADS1299 (24-bit Clinical Front-End)
3. **Bridge**: RP2040 (USB HID Interpreter)
4. **Safety**: "Bite Switch" N.C. hardware interlock.

### Implementation Guide

For detailed wiring, pin constraints, and Bill of Materials, see:

* [Bill of Materials](docs/hardware/bom.md)
* [Arty A7 XDC Constraints](rtl/constraints/boreal_arty_a7.xdc)
* [RP2040 Bridge Firmware](docs/reference/rp2040_bridge.c)

---

**Author**: Dawson Block & Antigravity (Advanced Agentic Architecture)
