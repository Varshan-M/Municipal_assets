import os
import sys
import json
import numpy as np
from pathlib import Path
import threading
import firebase_admin
from firebase_admin import credentials, firestore
from api.agent_worker import start_listening
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse
import tensorflow as tf
from tensorflow.keras.applications.mobilenet_v2 import MobileNetV2, preprocess_input, decode_predictions

# Add parent directory to path to import verify_image
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from verify_image import verify_image_logic, verify_resolution_logic

app = FastAPI(title="Municipal Asset Verification API")

MODELS_DIR = Path(r"D:\Municipal_assets\MunicipalAI\models")
MODEL_PATH = MODELS_DIR / "municipal_asset_model.keras"
CLASSES_PATH = MODELS_DIR / "classes.json"
IMG_SIZE = (224, 224)

# Global variables to hold the loaded models and classes
model = None
imagenet_model = None
classes = {}
db = None

# Blacklist of common keywords for things that are definitely NOT municipal assets
JUNK_KEYWORDS = [
    'bottle', 'cup', 'mug', 'glass', 'keyboard', 'mouse', 'laptop', 'monitor', 
    'screen', 'desk', 'chair', 'bed', 'sofa', 'couch', 'table', 'shoe', 'boot', 
    'sandal', 'foot', 'hand', 'face', 'person', 'dog', 'cat', 'bird', 'fish', 
    'horse', 'cow', 'sheep', 'pig', 'chicken', 'food', 'plate', 'bowl', 'pizza', 
    'burger', 'sandwich', 'fruit', 'apple', 'banana', 'orange', 'phone', 
    'television', 'remote', 'watch', 'clock', 'bag', 'backpack', 'purse', 
    'wallet', 'book', 'pen', 'pencil'
]

@app.on_event("startup")
def load_model_on_startup():
    global model, imagenet_model, classes, db
    
    # Initialize Firebase if not already initialized
    try:
        if not firebase_admin._apps:
            cred = credentials.Certificate(os.path.join(os.path.dirname(__file__), "firebase-service-account.json"))
            firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("Firebase initialized in main.py")
    except Exception as e:
        print(f"Warning: Could not initialize Firebase in main.py: {e}")
        
    if MODEL_PATH.exists() and CLASSES_PATH.exists():
        print("Loading custom Keras model into memory...")
        model = tf.keras.models.load_model(MODEL_PATH)
        
        print("Loading ImageNet Pre-check model...")
        imagenet_model = MobileNetV2(weights='imagenet')
        
        with open(CLASSES_PATH, 'r') as f:
            classes = json.load(f)
        print("Models and classes loaded successfully.")
    else:
        print("WARNING: Model or classes.json not found. API will not function correctly until training is complete.")
        
    print("Starting Automated Follow-up Agent in background...")
    agent_thread = threading.Thread(target=start_listening, daemon=True)
    agent_thread.start()

@app.post("/verify-image")
async def verify_image(
    asset: str = Form(...),
    problem: str = Form(...),
    image: UploadFile = File(...)
):
    global model, classes
    
    if model is None:
        return JSONResponse(status_code=503, content={
            "valid": False,
            "status": "model_not_ready",
            "message": "The backend AI model is not trained or loaded yet."
        })

    # Read image contents
    contents = await image.read()
    
    # Save temporarily to load with Keras
    temp_path = "temp_uploaded_img.jpg"
    with open(temp_path, "wb") as f:
        f.write(contents)
        
    try:
        # Load the raw image
        img = tf.keras.utils.load_img(temp_path, target_size=IMG_SIZE)
        img_array_raw = tf.keras.utils.img_to_array(img)
        img_array_batch = tf.expand_dims(img_array_raw, 0)
        
        # --- PRE-CHECK WITH IMAGENET ---
        # ImageNet requires preprocessing
        img_array_preprocessed = preprocess_input(img_array_batch.numpy().copy())
        imagenet_preds = imagenet_model.predict(img_array_preprocessed, verbose=0)
        decoded_preds = decode_predictions(imagenet_preds, top=3)[0]
        
        # Check if the top prediction contains a junk keyword
        for _, class_name, prob in decoded_preds:
            class_name_lower = class_name.lower().replace('_', ' ')
            if prob > 0.15: # If it's at least 15% confident about the object
                if any(kw in class_name_lower for kw in JUNK_KEYWORDS):
                    return JSONResponse(content={
                        "valid": False,
                        "status": "asset_mismatch",
                        "selected_asset": asset,
                        "selected_problem": problem,
                        "detected_class": "junk_object",
                        "confidence": float(prob),
                        "message": f"Please upload the {asset} image. (Detected: {class_name_lower})"
                    })
        
        # --- CUSTOM MODEL PREDICTION ---
        # Our custom model expects raw [0, 255] inputs because we baked preprocessing into the architecture
        predictions = model.predict(img_array_batch, verbose=0)[0]
        predicted_idx = np.argmax(predictions)
        predicted_class = classes[str(predicted_idx)]
        confidence = float(predictions[predicted_idx])
        
        # Verify
        result = verify_image_logic(asset, problem, predicted_class, confidence)
        return result
        
    finally:
        # Clean up
        if os.path.exists(temp_path):
            os.remove(temp_path)

