import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";

function firstRelation<T>(value: unknown): T | null {
  if (Array.isArray(value)) return (value[0] as T | undefined) ?? null;
  return (value as T | null) ?? null;
}

export default async function CurriculumPage() {
  const { supabase, organization } = await requireOrganization();

  const { data: courseData } = await supabase
    .from("course_versions")
    .select("id,course_code,title,status,instructional_weeks,grade_levels(name),subjects(name),curriculum_releases(version,status)")
    .eq("organization_id", organization.id)
    .order("course_code");

  const courses = courseData ?? [];
  const courseIds = courses.map((course) => course.id);

  const { data: lessonData } = courseIds.length
    ? await supabase
        .from("lessons")
        .select("id,course_version_id")
        .eq("organization_id", organization.id)
        .in("course_version_id", courseIds)
        .eq("status", "active")
    : { data: [] };

  const lessons = lessonData ?? [];
  const lessonIds = lessons.map((lesson) => lesson.id);

  const { data: contentData } = lessonIds.length
    ? await supabase
        .from("lesson_content_versions")
        .select("lesson_id,status")
        .eq("organization_id", organization.id)
        .in("lesson_id", lessonIds)
        .in("status", ["draft", "published"])
    : { data: [] };

  const content = contentData ?? [];

  return (
    <AppShell organizationName={organization.name}>
      <div className="grid gap-6">
        <section>
          <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
            Curriculum studio
          </div>
          <h1 className="mt-1 text-2xl font-bold sm:text-3xl">
            Courses & lesson content
          </h1>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-[#617078]">
            Build, revise, preview, and publish the instructional content that students receive. Published revisions remain frozen for students who already received them.
          </p>
        </section>

        <div className="grid gap-4">
          {courses.length ? courses.map((course) => {
            const grade = firstRelation<{ name: string }>(course.grade_levels);
            const subject = firstRelation<{ name: string }>(course.subjects);
            const release = firstRelation<{ version: string; status: string }>(course.curriculum_releases);
            const courseLessons = lessons.filter((lesson) => lesson.course_version_id === course.id);
            const lessonIdSet = new Set(courseLessons.map((lesson) => lesson.id));
            const published = new Set(
              content
                .filter((row) => row.status === "published" && lessonIdSet.has(row.lesson_id))
                .map((row) => row.lesson_id)
            ).size;
            const drafts = new Set(
              content
                .filter((row) => row.status === "draft" && lessonIdSet.has(row.lesson_id))
                .map((row) => row.lesson_id)
            ).size;

            return (
              <article key={course.id} className="app-surface rounded-2xl p-5 sm:p-6">
                <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-start">
                  <div>
                    <div className="text-xs font-bold uppercase tracking-wide text-[#23685a]">
                      {course.course_code}
                    </div>
                    <h2 className="mt-1 text-xl font-bold">{course.title}</h2>
                    <div className="mt-2 text-sm text-[#617078]">
                      {grade?.name ?? "No grade"} · {subject?.name ?? "Subject"} · Curriculum {release?.version ?? "—"}
                    </div>
                  </div>
                  <StatusPill tone={course.status === "published" ? "green" : "amber"}>
                    {course.status}
                  </StatusPill>
                </div>

                <div className="mt-5 grid grid-cols-3 gap-3">
                  <div className="rounded-xl bg-[#f6faf8] p-3">
                    <div className="text-xs text-[#718087]">Lessons</div>
                    <div className="mt-1 text-xl font-bold">{courseLessons.length}</div>
                  </div>
                  <div className="rounded-xl bg-[#edf7f3] p-3">
                    <div className="text-xs text-[#55766a]">Published</div>
                    <div className="mt-1 text-xl font-bold text-[#23685a]">{published}</div>
                  </div>
                  <div className="rounded-xl bg-[#fff7e8] p-3">
                    <div className="text-xs text-[#8a6b3a]">Drafts</div>
                    <div className="mt-1 text-xl font-bold text-[#8a6728]">{drafts}</div>
                  </div>
                </div>

                <Link
                  href={`/dashboard/curriculum/${course.id}`}
                  className="mt-5 inline-flex rounded-xl bg-[#23685a] px-4 py-2.5 text-sm font-bold text-white hover:bg-[#174d43]"
                >
                  Open course curriculum
                </Link>
              </article>
            );
          }) : (
            <div className="app-surface rounded-2xl p-8 text-center text-[#617078]">
              No curriculum course versions are available.
            </div>
          )}
        </div>
      </div>
    </AppShell>
  );
}
