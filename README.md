# Boreal Neuro-Core | Advanced Adaptive BCI

![RTL Build](https://img.shields.io/badge/EEG--Pipeline-Verified-success.svg)
![Hardware](https://img.shields.io/badge/Medical--Grade-Signal%20Chain-blue.svg)
![Intelligence](https://img.shields.io/badge/Adaptive-LMS%20Learning-purple.svg)
![Safety](https://img.shields.io/badge/Guard-Latching-red.svg)

> **Medical-grade, adaptive EEG-to-Intent processing in pure FPGA RTL.**  
> Featuring Common Spatial Pattern (CSP) filtering, Kalman state estimation, online LMS learning, and symbolic intent extraction.

---

## 🌈 Architecture: The Intelligent Pipeline

```mermaid
graph TD
    A[8-ch EEG In] --> B[Signal Guard]
    B -- Freeze --| Saturation | C[Zero Output]
    
    subgraph Signal Conditioning
        A --> D[Bandpass/Notch Filters]
        D --> E[Adaptive Normalization]
    end
    
    subgraph Intelligence Core
        E --> F[CSP Spatial Filter]
        F --> G[Kalman State Estimator]
        G --> H[LMS Adaptive Decoder]
        H --> I[Symbolic Intent Mapper]
    end
    
    I -.-> |Continuous Intent| J(Status & Safety Gate)
    I -.-> |Discrete States| J
    J --> K[USB HID Engine]
    K --> L[RFSN Decision VM]
```

---

## ⚡ Core Features

### 1. Neuro-Intelligence (RTL)

* **Common Spatial Pattern (CSP)**: Statistically optimized spatial weights to maximize variance between 8-channel EEG motor intent states.
* **Kalman State Estimator**: Fixed-point temporal state model tracking latent intent, eliminating momentary noise spikes.
* **LMS Adaptive Decoder**: Online gradient descent learning continuously adjusts projection weights based on error/reward, personalizing to the user.
* **Symbolic Intent Extraction**: Translates continuous neural coordinates into actionable machine codes (`STATE_IDLE`, `STATE_MOVE_X`, `STATE_MOVE_Y`, `STATE_SELECT`).

### 2. Signal Processing

* **8-Channel IIR Pipeline**: Parallel DC-blocking and noise filtering.
* **Frame Barrier Sync**: Hardware-level mask ensures synchronous updates across the 50MHz master clock domain.
* **Clinical Calibration**: Dynamic baseline variance and mean tracking.

### 3. Safety & Robustness

* **Latching Noise Guard**: Freezes all movement if any electrode saturates.
* **Hardware Watchdog**: Triggers safety halving if ADC frame rates stall.
* **CRC-8 Protection**: Hardened 8-byte HID packets (1kHz synchronous timing).

### 4. Hardware Ready

* **ADS1299 SPI**: Native interface for 24-bit clinical front-ends.
* **USB HID**: 1kHz native reporting to the host PC OS.
* **MMIO Tuning**: All Kalman matrices ($A$, $H$, $K$), LMS learning rates ($\eta$), and Symbolic thresholds are fully accessible over the host memory bus.

---

## 🛠 Verification

Ensure the advanced pipeline is functional via Icarus Verilog:

```bash
make test
```

### Passing Specs

* ✅ **Mathematical Stability**: Fixed-point LMS and Kalman algorithms avoid divergence.
* ✅ **Synchronous Timing**: System passes 50MHz disciplined strict mode.
* ✅ **Safety Latching**: Tier 3 hardware interlock zeroes all intent outputs.

---

## 🛠 Hardware Deployment

The Boreal Neuro-Core is optimized for the **Digilent Arty A7-100T** (Xilinx Artix-7 100T) research platform.

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
