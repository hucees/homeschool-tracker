import Link from "next/link";
import { PrintButton } from "@/components/print-button";
import { StudentShell } from "@/components/student-shell";
import { requireStudent } from "@/lib/auth";
import type { StudentLessonDelivery } from "@/lib/lesson-content";

export default async function StudentWorksheetPage({
  params,
}: {
  params: Promise<{ enrollmentId: string; lessonId: string }>;
}) {
  const { enrollmentId, lessonId } = await params;
  const { supabase, student, organization } = await requireStudent();
  const studentName = student.preferred_name || student.first_name;

  const { data, error } = await supabase.rpc("get_my_lesson_delivery", {
    p_student_course_enrollment_id: enrollmentId,
    p_lesson_id: lessonId,
  });

  const delivery = data as StudentLessonDelivery | null;
  const worksheetItems =
    delivery?.items?.filter((item) => item.section === "worksheet") ?? [];

  return (
    <StudentShell studentName={studentName} organizationName={organization.name}>
      <div className="print-hidden mb-5 flex flex-wrap items-center justify-between gap-3">
        <Link
          href={`/student/lessons/${enrollmentId}/${lessonId}`}
          className="text-sm font-bold text-[#23685a] hover:underline"
        >
          ← Back to lesson
        </Link>
        {delivery?.available && worksheetItems.length > 0 && (
          <PrintButton label="Print / Save Worksheet" />
        )}
      </div>

      {error || !delivery?.available ? (
        <div className="rounded-2xl border border-amber-200 bg-amber-50 p-5 text-sm text-amber-900">
          This worksheet is not available yet.
        </div>
      ) : (
        <article className="print-document rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-8">
          <div className="border-b border-[#dfe7e3] pb-5">
            <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
              {delivery.lesson.code}
            </div>
            <h1 className="mt-1 text-2xl font-bold">
              {delivery.content?.worksheet_title || delivery.lesson.title}
            </h1>
            <div className="mt-4 grid gap-3 sm:grid-cols-2">
              <div className="border-b border-[#9aaeb9] pb-1 text-sm">Name:</div>
              <div className="border-b border-[#9aaeb9] pb-1 text-sm">Date:</div>
            </div>
            {delivery.content?.worksheet_instructions && (
              <p className="mt-5 text-sm leading-6 text-[#53646b]">
                {delivery.content.worksheet_instructions}
              </p>
            )}
          </div>

          <ol className="mt-6 grid gap-7">
            {worksheetItems.map((item) => (
              <li key={item.sequence} className="print-break-avoid">
                <div className="font-semibold">{item.sequence}. {item.prompt}</div>
                <div className="mt-6 border-b border-[#9aaeb9]" />
              </li>
            ))}
          </ol>
        </article>
      )}
    </StudentShell>
  );
}