@app.post("/verify-resolution")
async def verify_resolution(
    asset: str = Form(...),
    image: UploadFile = File(...)
):
    global model, classes
    
    if model is None:
        return JSONResponse(status_code=503, content={
            "valid": False,
            "status": "model_not_ready",
            "message": "The backend AI model is not trained or loaded yet."
        })

    # Read image contents
    contents = await image.read()
    
    # Save temporarily to load with Keras
    temp_path = "temp_resolution_img.jpg"
    with open(temp_path, "wb") as f:
        f.write(contents)
        
    try:
        # Load the raw image
        img = tf.keras.utils.load_img(temp_path, target_size=IMG_SIZE)
        img_array_raw = tf.keras.utils.img_to_array(img)
        img_array_batch = tf.expand_dims(img_array_raw, 0)
        
        # --- PRE-CHECK WITH IMAGENET ---
        img_array_preprocessed = preprocess_input(img_array_batch.numpy().copy())
        imagenet_preds = imagenet_model.predict(img_array_preprocessed, verbose=0)
        decoded_preds = decode_predictions(imagenet_preds, top=3)[0]
        
        for _, class_name, prob in decoded_preds:
            class_name_lower = class_name.lower().replace('_', ' ')
            if prob > 0.15: 
                if any(kw in class_name_lower for kw in JUNK_KEYWORDS):
                    return JSONResponse(content={
                        "valid": False,
                        "status": "asset_mismatch",
                        "selected_asset": asset,
                        "detected_class": "junk_object",
                        "confidence": float(prob),
                        "message": f"Please upload a valid photo of the repaired {asset}. (Detected: {class_name_lower})"
                    })
        
        # --- CUSTOM MODEL PREDICTION ---
        predictions = model.predict(img_array_batch, verbose=0)[0]
        predicted_idx = np.argmax(predictions)
        predicted_class = classes[str(predicted_idx)]
        confidence = float(predictions[predicted_idx])
        
        # Verify Resolution
        result = verify_resolution_logic(asset, predicted_class, confidence)
        return result
        
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

@app.post("/iot-report")
async def iot_report(
    latitude: str = Form(...),
    longitude: str = Form(...),
    image: UploadFile = File(...)
):
    global model, classes, db
    
    if model is None or db is None:
        return JSONResponse(status_code=503, content={"success": False, "message": "Backend not fully initialized."})

    contents = await image.read()
    temp_path = "temp_iot_img.jpg"
    with open(temp_path, "wb") as f:
        f.write(contents)
        
    try:
        img = tf.keras.utils.load_img(temp_path, target_size=IMG_SIZE)
        img_array = tf.expand_dims(tf.keras.utils.img_to_array(img), 0)
        
        # We can run the ImageNet check here too to avoid false positives from IoT cams
        img_array_preprocessed = preprocess_input(img_array.numpy().copy())
        imagenet_preds = imagenet_model.predict(img_array_preprocessed, verbose=0)
        decoded_preds = decode_predictions(imagenet_preds, top=3)[0]
        
        for _, class_name, prob in decoded_preds:
            if prob > 0.15 and any(kw in class_name.lower().replace('_', ' ') for kw in JUNK_KEYWORDS):
                return JSONResponse(content={"success": False, "message": f"Rejected as junk: {class_name}"})

        # Run custom model
        predictions = model.predict(img_array, verbose=0)[0]
        predicted_idx = np.argmax(predictions)
        predicted_class = classes[str(predicted_idx)]
        confidence = float(predictions[predicted_idx])
        
        # Only log issues, ignore normal states
        if predicted_class == "normal_road" or confidence < 0.60:
            return JSONResponse(content={
                "success": True, 
                "detected": predicted_class,
                "confidence": confidence,
                "message": "No actionable issue detected."
            })
            
        # Map prediction to database formats
        asset_type = "Unknown"
        issue_type = predicted_class.capitalize()
        if predicted_class == "pothole":
            asset_type = "Road"
            
        # Write to Firebase
        doc_ref = db.collection('complaints').document()
        doc_ref.set({
            'assetType': asset_type,
            'issueType': issue_type,
            'description': f"Automatically detected by IoT Camera with {confidence*100:.1f}% confidence.",
            'latitude': float(latitude),
            'longitude': float(longitude),
            'address': f"Auto-Generated from GPS: {latitude}, {longitude}",
            'status': 'Submitted',
            'source': 'IoT Camera',
            'createdAt': firestore.SERVER_TIMESTAMP,
            'imageUrl': 'https://via.placeholder.com/400?text=IoT+Image' # In real life, upload to storage first
        })
        
        return JSONResponse(content={
            "success": True,
            "detected": predicted_class,
            "confidence": confidence,
            "message": f"Successfully created complaint {doc_ref.id} for {predicted_class}"
        })
        
    except Exception as e:
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
