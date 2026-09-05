"use client";

import { useEffect, useState } from "react";
import { collection, query, onSnapshot, orderBy } from "firebase/firestore";
import { db } from "@/lib/firebase/config";
import { Complaint } from "@/types";
import { Search, Filter, Eye, AlertCircle } from "lucide-react";
import Link from "next/link";
import clsx from "clsx";

export default function ComplaintsPage() {
  const [complaints, setComplaints] = useState<Complaint[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");

  useEffect(() => {
    // Fetch complaints ordered by creation date (newest first)
    // Note: This requires a Firestore index if we filter + orderBy.
    const q = query(collection(db, "complaints")); // Just fetch all for now, filter client-side for simplicity in demo
    
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const data: Complaint[] = [];
      snapshot.forEach((doc) => {
        data.push({ id: doc.id, ...doc.data() } as Complaint);
      });
      // Sort client-side if no index
      data.sort((a, b) => b.createdAt?.toMillis() - a.createdAt?.toMillis());
      setComplaints(data);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const filteredComplaints = complaints.filter(c => 
    c.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
    c.assetType.toLowerCase().includes(searchTerm.toLowerCase()) ||
    c.issueType.toLowerCase().includes(searchTerm.toLowerCase()) ||
    c.address.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const getStatusColor = (status: string) => {
    switch(status) {
      case 'Resolved': return 'bg-emerald-100 text-emerald-800 border-emerald-200';
      case 'In Progress': case 'Assigned': return 'bg-blue-100 text-blue-800 border-blue-200';
      case 'Pending': case 'Submitted': case 'Under Review': return 'bg-amber-100 text-amber-800 border-amber-200';
      case 'Rejected': case 'Closed': return 'bg-gray-100 text-gray-800 border-gray-200';
      default: return 'bg-gray-100 text-gray-800 border-gray-200';
    }
  };

  const getPriorityColor = (priority?: string) => {
    switch(priority) {
      case 'Critical': return 'text-red-600 bg-red-50';
      case 'High': return 'text-orange-600 bg-orange-50';
      case 'Medium': return 'text-amber-600 bg-amber-50';
      case 'Low': return 'text-blue-600 bg-blue-50';
      default: return 'text-gray-600 bg-gray-50';
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-primary">Complaints Management</h1>
          <p className="text-text-muted mt-1">View, track, and assign citizen reports.</p>
        </div>
        
        {/* Actions / Filters */}
        <div className="flex items-center gap-3 w-full sm:w-auto">
          <div className="relative flex-1 sm:w-64">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input 
              type="text" 
              placeholder="Search complaints..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-9 pr-4 py-2 bg-surface border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary focus:border-primary transition-all"
            />
          </div>
          <button className="flex items-center gap-2 px-4 py-2 bg-surface border border-gray-300 rounded-lg text-sm font-medium hover:bg-gray-50 transition-colors text-text">
            <Filter className="w-4 h-4" />
            <span className="hidden sm:inline">Filters</span>
          </button>
        </div>
      </div>

      {/* Table */}
      <div className="bg-surface rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm whitespace-nowrap">
            <thead className="bg-gray-50 text-text-muted font-medium border-b border-gray-200">
              <tr>
                <th className="px-6 py-4">Complaint ID</th>
                <th className="px-6 py-4">Department</th>
                <th className="px-6 py-4">Priority</th>
                <th className="px-6 py-4">Assigned Team</th>
                <th className="px-6 py-4">AI Confidence</th>
                <th className="px-6 py-4">Status</th>
                <th className="px-6 py-4 text-right"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {loading ? (
                <tr>
                  <td colSpan={7} className="px-6 py-12 text-center text-text-muted">
                    Loading complaints...
                  </td>
                </tr>
              ) : filteredComplaints.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-6 py-12 text-center text-text-muted">
                    <div className="flex flex-col items-center justify-center">
                      <AlertCircle className="w-8 h-8 mb-2 text-gray-400" />
                      <p>No complaints found.</p>
                    </div>
                  </td>
                </tr>
              ) : (
                filteredComplaints.map((complaint) => (
                  <tr key={complaint.id} className="hover:bg-gray-50 transition-colors">
                    <td className="px-6 py-4 font-medium text-primary">
                      <div className="flex flex-col">
                        <span>{complaint.id.substring(0, 8).toUpperCase()}</span>
                        <span className="text-xs text-text-muted font-normal">{complaint.issueType}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-text">
                      {complaint.department || <span className="text-gray-400 italic">Unassigned</span>}
                    </td>
                    <td className="px-6 py-4">
                      <span className={clsx("px-2.5 py-1 rounded-full text-xs font-bold", getPriorityColor(complaint.priority))}>
                        {complaint.priority || 'PENDING'}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-text">
                      {complaint.assignedTeam || <span className="text-gray-400 italic">Unassigned</span>}
                    </td>
                    <td className="px-6 py-4">
                      {complaint.aiAnalysis?.confidence ? (
                        <div className="flex items-center">
                          <span className={clsx(
                            "font-medium",
                            complaint.aiAnalysis.confidence >= 0.8 ? "text-green-600" : 
                            complaint.aiAnalysis.confidence >= 0.6 ? "text-amber-600" : "text-red-600"
                          )}>
                            {(complaint.aiAnalysis.confidence * 100).toFixed(0)}%
                          </span>
                        </div>
                      ) : (
                        <span className="text-gray-400 text-xs">N/A</span>
                      )}
                    </td>
                    <td className="px-6 py-4">
                      <span className={clsx("px-2.5 py-1 rounded-full text-xs font-semibold border", getStatusColor(complaint.status))}>
                        {complaint.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-text-muted">
                      {complaint.createdAt ? new Date(complaint.createdAt.toMillis()).toLocaleDateString() : 'N/A'}
                    </td>
                    <td className="px-6 py-4 text-right">
                      <Link 
                        href={`/complaints/${complaint.id}`}
                        className="inline-block px-4 py-1.5 bg-blue-50 text-blue-700 hover:bg-blue-100 hover:text-blue-800 text-xs font-semibold rounded-md transition-colors border border-blue-200"
                      >
                        View
                      </Link>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
        
        {/* Simple Pagination stub */}
        {!loading && filteredComplaints.length > 0 && (
          <div className="px-6 py-4 border-t border-gray-200 flex items-center justify-between bg-gray-50">
            <span className="text-sm text-text-muted">
              Showing {filteredComplaints.length} entries
            </span>
            <div className="flex gap-2">
              <button className="px-3 py-1 border border-gray-300 rounded-md text-sm bg-white disabled:opacity-50">Previous</button>
              <button className="px-3 py-1 border border-gray-300 rounded-md text-sm bg-white disabled:opacity-50">Next</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
