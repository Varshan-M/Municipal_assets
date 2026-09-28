import { Timestamp } from "firebase/firestore";

export interface User {
  id: string; // Firebase Auth UID
  firstName: string;
  lastName: string;
  email: string;
  phoneNumber?: string;
  phoneVerified?: boolean;
  role?: string;
  teamId?: string;
  createdAt: Timestamp;
}

export interface Complaint {
  id: string; // Document ID
  userId: string;
  assetType: string;
  issueType: string;
  description: string;
  imageUrl?: string; // Base64 string or URL
  resolutionImageUrl?: string; // Image uploaded when resolved
  barricadeImageUrl?: string; // Temporary safety barricade image
  latitude: number;
  longitude: number;
  address: string;
  status: 'Submitted' | 'Under Review' | 'Verified' | 'Assigned' | 'In Progress' | 'Team Assigned' | 'Work In Progress' | 'Resolved' | 'Rejected' | 'Closed';
  citizenPriority?: string;
  priority?: 'Low' | 'Medium' | 'High' | 'Critical' | 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  department?: string;
  assignedDepartment?: string;
  assignedTeam?: string;
  assignedTeamId?: string;
  assignedOfficerId?: string;
  createdAt: Timestamp;
  updatedAt?: Timestamp;
  
  // Future AI integration fields
  aiAnalysis?: {
    department: string;
    priority: string;
    recommendedTeam: string | null;
    estimatedResolutionHours: number;
    recommendedAction: string;
    reasoning: string;
    confidence: number;
    analyzedAt: Timestamp;
  };
  
  // AI Scheduling Agent Fields
  schedulingStatus?: 'Scheduled' | 'Unscheduled';
  scheduledDate?: string;
  scheduledStartTime?: string;
  expectedCompletionTime?: string;
  travelDistance?: number;
  estimatedTravelTime?: number;
  requiredSkill?: string;
  estimatedRepairDuration?: number;
  aiPriorityLevel?: string;
  aiPriorityReason?: string;
  slaHours?: number;
  
  aiProcessed?: boolean;
  aiOverridden?: boolean;
}

export interface TimelineEntry {
  id: string;
  status: string;
  message: string;
  timestamp: Timestamp;
  updatedBy?: string;
  updatedByName?: string;
  source?: "AI" | "ADMIN" | "CITIZEN";
}

export interface Team {
  id: string;
  name: string;
  skills: string[];
  isOnline: boolean;
  latitude: number;
  longitude: number;
  lastUpdated?: Timestamp;
}
