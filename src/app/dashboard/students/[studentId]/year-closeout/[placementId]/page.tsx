import Link from "next/link";
import { notFound } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";
import { localDateInTimezone } from "@/lib/student-login";
import { buildStudentTranscriptSnapshot } from "@/lib/student-transcript";
import { closeAcademicYear } from "./actions";

function firstRelation<T>(value: unknown): T | null {
  if (Array.isArray(value)) return (value[0] as T | undefined) ?? null;
  return (value as T | null) ?? null;
}

export default async function YearCloseoutPage({
  params,
  searchParams,
}: {
  params: Promise<{ studentId: string; placementId: string }>;
  searchParams: Promise<{ error?: string; closed?: string }>;
}) {
  const { studentId, placementId } = await params;
  const query = await searchParams;
  const { supabase, organization } = await requireOrganization();
  const today = localDateInTimezone(organization.timezone);

  const [{ data: placement }, { data: decision }, { data: gradeLevels }] = await Promise.all([
    supabase.from("student_academic_years")
      .select("id,status,start_date,end_date,academic_year_id,official_grade_level_id,academic_years(id,name,start_date,end_date,status),grade_levels(id,code,name,numeric_order)")
      .eq("organization_id", organization.id).eq("student_id", studentId).eq("id", placementId).maybeSingle(),
    supabase.from("grade_level_decisions")
      .select("id,decision,reason,decided_at,next_student_academic_year_id,closeout_snapshot")
      .eq("organization_id", organization.id).eq("student_id", studentId).eq("student_academic_year_id", placementId).maybeSingle(),
    supabase.from("grade_levels").select("id,code,name,numeric_order").eq("active", true).order("numeric_order"),
  ]);

  if (!placement) notFound();

  const [{ data: futureYears }, { count: reportCount }] = await Promise.all([
    supabase.from("academic_years").select("id,name,start_date,end_date,status")
      .eq("organization_id", organization.id).in("status", ["planned", "active"])
      .neq("id", placement.academic_year_id).gt("end_date", today).order("start_date"),
    supabase.from("report_snapshots").select("id", { count: "exact", head: true })
      .eq("organization_id", organization.id).eq("student_id", studentId)
      .eq("academic_year_id", placement.academic_year_id).eq("status", "official"),
  ]);

  const academicYear = firstRelation<{ id: string; name: string; start_date: string; end_date: string; status: string }>(placement.academic_years);
  const grade = firstRelation<{ id: string; code: string; name: string; numeric_order: number }>(placement.grade_levels);
  if (!academicYear || !grade) notFound();

  const snapshot = await buildStudentTranscriptSnapshot({ supabase, organization, studentId, recordAsOf: today });
  const year = snapshot.academic_years.find((row) => row.placement_id === placementId);
  if (!year) notFound();

  const unfinished = year.current_courses.length;
  const nextGrade = (gradeLevels ?? []).find((row) => row.numeric_order === grade.numeric_order + 1);
  const nextStartObj = new Date(`${academicYear.end_date}T12:00:00`);
  nextStartObj.setDate(nextStartObj.getDate() + 1);
  const nextStart = nextStartObj.toISOString().slice(0, 10);
  const nextEndObj = new Date(`${nextStart}T12:00:00`);
  nextEndObj.setFullYear(nextEndObj.getFullYear() + 1);
  nextEndObj.setDate(nextEndObj.getDate() - 1);
  const nextEnd = nextEndObj.toISOString().slice(0, 10);
  const nextYearStartNumber = Number(nextStart.slice(0, 4));
  const nextYearName = `${nextYearStartNumber}-${nextYearStartNumber + 1}`;

  return (
    <AppShell organizationName={organization.name}>
      <div className="grid gap-6">
        <Link href={`/dashboard/students/${studentId}`} className="text-sm font-bold text-[#23685a] hover:underline">← Back to student</Link>

        {query.error && <div className="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{query.error}</div>}
        {query.closed && <div className="rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm font-semibold text-emerald-800">Academic year closed successfully.</div>}

        <section className="overflow-hidden rounded-[26px] border border-[#d7e2dd] bg-white shadow-sm">
          <div className="bg-gradient-to-br from-[#eef7f3] via-white to-[#eef4f8] p-5 sm:p-7">
            <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-start">
              <div>
                <div className="text-xs font-bold uppercase tracking-[0.18em] text-[#23685a]">Academic year closeout</div>
                <h1 className="mt-2 text-2xl font-bold sm:text-3xl">{academicYear.name} · {grade.name}</h1>
                <p className="mt-2 text-sm text-[#617078]">Review the permanent record before recording the official year-end decision.</p>
              </div>
              <StatusPill tone={placement.status === "completed" ? "green" : "blue"}>{placement.status}</StatusPill>
            </div>
          </div>
          <div className="grid gap-3 p-5 sm:grid-cols-2 sm:p-7 lg:grid-cols-5">
            <div className="rounded-2xl bg-[#f8faf8] p-4"><div className="text-xs text-[#718087]">Completed courses</div><div className="mt-1 text-2xl font-bold">{year.completed_courses.length}</div></div>
            <div className="rounded-2xl bg-[#f8faf8] p-4"><div className="text-xs text-[#718087]">Unfinished courses</div><div className="mt-1 text-2xl font-bold">{unfinished}</div></div>
            <div className="rounded-2xl bg-[#f8faf8] p-4"><div className="text-xs text-[#718087]">Instructional days</div><div className="mt-1 text-2xl font-bold">{year.attendance.instructional_days}</div></div>
            <div className="rounded-2xl bg-[#f8faf8] p-4"><div className="text-xs text-[#718087]">Instructional minutes</div><div className="mt-1 text-2xl font-bold">{year.attendance.instructional_minutes}</div></div>
            <div className="rounded-2xl bg-[#f8faf8] p-4"><div className="text-xs text-[#718087]">Official reports</div><div className="mt-1 text-2xl font-bold">{reportCount ?? 0}</div></div>
          </div>
        </section>

        {decision ? (
          <section className="rounded-2xl border border-emerald-200 bg-[#f3fbf7] p-5 sm:p-6">
            <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#23685a]">Permanent closeout decision</div>
            <h2 className="mt-1 text-xl font-bold">{decision.decision}</h2>
            <p className="mt-2 text-sm text-[#617078]">Recorded {new Date(decision.decided_at).toLocaleString()}</p>
            {decision.reason && <div className="mt-4 rounded-xl bg-white/70 p-4 text-sm"><span className="font-bold">Reason:</span> {decision.reason}</div>}
          </section>
        ) : (
          <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
            <h2 className="text-xl font-bold">Record year-end decision</h2>
            <p className="mt-1 max-w-3xl text-sm leading-6 text-[#617078]">Promote changes only the next year&apos;s official grade placement. Unfinished subject enrollments are carried forward separately without changing their course grade level.</p>

            {unfinished > 0 && <div className="mt-4 rounded-2xl border border-[#cfdde6] bg-[#eef5fa] p-4 text-sm leading-6 text-[#345f80]">{unfinished} unfinished course{unfinished === 1 ? "" : "s"} will be preserved and carried into the next academic-year placement.</div>}

            <form action={closeAcademicYear} className="mt-5 grid gap-4">
              <input type="hidden" name="student_id" value={studentId} />
              <input type="hidden" name="placement_id" value={placementId} />

              <div className="grid gap-4 md:grid-cols-3">
                <label className="grid gap-1.5 text-sm font-semibold">Closeout date<input name="close_date" type="date" defaultValue={academicYear.end_date} min={placement.start_date} max={academicYear.end_date} required className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
                <label className="grid gap-1.5 text-sm font-semibold">Decision<select name="decision" defaultValue="promote" className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3">
                  {nextGrade && <option value="promote">Promote to {nextGrade.name}</option>}
                  <option value="retain">Retain in {grade.name}</option>
                  <option value="continue">Continue {grade.name}</option>
                  <option value="instructor_override">Instructor override</option>
                  {unfinished === 0 && <option value="graduate">Graduate</option>}
                </select></label>
                <label className="grid gap-1.5 text-sm font-semibold">Override target grade<select name="next_grade_level_id" defaultValue="" className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"><option value="">Automatic unless override</option>{(gradeLevels ?? []).map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
              </div>

              <div className="rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-4">
                <div className="font-bold">Next academic year</div>
                <p className="mt-1 text-xs leading-5 text-[#718087]">Select an existing year, or leave it blank and provide a new year below. Graduate decisions ignore these fields.</p>
                <div className="mt-4 grid gap-4 md:grid-cols-2">
                  <label className="grid gap-1.5 text-sm font-semibold">Existing academic year<select name="next_academic_year_id" defaultValue="" className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"><option value="">Create / use year below</option>{(futureYears ?? []).map((item) => <option key={item.id} value={item.id}>{item.name} · {item.start_date} to {item.end_date}</option>)}</select></label>
                  <label className="grid gap-1.5 text-sm font-semibold">New academic-year name<input name="next_academic_year_name" defaultValue={nextYearName} className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
                </div>
                <div className="mt-4 grid gap-4 md:grid-cols-2">
                  <label className="grid gap-1.5 text-sm font-semibold">New year start<input name="next_year_start" type="date" defaultValue={nextStart} className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
                  <label className="grid gap-1.5 text-sm font-semibold">New year end<input name="next_year_end" type="date" defaultValue={nextEnd} className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
                </div>
              </div>

              <label className="grid gap-1.5 text-sm font-semibold">Decision reason / notes<textarea name="reason" rows={3} placeholder="Optional unless using instructor override." className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
              <button className="w-full rounded-xl bg-[#23685a] px-5 py-3 font-bold text-white hover:bg-[#174d43] sm:w-fit">Close academic year permanently</button>
            </form>
          </section>
        )}
      </div>
    </AppShell>
  );
}
