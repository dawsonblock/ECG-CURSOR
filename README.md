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
    
    F --> G[Spatial Mixing]
    G --> H[2D Active Inference]
    H --> I[Smoothing & Map]
    I --> J[Intent Gate]
    J --> K[UART Packet Streamer]
    K --> L[RP2040 Bridge]
```

---

## ⚡ Core Features

### 1. Signal Processing (RTL)

* **8-Channel IIR Pipeline**: Parallel bandpass/notch filtering (1-30Hz).
* **Energy Extraction**: Square-and-accumulate bandpower for stable intent decoding.
* **Drift Rejection**: Dual-stage centering (Baseline Subtraction + High-Pass Core).
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

* ✅ **Energy Decoding**: Integrated control from filtered bandpower.
* ✅ **Intent Deadzone**: Zero-drift at rest.
* ✅ **Saturation Freeze**: Safety-critical artifact protection.

---

**Author**: Dawson Block & Antigravity (Advanced Agentic Architecture)
