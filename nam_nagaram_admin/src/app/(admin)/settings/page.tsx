"use client";

import { Info, Code, Shield, CheckCircle, Brain, Layout, Server, Activity } from "lucide-react";

export default function SettingsPage() {
  return (
    <div className="p-6 space-y-8 max-w-5xl mx-auto">
      <div>
        <h1 className="text-2xl font-bold text-gray-800">Settings</h1>
        <p className="text-gray-500 text-sm mt-1">Platform configuration and system information</p>
      </div>

      <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <div className="bg-primary/5 p-6 border-b border-gray-200">
          <div className="flex items-center gap-3 mb-2">
            <Info className="text-primary w-6 h-6" />
            <h2 className="text-xl font-semibold text-gray-800">About NAM NAGARAM</h2>
          </div>
          <p className="text-gray-600 leading-relaxed text-sm">
            NAM NAGARAM is an autonomous Agentic AI platform for municipal infrastructure maintenance. It integrates citizen reports, IoT-based detection and computer vision into a unified maintenance workflow to detect, verify, prioritize, schedule and coordinate municipal maintenance with minimal human intervention.
          </p>
        </div>

        <div className="grid md:grid-cols-2 gap-0 divide-y md:divide-y-0 md:divide-x border-b border-gray-200 divide-gray-200">
          {/* Project Info */}
          <div className="p-6 space-y-4">
            <h3 className="font-semibold text-gray-800 flex items-center gap-2">
              <Layout className="w-4 h-4 text-gray-400" />
              Project Information
            </h3>
            <ul className="space-y-3 text-sm text-gray-600">
              <li className="flex flex-col"><span className="text-xs font-medium text-gray-400 uppercase">Project</span><span className="font-medium text-gray-800">NAM NAGARAM</span></li>
              <li className="flex flex-col"><span className="text-xs font-medium text-gray-400 uppercase">Problem Statement</span><span>Autonomous Municipal Asset Maintenance Operations</span></li>
              <li className="flex flex-col"><span className="text-xs font-medium text-gray-400 uppercase">Domain</span><span>Smart Cities</span></li>
              <li className="flex flex-col"><span className="text-xs font-medium text-gray-400 uppercase">Purpose</span><span>Proactive and intelligent municipal infrastructure maintenance</span></li>
              <li className="flex flex-col"><span className="text-xs font-medium text-gray-400 uppercase">Status</span><span className="inline-flex items-center gap-1.5 px-2 py-1 rounded-md bg-blue-50 text-blue-700 font-medium text-xs w-max mt-1 border border-blue-100"><Activity className="w-3 h-3" /> Active Development / Prototype</span></li>
            </ul>
          </div>

          {/* Tech Stack */}
          <div className="p-6 space-y-4">
            <h3 className="font-semibold text-gray-800 flex items-center gap-2">
              <Code className="w-4 h-4 text-gray-400" />
              Technology Stack
            </h3>
            <div className="flex flex-wrap gap-2">
              <TechBadge name="Next.js 15" />
              <TechBadge name="React 19" />
              <TechBadge name="TypeScript" />
              <TechBadge name="Tailwind CSS" />
              <TechBadge name="Firebase Auth" />
              <TechBadge name="Firestore" />
              <TechBadge name="Leaflet Maps" />
              <TechBadge name="Lucide Icons" />
            </div>
          </div>
        </div>

        <div className="grid md:grid-cols-2 gap-0 divide-y md:divide-y-0 md:divide-x divide-gray-200">
          {/* Core Capabilities */}
          <div className="p-6 space-y-4">
            <h3 className="font-semibold text-gray-800 flex items-center gap-2">
              <Shield className="w-4 h-4 text-gray-400" />
              Core Capabilities
            </h3>
            <ul className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm text-gray-600">
              <CapabilityItem name="AI Asset & Problem Verification" />
              <CapabilityItem name="Intelligent Priority Ranking" />
              <CapabilityItem name="Autonomous Scheduling" />
              <CapabilityItem name="Crew Assignment" />
              <CapabilityItem name="Citizen + IoT Issue Detection" />
              <CapabilityItem name="Repair Verification" />
              <CapabilityItem name="Citizen Notification" />
              <CapabilityItem name="Supervisor Agent Monitoring & Self-Correction" />
              <CapabilityItem name="Municipal Analytics" />
            </ul>
          </div>

          {/* AI Agents */}
          <div className="p-6 space-y-4">
            <h3 className="font-semibold text-gray-800 flex items-center gap-2">
              <Brain className="w-4 h-4 text-gray-400" />
              Agentic AI System
            </h3>
            <ul className="space-y-2 text-sm text-gray-600">
              <AgentItem name="Verification Agent" desc="Validates citizen reports and IoT data" />
              <AgentItem name="Priority Ranking Agent" desc="Determines urgency based on impact and safety" />
              <AgentItem name="Scheduling Agent" desc="Optimizes repair timelines" />
              <AgentItem name="Crew Assignment Agent" desc="Matches skills and location to tasks" />
              <AgentItem name="Auto Follow-Up Agent" desc="Handles citizen notifications" />
              <AgentItem name="Supervisor Agent" desc="Monitors system health and resolves agent conflicts" />
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}

function TechBadge({ name }: { name: string }) {
  return (
    <span className="px-2.5 py-1 bg-gray-100 text-gray-700 text-xs font-medium rounded-md border border-gray-200">
      {name}
    </span>
  );
}

function CapabilityItem({ name }: { name: string }) {
  return (
    <li className="flex items-start gap-2">
      <CheckCircle className="w-4 h-4 text-green-500 mt-0.5 shrink-0" />
      <span>{name}</span>
    </li>
  );
}

function AgentItem({ name, desc }: { name: string; desc: string }) {
  return (
    <li className="flex flex-col p-2 bg-gray-50 rounded-md border border-gray-100">
      <span className="font-medium text-gray-800">{name}</span>
      <span className="text-xs text-gray-500">{desc}</span>
    </li>
  );
}
