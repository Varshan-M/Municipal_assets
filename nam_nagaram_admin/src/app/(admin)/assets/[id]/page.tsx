"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { collection, getDocs } from "firebase/firestore";
import { db } from "@/lib/firebase/config";
import { Complaint } from "@/types";
import { ArrowLeft, Search, Filter } from "lucide-react";

export default function CategoryProblemsPage() {
  const params = useParams();
  const router = useRouter();
  
  // The id is the category name, e.g. 'Street Light'
  const categoryName = typeof params.id === "string" ? decodeURIComponent(params.id) : "";
  
  const [complaints, setComplaints] = useState<Complaint[]>([]);
  const [loading, setLoading] = useState(true);
  
  // Filters
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [priorityFilter, setPriorityFilter] = useState("ALL");

  useEffect(() => {
    if (!categoryName) return;

    const fetchData = async () => {
      try {
        const complaintsSnapshot = await getDocs(collection(db, "complaints"));
        const complaintsData = complaintsSnapshot.docs.map(d => ({
          id: d.id,
          ...d.data()
        })) as Complaint[];
        
        // Filter complaints strictly for this asset category
        const related = complaintsData.filter(
          c => c.assetType?.toLowerCase() === categoryName.toLowerCase()
        );
        
        // Sort by submitted timestamp descending
        related.sort((a, b) => {
          const timeA = a.createdAt?.seconds || 0;
          const timeB = b.createdAt?.seconds || 0;
          return timeB - timeA;
        });
        
        setComplaints(related);
      } catch (error) {
        console.error("Error fetching category problems:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [categoryName]);

  const formatDate = (timestamp: any) => {
    if (!timestamp) return "N/A";
    const date = new Date(timestamp.seconds ? timestamp.seconds * 1000 : timestamp);
    return date.toLocaleString('en-IN', { 
      day: '2-digit', month: 'short', year: 'numeric',
      hour: '2-digit', minute: '2-digit'
    });
  };

  const getResolvedDate = (c: Complaint) => {
    if (c.status === "Resolved" || c.status === "Closed") {
      return formatDate(c.updatedAt);
    }
    return <span className="text-gray-400 italic">Not Resolved</span>;
  };

  const filteredComplaints = complaints.filter(c => {
    const matchesSearch = 
      (c.issueType || "").toLowerCase().includes(searchTerm.toLowerCase()) ||
      (c.address || "").toLowerCase().includes(searchTerm.toLowerCase()) ||
      (c.id || "").toLowerCase().includes(searchTerm.toLowerCase());
      
    const matchesStatus = statusFilter === "ALL" || c.status === statusFilter;
    
    const matchesPriority = priorityFilter === "ALL" || 
      (c.priority && c.priority.toUpperCase() === priorityFilter.toUpperCase());
      
    return matchesSearch && matchesStatus && matchesPriority;
  });

  const getStatusColor = (status: string) => {
    if (status === 'Resolved' || status === 'Closed') return 'bg-green-100 text-green-700';
    if (status === 'Submitted') return 'bg-amber-100 text-amber-700';
    if (status === 'In Progress' || status === 'Team Assigned') return 'bg-blue-100 text-blue-700';
    if (status === 'Critical') return 'bg-red-100 text-red-700';
    return 'bg-gray-100 text-gray-700';
  };

  const getPriorityColor = (priority?: string) => {
    const p = (priority || "").toUpperCase();
    if (p === 'CRITICAL') return 'text-red-600 font-bold';
    if (p === 'HIGH') return 'text-orange-500 font-bold';
    if (p === 'MEDIUM') return 'text-yellow-600 font-medium';
    return 'text-green-600';
  };

  // Get unique statuses and priorities for filter dropdowns
  const availableStatuses = Array.from(new Set(complaints.map(c => c.status))).filter(Boolean);
  const availablePriorities = Array.from(new Set(complaints.map(c => (c.priority || "").toUpperCase()))).filter(Boolean);

  if (loading) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center gap-4 mb-2">
        <button 
          onClick={() => router.push("/assets")}
          className="p-2 hover:bg-gray-100 rounded-full text-gray-500 transition-colors"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
        <div>
          <h1 className="text-2xl font-bold text-gray-800">{categoryName} Problems</h1>
          <p className="text-gray-500 text-sm">
            {complaints.length > 0 
              ? `Showing ${filteredComplaints.length} of ${complaints.length} reported problems` 
              : "No problems reported"}
          </p>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        {/* Filters */}
        <div className="p-4 border-b border-gray-200 bg-gray-50/50 flex flex-col md:flex-row gap-4 items-center justify-between">
          <div className="relative w-full md:w-96">
            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Search problem type, address, or ID..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-9 pr-4 py-2 w-full border border-gray-300 rounded-lg text-sm focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          
          <div className="flex gap-3 w-full md:w-auto">
            <div className="flex items-center gap-2">
              <Filter className="w-4 h-4 text-gray-500" />
              <select 
                className="border border-gray-300 rounded-lg text-sm py-2 px-3 bg-white focus:ring-blue-500"
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
              >
                <option value="ALL">All Statuses</option>
                {availableStatuses.map(s => (
                  <option key={s} value={s}>{s}</option>
                ))}
              </select>
            </div>
            
            <select 
              className="border border-gray-300 rounded-lg text-sm py-2 px-3 bg-white focus:ring-blue-500"
              value={priorityFilter}
              onChange={(e) => setPriorityFilter(e.target.value)}
            >
              <option value="ALL">All Priorities</option>
              {availablePriorities.map(p => (
                <option key={p} value={p}>{p}</option>
              ))}
            </select>
          </div>
        </div>

        {/* Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse min-w-[1000px]">
            <thead>
              <tr className="bg-white text-gray-500 text-xs uppercase tracking-wider border-b">
                <th className="p-4 font-medium w-16">S.No</th>
                <th className="p-4 font-medium w-48">Problem Type</th>
                <th className="p-4 font-medium">Location / Address</th>
                <th className="p-4 font-medium w-40">Submitted</th>
                <th className="p-4 font-medium w-40">Resolved</th>
                <th className="p-4 font-medium w-32">Status</th>
                <th className="p-4 font-medium w-24">Priority</th>
                <th className="p-4 font-medium w-40">Assigned Crew</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {filteredComplaints.length === 0 ? (
                <tr>
                  <td colSpan={8} className="p-8 text-center text-gray-500">
                    {complaints.length === 0 ? "No problems reported for this asset category." : "No problems match your filters."}
                  </td>
                </tr>
              ) : (
                filteredComplaints.map((complaint, index) => (
                  <tr key={complaint.id} className="hover:bg-gray-50/50 transition-colors group">
                    <td className="p-4 text-sm text-gray-500">{index + 1}</td>
                    <td className="p-4">
                      <div className="text-sm font-medium text-gray-900 line-clamp-2">{complaint.issueType || "Unknown Issue"}</div>
                      <div className="text-xs text-gray-400 mt-0.5" title={complaint.id}>ID: {complaint.id.substring(0, 8)}...</div>
                    </td>
                    <td className="p-4 text-sm text-gray-600">
                      <div className="line-clamp-2" title={complaint.address}>{complaint.address || "Location unavailable"}</div>
                    </td>
                    <td className="p-4 text-sm text-gray-600">
                      {formatDate(complaint.createdAt)}
                    </td>
                    <td className="p-4 text-sm">
                      {getResolvedDate(complaint)}
                    </td>
                    <td className="p-4">
                      <span className={`px-2.5 py-1 rounded-full text-xs font-semibold ${getStatusColor(complaint.status)}`}>
                        {complaint.status}
                      </span>
                    </td>
                    <td className="p-4 text-sm">
                      <span className={getPriorityColor(complaint.priority)}>
                        {(complaint.priority || "Normal").toUpperCase()}
                      </span>
                    </td>
                    <td className="p-4 text-sm text-gray-600">
                      {complaint.assignedTeam || complaint.assignedTeamId ? (
                        <span className="font-medium text-gray-800">{complaint.assignedTeam || complaint.assignedTeamId}</span>
                      ) : (
                        <span className="text-gray-400 italic">Unassigned</span>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
