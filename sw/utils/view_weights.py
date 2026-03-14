import numpy as np
import cv2

# Load the hex weights
weights = []
with open("weights.hex", "r") as f:
    for line in f:
        # Convert hex back to signed int8
        val = int(line.strip(), 16)
        if val > 127: val -= 256
        weights.append(val)

# Reshape to 64x64 and normalize for viewing
brain_img = np.array(weights).reshape(64, 64)
brain_view = cv2.normalize(brain_img, None, 0, 255, cv2.NORM_MINMAX).astype(np.uint8)
cv2.imwrite("ai_brain_visual.jpg", brain_view)
print("Brain visualized! Open 'ai_brain_visual.jpg'")