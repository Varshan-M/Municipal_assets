import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

cred = credentials.Certificate('firebase-service-account.json')
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

complaints = db.collection('complaints').stream()
for c in complaints:
    data = c.to_dict()
    print(f"ID: {c.id}")
    print(f"Status: {data.get('status')}")
    print(f"Assigned Team: {data.get('assignedTeamId')}")
    print(f"Lat: {data.get('latitude')}, Lng: {data.get('longitude')}")
    print("---")
