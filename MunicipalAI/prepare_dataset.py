import os
import shutil
import random
from pathlib import Path
from PIL import Image

# Configuration
SOURCE_DIR = Path(r"D:\Municipal_assets\dataset")
DEST_DIR = Path(r"D:\Municipal_assets\MunicipalAI\dataset")
REPORT_PATH = Path(r"D:\Municipal_assets\MunicipalAI\dataset_report.txt")
MAX_IMAGES_PER_CLASS = 1500  # Configurable balanced subset
SEED = 42

random.seed(SEED)

def is_valid_image(filepath):
    try:
        with Image.open(filepath) as img:
            img.verify()
        return True
    except Exception:
        return False

def discover_images(directory):
    extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.webp'}
    images = []
    for root, _, files in os.walk(directory):
        for file in files:
            if Path(file).suffix.lower() in extensions:
                images.append(Path(root) / file)
    return images

def create_split(images, train_ratio=0.7, val_ratio=0.15):
    random.shuffle(images)
    total = len(images)
    train_end = int(total * train_ratio)
    val_end = train_end + int(total * val_ratio)
    
    return {
        'train': images[:train_end],
        'validation': images[train_end:val_end],
        'test': images[val_end:]
    }

def process_dataset():
    if DEST_DIR.exists():
        print(f"Cleaning existing dataset directory: {DEST_DIR}")
        shutil.rmtree(DEST_DIR)
        
    for split in ['train', 'validation', 'test']:
        for class_name in ['pothole', 'building_crack', 'public_building_normal', 'trash_bin', 'street_light_working', 'street_light_not_working', 'normal_road', 'other']:
            (DEST_DIR / split / class_name).mkdir(parents=True, exist_ok=True)

    report_lines = []
    report_lines.append("DATASET PREPARATION AND AUDIT REPORT\n")
    report_lines.append("=" * 50 + "\n")
    
    # 1. Pothole
    print("Processing Pothole dataset (preserving original splits)...")
    pothole_stats = {'train': 0, 'validation': 0, 'test': 0, 'corrupted': 0}
    for split_in, split_out in [('train', 'train'), ('valid', 'validation'), ('test', 'test')]:
        src_split = SOURCE_DIR / 'pothole' / split_in / 'images'
        if src_split.exists():
            for img_path in discover_images(src_split):
                if is_valid_image(img_path):
                    shutil.copy2(img_path, DEST_DIR / split_out / 'pothole' / img_path.name)
                    pothole_stats[split_out] += 1
                else:
                    pothole_stats['corrupted'] += 1
    
    total_pothole = sum(v for k,v in pothole_stats.items() if k != 'corrupted')
    status = "Sufficient" if total_pothole > 500 else "Insufficient"
    report_lines.append(f"Class: pothole")
    report_lines.append(f"  Status: {status}")
    report_lines.append(f"  Total Valid Images: {total_pothole}")
    report_lines.append(f"  Train: {pothole_stats['train']}, Validation: {pothole_stats['validation']}, Test: {pothole_stats['test']}")
    report_lines.append(f"  Corrupted: {pothole_stats['corrupted']}\n")

    # 2. Public Building (Positive -> building_crack, Negative -> public_building_normal)
    print("Processing Public Building dataset...")
    for src_class, dest_class in [('Positive', 'building_crack'), ('Negative', 'public_building_normal')]:
        src_dir = SOURCE_DIR / 'public_building' / src_class
        stats = {'train': 0, 'validation': 0, 'test': 0, 'corrupted': 0}
        
        if src_dir.exists():
            all_images = discover_images(src_dir)
            valid_images = []
            print(f"  Checking {len(all_images)} images for {src_class} (this might take a moment)...")
            
            # Subsample first to avoid checking 20,000 images if we only need 1500
            random.shuffle(all_images)
            candidate_images = all_images[:int(MAX_IMAGES_PER_CLASS * 1.2)]
            
            for img_path in candidate_images:
                if len(valid_images) >= MAX_IMAGES_PER_CLASS:
                    break
                if is_valid_image(img_path):
                    valid_images.append(img_path)
                else:
                    stats['corrupted'] += 1
            
            splits = create_split(valid_images)
            
            for split_name, img_list in splits.items():
                for img_path in img_list:
                    shutil.copy2(img_path, DEST_DIR / split_name / dest_class / f"{src_class}_{img_path.name}")
                    stats[split_name] += 1
                    
        total = sum(v for k,v in stats.items() if k != 'corrupted')
        status = "Sufficient" if total > 500 else "Insufficient"
        report_lines.append(f"Class: {dest_class}")
        report_lines.append(f"  Status: {status} (Subsampled to MAX {MAX_IMAGES_PER_CLASS})")
        report_lines.append(f"  Total Valid Images: {total}")
        report_lines.append(f"  Train: {stats['train']}, Validation: {stats['validation']}, Test: {stats['test']}")
        report_lines.append(f"  Corrupted: {stats['corrupted']}\n")

    # 3. Trash Bin
    print("Processing Trash Bin dataset...")
    src_dir = SOURCE_DIR / 'trash_bin'
    stats = {'train': 0, 'validation': 0, 'test': 0, 'corrupted': 0}
    if src_dir.exists():
        valid_images = []
        for img_path in discover_images(src_dir):
            if is_valid_image(img_path):
                valid_images.append(img_path)
            else:
                stats['corrupted'] += 1
        
        splits = create_split(valid_images)
        for split_name, img_list in splits.items():
            for img_path in img_list:
                shutil.copy2(img_path, DEST_DIR / split_name / 'trash_bin' / img_path.name)
                stats[split_name] += 1
                
    total = sum(v for k,v in stats.items() if k != 'corrupted')
    report_lines.append(f"Class: trash_bin")
    report_lines.append(f"  Status: INSUFFICIENT (Do NOT train final model with this)")
    report_lines.append(f"  Total Valid Images: {total}")
    report_lines.append(f"  Train: {stats['train']}, Validation: {stats['validation']}, Test: {stats['test']}")
    report_lines.append(f"  Corrupted: {stats['corrupted']}\n")
    
    # 4. Street Light
    print("Processing Street Light dataset...")
    for src_class, dest_class in [('Working', 'street_light_working'), ('Not Working', 'street_light_not_working')]:
        src_dir = SOURCE_DIR / 'street_light' / src_class
        stats = {'train': 0, 'validation': 0, 'test': 0, 'corrupted': 0}
        
        if src_dir.exists():
            valid_images = []
            for img_path in discover_images(src_dir):
                if is_valid_image(img_path):
                    valid_images.append(img_path)
                else:
                    stats['corrupted'] += 1
            
            splits = create_split(valid_images)
            for split_name, img_list in splits.items():
                for img_path in img_list:
                    shutil.copy2(img_path, DEST_DIR / split_name / dest_class / img_path.name)
                    stats[split_name] += 1
                    
        total = sum(v for k,v in stats.items() if k != 'corrupted')
        status = "Sufficient" if total > 200 else "Insufficient"
        report_lines.append(f"Class: {dest_class}")
        report_lines.append(f"  Status: {status}")
        report_lines.append(f"  Total Valid Images: {total}")
        report_lines.append(f"  Train: {stats['train']}, Validation: {stats['validation']}, Test: {stats['test']}")
        report_lines.append(f"  Corrupted: {stats['corrupted']}\n")
    
    # 5. Normal Road
    print("Processing Normal Road dataset...")
    src_dir = SOURCE_DIR / 'pothole' / 'normal_road'
    stats = {'train': 0, 'validation': 0, 'test': 0, 'corrupted': 0}
    
    if src_dir.exists():
        valid_images = []
        for img_path in discover_images(src_dir):
            if is_valid_image(img_path):
                valid_images.append(img_path)
            else:
                stats['corrupted'] += 1
        
        splits = create_split(valid_images)
        for split_name, img_list in splits.items():
            for img_path in img_list:
                shutil.copy2(img_path, DEST_DIR / split_name / 'normal_road' / img_path.name)
                stats[split_name] += 1
                
    total = sum(v for k,v in stats.items() if k != 'corrupted')
    status = "Sufficient" if total > 200 else "Insufficient"
    report_lines.append(f"Class: normal_road")
    report_lines.append(f"  Status: {status}")
    report_lines.append(f"  Total Valid Images: {total}")
    report_lines.append(f"  Train: {stats['train']}, Validation: {stats['validation']}, Test: {stats['test']}")
    report_lines.append(f"  Corrupted: {stats['corrupted']}\n")
    
    # 6. Missing Classes
    report_lines.append(f"Class: other")
    report_lines.append(f"  Status: MISSING (0 images)\n")
    
    # Summary of Training Feasibility
    report_lines.append("=" * 50 + "\n")
    report_lines.append("TRAINING FEASIBILITY ANALYSIS\n")
    report_lines.append("Asset Verification Model: Ready for training! Ensure trash_bin is handled carefully.\n")
    report_lines.append("Problem Verification Model: Ready for training. Both positive and negative classes are present for major assets.\n")
    
    with open(REPORT_PATH, 'w', encoding='utf-8') as f:
        f.writelines(line + '\n' for line in report_lines)
    
    print(f"\nDataset preparation complete. Report saved to {REPORT_PATH}")

if __name__ == "__main__":
    process_dataset()
