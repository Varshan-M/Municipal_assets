import os
import time
import threading
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore
import google.generativeai as genai
import uuid
import math
import json

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

def evaluate_rating_reopen(rating_val, comment):
    if float(rating_val) > 2 or not str(comment).strip():
        return False
        
    prompt = f"""
    You are a Quality Assurance AI for a municipal maintenance team.
    A citizen gave a rating of {rating_val}/5 stars with the following comment:
    "{comment}"
    
    Determine if the citizen is stating that the work was NOT done, incomplete, or completely unsatisfactory, meaning the team needs to go back and fix it.
    Return ONLY "YES" if the task should be reopened and reassigned to the team.
    Return ONLY "NO" if the task is fine to remain closed (e.g. they are just mildly annoyed but it's done).
    """
    try:
        response = model.generate_content(prompt)
        text = response.text.strip().upper()
        return "YES" in text
    except Exception as e:
        print(f"Error evaluating rating with Gemini: {e}")
        # Fallback if we hit API Rate Limits during testing
        lower_comment = comment.lower()
        if "not done" in lower_comment or "nothing" in lower_comment or "didn't do" in lower_comment or "did not" in lower_comment:
            return True
        return False

def calculate_distance(lat1, lon1, lat2, lon2):
    R = 6371  # Earth radius in km
    dLat = math.radians(lat2 - lat1)
    dLon = math.radians(lon2 - lon1)
    a = (math.sin(dLat/2) * math.sin(dLat/2) +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * 
         math.sin(dLon/2) * math.sin(dLon/2))
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

def evaluate_priority(asset_type, issue_type, description, address, citizen_priority):
    prompt = f"""
    You are an AI Priority Assessment Agent for a Municipal Corporation.
    Evaluate the following reported issue and determine its objective priority level.
    
    Issue Details:
    - Asset Type: {asset_type}
    - Issue Type: {issue_type}
    - Description: {description}
    - Location: {address}
    - Citizen's Requested Priority: {citizen_priority}
    
    Rules for prioritization (Simple ranking factors):
    1. Problem Severity - e.g., pothole size, water leakage intensity, drainage blockage, etc.
    2. Location Importance - e.g., main road > residential street; school/hospital/bus stand areas get higher priority.
    3. Safety Impact - e.g., accident risk, electrical danger, flooding, etc.
    4. People Affected - e.g., number of citizens/vehicles likely to be impacted.
    5. Urgency - e.g., immediate hazard > normal maintenance.
    
    Examples:
    - Pothole A: Small pothole on a low-traffic residential street -> Low Priority (SLA: 168 hours)
    - Pothole B: Large pothole on a major road near a school -> Critical Priority (SLA: 4 hours)
    
    Standard SLA Hours based on Level:
    - Critical: 4
    - High: 24
    - Medium: 72
    - Low: 168
    
    Return your evaluation strictly as a JSON object with these keys:
    "level": (Must be one of "Critical", "High", "Medium", "Low")
    "reason": (A 1-sentence explanation of why this priority was chosen)
    "sla_hours": (Integer number of hours)
    """
    
    try:
        # Prompting gemini to return JSON
        response = model.generate_content(prompt)
        text = response.text.replace("```json", "").replace("```", "").strip()
        result = json.loads(text)
        
        # Validate output
        valid_levels = ["Critical", "High", "Medium", "Low"]
        if result.get("level") not in valid_levels:
            result["level"] = "Medium"
            
        return result
    except Exception as e:
        print(f"Error evaluating priority with Gemini: {e}")
        return {"level": "Medium", "reason": "Standard priority assigned automatically due to high traffic.", "sla_hours": 72}

