import { redirect } from "next/navigation";
import { Brand } from "@/components/brand";
import { createClient } from "@/lib/supabase/server";
import { isSupabaseConfigured } from "@/lib/env";
import { createHomeschool } from "./actions";

export default async function SetupPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  if (!isSupabaseConfigured()) redirect("/login");
  const params = await searchParams;
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  const userId = data?.claims?.sub;
  if (!userId) redirect("/login");

  const { data: existing } = await supabase.from("organization_members").select("id").eq("profile_id", userId).eq("status", "active").limit(1).maybeSingle();
  if (existing) redirect("/dashboard");

  return (
    <main className="min-h-screen bg-[#f7f8fb] px-5 py-10">
      <div className="mx-auto max-w-2xl">
        <Brand />
        <div className="mt-8 rounded-3xl border border-[#e4e7ec] bg-white p-7 shadow-sm">
          <div className="text-sm font-semibold uppercase tracking-wide text-[#315c4d]">First-time setup</div>
          <h1 className="mt-2 text-3xl font-bold">Create your homeschool</h1>
          <p className="mt-2 leading-7 text-[#667085]">This creates the organization, first academic year, owner membership, and installs the Grade 1 Math 2026.1 curriculum.</p>
          {params.error && <div className="mt-5 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{params.error}</div>}
          <form action={createHomeschool} className="mt-7 grid gap-5 sm:grid-cols-2">
            <label className="grid gap-1.5 text-sm font-medium sm:col-span-2">School / homeschool name<input name="name" required placeholder="Our Homeschool" className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" /></label>
            <label className="grid gap-1.5 text-sm font-medium sm:col-span-2">URL-friendly slug<input name="slug" placeholder="our-homeschool" className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" /></label>
            <label className="grid gap-1.5 text-sm font-medium sm:col-span-2">Academic year<input name="year_name" defaultValue="2026–2027" className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" /></label>
            <label className="grid gap-1.5 text-sm font-medium">Start date<input name="start_date" type="date" defaultValue="2026-08-10" className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" /></label>
            <label className="grid gap-1.5 text-sm font-medium">End date<input name="end_date" type="date" defaultValue="2027-05-21" className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" /></label>
            <button className="rounded-xl bg-[#315c4d] px-5 py-3 font-semibold text-white hover:bg-[#24483c] sm:col-span-2">Create homeschool and install curriculum</button>
          </form>
        </div>
      </div>
    </main>
  );
}
