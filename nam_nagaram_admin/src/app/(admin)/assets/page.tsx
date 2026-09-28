"use client";

import { useEffect, useState } from "react";
import { collection, getDocs } from "firebase/firestore";
import { db } from "@/lib/firebase/config";
import { Complaint } from "@/types";
import { Building2, Lightbulb, Droplets, Map, Home } from "lucide-react";
import { useRouter } from "next/navigation";

const CATEGORIES = [
  { name: "Road", icon: Map, color: "bg-gray-100 text-gray-700" },
  { name: "Street Light", icon: Lightbulb, color: "bg-yellow-100 text-yellow-700" },
  { name: "Public Building", icon: Building2, color: "bg-blue-100 text-blue-700" },
  { name: "Water Pipeline", icon: Droplets, color: "bg-blue-100 text-blue-700" },
  { name: "Drainage", icon: Home, color: "bg-purple-100 text-purple-700" }
];

export default function AssetsCategoriesPage() {
  const router = useRouter();
  const [complaints, setComplaints] = useState<Complaint[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const complaintsSnapshot = await getDocs(collection(db, "complaints"));
        const complaintsData = complaintsSnapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        })) as Complaint[];

        setComplaints(complaintsData);
      } catch (error) {
        console.error("Error fetching complaints data:", error);
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

  return (
    <div className="p-6 space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Municipal Infrastructure Assets</h1>
          <p className="text-gray-500 text-sm mt-1">Select an asset category to view reported problems</p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {CATEGORIES.map((category) => {
          // Count problems for this category
          const categoryProblems = complaints.filter(
            c => c.assetType?.toLowerCase() === category.name.toLowerCase()
          );
          const count = categoryProblems.length;

          return (
            <div 
              key={category.name}
              onClick={() => router.push(`/assets/${encodeURIComponent(category.name)}`)}
              className="bg-white p-6 rounded-xl shadow-sm border border-gray-200 cursor-pointer hover:shadow-md hover:border-blue-300 transition-all group"
            >
              <div className="flex items-start justify-between">
                <div className={`p-3 rounded-lg ${category.color}`}>
                  <category.icon className="w-8 h-8" />
                </div>
                <div className="text-right">
                  <h3 className="text-3xl font-bold text-gray-800">{count}</h3>
                  <p className="text-sm font-medium text-gray-500 uppercase tracking-wider">Problems</p>
                </div>
              </div>
              <h2 className="text-xl font-bold text-gray-800 mt-6 group-hover:text-blue-600 transition-colors">
                {category.name}
              </h2>
            </div>
          );
        })}
      </div>
    </div>
  );
}
