"use client";

import { useEffect, useState } from "react";
import { collection, getDocs } from "firebase/firestore";
import { db } from "@/lib/firebase/config";
import { Complaint, Team } from "@/types";
import { 
  PieChart, Pie, Cell, 
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip as RechartsTooltip, Legend, ResponsiveContainer 
} from "recharts";

export default function AnalyticsPage() {
  const [complaints, setComplaints] = useState<Complaint[]>([]);
  const [teams, setTeams] = useState<Team[]>([]);
  const [assets, setAssets] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  // Time Filter State
  const [timeFilter, setTimeFilter] = useState<"week" | "month" | "year" | "all">("all");

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [complaintsSnap, teamsSnap, assetsSnap] = await Promise.all([
          getDocs(collection(db, "complaints")).catch(e => { console.error("Error fetching complaints:", e); throw e; }),
          getDocs(collection(db, "crews")).catch(e => { console.error("Error fetching crews:", e); throw e; }),
          getDocs(collection(db, "assets")).catch(e => { console.error("Error fetching assets:", e); throw e; }),
        ]);

        setComplaints(complaintsSnap.docs.map(d => ({ id: d.id, ...d.data() })) as Complaint[]);
        setTeams(teamsSnap.docs.map(d => ({ id: d.id, ...d.data() })) as Team[]);
        setAssets(assetsSnap.docs.map(d => ({ id: d.id, ...d.data() })));
      } catch (error) {
        console.error("Error fetching analytics data:", error);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, []);

  if (loading) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  // Calculate KPIs
  const filteredComplaints = complaints.filter(c => {
    if (timeFilter === "all") return true;
    if (!c.createdAt) return true;
    
    const createdDate = c.createdAt.toDate();
    const now = new Date();
    
    if (timeFilter === "week") {
      const oneWeekAgo = new Date();
      oneWeekAgo.setDate(now.getDate() - 7);
      return createdDate >= oneWeekAgo;
    }
    if (timeFilter === "month") {
      const oneMonthAgo = new Date();
      oneMonthAgo.setMonth(now.getMonth() - 1);
      return createdDate >= oneMonthAgo;
    }
    if (timeFilter === "year") {
      const oneYearAgo = new Date();
      oneYearAgo.setFullYear(now.getFullYear() - 1);
      return createdDate >= oneYearAgo;
    }
    return true;
  });

  const totalIssues = filteredComplaints.length;
  const resolvedIssues = filteredComplaints.filter(c => c.status === "Resolved" || c.status === "Closed").length;
  const pendingIssues = filteredComplaints.filter(c => c.status === "Submitted").length;
  const inProgressIssues = filteredComplaints.filter(c => c.status !== "Resolved" && c.status !== "Closed" && c.status !== "Submitted" && c.status !== "Rejected").length;
  const criticalIssues = filteredComplaints.filter(c => (c.priority || "").toUpperCase() === "CRITICAL").length;
  
  // Try to determine source, default to Citizen if unknown
  const iotIssues = filteredComplaints.filter(c => c.userId === "iot_camera_system" || (c as any).source === "IoT").length;
  const citizenIssues = totalIssues - iotIssues;

  const totalCrews = teams.length;
  const activeCrews = teams.filter(t => t.isOnline).length;
  
  const totalAssets = assets.length;
  const assetsMaintenance = assets.filter(a => a.status === "Under Maintenance").length;

  const resolutionRate = totalIssues > 0 ? ((resolvedIssues / totalIssues) * 100).toFixed(1) + "%" : "N/A";
  
  let totalResolutionTime = 0;
  let resolvedWithTime = 0;
  filteredComplaints.forEach(c => {
    if (c.status === "Resolved" && c.createdAt && c.updatedAt) {
      const created = c.createdAt.toDate().getTime();
      const resolved = c.updatedAt.toDate().getTime();
      totalResolutionTime += (resolved - created);
      resolvedWithTime++;
    }
  });
  
  const avgResTimeHrs = resolvedWithTime > 0 ? (totalResolutionTime / resolvedWithTime / (1000 * 60 * 60)).toFixed(1) + " hrs" : "N/A";

  // Data for Charts
  const statusCounts = filteredComplaints.reduce((acc, c) => {
    acc[c.status] = (acc[c.status] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);
  const statusChartData = Object.keys(statusCounts).map(k => ({ name: k, value: statusCounts[k] }));

  const priorityCounts = filteredComplaints.reduce((acc, c) => {
    const p = (c.priority || "Unassigned").toUpperCase();
    acc[p] = (acc[p] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);
  const priorityChartData = Object.keys(priorityCounts).map(k => ({ name: k, count: priorityCounts[k] }));

  const assetTypeCounts = filteredComplaints.reduce((acc, c) => {
    const t = c.assetType || "Unknown";
    acc[t] = (acc[t] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);
  const assetChartData = Object.keys(assetTypeCounts).map(k => ({ name: k, count: assetTypeCounts[k] }));

  const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#a855f7', '#ec4899'];

  return (
    <div className="p-6 space-y-6">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">System Analytics</h1>
          <p className="text-gray-500 text-sm mt-1">Real-time NAM NAGARAM platform metrics</p>
        </div>
        
        {/* Time Filter Controls */}
        <div className="flex bg-white rounded-lg p-1 border border-gray-200 shadow-sm self-start">
          <button 
            onClick={() => setTimeFilter("week")}
            className={`px-4 py-1.5 text-sm font-medium rounded-md transition-colors ${timeFilter === "week" ? "bg-primary text-white shadow-sm" : "text-gray-600 hover:bg-gray-50"}`}
          >
            This Week
          </button>
          <button 
            onClick={() => setTimeFilter("month")}
            className={`px-4 py-1.5 text-sm font-medium rounded-md transition-colors ${timeFilter === "month" ? "bg-primary text-white shadow-sm" : "text-gray-600 hover:bg-gray-50"}`}
          >
            This Month
          </button>
          <button 
            onClick={() => setTimeFilter("year")}
            className={`px-4 py-1.5 text-sm font-medium rounded-md transition-colors ${timeFilter === "year" ? "bg-primary text-white shadow-sm" : "text-gray-600 hover:bg-gray-50"}`}
          >
            This Year
          </button>
          <button 
            onClick={() => setTimeFilter("all")}
            className={`px-4 py-1.5 text-sm font-medium rounded-md transition-colors ${timeFilter === "all" ? "bg-primary text-white shadow-sm" : "text-gray-600 hover:bg-gray-50"}`}
          >
            All Time
          </button>
        </div>
      </div>

      {/* KPI Grid */}
      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-4">
        <KpiCard title="Total Issues" value={totalIssues} />
        <KpiCard title="Resolved" value={resolvedIssues} color="text-green-600" />
        <KpiCard title="Pending" value={pendingIssues} color="text-yellow-600" />
        <KpiCard title="In Progress" value={inProgressIssues} color="text-blue-600" />
        <KpiCard title="Critical" value={criticalIssues} color="text-red-600" />
        <KpiCard title="Citizen Reported" value={citizenIssues} />
        <KpiCard title="IoT Detected" value={iotIssues} />
        
        <KpiCard title="Total Crews" value={totalCrews} />
        <KpiCard title="Active Crews" value={activeCrews} color="text-green-600" />
        <KpiCard title="Total Assets" value={totalAssets} />
        <KpiCard title="Assets in Maint." value={assetsMaintenance} color="text-purple-600" />
        
        <KpiCard title="Avg Res. Time" value={avgResTimeHrs} />
        <KpiCard title="Resolution Rate" value={resolutionRate} />
      </div>

      {/* Charts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Status Chart */}
        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-800 mb-4">Issues by Status</h3>
          <div className="h-64">
            {statusChartData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={statusChartData}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={80}
                    fill="#8884d8"
                    paddingAngle={5}
                    dataKey="value"
                    label={({ name, percent }) => `${name} ${((percent || 0) * 100).toFixed(0)}%`}
                  >
                    {statusChartData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <RechartsTooltip />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <NoData />
            )}
          </div>
        </div>

        {/* Priority Chart */}
        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-800 mb-4">Issues by Priority</h3>
          <div className="h-64">
            {priorityChartData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={priorityChartData}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} />
                  <XAxis dataKey="name" axisLine={false} tickLine={false} />
                  <YAxis axisLine={false} tickLine={false} />
                  <RechartsTooltip cursor={{ fill: 'rgba(0,0,0,0.05)' }} />
                  <Bar dataKey="count" fill="#3b82f6" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <NoData />
            )}
          </div>
        </div>

        {/* Asset Type Chart */}
        <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200 lg:col-span-2">
          <h3 className="text-lg font-semibold text-gray-800 mb-4">Issues by Asset Type</h3>
          <div className="h-72">
            {assetChartData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={assetChartData}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} />
                  <XAxis dataKey="name" axisLine={false} tickLine={false} />
                  <YAxis axisLine={false} tickLine={false} />
                  <RechartsTooltip cursor={{ fill: 'rgba(0,0,0,0.05)' }} />
                  <Bar dataKey="count" fill="#8b5cf6" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <NoData />
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function KpiCard({ title, value, color = "text-gray-800" }: { title: string, value: string | number, color?: string }) {
  return (
    <div className="bg-white p-4 rounded-lg shadow-sm border border-gray-200 flex flex-col justify-center">
      <p className="text-gray-500 text-xs font-medium uppercase tracking-wider mb-1 line-clamp-1" title={title}>{title}</p>
      <p className={`text-2xl font-bold ${color}`}>{value}</p>
    </div>
  );
}

function NoData() {
  return (
    <div className="w-full h-full flex items-center justify-center text-gray-400 text-sm">
      No data available
    </div>
  );
}
