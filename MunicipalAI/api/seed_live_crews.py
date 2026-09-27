import os
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

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

crews = [
    {
        "id": "team_alpha",
        "name": "Team Alpha",
        "skills": ["Plumbing", "Water Leakage", "General Maintenance"],
        "latitude": 11.2189, # Base coordinate (Namakkal area roughly)
        "longitude": 78.1675,
        "isOnline": True,
    },
    {
        "id": "team_beta",
        "name": "Team Beta",
        "skills": ["Electrical", "Streetlights", "Wiring"],
        "latitude": 11.2215,
        "longitude": 78.1702,
        "isOnline": True,
    },
    {
        "id": "team_gamma",
        "name": "Team Gamma",
        "skills": ["Roadwork", "Potholes", "Paving"],
        "latitude": 11.2150,
        "longitude": 78.1610,
        "isOnline": True,
    },
    {
        "id": "team_delta",
        "name": "Team Delta",
        "skills": ["Sanitation", "Waste", "Cleaning"],
        "latitude": 11.2250,
        "longitude": 78.1750,
        "isOnline": False, # Offline test
    }
]

def seed_crews():
    print("Seeding live crews into Firestore...")
    batch = db.batch()
    for crew in crews:
        doc_ref = db.collection('crews').document(crew["id"])
        batch.set(doc_ref, crew)
    
    batch.commit()
    print("Successfully seeded crews.")

if __name__ == "__main__":
    seed_crews()
