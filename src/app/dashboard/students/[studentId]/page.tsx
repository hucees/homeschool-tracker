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
  ] = await Promise.all([
    supabase
      .from("students")
      .select("id,student_number,first_name,middle_name,last_name,preferred_name,date_of_birth,enrollment_date,status")
      .eq("organization_id", organization.id)
      .eq("id", studentId)
      .maybeSingle(),
    supabase
      .from("student_academic_years")
      .select("id,status,start_date,end_date,grade_levels(name,code),academic_years(name,status)")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .eq("status", "active")
      .limit(1)
      .maybeSingle(),
    supabase
      .from("student_course_enrollments")
      .select("id,status,start_date,course_versions(title,course_code)")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .in("status", ["planned", "active"])
      .order("start_date"),
    supabase
      .from("student_user_links")
      .select("id,login_username,is_active,created_at,disabled_at")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .maybeSingle(),
    supabase
      .from("student_assignments")
      .select("id", { count: "exact", head: true })
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .neq("status", "cancelled"),
    supabase
      .from("grade_records")
      .select("id", { count: "exact", head: true })
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .eq("status", "current"),
    supabase
      .from("report_snapshots")
      .select("id", { count: "exact", head: true })
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .eq("status", "official"),
  ]);

  if (!student) notFound();

  const grade = firstRelation<{ name: string; code: string }>(placement?.grade_levels);
  const academicYear = firstRelation<{ name: string; status: string }>(placement?.academic_years);

  return (
    <AppShell organizationName={organization.name}>
      <div className="grid gap-6">
        <div>
          <Link href="/dashboard/students" className="text-sm font-semibold text-[#315c4d] hover:underline">← Back to students</Link>
        </div>

        {query.login_created && (
          <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800">
            Student login created. Username: <strong>{query.login_created}</strong>
          </div>
        )}
        {query.password_reset && (
          <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800">Student password updated successfully.</div>
        )}
        {query.error && <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{query.error}</div>}

        <section className="rounded-2xl border border-[#e4e7ec] bg-white p-6 sm:p-8">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <p className="text-sm font-medium text-[#667085]">Student record</p>
              <h1 className="mt-1 text-3xl font-bold">{student.preferred_name || student.first_name} {student.last_name}</h1>
              <p className="mt-2 text-sm text-[#667085]">{student.student_number} · Enrolled {student.enrollment_date}</p>
            </div>
            <StatusPill>{student.status}</StatusPill>
          </div>

          <div className="mt-6 grid gap-4 md:grid-cols-3">
            <div className="rounded-xl bg-[#f8faf9] p-4">
              <div className="text-xs font-semibold uppercase tracking-wide text-[#667085]">Official placement</div>
              <div className="mt-2 font-semibold">{grade?.name ?? "No active grade placement"}</div>
              <div className="mt-1 text-sm text-[#667085]">{academicYear?.name ?? "No active academic year"}</div>
            </div>

            <div className="rounded-xl bg-[#f8faf9] p-4">
              <div className="text-xs font-semibold uppercase tracking-wide text-[#667085]">Student login</div>
              {loginLink ? (
                <>
                  <div className="mt-2 font-semibold">{loginLink.login_username}</div>
                  <div className="mt-1 text-sm text-[#667085]">{loginLink.is_active ? "Active" : "Disabled"}</div>
                </>
              ) : (
                <div className="mt-2 text-sm text-[#667085]">No login account yet.</div>
              )}
            </div>

            <div className="rounded-xl bg-[#f8faf9] p-4">
              <div className="text-xs font-semibold uppercase tracking-wide text-[#667085]">Academic records</div>
              <div className="mt-2 font-semibold">{gradeCount ?? 0} current grade(s)</div>
              <div className="mt-1 text-sm text-[#667085]">{assignmentCount ?? 0} assessment(s) · {reportCount ?? 0} official report(s)</div>
            </div>
          </div>
        </section>

        <section className="grid gap-4 lg:grid-cols-3">
          <div className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
            <div className="flex h-full flex-col justify-between gap-5">
              <div>
                <h2 className="text-xl font-bold">Student portal access</h2>
                <p className="mt-1 text-sm text-[#667085]">School code: <strong>{organization.slug}</strong></p>
              </div>
              <Link href={`/dashboard/students/${student.id}/login`} className="w-fit rounded-xl bg-[#315c4d] px-4 py-2.5 text-sm font-semibold text-white hover:bg-[#24483c]">
                {loginLink ? "Manage login" : "Create login"}
              </Link>
            </div>

            {!isSupabaseAdminConfigured() && (
              <div className="mt-4 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
                Student Auth management needs the server-only <code>SUPABASE_SECRET_KEY</code> in <code>.env.local</code>.
              </div>
            )}
          </div>

          <div className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
            <div className="flex h-full flex-col justify-between gap-5">
              <div>
                <h2 className="text-xl font-bold">Assignments & grades</h2>
                <p className="mt-1 text-sm text-[#667085]">Assign assessments, enter grades, and review competency mastery.</p>
              </div>
              <Link href={`/dashboard/students/${student.id}/gradebook`} className="w-fit rounded-xl bg-[#315c4d] px-4 py-2.5 text-sm font-semibold text-white hover:bg-[#24483c]">
                Open gradebook
              </Link>
            </div>
          </div>

          <div className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
            <div className="flex h-full flex-col justify-between gap-5">
              <div>
                <h2 className="text-xl font-bold">Progress & reports</h2>
                <p className="mt-1 text-sm text-[#667085]">Review course progress, attendance, competency status, and permanent report snapshots.</p>
              </div>
              <Link href={`/dashboard/students/${student.id}/progress`} className="w-fit rounded-xl bg-[#315c4d] px-4 py-2.5 text-sm font-semibold text-white hover:bg-[#24483c]">
                View progress
              </Link>
            </div>
          </div>
        </section>

        <section className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
          <h2 className="text-xl font-bold">Active courses</h2>
          <div className="mt-4 grid gap-3">
            {enrollments?.length ? enrollments.map((enrollment) => {
              const course = firstRelation<{ title: string; course_code: string }>(enrollment.course_versions);
              return (
                <div key={enrollment.id} className="rounded-xl border border-[#eaecf0] p-4">
                  <div className="font-semibold">{course?.title ?? "Course"}</div>
                  <div className="mt-1 text-sm text-[#667085]">{course?.course_code} · Started {enrollment.start_date}</div>
                </div>
              );
            }) : <p className="text-sm text-[#667085]">No active courses assigned.</p>}
          </div>
        </section>
      </div>
    </AppShell>
  );
}
