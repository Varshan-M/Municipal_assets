import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate('firebase-service-account.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

docs = db.collection('complaints').order_by('createdAt', direction=firestore.Query.DESCENDING).limit(5).stream()
for doc in docs:
    data = doc.to_dict()
    print(f"{doc.id}: {data.get('status')} | {data.get('assetType')} | {data.get('issueType')} | Lat: {data.get('latitude')} | Lng: {data.get('longitude')}")
