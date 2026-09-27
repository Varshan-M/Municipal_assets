"use client";

import { useEffect, useState } from "react";
import { collection, doc, onSnapshot, query, updateDoc, setDoc, getDoc, orderBy, limit } from "firebase/firestore";
import { db } from "@/lib/firebase/config";
import { Bot, Settings2, Activity, CheckCircle2, ShieldAlert } from "lucide-react";
import clsx from "clsx";

interface AiConfig {
  auto_assign_enabled: boolean;
  auto_followup_enabled: boolean;
}

interface AiLog {
  id: string;
  actionType: string;
  targetId: string;
  message: string;
  timestamp: any;
}

export default function AiAgentsPage() {
  const [config, setConfig] = useState<AiConfig>({ auto_assign_enabled: true, auto_followup_enabled: true });
  const [logs, setLogs] = useState<AiLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    // 1. Initialize or listen to config
    const configRef = doc(db, "settings", "ai_config");
    
    // Ensure document exists first
    getDoc(configRef).then((docSnap) => {
      if (!docSnap.exists()) {
        setDoc(configRef, { auto_assign_enabled: true, auto_followup_enabled: true });
      }
    });

    const unsubscribeConfig = onSnapshot(configRef, (docSnap) => {
      if (docSnap.exists()) {
        setConfig(docSnap.data() as AiConfig);
      }
      setLoading(false);
    });

    // 2. Listen to AI logs
    const logsQuery = query(collection(db, "ai_logs"), orderBy("timestamp", "desc"), limit(50));
    const unsubscribeLogs = onSnapshot(logsQuery, (snapshot) => {
      const data: AiLog[] = [];
      snapshot.forEach(doc => {
        data.push({ id: doc.id, ...doc.data() } as AiLog);
      });
      setLogs(data);
    });

    return () => {
      unsubscribeConfig();
      unsubscribeLogs();
    };
  }, []);

  const toggleConfig = async (key: keyof AiConfig) => {
    setSaving(true);
    try {
      const configRef = doc(db, "settings", "ai_config");
      await updateDoc(configRef, {
        [key]: !config[key]
      });
    } catch (err) {
      console.error("Error updating config:", err);
    }
    setSaving(false);
  };

  if (loading) {
    return <div className="p-12 text-center text-text-muted">Loading AI Agents Control Panel...</div>;
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-primary flex items-center gap-2">
          <Bot className="w-6 h-6" />
          AI Workforce Agents
        </h1>
        <p className="text-text-muted mt-1">Monitor and control the automated AI systems managing your field crews.</p>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        
        {/* Left Column: Toggles */}
        <div className="xl:col-span-1 space-y-6">
          <div className="bg-surface rounded-xl border border-gray-200 shadow-sm overflow-hidden">
            <div className="p-4 border-b border-gray-200 bg-gray-50/50 flex items-center gap-2">
              <Settings2 className="w-5 h-5 text-gray-500" />
              <h2 className="text-lg font-bold text-text">Agent Controls</h2>
            </div>
            
            <div className="p-6 space-y-8">
              
              {/* Toggle 1: Auto-Assign */}
              <div className="flex items-start justify-between">
                <div className="pr-4">
                  <h3 className="font-semibold text-text flex items-center gap-2">
                    Auto-Assignment Agent
                  </h3>
                  <p className="text-sm text-text-muted mt-1">
                    Automatically verifies submitted issues, finds the nearest available crew with the required skills, and dispatches them.
                  </p>
                </div>
                <button 
                  onClick={() => toggleConfig('auto_assign_enabled')}
                  disabled={saving}
                  className={clsx(
                    "relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2",
                    config.auto_assign_enabled ? "bg-primary" : "bg-gray-200",
                    saving && "opacity-50 cursor-not-allowed"
                  )}
                >
                  <span
                    className={clsx(
                      "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                      config.auto_assign_enabled ? "translate-x-5" : "translate-x-0"
                    )}
                  />
                </button>
              </div>

              {/* Toggle 2: Auto-Followup */}
              <div className="flex items-start justify-between">
                <div className="pr-4">
                  <h3 className="font-semibold text-text flex items-center gap-2">
                    Auto-Followup Agent
                  </h3>
                  <p className="text-sm text-text-muted mt-1">
                    Uses generative AI to draft and send personalized completion messages to citizens when a crew resolves their issue.
                  </p>
                </div>
                <button 
                  onClick={() => toggleConfig('auto_followup_enabled')}
                  disabled={saving}
                  className={clsx(
                    "relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2",
                    config.auto_followup_enabled ? "bg-primary" : "bg-gray-200",
                    saving && "opacity-50 cursor-not-allowed"
                  )}
                >
                  <span
                    className={clsx(
                      "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                      config.auto_followup_enabled ? "translate-x-5" : "translate-x-0"
                    )}
                  />
                </button>
              </div>

            </div>
          </div>
          
          {/* Status Box */}
          <div className={clsx(
            "rounded-xl border p-4 shadow-sm",
            config.auto_assign_enabled && config.auto_followup_enabled ? "bg-emerald-50 border-emerald-200" : 
            (!config.auto_assign_enabled && !config.auto_followup_enabled ? "bg-red-50 border-red-200" : "bg-amber-50 border-amber-200")
          )}>
            <div className="flex items-center gap-3">
              {config.auto_assign_enabled && config.auto_followup_enabled ? (
                <CheckCircle2 className="w-8 h-8 text-emerald-600" />
              ) : (
                <ShieldAlert className={clsx("w-8 h-8", !config.auto_assign_enabled && !config.auto_followup_enabled ? "text-red-600" : "text-amber-600")} />
              )}
              <div>
                <h4 className={clsx(
                  "font-bold",
                  config.auto_assign_enabled && config.auto_followup_enabled ? "text-emerald-800" : 
                  (!config.auto_assign_enabled && !config.auto_followup_enabled ? "text-red-800" : "text-amber-800")
                )}>
                  {config.auto_assign_enabled && config.auto_followup_enabled ? "System Fully Automated" : 
                  (!config.auto_assign_enabled && !config.auto_followup_enabled ? "Automation Disabled" : "System Partially Automated")}
                </h4>
                <p className={clsx(
                  "text-xs mt-1",
                  config.auto_assign_enabled && config.auto_followup_enabled ? "text-emerald-600" : 
                  (!config.auto_assign_enabled && !config.auto_followup_enabled ? "text-red-600" : "text-amber-600")
                )}>
                  Ensure Python backend is running for agents to operate.
                </p>
              </div>
            </div>
          </div>

        </div>

        {/* Right Column: Live Logs */}
        <div className="xl:col-span-2">
          <div className="bg-gray-900 rounded-xl border border-gray-800 shadow-sm overflow-hidden h-[calc(100vh-140px)] flex flex-col">
            <div className="p-4 border-b border-gray-800 bg-gray-950 flex items-center justify-between">
              <h2 className="text-sm font-mono font-bold text-gray-300 flex items-center gap-2">
                <Activity className="w-4 h-4 text-emerald-400" />
                Live Agent Terminal
              </h2>
              <div className="flex gap-1.5">
                <div className="w-3 h-3 rounded-full bg-red-500"></div>
                <div className="w-3 h-3 rounded-full bg-yellow-500"></div>
                <div className="w-3 h-3 rounded-full bg-green-500"></div>
              </div>
            </div>
            
            <div className="p-4 flex-1 overflow-y-auto font-mono text-sm space-y-3">
              {logs.length === 0 ? (
                <div className="text-gray-500 italic">Waiting for agent activity...</div>
              ) : (
                logs.map((log) => (
                  <div key={log.id} className="border-b border-gray-800 pb-3">
                    <div className="flex gap-2 text-gray-500 text-xs mb-1">
                      <span>[{log.timestamp?.toDate().toLocaleString() || 'Just now'}]</span>
                      <span className={log.actionType === 'AUTO_ASSIGN' ? 'text-blue-400' : 'text-purple-400'}>
                        {log.actionType}
                      </span>
                      <span>Target: {log.targetId.substring(0, 8)}...</span>
                    </div>
                    <div className="text-gray-300 ml-4">
                      {">"} {log.message}
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
