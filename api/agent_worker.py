import os
import time
import threading
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore
import google.generativeai as genai
import uuid
import math

# Get the absolute path to the api directory
API_DIR = os.path.dirname(os.path.abspath(__file__))

# Load environment variables from api/.env
load_dotenv(os.path.join(API_DIR, '.env'))

# Configure Gemini
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    raise ValueError("GEMINI_API_KEY not found in .env file")
genai.configure(api_key=GEMINI_API_KEY)
# Using the latest Gemini Flash model for fast generation
model = genai.GenerativeModel('gemini-flash-latest')

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

def generate_followup_message(asset_type, issue_type, description, address):
    prompt = f"""
    You are a friendly and professional customer service agent for a Municipal Corporation.
    A citizen previously reported a municipal issue, and it has just been resolved by our maintenance team.
    
    Issue Details:
    - Asset Type: {asset_type}
    - Issue Type: {issue_type}
    - Description given by citizen: {description}
    - Location: {address}
    
    Draft a short, polite, and personalized follow-up message to the citizen letting them know that the issue has been successfully resolved. 
    Thank them for their report and for helping keep the city safe and clean.
    Keep the tone appreciative and helpful. Limit to 2-3 short paragraphs. No subject line.
    """
    
    try:
        response = model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        print(f"Error generating message with Gemini: {e}")
        return "Your reported issue has been successfully resolved. Thank you for your contribution to our community!"

def calculate_distance(lat1, lon1, lat2, lon2):
    R = 6371  # Earth radius in km
    dLat = math.radians(lat2 - lat1)
    dLon = math.radians(lon2 - lon1)
    a = (math.sin(dLat/2) * math.sin(dLat/2) +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * 
         math.sin(dLon/2) * math.sin(dLon/2))
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

def generate_crew_assignment(asset_type, issue_type, address, complaint_lat, complaint_lng):
    # Fetch live crews from Firestore
    try:
        crews_ref = db.collection('crews').where('isOnline', '==', True).stream()
        crew_list_text = ""
        crew_map = {} # Maps name to document ID
        
        for crew in crews_ref:
            data = crew.to_dict()
            crew_name = data.get('name', crew.id)
            crew_map[crew_name] = crew.id
            skills = ", ".join(data.get('skills', []))
            crew_lat = data.get('latitude')
            crew_lng = data.get('longitude')
            
            if crew_lat is not None and crew_lng is not None and complaint_lat is not None and complaint_lng is not None:
                dist = calculate_distance(complaint_lat, complaint_lng, crew_lat, crew_lng)
                crew_list_text += f"- {crew_name} ({skills}): {dist:.1f} km away\n"
            else:
                crew_list_text += f"- {crew_name} ({skills}): Unknown distance\n"
                
        if not crew_list_text:
            return None, "Pending Manual Assignment"
    except Exception as e:
        print(f"Error fetching live crews: {e}")
        return None, "Pending Manual Assignment"

    prompt = f"""
    You are an AI Workforce Assignment Agent for a Municipal Corporation.
    A new complaint has been verified and needs to be assigned to the most appropriate crew.
    
    Issue Details:
    - Asset Type: {asset_type}
    - Issue Type: {issue_type}
    - Location: {address}
    
    Available Teams (Live Locations):
    {crew_list_text}
    
    Analyze the issue and assign the best team based on required skills and distance.
    Return ONLY the name of the assigned team. No other text.
    """
    
    try:
        response = model.generate_content(prompt)
        assigned_team = response.text.strip()
        
        # Fallback just in case Gemini gets chatty
        for name, doc_id in crew_map.items():
            if name.lower() in assigned_team.lower():
                return doc_id, name
                
        # If perfect match fails, just return the first available
        first_name = list(crew_map.keys())[0] if crew_map else "Pending Manual Assignment"
        first_id = crew_map[first_name] if crew_map else None
        return first_id, first_name
    except Exception as e:
        print(f"Error assigning team with Gemini: {e}")
        first_name = list(crew_map.keys())[0] if crew_map else "Pending Manual Assignment"
        first_id = crew_map[first_name] if crew_map else None
        return first_id, first_name

