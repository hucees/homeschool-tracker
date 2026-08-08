import { StatusPill } from "@/components/status-pill";
import { PrintButton } from "@/components/print-button";
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

function competencyTone(status: string) {
  if (status === "Mastered" || status === "Proficient") return "green" as const;
  if (status === "Practicing" || status === "Needs review") return "amber" as const;
  return "gray" as const;
}

export function ProgressReportDocument({
  snapshot,
  official,
  version,
  status,
  snapshotSha256,
  generatedAt,
  showPrintButton = true,
}: {
  snapshot: StudentProgressSnapshot;
  official: boolean;
  version?: number | null;
  status?: string | null;
  snapshotSha256?: string | null;
  generatedAt?: string | null;
  showPrintButton?: boolean;
}) {
  const studentName =
    snapshot.student.preferred_name ||
    `${snapshot.student.first_name} ${snapshot.student.last_name}`;

  return (
    <div className="grid gap-4">
      {showPrintButton && (
        <div className="print-hidden flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-[#dfe7e3] bg-white/80 p-3 shadow-sm sm:p-4">
          <div>
            <div className="font-bold text-[#26363d]">
              {official ? "Official academic record" : "Current progress report"}
            </div>
            <div className="mt-0.5 text-xs text-[#718087]">
              {official
                ? "This saved version will not change."
                : "This report reflects current records and is not an official frozen snapshot."}
            </div>
          </div>
          <PrintButton />
        </div>
      )}

      <article className="print-document overflow-hidden rounded-[24px] border border-[#d7e2dd] bg-white shadow-[0_24px_70px_rgba(32,66,55,0.10)]">
        <header className="bg-gradient-to-br from-[#eef7f3] via-white to-[#eef4f8] p-5 sm:p-8 lg:p-10">
          <div className="flex flex-col justify-between gap-5 sm:flex-row sm:items-start">
            <div className="min-w-0">
              <div className="text-xs font-bold uppercase tracking-[0.18em] text-[#23685a]">
                {snapshot.organization.name}
              </div>
              <h1 className="mt-2 text-2xl font-bold tracking-tight text-[#172329] sm:text-3xl">
                {official ? reportLabel(snapshot.report.report_type) : "Current Progress Report"}
              </h1>
              <div className="mt-2 text-sm text-[#617078]">
                {snapshot.report.period_start} through {snapshot.report.period_end}
              </div>
            </div>

            <div className="flex flex-wrap items-center gap-2 sm:flex-col sm:items-end">
              <StatusPill tone={official ? "green" : "blue"}>
                {official ? (status ?? "official") : "Unofficial · live"}
              </StatusPill>
              {official && version ? (
                <div className="text-xs font-semibold text-[#718087]">Report version {version}</div>
              ) : (
                <div className="text-xs font-semibold text-[#718087]">Generated from current records</div>
              )}
            </div>
          </div>

          <div className="mt-7 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {[
              ["Student", studentName],
              ["Student number", snapshot.student.student_number],
              ["Official grade", snapshot.academic_year.official_grade_name],
              ["Academic year", snapshot.academic_year.name],
            ].map(([label, value]) => (
              <div key={label} className="rounded-2xl border border-white/80 bg-white/75 p-4 shadow-sm">
                <div className="text-[11px] font-bold uppercase tracking-wide text-[#7b898f]">{label}</div>
                <div className="mt-1 break-words font-bold text-[#26363d]">{value}</div>
              </div>
            ))}
          </div>
        </header>

        <div className="p-5 sm:p-8 lg:p-10">
          <section>
            <div className="flex flex-wrap items-end justify-between gap-2">
              <div>
                <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">Attendance</div>
                <h2 className="mt-1 text-xl font-bold text-[#172329]">Confirmed school attendance</h2>
              </div>
              <div className="text-xs text-[#718087]">
                {snapshot.attendance.instructional_days} instructional day{snapshot.attendance.instructional_days === 1 ? "" : "s"}
              </div>
            </div>

            <div className="mt-4 grid grid-cols-2 gap-3 lg:grid-cols-4">
              {[
                ["Present", snapshot.attendance.present_days],
                ["Partial", snapshot.attendance.partial_days],
                ["Absent", snapshot.attendance.absent_days],
                ["Instructional minutes", snapshot.attendance.instructional_minutes],
              ].map(([label, value]) => (
                <div key={label} className="rounded-2xl border border-[#e0e8e4] bg-[#f8faf8] p-4">
                  <div className="text-xs font-semibold text-[#718087]">{label}</div>
                  <div className="mt-1 text-2xl font-bold text-[#223239]">{value}</div>
                </div>
              ))}
            </div>
          </section>

          <section className="mt-8 border-t border-[#e5ebe8] pt-8">
            <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">Academics</div>
            <h2 className="mt-1 text-xl font-bold text-[#172329]">Course progress</h2>

            <div className="mt-5 grid gap-6">
              {snapshot.courses.map((course) => (
                <div key={course.enrollment_id} className="print-break-avoid overflow-hidden rounded-2xl border border-[#dfe7e3]">
                  <div className="flex flex-col justify-between gap-4 bg-[#fbfcfb] p-5 sm:flex-row sm:items-start">
                    <div>
                      <div className="text-xs font-bold uppercase tracking-wide text-[#23685a]">{course.course_code}</div>
                      <h3 className="mt-1 text-lg font-bold text-[#172329]">{course.title}</h3>
                      <div className="mt-1 text-sm text-[#617078]">
                        {course.lessons_completed}/{course.lessons_total} lessons completed
                        {course.current_week > 0 ? ` · Through week ${course.current_week}` : ""}
                      </div>
                    </div>

                    <div className="sm:text-right">
                      {course.current_grade_percent !== null ? (
                        <>
                          <div className="text-3xl font-bold text-[#172329]">{course.current_grade_percent.toFixed(1)}%</div>
                          <div className="text-sm font-semibold text-[#617078]">
                            {course.current_letter_grade} · {course.graded_assignments} graded
                          </div>
                        </>
                      ) : (
                        <StatusPill tone="gray">No report-period grade</StatusPill>
                      )}
                    </div>
                  </div>

                  <div className="p-5">
                    <div className="mb-4">
                      <div className="flex items-center justify-between gap-3 text-xs font-semibold text-[#617078]">
                        <span>Lesson completion</span>
                        <span>{course.lesson_progress_percent.toFixed(1)}%</span>
                      </div>
                      <div className="mt-2 h-2 overflow-hidden rounded-full bg-[#edf1ef]">
                        <div
                          className="h-full rounded-full bg-gradient-to-r from-[#23685a] to-[#4f8d79]"
                          style={{ width: `${Math.min(course.lesson_progress_percent, 100)}%` }}
                        />
                      </div>
                    </div>

                    <div className="grid grid-cols-2 gap-2 sm:grid-cols-5">
                      {[
                        ["Mastered", course.competency_counts.mastered, "bg-[#e8f6ef] text-[#17644f]"],
                        ["Proficient", course.competency_counts.proficient, "bg-[#edf7f3] text-[#23685a]"],
                        ["Practicing", course.competency_counts.practicing, "bg-[#fff5e6] text-[#8b5a18]"],
                        ["Needs review", course.competency_counts.needs_review, "bg-[#fff0e9] text-[#9a5738]"],
                        ["Not started", course.competency_counts.not_started, "bg-[#f2f5f4] text-[#617078]"],
                      ].map(([label, count, classes]) => (
                        <div key={String(label)} className={`rounded-xl p-3 text-sm ${classes}`}>
                          <div className="text-xs font-semibold">{label}</div>
                          <div className="mt-1 text-xl font-bold">{count}</div>
                        </div>
                      ))}
                    </div>

                    <div className="mt-5 grid gap-2">
                      {course.competencies.map((competency) => (
                        <div
                          key={competency.code}
                          className="grid gap-2 border-t border-[#edf1ef] pt-3 text-sm sm:grid-cols-[120px_minmax(0,1fr)_auto] sm:items-center"
                        >
                          <div className="font-mono text-xs font-bold text-[#53646b]">{competency.code}</div>
                          <div className="min-w-0 text-[#26363d]">{competency.title}</div>
                          <div className="justify-self-start sm:justify-self-end">
                            <StatusPill tone={competencyTone(competency.status)}>{competency.status}</StatusPill>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              ))}

              {!snapshot.courses.length && (
                <div className="rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-5 text-sm text-[#617078]">
                  No course enrollments are included in this reporting period.
                </div>
              )}
            </div>
          </section>

          {snapshot.report.teacher_comments && (
            <section className="mt-8 border-t border-[#e5ebe8] pt-8">
              <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">Instructor</div>
              <h2 className="mt-1 text-xl font-bold text-[#172329]">Teacher comments</h2>
              <div className="mt-4 whitespace-pre-wrap rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-5 leading-7 text-[#34474f]">
                {snapshot.report.teacher_comments}
              </div>
            </section>
          )}

          <footer className="mt-8 border-t border-[#e5ebe8] pt-5 text-xs leading-5 text-[#718087]">
            <div>
              Generated {new Date(generatedAt ?? snapshot.generated_at).toLocaleString()}
            </div>
            {official && snapshotSha256 && (
              <div className="mt-1 break-all font-mono">Snapshot SHA-256: {snapshotSha256}</div>
            )}
            <div className="mt-2">
              {official
                ? "This is a frozen academic-record snapshot. Later changes to grades, attendance, curriculum, or competency evidence do not alter this version."
                : "This is a live, unofficial progress report. Values can change as new attendance, grades, lessons, or competency evidence are recorded."}
            </div>
          </footer>
        </div>
      </article>
    </div>
  );
}
