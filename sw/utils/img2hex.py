import cv2
import sys

def convert_image_to_hex(image_path, output_path):
    # 1. Load the image
    img = cv2.imread(image_path)
    if img is None:
        print(f"Error: Could not open {image_path}")
        sys.exit(1)

    # 2. Resize to our hardware specification (1280x720)
    img_resized = cv2.resize(img, (1280, 720))

    # 3. OpenCV loads as BGR. Convert to standard RGB for our hardware.
    img_rgb = cv2.cvtColor(img_resized, cv2.COLOR_BGR2RGB)

    # 4. Write pixels to hex file (Left to Right, Top to Bottom)
    with open(output_path, 'w') as f:
        for row in range(720):
            for col in range(1280):
                r, g, b = img_rgb[row, col]
                # Format as 24-bit hex: RRGGBB
                hex_str = f"{r:02X}{g:02X}{b:02X}\n"
                f.write(hex_str)
                
    print(f"Successfully generated {output_path} (921,600 pixels)")

if __name__ == "__main__":
    convert_image_to_hex("test_image.png", "video_in.hex")