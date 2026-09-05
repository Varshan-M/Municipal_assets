import { Complaint } from "@/types";

export function predictPriority(complaint: Complaint): { 
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'; 
  confidence: number;
  reasoning: string;
} {
  const text = `${complaint.assetType} ${complaint.issueType} ${complaint.description}`.toLowerCase();
  
  // High risk keywords
  const criticalKeywords = ['live wire', 'fire', 'explosion', 'accident', 'fatal', 'death', 'collapsed', 'gas leak', 'major hazard'];
  const highKeywords = ['school', 'hospital', 'children', 'main road', 'highway', 'deep pothole', 'open manhole', 'flooding', 'no water', 'sewage leak'];
  const lowKeywords = ['garbage', 'litter', 'weeds', 'park bench', 'faded sign'];

  if (criticalKeywords.some(kw => text.includes(kw))) {
    return {
      priority: 'CRITICAL',
      confidence: 0.95,
      reasoning: "The complaint contains keywords indicating a severe public safety hazard or emergency."
    };
  }

  if (highKeywords.some(kw => text.includes(kw))) {
    return {
      priority: 'HIGH',
      confidence: 0.88,
      reasoning: "The complaint describes an issue near a sensitive location (e.g., school/hospital) or involves significant infrastructure disruption."
    };
  }

  if (lowKeywords.some(kw => text.includes(kw))) {
    return {
      priority: 'LOW',
      confidence: 0.85,
      reasoning: "The complaint describes a minor maintenance issue that does not pose an immediate risk to public safety."
    };
  }

  return {
    priority: 'MEDIUM',
    confidence: 0.75,
    reasoning: "The issue appears to be a standard municipal problem requiring routine attention."
  };
}
