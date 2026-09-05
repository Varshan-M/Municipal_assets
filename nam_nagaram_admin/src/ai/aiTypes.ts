import { Complaint } from "@/types";

export interface AIAnalysisResult {
  department: string;
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  recommendedTeam: string | null;
  estimatedResolutionHours: number;
  recommendedAction: string;
  reasoning: string;
  confidence: number;
}

export interface AIProvider {
  analyzeComplaint: (complaint: Complaint) => Promise<AIAnalysisResult>;
}
