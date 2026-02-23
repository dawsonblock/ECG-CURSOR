# Boreal Neuro-Core — 2D Cursor Control
# Makefile for simulation with Icarus Verilog

IVERILOG := iverilog
VVP      := vvp

# Source file lists
CORE_SRC := rtl/core/boreal_apex_core_2d.v \
            rtl/core/boreal_feature_extract.v

CURSOR_SRC := rtl/cursor/cursor_smoothing.v \
              rtl/cursor/cursor_map.v \
              rtl/cursor/dwell_click.v

OUTPUT_SRC := rtl/output/cursor_uart_tx.v \
              rtl/output/boreal_usb_hid.v

ADVANCED_SRC := rtl/advanced/cursor_adaptive_gain.v \
                rtl/advanced/cursor_recenter.v

# Top-level modules
TOP_BASE := rtl/boreal_cursor_top.v
TOP_FULL := rtl/boreal_cursor_top_full.v

# Base build (core pipeline only)
BASE_SRC := $(CORE_SRC) $(CURSOR_SRC) rtl/output/cursor_uart_tx.v $(TOP_BASE)

# Full build (all modules)
FULL_SRC := $(CORE_SRC) $(CURSOR_SRC) $(OUTPUT_SRC) $(ADVANCED_SRC) $(TOP_FULL)

# Testbench
TB_SRC := tb/boreal_cursor_tb.v

.PHONY: all test test-full clean

all: test

# Compile and run core testbench
test: build/tb
	$(VVP) build/tb

build/tb: $(TB_SRC) $(BASE_SRC) | build
	$(IVERILOG) -o $@ $^

# Compile full build (link check only)
test-full: build/full
	@echo "Full build compiled successfully (all 12 modules linked)."

build/full: $(FULL_SRC) | build
	$(IVERILOG) -o $@ $^

build:
	mkdir -p build

# Clean all build artifacts
clean:
	rm -rf build *.vcd
