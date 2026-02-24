# Boreal Neuro-Core Makefile
# Usage:
#   make test    - Run Icarus Verilog simulation
#   make lint    - Run Verilator linting
#   make docker  - Build and run in Docker

IVERILOG = iverilog
VVP = vvp
VERILATOR = verilator

RTL_FILES = rtl/core/boreal_memory.v \
            rtl/core/boreal_pll_tracker.v \
            rtl/core/boreal_rr8.v \
            rtl/core/boreal_apex_core_v3.v \
            rtl/core/boreal_biquad.v \
            rtl/core/calibration_controller.v \
            rtl/core/boreal_adaptive_norm.v \
            rtl/core/boreal_envelope_ema.v \
            rtl/core/boreal_spectral_cube.v \
            rtl/core/advanced/boreal_csp_filter.v \
            rtl/core/advanced/boreal_kalman_state.v \
            rtl/core/advanced/boreal_lms_decoder.v \
            rtl/core/advanced/boreal_symbolic_decoder.v \
            rtl/cursor/boreal_velocity_pwm.v \
            rtl/output/boreal_uart_host.v \
            rtl/output/cursor_uart_tx.v \
            rtl/output/usb_hid_report.v \
            rtl/io/ads1299_spi.v \
            rtl/safety/boreal_artifact_monitor.v \
            rtl/safety/boreal_safety_tiers.v \
            rtl/safety/boreal_watchdog.v \
            rtl/top/boreal_neuro_v3_top.v

TB_FILES = tb/boreal_v3_tb.v
BUILD_DIR = build

.PHONY: all test lint clean docker

all: test

test: $(BUILD_DIR)/boreal_v3_instrument
	cd $(BUILD_DIR) && ./boreal_v3_instrument

$(BUILD_DIR)/boreal_v3_instrument: $(RTL_FILES) $(TB_FILES)
	mkdir -p $(BUILD_DIR)
	$(IVERILOG) -g2012 -o $(BUILD_DIR)/boreal_v3_instrument $(RTL_FILES) $(TB_FILES)

lint:
	$(VERILATOR) --lint-only -Irtl/core -Irtl/core/advanced -Irtl/cursor -Irtl/io -Irtl/output -Irtl/safety -Irtl/top rtl/top/boreal_neuro_v3_top.v

docker:
	docker build -t boreal-v3 .
	docker run --rm boreal-v3

clean:
	rm -rf $(BUILD_DIR)
