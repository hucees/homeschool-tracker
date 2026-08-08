import Link from "next/link";
import { StatusPill } from "@/components/status-pill";
import { StudentShell } from "@/components/student-shell";
import { requireStudent } from "@/lib/auth";
import { localDateInTimezone } from "@/lib/student-login";
import { saveDailyCourseWork } from "./actions";

type Enrollment = {
  id: string;
  course_version_id: string;
  student_academic_year_id: string;
  course_versions: unknown;
};

type Lesson = {
  id: string;
  course_version_id: string;
  code: string;
  title: string;
  description: string | null;
  week_number: number;
  day_number: number | null;
  sequence: number;
  estimated_minutes: number | null;
  lesson_type: string;
};

type Entry = {
  id: string;
  student_course_enrollment_id: string;
  lesson_id: string | null;
  status: string;
  minutes_spent: number | null;
  student_note: string | null;
};

type Assignment = {
  id: string;
  student_course_enrollment_id: string;
  title: string;
  assignment_type: string;
  max_points: number | null;
  assigned_date: string;
  due_date: string | null;
  status: string;
  curriculum_instance_number: number;
};

type Grade = {
  student_assignment_id: string;
  points_earned: number | null;
  points_possible: number | null;
  percentage: number | null;
  letter_grade: string | null;
  teacher_feedback: string | null;
  graded_at: string;
};

type OnlineAssessment = {
  student_assignment_id: string;
  question_count: number;
};

type Report = {
  id: string;
  version: number;
  report_type: string;
  period_start: string;
  period_end: string;
  generated_at: string;
};

