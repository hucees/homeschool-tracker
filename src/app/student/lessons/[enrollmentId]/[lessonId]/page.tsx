import Link from "next/link";
import { LessonContentView } from "@/components/lesson-content-view";
import { StudentShell } from "@/components/student-shell";
import { StatusPill } from "@/components/status-pill";
import { requireStudent } from "@/lib/auth";
import type { StudentLessonDelivery } from "@/lib/lesson-content";
import { saveDailyCourseWork } from "@/app/student/actions";

export default async function StudentLessonPage({
  params,
}: {
  params: Promise<{ enrollmentId: string; lessonId: string }>;
}) {
  const { enrollmentId, lessonId } = await params;
  const { supabase, student, organization } = await requireStudent();
  const studentName = student.preferred_name || student.first_name;

  const [{ data, error }, { data: onlineData }] = await Promise.all([
    supabase.rpc("get_my_lesson_delivery", {
      p_student_course_enrollment_id: enrollmentId,
      p_lesson_id: lessonId,
    }),
    supabase.rpc("get_my_online_assessments"),
  ]);

  if (error) {
    return (
      <StudentShell studentName={studentName} organizationName={organization.name}>
        <div className="rounded-2xl border border-red-200 bg-red-50 p-5 text-sm text-red-700">
          {error.message}
        </div>
      </StudentShell>
    );
  }

  const delivery = data as StudentLessonDelivery;
  const lesson = delivery.lesson;
  const worksheetItems =
    delivery.items?.filter((item) => item.section === "worksheet") ?? [];

  const onlineIds = (onlineData ?? []).map(
    (row: { student_assignment_id: string }) => row.student_assignment_id
  );

  let assessment: { id: string; title: string } | null = null;
  if (onlineIds.length) {
    const { data: assessmentData } = await supabase
      .from("student_assignments")
      .select("id,title")
      .eq("student_id", student.id)
      .eq("student_course_enrollment_id", enrollmentId)
      .eq("lesson_id", lessonId)
      .eq("status", "assigned")
      .in("id", onlineIds)
      .limit(1);

    assessment = assessmentData?.[0] ?? null;
  }

  return (
    <StudentShell studentName={studentName} organizationName={organization.name}>
      <div className="grid gap-6">
        <div className="print-hidden flex flex-wrap items-center justify-between gap-3">
          <Link href="/student/lessons" className="text-sm font-bold text-[#23685a] hover:underline">
            ← Back to lessons
          </Link>
          {delivery.available && worksheetItems.length > 0 && (
            <Link
              href={`/student/lessons/${enrollmentId}/${lessonId}/worksheet`}
              className="rounded-xl border border-[#b9cec5] bg-white px-3.5 py-2 text-sm font-bold text-[#23685a] hover:bg-[#edf7f3]"
            >
              Open printable worksheet
            </Link>
          )}
        </div>

        <section className="overflow-hidden rounded-[26px] border border-[#d7e2dd] bg-white shadow-sm">
          <div className="bg-gradient-to-br from-[#eef7f3] via-white to-[#eef4f8] p-5 sm:p-7">
            <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-start">
              <div>
                <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
                  Week {lesson.week_number} · Day {lesson.day_number ?? lesson.sequence}
                </div>
                <h1 className="mt-2 text-2xl font-bold sm:text-3xl">{lesson.title}</h1>
                <div className="mt-2 text-sm text-[#617078]">
                  {lesson.code} · {lesson.estimated_minutes ?? "—"} minutes
                </div>
              </div>
              {delivery.available ? (
                <StatusPill tone="green">Published revision {delivery.revision_number}</StatusPill>
              ) : (
                <StatusPill tone="amber">Content pending</StatusPill>
              )}
            </div>
          </div>
        </section>

        {delivery.available ? (
          <LessonContentView delivery={delivery} />
        ) : (
          <section className="rounded-2xl border border-amber-200 bg-amber-50 p-5 sm:p-6">
            <h2 className="font-bold text-amber-950">Detailed lesson content is not published yet.</h2>
            <p className="mt-2 text-sm leading-6 text-amber-900">
              The lesson is still part of your assigned course, but its full Learn / Practice / Worksheet content has not been published.
            </p>
          </section>
        )}

        {assessment && (
          <section className="rounded-2xl border border-[#dfc994] bg-[#fff9eb] p-5 shadow-sm sm:p-6">
            <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#8a6728]">
              Week check
            </div>
            <h2 className="mt-1 text-xl font-bold">{assessment.title}</h2>
            <p className="mt-2 text-sm leading-6 text-[#765f39]">
              Your online check is assigned and ready. Complete it independently after finishing the lesson review.
            </p>
            <Link
              href={`/student/assessments/${assessment.id}`}
              className="mt-4 inline-flex w-full justify-center rounded-xl bg-[#8a6728] px-5 py-3 font-bold text-white hover:bg-[#6f511d] sm:w-auto"
            >
              Start Week 1 Check
            </Link>
          </section>
        )}

        <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
          <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#23685a]">
            Finish lesson
          </div>
          <h2 className="mt-1 text-xl font-bold">Record today&apos;s work</h2>

          <form action={saveDailyCourseWork} className="mt-4 grid gap-4">
            <input type="hidden" name="enrollment_id" value={enrollmentId} />
            <input type="hidden" name="lesson_id" value={lessonId} />

            <label className="flex items-center gap-3 rounded-xl border border-[#cbd8d2] p-4 text-sm font-bold">
              <input
                name="completed"
                type="checkbox"
                className="h-5 w-5 accent-[#23685a]"
              />
              I completed this lesson today
            </label>

            <label className="grid gap-1.5 text-sm font-semibold sm:max-w-48">
              Minutes worked
              <input
                name="minutes_spent"
                type="number"
                min={0}
                max={1440}
                defaultValue={lesson.estimated_minutes ?? ""}
                className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
              />
            </label>

            <label className="grid gap-1.5 text-sm font-semibold">
              Student note
              <textarea
                name="student_note"
                rows={3}
                placeholder="What did you learn or practice?"
                className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
              />
            </label>

            <button className="w-full rounded-xl bg-[#23685a] px-5 py-3 font-bold text-white hover:bg-[#174d43] sm:w-fit">
              Save & finish lesson
            </button>
          </form>
        </section>
      </div>
    </StudentShell>
  );
}
