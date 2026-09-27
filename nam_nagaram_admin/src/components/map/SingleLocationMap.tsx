'use client';

import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import 'leaflet-defaulticon-compatibility';
import 'leaflet-defaulticon-compatibility/dist/leaflet-defaulticon-compatibility.css';
import L from 'leaflet';

const complaintIcon = new L.Icon({
  iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png',
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41]
});

interface SingleLocationMapProps {
  latitude: number;
  longitude: number;
  title: string;
  subtitle: string;
}

export default function SingleLocationMap({ latitude, longitude, title, subtitle }: SingleLocationMapProps) {
  return (
    <MapContainer 
      center={[latitude, longitude]} 
      zoom={16} 
      style={{ height: '100%', width: '100%', zIndex: 0 }}
      scrollWheelZoom={false}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <Marker position={[latitude, longitude]} icon={complaintIcon}>
        <Popup>
          <div className="font-sans">
            <strong className="block text-red-600">{title}</strong>
            <span className="text-xs text-gray-600 block">{subtitle}</span>
          </div>
        </Popup>
      </Marker>
    </MapContainer>
  );
}
