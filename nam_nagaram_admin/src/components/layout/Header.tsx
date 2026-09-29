"use client";

import { Bell, Menu } from "lucide-react";
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
      </div>
    </header>
  );
}
