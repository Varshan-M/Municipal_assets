"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { 
  LayoutDashboard, 
  AlertCircle, 
  Map as MapIcon, 
  Settings, 
  LogOut, 
  Bell, 
  BarChart3, 
  Building2, 
  Users 
} from "lucide-react";
import clsx from "clsx";
import { useAuth } from "@/lib/auth/AuthContext";

const navItems = [
  { name: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  { name: "Complaints", href: "/complaints", icon: AlertCircle },
  { name: "Map", href: "/map", icon: MapIcon },
  { name: "Assets", href: "/assets", icon: Building2 },
  { name: "Teams", href: "/teams", icon: Users },
  { name: "Analytics", href: "/analytics", icon: BarChart3 },
  { name: "Notifications", href: "/notifications", icon: Bell },
  { name: "Settings", href: "/settings", icon: Settings },
];

export default function Sidebar() {
  const pathname = usePathname();
  const { logout } = useAuth();

  return (
    <aside className="w-64 bg-primary text-white flex flex-col h-screen shrink-0 hidden md:flex">
      {/* Logo Area */}
      <div className="p-6 border-b border-primary-light flex flex-col items-center justify-center">
        <img 
          src="/logo.png" 
          alt="Nam Nagaram Logo" 
          className="w-24 h-24 object-contain bg-white rounded-full p-2 mb-2 shadow-sm"
        />
        <h1 className="text-xl font-bold tracking-wider mt-2">NAM NAGARAM</h1>
        <p className="text-xs text-blue-200 mt-1 uppercase tracking-wide text-center">
          Municipal Administration
        </p>
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto py-4">
        <ul className="space-y-1 px-3">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = pathname.startsWith(item.href);
            
            return (
              <li key={item.name}>
                <Link
                  href={item.href}
                  className={clsx(
                    "flex items-center px-3 py-2.5 rounded-md transition-colors",
                    "hover:bg-primary-light",
                    isActive ? "bg-primary-light font-medium" : "text-blue-100"
                  )}
                >
                  <Icon className="w-5 h-5 mr-3" />
                  {item.name}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      {/* Admin Profile & Logout */}
      <div className="p-4 border-t border-primary-light bg-primary-light/30">
        <div className="flex items-center mb-4">
          <div className="w-10 h-10 rounded-full bg-blue-500 flex items-center justify-center font-bold text-lg mr-3">
            A
          </div>
          <div className="overflow-hidden">
            <p className="text-sm font-medium truncate">Admin User</p>
            <p className="text-xs text-blue-200 truncate">System Administrator</p>
          </div>
        </div>
        <button 
          className="w-full flex items-center justify-center py-2 text-sm text-red-300 hover:text-red-100 hover:bg-red-900/30 rounded-md transition-colors"
          onClick={logout}
        >
          <LogOut className="w-4 h-4 mr-2" />
          Sign Out
        </button>
      </div>
    </aside>
  );
}
