import cv2
import numpy as np
import sys

def convert_hex_to_image(hex_file, output_image, width=1280, height=720):
    # Create an empty numpy array for the grayscale image
    img_array = np.zeros((height, width), dtype=np.uint8)
    
    pixel_count = 0
    with open(hex_file, 'r') as f:
        for row in range(height):
            for col in range(width):
                line = f.readline().strip()
                if not line:
                    break # End of file reached prematurely
                
                # Convert 8-bit hex string back to integer
                img_array[row, col] = int(line, 16)
                pixel_count += 1
                
    # Save the array as an image
    cv2.imwrite(output_image, img_array)
    print(f"Successfully reconstructed {output_image} from {pixel_count} pixels.")

if __name__ == "__main__":
    convert_hex_to_image("video_out.hex", "dsp_output.jpg")