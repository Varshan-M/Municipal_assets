import os
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv
from datetime import datetime, timedelta

# Get the absolute path to the api directory
API_DIR = os.path.dirname(os.path.abspath(__file__))

# Load environment variables
load_dotenv(os.path.join(API_DIR, '.env'))

# Configure Firebase
CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json")
if not os.path.isabs(CREDENTIALS_PATH):
    CREDENTIALS_PATH = os.path.join(API_DIR, CREDENTIALS_PATH)

if not firebase_admin._apps:
    cred = credentials.Certificate(CREDENTIALS_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()

now = datetime.now()
today_str = now.strftime("%Y-%m-%d")

crews = [
    {
        "id": "team_alpha",
        "name": "Civil Works Team (Alpha)",
        "skills": ["Road", "Public Building", "Crack", "Pothole"],
        "workingHours": {"start": "08:00", "end": "18:00"},
        "latitude": 11.2189,
        "longitude": 78.1675,
        "isOnline": True,
    },
    {
        "id": "team_beta",
        "name": "Electrical Team (Beta)",
        "skills": ["Street Light", "Not Working"],
        "workingHours": {"start": "16:00", "end": "04:00"}, # Night shift
        "latitude": 11.2215,
        "longitude": 78.1702,
        "isOnline": True,
    },
    {
        "id": "team_gamma",
        "name": "Sanitation Team (Gamma)",
        "skills": ["Garbage Bin", "Overflowing", "Waste"],
        "workingHours": {"start": "06:00", "end": "14:00"},
        "latitude": 11.2150,
        "longitude": 78.1610,
        "isOnline": True,
    }
]

# Create some mock scheduled complaints for today to simulate existing workload
mock_scheduled_tasks = [
    {
        "id": "task_alpha_1",
        "assignedTeamId": "team_alpha",
        "status": "In Progress",
        "assetType": "Road",
        "issueType": "Pothole",
        "address": "Main St, Namakkal",
        "latitude": 11.2190,
        "longitude": 78.1680,
        "estimatedRepairDuration": 120,
        "scheduledDate": today_str,
        "scheduledStartTime": "09:00",
        "expectedCompletionTime": "11:00",
    },
    {
        "id": "task_alpha_2",
        "assignedTeamId": "team_alpha",
        "status": "Team Assigned",
        "assetType": "Public Building",
        "issueType": "Crack",
        "address": "Library, Namakkal",
        "latitude": 11.2195,
        "longitude": 78.1690,
        "estimatedRepairDuration": 90,
        "scheduledDate": today_str,
        "scheduledStartTime": "13:00",
        "expectedCompletionTime": "14:30",
    },
    {
        "id": "task_beta_1",
        "assignedTeamId": "team_beta",
        "status": "Team Assigned",
        "assetType": "Street Light",
        "issueType": "Not Working",
        "address": "South Ave, Namakkal",
        "latitude": 11.2220,
        "longitude": 78.1710,
        "estimatedRepairDuration": 45,
        "scheduledDate": today_str,
        "scheduledStartTime": "18:00",
        "expectedCompletionTime": "18:45",
    }
]

def seed_database():
    print("Seeding realistic crews into Firestore...")
    batch = db.batch()
    
    # 1. Seed Crews
    for crew in crews:
        doc_ref = db.collection('crews').document(crew["id"])
        batch.set(doc_ref, crew)
        
    # 2. Seed Mock Scheduled Tasks
    print("Seeding active scheduled tasks to build existing workload...")
    for task in mock_scheduled_tasks:
        doc_ref = db.collection('complaints').document(task["id"])
        batch.set(doc_ref, task)
    
    batch.commit()
    print("Successfully seeded database for Scheduling Agent testing!")

if __name__ == "__main__":
    seed_database()
