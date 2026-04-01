# 🚁 UAV Hardware Vision & AI Accelerator

An ultra-low-latency **Machine Vision + AI Accelerator** built on the **Xilinx Zynq-7000 SoC**, designed to give micro-UAVs *insect-like reflexes*.

This system bypasses traditional CPU bottlenecks by processing **live 720p video directly in FPGA fabric**, enabling **real-time hazard detection and hardware-triggered evasive action**.


## 🧠 System Overview

The accelerator is a **fully pipelined, AXI4-Stream compliant Image Signal Processor (ISP)** combined with a **custom AI MAC array**, written entirely in **SystemVerilog**.

- ⚡ **Throughput:** 1 pixel per clock cycle  
- ⏱️ **Clock Frequency:** 100 MHz  
- 🚫 **CPU Dependency:** None (hardware-level decision making)


## 🏗️ Architecture

                    ┌─────────────────┐
                    │  Camera Module  |
                    └────────┬────────┘
                             │ AXI4-Stream (RGB 24-bit)
                             ▼
        ┌─────────────────────────────────────────────┐
        │  ┌───────────────────────────────────────┐  │
        │  │ Grayscale Converter                   │  │
        │  │ (R>>2 + G>>1 + B>>2)                  │  │
        │  └──────────────┬────────────────────────┘  │
        │                 │                           │
        │                 ▼                           │
        │  ┌───────────────────────────────────────┐  │
        │  │ Gaussian Blur (3×3)                   │  │
        │  │ Line Buffers (BRAM)                   │  │
        │  └──────────────┬────────────────────────┘  │
        │                 │                           │
        │                 ▼                           │
        │  ┌───────────────────────────────────────┐  │
        │  │ Sobel Edge Detector (3×3)             │  │
        │  │ Gradient (Gx, Gy)                     │  │
        │  └──────────────┬────────────────────────┘  │
        │                 │                           │
        │                 ▼                           │
        │  ┌───────────────────────────────────────┐  │
        │  │ AI MAC Array                          │  │
        │  │ (Dot Product w/ BRAM Weights)         │  │
        │  └──────────────┬────────────────────────┘  │
        │                 │                           │
        │                 ▼                           │
        │  ┌───────────────────────────────────────┐  | 
        │  │ Hazard Detection Logic                │  │
        │  └──────────────┬────────────────────────┘  │
        │                 │                           │
        └─────────────────┼───────────────────────────┘
                          │
                          ▼
                ┌────────────────────┐
                │ AXI GPIO Interrupt │
                └─────────┬──────────┘
                          │
                          ▼
                ┌────────────────────┐
                │ Flight Controller  │
                └────────────────────┘

### 📥 Input Interface
- **AXI4-Stream Video Input**
- Connected via **VDMA** to DDR3 memory
- Supports **24-bit RGB video (720p)**

### 🎛️ Processing Pipeline

1. **Grayscale Conversion**
   - Optimized integer approximation:
     `(R >> 2) + (G >> 1) + (B >> 2)`
   - Minimizes DSP usage

2. **Gaussian Blur (3×3)**
   - Spatial filtering using **line buffers (BRAM)**
   - Reduces sensor noise

3. **Sobel Edge Detection (3×3)**
   - Computes gradients (**Gx, Gy**)
   - Extracts structural features

4. **AI MAC Array**
   - Custom **Multiply-Accumulate unit**
   - Performs dot-product with **pre-trained weights (BRAM ROM)**

5. **Hardware Interrupt**
   - 1-bit signal via **AXI GPIO**
   - Direct trigger to ARM processor for **instant evasive maneuver**


## ⚡ Performance & Optimization

| Metric                  | Value        |
|-------------------------|--------------|
| Power Consumption       | **0.125 W** |
| Slice Registers         | 288          |
| Slice LUTs              | 272          |
| DSP48E1 Usage           | Optimized    |
| BRAM Usage              | Fully utilized |
| Timing                  | 100 MHz (positive slack) |

