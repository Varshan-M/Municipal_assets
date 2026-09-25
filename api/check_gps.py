import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

cred = credentials.Certificate('firebase-service-account.json')
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

crews = db.collection('crews').stream()
for crew in crews:
    data = crew.to_dict()
    print(f"Team: {data.get('name')}")
    print(f"Lat: {data.get('latitude')}, Lng: {data.get('longitude')}")
    print(f"IsOnline: {data.get('isOnline')}")
