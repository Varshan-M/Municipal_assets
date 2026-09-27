import dynamic from 'next/dynamic';
import { Team, Complaint } from '@/types';

// Dynamically import the MapContent component with SSR disabled
const MapContent = dynamic(() => import('./MapContent'), { 
  ssr: false,
  loading: () => (
    <div className="w-full h-full flex items-center justify-center bg-gray-100 rounded-xl">
      <div className="flex flex-col items-center">
        <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-600 mb-4"></div>
        <p className="text-gray-500 font-medium">Loading live map...</p>
      </div>
    </div>
  )
});

interface LiveMapProps {
  teams: Team[];
  complaints: Complaint[];
}

export default function LiveMap({ teams, complaints }: LiveMapProps) {
  return (
    <div className="w-full h-full rounded-xl overflow-hidden border border-gray-200 shadow-sm relative z-0">
      <MapContent teams={teams} complaints={complaints} />
    </div>
  );
}