def log_ai_action(action_type, target_id, message):
    try:
        db.collection('ai_logs').add({
            'actionType': action_type,
            'targetId': target_id,
            'message': message,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
    except Exception as e:
        print(f"Error writing to ai_logs: {e}")

def get_ai_config():
    try:
        doc = db.collection('settings').document('ai_config').get()
        if doc.exists:
            return doc.to_dict()
        return {'auto_assign_enabled': True, 'auto_followup_enabled': True}
    except Exception as e:
        print(f"Error fetching AI config: {e}")
        return {'auto_assign_enabled': True, 'auto_followup_enabled': True}

def on_snapshot(doc_snapshot, changes, read_time):
    config = get_ai_config()
    auto_assign = config.get('auto_assign_enabled', True)
    auto_followup = config.get('auto_followup_enabled', True)

    for change in changes:
        if change.type.name in ['ADDED', 'MODIFIED']:
            doc = change.document
            data = doc.to_dict()
            
            # Check if status is Resolved and we haven't sent a follow up yet
            if data.get('status') == 'Resolved' and not data.get('agent_followup_sent'):
                if not auto_followup:
                    print(f"[*] Skipping follow-up for {doc.id} (AI Follow-up is disabled)")
                    continue

                complaint_id = doc.id
                print(f"[*] Detected newly resolved complaint: {complaint_id}")
                
                asset_type = data.get('assetType', 'Unknown Asset')
                issue_type = data.get('issueType', 'Unknown Issue')
                description = data.get('description', '')
                address = data.get('address', 'Unknown Location')
                
                # Generate message using Gemini
                print(f"    - Drafting message using Gemini...")
                message = generate_followup_message(asset_type, issue_type, description, address)
                print(f"    - Drafted Message: {message[:100]}...")
                
                # Update Firestore
                try:
                    # 1. Add to timeline
                    timeline_ref = db.collection('complaints').document(complaint_id).collection('timeline')
                    timeline_id = str(uuid.uuid4())
                    
                    timeline_ref.document(timeline_id).set({
                        'id': timeline_id,
                        'status': 'Resolved',
                        'message': message,
                        'timestamp': firestore.SERVER_TIMESTAMP,
                        'updatedBy': 'AI_Agent',
                        'isAiGenerated': True
                    })
                    
                    # 2. Update complaint flag
                    db.collection('complaints').document(complaint_id).update({
                        'agent_followup_sent': True
                    })
                    
                    log_ai_action('FOLLOW_UP', complaint_id, f"Generated and sent follow-up message to citizen.")
                    print(f"    - Successfully processed and updated timeline for {complaint_id}\n")
                    
                except Exception as e:
                    print(f"    - Error updating Firestore for {complaint_id}: {e}\n")

            # Check if status is Submitted and no team is assigned yet
            elif data.get('status') == 'Submitted' and not data.get('assignedTeamId'):
                if not auto_assign:
                    print(f"[*] Skipping assignment for {doc.id} (AI Auto-Assign is disabled)")
                    continue
                    
                complaint_id = doc.id
                print(f"[*] Detected submitted complaint needing assignment: {complaint_id}")
                
                asset_type = data.get('assetType', 'Unknown Asset')
                issue_type = data.get('issueType', 'Unknown Issue')
                address = data.get('address', 'Unknown Location')
                complaint_lat = data.get('latitude')
                complaint_lng = data.get('longitude')
                
                print(f"    - Analyzing real-time team data and issue requirements using Gemini...")
                assigned_team_id, assigned_team_name = generate_crew_assignment(asset_type, issue_type, address, complaint_lat, complaint_lng)
                
                if not assigned_team_id:
                    print(f"    - No teams available to assign.")
                    continue
                    
                print(f"    - Assigned Team: {assigned_team_name} (ID: {assigned_team_id})")
                
                # Update Firestore with assignment
                try:
                    # 1. Add to timeline
                    timeline_ref = db.collection('complaints').document(complaint_id).collection('timeline')
                    timeline_id = str(uuid.uuid4())
                    
                    timeline_message = f"Issue has been automatically verified and assigned to {assigned_team_name} based on real-time location and skill requirements."
                    
                    timeline_ref.document(timeline_id).set({
                        'id': timeline_id,
                        'status': 'Team Assigned',
                        'message': timeline_message,
                        'timestamp': firestore.SERVER_TIMESTAMP,
                        'updatedBy': 'AI_Workforce_Agent',
                        'isAiGenerated': True
                    })
                    
                    # 2. Update complaint status and team
                    db.collection('complaints').document(complaint_id).update({
                        'status': 'Team Assigned',
                        'assignedTeamId': assigned_team_id,
                        'assignedTeamName': assigned_team_name
                    })
                    
                    log_ai_action('AUTO_ASSIGN', complaint_id, f"Automatically verified and assigned to {assigned_team_name}.")
                    print(f"    - Successfully assigned {assigned_team_name} and updated timeline for {complaint_id}\n")
                    
                except Exception as e:
                    print(f"    - Error assigning team in Firestore for {complaint_id}: {e}\n")

def start_listening():
    print("Starting Automated Follow-up Agent...")
    complaints_ref = db.collection('complaints')
    
    # Watch the collection
    doc_watch = complaints_ref.on_snapshot(on_snapshot)
    
    try:
        print("Agent is listening for changes in Firestore. Press Ctrl+C to stop.")
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Agent stopping...")
        doc_watch.unsubscribe()

if __name__ == "__main__":
    start_listening()
