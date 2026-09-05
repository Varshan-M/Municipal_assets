import { Complaint } from "@/types";
import { AIAnalysisResult, AIProvider } from "./aiTypes";
import { predictPriority } from "./priorityEngine";
import { classifyDepartmentAndTeam } from "./teamAssignment";

export class RuleBasedAIProvider implements AIProvider {
  async analyzeComplaint(complaint: Complaint): Promise<AIAnalysisResult> {
    // 1. Determine priority
    const priorityResult = predictPriority(complaint);
    
    // 2. Determine department and team
    const routingResult = classifyDepartmentAndTeam(complaint);

    // 3. Estimate resolution time based on priority and department
    let estimatedResolutionHours = 48;
    if (priorityResult.priority === 'CRITICAL') estimatedResolutionHours = 4;
    else if (priorityResult.priority === 'HIGH') estimatedResolutionHours = 24;
    else if (priorityResult.priority === 'LOW') estimatedResolutionHours = 120; // 5 days

    if (routingResult.department === 'Electrical Department' && priorityResult.priority === 'HIGH') {
      estimatedResolutionHours = 12; // Electricity is prioritized
    }

    // 4. Calculate an overall confidence score
    const overallConfidence = (priorityResult.confidence + routingResult.confidence) / 2;

    // 5. Generate recommended action
    let recommendedAction = `Inspect and repair ${complaint.issueType.toLowerCase()} as soon as possible.`;
    if (priorityResult.priority === 'CRITICAL') {
      recommendedAction = `Immediate dispatch required. Potential safety hazard reported regarding: ${complaint.issueType}.`;
    } else if (routingResult.confidence < 0.6) {
      recommendedAction = `Manual review required. The system could not confidently determine the correct department for this issue.`;
    }

    // Combine reasoning
    let fullReasoning = routingResult.confidence > 0.6 
      ? `Based on the keywords in the complaint, it was mapped to the ${routingResult.department}. ` 
      : `The complaint description was too ambiguous to map to a specific department. `;
    
    fullReasoning += priorityResult.reasoning;

    return {
      department: routingResult.department,
      priority: priorityResult.priority,
      recommendedTeam: routingResult.recommendedTeam,
      estimatedResolutionHours,
      recommendedAction,
      reasoning: fullReasoning,
      confidence: Number(overallConfidence.toFixed(2)) // E.g., 0.91
    };
  }
}

// Export a singleton instance for easy usage
export const aiEngine = new RuleBasedAIProvider();
