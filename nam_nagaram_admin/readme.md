NAM NAGARAM - ADMIN WEBSITE HANDOVER DOCUMENT
This document contains the exact technical specifications and current state of the Nam Nagaram Firebase backend and Flutter citizen app. Use this as the source of truth for developing the Admin Website.

1. PROJECT OVERVIEW
Project Name: Nam Nagaram
Problem Statement: Streamlining the reporting and resolution of municipal issues (potholes, streetlights, garbage, etc.) by connecting citizens directly with the local government.
Purpose of Citizen App: Enable citizens to securely report issues with geolocation and photographic evidence, and track the resolution timeline of their complaints.
Purpose of Admin Website: Enable municipal administrators and officers to view all citizen reports, assign them to field teams, and update their statuses to reflect real-world progress.
Overall System Workflow: Citizen submits report via mobile app → Data saved to Firestore → Admin views report on Website → Admin assigns team & updates status → Admin adds timeline entry → Citizen app live-updates to reflect new status and timeline.
2. CURRENT MOBILE APP FEATURES
This reflects the exact current state of the citizen mobile app codebase.

Authentication (Email/Password): Completed
OTP (Phone auth): Partially completed (UI exists, phoneVerified field exists, but currently bypassed in mobile router)
Home Dashboard: Completed (Shows Active/Resolved stats and recent activity)
Report Issue Flow: Completed
Asset Categories: Completed
Image Handling: Completed (Images are captured, converted to Base64 strings, and saved directly to Firestore to bypass Firebase Storage)
Location/GPS: Completed (Captures lat/long and reverse geocodes to a street address)
My Reports History: Completed
Report Timeline: Completed (Reads from a Firestore subcollection)
Notifications: Partially completed (UI exists, but data is currently static/empty)
User Profile: Completed
3. FIREBASE CONFIGURATION
Use these configuration details to initialize the Firebase Web SDK in the admin website.

Firebase Project ID: municipal-assets
Enabled Firebase Services: Authentication, Cloud Firestore
Authentication Providers: Email/Password
Firestore Usage: Core database for users, complaints, and timelines.
Storage Usage: NOT USED. (Images are processed as Base64 strings).
Messaging Usage: Planned (Not currently active).
Important Requirement: The Admin Website must use the Firebase Web SDK (or Firebase Admin SDK if building a Node.js backend).
4. FIRESTORE DATABASE STRUCTURE
Critical: The admin website must conform exactly to this schema.

Collection: users
Purpose: Stores citizen profile data.
Who can read: Owner only (UID == request.auth.uid)
Who can write: Owner only
Fields:
id (String) - Firebase Auth UID
firstName (String)
lastName (String)
email (String)
phoneNumber (String)
phoneVerified (Boolean)
createdAt (Timestamp)
Collection: complaints
Purpose: Stores the actual issue reports submitted by citizens.
Who can read: Owner only (Admin rules need to be added)
Who can write: Any authenticated citizen can CREATE. UPDATE/DELETE is blocked.
Fields:
id (String) - Document ID
userId (String) - UID of the submitting citizen
assetType (String) - E.g., 'Roads', 'Streetlights'
issueType (String) - E.g., 'Pothole', 'Not working'
description (String)
image (String) - Base64 encoded string representing the image
latitude (Number/Double)
longitude (Number/Double)
address (String)
status (String) - E.g., 'Submitted', 'Resolved'
createdAt (Timestamp)
Subcollection: timeline (Path: complaints/{complaintId}/timeline)
Purpose: Tracks the historical updates of a single complaint.
Who can read: Owner of parent complaint (Admin rules need to be added)
Who can write: Currently blocked. (Admin website will need permission to write here)
Fields:
id (String)
status (String)
message (String) - E.g., 'The municipality has assigned a team.'
timestamp (Timestamp)
Collections NOT currently implemented:
teams, notifications, admins (These will need to be created by the Admin Website developer).
5. COMPLAINT / REPORT MODEL
Exact current data shape mapping to the mobile app:

json

{
  "id": "uuid-string",
  "userId": "firebase-uid",
  "assetType": "Streetlights",
  "issueType": "Bulb fused",
  "description": "The streetlight outside house #42 has been flickering and died.",
  "image": "/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAkGBx...", // Base64 string
  "latitude": 13.0827,
  "longitude": 80.2707,
  "address": "42 Main Street, Chennai",
  "status": "Submitted",
  "createdAt": "Firestore Timestamp"
}
(Note: Fields like assignedTeam, priority, and updatedAt are planned but do not currently exist in the citizen app).

