import Link from "next/link";
import { notFound } from "next/navigation";
import { PrintButton } from "@/components/print-button";
import { requireOrganization } from "@/lib/auth";

export default async function TeacherWorksheetPage({
  params,
}: {
  params: Promise<{ lessonId: string }>;
}) {
  const { lessonId } = await params;
  const { supabase, organization } = await requireOrganization();

  const { data: lesson } = await supabase
    .from("lessons")
    .select("id,code,title")
    .eq("organization_id", organization.id)
    .eq("id", lessonId)
    .maybeSingle();

  if (!lesson) notFound();

  const { data: content } = await supabase
    .from("lesson_content_versions")
    .select("id,revision_number,worksheet_title,worksheet_instructions")
    .eq("organization_id", organization.id)
    .eq("lesson_id", lessonId)
    .eq("status", "published")
    .maybeSingle();

  if (!content) notFound();

  const { data: items } = await supabase
    .from("lesson_content_items")
    .select("sequence,prompt,correct_answer,answer_explanation")
    .eq("organization_id", organization.id)
    .eq("lesson_content_version_id", content.id)
    .eq("section", "worksheet")
    .order("sequence");

  return (
    <main className="min-h-screen px-3 py-4 sm:px-5 sm:py-6">
      <div className="mx-auto max-w-4xl">
        <div className="print-hidden mb-5 flex flex-wrap items-center justify-between gap-3">
          <Link
            href={`/dashboard/curriculum/lessons/${lessonId}`}
            className="text-sm font-bold text-[#23685a] hover:underline"
          >
            ← Back to lesson
          </Link>
          <PrintButton label="Print / Save Answer Key" />
        </div>

        <article className="print-document rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-8">
          <div className="border-b border-[#dfe7e3] pb-5">
            <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#8a6728]">
              Teacher answer key · {lesson.code} · Revision {content.revision_number}
            </div>
            <h1 className="mt-1 text-2xl font-bold">
              {content.worksheet_title || lesson.title}
            </h1>
            {content.worksheet_instructions && (
              <p className="mt-3 text-sm text-[#617078]">{content.worksheet_instructions}</p>
            )}
          </div>

          <div className="mt-6 grid gap-4">
            {(items ?? []).map((item) => (
              <div key={item.sequence} className="print-break-avoid rounded-xl border border-[#e1e8e4] bg-[#f8faf8] p-4">
                <div className="font-semibold">{item.sequence}. {item.prompt}</div>
                <div className="mt-2 text-sm">
                  <strong>Answer:</strong> {item.correct_answer ?? "Teacher judgment"}
                </div>
                {item.answer_explanation && (
                  <div className="mt-1 text-sm text-[#617078]">{item.answer_explanation}</div>
                )}
              </div>
            ))}
          </div>
        </article>
      </div>
    </main>
  );
}