def generate_crew_assignment(asset_type, issue_type, address, complaint_lat, complaint_lng, priority_level, sla_hours):
    # Fetch live crews and calculate their current active workloads
    try:
        crews_ref = db.collection('crews').stream()
        crew_list_text = ""
        crew_map = {}
        
        for crew in crews_ref:
            data = crew.to_dict()
            # TEMPORARILY DISABLED FOR SINGLE-DEVICE TESTING:
            # if not data.get('isOnline'):
            #     continue
                
            crew_name = data.get('name', crew.id)
            crew_map[crew_name] = crew.id
            skills = ", ".join(data.get('skills', []))
            crew_lat = data.get('latitude')
            crew_lng = data.get('longitude')
            
            # Count active tasks for this crew
            active_tasks = 0
            tasks_ref = db.collection('complaints').where('assignedTeamId', '==', crew.id).where('status', 'in', ['Team Assigned', 'In Progress']).stream()
            active_tasks = len(list(tasks_ref))
            
            if crew_lat is not None and crew_lng is not None and complaint_lat is not None and complaint_lng is not None:
                dist = calculate_distance(complaint_lat, complaint_lng, crew_lat, crew_lng)
                crew_list_text += f"- {crew_name} (Skills: {skills}) | Distance: {dist:.1f} km | Active Tasks: {active_tasks}\n"
            else:
                crew_list_text += f"- {crew_name} (Skills: {skills}) | Distance: Unknown | Active Tasks: {active_tasks}\n"
                
        if not crew_list_text:
            return None, "Pending Manual Assignment"
    except Exception as e:
        print(f"Error fetching live crews: {e}")
        return None, "Pending Manual Assignment"

    prompt = f"""
    You are an Intelligent Workforce Scheduling Agent.
    A new complaint has been prioritized and needs to be assigned to the most appropriate crew.
    
    Issue Details:
    - Priority Level: {priority_level} (SLA Deadline: {sla_hours} hours)
    - Asset Type: {asset_type}
    - Issue Type: {issue_type}
    - Location: {address}
    
    Available Teams (Live Workload & Location):
    {crew_list_text}
    
    Analyze the issue and assign the best team. 
    Crucial Logic: You must balance the workload. Do NOT assign to a team if they have many active tasks compared to others, even if they are slightly closer. Prioritize skills first, workload second, distance third.
    
    Return ONLY the exact name of the assigned team. No other text.
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
                user_id = data.get('userId')
                
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
                    print(f"    - Successfully processed and updated timeline for {complaint_id}")
                    
                    if user_id:
                        from firebase_admin import messaging
                        try:
                            msg = messaging.Message(
                                notification=messaging.Notification(
                                    title='Issue Resolved!',
                                    body=f'Your reported {asset_type} issue has been resolved. Thank you!'
                                ),
                                data={'complaintId': complaint_id},
                                android=messaging.AndroidConfig(
                                    priority='high',
                                    notification=messaging.AndroidNotification(
                                        sound='default'
                                    )
                                ),
                                topic=f'user_{user_id}'
                            )
                            messaging.send(msg)
                            print(f"    - Successfully sent FCM Push Notification to citizen topic: user_{user_id}\n")
                        except Exception as e:
                            print(f"    - Error sending FCM Push Notification to citizen: {e}\n")
                            
                        # Write to Firestore collection for in-app display
                        try:
                            db.collection('notifications').document().set({
                                'userId': user_id,
                                'title': 'Issue Resolved!',
                                'body': f'Your reported {asset_type} issue has been resolved. Thank you!',
                                'createdAt': firestore.SERVER_TIMESTAMP,
                                'read': False,
                                'complaintId': complaint_id
                            })
                        except Exception as e:
                            print(f"    - Error writing to notifications collection: {e}\n")
                    else:
                        print("\n")
                    
                except Exception as e:
                    print(f"    - Error updating Firestore for {complaint_id}: {e}\n")

            # Check if rating was just submitted
            if data.get('rating') is not None and not data.get('agent_rating_notified'):
                assigned_team_id = data.get('assignedTeamId')
                if assigned_team_id:
                    rating_val = data.get('rating')
                    comment = data.get('ratingComment', '')
                    complaint_id = doc.id
                    
                    print(f"[*] Detected new rating for complaint: {complaint_id}")
                    
                    # AI Rating Agent: Check if we need to reopen the issue
                    should_reopen = evaluate_rating_reopen(rating_val, comment)
                    
                    try:
                        from firebase_admin import messaging
                        
                        if should_reopen:
                            print(f"    - AI decided to REOPEN complaint {complaint_id} due to negative feedback.")
                            
                            # 1. Update Complaint Status & clear rating
                            db.collection('complaints').document(complaint_id).update({
                                'status': 'Team Assigned',
                                'agent_rating_notified': False, # Allow rating again later
                                'rating': firestore.DELETE_FIELD,
                                'ratingComment': firestore.DELETE_FIELD
                            })
                            
                            # 2. Add Timeline Entry
                            timeline_ref = db.collection('complaints').document(complaint_id).collection('timeline')
                            timeline_id = str(uuid.uuid4())
                            timeline_ref.document(timeline_id).set({
                                'id': timeline_id,
                                'status': 'Reopened',
                                'message': f'AI Quality Agent: The citizen reported that the work was incomplete or unsatisfactory ("{comment}"). This task has been automatically reopened and reassigned to you.',
                                'timestamp': firestore.SERVER_TIMESTAMP,
                                'updatedBy': 'AI_Quality_Agent',
                                'isAiGenerated': True
                            })
                            
                            # 3. Send Push Notification to Team
                            msg = messaging.Message(
                                notification=messaging.Notification(
                                    title='Task Reopened! ⚠️',
                                    body=f'Citizen reported work as incomplete. Rating: {rating_val} stars. Check timeline for details.'
                                ),
                                data={'complaintId': complaint_id},
                                android=messaging.AndroidConfig(
                                    priority='high',
                                    notification=messaging.AndroidNotification(
                                        sound='default'
                                    )
                                ),
                                topic=f'team_{assigned_team_id}'
                            )
                            messaging.send(msg)
                            
                            log_ai_action('REOPEN_TASK', complaint_id, f"Reopened due to bad rating ({rating_val}) and comment: {comment}")
                            
                        else:
                            # Standard Rating Processing
                            msg = messaging.Message(
                                notification=messaging.Notification(
                                    title=f'Got {rating_val} stars for this work! ⭐',
                                    body=f'Citizen comment: "{comment}"' if comment else 'Great job! The citizen was happy with your work.'
                                ),
                                data={'complaintId': complaint_id},
                                android=messaging.AndroidConfig(
                                    priority='high',
                                    notification=messaging.AndroidNotification(
                                        sound='default'
                                    )
                                ),
                                topic=f'team_{assigned_team_id}'
                            )
                            messaging.send(msg)
                            print(f"    - Successfully sent FCM Push Notification for Rating to team_{assigned_team_id}")
                            
                            
                            # Write to Firestore collection for in-app display
                            try:
                                db.collection('notifications').document().set({
                                    'teamId': assigned_team_id,
                                    'title': f'Got {rating_val} stars for this work! ⭐',
                                    'body': f'Citizen comment: "{comment}"' if comment else 'Great job! The citizen was happy with your work.',
                                    'createdAt': firestore.SERVER_TIMESTAMP,
                                    'read': False,
                                    'complaintId': complaint_id
                                })
                            except Exception as e:
                                print(f"    - Error writing rating to notifications collection: {e}")
                                
                            db.collection('complaints').document(complaint_id).update({
                                'agent_rating_notified': True
                            })
                    except Exception as e:
                        print(f"    - Error handling Rating/Reopen logic: {e}")

            # Check if status is Submitted and needs Priority or Assignment
            elif data.get('status') == 'Submitted' and not data.get('assignedTeamId'):
                if not auto_assign:
                    print(f"[*] Skipping processing for {doc.id} (AI Auto-Assign is disabled)")
                    continue
                    
                complaint_id = doc.id
                asset_type = data.get('assetType', 'Unknown Asset')
                issue_type = data.get('issueType', 'Unknown Issue')
                description = data.get('description', '')
                address = data.get('address', 'Unknown Location')
                citizen_priority = data.get('citizenPriority', 'Normal')
                complaint_lat = data.get('latitude')
                complaint_lng = data.get('longitude')
                
                # --- PHASE 1: Priority Agent ---
                priority_level = data.get('aiPriorityLevel')
                priority_reason = data.get('aiPriorityReason')
                sla_hours = data.get('slaHours', 72)
                
                if not priority_level:
                    print(f"[*] Analyzing Priority for newly submitted complaint: {complaint_id}")
                    eval_result = evaluate_priority(asset_type, issue_type, description, address, citizen_priority)
                    
                    priority_level = eval_result.get("level", "Medium")
                    priority_reason = eval_result.get("reason", "Standard priority assigned.")
                    sla_hours = eval_result.get("sla_hours", 72)
                    
                    print(f"    - Assigned Priority: {priority_level} (SLA: {sla_hours}h) | Reason: {priority_reason}")
                    
                    # Store priority to be updated at the end
                    log_ai_action('PRIORITY_ASSESSMENT', complaint_id, f"Evaluated as {priority_level} Priority. Reason: {priority_reason}")
                
                # --- PHASE 2: Intelligent Scheduling Agent ---
                print(f"    - Running Intelligent Scheduling Agent for {complaint_id}...")
                assigned_team_id, assigned_team_name = generate_crew_assignment(
                    asset_type, issue_type, address, complaint_lat, complaint_lng, priority_level, sla_hours
                )
                
                if not assigned_team_id:
                    print(f"    - No teams available to schedule.")
                    continue
                    
                print(f"    - Scheduled to Team: {assigned_team_name} (ID: {assigned_team_id})")
                
                # Update Firestore with assignment
                try:
                    # 1. Add to timeline
                    timeline_ref = db.collection('complaints').document(complaint_id).collection('timeline')
                    timeline_id = str(uuid.uuid4())
                    
                    timeline_message = f"AI Priority Assessment: {priority_level} (SLA: {sla_hours}h). Issue has been intelligently scheduled to {assigned_team_name} based on workload and proximity."
                    
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
                    
                    log_ai_action('SMART_SCHEDULE', complaint_id, f"Intelligently scheduled to {assigned_team_name}.")
                    print(f"    - Successfully scheduled {assigned_team_name} and updated timeline for {complaint_id}")
                    
                    from firebase_admin import messaging
                    try:
                        message = messaging.Message(
                            notification=messaging.Notification(
                                title='New Task Assigned!',
                                body=f'{asset_type} at {address}\nPriority: {priority_level}'
                            ),
                            data={'complaintId': complaint_id},
                            android=messaging.AndroidConfig(
                                priority='high',
                                notification=messaging.AndroidNotification(
                                    sound='default'
                                )
                            ),
                            topic=f'team_{assigned_team_id}'
                        )
                        messaging.send(message)
                        print(f"    - Successfully sent FCM Push Notification to topic: team_{assigned_team_id}\n")

                        # Send notification to the citizen
                        user_id = data.get('userId')
                        if user_id:
                            citizen_msg = messaging.Message(
                                notification=messaging.Notification(
                                    title='Team Assigned!',
                                    body=f'Your {asset_type} issue has been reviewed and assigned to {assigned_team_name}.'
                                ),
                                data={'complaintId': complaint_id},
                                android=messaging.AndroidConfig(
                                    priority='high',
                                    notification=messaging.AndroidNotification(
                                        sound='default'
                                    )
                                ),
                                topic=f'user_{user_id}'
                            )
                            messaging.send(citizen_msg)
                            print(f"    - Successfully sent FCM Push Notification to citizen topic: user_{user_id}\n")

                    except Exception as e:
                        print(f"    - Error sending FCM Push Notification: {e}\n")
                    
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