6. COMPLAINT STATUS FLOW
Current statuses recognized by the mobile app:

Submitted (Default)
In Progress
Resolved
Rejected
Recommended flow for Admin Website to introduce: Submitted → Under Review → Assigned → In Progress → Resolved

7. TIMELINE STRUCTURE
The timeline is the primary way citizens track progress. It is not an array; it is a Subcollection inside the complaint document.

To add a timeline event, the Admin Website must write a document to: /complaints/{complaintId}/timeline/{newTimelineId}

json

{
  "id": "uuid-string",
  "status": "In Progress",
  "message": "A field team has been dispatched to assess the damage.",
  "timestamp": "Firestore Timestamp"
}
8. FIRESTORE SECURITY RULES
Current Conceptual Rules:

Citizens can read/write their own profile (/users/{uid}).
Citizens can create complaints but can only read complaints where resource.data.userId == request.auth.uid.
Citizens cannot update or delete complaints.
Citizens cannot write to the timeline subcollection.
Changes Required for Admin Website: The Admin Website developer MUST update the Firestore security rules to allow admin access. Recommendation: Create an admins collection. Add a rule: allow read, write: if exists(/databases/$(database)/documents/admins/$(request.auth.uid)); to all relevant collections.

9. AUTHENTICATION
Current implementation: Standard Firebase Email/Password Auth.
User Creation: Mobile app creates the Firebase Auth user, then immediately writes a corresponding document to the /users Firestore collection.
Roles: No role system is currently implemented. Every user is treated as a standard citizen.
10. ADMIN WEBSITE REQUIREMENTS
MUST HAVE:

Admin Authentication Login.
Dashboard (Statistics: Total reports, Active, Resolved).
Complaint Data Grid (Filterable by status, date, and asset category).
Complaint Detail View (Must render the Base64 image, map the coordinates, and show description).
Status Update Module (Changes the status field on the complaint AND pushes a document to the timeline subcollection).
SHOULD HAVE:

Map View (Visualize all active complaints geographically).
Team Assignment (Assign reports to specific field workers).
Citizen Database View.
FUTURE:

Analytics (Resolution timeframes, hotspot heatmaps).
Push Notifications integration.
11. ADMIN ROLES (Recommended Architecture)
Super Admin: Full system access, can create other admins.
Municipal Admin: Can view all reports across all departments, reassign teams.
Department Officer (e.g., Water, Roads): Can view and update reports only for their specific assetType.
Field Team: Mobile-friendly web view to see assigned reports and update status to 'Resolved'.
12. DATA FLOW EXAMPLE
Citizen App: Citizen takes photo, app converts it to Base64, gets GPS, and writes to /complaints collection with status 'Submitted'.
Admin Website: Admin logs in, queries /complaints, and sees the new report.
Admin Action: Admin clicks "Mark In Progress" and types a message.
Firebase Update: Admin website updates the status field on the complaint document to 'In Progress' AND creates a new document in the /complaints/{id}/timeline subcollection.
Citizen App: The citizen's app (listening via Riverpod StreamProviders) instantly updates the UI, showing the new 'In Progress' badge and the timeline message.
13. CURRENT TECH STACK (Citizen App)
Framework: Flutter (Dart)
State Management: Riverpod
Routing: GoRouter
Backend: Firebase (Auth, Firestore)
Maps/Location: geolocator, geocoding
14. RECOMMENDED WEBSITE TECH STACK
Framework: Next.js (React) or Vue.js with TailwindCSS. (Alternatively, Flutter Web could be used to easily share data models with the mobile app).
Backend: Firebase Web SDK (Serverless) or Firebase Admin SDK (if using Next.js API routes).
15. IMPORTANT INTEGRATION NOTES ⚠️
Base64 Images: Do NOT attempt to load images from Firebase Storage URLs. The image field in Firestore contains a raw Base64 string. To display it in HTML/React, format the src attribute exactly like this: <img src={\data:image/jpeg;base64,${complaint.image}`} />`
Two-Step Updates: Do not just update the status field on a complaint. You MUST also add a subcollection document to /timeline so the citizen can see why the status changed.
Security Rules: Your first task should be securing the database for Admins, otherwise, your website queries will return "Missing or insufficient permissions".
16. FINAL INTEGRATION CHECKLIST
 Admin login bypasses citizen security rules successfully.
 Website correctly queries the /complaints collection and bypasses the userId restriction.
 Website successfully decodes and renders Base64 images directly from the Firestore document.
 Website correctly updates the status field on a complaint.
 Website correctly writes new documents to the /timeline subcollection.
 Changes made on the website reflect instantly on the citizen mobile app without crashing it.