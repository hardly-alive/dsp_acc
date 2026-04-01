#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vuav_accelerator_top.h"
#include <iostream>
#include <fstream>
#include <vector>
#include <iomanip>

#define MAX_COLS 1280
#define MAX_ROWS 720

vluint64_t main_time = 0;

// Clock generation function
double sc_time_stamp() {
    return main_time;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vuav_accelerator_top* top = new Vuav_accelerator_top;

    // Enable VCD tracing
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("waveform.vcd");

    // File I/O for images
    std::ifstream infile("video_in.hex");
    std::ofstream outfile("video_out.hex");

    if (!infile.is_open()) {
        std::cerr << "Error: Could not open video_in.hex!" << std::endl;
        return -1;
    }

    // Initialize inputs
    top->aclk = 0;
    top->aresetn = 0; // Active-low reset
    top->s_axis_tvalid = 0;
    top->s_axis_tdata = 0;
    top->s_axis_tlast = 0;
    top->s_axis_tuser = 0;
    top->m_axis_tready = 1; // We (the output memory) are always ready

    // 1. Reset Sequence
    std::cout << "[TB] Starting Reset Sequence..." << std::endl;
    for (int i = 0; i < 10; i++) {
        top->aclk = !top->aclk;
        top->eval();
        tfp->dump(main_time++);
    }
    top->aresetn = 1; // Release reset
    std::cout << "[TB] Reset Released. Starting AXI Video Stream." << std::endl;

    // 2. Stream the Image
    std::string line;
    int row = 0;
    int col = 0;
    int pixel_count = 0;
    int hazard_triggered_count = 0;

    while (std::getline(infile, line) && !Verilated::gotFinish()) {
        uint32_t pixel_val = std::stoul(line, nullptr, 16);

        // --- THE AXI BRIDGE LOGIC ---
        top->s_axis_tvalid = 1;
        top->s_axis_tdata = pixel_val;
        
        // Start of Frame (tuser) is 1 ONLY on the very first pixel
        top->s_axis_tuser = (row == 0 && col == 0) ? 1 : 0;
        
        // End of Line (tlast) is 1 ONLY on the last pixel of the row
        top->s_axis_tlast = (col == MAX_COLS - 1) ? 1 : 0;

        // Tick the clock (Rising Edge)
        top->aclk = 1;
        top->eval();
        tfp->dump(main_time++);

        // --- CHECK OUTPUTS ON RISING EDGE ---
        if (top->m_axis_tvalid && top->m_axis_tready) {
            // Write the edge map pixel to our output hex file
            outfile << std::hex << std::setw(2) << std::setfill('0') << (int)top->m_axis_tdata << "\n";
        }

        if (top->hazard_detected) {
            hazard_triggered_count++;
        }

        // Tick the clock (Falling Edge)
        top->aclk = 0;
        top->eval();
        tfp->dump(main_time++);

        // Move coordinate trackers
        col++;
        if (col == MAX_COLS) {
            col = 0;
            row++;
        }
        pixel_count++;
    }

    // 3. Flush the pipeline (Run clock for a few more cycles to let the last pixels exit)
    top->s_axis_tvalid = 0;
    top->s_axis_tlast = 0;
    top->s_axis_tuser = 0;
    for (int i = 0; i < 3000; i++) {
        top->aclk = !top->aclk;
        top->eval();
        
        if (top->aclk && top->m_axis_tvalid) {
             outfile << std::hex << std::setw(2) << std::setfill('0') << (int)top->m_axis_tdata << "\n";
        }
        tfp->dump(main_time++);
    }

    std::cout << "[TB] Stream Complete. Processed " << std::dec << pixel_count << " pixels." << std::endl;
    if (hazard_triggered_count > 0) {
        std::cout << "[TB] HAZARD DETECTED during simulation! Evasive action triggered." << std::endl;
    } else {
        std::cout << "[TB] Flight path clear. No hazards detected." << std::endl;
    }

    // Cleanup
    top->final();
    tfp->close();
    infile.close();
    outfile.close();
    delete top;
    delete tfp;

    return 0;
}