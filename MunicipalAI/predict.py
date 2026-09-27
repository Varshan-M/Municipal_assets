import argparse
import json
import numpy as np
from pathlib import Path
import tensorflow as tf

MODELS_DIR = Path(r"D:\Municipal_assets\MunicipalAI\models")
MODEL_PATH = MODELS_DIR / "municipal_asset_model.keras"
CLASSES_PATH = MODELS_DIR / "classes.json"
IMG_SIZE = (224, 224)

def load_classes():
    with open(CLASSES_PATH, 'r') as f:
        return json.load(f)

def predict(image_path):
    if not MODEL_PATH.exists():
        print(f"Error: Model not found at {MODEL_PATH}")
        return
        
    model = tf.keras.models.load_model(MODEL_PATH)
    classes = load_classes()
    
    # Load and preprocess image
    img = tf.keras.utils.load_img(image_path, target_size=IMG_SIZE)
    img_array = tf.keras.utils.img_to_array(img)
    # Expand dimensions to create batch of size 1
    img_array = tf.expand_dims(img_array, 0)
    
    # Predict
    predictions = model.predict(img_array, verbose=0)[0]
    
    # Get highest probability
    predicted_idx = np.argmax(predictions)
    predicted_class = classes[str(predicted_idx)]
    confidence = predictions[predicted_idx] * 100
    
    print(f"\nImage: {image_path}")
    print(f"Predicted class: {predicted_class}")
    print(f"Confidence: {confidence:.2f}%\n")
    print("Probabilities:")
    
    # Print all probabilities sorted
    sorted_indices = np.argsort(predictions)[::-1]
    for idx in sorted_indices:
        print(f"{classes[str(idx)]}: {predictions[idx] * 100:.2f}%")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Predict municipal asset from an image.")
    parser.add_argument("image_path", type=str, help="Path to the image to verify")
    args = parser.parse_args()
    
    predict(args.image_path)
