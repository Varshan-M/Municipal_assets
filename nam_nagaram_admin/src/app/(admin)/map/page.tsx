"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { collection, getDocs } from "firebase/firestore";
import { db } from "@/lib/firebase/config";
import { Team, Complaint } from "@/types";
import LiveMap from "@/components/map/LiveMap";
import { ArrowLeft } from "lucide-react";

export default function FullScreenMapPage() {
  const router = useRouter();
  const [teams, setTeams] = useState<Team[]>([]);
  const [complaints, setComplaints] = useState<Complaint[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Handle ESC key to exit
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        router.push("/dashboard");
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [router]);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const teamsSnapshot = await getDocs(collection(db, "crews"));
        const teamsData = teamsSnapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        })) as Team[];

        const complaintsSnapshot = await getDocs(collection(db, "complaints"));
        const complaintsData = complaintsSnapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        })) as Complaint[];

        setTeams(teamsData);
        setComplaints(complaintsData);
      } catch (error) {
        console.error("Error fetching map data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  return (
    <div className="fixed inset-0 z-50 bg-white">
      {/* Map Header Overlay */}
      <div className="absolute top-4 left-4 right-4 z-[60] flex items-center justify-between pointer-events-none">
        <button
          onClick={() => router.push("/dashboard")}
          className="flex items-center gap-2 px-4 py-2 bg-white text-gray-800 rounded-lg shadow-md pointer-events-auto hover:bg-gray-50 transition-colors font-medium"
        >
          <ArrowLeft className="w-5 h-5" />
          Back to Dashboard (ESC)
        </button>

        <div className="flex gap-4 pointer-events-auto bg-white/90 backdrop-blur-sm p-3 rounded-lg shadow-md border border-gray-100">
          <div className="flex items-center gap-2">
            <span className="w-3 h-3 rounded-full bg-green-500"></span>
            <span className="text-sm font-medium text-gray-700">Crew</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="w-3 h-3 rounded-full bg-red-500"></span>
            <span className="text-sm font-medium text-gray-700">Issues</span>
          </div>
        </div>
      </div>

      {loading ? (
        <div className="w-full h-full flex flex-col items-center justify-center bg-gray-50">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mb-4"></div>
          <p className="text-gray-500 font-medium">Loading map data...</p>
        </div>
      ) : (
        <LiveMap teams={teams} complaints={complaints} />
      )}
    </div>
  );
}
