import { Brand } from "@/components/brand";
import { StatusPill } from "@/components/status-pill";
import { requireStudent } from "@/lib/auth";
import { localDateInTimezone } from "@/lib/student-login";
import { saveDailyCourseWork, studentSignOut } from "./actions";

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

function firstRelation<T>(value: unknown): T | null {
  if (Array.isArray(value)) return (value[0] as T | undefined) ?? null;
  return (value as T | null) ?? null;
}

export default async function StudentPortalPage({
  searchParams,
}: {
  searchParams: Promise<{ saved?: string; error?: string }>;
}) {
  const params = await searchParams;
  const { supabase, student, organization } = await requireStudent();
  const recordDate = localDateInTimezone(organization.timezone);

  const { data: enrollmentData } = await supabase
    .from("student_course_enrollments")
    .select("id,course_version_id,student_academic_year_id,course_versions(title,course_code)")
    .eq("organization_id", organization.id)
    .eq("student_id", student.id)
    .eq("status", "active")
    .order("start_date");

  const enrollments = (enrollmentData ?? []) as Enrollment[];
  const enrollmentIds = enrollments.map((item) => item.id);
  const courseVersionIds = [...new Set(enrollments.map((item) => item.course_version_id))];

  let todayEntries: Entry[] = [];
  let completedEntries: Entry[] = [];
  let lessons: Lesson[] = [];
  let assignments: Assignment[] = [];
  let grades: Grade[] = [];

  if (enrollmentIds.length) {
    const { data: todayRecord } = await supabase
      .from("student_daily_records")
      .select("id")
      .eq("student_id", student.id)
      .eq("record_date", recordDate)
      .maybeSingle();

    const [completedResult, lessonsResult, assignmentResult] = await Promise.all([
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
        .select("id,student_course_enrollment_id,title,assignment_type,max_points,assigned_date,due_date,status")
        .eq("student_id", student.id)
        .in("student_course_enrollment_id", enrollmentIds)
        .neq("status", "cancelled")
        .order("assigned_date", { ascending: false }),
    ]);

    completedEntries = (completedResult.data ?? []) as Entry[];
    lessons = (lessonsResult.data ?? []) as Lesson[];
    assignments = (assignmentResult.data ?? []) as Assignment[];

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

  return (
    <main className="min-h-screen bg-[#f7f8fb] px-5 py-6">
      <div className="mx-auto max-w-5xl">
        <header className="flex flex-wrap items-center justify-between gap-4 rounded-2xl border border-[#e4e7ec] bg-white px-5 py-4">
          <Brand />
          <div className="flex items-center gap-3">
            <span className="text-sm text-[#667085]">{student.preferred_name || student.first_name}</span>
            <form action={studentSignOut}><button className="rounded-lg border border-[#d0d5dd] px-3 py-2 text-sm font-medium hover:bg-slate-50">Sign out</button></form>
          </div>
        </header>

        <section className="mt-6">
          <div className="text-sm font-semibold text-[#315c4d]">STUDENT PORTAL</div>
          <h1 className="mt-1 text-3xl font-bold">Today&apos;s school work</h1>
          <p className="mt-2 text-[#667085]">{recordDate} · {organization.name}</p>
        </section>

        {params.saved && <div className="mt-5 rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800">Your work was saved.</div>}
        {params.error && <div className="mt-5 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{params.error}</div>}

        <section className="mt-6 grid gap-5">
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
              <article key={enrollment.id} className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <div className="text-sm font-semibold text-[#315c4d]">{course?.course_code ?? "COURSE"}</div>
                    <h2 className="mt-1 text-2xl font-bold">{course?.title ?? "Assigned course"}</h2>
                  </div>
                  {todayEntry?.status === "completed" && <span className="rounded-full bg-emerald-50 px-3 py-1 text-sm font-semibold text-emerald-700">Completed today</span>}
                </div>

                {lesson ? (
                  <form action={saveDailyCourseWork} className="mt-5 grid gap-4">
                    <input type="hidden" name="enrollment_id" value={enrollment.id} />
                    <input type="hidden" name="lesson_id" value={lesson.id} />
                    <div className="rounded-xl bg-[#f8faf9] p-4">
                      <div className="text-xs font-semibold uppercase tracking-wide text-[#667085]">Week {lesson.week_number} · Lesson {lesson.day_number ?? lesson.sequence}</div>
                      <div className="mt-1 text-lg font-bold">{lesson.title}</div>
                      {lesson.description && <p className="mt-2 text-sm leading-6 text-[#667085]">{lesson.description}</p>}
                    </div>
                    <label className="flex items-center gap-3 rounded-xl border border-[#d0d5dd] p-4 text-sm font-semibold">
                      <input name="completed" type="checkbox" defaultChecked={todayEntry?.status === "completed"} className="h-5 w-5" />
                      I completed this lesson today
                    </label>
                    <label className="grid gap-1.5 text-sm font-medium">
                      Minutes worked
                      <input name="minutes_spent" type="number" min={0} max={1440} defaultValue={todayEntry?.minutes_spent ?? lesson.estimated_minutes ?? ""} className="max-w-40 rounded-xl border border-[#d0d5dd] px-3.5 py-3" />
                    </label>
                    <label className="grid gap-1.5 text-sm font-medium">
                      What did you learn or work on today?
                      <textarea name="student_note" rows={4} defaultValue={todayEntry?.student_note ?? ""} placeholder="Today I learned..." className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" />
                    </label>
                    <button className="w-fit rounded-xl bg-[#315c4d] px-5 py-3 font-semibold text-white hover:bg-[#24483c]">Save my work</button>
                  </form>
                ) : (
                  <div className="mt-5 rounded-xl bg-emerald-50 p-4 text-sm font-medium text-emerald-800">All currently available lessons in this course are complete.</div>
                )}
              </article>
            );
          }) : (
            <div className="rounded-2xl border border-[#e4e7ec] bg-white p-8 text-center text-[#667085]">No active courses are assigned yet.</div>
          )}
        </section>

        <section className="mt-8">
          <div>
            <div className="text-sm font-semibold text-[#315c4d]">MY GRADES</div>
            <h2 className="mt-1 text-2xl font-bold">Assignments & feedback</h2>
          </div>

          <div className="mt-4 grid gap-4">
            {assignments.length ? assignments.map((assignment) => {
              const grade = gradeByAssignment.get(assignment.id);
              const enrollment = enrollmentById.get(assignment.student_course_enrollment_id);
              const course = firstRelation<{ title: string; course_code: string }>(enrollment?.course_versions);

              return (
                <article key={assignment.id} className="rounded-2xl border border-[#e4e7ec] bg-white p-5">
                  <div className="flex flex-wrap items-start justify-between gap-4">
                    <div>
                      <div className="text-xs font-semibold uppercase tracking-wide text-[#315c4d]">{course?.course_code ?? "COURSE"} · {assignment.assignment_type}</div>
                      <h3 className="mt-1 font-bold">{assignment.title}</h3>
                      <div className="mt-1 text-sm text-[#667085]">
                        Assigned {assignment.assigned_date}{assignment.due_date ? ` · Due ${assignment.due_date}` : ""}
                      </div>
                    </div>

                    {grade ? (
                      <div className="text-right">
                        <div className="text-2xl font-bold">{grade.percentage?.toFixed(1)}%</div>
                        <div className="text-sm text-[#667085]">{grade.points_earned}/{grade.points_possible} · {grade.letter_grade}</div>
                      </div>
                    ) : (
                      <StatusPill tone="amber">Not graded yet</StatusPill>
                    )}
                  </div>

                  {grade?.teacher_feedback && (
                    <div className="mt-4 rounded-xl bg-[#f8faf9] p-4 text-sm leading-6">
                      <span className="font-semibold">Teacher feedback:</span> {grade.teacher_feedback}
                    </div>
                  )}
                </article>
              );
            }) : (
              <div className="rounded-2xl border border-[#e4e7ec] bg-white p-6 text-sm text-[#667085]">
                No graded assignments yet.
              </div>
            )}
          </div>
        </section>
      </div>
    </main>
  );
}
