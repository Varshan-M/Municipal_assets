"use client";

import { useEffect, useState } from "react";
import { collection, onSnapshot, query, orderBy, limit } from "firebase/firestore";
import { db } from "@/lib/firebase/config";
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from "recharts";
import { Activity, Wifi, WifiOff, AlertTriangle, Settings, Cpu } from "lucide-react";
import clsx from "clsx";

interface SensorData {
  id: string;
  status: "Online" | "Offline";
  lastSeen: any;
  currentDistanceCm: number;
}

interface ReadingData {
  timestamp: string;
  distance_cm: number;
}

export default function IoTSensorsPage() {
  const [sensors, setSensors] = useState<SensorData[]>([]);
  const [selectedSensor, setSelectedSensor] = useState<string | null>(null);
  const [readings, setReadings] = useState<ReadingData[]>([]);
  const [threshold, setThreshold] = useState<number>(5.0);
  
  // Listen to sensors collection
  useEffect(() => {
    const q = query(collection(db, "sensors"));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const sensorList: SensorData[] = [];
      snapshot.forEach((doc) => {
        const data = doc.data();
        
        // Determine Online status (if lastSeen within 2 mins)
        let isOnline = false;
        if (data.lastSeen) {
          const lastSeenDate = data.lastSeen.toDate();
          const now = new Date();
          if ((now.getTime() - lastSeenDate.getTime()) < 120000) {
            isOnline = true;
          }
        }
        
        sensorList.push({
          id: doc.id,
          status: isOnline ? "Online" : "Offline",
          lastSeen: data.lastSeen,
          currentDistanceCm: data.currentDistanceCm || 0
        });
      });
      setSensors(sensorList);
      
      if (!selectedSensor && sensorList.length > 0) {
        setSelectedSensor(sensorList[0].id);
      }
    });
    
    return () => unsubscribe();
  }, [selectedSensor]);
  
  // Listen to readings subcollection for selected sensor
  useEffect(() => {
    if (!selectedSensor) return;
    
    const readingsRef = collection(db, "sensors", selectedSensor, "readings");
    const q = query(readingsRef, orderBy("timestamp", "desc"), limit(50));
    
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const readingList: ReadingData[] = [];
      snapshot.forEach((doc) => {
        const data = doc.data();
        if (data.timestamp) {
          const date = data.timestamp.toDate();
          readingList.push({
            timestamp: date.toLocaleTimeString(),
            distance_cm: Number(data.distance_cm.toFixed(2))
          });
        }
      });
      // Reverse to chronological for chart
      setReadings(readingList.reverse());
    });
    
    return () => unsubscribe();
  }, [selectedSensor]);

  return (
    <div className="space-y-6 max-w-7xl mx-auto pb-12">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-primary">IoT Surface Monitoring</h1>
          <p className="text-text-muted mt-1 text-sm">Real-time ultrasonic displacement tracking for structural health.</p>
        </div>
        <div className="flex gap-3">
          <button className="px-4 py-2 bg-surface border border-gray-200 text-text text-sm font-medium rounded-lg hover:bg-gray-50 flex items-center gap-2">
            <Settings className="w-4 h-4" /> Threshold Settings
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
        
        {/* Left Column: Sensor List */}
        <div className="lg:col-span-1 bg-surface border border-gray-200 rounded-xl shadow-sm flex flex-col overflow-hidden">
          <div className="px-5 py-4 border-b border-gray-100 bg-gray-50 flex items-center gap-2">
            <Cpu className="w-4 h-4 text-primary" />
            <h2 className="font-semibold text-text">Deployed Scanners</h2>
          </div>
          <div className="flex-1 overflow-y-auto p-2">
            {sensors.length === 0 ? (
              <p className="text-sm text-text-muted text-center py-6">No sensors active.</p>
            ) : (
              sensors.map(sensor => (
                <button
                  key={sensor.id}
                  onClick={() => setSelectedSensor(sensor.id)}
                  className={clsx(
                    "w-full text-left p-3 rounded-lg mb-2 flex items-center justify-between transition-colors",
                    selectedSensor === sensor.id ? "bg-indigo-50 border border-indigo-100" : "hover:bg-gray-50 border border-transparent"
                  )}
                >
                  <div>
                    <p className={clsx("font-semibold text-sm", selectedSensor === sensor.id ? "text-indigo-900" : "text-text")}>{sensor.id}</p>
                    <p className="text-xs text-text-muted mt-0.5">{sensor.currentDistanceCm} cm</p>
                  </div>
                  <div className={clsx(
                    "px-2 py-1 rounded-full text-[10px] font-bold flex items-center gap-1",
                    sensor.status === 'Online' ? "bg-emerald-100 text-emerald-700" : "bg-gray-100 text-gray-500"
                  )}>
                    {sensor.status === 'Online' ? <Wifi className="w-3 h-3" /> : <WifiOff className="w-3 h-3" />}
                  </div>
                </button>
              ))
            )}
          </div>
        </div>

        {/* Right Column: Chart & Anomaly Details */}
        <div className="lg:col-span-3 space-y-6">
          
          {selectedSensor ? (
            <>
              {/* Realtime Chart */}
              <div className="bg-surface border border-gray-200 rounded-xl shadow-sm p-6">
                <div className="flex items-center justify-between mb-6">
                  <div className="flex items-center gap-2">
                    <Activity className="w-5 h-5 text-indigo-600" />
                    <h2 className="text-lg font-bold text-text">Real-time Displacement: <span className="text-indigo-600">{selectedSensor}</span></h2>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                    <span className="text-xs font-semibold text-emerald-700">LIVE MQTT</span>
                  </div>
                </div>
                
                <div className="h-80 w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={readings}>
                      <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f0f0f0" />
                      <XAxis dataKey="timestamp" tick={{fontSize: 10}} tickMargin={10} minTickGap={20} stroke="#9ca3af" />
                      <YAxis domain={['auto', 'auto']} tick={{fontSize: 12}} stroke="#9ca3af" unit=" cm" width={50} />
                      <Tooltip 
                        contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }}
                        labelStyle={{ fontWeight: 'bold', color: '#374151' }}
                      />
                      <Line 
                        type="monotone" 
                        dataKey="distance_cm" 
                        stroke="#4f46e5" 
                        strokeWidth={3}
                        dot={false}
                        activeDot={{ r: 6, fill: "#4f46e5", stroke: "#fff", strokeWidth: 2 }}
                        isAnimationActive={false} // Disable to avoid flicker on live updates
                      />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </div>

              {/* Anomaly Configuration */}
              <div className="bg-gradient-to-br from-amber-50 to-orange-50 border border-amber-200 rounded-xl shadow-sm p-6 flex items-start gap-4">
                <div className="bg-amber-100 p-3 rounded-full text-amber-600">
                  <AlertTriangle className="w-6 h-6" />
                </div>
                <div className="flex-1">
                  <h3 className="text-base font-bold text-amber-900 mb-1">Automated AI Trigger Active</h3>
                  <p className="text-sm text-amber-800/80 mb-4">
                    The backend MQTT worker is actively analyzing this data stream. If the surface displacement exceeds the variance threshold suddenly, it will automatically schedule a maintenance team.
                  </p>
                  <div className="flex items-center gap-4 bg-white/60 p-3 rounded-lg border border-amber-100 max-w-sm">
                    <label className="text-sm font-semibold text-amber-900">Variance Threshold (cm):</label>
                    <input 
                      type="number" 
                      value={threshold} 
                      onChange={(e) => setThreshold(Number(e.target.value))}
                      className="w-20 px-2 py-1 text-center rounded border border-amber-200 focus:outline-none focus:ring-2 focus:ring-amber-500"
                    />
                  </div>
                </div>
              </div>
            </>
          ) : (
            <div className="bg-surface border border-dashed border-gray-300 rounded-xl p-12 flex flex-col items-center justify-center text-center h-full">
              <Cpu className="w-12 h-12 text-gray-300 mb-4" />
              <h3 className="text-lg font-bold text-text mb-2">No Sensor Selected</h3>
              <p className="text-text-muted text-sm max-w-md">
                Select an IoT scanner from the sidebar to view real-time structural displacement readings and configure AI anomaly triggers.
              </p>
            </div>
          )}

        </div>
      </div>
    </div>
  );
}