function firstRelation<T>(value: unknown): T | null {
  if (Array.isArray(value)) return (value[0] as T | undefined) ?? null;
  return (value as T | null) ?? null;
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

export default async function StudentPortalPage({
  searchParams,
}: {
  searchParams: Promise<{ saved?: string; error?: string }>;
}) {
  const params = await searchParams;
  const { supabase, student, organization } = await requireStudent();
  const recordDate = localDateInTimezone(organization.timezone);
  const studentName = student.preferred_name || student.first_name;

  const [{ data: enrollmentData }, { data: reportData }] = await Promise.all([
    supabase
      .from("student_course_enrollments")
      .select("id,course_version_id,student_academic_year_id,course_versions(title,course_code)")
      .eq("organization_id", organization.id)
      .eq("student_id", student.id)
      .eq("status", "active")
      .order("start_date"),
    supabase
      .from("report_snapshots")
      .select("id,version,report_type,period_start,period_end,generated_at")
      .eq("organization_id", organization.id)
      .eq("student_id", student.id)
      .eq("status", "official")
      .order("generated_at", { ascending: false })
      .limit(5),
  ]);

  const enrollments = (enrollmentData ?? []) as Enrollment[];
  const reports = (reportData ?? []) as Report[];
  const enrollmentIds = enrollments.map((item) => item.id);
  const courseVersionIds = [...new Set(enrollments.map((item) => item.course_version_id))];

  let todayEntries: Entry[] = [];
  let completedEntries: Entry[] = [];
  let lessons: Lesson[] = [];
  let assignments: Assignment[] = [];
  let grades: Grade[] = [];
  let onlineAssessments: OnlineAssessment[] = [];

  if (enrollmentIds.length) {
    const { data: todayRecord } = await supabase
      .from("student_daily_records")
      .select("id")
      .eq("student_id", student.id)
      .eq("record_date", recordDate)
      .maybeSingle();

    const [completedResult, lessonsResult, assignmentResult, onlineResult] = await Promise.all([
      supabase
        .from("daily_learning_entries")
        .select("id,student_course_enrollment_id,lesson_id,status,minutes_spent,student_note")
        .eq("student_id", student.id)
        .in("student_course_enrollment_id", enrollmentIds)
        .eq("status", "completed"),
      supabase
        .from("lessons")
        .select("id,course_version_id,code,title,description,week_number,day_number,sequence,estimated_minutes,lesson_type")
        .in("course_version_id", courseVersionIds)
        .eq("status", "active")
        .order("sequence"),
      supabase
        .from("student_assignments")
        .select("id,student_course_enrollment_id,title,assignment_type,max_points,assigned_date,due_date,status,curriculum_instance_number")
        .eq("student_id", student.id)
        .in("student_course_enrollment_id", enrollmentIds)
        .neq("status", "cancelled")
        .order("assigned_date", { ascending: false }),
      supabase.rpc("get_my_online_assessments"),
    ]);

    completedEntries = (completedResult.data ?? []) as Entry[];
    lessons = (lessonsResult.data ?? []) as Lesson[];
    assignments = (assignmentResult.data ?? []) as Assignment[];
    onlineAssessments = (onlineResult.data ?? []) as OnlineAssessment[];

    if (todayRecord?.id) {
      const { data } = await supabase
        .from("daily_learning_entries")
        .select("id,student_course_enrollment_id,lesson_id,status,minutes_spent,student_note")
        .eq("daily_record_id", todayRecord.id)
        .in("student_course_enrollment_id", enrollmentIds);
      todayEntries = (data ?? []) as Entry[];
    }

    const assignmentIds = assignments.map((assignment) => assignment.id);
    if (assignmentIds.length) {
      const { data } = await supabase
        .from("grade_records")
        .select("student_assignment_id,points_earned,points_possible,percentage,letter_grade,teacher_feedback,graded_at")
        .eq("student_id", student.id)
        .eq("status", "current")
        .in("student_assignment_id", assignmentIds)
        .order("graded_at", { ascending: false });
      grades = (data ?? []) as Grade[];
    }
  }

  const todayByEnrollment = new Map(todayEntries.map((entry) => [entry.student_course_enrollment_id, entry]));
  const gradeByAssignment = new Map(grades.map((grade) => [grade.student_assignment_id, grade]));
  const enrollmentById = new Map(enrollments.map((enrollment) => [enrollment.id, enrollment]));
  const onlineByAssignment = new Map(onlineAssessments.map((item) => [item.student_assignment_id, Number(item.question_count)]));

  return (
    <StudentShell
      studentName={studentName}
      organizationName={organization.name}
    >
      <section className="rounded-[26px] bg-gradient-to-br from-[#23685a] via-[#2f7566] to-[#456f91] p-5 text-white shadow-[0_22px_55px_rgba(35,104,90,0.18)] sm:p-7">
        <div className="text-xs font-bold uppercase tracking-[0.18em] text-white/75">Student portal</div>
        <h1 className="mt-2 text-2xl font-bold sm:text-3xl">Welcome back, {studentName}</h1>
        <p className="mt-2 max-w-2xl text-sm leading-6 text-white/80">
          Your school work, assessments, grades, and progress reports are all in one place.
        </p>
        <div className="mt-5 flex flex-wrap gap-2">
          <span className="rounded-full bg-white/15 px-3 py-1.5 text-xs font-semibold">{recordDate}</span>
          <span className="rounded-full bg-white/15 px-3 py-1.5 text-xs font-semibold">{organization.name}</span>
        </div>
      </section>

      {params.saved && (
        <div className="mt-5 rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm font-medium text-emerald-800">
          Your work was saved.
        </div>
      )}
      {params.error && (
        <div className="mt-5 rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {params.error}
        </div>
      )}

      <section className="mt-6 grid gap-4 md:grid-cols-[1.25fr_.75fr]">
        <div className="app-surface rounded-2xl p-5 sm:p-6">
          <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">Progress & reports</div>
          <h2 className="mt-1 text-xl font-bold text-[#172329]">See how you are doing</h2>
          <p className="mt-2 text-sm leading-6 text-[#617078]">
            Generate a current progress report whenever you want. It uses your latest grades, attendance, lesson completion, and competency progress.
          </p>
          <Link
            href="/student/progress"
            className="mt-4 inline-flex rounded-xl bg-[#23685a] px-4 py-2.5 text-sm font-bold text-white hover:bg-[#174d43]"
          >
            View / Save current report
          </Link>
        </div>

        <div className="app-surface rounded-2xl p-5 sm:p-6">
          <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">Official reports</div>
          <div className="mt-1 text-3xl font-bold text-[#172329]">{reports.length}</div>
          <p className="mt-1 text-sm text-[#617078]">
            {reports.length ? "Recent instructor-issued reports available." : "No official reports have been issued yet."}
          </p>
        </div>
      </section>

      {reports.length > 0 && (
        <section className="mt-7">
          <div>
            <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">My reports</div>
            <h2 className="mt-1 text-xl font-bold">Official reports</h2>
          </div>
          <div className="mt-3 grid gap-3 sm:grid-cols-2">
            {reports.map((report) => (
              <Link
                key={report.id}
                href={`/student/reports/${report.id}`}
                className="rounded-2xl border border-[#dfe7e3] bg-white p-4 shadow-sm transition hover:-translate-y-0.5 hover:border-[#b8cdc4] hover:shadow-md"
              >
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="font-bold text-[#26363d]">{reportLabel(report.report_type)}</div>
                    <div className="mt-1 text-xs text-[#718087]">
                      {report.period_start} through {report.period_end}
                    </div>
                  </div>
                  <StatusPill tone="green">Official</StatusPill>
                </div>
                <div className="mt-3 text-xs font-semibold text-[#456f91]">Version {report.version} · Open / Save PDF</div>
              </Link>
            ))}
          </div>
        </section>
      )}

      <section className="mt-8">
        <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">Today</div>
        <h2 className="mt-1 text-2xl font-bold">School work</h2>

        <div className="mt-4 grid gap-5">
          {enrollments.length ? enrollments.map((enrollment) => {
            const course = firstRelation<{ title: string; course_code: string }>(enrollment.course_versions);
            const todayEntry = todayByEnrollment.get(enrollment.id);
            const completedLessonIds = new Set(
              completedEntries
                .filter((entry) => entry.student_course_enrollment_id === enrollment.id && entry.lesson_id)
                .map((entry) => entry.lesson_id as string)
            );
            const courseLessons = lessons.filter((lesson) => lesson.course_version_id === enrollment.course_version_id);
            const lesson = todayEntry?.lesson_id
              ? courseLessons.find((item) => item.id === todayEntry.lesson_id) ?? null
              : courseLessons.find((item) => !completedLessonIds.has(item.id)) ?? null;

            return (
              <article key={enrollment.id} className="app-surface overflow-hidden rounded-2xl">
                <div className="flex flex-col justify-between gap-3 border-b border-[#edf1ef] bg-[#fbfcfb] p-5 sm:flex-row sm:items-start sm:p-6">
                  <div>
                    <div className="text-xs font-bold uppercase tracking-wide text-[#23685a]">{course?.course_code ?? "COURSE"}</div>
                    <h3 className="mt-1 text-xl font-bold sm:text-2xl">{course?.title ?? "Assigned course"}</h3>
                  </div>
                  {todayEntry?.status === "completed" && <StatusPill tone="green">Completed today</StatusPill>}
                </div>

                <div className="p-5 sm:p-6">
                  {lesson ? (
                    <form action={saveDailyCourseWork} className="grid gap-4">
                      <input type="hidden" name="enrollment_id" value={enrollment.id} />
                      <input type="hidden" name="lesson_id" value={lesson.id} />

                      <div className="rounded-2xl border border-[#dfe7e3] bg-[#f6faf8] p-4">
                        <div className="text-xs font-bold uppercase tracking-wide text-[#718087]">
                          Week {lesson.week_number} · Lesson {lesson.day_number ?? lesson.sequence}
                        </div>
                        <div className="mt-1 text-lg font-bold">{lesson.title}</div>
                        {lesson.description && <p className="mt-2 text-sm leading-6 text-[#617078]">{lesson.description}</p>}
                      </div>

                      <label className="flex items-center gap-3 rounded-2xl border border-[#cbd8d2] bg-white p-4 text-sm font-bold">
                        <input
                          name="completed"
                          type="checkbox"
                          defaultChecked={todayEntry?.status === "completed"}
                          className="h-5 w-5 accent-[#23685a]"
                        />
                        I completed this lesson today
                      </label>

                      <div className="grid gap-4 sm:grid-cols-[170px_minmax(0,1fr)]">
                        <label className="grid gap-1.5 text-sm font-semibold">
                          Minutes worked
                          <input
                            name="minutes_spent"
                            type="number"
                            min={0}
                            max={1440}
                            defaultValue={todayEntry?.minutes_spent ?? lesson.estimated_minutes ?? ""}
                            className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
                          />
                        </label>

                        <label className="grid gap-1.5 text-sm font-semibold">
                          What did you learn or work on today?
                          <textarea
                            name="student_note"
                            rows={3}
                            defaultValue={todayEntry?.student_note ?? ""}
                            placeholder="Today I learned..."
                            className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
                          />
                        </label>
                      </div>

                      <button className="w-full rounded-xl bg-[#23685a] px-5 py-3 font-bold text-white hover:bg-[#174d43] sm:w-fit">
                        Save my work
                      </button>
                    </form>
                  ) : (
                    <div className="rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm font-semibold text-emerald-800">
                      All currently available lessons in this course are complete.
                    </div>
                  )}
                </div>
              </article>
            );
          }) : (
            <div className="app-surface rounded-2xl p-8 text-center text-[#617078]">No active courses are assigned yet.</div>
          )}
        </div>
      </section>

      {onlineAssessments.length > 0 && (
        <section className="mt-8">
          <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#c17c32]">Assessments to complete</div>
          <h2 className="mt-1 text-2xl font-bold">Assigned assessments</h2>

          <div className="mt-4 grid gap-4">
            {assignments.filter((assignment) => onlineByAssignment.has(assignment.id)).map((assignment) => {
              const enrollment = enrollmentById.get(assignment.student_course_enrollment_id);
              const course = firstRelation<{ title: string; course_code: string }>(enrollment?.course_versions);
              return (
                <article key={assignment.id} className="rounded-2xl border border-[#ebcfaa] bg-[#fff8ec] p-5 shadow-sm">
                  <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
                    <div>
                      <div className="text-xs font-bold uppercase tracking-wide text-[#9a641f]">
                        {course?.course_code ?? "COURSE"} · {assignment.assignment_type}
                      </div>
                      <h3 className="mt-1 text-lg font-bold">{assignment.title}</h3>
                      <div className="mt-1 text-sm text-[#7b674d]">
                        {onlineByAssignment.get(assignment.id)} questions
                        {assignment.due_date ? ` · Due ${assignment.due_date}` : ""}
                      </div>
                    </div>
                    <Link
                      href={`/student/assessments/${assignment.id}`}
                      className="inline-flex w-full justify-center rounded-xl bg-[#23685a] px-5 py-3 font-bold text-white hover:bg-[#174d43] sm:w-auto"
                    >
                      Take assessment
                    </Link>
                  </div>
                </article>
              );
            })}
          </div>
        </section>
      )}

      <section className="mt-8 pb-8">
        <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">My grades</div>
        <h2 className="mt-1 text-2xl font-bold">Assignments & feedback</h2>

        <div className="mt-4 grid gap-4 sm:grid-cols-2">
          {assignments.length ? assignments.map((assignment) => {
            const grade = gradeByAssignment.get(assignment.id);
            const enrollment = enrollmentById.get(assignment.student_course_enrollment_id);
            const course = firstRelation<{ title: string; course_code: string }>(enrollment?.course_versions);

            return (
              <article key={assignment.id} className="app-surface rounded-2xl p-5">
                <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-start">
                  <div className="min-w-0">
                    <div className="text-xs font-bold uppercase tracking-wide text-[#23685a]">
                      {course?.course_code ?? "COURSE"} · {assignment.assignment_type}
                    </div>
                    <h3 className="mt-1 font-bold">{assignment.title}</h3>
                    <div className="mt-1 text-xs text-[#718087]">
                      Assigned {assignment.assigned_date}{assignment.due_date ? ` · Due ${assignment.due_date}` : ""}
                    </div>
                  </div>

                  {grade ? (
                    <div className="shrink-0 sm:text-right">
                      <div className="text-2xl font-bold">{grade.percentage?.toFixed(1)}%</div>
                      <div className="text-xs font-semibold text-[#617078]">{grade.points_earned}/{grade.points_possible} · {grade.letter_grade}</div>
                    </div>
                  ) : onlineByAssignment.has(assignment.id) ? (
                    <StatusPill tone="amber">Ready to take</StatusPill>
                  ) : (
                    <StatusPill tone="gray">Not graded yet</StatusPill>
                  )}
                </div>

                {grade?.teacher_feedback && (
                  <div className="mt-4 rounded-xl border border-[#e1e8e4] bg-[#f8faf8] p-4 text-sm leading-6 text-[#405158]">
                    <span className="font-bold">Teacher feedback:</span> {grade.teacher_feedback}
                  </div>
                )}
              </article>
            );
          }) : (
            <div className="app-surface rounded-2xl p-6 text-sm text-[#617078] sm:col-span-2">
              No assignments yet.
            </div>
          )}
        </div>
      </section>
    </StudentShell>
  );
}
