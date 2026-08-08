import Link from "next/link";
import { StudentShell } from "@/components/student-shell";
import { StatusPill } from "@/components/status-pill";
import { requireStudent } from "@/lib/auth";

type Enrollment = {
  id: string;
  course_version_id: string;
  course_versions: unknown;
};

function firstRelation<T>(value: unknown): T | null {
  if (Array.isArray(value)) return (value[0] as T | undefined) ?? null;
  return (value as T | null) ?? null;
}

export default async function StudentLessonsPage() {
  const { supabase, student, organization } = await requireStudent();
  const studentName = student.preferred_name || student.first_name;

  const { data: enrollmentData } = await supabase
    .from("student_course_enrollments")
    .select("id,course_version_id,course_versions(title,course_code)")
    .eq("organization_id", organization.id)
    .eq("student_id", student.id)
    .eq("status", "active")
    .order("start_date");

  const enrollments = (enrollmentData ?? []) as Enrollment[];
  const enrollmentIds = enrollments.map((row) => row.id);
  const courseVersionIds = enrollments.map((row) => row.course_version_id);

  const [{ data: lessonData }, { data: completedData }] = await Promise.all([
    courseVersionIds.length
      ? supabase
          .from("lessons")
          .select("id,course_version_id,code,title,description,week_number,day_number,sequence,estimated_minutes,lesson_type")
          .in("course_version_id", courseVersionIds)
          .eq("status", "active")
          .order("sequence")
      : Promise.resolve({ data: [] }),
    enrollmentIds.length
      ? supabase
          .from("daily_learning_entries")
          .select("student_course_enrollment_id,lesson_id,status")
          .eq("organization_id", organization.id)
          .eq("student_id", student.id)
          .in("student_course_enrollment_id", enrollmentIds)
          .eq("status", "completed")
      : Promise.resolve({ data: [] }),
  ]);

  const lessons = lessonData ?? [];
  const completed = completedData ?? [];

  return (
    <StudentShell studentName={studentName} organizationName={organization.name}>
      <section>
        <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
          Lessons
        </div>
        <h1 className="mt-1 text-2xl font-bold sm:text-3xl">Your next lessons</h1>
        <p className="mt-2 text-sm text-[#617078]">
          Open the next unfinished lesson for each active course.
        </p>
      </section>

      <div className="mt-6 grid gap-5">
        {enrollments.length ? enrollments.map((enrollment) => {
          const course = firstRelation<{ title: string; course_code: string }>(
            enrollment.course_versions
          );
          const completedIds = new Set(
            completed
              .filter(
                (row) =>
                  row.student_course_enrollment_id === enrollment.id &&
                  row.lesson_id
              )
              .map((row) => row.lesson_id as string)
          );
          const nextLesson = lessons.find(
            (lesson) =>
              lesson.course_version_id === enrollment.course_version_id &&
              !completedIds.has(lesson.id)
          );

          return (
            <article key={enrollment.id} className="app-surface rounded-2xl p-5 sm:p-6">
              <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-start">
                <div>
                  <div className="text-xs font-bold uppercase tracking-wide text-[#23685a]">
                    {course?.course_code ?? "COURSE"}
                  </div>
                  <h2 className="mt-1 text-xl font-bold">{course?.title ?? "Assigned course"}</h2>
                </div>
                <StatusPill tone="blue">{completedIds.size} completed</StatusPill>
              </div>

              {nextLesson ? (
                <div className="mt-5 rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-4">
                  <div className="text-xs font-bold uppercase tracking-wide text-[#718087]">
                    Week {nextLesson.week_number} · Day {nextLesson.day_number ?? nextLesson.sequence}
                  </div>
                  <div className="mt-1 text-lg font-bold">{nextLesson.title}</div>
                  {nextLesson.description && (
                    <div className="mt-2 text-sm leading-6 text-[#617078]">
                      {nextLesson.description}
                    </div>
                  )}
                  <Link
                    href={`/student/lessons/${enrollment.id}/${nextLesson.id}`}
                    className="mt-4 inline-flex w-full justify-center rounded-xl bg-[#23685a] px-5 py-3 font-bold text-white hover:bg-[#174d43] sm:w-auto"
                  >
                    Open lesson
                  </Link>
                </div>
              ) : (
                <div className="mt-5 rounded-xl bg-emerald-50 p-4 text-sm font-semibold text-emerald-800">
                  All currently assigned lessons are complete.
                </div>
              )}
            </article>
          );
        }) : (
          <div className="app-surface rounded-2xl p-8 text-center text-[#617078]">
            No active courses are assigned.
          </div>
        )}
      </div>
    </StudentShell>
  );
}
