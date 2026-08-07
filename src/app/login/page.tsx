import Link from "next/link";
import { redirect } from "next/navigation";
import { Brand } from "@/components/brand";
import { isSupabaseConfigured } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";
import { login } from "./actions";

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const configured = isSupabaseConfigured();
  const params = await searchParams;

  if (configured) {
    const supabase = await createClient();
    const { data } = await supabase.auth.getClaims();
    const userId = data?.claims?.sub;
    if (userId) {
      const { data: studentLink } = await supabase
        .from("student_user_links")
        .select("id")
        .eq("profile_id", userId)
        .eq("is_active", true)
        .limit(1)
        .maybeSingle();
      if (studentLink) redirect("/student");
      redirect("/dashboard");
    }
  }

  return (
    <main className="grid min-h-screen place-items-center bg-[#f7f8fb] px-5 py-10">
      <div className="w-full max-w-md">
        <div className="mb-6"><Brand /></div>
        <div className="rounded-3xl border border-[#e4e7ec] bg-white p-7 shadow-sm">
          <h1 className="text-2xl font-bold">Instructor sign in</h1>
          <p className="mt-2 text-sm leading-6 text-[#667085]">The first instructor account will be created in Supabase Auth during setup.</p>

          {!configured && (
            <div className="mt-5 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
              Supabase is not connected yet. This is expected on the first run. Copy <code>.env.example</code> to <code>.env.local</code> after we create the Supabase project.
            </div>
          )}
          {params.error && <div className="mt-5 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{params.error}</div>}

          <form action={login} className="mt-6 grid gap-4">
            <label className="grid gap-1.5 text-sm font-medium">Email<input name="email" type="email" autoComplete="email" required disabled={!configured} className="rounded-xl border border-[#d0d5dd] px-3.5 py-3 outline-none focus:border-[#315c4d] disabled:bg-slate-50" /></label>
            <label className="grid gap-1.5 text-sm font-medium">Password<input name="password" type="password" autoComplete="current-password" required disabled={!configured} className="rounded-xl border border-[#d0d5dd] px-3.5 py-3 outline-none focus:border-[#315c4d] disabled:bg-slate-50" /></label>
            <button disabled={!configured} className="mt-1 rounded-xl bg-[#315c4d] px-4 py-3 font-semibold text-white hover:bg-[#24483c] disabled:cursor-not-allowed disabled:bg-slate-300">Sign in</button>
          </form>
        </div>
        <Link href="/" className="mt-5 block text-center text-sm text-[#667085] hover:text-[#344054]">← Back to project home</Link>
      </div>
    </main>
  );
}
