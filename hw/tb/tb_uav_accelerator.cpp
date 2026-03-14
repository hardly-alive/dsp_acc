#include <iostream>
#include <fstream>
#include <string>
#include <iomanip> // Required for hex formatting
#include "Vuav_accelerator_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char** argv) {
    // 1. Create a modern VerilatedContext to manage simulation time and state
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    contextp->traceEverOn(true);
    
    // 2. Instantiate the hardware module, passing the context
    Vuav_accelerator_top* top = new Vuav_accelerator_top{contextp};

    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99); // Trace 99 levels of hierarchy
    tfp->open("waveform.vcd");

    // 3. Open input and output files
    std::ifstream video_in("video_in.hex");
    std::ofstream video_out("video_out.hex");

    if (!video_in.is_open()) {
        std::cerr << "Error: Could not open video_in.hex" << std::endl;
        return 1;
    }
    if (!video_out.is_open()) {
        std::cerr << "Error: Could not open video_out.hex" << std::endl;
        return 1;
    }

    // Initialize physical pins
    top->clk = 0;
    top->rst_n = 0;
    top->s_valid = 0;
    top->s_data = 0;

    int input_pixel_count = 0;
    int output_pixel_count = 0;
    std::string hex_line;

    std::cout << "Starting UAV Hardware Simulation with VerilatedContext..." << std::endl;

    // Run until the file is empty or Verilator is forced to stop
    while (!contextp->gotFinish() && !video_in.eof()) {
        
        // Hardware Reset Sequence: Hold reset low for the first 10 time steps
        if (contextp->time() > 10) {
            top->rst_n = 1; 
        }

        // Feed Data to the Pins (Only update inputs when clock is LOW)
        if (top->rst_n == 1 && top->clk == 0) {
            if (std::getline(video_in, hex_line)) {
                top->s_valid = 1;
                top->s_data = std::stoi(hex_line, nullptr, 16);
                input_pixel_count++;
            } else {
                top->s_valid = 0;
            }
        }

        // Toggle Clock HIGH
        top->clk = 1;
        top->eval(); // Evaluate the SystemVerilog logic
        tfp->dump(contextp->time());
        contextp->timeInc(1); // Increment context time

        // Monitor AI Trigger Output
        if (top->hazard_detected == 1 && output_pixel_count < 5) {
            std::cout << "⚠️ [TIME " << contextp->time() << "] HAZARD DETECTED! Evasive action triggered." << std::endl;
        }

        // Write DSP Output to video_out.hex
        if (top->m_dsp_valid == 1) {
            // Write the 8-bit edge map pixel as a 2-character hex string
            video_out << std::setfill('0') << std::setw(2) << std::hex << (int)top->m_dsp_data << "\n";
            output_pixel_count++;
        }
        

        // Toggle Clock LOW
        top->clk = 0;
        top->eval(); 
        tfp->dump(contextp->time());
        contextp->timeInc(1); // Increment context time
    }

    // Print Simulation Stats
    std::cout << "\nSimulation finished." << std::endl;
    std::cout << "Total Time Steps: " << std::dec << contextp->time() << std::endl;
    std::cout << "Pixels Pushed:    " << input_pixel_count << std::endl;
    std::cout << "Edges Captured:   " << output_pixel_count << std::endl;

    // Cleanup
    video_in.close();
    video_out.close();
    tfp->close();
    top->final(); // Execute any SystemVerilog final blocks
    delete top;
    delete contextp;
    delete tfp;
    return 0;
}