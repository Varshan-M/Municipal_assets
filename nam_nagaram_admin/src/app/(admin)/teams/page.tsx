"use client";

import { useEffect, useState } from "react";
import { collection, query, where, getDocs, onSnapshot } from "firebase/firestore";
import { db } from "@/lib/firebase/config";
import { Complaint, User, Team } from "@/types";
import { Users, Briefcase, MapPin, Phone, Mail, Clock } from "lucide-react";
import clsx from "clsx";
import Link from "next/link";
import LiveMap from "@/components/map/LiveMap";

export default function TeamsPage() {
  const [teams, setTeams] = useState<Team[]>([]);
  const [crewMembers, setCrewMembers] = useState<User[]>([]);
  const [activeWorks, setActiveWorks] = useState<Complaint[]>([]);
  const [loading, setLoading] = useState(true);
  const [now, setNow] = useState(new Date());

  useEffect(() => {
    // Keep 'now' updated every 30 seconds for accurate offline detection
    const interval = setInterval(() => setNow(new Date()), 30000);
    return () => clearInterval(interval);
  }, []);

  const isTeamActuallyOnline = (team: Team) => {
    if (!team.isOnline) return false;
    if (!team.lastUpdated) return false;
    
    // Check if the last update was within the last 3 minutes (180000 ms)
    try {
      const lastUpdateTime = team.lastUpdated.toDate().getTime();
      return (now.getTime() - lastUpdateTime) < 180000;
    } catch {
      return false; // if timestamp conversion fails
    }
  };

  useEffect(() => {
    // 1. Fetch Teams (crews)
    const fetchTeams = async () => {
      try {
        const q = query(collection(db, "crews"));
        const snapshot = await getDocs(q);
        const data: Team[] = [];
        snapshot.forEach(doc => {
          data.push({ id: doc.id, ...doc.data() } as Team);
        });
        setTeams(data);
      } catch (err) {
        console.error("Error fetching teams:", err);
      }
    };

    let unsubscribeUsers: () => void = () => {};
    let unsubscribeComplaints: () => void = () => {};

    try {
      // 2. Listen to maintenance users
      const usersQuery = query(collection(db, "users"), where("role", "==", "maintenance"));
      unsubscribeUsers = onSnapshot(usersQuery, (snapshot) => {
        const data: User[] = [];
        snapshot.forEach(doc => {
          data.push({ id: doc.id, ...doc.data() } as User);
        });
        setCrewMembers(data);
      }, (error) => {
        console.error("Error listening to users:", error);
      });

      // 3. Listen to active assigned works
      const complaintsQuery = query(collection(db, "complaints"), where("status", "in", ["Team Assigned", "Work In Progress"]));
      unsubscribeComplaints = onSnapshot(complaintsQuery, (snapshot) => {
        const data: Complaint[] = [];
        snapshot.forEach(doc => {
          data.push({ id: doc.id, ...doc.data() } as Complaint);
        });
        setActiveWorks(data);
      }, (error) => {
        console.error("Error listening to complaints:", error);
      });
    } catch (err) {
      console.error("Error setting up listeners:", err);
    }

    fetchTeams().then(() => setLoading(false));

    return () => {
      unsubscribeUsers();
      unsubscribeComplaints();
    };
  }, []);

  if (loading) {
    return <div className="p-12 text-center text-text-muted">Loading Teams...</div>;
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-primary">Team Management</h1>
          <p className="text-text-muted mt-1">Manage field crews, members, and active assignments.</p>
        </div>
      </div>

      {teams.length === 0 ? (
        <div className="bg-surface p-12 text-center rounded-xl border border-gray-200">
          <p className="text-text-muted">No teams found in the database.</p>
        </div>
      ) : (
        <div className="flex flex-col xl:flex-row gap-6 h-[calc(100vh-140px)]">
          
          {/* Left Column: Teams List (Scrollable) */}
          <div className="w-full xl:w-1/3 flex flex-col gap-6 overflow-y-auto pr-2">
            {teams.map((team) => {
              // Find members and works for this specific team
              const members = crewMembers.filter(m => m.teamId === team.id || m.teamId === team.name);
              const works = activeWorks.filter(w => w.assignedTeamId === team.id || w.assignedTeamId === team.name || w.assignedTeam === team.name);

              return (
                <div key={team.id} className="bg-surface rounded-xl border border-gray-200 shadow-sm overflow-hidden flex flex-col shrink-0">
                  {/* Team Header */}
                  <div className="p-4 border-b border-gray-200 bg-gray-50/50">
                    <div className="flex justify-between items-start mb-2">
                      <h2 className="text-lg font-bold text-primary flex items-center gap-2">
                        <Users className="w-5 h-5" />
                        {team.name}
                      </h2>
                      <span className={clsx(
                        "px-2.5 py-1 rounded-full text-xs font-bold border",
                        isTeamActuallyOnline(team) ? "bg-emerald-100 text-emerald-800 border-emerald-200" : "bg-gray-100 text-gray-800 border-gray-200"
                      )}>
                        {isTeamActuallyOnline(team) ? "ONLINE" : "OFFLINE"}
                      </span>
                    </div>
                    <div className="flex flex-wrap gap-1 mt-2">
                      {team.skills?.map(skill => (
                        <span key={skill} className="px-2 py-0.5 bg-blue-50 text-blue-700 text-xs rounded-md border border-blue-100">
                          {skill}
                        </span>
                      ))}
                    </div>
                  </div>

                  <div className="p-4 flex-1">
                    {/* Active Works */}
                    <div className="mb-4">
                      <h3 className="font-semibold text-text mb-2 flex items-center gap-2 text-sm">
                        <Briefcase className="w-4 h-4 text-gray-400" />
                        Active Assignments ({works.length})
                      </h3>
                      
                      {works.length === 0 ? (
                        <p className="text-xs text-text-muted italic bg-gray-50 p-2 rounded-lg">No active assignments.</p>
                      ) : (
                        <ul className="space-y-2">
                          {works.map(work => (
                            <li key={work.id} className="p-2 border border-blue-100 rounded-lg bg-blue-50/30">
                              <div className="flex justify-between items-start">
                                <span className="text-[10px] font-bold text-blue-700 bg-blue-100 px-1.5 py-0.5 rounded">
                                  {work.id.substring(0, 8).toUpperCase()}
                                </span>
                                <span className="text-xs font-medium text-text">{work.issueType}</span>
                              </div>
                            </li>
                          ))}
                        </ul>
                      )}
                    </div>
                    
                    {/* Crew Members */}
                    <div>
                      <h3 className="font-semibold text-text mb-2 flex items-center gap-2 text-sm">
                        <Users className="w-4 h-4 text-gray-400" />
                        App Users ({members.length})
                      </h3>
                      
                      {members.length === 0 ? (
                        <p className="text-xs text-text-muted italic bg-gray-50 p-2 rounded-lg">No registered users.</p>
                      ) : (
                        <div className="flex flex-wrap gap-2">
                          {members.map(member => (
                            <span key={member.id} className="px-2 py-1 bg-gray-100 text-gray-700 text-xs rounded border border-gray-200">
                              {member.firstName} {member.lastName}
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Right Column: Live Map */}
          <div className="w-full xl:w-2/3 h-[500px] xl:h-full relative">
            <LiveMap teams={teams} complaints={activeWorks} />
          </div>

        </div>
      )}
    </div>
  );
}
