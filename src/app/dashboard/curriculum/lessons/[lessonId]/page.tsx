import Link from "next/link";
import { notFound } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { LessonAuthorForm } from "@/components/lesson-author-form";
import { LessonContentView } from "@/components/lesson-content-view";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";
import type {
  LessonContentRecord,
  LessonPracticeItem,
  StudentLessonDelivery,
} from "@/lib/lesson-content";
import { publishLessonContent, saveLessonDraft } from "../../actions";

export default async function LessonAuthorPage({
  params,
  searchParams,
}: {
  params: Promise<{ lessonId: string }>;
  searchParams: Promise<{ saved?: string; published?: string; error?: string }>;
}) {
  const { lessonId } = await params;
  const query = await searchParams;
  const { supabase, organization } = await requireOrganization();

  const { data: lesson } = await supabase
    .from("lessons")
    .select("id,course_version_id,code,title,description,week_number,day_number,sequence,estimated_minutes,lesson_type,course_versions(course_code,title)")
    .eq("organization_id", organization.id)
    .eq("id", lessonId)
    .maybeSingle();

  if (!lesson) notFound();

  const { data: contentData } = await supabase
    .from("lesson_content_versions")
    .select("id,revision_number,status,objective,student_goal,materials,vocabulary,teacher_introduction,teacher_modeling,teacher_notes,student_learn,guided_practice,independent_practice,activity,worksheet_title,worksheet_instructions,completion_criteria,accommodations,enrichment,published_at")
    .eq("organization_id", organization.id)
    .eq("lesson_id", lessonId)
    .in("status", ["draft", "published"])
    .order("revision_number", { ascending: false });

  const versions = (contentData ?? []) as LessonContentRecord[];
  const draft = versions.find((row) => row.status === "draft") ?? null;
  const published = versions.find((row) => row.status === "published") ?? null;
  const base = draft ?? published;
  let items: LessonPracticeItem[] = [];

  if (base) {
    const { data } = await supabase
      .from("lesson_content_items")
      .select("id,section,sequence,prompt,student_support,correct_answer,answer_explanation,points")
      .eq("organization_id", organization.id)
      .eq("lesson_content_version_id", base.id)
      .order("section")
      .order("sequence");
    items = (data ?? []) as LessonPracticeItem[];
  }

  const course = Array.isArray(lesson.course_versions)
    ? lesson.course_versions[0]
    : lesson.course_versions;

  return (
    <AppShell organizationName={organization.name}>
      <div className="grid gap-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <Link
            href={`/dashboard/curriculum/${lesson.course_version_id}`}
            className="text-sm font-bold text-[#23685a] hover:underline"
          >
            ← Back to {course?.course_code ?? "course"}
          </Link>

          <div className="flex flex-wrap gap-2">
            {published && (
              <>
                <Link
                  href={`/dashboard/curriculum/lessons/${lessonId}/guide`}
                  className="rounded-xl border border-[#cbd8d2] bg-white px-3 py-2 text-sm font-bold text-[#456f91] hover:bg-[#f5f9fc]"
                >
                  Teacher guide
                </Link>
                <Link
                  href={`/dashboard/curriculum/lessons/${lessonId}/worksheet`}
                  className="rounded-xl border border-[#cbd8d2] bg-white px-3 py-2 text-sm font-bold text-[#456f91] hover:bg-[#f5f9fc]"
                >
                  Answer key
                </Link>
              </>
            )}
          </div>
        </div>

        {query.saved && (
          <div className="rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm font-semibold text-emerald-800">
            Lesson draft saved.
          </div>
        )}
        {query.published && (
          <div className="rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm font-semibold text-emerald-800">
            Lesson revision published. Future student deliveries will use this revision.
          </div>
        )}
        {query.error && (
          <div className="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
            {query.error}
          </div>
        )}

        <section className="overflow-hidden rounded-[26px] border border-[#d7e2dd] bg-white shadow-sm">
          <div className="bg-gradient-to-br from-[#eef7f3] via-white to-[#eef4f8] p-5 sm:p-7">
            <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-start">
              <div>
                <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
                  {course?.course_code ?? "COURSE"} · Week {lesson.week_number} · Day {lesson.day_number ?? lesson.sequence}
                </div>
                <h1 className="mt-2 text-2xl font-bold sm:text-3xl">{lesson.title}</h1>
                <p className="mt-2 text-sm leading-6 text-[#617078]">
                  {lesson.code} · {lesson.lesson_type ?? "lesson"} · {lesson.estimated_minutes ?? "—"} minutes
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                {published && <StatusPill tone="green">Published r{published.revision_number}</StatusPill>}
                {draft && <StatusPill tone="amber">Draft r{draft.revision_number}</StatusPill>}
              </div>
            </div>
          </div>
        </section>

        {published && !draft && (
          <div className="rounded-2xl border border-[#cfdde6] bg-[#eef5fa] p-4 text-sm leading-6 text-[#345f80]">
            Revision {published.revision_number} is published and immutable. Saving edits creates a new draft revision; students already delivered revision {published.revision_number} keep it.
          </div>
        )}

        <LessonAuthorForm
          lessonId={lessonId}
          base={base}
          initialItems={items}
          action={saveLessonDraft}
        />

        {base && (
          <details className="rounded-2xl border border-[#cfdde6] bg-[#f5f9fc] p-5 shadow-sm sm:p-6">
            <summary className="cursor-pointer font-bold text-[#345f80]">
              Preview student lesson
            </summary>
            <p className="mt-2 text-sm text-[#617078]">
              This preview hides teacher-only notes and all answers.
            </p>
            <div className="mt-5">
              <LessonContentView
                delivery={{
                  available: true,
                  revision_number: base.revision_number,
                  lesson: {
                    id: lesson.id,
                    code: lesson.code,
                    title: lesson.title,
                    description: lesson.description,
                    week_number: lesson.week_number,
                    day_number: lesson.day_number,
                    sequence: lesson.sequence,
                    estimated_minutes: lesson.estimated_minutes,
                    lesson_type: lesson.lesson_type,
                  },
                  content: {
                    student_goal: base.student_goal,
                    materials: base.materials,
                    vocabulary: base.vocabulary,
                    student_learn: base.student_learn,
                    guided_practice: base.guided_practice,
                    independent_practice: base.independent_practice,
                    activity: base.activity,
                    worksheet_title: base.worksheet_title,
                    worksheet_instructions: base.worksheet_instructions,
                    completion_criteria: base.completion_criteria,
                  },
                  items: items.map((item) => ({
                    section: item.section,
                    sequence: item.sequence,
                    prompt: item.prompt,
                    student_support: item.student_support,
                    points: item.points,
                  })),
                } satisfies StudentLessonDelivery}
              />
            </div>
          </details>
        )}

        {draft && (
          <section className="rounded-2xl border border-[#d8c697] bg-[#fff9eb] p-5 sm:p-6">
            <h2 className="text-lg font-bold text-[#6f511d]">
              Publish draft revision {draft.revision_number}
            </h2>
            <p className="mt-2 text-sm leading-6 text-[#765f39]">
              Publishing makes this revision available to students. Published content cannot be edited in place.
            </p>
            <form action={publishLessonContent} className="mt-4">
              <input type="hidden" name="lesson_id" value={lessonId} />
              <input type="hidden" name="course_version_id" value={lesson.course_version_id} />
              <button className="rounded-xl bg-[#8a6728] px-5 py-3 font-bold text-white hover:bg-[#6f511d]">
                Publish this lesson revision
              </button>
            </form>
          </section>
        )}
      </div>
    </AppShell>
  );
}
