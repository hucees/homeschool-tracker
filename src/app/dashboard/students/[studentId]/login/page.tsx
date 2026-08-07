import Link from "next/link";
import { notFound } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { requireOrganization } from "@/lib/auth";
import { isSupabaseAdminConfigured } from "@/lib/env";
import { createStudentLogin, resetStudentPassword } from "./actions";

export default async function StudentLoginManagementPage({ params }: { params: Promise<{ studentId: string }> }) {
  const { studentId } = await params;
  const { supabase, organization } = await requireOrganization();

  const [{ data: student }, { data: loginLink }] = await Promise.all([
    supabase
      .from("students")
      .select("id,first_name,last_name,preferred_name,student_number")
      .eq("organization_id", organization.id)
      .eq("id", studentId)
      .maybeSingle(),
    supabase
      .from("student_user_links")
      .select("id,login_username,is_active")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .maybeSingle(),
  ]);

  if (!student) notFound();

  return (
    <AppShell organizationName={organization.name}>
      <div className="mx-auto max-w-2xl">
        <Link href={`/dashboard/students/${student.id}`} className="text-sm font-semibold text-[#315c4d] hover:underline">← Back to student</Link>
        <section className="mt-5 rounded-2xl border border-[#e4e7ec] bg-white p-6 sm:p-8">
          <p className="text-sm font-medium text-[#667085]">Student portal access</p>
          <h1 className="mt-1 text-3xl font-bold">{student.preferred_name || student.first_name} {student.last_name}</h1>
          <p className="mt-2 text-sm text-[#667085]">School code: <strong>{organization.slug}</strong></p>

          {!isSupabaseAdminConfigured() && (
            <div className="mt-5 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
              Add <code>SUPABASE_SECRET_KEY</code> to <code>.env.local</code> before using this page. This secret stays server-only and must never be committed to GitHub.
            </div>
          )}

          {!loginLink ? (
            <form action={createStudentLogin} className="mt-7 grid gap-4">
              <input type="hidden" name="student_id" value={student.id} />
              <label className="grid gap-1.5 text-sm font-medium">
                Username
                <input name="username" required minLength={3} maxLength={20} autoCapitalize="none" autoCorrect="off" placeholder="alex" className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" />
                <span className="text-xs font-normal text-[#667085]">3–20 lowercase letters/numbers; dots, underscores and hyphens are allowed.</span>
              </label>
              <label className="grid gap-1.5 text-sm font-medium">Password<input name="password" type="password" required minLength={8} className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" /></label>
              <label className="grid gap-1.5 text-sm font-medium">Confirm password<input name="confirm_password" type="password" required minLength={8} className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" /></label>
              <button disabled={!isSupabaseAdminConfigured()} className="rounded-xl bg-[#315c4d] px-5 py-3 font-semibold text-white hover:bg-[#24483c] disabled:cursor-not-allowed disabled:bg-slate-300">Create student login</button>
            </form>
          ) : (
            <div className="mt-7 grid gap-6">
              <div className="rounded-xl bg-[#f8faf9] p-4">
                <div className="text-xs font-semibold uppercase tracking-wide text-[#667085]">Current username</div>
                <div className="mt-2 text-xl font-bold">{loginLink.login_username}</div>
                <div className="mt-1 text-sm text-[#667085]">Status: {loginLink.is_active ? "Active" : "Disabled"}</div>
              </div>
              <form action={resetStudentPassword} className="grid gap-4">
                <input type="hidden" name="student_id" value={student.id} />
                <h2 className="text-lg font-bold">Reset password</h2>
                <label className="grid gap-1.5 text-sm font-medium">New password<input name="password" type="password" required minLength={8} className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" /></label>
                <label className="grid gap-1.5 text-sm font-medium">Confirm new password<input name="confirm_password" type="password" required minLength={8} className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" /></label>
                <button disabled={!isSupabaseAdminConfigured()} className="w-fit rounded-xl bg-[#315c4d] px-5 py-3 font-semibold text-white hover:bg-[#24483c] disabled:bg-slate-300">Update password</button>
              </form>
            </div>
          )}
        </section>
      </div>
    </AppShell>
  );
}
