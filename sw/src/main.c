#include <stdio.h>
#include "xil_printf.h"
#include "xparameters.h"
#include "xaxivdma.h"
#include "xgpio.h"
#include "xil_cache.h"

// Define 720p Image Dimensions
#define IMAGE_WIDTH  1280
#define IMAGE_HEIGHT 720
#define PIXEL_COUNT  (IMAGE_WIDTH * IMAGE_HEIGHT)

// Define Hardware Base Addresses (From our Vivado Block Design)
#define VDMA_BASEADDR 0x43000000
#define GPIO_BASEADDR 0x41200000

// Define Memory Alignment for DMA (Must be aligned to 32 bytes)
u32 input_image_buffer[PIXEL_COUNT] __attribute__((aligned(32)));
u32 output_edge_buffer[PIXEL_COUNT] __attribute__((aligned(32)));

// Driver Instances
XAxiVdma Vdma;
XGpio    HazardGpio;

void generate_synthetic_image() {
    xil_printf("[CPU] Generating synthetic image in DDR RAM...\r\n");
    for (int y = 0; y < IMAGE_HEIGHT; y++) {
        for (int x = 0; x < IMAGE_WIDTH; x++) {
            int index = (y * IMAGE_WIDTH) + x;
            // Create a sharp "box" in the middle of the screen to trigger strong edges
            if (x > 500 && x < 780 && y > 300 && y < 420) {
                input_image_buffer[index] = 0x00FFFFFF; // White box
            } else {
                input_image_buffer[index] = 0x00000000; // Black background
            }
        }
    }
    // CRITICAL: Flush the CPU cache so the VDMA can actually see the data in DDR!
    Xil_DCacheFlushRange((UINTPTR)input_image_buffer, PIXEL_COUNT * sizeof(u32));
}

int main() {
    int Status;
    xil_printf("\r\n=========================================\r\n");
    xil_printf("  UAV Hardware Accelerator Initializing\r\n");
    xil_printf("=========================================\r\n");

    // 1. Generate Data
    generate_synthetic_image();

    // 2. Initialize GPIO using SDT Config Lookup (Base Address)
    XGpio_Config *GpioCfg = XGpio_LookupConfig(GPIO_BASEADDR);
    Status = XGpio_CfgInitialize(&HazardGpio, GpioCfg, GpioCfg->BaseAddress);
    if (Status != XST_SUCCESS) { xil_printf("GPIO Init Failed!\r\n"); return XST_FAILURE; }
    XGpio_SetDataDirection(&HazardGpio, 1, 0xFFFFFFFF); // Set Channel 1 as Input

    // 3. Initialize VDMA using SDT Config Lookup (Base Address)
    XAxiVdma_Config *VdmaCfg = XAxiVdma_LookupConfig(VDMA_BASEADDR);
    Status = XAxiVdma_CfgInitialize(&Vdma, VdmaCfg, VdmaCfg->BaseAddress);
    if (Status != XST_SUCCESS) { xil_printf("VDMA Init Failed!\r\n"); return XST_FAILURE; }

    // 4. Wrap our buffers in arrays (Because VDMA supports Multi-Frame Buffering)
    UINTPTR ReadAddrs[1]  = { (UINTPTR)input_image_buffer };
    UINTPTR WriteAddrs[1] = { (UINTPTR)output_edge_buffer };

    // 5. Configure VDMA Read (MM2S) - Sending RGB image TO the Accelerator
    XAxiVdma_DmaSetup ReadCfg;
    ReadCfg.VertSizeInput = IMAGE_HEIGHT;
    ReadCfg.HoriSizeInput = IMAGE_WIDTH * 4; // 4 bytes per pixel
    ReadCfg.Stride        = IMAGE_WIDTH * 4;
    ReadCfg.FrameDelay    = 0;
    ReadCfg.EnableCircularBuf = 0;
    ReadCfg.EnableSync    = 0;
    ReadCfg.PointNum      = 0;
    ReadCfg.EnableFrameCounter = 0;
    ReadCfg.FixedFrameStoreAddr = 0;
    Status = XAxiVdma_DmaConfig(&Vdma, XAXIVDMA_READ, &ReadCfg);
    Status = XAxiVdma_DmaSetBufferAddr(&Vdma, XAXIVDMA_READ, ReadAddrs);

    // 6. Configure VDMA Write (S2MM) - Reading Edge Map FROM the Accelerator
    XAxiVdma_DmaSetup WriteCfg;
    WriteCfg.VertSizeInput = IMAGE_HEIGHT;
    WriteCfg.HoriSizeInput = IMAGE_WIDTH * 4; 
    WriteCfg.Stride        = IMAGE_WIDTH * 4;
    WriteCfg.FrameDelay    = 0;
    WriteCfg.EnableCircularBuf = 0;
    WriteCfg.EnableSync    = 0;
    WriteCfg.PointNum      = 0;
    WriteCfg.EnableFrameCounter = 0;
    WriteCfg.FixedFrameStoreAddr = 0;
    Status = XAxiVdma_DmaConfig(&Vdma, XAXIVDMA_WRITE, &WriteCfg);
    Status = XAxiVdma_DmaSetBufferAddr(&Vdma, XAXIVDMA_WRITE, WriteAddrs);

    // 7. Start the Hardware Pipeline!
    xil_printf("[CPU] Yelling 'GO!' to the Hardware Pipeline...\r\n");
    XAxiVdma_DmaStart(&Vdma, XAXIVDMA_WRITE); // Always start S2MM first
    XAxiVdma_DmaStart(&Vdma, XAXIVDMA_READ);

    // 8. The Waiting Game (Hardware Polling)
    xil_printf("[CPU] ARM Processor is now free. Polling for hardware interrupts...\r\n");
    
    u32 hazard_status = 0;
    int timeout = 0;
    
    // Check the hardware pin 10 million times
    while(timeout < 10000000) {
        hazard_status = XGpio_DiscreteRead(&HazardGpio, 1);
        if (hazard_status == 1) {
            xil_printf("\r\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\r\n");
            xil_printf("  SILICON ALERT: HAZARD DETECTED!  \r\n");
            xil_printf("<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\r\n");
            break;
        }
        timeout++;
    }

    if (timeout >= 10000000) {
        xil_printf("[CPU] Transfer finished. No hazard detected in this frame.\r\n");
    }

    xil_printf("Test Complete. Shutting down.\r\n");
    return 0;
}