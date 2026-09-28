import os
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore

# Setup Firebase
API_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(API_DIR, '.env'))

CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json")
if not os.path.isabs(CREDENTIALS_PATH):
    CREDENTIALS_PATH = os.path.join(API_DIR, CREDENTIALS_PATH)

if not firebase_admin._apps:
    cred = credentials.Certificate(CREDENTIALS_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("--- Injecting Supervisor Test Data ---")

# Test Case 1: Missing GPS Data (Faulty Input Correction)
doc1_ref = db.collection('complaints').document('test_faulty_input')
doc1_ref.set({
    'status': 'Submitted',
    'assetType': 'Road',
    'issueType': 'Pothole',
    'address': '123 Fake Street',
    'description': 'Supervisor Test - Missing GPS Data',
    # Notice we are INTENTIONALLY leaving out 'latitude' and 'longitude'
    'createdAt': firestore.SERVER_TIMESTAMP,
    'updatedAt': firestore.SERVER_TIMESTAMP,
})
print("1. Injected 'test_faulty_input' (Missing GPS data). Supervisor should auto-correct this within 60 seconds.")

# Test Case 2: Stuck Process (Simulating an AI Failure 10 minutes ago)
doc2_ref = db.collection('complaints').document('test_stuck_process')
doc2_ref.set({
    'status': 'Submitted',
    'assetType': 'Street Light',
    'issueType': 'Not Working',
    'address': '456 Stuck Ave',
    'description': 'Supervisor Test - Stuck for 10 minutes',
    'latitude': 10.7905,
    'longitude': 78.7047,
    # Simulate that this was created 10 minutes ago and got stuck
    'createdAt': datetime.now(timezone.utc) - timedelta(minutes=10),
    'updatedAt': datetime.now(timezone.utc) - timedelta(minutes=10),
})
print("2. Injected 'test_stuck_process' (Stuck for 10 mins). Supervisor should detect it and re-trigger it.")

print("---------------------------------------")
print("Data injected successfully! Now run `python main.py` or `python supervisor_agent.py` directly to see the Supervisor in action.")
