import Link from "next/link";
import { Brand } from "@/components/brand";
import { isSupabaseConfigured } from "@/lib/env";

export default function StudentPortalPlaceholder() {
  return (
    <main className="min-h-screen bg-[#f7f8fb] px-5 py-10">
      <div className="mx-auto max-w-3xl"><Brand /><div className="mt-10 rounded-3xl border border-[#e4e7ec] bg-white p-8"><div className="text-sm font-semibold text-[#315c4d]">STUDENT PORTAL</div><h1 className="mt-2 text-3xl font-bold">Chromebook experience scaffold</h1><p className="mt-3 leading-7 text-[#667085]">This route is intentionally waiting for the next vertical slice: student account linking, today’s assigned lessons, completion checkboxes, minutes worked, and daily learning notes.</p><div className="mt-5 rounded-xl bg-[#f8faf9] p-4 text-sm">Supabase configuration: <strong>{isSupabaseConfigured() ? "connected" : "not connected yet"}</strong></div><Link href="/" className="mt-6 inline-block font-semibold text-[#315c4d]">← Project home</Link></div></div>
    </main>
  );
}
