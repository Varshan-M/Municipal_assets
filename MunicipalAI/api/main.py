import os
import sys
import json
import numpy as np
from pathlib import Path
import threading
import socket
import uuid
import firebase_admin
from firebase_admin import credentials, firestore
from api.agent_worker import start_listening
from api.mqtt_worker import start_mqtt_worker
from api.supervisor_agent import start_supervisor_worker
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import tensorflow as tf
from tensorflow.keras.applications.mobilenet_v2 import MobileNetV2, preprocess_input, decode_predictions
from PIL import Image, ImageDraw, ImageFont
import base64
import io
from datetime import datetime

# Add parent directory to path to import verify_image
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from verify_image import verify_image_logic, verify_resolution_logic

app = FastAPI(title="Municipal Asset Verification API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MODELS_DIR = Path(os.path.abspath(__file__)).parent.parent / "models"
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
            cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", os.path.join(os.path.dirname(__file__), "firebase-service-account.json"))
            cred = credentials.Certificate(cred_path)
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
    else:
        print("WARNING: Model or classes.json not found. API will not function correctly until training is complete.")
        
    # Auto-publish local IP to Firestore so the mobile app can find the backend dynamically
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        
        backend_url = f"http://{local_ip}:8000"
        db.collection('settings').document('backend_config').set({
            'url': backend_url,
            'updatedAt': firestore.SERVER_TIMESTAMP
        })
        print(f"Published backend URL to Firestore: {backend_url}")
    except Exception as e:
        print(f"Warning: Could not publish backend IP to Firestore: {e}")
        
    print("Starting Automated Follow-up Agent in background...")
    agent_thread = threading.Thread(target=start_listening, daemon=True)
    agent_thread.start()
    
    print("Starting IoT Surface Monitoring MQTT Daemon...")
    mqtt_thread = threading.Thread(target=start_mqtt_worker, daemon=True)
    mqtt_thread.start()

    print("Starting Supervisor Agent...")
    start_supervisor_worker()

@app.post("/verify-image")
async def verify_image(
    asset: str = Form(...),
    problem: str = Form(...),
    latitude: str = Form(None),
    longitude: str = Form(None),
    address: str = Form(None),
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
        
        # If valid and we have GPS, draw a visual Geotag watermark on the image
        if result.get("valid") == True and latitude and longitude:
            try:
                pil_img = Image.open(temp_path).convert("RGB")
                draw = ImageDraw.Draw(pil_img, "RGBA")
                width, height = pil_img.size
                
                # Draw semi-transparent rectangle at bottom
                rect_height = max(80, int(height * 0.15))
                draw.rectangle([(0, height - rect_height), (width, height)], fill=(0, 0, 0, 180))
                
                # We use default font since we can't guarantee ttf existence across all OS
                font = ImageFont.load_default()
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                
                # Use standard string formatting for text
                text_lat_lng = f"Lat: {latitude[:9]}, Lng: {longitude[:9]}"
                text_date = f"Date: {timestamp}"
                text_address = f"Address: {address[:40]}..." if address else ""
                
                # Draw text
                draw.text((10, height - rect_height + 10), text_lat_lng, fill=(255, 255, 255), font=font)
                draw.text((10, height - rect_height + 30), text_date, fill=(255, 255, 255), font=font)
                if text_address:
                    draw.text((10, height - rect_height + 50), text_address, fill=(255, 255, 255), font=font)
                
                # Convert back to base64
                buffered = io.BytesIO()
                pil_img.save(buffered, format="JPEG", quality=85)
                img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")
                
                result["watermarked_base64"] = f"data:image/jpeg;base64,{img_str}"
            except Exception as e:
                print(f"Failed to watermark image: {e}")
                
        return result
        
    finally:
        # Clean up
        if os.path.exists(temp_path):
            os.remove(temp_path)

@app.post("/verify-resolution")
async def verify_resolution(
    asset: str = Form(...),
    latitude: str = Form(None),
    longitude: str = Form(None),
    address: str = Form(None),
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
        
        # If valid and we have GPS, draw a visual Geotag watermark on the image
        if result.get("valid") == True and latitude and longitude:
            try:
                pil_img = Image.open(temp_path).convert("RGB")
                draw = ImageDraw.Draw(pil_img, "RGBA")
                width, height = pil_img.size
                
                # Draw semi-transparent rectangle at bottom
                rect_height = max(80, int(height * 0.15))
                draw.rectangle([(0, height - rect_height), (width, height)], fill=(0, 0, 0, 180))
                
                font = ImageFont.load_default()
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                
                text_lat_lng = f"Lat: {latitude[:9]}, Lng: {longitude[:9]}"
                text_date = f"Date: {timestamp} (RESOLVED)"
                text_address = f"Address: {address[:40]}..." if address else ""
                
                draw.text((10, height - rect_height + 10), text_lat_lng, fill=(0, 255, 0), font=font)
                draw.text((10, height - rect_height + 30), text_date, fill=(0, 255, 0), font=font)
                if text_address:
                    draw.text((10, height - rect_height + 50), text_address, fill=(0, 255, 0), font=font)
                
                buffered = io.BytesIO()
                pil_img.save(buffered, format="JPEG", quality=85)
                img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")
                
                result["watermarked_base64"] = f"data:image/jpeg;base64,{img_str}"
            except Exception as e:
                print(f"Failed to watermark resolution image: {e}")

        return result
        
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)



@app.post("/iot-report")
async def iot_report(
    latitude: str = Form(None),
    longitude: str = Form(None),
    image: UploadFile = File(...)
):
    global model, classes, db
    
    if model is None or db is None:
        return JSONResponse(status_code=503, content={"success": False, "message": "Backend not fully initialized."})

    contents = await image.read()
    temp_path = f"temp_iot_img_{uuid.uuid4().hex[:6]}.jpg"
    with open(temp_path, "wb") as f:
        f.write(contents)
        
    try:
        img = tf.keras.utils.load_img(temp_path, target_size=IMG_SIZE)
        img_array = tf.expand_dims(tf.keras.utils.img_to_array(img), 0)
        
        # ImageNet Pre-check
        img_array_preprocessed = preprocess_input(img_array.numpy().copy())
        imagenet_preds = imagenet_model.predict(img_array_preprocessed, verbose=0)
        decoded_preds = decode_predictions(imagenet_preds, top=3)[0]
        
        for _, class_name, prob in decoded_preds:
            if prob > 0.15 and any(kw in class_name.lower().replace('_', ' ') for kw in JUNK_KEYWORDS):
                return JSONResponse(content={"success": False, "message": f"Rejected as junk: {class_name}"})

        # Custom model prediction
        predictions = model.predict(img_array, verbose=0)[0]
        predicted_idx = np.argmax(predictions)
        predicted_class = classes[str(predicted_idx)]
        confidence = float(predictions[predicted_idx])
        
        valid_issues = {
            "pothole": {"assetType": "Road", "issueType": "Pothole"},
            "building_crack": {"assetType": "Public Building", "issueType": "Crack"},
            "street_light_not_working": {"assetType": "Street Light", "issueType": "Not Working"},
            "trash_bin": {"assetType": "Garbage Bin", "issueType": "Overflowing"}
        }
        
        if predicted_class not in valid_issues or confidence < 0.70:
            return JSONResponse(content={
                "success": True, 
                "detected": predicted_class,
                "confidence": confidence,
                "message": "No actionable issue detected or confidence too low."
            })
            
        issue_data = valid_issues[predicted_class]
        
        # Watermark the image
        try:
            pil_img = Image.open(temp_path).convert("RGB")
            draw = ImageDraw.Draw(pil_img, "RGBA")
            width, height = pil_img.size
            
            rect_height = max(80, int(height * 0.15))
            draw.rectangle([(0, height - rect_height), (width, height)], fill=(0, 0, 0, 180))
            
            font = ImageFont.load_default()
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            lat_val = str(latitude)[:9] if latitude else "Unknown"
            lng_val = str(longitude)[:9] if longitude else "Unknown"
            
            text_lat_lng = f"Lat: {lat_val}, Lng: {lng_val}"
            text_date = f"Date: {timestamp}"
            text_iot = f"Source: IoT Camera System"
            
            draw.text((10, height - rect_height + 10), text_lat_lng, fill=(255, 255, 255), font=font)
            draw.text((10, height - rect_height + 30), text_date, fill=(255, 255, 255), font=font)
            draw.text((10, height - rect_height + 50), text_iot, fill=(255, 255, 255), font=font)
            
            buffered = io.BytesIO()
            pil_img.save(buffered, format="JPEG", quality=85)
            img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")
            watermarked_base64 = f"data:image/jpeg;base64,{img_str}"
        except Exception as e:
            print(f"IoT watermark failed: {e}")
            watermarked_base64 = None
            
        if not watermarked_base64:
             return JSONResponse(status_code=500, content={"success": False, "message": "Failed to process image."})
             
        # Write to Firebase
        complaint_id = str(uuid.uuid4())
        db.collection('complaints').document(complaint_id).set({
            'userId': 'iot_camera_system',
            'assetType': issue_data['assetType'],
            'issueType': issue_data['issueType'],
            'description': f"Automatically detected by IoT Camera with {confidence*100:.1f}% confidence.",
            'latitude': float(latitude) if latitude else 0.0,
            'longitude': float(longitude) if longitude else 0.0,
            'address': f"IoT Auto-Generated: {latitude}, {longitude}",
            'status': 'Submitted',
            'citizenPriority': 'Normal',
            'createdAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
            'imageUrl': watermarked_base64,
            'aiConfidence': confidence,
            'aiCategory': issue_data['assetType']
        })
        
        return JSONResponse(content={
            "success": True,
            "detected": predicted_class,
            "confidence": confidence,
            "complaint_id": complaint_id,
            "message": f"Successfully created complaint for {predicted_class}"
        })
        
    except Exception as e:
        print(f"IoT Report Error: {e}")
        return JSONResponse(status_code=500, content={"success": False, "error": str(e)})
    finally:
        if os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except:
                pass

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
