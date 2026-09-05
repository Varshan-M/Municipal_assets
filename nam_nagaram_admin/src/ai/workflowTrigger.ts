import { db } from "@/lib/firebase/config";
import { doc, writeBatch, collection, serverTimestamp } from "firebase/firestore";
import { Complaint } from "@/types";
import { aiEngine } from "./complaintAnalyzer";

/**
 * For V1, this is called from the Admin Dashboard.
 * For V2, this exact function body can be moved to a Firebase Cloud Function (onDocumentCreated)
 * by simply replacing 'db' with 'admin.firestore()'.
 */
export async function processComplaintWorkflow(complaint: Complaint, adminUid: string) {
  if (complaint.aiProcessed) return null; // Prevent double processing

  const analysis = await aiEngine.analyzeComplaint(complaint);
  
  const batch = writeBatch(db);
  const complaintRef = doc(db, "complaints", complaint.id);
  
  let newStatus = "Submitted";
  let finalAssignedTeam = null;

  // Confidence-based workflow routing
  if (analysis.confidence >= 0.80) {
    newStatus = "Assigned";
    finalAssignedTeam = analysis.recommendedTeam;
  } else {
    // Both <60% (manual review) and 60-79% (department routing only) get Under Review
    newStatus = "Under Review";
  }

  // Safety critical override
  if (analysis.priority === 'CRITICAL') {
    newStatus = "Under Review";
    finalAssignedTeam = null;
  }

  batch.update(complaintRef, {
    aiAnalysis: analysis,
    aiProcessed: true,
    aiOverridden: false,
    status: newStatus,
    department: analysis.department,
    priority: analysis.priority,
    assignedTeam: finalAssignedTeam,
    estimatedResolutionHours: analysis.estimatedResolutionHours,
    updatedAt: serverTimestamp()
  });

  const timelineRef = doc(collection(db, "complaints", complaint.id, "timeline"));
  
  let timelineMessage = `AI analysis mapped this to ${analysis.department}. Priority: ${analysis.priority}.`;
  if (newStatus === "Assigned") {
    timelineMessage += ` Automatically assigned to ${finalAssignedTeam} based on high confidence (${(analysis.confidence * 100).toFixed(0)}%).`;
  } else if (analysis.priority === 'CRITICAL') {
    timelineMessage += ` Manual review required due to CRITICAL safety hazard.`;
  } else if (analysis.confidence < 0.6) {
    timelineMessage += ` Manual review required due to low AI confidence (${(analysis.confidence * 100).toFixed(0)}%).`;
  } else {
    timelineMessage += ` Pending manual assignment.`;
  }

  batch.set(timelineRef, {
    status: newStatus,
    message: timelineMessage,
    timestamp: serverTimestamp(),
    source: "AI",
    updatedBy: adminUid,
    updatedByName: "AI Triage System"
  });

  await batch.commit();
  return analysis;
}
