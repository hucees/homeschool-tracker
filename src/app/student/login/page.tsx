import Link from "next/link";
import { redirect } from "next/navigation";
import { Brand } from "@/components/brand";
import { createClient } from "@/lib/supabase/server";
import { isSupabaseConfigured } from "@/lib/env";
import { studentLogin } from "./actions";

export default async function StudentLoginPage({ searchParams }: { searchParams: Promise<{ error?: string; school?: string }> }) {
  const params = await searchParams;

  if (isSupabaseConfigured()) {
    const supabase = await createClient();
    const { data } = await supabase.auth.getClaims();
    const userId = data?.claims?.sub;
    if (userId) {
      const { data: link } = await supabase.from("student_user_links").select("id").eq("profile_id", userId).eq("is_active", true).maybeSingle();
      if (link) redirect("/student");
      redirect("/dashboard");
    }
  }

  return (
    <main className="grid min-h-screen place-items-center bg-[#f7f8fb] px-5 py-10">
      <div className="w-full max-w-md">
        <div className="mb-6"><Brand /></div>
        <div className="rounded-3xl border border-[#e4e7ec] bg-white p-7 shadow-sm">
          <div className="text-sm font-semibold text-[#315c4d]">STUDENT PORTAL</div>
          <h1 className="mt-1 text-2xl font-bold">Student sign in</h1>
          <p className="mt-2 text-sm leading-6 text-[#667085]">Use the school code and login your instructor created for you.</p>
          {params.error && <div className="mt-5 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{params.error}</div>}
          <form action={studentLogin} className="mt-6 grid gap-4">
            <label className="grid gap-1.5 text-sm font-medium">School code<input name="school_code" required defaultValue={params.school ?? ""} autoCapitalize="none" autoCorrect="off" className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" /></label>
            <label className="grid gap-1.5 text-sm font-medium">Username<input name="username" required autoCapitalize="none" autoCorrect="off" className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" /></label>
            <label className="grid gap-1.5 text-sm font-medium">Password<input name="password" type="password" required autoComplete="current-password" className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" /></label>
            <button className="rounded-xl bg-[#315c4d] px-4 py-3 font-semibold text-white hover:bg-[#24483c]">Sign in</button>
          </form>
        </div>
        <Link href="/" className="mt-5 block text-center text-sm text-[#667085] hover:text-[#344054]">← Back to home</Link>
      </div>
    </main>
  );
}
