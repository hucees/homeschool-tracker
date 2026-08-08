import { PrintButton } from "@/components/print-button";
import { StatusPill } from "@/components/status-pill";
import type {
  StudentTranscriptSnapshot,
  TranscriptCourse,
} from "@/lib/student-transcript";

function displayGrade(course: TranscriptCourse) {
  if (course.final_percentage === null) return "—";
  return `${course.final_percentage.toFixed(1)}%${course.final_letter_grade ? ` · ${course.final_letter_grade}` : ""}`;
}

function displayCredits(value: number | null) {
  return value === null ? "—" : value.toFixed(2).replace(/\.00$/, "");
}

export function TranscriptDocument({
  snapshot,
  official,
  version,
  status,
  snapshotSha256,
  generatedAt,
}: {
  snapshot: StudentTranscriptSnapshot;
  official: boolean;
  version?: number | null;
  status?: string | null;
  snapshotSha256?: string | null;
  generatedAt?: string | null;
}) {
  const studentName = [
    snapshot.student.first_name,
    snapshot.student.middle_name,
    snapshot.student.last_name,
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <div className="grid gap-4">
      <div className="print-hidden flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-[#dfe7e3] bg-white/85 p-4 shadow-sm">
        <div>
          <div className="font-bold text-[#26363d]">
            {official ? "Official academic transcript" : "Current academic record"}
          </div>
          <div className="mt-0.5 text-xs text-[#718087]">
            {official
              ? "This numbered transcript is frozen and will not change."
              : "This live record updates as academic history changes and is not an issued transcript."}
          </div>
        </div>
        <PrintButton label="Print / Save PDF" />
      </div>

      <article className="print-document overflow-hidden rounded-[24px] border border-[#d7e2dd] bg-white shadow-[0_24px_70px_rgba(32,66,55,0.10)]">
        <header className="bg-gradient-to-br from-[#eaf4f0] via-white to-[#eaf1f7] p-5 sm:p-8 lg:p-10">
          <div className="flex flex-col justify-between gap-5 sm:flex-row sm:items-start">
            <div>
              <div className="text-xs font-bold uppercase tracking-[0.18em] text-[#23685a]">
                {snapshot.organization.name}
              </div>
              <h1 className="mt-2 text-2xl font-bold tracking-tight sm:text-3xl">
                {official ? "Official Academic Transcript" : "Current Academic Record"}
              </h1>
              <div className="mt-2 text-sm text-[#617078]">
                Record as of {snapshot.record_as_of}
              </div>
            </div>
            <div className="flex flex-wrap items-center gap-2 sm:flex-col sm:items-end">
              <StatusPill tone={official ? "green" : "blue"}>
                {official ? status ?? "official" : "Unofficial · live"}
              </StatusPill>
              {official && version ? (
                <div className="text-xs font-semibold text-[#718087]">
                  Transcript version {version}
                </div>
              ) : null}
            </div>
          </div>

          <div className="mt-7 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <div className="rounded-2xl border border-white/80 bg-white/75 p-4 shadow-sm">
              <div className="text-[11px] font-bold uppercase tracking-wide text-[#7b898f]">Student</div>
              <div className="mt-1 font-bold">{studentName}</div>
            </div>
            <div className="rounded-2xl border border-white/80 bg-white/75 p-4 shadow-sm">
              <div className="text-[11px] font-bold uppercase tracking-wide text-[#7b898f]">Student number</div>
              <div className="mt-1 font-bold">{snapshot.student.student_number}</div>
            </div>
            <div className="rounded-2xl border border-white/80 bg-white/75 p-4 shadow-sm">
              <div className="text-[11px] font-bold uppercase tracking-wide text-[#7b898f]">Date of birth</div>
              <div className="mt-1 font-bold">{snapshot.student.date_of_birth ?? "Not recorded"}</div>
            </div>
            <div className="rounded-2xl border border-white/80 bg-white/75 p-4 shadow-sm">
              <div className="text-[11px] font-bold uppercase tracking-wide text-[#7b898f]">Enrollment date</div>
              <div className="mt-1 font-bold">{snapshot.student.enrollment_date}</div>
            </div>
          </div>
        </header>

        <div className="p-5 sm:p-8 lg:p-10">
          <section>
            <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
              Cumulative record
            </div>
            <div className="mt-4 grid grid-cols-2 gap-3 lg:grid-cols-5">
              <div className="rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-4">
                <div className="text-xs text-[#718087]">Completed courses</div>
                <div className="mt-1 text-2xl font-bold">{snapshot.cumulative.completed_courses}</div>
              </div>
              <div className="rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-4">
                <div className="text-xs text-[#718087]">Current courses</div>
                <div className="mt-1 text-2xl font-bold">{snapshot.cumulative.active_courses}</div>
              </div>
              <div className="rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-4">
                <div className="text-xs text-[#718087]">Instructional days</div>
                <div className="mt-1 text-2xl font-bold">{snapshot.cumulative.instructional_days}</div>
              </div>
              <div className="rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-4">
                <div className="text-xs text-[#718087]">Credits attempted</div>
                <div className="mt-1 text-2xl font-bold">{displayCredits(snapshot.cumulative.credits_attempted || null)}</div>
              </div>
              <div className="rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-4">
                <div className="text-xs text-[#718087]">Credits earned</div>
                <div className="mt-1 text-2xl font-bold">{displayCredits(snapshot.cumulative.credits_earned || null)}</div>
              </div>
            </div>
          </section>

          <section className="mt-8 border-t border-[#e5ebe8] pt-8">
            <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
              Academic history
            </div>
            <h2 className="mt-1 text-xl font-bold">Academic years & coursework</h2>

            <div className="mt-5 grid gap-6">
              {snapshot.academic_years.map((year) => (
                <div
                  key={year.placement_id}
                  className="print-break-avoid overflow-hidden rounded-2xl border border-[#dfe7e3]"
                >
                  <div className="flex flex-col justify-between gap-3 bg-[#f7faf8] p-5 sm:flex-row sm:items-start">
                    <div>
                      <h3 className="text-lg font-bold">{year.academic_year_name}</h3>
                      <div className="mt-1 text-sm text-[#617078]">
                        Official placement: {year.official_grade_name}
                      </div>
                    </div>
                    <div className="sm:text-right">
                      <StatusPill tone={year.placement_status === "completed" ? "green" : "blue"}>
                        {year.placement_status}
                      </StatusPill>
                      <div className="mt-2 text-xs text-[#718087]">
                        {year.start_date} through {year.end_date}
                      </div>
                    </div>
                  </div>

                  <div className="p-5">
                    <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
                      <div className="rounded-xl bg-[#f2f6f4] p-3 text-sm">
                        <div className="text-xs text-[#718087]">Present</div>
                        <div className="mt-1 font-bold">{year.attendance.present_days}</div>
                      </div>
                      <div className="rounded-xl bg-[#f2f6f4] p-3 text-sm">
                        <div className="text-xs text-[#718087]">Partial</div>
                        <div className="mt-1 font-bold">{year.attendance.partial_days}</div>
                      </div>
                      <div className="rounded-xl bg-[#f2f6f4] p-3 text-sm">
                        <div className="text-xs text-[#718087]">Absent</div>
                        <div className="mt-1 font-bold">{year.attendance.absent_days}</div>
                      </div>
                      <div className="rounded-xl bg-[#f2f6f4] p-3 text-sm">
                        <div className="text-xs text-[#718087]">Minutes</div>
                        <div className="mt-1 font-bold">{year.attendance.instructional_minutes}</div>
                      </div>
                    </div>

                    <div className="mt-5">
                      <div className="text-sm font-bold">Completed courses</div>
                      {year.completed_courses.length ? (
                        <div className="mt-2 overflow-x-auto">
                          <table className="w-full min-w-[650px] border-collapse text-left text-sm">
                            <thead>
                              <tr className="border-b border-[#dfe7e3] text-xs uppercase tracking-wide text-[#718087]">
                                <th className="py-2 pr-3">Course</th>
                                <th className="py-2 pr-3">Subject</th>
                                <th className="py-2 pr-3">Completed</th>
                                <th className="py-2 pr-3">Grade</th>
                                <th className="py-2">Credits</th>
                              </tr>
                            </thead>
                            <tbody>
                              {year.completed_courses.map((course) => (
                                <tr key={course.completion_record_id ?? course.enrollment_id} className="border-b border-[#edf1ef]">
                                  <td className="py-3 pr-3">
                                    <div className="font-bold">{course.title}</div>
                                    <div className="text-xs text-[#718087]">
                                      {course.course_code}
                                      {course.course_grade_level ? ` · ${course.course_grade_level}` : ""}
                                    </div>
                                  </td>
                                  <td className="py-3 pr-3">{course.subject_name ?? "—"}</td>
                                  <td className="py-3 pr-3">{course.completion_date ?? "—"}</td>
                                  <td className="py-3 pr-3 font-semibold">{displayGrade(course)}</td>
                                  <td className="py-3">{displayCredits(course.credits_earned)}</td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>
                      ) : (
                        <div className="mt-2 rounded-xl bg-[#f8faf8] p-4 text-sm text-[#617078]">
                          No completed courses recorded for this academic year yet.
                        </div>
                      )}
                    </div>

                    {year.current_courses.length > 0 && (
                      <div className="mt-5">
                        <div className="text-sm font-bold">Current / planned coursework</div>
                        <div className="mt-2 grid gap-2">
                          {year.current_courses.map((course) => (
                            <div
                              key={course.enrollment_id}
                              className="flex flex-col justify-between gap-2 rounded-xl border border-[#e1e8e4] bg-[#fbfcfb] p-3 sm:flex-row sm:items-center"
                            >
                              <div>
                                <div className="font-semibold">{course.title}</div>
                                <div className="mt-0.5 text-xs text-[#718087]">
                                  {course.course_code}
                                  {course.course_grade_level ? ` · ${course.course_grade_level}` : ""}
                                </div>
                              </div>
                              <div className="text-sm sm:text-right">
                                <StatusPill tone="blue">{course.status}</StatusPill>
                                <div className="mt-1 text-xs text-[#617078]">
                                  Current grade: {displayGrade(course)}
                                </div>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </section>

          <footer className="mt-8 border-t border-[#e5ebe8] pt-5 text-xs leading-5 text-[#718087]">
            <div>
              Generated {new Date(generatedAt ?? snapshot.generated_at).toLocaleString()}
            </div>
            {official && snapshotSha256 && (
              <div className="mt-1 break-all font-mono">
                Snapshot SHA-256: {snapshotSha256}
              </div>
            )}
            <div className="mt-2">
              {official
                ? "This transcript is a frozen permanent academic-record snapshot. Later changes do not alter this version."
                : "This is a live academic record, not an issued official transcript. It can change as new academic records are entered."}
            </div>
            <div className="mt-1">
              GPA is not calculated unless a future high-school grade-point policy is explicitly configured. Elementary percentage and letter grades are preserved as recorded.
            </div>
          </footer>
        </div>
      </article>
    </div>
  );
}
