import os
import time
import threading
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore
import uuid

# Get the absolute path to the api directory
API_DIR = os.path.dirname(os.path.abspath(__file__))

# Load environment variables from api/.env
load_dotenv(os.path.join(API_DIR, '.env'))

# Configure Firebase
CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json")
if not os.path.isabs(CREDENTIALS_PATH):
    CREDENTIALS_PATH = os.path.join(API_DIR, CREDENTIALS_PATH)
if not os.path.exists(CREDENTIALS_PATH):
    raise FileNotFoundError(f"Firebase credentials not found at {CREDENTIALS_PATH}")

if not firebase_admin._apps:
    cred = credentials.Certificate(CREDENTIALS_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()

def log_supervisor_action(action_type, target_id, message):
    try:
        db.collection('ai_logs').add({
            'actionType': action_type,
            'targetId': target_id,
            'message': message,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'agent': 'Supervisor_Agent'
        })
        print(f"[Supervisor Agent] {action_type} - {message}")
    except Exception as e:
        print(f"[Supervisor Agent] Error logging action: {e}")

def create_admin_alert(title, body, complaint_id=None):
    try:
        db.collection('notifications').add({
            'userId': 'admin', # generic admin target
            'title': title,
            'body': body,
            'createdAt': firestore.SERVER_TIMESTAMP,
            'read': False,
            'complaintId': complaint_id,
            'type': 'SUPERVISOR_ALERT'
        })
    except Exception as e:
        print(f"[Supervisor Agent] Error creating admin alert: {e}")

def check_stuck_assignments():
    """Detect complaints that have been submitted but failed to get scheduled by the Scheduling Agent."""
    now = datetime.now(timezone.utc)
    five_mins_ago = now - timedelta(minutes=5)
    
    # We query for Submitted complaints
    docs = db.collection('complaints').where('status', '==', 'Submitted').stream()
    
    for doc in docs:
        data = doc.to_dict()
        if not data.get('assignedTeamId'):
            # Check timestamps
            created_at = data.get('createdAt')
            if created_at:
                if isinstance(created_at, datetime):
                    created_time = created_at
                else:
                    try:
                        created_time = created_at.astimezone(timezone.utc)
                    except:
                        continue
                        
                if created_time < five_mins_ago:
                    # It's stuck!
                    complaint_id = doc.id
                    retrigger_count = data.get('_supervisor_retries', 0)
                    
                    if retrigger_count < 3:
                        log_supervisor_action('RETRIGGER_ASSIGNMENT', complaint_id, f"Scheduling Agent failed to process. Retriggering (Attempt {retrigger_count + 1}).")
                        
                        # Retrigger by forcing an update that the main agent will catch
                        db.collection('complaints').document(complaint_id).update({
                            '_supervisor_retries': retrigger_count + 1,
                            'updatedAt': firestore.SERVER_TIMESTAMP
                        })
                    elif retrigger_count == 3:
                        # Max retries reached, raise alert
                        alert_msg = f"CRITICAL: Auto-scheduling failed 3 times for issue at {data.get('address')}. Manual intervention required."
                        log_supervisor_action('MAX_RETRIES_REACHED', complaint_id, alert_msg)
                        create_admin_alert("AI Scheduling Failure", alert_msg, complaint_id)
                        
                        # Mark it so we don't keep alerting
                        db.collection('complaints').document(complaint_id).update({
                            '_supervisor_retries': 4
                        })

def check_faulty_inputs():
    """Detect complaints with missing crucial data and attempt self-correction."""
    docs = db.collection('complaints').where('status', '==', 'Submitted').stream()
    
    for doc in docs:
        data = doc.to_dict()
        complaint_id = doc.id
        
        # Check for missing location data
        if 'latitude' not in data or 'longitude' not in data:
            if not data.get('_supervisor_location_fixed'):
                log_supervisor_action('CORRECT_FAULTY_INPUT', complaint_id, "Missing GPS coordinates detected. Assigning default city center coordinates for routing fallback.")
                
                # Assign a default fallback coordinate (e.g., city center) so the routing algorithm doesn't crash
                db.collection('complaints').document(complaint_id).update({
                    'latitude': 10.7905, # Default City Center Lat
                    'longitude': 78.7047, # Default City Center Lng
                    '_supervisor_location_fixed': True,
                    'address': data.get('address', 'Unknown') + ' (Location Auto-Corrected)'
                })
                create_admin_alert("Input Auto-Corrected", f"Missing GPS for {complaint_id}. Supervisor inserted fallback coordinates.", complaint_id)

def supervisor_loop():
    print("[Supervisor Agent] Online and monitoring all sub-agents...")
    while True:
        try:
            check_stuck_assignments()
            check_faulty_inputs()
        except Exception as e:
            print(f"[Supervisor Agent] Loop error: {e}")
            
        # Run sweeps every 60 seconds
        time.sleep(60)

def start_supervisor_worker():
    thread = threading.Thread(target=supervisor_loop, daemon=True)
    thread.start()
    return thread

if __name__ == "__main__":
    supervisor_loop()
