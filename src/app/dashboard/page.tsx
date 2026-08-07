import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";

export default async function DashboardPage() {
  const { supabase, organization } = await requireOrganization();
  const orgId = organization.id;

  const [{ count: studentCount }, { count: activeYearCount }, { data: courseVersion }] = await Promise.all([
    supabase.from("students").select("id", { count: "exact", head: true }).eq("organization_id", orgId).eq("status", "active"),
    supabase.from("academic_years").select("id", { count: "exact", head: true }).eq("organization_id", orgId).eq("status", "active"),
    supabase.from("course_versions").select("id,title,course_code,instructional_weeks,status").eq("organization_id", orgId).eq("course_code", "1-MATH").limit(1).maybeSingle(),
  ]);

  let competencyCount = 0;
  let lessonCount = 0;
  let weekCount = 0;
  if (courseVersion?.id) {
    const [competencies, lessons, weeks] = await Promise.all([
      supabase.from("competencies").select("id", { count: "exact", head: true }).eq("course_version_id", courseVersion.id),
      supabase.from("lessons").select("id", { count: "exact", head: true }).eq("course_version_id", courseVersion.id),
      supabase.from("course_weeks").select("id", { count: "exact", head: true }).eq("course_version_id", courseVersion.id),
    ]);
    competencyCount = competencies.count ?? 0;
    lessonCount = lessons.count ?? 0;
    weekCount = weeks.count ?? 0;
  }

  return (
    <AppShell organizationName={organization.name}>
      <div className="grid gap-6">
        <section>
          <p className="text-sm font-medium text-[#667085]">Instructor dashboard</p>
          <h1 className="mt-1 text-3xl font-bold">Welcome to {organization.name}</h1>
          <p className="mt-2 text-[#667085]">This dashboard is reading from the real Supabase schema once migrations and credentials are connected.</p>
        </section>

        <section className="grid gap-4 sm:grid-cols-3">
          {[["Active students", studentCount ?? 0], ["Active academic years", activeYearCount ?? 0], ["Curriculum courses", courseVersion ? 1 : 0]].map(([label, value]) => (
            <div key={String(label)} className="rounded-2xl border border-[#e4e7ec] bg-white p-5"><div className="text-sm text-[#667085]">{label}</div><div className="mt-2 text-3xl font-bold">{value}</div></div>
          ))}
        </section>

        <section id="curriculum" className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div><div className="text-sm font-semibold text-[#315c4d]">CURRICULUM</div><h2 className="mt-1 text-xl font-bold">{courseVersion?.title ?? "Grade 1 Mathematics"}</h2></div>
            <StatusPill tone={courseVersion ? "green" : "amber"}>{courseVersion ? "Installed" : "Awaiting database setup"}</StatusPill>
          </div>
          <div className="mt-5 grid gap-3 sm:grid-cols-3">
            <div className="rounded-xl bg-[#f8faf9] p-4"><div className="text-2xl font-bold">{competencyCount || 21}</div><div className="text-sm text-[#667085]">Competencies</div></div>
            <div className="rounded-xl bg-[#f8faf9] p-4"><div className="text-2xl font-bold">{weekCount || 36}</div><div className="text-sm text-[#667085]">Instructional weeks</div></div>
            <div className="rounded-xl bg-[#f8faf9] p-4"><div className="text-2xl font-bold">{lessonCount || 180}</div><div className="text-sm text-[#667085]">Daily lessons</div></div>
          </div>
        </section>

        <section className="grid gap-4 lg:grid-cols-2">
          <div id="attendance" className="rounded-2xl border border-[#e4e7ec] bg-white p-6"><h2 className="font-bold">Attendance</h2><p className="mt-2 text-sm leading-6 text-[#667085]">The database tables and RLS are ready. The attendance confirmation workflow is a later vertical-slice step.</p></div>
          <div id="reports" className="rounded-2xl border border-[#e4e7ec] bg-white p-6"><h2 className="font-bold">Permanent reports</h2><p className="mt-2 text-sm leading-6 text-[#667085]">Progress-report and transcript snapshot tables are already included so official historical outputs can be preserved.</p></div>
        </section>

        <Link href="/dashboard/students" className="w-fit rounded-xl bg-[#315c4d] px-5 py-3 font-semibold text-white hover:bg-[#24483c]">Open student roster →</Link>
      </div>
    </AppShell>
  );
}
