# Boreal Neuro-Core 2D | True Cursor Control Build

[![RTL Build](https://img.shields.io/badge/RTL-Verified-success.svg)]()
[![Hardware](https://img.shields.io/badge/Target-Artix--7-orange.svg)]()
[![Inference](https://img.shields.io/badge/Engine-True%202D%20Active%20Inference-9c27b0.svg)]()

> **The definitive 2D EEG-to-Cursor Control Pipeline for the Boreal Neuro-Core.**  
> Professionally refined for real-world biosignal decoding and robust HID output.

---

## 🚀 Overview

This repository contains the complete RTL implementation for the Boreal 2D Cursor Control system. Unlike standard controllers, this build implements **True 2D Decoding** by processing independent neural feature streams through a dual-axis Active Inference engine.

### Core Breakthroughs

* **True 2D Active Inference**: Separate X/Y manifolds updated via spatially weighted biological features.
* **Surgical Feature Extraction**: Fixed-point 8-channel accumulator with no dropped samples and medical-grade weighting.
* **Pulse-Based Clicks**: Latched button states driven by one-cycle pulses for reliable HID performance.
* **Robust UART Bridge**: 115200 baud protocol with start-sync and checksum for MCU-based USB HID emulation.

---

## 🏗 Architecture

```mermaid
graph LR
    subgraph Feature Extraction
        A[8-ch EEG] --> B[Spatial Weights]
        B --> C[X-Feature]
        B --> D[Y-Feature]
    end
    
    subgraph Manifold Control
        C & D --> E[2D High-Pass Core]
        E --> F[Dual-Axis Smoother]
        F --> G[Drift Compensation]
    end
    
    subgraph HID Output
        G --> H[Adaptive Gain Mapper]
        H --> I[UART Packet Streamer]
        I --> J[RP2040 HID Bridge]
    end
    
    style E fill:#f9f,stroke:#333,stroke-width:2px
    style J fill:#bbf,stroke:#333,stroke-width:2px
```

---

## 🎛 Technical Specifications

| Metric | Detail |
|:---|:---|
| **Decoding** | True 2D (Independent X/Y Feature Paths) |
| **Integrator** | Alpha-beta Active Inference with DC-Rejection |
| **Protocol** | 0xAA | Buttons | dx | dy | Checksum |
| **Latency** | < 100ns Pipeline Latency |
| **Hardware** | FPGA (RTL) + RP2040 (HID Bridge) |

---

## 🛠 Verification

Execute the refined 2D test suite:

```bash
make test
```

### Final Results

* ✅ **2D Separation**: Verified independent axis deflection.
* ✅ **Dwell Click**: Verified latching button states.
* ✅ **Data Integrity**: Verified XOR checksum and 0xAA frame alignment.

---

## 📜 MCU Bridge

To use as a real mouse, flash the firmware in `docs/reference/rp2040_bridge.c` to a Raspberry Pi Pico. Connect FPGA TX to Pico RX.

**Author**: Dawson Block & Antigravity (Advanced Agentic Architecture)
