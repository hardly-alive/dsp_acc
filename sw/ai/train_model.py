import torch
import torch.nn as nn
import torch.optim as optim
import numpy as np
import random

# ==========================================
# 1. Synthetic Dataset Generator
# ==========================================
def generate_dataset(num_samples=5000):
    X = torch.zeros((num_samples, 4096))
    y = torch.zeros((num_samples, 1))
    
    for i in range(num_samples):
        img = np.zeros((64, 64), dtype=np.float32)
        is_hazard = random.choice([0, 1])
        
        if is_hazard:
            # RANDOM POSITION: Wire can appear anywhere from row 5 to 55
            start_row = random.randint(5, 55)
            # RANDOM THICKNESS: 2 to 4 pixels
            thick = random.randint(2, 4)
            
            # RANDOM ORIENTATION: Horizontal OR slightly diagonal
            if random.random() > 0.5:
                # Horizontal line
                img[start_row : start_row + thick, :] = 1.0
            else:
                # Simple diagonal line (simulated by drawing across columns)
                for c in range(64):
                    r = start_row + (c // 8) # Creates a slight tilt
                    if r < 64:
                        img[r : r + thick, c] = 1.0
            y[i] = 1.0
        
        # INCREASED CLUTTER: Add random "edge noise" everywhere
        noise_mask = np.random.random((64, 64)) > 0.99
        img[noise_mask] = 1.0
            
        X[i] = torch.tensor(img.flatten(), dtype=torch.float32)
        
    return X, y

# ==========================================
# 2. Model
# ==========================================
class HardwareMAC(nn.Module):
    def __init__(self):
        super(HardwareMAC, self).__init__()
        # EXACT match to our FPGA: 4096 inputs, 1 output, NO bias adder.
        self.fc = nn.Linear(in_features=4096, out_features=1, bias=False)
        
    def forward(self, x):
        # Multiply/Accumulate, then squash to 0.0 -> 1.0 probability
        mac_result = self.fc(x)
        return mac_result

# ==========================================
# 3. The Training Setup
# ==========================================
print("Generating 5,000 synthetic edge maps...")
X_train, y_train = generate_dataset(5000)
model = HardwareMAC()
torch.nn.init.xavier_uniform_(model.fc.weight)

# BCE measures how far the probability is from the true 0 or 1
criterion = nn.MSELoss() 
# Adam is the engine that nudges the weights
optimizer = optim.Adam(model.parameters(), lr=0.001)

# ==========================================
# 4. The Training Loop
# ==========================================
epochs = 500
print("Starting AI Training...")

for epoch in range(epochs):
    # 1. Wipe the old math
    optimizer.zero_grad()
    
    # 2. Forward Pass: Make a guess
    predictions = model(X_train)
    
    # 3. Calculate how wrong the guess was
    loss = criterion(predictions, y_train)
    
    # 4. Backward Pass: Calculate the corrections
    loss.backward()
    
    # 5. Apply the corrections to the weights
    optimizer.step()
    
    # Print progress every 50 loops
    if epoch % 50 == 0:
        print(f"Epoch {epoch:3d} | Loss: {loss.item():.4f}")

print("Training Complete!")

# ==========================================
# 5. Quantization & Export (FP32 -> INT8)
# ==========================================
print("\nQuantizing weights for the FPGA...")
# Pull the raw decimal weights out of PyTorch
raw_weights = model.fc.weight.data.numpy().flatten()

# Find the maximum absolute value
max_val = np.max(np.abs(raw_weights))

# Calculate the scale factor to stretch the max value to exactly 127
scale_factor = 127.0 / max_val

# Multiply, round to nearest whole number, and force into integer type
quantized_weights = np.round(raw_weights * scale_factor).astype(int)

# Write to our hardware's hex file!
with open("weights.hex", "w") as f:
    for w in quantized_weights:
        # Convert signed INT8 to two's complement 8-bit hex
        hex_val = w & 0xFF
        f.write(f"{hex_val:02X}\n")

print("✅ Saved 4,096 quantized INT8 weights to 'weights.hex'!")