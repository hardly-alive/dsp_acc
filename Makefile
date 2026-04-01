# ==========================================
# UAV Hardware Accelerator Makefile
# ==========================================

# --- Tools & Variables ---
VERILATOR = verilator
VIVADO    = vivado
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
.PHONY: all prep build run image clean full_flow vivado gui clean_vivado clean_all

# The default target runs the simulation pipeline end-to-end
all: full_flow

# ==========================================
# VERILATOR SIMULATION FLOW
# ==========================================

# 1. Generate the test data using Python
prep:
	@echo "\n--- [1/4] Generating Hex Data ---"
	python3 sw/utils/img2hex.py
	python3 sw/ai/train_model.py

# 2. Compile SystemVerilog to C++ and build the executable
build:
	@echo "\n--- [2/4] Verilating SystemVerilog & Building C++ ---"
	$(VERILATOR) --cc --exe --build --trace -j 4 $(INC_FLAGS) $(PKG_SRC) $(SV_SRCS) $(TB) --top-module $(TOP) -Wno-fatal

# 3. Run the compiled C++ simulation
run: build
	@echo "\n--- [3/4] Running Hardware Simulation ---"
	./obj_dir/V$(TOP)

# 4. Convert the hardware's hex output back to a .jpg
image:
	@echo "\n--- [4/4] Reconstructing Output Image ---"
	python3 sw/utils/hex2img.py
	python3 sw/utils/view_weights.py

# The master sequence
full_flow: prep run image
	@echo "\n✅ PIPELINE COMPLETE! Open 'dsp_output.jpg' to see your hardware's vision."

# Cleanup temporary simulation files
clean:
	@echo "Cleaning simulation workspace..."
	rm -rf obj_dir
	rm -f video_in.hex video_out.hex *.jpg *.vcd


# ==========================================
# VIVADO FPGA FLOW
# ==========================================

# 1. Build the entire Vivado Project from the Tcl script
vivado:
	@echo "\n--- Building Vivado Project ---"
	$(VIVADO) -mode batch -source tcl_scripts/build_project.tcl
	@echo "\n✅ Vivado project 'UAV_DSP' successfully recreated!"

# 2. Open the generated Vivado project in the GUI
gui:
	@echo "\n--- Opening Vivado GUI ---"
	$(VIVADO) UAV_DSP/UAV_DSP.xpr &

# 3. Clean up all Vivado-generated junk
clean_vivado:
	@echo "Cleaning Vivado workspace..."
	rm -rf UAV_DSP .Xil *.jou *.log *.str

# ==========================================
# MASTER CLEAN
# ==========================================
clean_all: clean clean_vivado
	@echo "✅ Repository restored to pristine state!"