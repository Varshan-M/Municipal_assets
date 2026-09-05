import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Nam Nagaram - Admin Portal",
  description: "Municipal Administration Web Portal",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${inter.className} antialiased h-screen flex overflow-hidden bg-background`}>
        {/* Auth Provider Wrapper will go here */}
        <div className="flex h-screen w-full">
          {children}
        </div>
      </body>
    </html>
  );
}
