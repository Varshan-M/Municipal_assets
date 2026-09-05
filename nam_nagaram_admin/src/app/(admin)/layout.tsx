import Sidebar from "@/components/layout/Sidebar";
import Header from "@/components/layout/Header";
import { ReactNode } from "react";
import { AuthProvider } from "@/lib/auth/AuthContext";
import AuthGuard from "@/components/layout/AuthGuard";

export default function AdminLayout({ children }: { children: ReactNode }) {
  return (
    <AuthProvider>
      <AuthGuard>
        <div className="flex h-screen w-full bg-background overflow-hidden">
          <Sidebar />
          <div className="flex flex-col flex-1 overflow-hidden">
            <Header />
            <main className="flex-1 overflow-y-auto p-6">
              {children}
            </main>
          </div>
        </div>
      </AuthGuard>
    </AuthProvider>
  );
}
