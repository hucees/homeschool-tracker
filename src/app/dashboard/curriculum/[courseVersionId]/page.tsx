import Link from "next/link";
import { notFound } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";

export default async function CourseCurriculumPage({
  params,
}: {
  params: Promise<{ courseVersionId: string }>;
}) {
  const { courseVersionId } = await params;
  const { supabase, organization } = await requireOrganization();

  const [{ data: course }, { data: lessonData }] = await Promise.all([
    supabase
      .from("course_versions")
      .select("id,course_code,title,status,instructional_weeks")
      .eq("organization_id", organization.id)
      .eq("id", courseVersionId)
      .maybeSingle(),
    supabase
      .from("lessons")
      .select("id,code,title,description,week_number,day_number,sequence,estimated_minutes,lesson_type")
      .eq("organization_id", organization.id)
      .eq("course_version_id", courseVersionId)
      .eq("status", "active")
      .order("sequence"),
  ]);

  if (!course) notFound();

  const lessons = lessonData ?? [];
  const lessonIds = lessons.map((lesson) => lesson.id);

  const { data: contentData } = lessonIds.length
    ? await supabase
        .from("lesson_content_versions")
        .select("id,lesson_id,revision_number,status,published_at,updated_at")
        .eq("organization_id", organization.id)
        .in("lesson_id", lessonIds)
        .in("status", ["draft", "published"])
    : { data: [] };

  const content = contentData ?? [];
  const weeks = [...new Set(lessons.map((lesson) => lesson.week_number))].sort(
    (a, b) => a - b
  );

  return (
    <AppShell organizationName={organization.name}>
      <div className="grid gap-6">
        <div>
          <Link href="/dashboard/curriculum" className="text-sm font-bold text-[#23685a] hover:underline">
            ← Back to curriculum
          </Link>
          <div className="mt-5 text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
            {course.course_code}
          </div>
          <h1 className="mt-1 text-2xl font-bold sm:text-3xl">{course.title}</h1>
          <p className="mt-2 text-sm text-[#617078]">
            {lessons.length} lessons across {course.instructional_weeks} instructional weeks.
          </p>
        </div>

        <div className="grid gap-5">
          {weeks.map((week) => {
            const weekLessons = lessons.filter((lesson) => lesson.week_number === week);
            return (
              <section key={week} className="app-surface overflow-hidden rounded-2xl">
                <div className="border-b border-[#e5ebe8] bg-[#f7faf8] px-5 py-4">
                  <h2 className="font-bold">Week {week}</h2>
                </div>
                <div className="divide-y divide-[#edf1ef]">
                  {weekLessons.map((lesson) => {
                    const rows = content.filter((row) => row.lesson_id === lesson.id);
                    const published = rows.find((row) => row.status === "published");
                    const draft = rows.find((row) => row.status === "draft");

                    return (
                      <div
                        key={lesson.id}
                        className="flex flex-col justify-between gap-4 p-4 sm:flex-row sm:items-center sm:p-5"
                      >
                        <div className="min-w-0">
                          <div className="text-xs font-bold uppercase tracking-wide text-[#718087]">
                            {lesson.code} · Day {lesson.day_number ?? lesson.sequence} · {lesson.estimated_minutes ?? "—"} min
                          </div>
                          <div className="mt-1 font-bold">{lesson.title}</div>
                          <div className="mt-2 flex flex-wrap gap-2">
                            {published ? (
                              <StatusPill tone="green">Published r{published.revision_number}</StatusPill>
                            ) : (
                              <StatusPill tone="gray">Not published</StatusPill>
                            )}
                            {draft && (
                              <StatusPill tone="amber">Draft r{draft.revision_number}</StatusPill>
                            )}
                          </div>
                        </div>
                        <Link
                          href={`/dashboard/curriculum/lessons/${lesson.id}`}
                          className="inline-flex w-full justify-center rounded-xl border border-[#b9cec5] bg-white px-4 py-2.5 text-sm font-bold text-[#23685a] hover:bg-[#edf7f3] sm:w-auto"
                        >
                          {draft || published ? "Edit lesson" : "Author lesson"}
                        </Link>
                      </div>
                    );
                  })}
                </div>
              </section>
            );
          })}
        </div>
      </div>
    </AppShell>
  );
}
