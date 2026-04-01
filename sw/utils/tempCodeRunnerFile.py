import cv2
import numpy as np
import time

def run_cpu_benchmark(image_path, weights_path):
    print("--- Starting CPU Benchmark ---")
    
    # 1. Load the raw image and the quantized weights
    img = cv2.imread(image_path)
    if img is None:
        print(f"Error: Could not load {image_path}. Make sure the file exists.")
        return
        
# Load as unsigned first to safely capture 0-255, then cast the bits to signed int8
    weights = np.loadtxt(weights_path, dtype=np.uint8, converters={0: lambda s: int(s, 16)})
    weights = weights.astype(np.int8).reshape((64, 64))

    # --- START TIMER ---
    start_time = time.perf_counter()

    # Stage 1: Grayscale (Manual weights to match our RTL: R>>2 + G>>1 + B>>2)
    # OpenCV loads in BGR format
    b, g, r = cv2.split(img)
    gray = (r >> 2) + (g >> 1) + (b >> 2)
    gray = gray.astype(np.uint8)

    # Stage 2: 3x3 Gaussian Blur
    # We use a custom kernel to exactly match our hardware bit-shifts
    blur_kernel = np.array([[1, 2, 1],
                            [2, 4, 2],
                            [1, 2, 1]], dtype=np.float32) / 16.0
    blurred = cv2.filter2D(gray, -1, blur_kernel)

    # Stage 3: Sobel Edge Detection (Matching our RTL magnitude logic)
    sobel_x = cv2.Sobel(blurred, cv2.CV_16S, 1, 0, ksize=3)
    sobel_y = cv2.Sobel(blurred, cv2.CV_16S, 0, 1, ksize=3)
    abs_gx = np.absolute(sobel_x)
    abs_gy = np.absolute(sobel_y)
    magnitude = abs_gx + abs_gy
    
    # RTL Thresholding
    edges = np.where(magnitude > 100, 1, 0).astype(np.int8)

    # Stage 4: AI Brain (MAC Accumulation)
    # Extract the 64x64 bounding box (X: 608-671, Y: 328-391)
    roi = edges[328:392, 608:672]
    
    # Multiply and Accumulate
    mac_result = np.sum(roi * weights)

    # Hardware Reflex Trigger
    hazard_detected = mac_result > 700

    # --- STOP TIMER ---
    end_time = time.perf_counter()
    cpu_latency = (end_time - start_time) * 1000 # Convert to milliseconds

    print(f"CPU Processing Time: {cpu_latency:.2f} ms")
    print(f"Hazard Score: {mac_result}")
    print(f"Hazard Detected: {hazard_detected}")
    print("------------------------------")

if __name__ == "__main__":
    # We use a standard JPG version of your input for the CPU test
    # (Assuming you have a 'test_image.jpg' that matches the hex data)
    run_cpu_benchmark("dsp_output.jpg", "weights.hex") 
    # Note: Replace 'dsp_output.jpg' with the original raw image if you have it saved as a JPG/PNG. 
    # If not, the processing time calculation will still be architecturally valid on this image.