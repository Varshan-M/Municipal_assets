import { Complaint } from "@/types";

export function classifyDepartmentAndTeam(complaint: Complaint): {
  department: string;
  recommendedTeam: string | null;
  confidence: number;
} {
  const text = `${complaint.assetType} ${complaint.issueType} ${complaint.description}`.toLowerCase();
  
  if (text.includes("road") || text.includes("pothole") || text.includes("pavement")) {
    return {
      department: "Roads Department",
      recommendedTeam: "Road Maintenance Team A",
      confidence: 0.92
    };
  }
  
  if (text.includes("electric") || text.includes("light") || text.includes("wire") || text.includes("pole")) {
    return {
      department: "Electrical Department",
      recommendedTeam: "Electrical Maintenance Team B",
      confidence: 0.94
    };
  }

  if (text.includes("garbage") || text.includes("waste") || text.includes("sanitation") || text.includes("litter") || text.includes("bin")) {
    return {
      department: "Sanitation Department",
      recommendedTeam: "Sanitation Team A",
      confidence: 0.89
    };
  }

  if (text.includes("water") || text.includes("leak") || text.includes("pipe") || text.includes("drain")) {
    return {
      department: "Water & Sewage Department",
      recommendedTeam: "Plumbing Unit 1",
      confidence: 0.90
    };
  }

  return {
    department: "General Administration",
    recommendedTeam: null, // Requires manual routing
    confidence: 0.45
  };
}
