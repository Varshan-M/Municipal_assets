'use client';

import { useEffect, useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import 'leaflet-defaulticon-compatibility';
import 'leaflet-defaulticon-compatibility/dist/leaflet-defaulticon-compatibility.css';
import L from 'leaflet';
import { Team, Complaint } from '@/types';

// Custom icons
const teamOnlineIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

const teamOfflineIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-grey.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

const complaintIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

interface MapContentProps {
  teams: Team[];
  complaints: Complaint[];
}

function AutoZoom({ teams }: { teams: Team[] }) {
  const map = useMap();
  const [now, setNow] = useState(new Date());

  useEffect(() => {
    const interval = setInterval(() => setNow(new Date()), 30000);
    return () => clearInterval(interval);
  }, []);

  const isTeamActuallyOnline = (team: Team) => {
    if (!team.isOnline) return false;
    if (!team.lastUpdated) return false;
    try {
      return (now.getTime() - team.lastUpdated.toDate().getTime()) < 180000;
    } catch {
      return false;
    }
  };
  
  useEffect(() => {
    const onlineTeams = teams.filter(t => isTeamActuallyOnline(t) && typeof t.latitude === 'number' && typeof t.longitude === 'number');
    
    if (onlineTeams.length > 0) {
      if (onlineTeams.length === 1) {
        // Fly directly to the single team
        map.flyTo([onlineTeams[0].latitude as number, onlineTeams[0].longitude as number], 15, {
          duration: 1.5,
          easeLinearity: 0.25
        });
      } else {
        // Fit bounds for multiple teams
        const bounds = L.latLngBounds(onlineTeams.map(t => [t.latitude as number, t.longitude as number]));
        map.flyToBounds(bounds, { padding: [50, 50], duration: 1.5 });
      }
    }
  }, [teams, map]);

  return null;
}

export default function MapContent({ teams, complaints }: MapContentProps) {
  const [now, setNow] = useState(new Date());

  useEffect(() => {
    const interval = setInterval(() => setNow(new Date()), 30000);
    return () => clearInterval(interval);
  }, []);

  const isTeamActuallyOnline = (team: Team) => {
    if (!team.isOnline) return false;
    if (!team.lastUpdated) return false;
    try {
      return (now.getTime() - team.lastUpdated.toDate().getTime()) < 180000;
    } catch {
      return false;
    }
  };

  // Center of the city (defaulting to Salem or typical center)
  const centerPosition: [number, number] = [11.6643, 78.1460];

  return (
    <MapContainer 
      center={centerPosition} 
      zoom={12} 
      style={{ height: '100%', width: '100%', borderRadius: '0.75rem', zIndex: 0 }}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <AutoZoom teams={teams} />

      {/* Plot Active Complaints */}
      {complaints.filter(c => c.status !== 'Resolved' && c.status !== 'Rejected').map((complaint) => {
        if (typeof complaint.latitude !== 'number' || typeof complaint.longitude !== 'number') return null;
        return (
          <Marker 
            key={complaint.id} 
            position={[complaint.latitude, complaint.longitude]}
            icon={complaintIcon}
          >
          <Popup>
            <div className="font-sans">
              <strong className="block text-red-600">{complaint.assetType} - {complaint.issueType}</strong>
              <span className="text-xs text-gray-500 block mb-1">{complaint.id.substring(0, 8).toUpperCase()}</span>
              <p className="text-sm m-0 mb-1">{complaint.address}</p>
              <span className="inline-block px-2 py-0.5 bg-yellow-100 text-yellow-800 text-xs font-medium rounded">
                {complaint.status}
              </span>
            </div>
          </Popup>
        </Marker>
        );
      })}

      {/* Plot Teams */}
      {teams.map((team) => {
        if (typeof team.latitude !== 'number' || typeof team.longitude !== 'number') return null;
        
        // Find if this team has an assigned complaint
        const assignedComplaint = complaints.find(c => 
          (c.assignedTeamId === team.id || c.assignedTeam === team.id) && 
          (c.status === 'Team Assigned' || c.status === 'Work In Progress')
        );

        return (
          <div key={`team-group-${team.id}`}>
            <Marker 
              position={[team.latitude, team.longitude]}
              icon={isTeamActuallyOnline(team) ? teamOnlineIcon : teamOfflineIcon}
            >
              <Popup>
                <div className="font-sans">
                  <strong className="block text-green-700">{team.name}</strong>
                  <div className="flex flex-wrap gap-1 my-1">
                    {team.skills?.map(skill => (
                      <span key={skill} className="px-1.5 py-0.5 bg-gray-100 text-gray-600 text-[10px] rounded">
                        {skill}
                      </span>
                    ))}
                  </div>
                  <span className={`inline-flex items-center gap-1 text-xs font-medium ${isTeamActuallyOnline(team) ? 'text-green-600' : 'text-gray-500'}`}>
                    <span className={`w-2 h-2 rounded-full ${isTeamActuallyOnline(team) ? 'bg-green-500' : 'bg-gray-400'}`}></span>
                    {isTeamActuallyOnline(team) ? 'Online' : 'Offline'}
                  </span>
                  
                  {assignedComplaint && (
                    <div className="mt-2 pt-2 border-t text-xs">
                      <strong className="block text-gray-700">Current Task:</strong>
                      {assignedComplaint.assetType}
                    </div>
                  )}
                </div>
              </Popup>
            </Marker>

            {/* Draw a line connecting the team to their assigned complaint */}
            {assignedComplaint && typeof assignedComplaint.latitude === 'number' && typeof assignedComplaint.longitude === 'number' && (
              <Polyline 
                positions={[
                  [team.latitude, team.longitude],
                  [assignedComplaint.latitude, assignedComplaint.longitude]
                ]}
                color="#3b82f6" // blue-500
                weight={3}
                dashArray="5, 10"
                opacity={0.7}
              />
            )}
          </div>
        );
      })}
    </MapContainer>
  );
}
