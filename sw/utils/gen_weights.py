import random

def generate_dummy_weights(output_path, num_weights=4096):
    with open(output_path, 'w') as f:
        for _ in range(num_weights):
            # Generate random INT8 (-128 to 127)
            val = random.randint(-128, 127)
            # Convert to 8-bit two's complement hex
            hex_val = val & 0xFF
            f.write(f"{hex_val:02X}\n")
            
    print(f"Successfully generated {num_weights} dummy weights in {output_path}")

if __name__ == "__main__":
    generate_dummy_weights("weights.hex")