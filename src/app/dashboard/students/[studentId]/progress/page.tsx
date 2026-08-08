import Link from "next/link";
import { notFound } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";
import { localDateInTimezone } from "@/lib/student-login";
import {
  buildStudentProgressSnapshot,
  type CompetencyProgressSnapshot,
} from "@/lib/student-progress";
import { generateOfficialReport } from "./actions";

function competencyTone(status: CompetencyProgressSnapshot["status"]) {
  if (status === "Mastered" || status === "Proficient") return "green" as const;
  if (status === "Practicing" || status === "Needs review") return "amber" as const;
  return "gray" as const;
}

function reportLabel(value: string) {
  return {
    progress_report: "Progress Report",
    quarter_report: "Quarter Report",
    semester_report: "Semester Report",
    annual_report: "Annual Report",
    attendance_report: "Attendance Report",
    competency_report: "Competency Report",
  }[value] ?? value;
}

export default async function StudentProgressPage({
  params,
  searchParams,
}: {
  params: Promise<{ studentId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { studentId } = await params;
  const query = await searchParams;
  const { supabase, organization } = await requireOrganization();
  const today = localDateInTimezone(organization.timezone);

  let snapshot;
  try {
    snapshot = await buildStudentProgressSnapshot({
      supabase,
      organization,
      studentId,
      periodEnd: today,
    });
  } catch {
    notFound();
  }

  const { data: reportData } = await supabase
    .from("report_snapshots")
    .select("id,version,report_type,status,period_start,period_end,generated_at,snapshot_sha256")
    .eq("organization_id", organization.id)
    .eq("student_id", studentId)
    .order("generated_at", { ascending: false })
    .limit(12);

  const reports = reportData ?? [];
  const studentName =
    snapshot.student.preferred_name ||
    `${snapshot.student.first_name} ${snapshot.student.last_name}`;

  return (
    <AppShell organizationName={organization.name}>
      <div className="grid gap-6">
        <div>
          <Link
            href={`/dashboard/students/${studentId}`}
            className="text-sm font-semibold text-[#315c4d] hover:underline"
          >
            ← Back to student
          </Link>
        </div>

        <section>
          <p className="text-sm font-medium text-[#667085]">Academic progress</p>
          <h1 className="mt-1 text-3xl font-bold">{studentName}</h1>
          <p className="mt-2 text-[#667085]">
            {snapshot.academic_year.official_grade_name} · {snapshot.academic_year.name} · Live through {today}
          </p>
        </section>

        {query.error && (
          <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
            {query.error}
          </div>
        )}

        <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-2xl border border-[#e4e7ec] bg-white p-5">
            <div className="text-xs font-semibold uppercase tracking-wide text-[#667085]">Present days</div>
            <div className="mt-2 text-3xl font-bold">{snapshot.attendance.present_days}</div>
          </div>
          <div className="rounded-2xl border border-[#e4e7ec] bg-white p-5">
            <div className="text-xs font-semibold uppercase tracking-wide text-[#667085]">Partial days</div>
            <div className="mt-2 text-3xl font-bold">{snapshot.attendance.partial_days}</div>
          </div>
          <div className="rounded-2xl border border-[#e4e7ec] bg-white p-5">
            <div className="text-xs font-semibold uppercase tracking-wide text-[#667085]">Absent days</div>
            <div className="mt-2 text-3xl font-bold">{snapshot.attendance.absent_days}</div>
          </div>
          <div className="rounded-2xl border border-[#e4e7ec] bg-white p-5">
            <div className="text-xs font-semibold uppercase tracking-wide text-[#667085]">Instructional minutes</div>
            <div className="mt-2 text-3xl font-bold">{snapshot.attendance.instructional_minutes}</div>
          </div>
        </section>

        <section className="grid gap-5">
          <div>
            <h2 className="text-xl font-bold">Course progress</h2>
            <p className="mt-1 text-sm text-[#667085]">
              Lesson completion is cumulative through today. Grade and attendance figures use the current academic-year reporting period.
            </p>
          </div>

          {snapshot.courses.length ? snapshot.courses.map((course) => (
            <article key={course.enrollment_id} className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
              <div className="flex flex-wrap items-start justify-between gap-4">
                <div>
                  <div className="text-sm font-semibold text-[#315c4d]">{course.course_code}</div>
                  <h3 className="mt-1 text-2xl font-bold">{course.title}</h3>
                  <div className="mt-1 text-sm text-[#667085]">
                    {course.current_week > 0
                      ? `Week ${course.current_week} of ${course.instructional_weeks}`
                      : `0 of ${course.instructional_weeks} instructional weeks started`}
                  </div>
                </div>

                <div className="text-right">
                  {course.current_grade_percent !== null ? (
                    <>
                      <div className="text-3xl font-bold">{course.current_grade_percent.toFixed(1)}%</div>
                      <div className="text-sm text-[#667085]">{course.current_letter_grade} · {course.graded_assignments} graded</div>
                    </>
                  ) : (
                    <StatusPill tone="gray">No grade yet</StatusPill>
                  )}
                </div>
              </div>

              <div className="mt-5">
                <div className="flex justify-between text-sm">
                  <span>Lessons completed</span>
                  <span className="font-semibold">{course.lessons_completed} / {course.lessons_total}</span>
                </div>
                <div className="mt-2 h-2 overflow-hidden rounded-full bg-slate-100">
                  <div
                    className="h-full rounded-full bg-[#315c4d]"
                    style={{ width: `${Math.min(course.lesson_progress_percent, 100)}%` }}
                  />
                </div>
              </div>

              <div className="mt-5 grid gap-3 sm:grid-cols-3 lg:grid-cols-6">
                <div className="rounded-xl bg-emerald-50 p-3">
                  <div className="text-xs font-medium text-emerald-700">Mastered</div>
                  <div className="mt-1 text-xl font-bold text-emerald-900">{course.competency_counts.mastered}</div>
                </div>
                <div className="rounded-xl bg-emerald-50 p-3">
                  <div className="text-xs font-medium text-emerald-700">Proficient</div>
                  <div className="mt-1 text-xl font-bold text-emerald-900">{course.competency_counts.proficient}</div>
                </div>
                <div className="rounded-xl bg-amber-50 p-3">
                  <div className="text-xs font-medium text-amber-700">Practicing</div>
                  <div className="mt-1 text-xl font-bold text-amber-900">{course.competency_counts.practicing}</div>
                </div>
                <div className="rounded-xl bg-amber-50 p-3">
                  <div className="text-xs font-medium text-amber-700">Needs review</div>
                  <div className="mt-1 text-xl font-bold text-amber-900">{course.competency_counts.needs_review}</div>
                </div>
                <div className="rounded-xl bg-slate-50 p-3">
                  <div className="text-xs font-medium text-slate-600">Not started</div>
                  <div className="mt-1 text-xl font-bold text-slate-800">{course.competency_counts.not_started}</div>
                </div>
                <div className="rounded-xl bg-[#f8faf9] p-3">
                  <div className="text-xs font-medium text-[#667085]">Course minutes</div>
                  <div className="mt-1 text-xl font-bold">{course.period_instructional_minutes}</div>
                </div>
              </div>

              <details className="mt-5">
                <summary className="cursor-pointer text-sm font-semibold text-[#315c4d]">
                  View all {course.competencies.length} competencies
                </summary>
                <div className="mt-3 grid gap-2">
                  {course.competencies.map((competency) => (
                    <div key={competency.code} className="grid gap-2 rounded-xl border border-[#eaecf0] p-3 md:grid-cols-[120px_1fr_auto] md:items-center">
                      <div className="font-mono text-xs font-semibold">{competency.code}</div>
                      <div>
                        <div className="text-sm font-medium">{competency.title}</div>
                        <div className="mt-0.5 text-xs text-[#667085]">
                          {competency.qualifying_demonstrations}/{competency.required_demonstrations} qualifying demonstrations · threshold {competency.threshold_percent}%
                        </div>
                      </div>
                      <StatusPill tone={competencyTone(competency.status)}>{competency.status}</StatusPill>
                    </div>
                  ))}
                </div>
              </details>
            </article>
          )) : (
            <div className="rounded-2xl border border-[#e4e7ec] bg-white p-6 text-sm text-[#667085]">
              No course enrollments are available for this academic year.
            </div>
          )}
        </section>

        <section className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
          <h2 className="text-xl font-bold">Generate official report</h2>
          <p className="mt-1 text-sm leading-6 text-[#667085]">
            Generating a report freezes the exact grades, attendance, lesson progress, and competency status shown for that reporting period. Later changes do not rewrite the saved report.
          </p>

          <form action={generateOfficialReport} className="mt-5 grid gap-4">
            <input type="hidden" name="student_id" value={studentId} />

            <div className="grid gap-4 md:grid-cols-3">
              <label className="grid gap-1.5 text-sm font-medium">
                Report type
                <select name="report_type" defaultValue="progress_report" className="rounded-xl border border-[#d0d5dd] bg-white px-3.5 py-3">
                  <option value="progress_report">Progress Report</option>
                  <option value="quarter_report">Quarter Report</option>
                  <option value="semester_report">Semester Report</option>
                  <option value="annual_report">Annual Report</option>
                  <option value="attendance_report">Attendance Report</option>
                  <option value="competency_report">Competency Report</option>
                </select>
              </label>

              <label className="grid gap-1.5 text-sm font-medium">
                Period start
                <input
                  name="period_start"
                  type="date"
                  defaultValue={snapshot.academic_year.start_date}
                  min={snapshot.academic_year.start_date}
                  max={snapshot.academic_year.end_date}
                  required
                  className="rounded-xl border border-[#d0d5dd] px-3.5 py-3"
                />
              </label>

              <label className="grid gap-1.5 text-sm font-medium">
                Period end
                <input
                  name="period_end"
                  type="date"
                  defaultValue={today}
                  min={snapshot.academic_year.start_date}
                  max={snapshot.academic_year.end_date}
                  required
                  className="rounded-xl border border-[#d0d5dd] px-3.5 py-3"
                />
              </label>
            </div>

            <label className="grid gap-1.5 text-sm font-medium">
              Teacher comments
              <textarea
                name="teacher_comments"
                rows={4}
                placeholder="Summarize progress, strengths, and areas to continue working on..."
                className="rounded-xl border border-[#d0d5dd] px-3.5 py-3"
              />
            </label>

            <button className="w-fit rounded-xl bg-[#315c4d] px-5 py-3 font-semibold text-white hover:bg-[#24483c]">
              Generate official report
            </button>
          </form>
        </section>

        <section className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
          <h2 className="text-xl font-bold">Saved reports</h2>
          <div className="mt-4 grid gap-3">
            {reports.length ? reports.map((report) => (
              <Link
                key={report.id}
                href={`/dashboard/students/${studentId}/reports/${report.id}`}
                className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-[#eaecf0] p-4 hover:bg-[#f8faf9]"
              >
                <div>
                  <div className="font-semibold">{reportLabel(report.report_type)} · Version {report.version}</div>
                  <div className="mt-1 text-sm text-[#667085]">
                    {report.period_start} through {report.period_end} · Generated {new Date(report.generated_at).toLocaleString()}
                  </div>
                </div>
                <StatusPill tone={report.status === "official" ? "green" : "gray"}>{report.status}</StatusPill>
              </Link>
            )) : (
              <p className="text-sm text-[#667085]">No official reports have been generated yet.</p>
            )}
          </div>
        </section>
      </div>
    </AppShell>
  );
}
