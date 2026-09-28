import os
import json
import time
import threading
import uuid
import paho.mqtt.client as mqtt
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timezone
from dotenv import load_dotenv

# Load Environment Variables
load_dotenv()

# ==========================================
# 1. FIREBASE INITIALIZATION
# ==========================================
print("[MQTT Worker] Initializing Firebase...")
try:
    if not firebase_admin._apps:
        cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", os.path.join(os.path.dirname(__file__), "firebase-service-account.json"))
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("[MQTT Worker] Firebase connected successfully!")
except Exception as e:
    print(f"[MQTT Worker] Firebase initialization error: {e}")
    exit(1)


# ==========================================
# 2. MQTT SETTINGS & CONSTANTS
# ==========================================
MQTT_BROKER = os.getenv("MQTT_BROKER", "your-broker.s1.eu.hivemq.cloud")
MQTT_PORT = int(os.getenv("MQTT_PORT", "8883"))
MQTT_USER = os.getenv("MQTT_USER", "nam_nagaram_admin")
MQTT_PASS = os.getenv("MQTT_PASS", "SecurePass123!")

TOPIC = "building/scanner/distance"

# Anomaly Detection Settings
DISPLACEMENT_THRESHOLD_CM = 5.0  # Alert if distance jumps by more than 5 cm
baseline_distances = {} # Store moving averages per device: { device_id: { 'avg': float, 'count': int } }

# ==========================================
# 3. ANOMALY DETECTION LOGIC
# ==========================================
def detect_structural_anomaly(device_id, distance_cm):
    """
    Maintains a simple moving average baseline.
    If the current reading deviates significantly from the baseline, trigger a structural anomaly complaint.
    """
    global baseline_distances
    
    if device_id not in baseline_distances:
        baseline_distances[device_id] = {'avg': distance_cm, 'count': 1}
        return False
    
    current_avg = baseline_distances[device_id]['avg']
    count = baseline_distances[device_id]['count']
    
    # Calculate difference
    difference = abs(current_avg - distance_cm)
    
    # Check if anomaly
    if difference > DISPLACEMENT_THRESHOLD_CM:
        print(f"[ALERT] Structural Anomaly Detected on {device_id}! Distance changed by {difference:.2f} cm (Baseline: {current_avg:.2f} cm, Current: {distance_cm:.2f} cm)")
        
        # We don't want to spam complaints, so maybe reset the baseline after triggering,
        # or implement a cooldown. For now, we reset baseline.
        baseline_distances[device_id] = {'avg': distance_cm, 'count': 1}
        return True
        
    # Update baseline (simple moving average, capping count to prevent it from getting too stiff)
    new_count = min(count + 1, 20) 
    new_avg = ((current_avg * (new_count - 1)) + distance_cm) / new_count
    baseline_distances[device_id] = {'avg': new_avg, 'count': new_count}
    
    return False

def generate_complaint(device_id, distance_cm):
    """
    Creates a new Complaint in Firestore so the AI Agent can schedule it.
    """
    try:
        complaint_id = str(uuid.uuid4())
        
        complaint_data = {
            "userId": "system_iot_scanner",
            "assetType": "Public Building",
            "issueType": "Structural Anomaly / Displacement",
            "description": f"URGENT: IoT Sensor '{device_id}' detected a sudden structural displacement. The surface distance reading suddenly shifted to {distance_cm} cm. This indicates a possible widening crack, wall shift, or structural settling. Immediate physical inspection required.",
            "latitude": 11.0168, # Defaulting to Coimbatore center; in real prod, map device_id to known coordinates
            "longitude": 76.9558,
            "address": f"IoT Monitored Location ({device_id})",
            "status": "Submitted",
            "citizenPriority": "Critical", # Trigger critical SLA
            "imageUrl": "", 
            "createdAt": firestore.SERVER_TIMESTAMP
        }
        
        db.collection('complaints').document(complaint_id).set(complaint_data)
        print(f"[MQTT Worker] Successfully generated structural complaint: {complaint_id}")
        
    except Exception as e:
        print(f"[MQTT Worker] Failed to generate complaint: {e}")

# ==========================================
# 4. MQTT CALLBACKS
# ==========================================
def on_connect(client, userdata, flags, reason_code, properties):
    if reason_code == 0:
        print(f"[MQTT Worker] Connected securely to MQTT Broker!")
        client.subscribe(TOPIC)
        print(f"[MQTT Worker] Subscribed to topic: {TOPIC}")
    else:
        print(f"[MQTT Worker] Failed to connect, return code {reason_code}")

def on_message(client, userdata, msg):
    try:
        payload = msg.payload.decode('utf-8')
        data = json.loads(payload)
        
        device_id = data.get("device_id", "unknown_device")
        distance_cm = float(data.get("distance_cm", -1.0))
        
        if distance_cm < 0:
            return # Ignore bad readings
            
        print(f"[MQTT Worker] Received reading: {device_id} -> {distance_cm} cm")
        
        # 1. Update Firestore Sensor Status (Heartbeat)
        db.collection("sensors").document(device_id).set({
            "lastSeen": firestore.SERVER_TIMESTAMP,
            "currentDistanceCm": distance_cm,
            "status": "Online"
        }, merge=True)
        
        # 2. Store Reading for Historical Charting
        reading_id = str(uuid.uuid4())
        db.collection("sensors").document(device_id).collection("readings").document(reading_id).set({
            "distance_cm": distance_cm,
            "timestamp": firestore.SERVER_TIMESTAMP
        })
        
        # 3. Anomaly Detection
        if detect_structural_anomaly(device_id, distance_cm):
            generate_complaint(device_id, distance_cm)
            
    except Exception as e:
        print(f"[MQTT Worker] Error processing message: {e}")

# ==========================================
# 5. START WORKER
# ==========================================
def start_mqtt_worker():
    print("[MQTT Worker] Starting Persistent MQTT Daemon...")
    
    # Enable TLS for secure connection
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.tls_set() # Uses default system certs
    client.username_pw_set(MQTT_USER, MQTT_PASS)
    
    client.on_connect = on_connect
    client.on_message = on_message
    
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_forever() # Persistent blocking loop
    except Exception as e:
        print(f"[MQTT Worker] Connection exception: {e}")
        time.sleep(5)
        start_mqtt_worker() # Recursive retry on fatal crash

if __name__ == "__main__":
    start_mqtt_worker()
