import Link from "next/link";
import { notFound } from "next/navigation";
import { TeacherLessonGuide } from "@/components/teacher-lesson-guide";
import { requireOrganization } from "@/lib/auth";
import type {
  LessonContentRecord,
  LessonPracticeItem,
} from "@/lib/lesson-content";

export default async function TeacherGuidePage({
  params,
}: {
  params: Promise<{ lessonId: string }>;
}) {
  const { lessonId } = await params;
  const { supabase, organization } = await requireOrganization();

  const [{ data: lesson }, { data: contentData }] = await Promise.all([
    supabase
      .from("lessons")
      .select("id,code,title,week_number,day_number,sequence,estimated_minutes,lesson_type")
      .eq("organization_id", organization.id)
      .eq("id", lessonId)
      .maybeSingle(),
    supabase
      .from("lesson_content_versions")
      .select("id,revision_number,status,objective,student_goal,materials,vocabulary,teacher_introduction,teacher_modeling,teacher_notes,student_learn,guided_practice,independent_practice,activity,worksheet_title,worksheet_instructions,completion_criteria,accommodations,enrichment,published_at")
      .eq("organization_id", organization.id)
      .eq("lesson_id", lessonId)
      .in("status", ["published", "draft"])
      .order("status", { ascending: false })
      .order("revision_number", { ascending: false }),
  ]);

  if (!lesson || !contentData?.length) notFound();

  const content =
    (contentData.find((row) => row.status === "published") ??
      contentData[0]) as LessonContentRecord;

  const { data: itemData } = await supabase
    .from("lesson_content_items")
    .select("id,section,sequence,prompt,student_support,correct_answer,answer_explanation,points")
    .eq("organization_id", organization.id)
    .eq("lesson_content_version_id", content.id)
    .order("section")
    .order("sequence");

  return (
    <main className="min-h-screen px-3 py-4 sm:px-5 sm:py-6">
      <div className="mx-auto max-w-5xl">
        <div className="print-hidden mb-5">
          <Link
            href={`/dashboard/curriculum/lessons/${lessonId}`}
            className="text-sm font-bold text-[#23685a] hover:underline"
          >
            ← Back to lesson authoring
          </Link>
        </div>

        <TeacherLessonGuide
          lesson={lesson}
          content={content}
          items={(itemData ?? []) as LessonPracticeItem[]}
        />
      </div>
    </main>
  );
}
