import Link from "next/link";
import { notFound } from "next/navigation";
import { PrintButton } from "@/components/print-button";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";
import type { StudentProgressSnapshot } from "@/lib/student-progress";

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

function tone(status: string) {
  if (status === "Mastered" || status === "Proficient") return "green" as const;
  if (status === "Practicing" || status === "Needs review") return "amber" as const;
  return "gray" as const;
}

export default async function OfficialReportPage({
  params,
  searchParams,
}: {
  params: Promise<{ studentId: string; reportId: string }>;
  searchParams: Promise<{ created?: string }>;
}) {
  const { studentId, reportId } = await params;
  const query = await searchParams;
  const { supabase, organization } = await requireOrganization();

  const { data: report } = await supabase
    .from("report_snapshots")
    .select("id,student_id,version,report_type,status,period_start,period_end,snapshot_data,snapshot_sha256,generated_at")
    .eq("organization_id", organization.id)
    .eq("student_id", studentId)
    .eq("id", reportId)
    .maybeSingle();

  if (!report) notFound();

  const snapshot = report.snapshot_data as StudentProgressSnapshot;
  const studentName =
    snapshot.student.preferred_name ||
    `${snapshot.student.first_name} ${snapshot.student.last_name}`;

  return (
    <main className="min-h-screen bg-[#f7f8fb] px-5 py-6 print:bg-white print:px-0 print:py-0">
      <div className="mx-auto max-w-5xl">
        <div className="mb-5 flex flex-wrap items-center justify-between gap-3 print:hidden">
          <Link
            href={`/dashboard/students/${studentId}/progress`}
            className="text-sm font-semibold text-[#315c4d] hover:underline"
          >
            ← Back to progress
          </Link>
          <PrintButton />
        </div>

        {query.created && (
          <div className="mb-5 rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800 print:hidden">
            Official report created and frozen successfully.
          </div>
        )}

        <article className="rounded-2xl border border-[#dfe3e8] bg-white p-7 sm:p-10 print:rounded-none print:border-0 print:p-0">
          <header className="border-b border-[#dfe3e8] pb-6">
            <div className="flex flex-wrap items-start justify-between gap-5">
              <div>
                <div className="text-sm font-semibold uppercase tracking-[0.16em] text-[#315c4d]">
                  {snapshot.organization.name}
                </div>
                <h1 className="mt-2 text-3xl font-bold">{reportLabel(report.report_type)}</h1>
                <div className="mt-2 text-[#667085]">
                  {report.period_start} through {report.period_end}
                </div>
              </div>
              <div className="text-right">
                <StatusPill tone={report.status === "official" ? "green" : "gray"}>{report.status}</StatusPill>
                <div className="mt-2 text-xs text-[#667085]">Report version {report.version}</div>
              </div>
            </div>

            <div className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <div>
                <div className="text-xs font-semibold uppercase text-[#667085]">Student</div>
                <div className="mt-1 font-semibold">{studentName}</div>
              </div>
              <div>
                <div className="text-xs font-semibold uppercase text-[#667085]">Student number</div>
                <div className="mt-1 font-semibold">{snapshot.student.student_number}</div>
              </div>
              <div>
                <div className="text-xs font-semibold uppercase text-[#667085]">Official grade</div>
                <div className="mt-1 font-semibold">{snapshot.academic_year.official_grade_name}</div>
              </div>
              <div>
                <div className="text-xs font-semibold uppercase text-[#667085]">Academic year</div>
                <div className="mt-1 font-semibold">{snapshot.academic_year.name}</div>
              </div>
            </div>
          </header>

          <section className="py-6">
            <h2 className="text-xl font-bold">Attendance</h2>
            <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
              <div className="rounded-xl bg-[#f8faf9] p-4">
                <div className="text-xs text-[#667085]">Present</div>
                <div className="mt-1 text-2xl font-bold">{snapshot.attendance.present_days}</div>
              </div>
              <div className="rounded-xl bg-[#f8faf9] p-4">
                <div className="text-xs text-[#667085]">Partial</div>
                <div className="mt-1 text-2xl font-bold">{snapshot.attendance.partial_days}</div>
              </div>
              <div className="rounded-xl bg-[#f8faf9] p-4">
                <div className="text-xs text-[#667085]">Absent</div>
                <div className="mt-1 text-2xl font-bold">{snapshot.attendance.absent_days}</div>
              </div>
              <div className="rounded-xl bg-[#f8faf9] p-4">
                <div className="text-xs text-[#667085]">Instructional minutes</div>
                <div className="mt-1 text-2xl font-bold">{snapshot.attendance.instructional_minutes}</div>
              </div>
            </div>
          </section>

          <section className="border-t border-[#dfe3e8] py-6">
            <h2 className="text-xl font-bold">Academic progress</h2>

            <div className="mt-4 grid gap-6">
              {snapshot.courses.map((course) => (
                <div key={course.enrollment_id} className="break-inside-avoid rounded-xl border border-[#e4e7ec] p-5">
                  <div className="flex flex-wrap items-start justify-between gap-4">
                    <div>
                      <div className="text-sm font-semibold text-[#315c4d]">{course.course_code}</div>
                      <h3 className="mt-1 text-lg font-bold">{course.title}</h3>
                      <div className="mt-1 text-sm text-[#667085]">
                        {course.lessons_completed}/{course.lessons_total} lessons completed
                        {course.current_week > 0 ? ` · Through week ${course.current_week}` : ""}
                      </div>
                    </div>

                    <div className="text-right">
                      {course.current_grade_percent !== null ? (
                        <>
                          <div className="text-2xl font-bold">{course.current_grade_percent.toFixed(1)}%</div>
                          <div className="text-sm text-[#667085]">{course.current_letter_grade}</div>
                        </>
                      ) : (
                        <div className="text-sm text-[#667085]">No report-period grade</div>
                      )}
                    </div>
                  </div>

                  <div className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-5">
                    <div className="rounded-lg bg-emerald-50 p-3 text-sm">
                      <div className="text-emerald-700">Mastered</div>
                      <div className="font-bold text-emerald-900">{course.competency_counts.mastered}</div>
                    </div>
                    <div className="rounded-lg bg-emerald-50 p-3 text-sm">
                      <div className="text-emerald-700">Proficient</div>
                      <div className="font-bold text-emerald-900">{course.competency_counts.proficient}</div>
                    </div>
                    <div className="rounded-lg bg-amber-50 p-3 text-sm">
                      <div className="text-amber-700">Practicing</div>
                      <div className="font-bold text-amber-900">{course.competency_counts.practicing}</div>
                    </div>
                    <div className="rounded-lg bg-amber-50 p-3 text-sm">
                      <div className="text-amber-700">Needs review</div>
                      <div className="font-bold text-amber-900">{course.competency_counts.needs_review}</div>
                    </div>
                    <div className="rounded-lg bg-slate-50 p-3 text-sm">
                      <div className="text-slate-600">Not started</div>
                      <div className="font-bold text-slate-800">{course.competency_counts.not_started}</div>
                    </div>
                  </div>

                  <div className="mt-4 grid gap-2">
                    {course.competencies.map((competency) => (
                      <div key={competency.code} className="grid gap-1 border-t border-[#eaecf0] pt-2 text-sm sm:grid-cols-[115px_1fr_auto] sm:items-center">
                        <div className="font-mono text-xs font-semibold">{competency.code}</div>
                        <div>{competency.title}</div>
                        <StatusPill tone={tone(competency.status)}>{competency.status}</StatusPill>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </section>

          {snapshot.report.teacher_comments && (
            <section className="border-t border-[#dfe3e8] py-6">
              <h2 className="text-xl font-bold">Teacher comments</h2>
              <p className="mt-3 whitespace-pre-wrap leading-7 text-[#344054]">
                {snapshot.report.teacher_comments}
              </p>
            </section>
          )}

          <footer className="border-t border-[#dfe3e8] pt-5 text-xs leading-5 text-[#667085]">
            <div>Generated {new Date(report.generated_at).toLocaleString()}</div>
            {report.snapshot_sha256 && (
              <div className="mt-1 font-mono">Snapshot SHA-256: {report.snapshot_sha256}</div>
            )}
            <div className="mt-2">
              This report is a frozen academic-record snapshot. Later changes to grades, attendance, curriculum, or competency evidence do not alter this version.
            </div>
          </footer>
        </article>
      </div>
    </main>
  );
}
