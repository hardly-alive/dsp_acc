# ==========================================
# UAV Hardware Accelerator Makefile
# ==========================================

# --- Tools & Variables ---
VERILATOR = verilator
TOP       = uav_accelerator_top
TB        = hw/tb/tb_uav_accelerator.cpp

# --- Source Directories & Files ---
INC_DIR   = hw/include
SRC_DIRS  = hw/src/dsp hw/src/ai hw/src/top

# 1. Explicitly list the package first so it compiles before the modules!
PKG_SRC   = $(INC_DIR)/dsp_pkg.sv
# 2. Automatically find all other .sv files in the source directories
SV_SRCS   = $(foreach dir, $(SRC_DIRS), $(wildcard $(dir)/*.sv))

# Tell Verilator where to look for module includes (-I flags)
INC_FLAGS = -I$(INC_DIR) $(foreach dir, $(SRC_DIRS), -I$(dir))

# --- Rules ---
.PHONY: all prep build run image clean full_flow

# The default target runs the whole pipeline end-to-end
all: full_flow

# 1. Generate the test data using Python
prep:
	@echo "\n--- [1/4] Generating Hex Data ---"
	python3 sw/utils/img2hex.py
	python3 sw/utils/gen_weights.py

# 2. Compile SystemVerilog to C++ and build the executable
build:
	@echo "\n--- [2/4] Verilating SystemVerilog & Building C++ ---"
	$(VERILATOR) --cc --exe --build -j 4 $(INC_FLAGS) $(PKG_SRC) $(SV_SRCS) $(TB) --top-module $(TOP) -Wno-fatal

# 3. Run the compiled C++ simulation
run: build
	@echo "\n--- [3/4] Running Hardware Simulation ---"
	./obj_dir/V$(TOP)

# 4. Convert the hardware's hex output back to a .jpg
image:
	@echo "\n--- [4/4] Reconstructing Output Image ---"
	python3 sw/utils/hex2img.py

# The master sequence
full_flow: prep run image
	@echo "\n✅ PIPELINE COMPLETE! Open 'dsp_output.jpg' to see your hardware's vision."

# Cleanup temporary files and build directories
clean:
	@echo "Cleaning workspace..."
	rm -rf obj_dir
	rm -f video_in.hex video_out.hex weights.hex dsp_output.jpg