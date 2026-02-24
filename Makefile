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
            rtl/cursor/boreal_velocity_pwm.v \
            rtl/output/boreal_uart_host.v \
            rtl/output/cursor_uart_tx.v \
            rtl/io/ads1299_spi.v \
            rtl/safety/boreal_artifact_monitor.v \
            rtl/safety/boreal_safety_tiers.v \
            rtl/boreal_neuro_v3_top.v

TB_FILES = tb/boreal_v3_tb.v

.PHONY: all test lint clean docker

all: test

test: boreal_v3_instrument
	$(VVP) boreal_v3_instrument

boreal_v3_instrument: $(RTL_FILES) $(TB_FILES)
	$(IVERILOG) -g2012 -o boreal_v3_instrument $(RTL_FILES) $(TB_FILES)

lint:
	$(VERILATOR) --lint-only -Irtl/core -Irtl/cursor -Irtl/io -Irtl/output -Irtl/safety rtl/boreal_neuro_v3_top.v

docker:
	docker build -t boreal-v3 .
	docker run --rm boreal-v3

clean:
	rm -f boreal_v3_instrument boreal_v3.vcd