### 🔧 Key Optimizations

- Eliminated **42,000+ flip-flops** caused by async resets  
- Enforced **synchronous design (`always_ff @(posedge clk)`)** - Forced inference into:
  - ✅ **BRAM (line buffers, weights)**
  - ✅ **DSP slices (MAC operations)** Result: **67% power reduction + deterministic latency**


## 🏎️ Benchmark: Hardware vs. CPU

To prove the necessity of this architecture, the exact same AI vision pipeline (Grayscale → Gaussian Blur → Sobel → MAC Array) was benchmarked on a laptop CPU using Python/NumPy, and compared against the Verilator hardware simulation.

| Metric | Software (Laptop CPU) | Hardware (FPGA Fabric) | Improvement |
| :--- | :--- | :--- | :--- |
| **Processing Time** | 62.41 ms | **9.21 ms** | **~6.7x Faster** |

*Note: The hardware processes 1 pixel per clock cycle at 100 MHz. For a 1280x720 frame (921,600 pixels), total hardware pipeline time is strictly bounded to 9.21 ms, allowing the drone to react to hazards instantaneously while leaving the CPU entirely free for flight dynamics.*

### Execution Log (Verilator & CPU Benchmark)
```text
hardlyalive@HAkCbOOk:~/dsp_acc$ make full_flow

--- [3/4] Running Hardware Simulation ---
./obj_dir/Vuav_accelerator_top
[TB] Starting Reset Sequence...
[TB] Reset Released. Starting AXI Video Stream.
>>> [HAZARD] Score: 1249 | Time: 1002326
[TB] Stream Complete. Processed 921600 pixels.
[TB] HAZARD DETECTED during simulation! Evasive action triggered.
------------------------------
```
```text
hardlyalive@HAkCbOOk:~/dsp_acc$ python -u sw/utils/benchmark_cpu.py
--- Starting CPU Benchmark ---
CPU Processing Time: 62.41 ms
Hazard Score: 2170
Hazard Detected: True
------------------------------
```

## 📂 Repository Structure

```text
dsp_acc/
├── hw/
│   ├── constrs/        # XDC timing & pin constraints
│   ├── include/        # SystemVerilog packages
│   ├── src/            # Core RTL (DSP, AI, top)
│   └── tb/             # Verilator testbenches
│
├── ip/                 # Packaged IP (component.xml)
│
├── sw/
│   ├── ai/             # Python model training
│   ├── src/            # Vitis main file
│   └── utils/          # Image ↔ Hex converters
│
├── tcl_scripts/        # Vivado automation
├── Makefile            # Build system
└── .gitignore          # Excludes Vivado artifacts
```


## 🚀 Quick Start

### ⚙️ Prerequisites

- Linux / WSL2 (recommended)
- Verilator
  ```bash
  sudo apt install verilator
  ```
- Python 3 (numpy, OpenCV)
- Vivado 2024.1 (added to PATH)

---

### 1️⃣ Run Full Simulation (No FPGA Required)

```bash
make full_flow
```

- Converts image → hex
- Simulates RTL via Verilator
- Outputs processed edge map

➡️ Output: `dsp_output.jpg`

---

### 2️⃣ Generate Vivado Project

```bash
make vivado
```

✔ Builds complete SoC:

* ARM Cortex-A9
* AXI Interconnect
* VDMA
* Custom accelerator IP

➡️ Output: `UAV_DSP/`

---

### 3️⃣ Launch Vivado GUI

```bash
make gui
```

- Inspect block design 
- Analyze power/timing
- Generate bitstream

---

### 4️⃣ Clean Workspace

```bash
make clean_all
```

Removes:
* Vivado runs
* Simulation artifacts
* Generated binaries


## 🔮 Future Roadmap

### 🧠 CNN Acceleration
* AXI4-Lite weight loading
* Fully unrolled convolution layers

### 📷 Live Camera Input
* MIPI CSI-2 sensor integration
* Real-time onboard processing