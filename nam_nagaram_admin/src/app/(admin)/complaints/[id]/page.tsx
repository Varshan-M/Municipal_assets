"use client";

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { useParams, useRouter } from "next/navigation";
import { doc, getDoc, collection, query, onSnapshot, writeBatch, serverTimestamp } from "firebase/firestore";
import { db } from "@/lib/firebase/config";
import { useAuth } from "@/lib/auth/AuthContext";
import { Complaint, User, TimelineEntry } from "@/types";
import { ArrowLeft, User as UserIcon, MapPin, Camera, AlertTriangle, Clock, ShieldCheck, X, Cpu } from "lucide-react";
import Link from "next/link";
import clsx from "clsx";

export default function ComplaintDetailPage() {
  const params = useParams();
  const router = useRouter();
  const { user: adminUser } = useAuth();
  const complaintId = params.id as string;

  const [complaint, setComplaint] = useState<Complaint | null>(null);
  const [citizen, setCitizen] = useState<User | null>(null);
  const [timeline, setTimeline] = useState<TimelineEntry[]>([]);
  const [loading, setLoading] = useState(true);

  // Modal State
  const [isStatusModalOpen, setIsStatusModalOpen] = useState(false);
  const [isTeamModalOpen, setIsTeamModalOpen] = useState(false);
  
  // Form State
  const [newStatus, setNewStatus] = useState("In Progress");
  const [statusMessage, setStatusMessage] = useState("");
  const [newDepartment, setNewDepartment] = useState("");
  const [newTeam, setNewTeam] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (!complaintId) return;

    const fetchComplaintData = async () => {
      try {
        // Fetch Complaint
        const complaintRef = doc(db, "complaints", complaintId);
        const complaintSnap = await getDoc(complaintRef);
        
        if (complaintSnap.exists()) {
          const compData = { id: complaintSnap.id, ...complaintSnap.data() } as Complaint;
          setComplaint(compData);

          // Fetch Citizen Info
          if (compData.userId) {
            const userRef = doc(db, "users", compData.userId);
            const userSnap = await getDoc(userRef);
            if (userSnap.exists()) {
              setCitizen({ id: userSnap.id, ...userSnap.data() } as User);
            }
          }
        }
        
        setLoading(false);
      } catch (error) {
        console.error("Error fetching complaint:", error);
        setLoading(false);
      }
    };

    fetchComplaintData();

    // Listen to Timeline Subcollection
    const timelineRef = collection(db, "complaints", complaintId, "timeline");
    // Sort by timestamp asc (requires index, dropping orderBy for simplicity unless necessary)
    const q = query(timelineRef);
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const entries: TimelineEntry[] = [];
      snapshot.forEach(doc => {
        entries.push({ id: doc.id, ...doc.data() } as TimelineEntry);
      });
      // Sort client-side
      entries.sort((a, b) => (a.timestamp?.toMillis() || 0) - (b.timestamp?.toMillis() || 0));
      setTimeline(entries);
    });

    return () => unsubscribe();
  }, [complaintId]);

  const handleUpdateStatus = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!complaint || !adminUser || !statusMessage.trim()) return;
    
    setIsSubmitting(true);
    try {
      const batch = writeBatch(db);
      
      const complaintRef = doc(db, "complaints", complaint.id);
      batch.update(complaintRef, {
        status: newStatus,
        updatedAt: serverTimestamp(),
        aiOverridden: complaint.aiProcessed ? true : false
      });

      const newTimelineRef = doc(collection(db, "complaints", complaint.id, "timeline"));
      batch.set(newTimelineRef, {
        status: newStatus,
        message: statusMessage.trim(),
        timestamp: serverTimestamp(),
        updatedBy: adminUser.uid,
        updatedByName: adminUser.email || 'Administrator',
        source: "ADMIN"
      });

      await batch.commit();
      setIsStatusModalOpen(false);
      setStatusMessage("");
    } catch (error) {
      console.error("Error updating status:", error);
      alert("Failed to update status. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleAssignTeam = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!complaint || !adminUser || !newDepartment.trim() || !newTeam.trim()) return;
    
    setIsSubmitting(true);
    try {
      const batch = writeBatch(db);
      
      const complaintRef = doc(db, "complaints", complaint.id);
      batch.update(complaintRef, {
        assignedDepartment: newDepartment.trim(),
        assignedTeam: newTeam.trim(),
        status: "Assigned",
        updatedAt: serverTimestamp(),
        aiOverridden: complaint.aiProcessed ? true : false
      });

      const newTimelineRef = doc(collection(db, "complaints", complaint.id, "timeline"));
      batch.set(newTimelineRef, {
        status: "Assigned",
        message: `Assigned to ${newDepartment.trim()} - ${newTeam.trim()}`,
        timestamp: serverTimestamp(),
        updatedBy: adminUser.uid,
        updatedByName: adminUser.email || 'Administrator',
        source: "ADMIN"
      });

      await batch.commit();
      setIsTeamModalOpen(false);
      setNewDepartment("");
      setNewTeam("");
    } catch (error) {
      console.error("Error assigning team:", error);
      alert("Failed to assign team. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  if (loading) {
    return <div className="p-12 text-center text-text-muted">Loading complaint details...</div>;
  }

  if (!complaint) {
    return (
      <div className="p-12 text-center">
        <AlertTriangle className="w-12 h-12 text-red-500 mx-auto mb-4" />
        <h2 className="text-xl font-bold text-text">Complaint Not Found</h2>
        <button onClick={() => router.push('/complaints')} className="mt-4 text-primary hover:underline">
          Return to complaints list
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-6 max-w-7xl mx-auto pb-12">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link href="/complaints" className="p-2 bg-surface border border-gray-200 rounded-lg text-text-muted hover:text-text transition-colors">
          <ArrowLeft className="w-5 h-5" />
        </Link>
        <div>
          <div className="flex items-center gap-3">
            <h1 className="text-2xl font-bold text-primary">Complaint Details</h1>
            <span className="px-3 py-1 bg-gray-100 border border-gray-200 rounded-full text-xs font-mono font-medium text-text-muted">
              {complaint.id}
            </span>
          </div>
          <p className="text-text-muted mt-1 text-sm">Submitted on {complaint.createdAt ? new Date(complaint.createdAt.toMillis()).toLocaleString() : 'Unknown Date'}</p>
        </div>
        
        <div className="ml-auto flex gap-3">
          <button 
            onClick={() => setIsStatusModalOpen(true)}
            className="px-4 py-2 bg-primary text-white text-sm font-medium rounded-lg hover:bg-primary-light transition-colors shadow-sm"
          >
            Update Status
          </button>
          <button 
            onClick={() => setIsTeamModalOpen(true)}
            className="px-4 py-2 bg-surface border border-gray-300 text-text text-sm font-medium rounded-lg hover:bg-gray-50 transition-colors shadow-sm"
          >
            Assign Team
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column: Details */}
        <div className="lg:col-span-2 space-y-6">
          
          {/* AI Analysis Card */}
          {complaint.aiProcessed && complaint.aiAnalysis && (
            <div className="bg-surface border border-indigo-200 rounded-xl overflow-hidden shadow-sm relative">
              {complaint.aiOverridden && (
                <div className="absolute top-0 right-0 bg-amber-500 text-white text-[10px] font-bold px-2 py-1 rounded-bl-lg">
                  OVERRIDDEN BY ADMIN
                </div>
              )}
              <div className="px-6 py-4 border-b border-indigo-100 bg-indigo-50/50 flex items-center gap-2">
                <Cpu className="w-4 h-4 text-indigo-600" />
                <h2 className="font-semibold text-indigo-900">AI Analysis</h2>
                <span className={clsx(
                  "ml-auto px-2 py-0.5 rounded-full text-xs font-bold",
                  complaint.aiAnalysis.confidence >= 0.8 ? "bg-green-100 text-green-700" :
                  complaint.aiAnalysis.confidence >= 0.6 ? "bg-amber-100 text-amber-700" : "bg-red-100 text-red-700"
                )}>
                  {(complaint.aiAnalysis.confidence * 100).toFixed(0)}% Confidence
                </span>
              </div>
              <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <p className="text-xs text-text-muted mb-1">Recommended Department</p>
                  <p className="font-medium text-text">{complaint.aiAnalysis.department}</p>
                </div>
                <div>
                  <p className="text-xs text-text-muted mb-1">Recommended Team</p>
                  <p className="font-medium text-text">{complaint.aiAnalysis.recommendedTeam || <span className="italic text-gray-400">Manual review required</span>}</p>
                </div>
                <div>
                  <p className="text-xs text-text-muted mb-1">AI Priority</p>
                  <p className={clsx("font-bold", 
                    complaint.aiAnalysis.priority === 'CRITICAL' ? 'text-red-600' :
                    complaint.aiAnalysis.priority === 'HIGH' ? 'text-orange-600' : 'text-text'
                  )}>{complaint.aiAnalysis.priority}</p>
                </div>
                <div>
                  <p className="text-xs text-text-muted mb-1">Est. Resolution Time</p>
                  <p className="font-medium text-text">{complaint.aiAnalysis.estimatedResolutionHours} hours</p>
                </div>
                <div className="md:col-span-2">
                  <p className="text-xs text-text-muted mb-1">AI Reasoning</p>
                  <p className="text-sm text-text bg-white border border-gray-100 p-3 rounded-lg italic">
                    "{complaint.aiAnalysis.reasoning}"
                  </p>
                </div>
                <div className="md:col-span-2">
                  <p className="text-xs text-text-muted mb-1">Recommended Action</p>
                  <p className="text-sm font-medium text-indigo-900">
                    {complaint.aiAnalysis.recommendedAction}
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Issue Information */}
          <div className="bg-surface border border-gray-200 rounded-xl overflow-hidden shadow-sm">
            <div className="px-6 py-4 border-b border-gray-200 bg-gray-50/50 flex justify-between items-center">
              <h2 className="font-semibold text-text flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 text-primary" />
                Issue Information
              </h2>
              <span className={clsx(
                "px-2.5 py-1 rounded-full text-xs font-semibold border", 
                complaint.status === 'Resolved' ? 'bg-emerald-100 text-emerald-800 border-emerald-200' : 
                complaint.status === 'In Progress' ? 'bg-blue-100 text-blue-800 border-blue-200' :
                'bg-amber-100 text-amber-800 border-amber-200'
              )}>
                {complaint.status}
              </span>
            </div>
            <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <p className="text-sm text-text-muted mb-1">Asset Category</p>
                <p className="font-medium text-text">{complaint.assetType}</p>
              </div>
              <div>
                <p className="text-sm text-text-muted mb-1">Issue Type</p>
                <p className="font-medium text-text">{complaint.issueType}</p>
              </div>
              <div className="md:col-span-2">
                <p className="text-sm text-text-muted mb-1">Description</p>
                <p className="text-text bg-gray-50 p-4 rounded-lg text-sm border border-gray-100">
                  {complaint.description || 'No description provided.'}
                </p>
              </div>
              <div>
                <p className="text-sm text-text-muted mb-1">Priority</p>
                <p className="font-medium text-text">{complaint.priority || 'Not set'}</p>
              </div>
            </div>
          </div>

          {/* Evidence */}
          <div className="bg-surface border border-gray-200 rounded-xl overflow-hidden shadow-sm">
            <div className="px-6 py-4 border-b border-gray-200 bg-gray-50/50 flex items-center gap-2">
              <Camera className="w-4 h-4 text-primary" />
              <h2 className="font-semibold text-text">Evidence</h2>
            </div>
            <div className="p-6">
              {complaint.imageUrl ? (
                // Note: handling base64 strings if that's how it's stored
                <div className="rounded-lg overflow-hidden border border-gray-200 max-w-md">
                  <img 
                    src={complaint.imageUrl.startsWith('http') || complaint.imageUrl.startsWith('data:') ? complaint.imageUrl : `data:image/jpeg;base64,${complaint.imageUrl}`} 
                    alt="Issue Evidence" 
                    className="w-full h-auto object-cover"
                  />
                </div>
              ) : (
                <div className="p-12 text-center border-2 border-dashed border-gray-200 rounded-lg text-text-muted">
                  No image evidence provided.
                </div>
              )}
            </div>
          </div>

          {/* Location */}
          <div className="bg-surface border border-gray-200 rounded-xl overflow-hidden shadow-sm">
            <div className="px-6 py-4 border-b border-gray-200 bg-gray-50/50 flex items-center gap-2">
              <MapPin className="w-4 h-4 text-primary" />
              <h2 className="font-semibold text-text">Location Details</h2>
            </div>
            <div className="p-6">
              <p className="font-medium text-text mb-4">{complaint.address}</p>
              <div className="bg-gray-100 rounded-lg w-full h-64 flex items-center justify-center border border-gray-200 text-text-muted relative overflow-hidden">
                {/* Map stub for now */}
                <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/cubes.png')] opacity-10"></div>
                <div className="z-10 flex flex-col items-center bg-white/80 p-4 rounded-lg backdrop-blur-sm border border-gray-200 shadow-sm">
                  <MapPin className="w-8 h-8 text-red-500 mb-2" />
                  <p className="text-sm font-medium">Map integration pending</p>
                  <p className="text-xs">{complaint.latitude}, {complaint.longitude}</p>
                </div>
              </div>
            </div>
          </div>

        </div>

        {/* Right Column: Citizen, AI, Timeline */}
        <div className="space-y-6">
          
          {/* Citizen Info */}
          <div className="bg-surface border border-gray-200 rounded-xl overflow-hidden shadow-sm">
            <div className="px-6 py-4 border-b border-gray-200 bg-gray-50/50 flex items-center gap-2">
              <UserIcon className="w-4 h-4 text-primary" />
              <h2 className="font-semibold text-text">Citizen Information</h2>
            </div>
            <div className="p-6 space-y-4">
              {citizen ? (
                <>
                  <div>
                    <p className="text-xs text-text-muted mb-1">Name</p>
                    <p className="text-sm font-medium text-text">{citizen.firstName} {citizen.lastName}</p>
                  </div>
                  <div>
                    <p className="text-xs text-text-muted mb-1">Email</p>
                    <p className="text-sm font-medium text-text">{citizen.email}</p>
                  </div>
                  <div>
                    <p className="text-xs text-text-muted mb-1">Phone</p>
                    <p className="text-sm font-medium text-text">{citizen.phoneNumber || 'Not provided'}</p>
                  </div>
                </>
              ) : (
                <p className="text-sm text-text-muted">Loading citizen details or citizen not found.</p>
              )}
            </div>
          </div>


          {/* Timeline */}
          <div className="bg-surface border border-gray-200 rounded-xl overflow-hidden shadow-sm">
            <div className="px-6 py-4 border-b border-gray-200 bg-gray-50/50 flex items-center gap-2">
              <Clock className="w-4 h-4 text-primary" />
              <h2 className="font-semibold text-text">Timeline</h2>
            </div>
            <div className="p-6">
              {timeline.length > 0 ? (
                <div className="relative border-l border-gray-200 ml-3 space-y-6">
                  {timeline.map((entry, index) => (
                    <div key={entry.id} className="relative pl-6">
                      <div className="absolute -left-1.5 top-1.5 w-3 h-3 rounded-full bg-primary ring-4 ring-white" />
                      <div className="flex items-center gap-2 mb-1">
                        <span className="text-sm font-semibold text-text">{entry.status}</span>
                        <span className="text-xs text-text-muted">
                          {entry.timestamp ? new Date(entry.timestamp.toMillis()).toLocaleString() : 'Unknown Date'}
                        </span>
                      </div>
                      <p className="text-sm text-text-muted">{entry.message}</p>
                      {entry.updatedByName && (
                        <div className="flex items-center gap-1 mt-2">
                          {entry.source === "AI" ? (
                            <span className="text-[10px] font-bold text-indigo-600 flex items-center bg-indigo-50 px-2 py-0.5 rounded-full uppercase tracking-wide"><Cpu className="w-3 h-3 mr-1"/> AI Update</span>
                          ) : entry.source === "ADMIN" ? (
                            <span className="text-[10px] font-bold text-blue-600 flex items-center bg-blue-50 px-2 py-0.5 rounded-full uppercase tracking-wide"><ShieldCheck className="w-3 h-3 mr-1"/> Municipal Officer</span>
                          ) : (
                            <span className="text-[10px] text-gray-500 bg-gray-100 px-2 py-0.5 rounded-full">By: {entry.updatedByName}</span>
                          )}
                        </div>
                      )}
                    </div>
                  ))}
                  
                  {/* Pending stub for next state */}
                  {complaint.status !== 'Resolved' && complaint.status !== 'Closed' && complaint.status !== 'Rejected' && (
                    <div className="relative pl-6 opacity-50">
                      <div className="absolute -left-1.5 top-1.5 w-3 h-3 rounded-full bg-gray-300 ring-4 ring-white" />
                      <div className="flex items-center gap-2 mb-1">
                        <span className="text-sm font-medium text-gray-500">Next Step</span>
                      </div>
                      <p className="text-sm text-gray-400">Awaiting status update...</p>
                    </div>
                  )}
                </div>
              ) : (
                <div className="text-center py-6 text-sm text-text-muted">
                  <p>No timeline entries found.</p>
                </div>
              )}
            </div>
          </div>

        </div>
      </div>

      {/* Update Status Modal */}
      {isStatusModalOpen && typeof document !== "undefined" && createPortal(
        <div className="fixed inset-0 z-[9999] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
          <div className="bg-surface rounded-xl shadow-xl w-full max-w-md overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-200 flex justify-between items-center">
              <h3 className="font-semibold text-text text-lg">Update Complaint Status</h3>
              <button onClick={() => setIsStatusModalOpen(false)} className="text-gray-400 hover:text-gray-600">
                <X className="w-5 h-5" />
              </button>
            </div>
            <form onSubmit={handleUpdateStatus} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-text mb-1">New Status</label>
                <select 
                  value={newStatus}
                  onChange={(e) => setNewStatus(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-primary outline-none bg-white text-black"
                >
                  <option value="In Progress">In Progress</option>
                  <option value="Under Review">Under Review</option>
                  <option value="Resolved">Resolved</option>
                  <option value="Rejected">Rejected</option>
                  <option value="Closed">Closed</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-text mb-1">Public Update Message</label>
                <textarea 
                  value={statusMessage}
                  onChange={(e) => setStatusMessage(e.target.value)}
                  required
                  placeholder="e.g., A repair crew has been dispatched."
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-primary outline-none min-h-[100px] bg-white text-black"
                />
                <p className="text-xs text-text-muted mt-1">This message will be visible to the citizen in their timeline.</p>
              </div>
              <div className="pt-4 flex justify-end gap-3">
                <button 
                  type="button" 
                  onClick={() => setIsStatusModalOpen(false)}
                  className="px-4 py-2 text-sm font-medium text-text bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
                >
                  Cancel
                </button>
                <button 
                  type="submit" 
                  disabled={isSubmitting}
                  className="px-4 py-2 text-sm font-medium text-white bg-primary hover:bg-primary-light rounded-lg transition-colors disabled:opacity-50"
                >
                  {isSubmitting ? "Updating..." : "Confirm Update"}
                </button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}

      {/* Assign Team Modal */}
      {isTeamModalOpen && typeof document !== "undefined" && createPortal(
        <div className="fixed inset-0 z-[9999] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
          <div className="bg-surface rounded-xl shadow-xl w-full max-w-md overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-200 flex justify-between items-center">
              <h3 className="font-semibold text-text text-lg">Assign Department & Team</h3>
              <button onClick={() => setIsTeamModalOpen(false)} className="text-gray-400 hover:text-gray-600">
                <X className="w-5 h-5" />
              </button>
            </div>
            <form onSubmit={handleAssignTeam} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-text mb-1">Department</label>
                <input 
                  type="text"
                  value={newDepartment}
                  onChange={(e) => setNewDepartment(e.target.value)}
                  required
                  placeholder="e.g., Roads Department"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-primary outline-none bg-white text-black"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-text mb-1">Specific Team</label>
                <input 
                  type="text"
                  value={newTeam}
                  onChange={(e) => setNewTeam(e.target.value)}
                  required
                  placeholder="e.g., Road Repair Team A"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-primary outline-none bg-white text-black"
                />
                <p className="text-xs text-text-muted mt-2">
                  Assigning a team will automatically update the status to "Assigned" and notify the citizen.
                </p>
              </div>
              <div className="pt-4 flex justify-end gap-3">
                <button 
                  type="button" 
                  onClick={() => setIsTeamModalOpen(false)}
                  className="px-4 py-2 text-sm font-medium text-text bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
                >
                  Cancel
                </button>
                <button 
                  type="submit" 
                  disabled={isSubmitting}
                  className="px-4 py-2 text-sm font-medium text-white bg-primary hover:bg-primary-light rounded-lg transition-colors disabled:opacity-50"
                >
                  {isSubmitting ? "Assigning..." : "Confirm Assignment"}
                </button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}

    </div>
  );
}
