import os
from collections import defaultdict
import glob

dataset_dir = r"D:\Municipal_assets\dataset"
extensions = ('.jpg', '.jpeg', '.png', '.bmp', '.webp')

print(f"Inspecting {dataset_dir}...")
for root, dirs, files in os.walk(dataset_dir):
    image_count = sum(1 for f in files if f.lower().endswith(extensions))
    if image_count > 0:
        print(f"{root}: {image_count} images")

print("Inspection complete.")
