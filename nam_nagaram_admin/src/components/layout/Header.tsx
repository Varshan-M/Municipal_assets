"use client";

import { Bell, Search, Menu } from "lucide-react";
import { usePathname } from "next/navigation";

export default function Header() {
  const pathname = usePathname();
  const title = pathname.split('/')[1] || 'Dashboard';
  const displayTitle = title.charAt(0).toUpperCase() + title.slice(1);

  // Format current date
  const today = new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });

  return (
    <header className="h-16 bg-surface border-b border-gray-200 flex items-center justify-between px-6 shrink-0">
      <div className="flex items-center">
        <button className="md:hidden mr-4 text-text-muted hover:text-text">
          <Menu className="w-6 h-6" />
        </button>
        <h2 className="text-xl font-semibold text-text">{displayTitle}</h2>
      </div>

      <div className="flex items-center space-x-6">
        <div className="hidden lg:flex items-center text-sm text-text-muted bg-gray-100 px-3 py-1.5 rounded-full">
          {today}
        </div>
        
        <div className="relative hidden md:block">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input 
            type="text" 
            placeholder="Search ID, location..." 
            className="pl-9 pr-4 py-1.5 bg-gray-100 border-transparent rounded-full text-sm focus:border-blue-500 focus:bg-white focus:ring-2 focus:ring-blue-200 transition-all w-64"
          />
        </div>

        <button className="relative p-2 text-text-muted hover:bg-gray-100 rounded-full transition-colors">
          <Bell className="w-5 h-5" />
          <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full border border-white"></span>
        </button>
      </div>
    </header>
  );
}
