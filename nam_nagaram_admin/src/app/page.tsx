import { redirect } from "next/navigation";

export default function Home() {
  // For now, redirect to dashboard.
  // Later we will check auth state and redirect to /login or /dashboard.
  redirect("/dashboard");
}
