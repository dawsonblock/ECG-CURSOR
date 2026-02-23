# Boreal Neuro-Core — 2D Cursor Control

FPGA-based brain-computer interface cursor control pipeline.  
Converts EEG neural features into USB HID mouse output with < 20ms latency.

## Quick Start

```bash
make test        # Compile + run 9-test verification suite
make test-full   # Compile all 12 modules (link check)
make clean       # Remove build artifacts
```

## Project Structure

```
ECG-CURSOR/
├── Makefile
├── README.md
├── rtl/
│   ├── boreal_cursor_top.v          # Base pipeline integration
│   ├── boreal_cursor_top_full.v     # Full build (all advanced modules)
│   ├── core/
│   │   ├── boreal_apex_core_2d.v    # 2-D Active Inference engine
│   │   └── boreal_feature_extract.v # Multi-channel spatial weighting
│   ├── cursor/
│   │   ├── cursor_smoothing.v       # IIR jitter filter
│   │   ├── cursor_map.v             # Velocity mapper + deadzone
│   │   └── dwell_click.v            # Hold-to-click detector
│   ├── output/
│   │   ├── cursor_uart_tx.v         # UART bridge to MCU
│   │   └── boreal_usb_hid.v        # On-FPGA USB 1.1 mouse
│   └── advanced/
│       ├── cursor_adaptive_gain.v   # Auto-tuning gain
│       └── cursor_recenter.v        # Drift compensation
├── tb/
│   └── boreal_cursor_tb.v           # 9-test synthetic verification
└── docs/
    ├── reference/                   # Legacy design notes
    └── papers/                      # Research PDFs
```

## Pipeline

```
EEG ADC → DC-Block Filter → 2D Active Inference (μx, μy)
    → IIR Smoothing → Drift Recenter → Adaptive Gain
    → Cursor Map (deadzone + clamp) → Dwell Click Detector
    → Safety Gate (tier ≥ 2 = freeze)
    → UART TX (MCU bridge) + On-FPGA USB HID
```

## Modules

| Module | Location | Function |
|--------|----------|----------|
| `boreal_apex_core_2d` | `rtl/core/` | Dual-axis gradient descent on Free Energy manifold |
| `boreal_feature_extract` | `rtl/core/` | 8-channel spatial weight mixer |
| `cursor_smoothing` | `rtl/cursor/` | IIR low-pass (α = 0.2, Q8) |
| `cursor_map` | `rtl/cursor/` | Deadzone + gain × velocity + Vmax clamp |
| `dwell_click` | `rtl/cursor/` | Left click on 400ms idle, right click on spike |
| `cursor_uart_tx` | `rtl/output/` | 3-byte `[buttons, dx, dy]` at 115200 baud |
| `boreal_usb_hid` | `rtl/output/` | Low-Speed USB 1.1 HID mouse (no MCU needed) |
| `cursor_adaptive_gain` | `rtl/advanced/` | Q8.8 gain: ↑ on click success, ↓ on overshoot |
| `cursor_recenter` | `rtl/advanced/` | Idle-detect counter-bias to fight drift |

## Tunable Parameters

| Parameter | Module | Default | Purpose |
|-----------|--------|---------|---------|
| `ALPHA` | `cursor_smoothing` | 51 (Q8) | Smoothing strength (↑ = less smooth) |
| `DEAD` | `cursor_map` | 200 | Deadzone threshold |
| `GAIN` | `cursor_map` | 2 | Velocity multiplier |
| `VMAX` | `cursor_map` | 20 | Max cursor speed (px/tick) |
| `HOLD_CYCLES` | `dwell_click` | 40M | Dwell click duration (~400ms @ 100MHz) |
| `GAIN_MIN/MAX` | `cursor_adaptive_gain` | 64–1024 | Adaptive gain bounds (Q8.8) |
| `IDLE_CYCLES` | `cursor_recenter` | 50M | Idle wait before drift correction |

## Verification

9/9 tests pass with Icarus Verilog:

- ✅ Positive/negative input response
- ✅ Convergence (no saturation at ±32768)
- ✅ Smoothing lag confirmed
- ✅ Cursor velocity output
- ✅ Safety tier freeze
- ✅ Emergency halt
- ✅ UART TX emission
- ✅ Deadzone filtering

## Target Hardware

- **FPGA**: Xilinx Artix-7 (100 MHz)
- **ADC**: ADS1299 (24-bit, 8-channel)
- **USB bridge**: RP2040 / ATmega32u4 (UART path) or direct FPGA D+/D- (USB HID path)

## License

Research use.
