"""After bake_sprites.gd: make the glow sheets' dark pixels transparent.

Run from the project root:  python3 tools/finish_glow.py
"""
import glob
import numpy as np
from PIL import Image

for path in glob.glob("sprites/*_glow.png"):
    a = np.asarray(Image.open(path).convert("RGBA")).astype(float) / 255
    rgb, alpha = a[..., :3], a[..., 3]
    m = rgb.max(axis=2)
    out = np.zeros_like(a)
    out[..., :3] = rgb / np.maximum(m, 1e-3)[..., None]
    out[..., 3] = np.clip(m * alpha * 1.4, 0, 1)
    Image.fromarray((out * 255).astype(np.uint8)).save(path)
    print("finished", path)
