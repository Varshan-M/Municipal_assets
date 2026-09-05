"use client";

import { useEffect, useState } from "react";
import { collection, query, onSnapshot } from "firebase/firestore";
import { db } from "@/lib/firebase/config";
import { useAuth } from "@/lib/auth/AuthContext";
import { BarChart3, Users, AlertTriangle, CheckCircle2, AlertCircle, Clock, ShieldAlert, Cpu } from "lucide-react";
import { processComplaintWorkflow } from "@/ai/workflowTrigger";
import { Complaint } from "@/types";

export default function DashboardPage() {
  const { user: adminUser } = useAuth();
  const [stats, setStats] = useState({
    total: 0,
    pending: 0,
    inProgress: 0,
    resolved: 0
  });

  const [aiStats, setAiStats] = useState({
    processed: 0,
    autoAssigned: 0,
    manualReview: 0,
    highPriority: 0,
    critical: 0
  });

  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  useEffect(() => {
    const q = query(collection(db, "complaints"));
    const unsubscribe = onSnapshot(q, async (snapshot) => {
      let total = 0;
      let pending = 0;
      let inProgress = 0;
      let resolved = 0;

      let processed = 0;
      let autoAssigned = 0;
      let manualReview = 0;
      let highPriority = 0;
      let critical = 0;

      const unprocessedComplaints: Complaint[] = [];

      snapshot.forEach((doc) => {
        total++;
        const data = doc.data();
        const status = data.status || 'Submitted';
        const aiProcessed = data.aiProcessed;
        const priority = data.priority || 'LOW';

        if (status === 'Submitted') pending++;
        else if (status === 'In Progress' || status === 'Under Review' || status === 'Assigned') inProgress++;
        else if (status === 'Resolved') resolved++;

        if (aiProcessed) {
          processed++;
          if (data.aiAnalysis) {
            if (data.aiAnalysis.confidence >= 0.80 && priority !== 'CRITICAL') autoAssigned++;
            else manualReview++;
          }
          if (priority === 'HIGH') highPriority++;
          if (priority === 'CRITICAL') critical++;
        } else {
          // Push to processing queue if we have an admin user
          unprocessedComplaints.push({ id: doc.id, ...data } as Complaint);
        }
      });

      setStats({ total, pending, inProgress, resolved });
      setAiStats({ processed, autoAssigned, manualReview, highPriority, critical });
      setLoading(false);
      setErrorMsg(null);

      // Auto-trigger AI processing for any new complaints
      if (adminUser && unprocessedComplaints.length > 0) {
        for (const complaint of unprocessedComplaints) {
          try {
            await processComplaintWorkflow(complaint, adminUser.uid);
            console.log(`Processed complaint ${complaint.id} via AI Engine`);
          } catch (e) {
            console.error(`Failed to process complaint ${complaint.id}:`, e);
          }
        }
      }

    }, (error) => {
      console.error("Error fetching complaints:", error);
      if (error.code === 'permission-denied') {
        setErrorMsg("Permission Denied: Your account does not have Admin access to view complaints. Please ensure your User UID is added to the 'admins' collection in Firestore.");
      } else {
        setErrorMsg("Failed to load dashboard data.");
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, [adminUser]);

  if (loading) {
    return <div className="p-12 text-center text-text-muted">Loading dashboard data...</div>;
  }

  if (errorMsg) {
    return (
      <div className="p-8">
        <div className="bg-red-50 border border-red-200 rounded-xl p-6 flex flex-col items-center justify-center text-center max-w-2xl mx-auto">
          <AlertCircle className="w-12 h-12 text-red-500 mb-4" />
          <h2 className="text-lg font-bold text-red-700 mb-2">Access Error</h2>
          <p className="text-red-600">{errorMsg}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-primary mb-2">Dashboard Overview</h1>
        <p className="text-text-muted">Welcome back. Here is the current status of all municipal complaints.</p>
      </div>

      {/* Main Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard 
          title="Total Reports" 
          value={stats.total} 
          icon={<BarChart3 className="w-6 h-6 text-blue-500" />} 
          trend="+12% from last month"
        />
        <StatCard 
          title="Pending / Submitted" 
          value={stats.pending} 
          icon={<AlertTriangle className="w-6 h-6 text-amber-500" />} 
          trend="Requires attention"
        />
        <StatCard 
          title="In Progress" 
          value={stats.inProgress} 
          icon={<Clock className="w-6 h-6 text-purple-500" />} 
          trend="Active resolutions"
        />
        <StatCard 
          title="Resolved" 
          value={stats.resolved} 
          icon={<CheckCircle2 className="w-6 h-6 text-green-500" />} 
          trend="Successfully closed"
        />
      </div>

      {/* AI Triage Stats */}
      <div className="mt-8">
        <h2 className="text-xl font-bold text-primary mb-4 flex items-center">
          <Cpu className="w-6 h-6 mr-2 text-blue-500" />
          AI Triage & Automation Engine
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-4">
          <AiStatCard title="Processed" value={aiStats.processed} color="bg-blue-50 text-blue-700 border-blue-200" />
          <AiStatCard title="Auto Assigned" value={aiStats.autoAssigned} color="bg-green-50 text-green-700 border-green-200" />
          <AiStatCard title="Manual Review" value={aiStats.manualReview} color="bg-amber-50 text-amber-700 border-amber-200" />
          <AiStatCard title="High Priority" value={aiStats.highPriority} color="bg-orange-50 text-orange-700 border-orange-200" />
          <AiStatCard title="Critical Safety" value={aiStats.critical} color="bg-red-50 text-red-700 border-red-200 font-bold" />
        </div>
      </div>
    </div>
  );
}

function StatCard({ title, value, icon, trend }: { title: string, value: number, icon: React.ReactNode, trend: string }) {
  return (
    <div className="bg-surface p-6 rounded-xl shadow-sm border border-gray-100 flex flex-col hover:shadow-md transition-shadow">
      <div className="flex justify-between items-start mb-4">
        <div className="p-3 bg-gray-50 rounded-lg">
          {icon}
        </div>
      </div>
      <div>
        <p className="text-sm font-medium text-text-muted mb-1">{title}</p>
        <h3 className="text-3xl font-bold text-text mb-2">{value}</h3>
        <p className="text-xs text-text-muted">{trend}</p>
      </div>
    </div>
  );
}

function AiStatCard({ title, value, color }: { title: string, value: number, color: string }) {
  return (
    <div className={`p-4 rounded-xl shadow-sm border ${color} flex flex-col items-center justify-center text-center`}>
      <h3 className="text-2xl font-bold mb-1">{value}</h3>
      <p className="text-xs uppercase font-semibold tracking-wider opacity-80">{title}</p>
    </div>
  );
}
