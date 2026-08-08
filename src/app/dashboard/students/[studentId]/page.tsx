import Link from "next/link";
import { notFound } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";
import { isSupabaseAdminConfigured } from "@/lib/env";

function firstRelation<T>(value: unknown): T | null {
  if (Array.isArray(value)) return (value[0] as T | undefined) ?? null;
  return (value as T | null) ?? null;
}

export default async function StudentDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ studentId: string }>;
  searchParams: Promise<{ login_created?: string; password_reset?: string; error?: string }>;
}) {
  const { studentId } = await params;
  const query = await searchParams;
  const { supabase, organization } = await requireOrganization();

  const [
    { data: student },
    { data: placement },
    { data: enrollments },
    { data: loginLink },
    { count: assignmentCount },
    { count: gradeCount },
    { count: reportCount },
    { count: transcriptCount },
  ] = await Promise.all([
    supabase.from("students").select("id,student_number,first_name,middle_name,last_name,preferred_name,date_of_birth,enrollment_date,status").eq("organization_id", organization.id).eq("id", studentId).maybeSingle(),
    supabase.from("student_academic_years").select("id,status,start_date,end_date,grade_levels(name,code),academic_years(name,status)").eq("organization_id", organization.id).eq("student_id", studentId).eq("status", "active").limit(1).maybeSingle(),
    supabase.from("student_course_enrollments").select("id,status,start_date,end_date,attempt_number,course_versions(title,course_code)").eq("organization_id", organization.id).eq("student_id", studentId).in("status", ["planned", "active", "completed"]).order("start_date"),
    supabase.from("student_user_links").select("id,login_username,is_active,created_at,disabled_at").eq("organization_id", organization.id).eq("student_id", studentId).maybeSingle(),
    supabase.from("student_assignments").select("id", { count: "exact", head: true }).eq("organization_id", organization.id).eq("student_id", studentId).neq("status", "cancelled"),
    supabase.from("grade_records").select("id", { count: "exact", head: true }).eq("organization_id", organization.id).eq("student_id", studentId).eq("status", "current"),
    supabase.from("report_snapshots").select("id", { count: "exact", head: true }).eq("organization_id", organization.id).eq("student_id", studentId).eq("status", "official"),
    supabase.from("transcript_snapshots").select("id", { count: "exact", head: true }).eq("organization_id", organization.id).eq("student_id", studentId).eq("status", "official"),
  ]);

  if (!student) notFound();

  const grade = firstRelation<{ name: string; code: string }>(placement?.grade_levels);
  const academicYear = firstRelation<{ name: string; status: string }>(placement?.academic_years);

  return (
    <AppShell organizationName={organization.name}>
      <div className="grid gap-6">
        <div>
          <Link href="/dashboard/students" className="text-sm font-bold text-[#23685a] hover:underline">
            ← Back to students
          </Link>
        </div>

        {query.login_created && <div className="rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800">Student login created. Username: <strong>{query.login_created}</strong></div>}
        {query.password_reset && <div className="rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800">Student password updated successfully.</div>}
        {query.error && <div className="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{query.error}</div>}

        <section className="app-surface rounded-[26px] p-5 sm:p-8">
          <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-start">
            <div>
              <p className="text-sm font-medium text-[#617078]">Student record</p>
              <h1 className="mt-1 text-2xl font-bold sm:text-3xl">{student.preferred_name || student.first_name} {student.last_name}</h1>
              <p className="mt-2 text-sm text-[#617078]">{student.student_number} · Enrolled {student.enrollment_date}</p>
            </div>
            <StatusPill>{student.status}</StatusPill>
          </div>

          <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <div className="rounded-2xl bg-[#f6faf8] p-4">
              <div className="text-xs font-bold uppercase tracking-wide text-[#718087]">Official placement</div>
              <div className="mt-2 font-bold">{grade?.name ?? "No active grade placement"}</div>
              <div className="mt-1 text-sm text-[#617078]">{academicYear?.name ?? "No active academic year"}</div>
            </div>
            <div className="rounded-2xl bg-[#f6faf8] p-4">
              <div className="text-xs font-bold uppercase tracking-wide text-[#718087]">Student login</div>
              {loginLink ? <><div className="mt-2 font-bold">{loginLink.login_username}</div><div className="mt-1 text-sm text-[#617078]">{loginLink.is_active ? "Active" : "Disabled"}</div></> : <div className="mt-2 text-sm text-[#617078]">No login account yet.</div>}
            </div>
            <div className="rounded-2xl bg-[#f6faf8] p-4 sm:col-span-2 lg:col-span-1">
              <div className="text-xs font-bold uppercase tracking-wide text-[#718087]">Academic records</div>
              <div className="mt-2 font-bold">{gradeCount ?? 0} current grade(s)</div>
              <div className="mt-1 text-sm text-[#617078]">{assignmentCount ?? 0} assessment(s) · {reportCount ?? 0} report(s) · {transcriptCount ?? 0} transcript(s)</div>
            </div>
          </div>
        </section>

        <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
          <div className="app-surface rounded-2xl p-5 sm:p-6">
            <div className="flex h-full flex-col justify-between gap-5">
              <div><h2 className="text-lg font-bold">Student portal</h2><p className="mt-1 text-sm text-[#617078]">School code: <strong>{organization.slug}</strong></p></div>
              <Link href={`/dashboard/students/${student.id}/login`} className="w-fit rounded-xl bg-[#23685a] px-4 py-2.5 text-sm font-bold text-white hover:bg-[#174d43]">{loginLink ? "Manage login" : "Create login"}</Link>
            </div>
            {!isSupabaseAdminConfigured() && <div className="mt-4 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">Student Auth management needs the server-only <code>SUPABASE_SECRET_KEY</code> in <code>.env.local</code>.</div>}
          </div>

          <div className="app-surface rounded-2xl p-5 sm:p-6">
            <div className="flex h-full flex-col justify-between gap-5">
              <div><h2 className="text-lg font-bold">Assignments & grades</h2><p className="mt-1 text-sm text-[#617078]">Assessments, grades, and competency mastery.</p></div>
              <Link href={`/dashboard/students/${student.id}/gradebook`} className="w-fit rounded-xl bg-[#23685a] px-4 py-2.5 text-sm font-bold text-white hover:bg-[#174d43]">Open gradebook</Link>
            </div>
          </div>

          <div className="app-surface rounded-2xl p-5 sm:p-6">
            <div className="flex h-full flex-col justify-between gap-5">
              <div><h2 className="text-lg font-bold">Progress & reports</h2><p className="mt-1 text-sm text-[#617078]">Attendance, progress, and report snapshots.</p></div>
              <Link href={`/dashboard/students/${student.id}/progress`} className="w-fit rounded-xl bg-[#456f91] px-4 py-2.5 text-sm font-bold text-white hover:bg-[#345f80]">View progress</Link>
            </div>
          </div>

          <div className="app-surface rounded-2xl p-5 sm:p-6">
            <div className="flex h-full flex-col justify-between gap-5">
              <div><h2 className="text-lg font-bold">Academic record</h2><p className="mt-1 text-sm text-[#617078]">Cumulative history and official transcripts.</p></div>
              <Link href={`/dashboard/students/${student.id}/transcript`} className="w-fit rounded-xl bg-[#456f91] px-4 py-2.5 text-sm font-bold text-white hover:bg-[#345f80]">Open record</Link>
            </div>
          </div>
        </section>

        <section className="app-surface rounded-2xl p-5 sm:p-6">
          <div>
            <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">Subject placement</div>
            <h2 className="mt-1 text-xl font-bold">Courses & progression</h2>
            <p className="mt-1 text-sm text-[#617078]">Course advancement is independent from the student&apos;s official grade placement.</p>
          </div>

          <div className="mt-4 grid gap-3">
            {enrollments?.length ? enrollments.map((enrollment) => {
              const course = firstRelation<{ title: string; course_code: string }>(enrollment.course_versions);
              return (
                <div key={enrollment.id} className="flex flex-col justify-between gap-4 rounded-2xl border border-[#dfe7e3] bg-[#fbfcfb] p-4 sm:flex-row sm:items-center">
                  <div>
                    <div className="font-bold">{course?.title ?? "Course"}</div>
                    <div className="mt-1 text-sm text-[#617078]">{course?.course_code} · Attempt {enrollment.attempt_number} · Started {enrollment.start_date}</div>
                    <div className="mt-2"><StatusPill tone={enrollment.status === "completed" ? "green" : enrollment.status === "active" ? "blue" : "gray"}>{enrollment.status}</StatusPill></div>
                  </div>
                  <Link href={`/dashboard/students/${student.id}/courses/${enrollment.id}`} className="inline-flex w-full justify-center rounded-xl border border-[#b9cec5] bg-white px-4 py-2.5 text-sm font-bold text-[#23685a] hover:bg-[#edf7f3] sm:w-auto">{enrollment.status === "completed" ? "View completion" : "Review completion"}</Link>
                </div>
              );
            }) : <p className="text-sm text-[#617078]">No course enrollments assigned.</p>}
          </div>
        </section>
      </div>
    </AppShell>
  );
}
