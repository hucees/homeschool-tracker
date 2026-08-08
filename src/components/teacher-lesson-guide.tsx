import { PrintButton } from "@/components/print-button";
import { StatusPill } from "@/components/status-pill";
import type {
  LessonContentRecord,
  LessonPracticeItem,
} from "@/lib/lesson-content";

function Text({ value }: { value: string | null | undefined }) {
  if (!value) return <div className="text-sm italic text-[#879198]">Not provided.</div>;
  return <div className="whitespace-pre-wrap text-sm leading-7 text-[#405158]">{value}</div>;
}

export function TeacherLessonGuide({
  lesson,
  content,
  items,
}: {
  lesson: {
    code: string;
    title: string;
    week_number: number;
    day_number: number | null;
    sequence: number;
    estimated_minutes: number | null;
    lesson_type: string | null;
  };
  content: LessonContentRecord;
  items: LessonPracticeItem[];
}) {
  const grouped = {
    guided_practice: items.filter((item) => item.section === "guided_practice"),
    independent_practice: items.filter((item) => item.section === "independent_practice"),
    worksheet: items.filter((item) => item.section === "worksheet"),
  };

  return (
    <div className="grid gap-4">
      <div className="print-hidden flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-[#dfe7e3] bg-white p-4 shadow-sm">
        <div>
          <div className="font-bold">Teacher guide</div>
          <div className="mt-1 text-xs text-[#718087]">
            {lesson.code} · Revision {content.revision_number}
          </div>
        </div>
        <PrintButton label="Print / Save Teacher Guide" />
      </div>

      <article className="print-document overflow-hidden rounded-[24px] border border-[#d7e2dd] bg-white shadow-sm">
        <header className="bg-gradient-to-br from-[#fff8e9] via-white to-[#eef7f3] p-5 sm:p-8">
          <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-start">
            <div>
              <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#8a6728]">
                Week {lesson.week_number} · Day {lesson.day_number ?? lesson.sequence}
              </div>
              <h1 className="mt-2 text-2xl font-bold sm:text-3xl">{lesson.title}</h1>
              <div className="mt-2 text-sm text-[#617078]">
                {lesson.lesson_type ?? "lesson"} · {lesson.estimated_minutes ?? "—"} minutes
              </div>
            </div>
            <StatusPill tone={content.status === "published" ? "green" : "amber"}>
              {content.status} r{content.revision_number}
            </StatusPill>
          </div>
        </header>

        <div className="grid gap-7 p-5 sm:p-8">
          <section className="grid gap-4 md:grid-cols-2">
            <div className="rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-5">
              <div className="text-xs font-bold uppercase tracking-wide text-[#456f91]">Objective</div>
              <div className="mt-3"><Text value={content.objective} /></div>
            </div>
            <div className="rounded-2xl border border-[#bcd8cc] bg-[#edf7f3] p-5">
              <div className="text-xs font-bold uppercase tracking-wide text-[#23685a]">Student goal</div>
              <div className="mt-3 font-bold leading-7 text-[#174d43]">{content.student_goal}</div>
            </div>
          </section>

          <section className="grid gap-4 md:grid-cols-2">
            <div>
              <h2 className="text-lg font-bold">Materials</h2>
              <ul className="mt-3 grid gap-2 text-sm text-[#405158]">
                {content.materials.map((item) => <li key={item}>• {item}</li>)}
              </ul>
            </div>
            <div>
              <h2 className="text-lg font-bold">Vocabulary</h2>
              <div className="mt-3 grid gap-2 text-sm">
                {content.vocabulary.map((item) => (
                  <div key={item.term}><strong>{item.term}</strong> — {item.definition}</div>
                ))}
              </div>
            </div>
          </section>

          <section className="border-t border-[#e5ebe8] pt-6">
            <h2 className="text-xl font-bold">1. Introduction / warm-up</h2>
            <div className="mt-3"><Text value={content.teacher_introduction} /></div>
          </section>

          <section className="border-t border-[#e5ebe8] pt-6">
            <h2 className="text-xl font-bold">2. Model / teach</h2>
            <div className="mt-3"><Text value={content.teacher_modeling} /></div>
          </section>

          <section className="border-t border-[#e5ebe8] pt-6">
            <h2 className="text-xl font-bold">3. Teaching notes</h2>
            <div className="mt-3"><Text value={content.teacher_notes} /></div>
          </section>

          {(["guided_practice", "independent_practice", "worksheet"] as const).map((section) => (
            <section key={section} className="border-t border-[#e5ebe8] pt-6">
              <h2 className="text-xl font-bold">
                {section === "guided_practice"
                  ? "Guided practice answer key"
                  : section === "independent_practice"
                    ? "Independent practice answer key"
                    : "Worksheet answer key"}
              </h2>
              <div className="mt-4 grid gap-3">
                {grouped[section].map((item) => (
                  <div key={`${section}-${item.sequence}`} className="print-break-avoid rounded-xl border border-[#e1e8e4] bg-[#f8faf8] p-4">
                    <div className="font-semibold">{item.sequence}. {item.prompt}</div>
                    <div className="mt-2 text-sm"><strong>Answer:</strong> {item.correct_answer ?? "Teacher judgment"}</div>
                    {item.answer_explanation && (
                      <div className="mt-1 text-sm text-[#617078]">{item.answer_explanation}</div>
                    )}
                  </div>
                ))}
              </div>
            </section>
          ))}

          <section className="grid gap-4 border-t border-[#e5ebe8] pt-6 md:grid-cols-2">
            <div className="rounded-xl bg-[#f8faf8] p-4">
              <h2 className="font-bold">Accommodations</h2>
              <div className="mt-2"><Text value={content.accommodations} /></div>
            </div>
            <div className="rounded-xl bg-[#fff9ee] p-4">
              <h2 className="font-bold">Enrichment</h2>
              <div className="mt-2"><Text value={content.enrichment} /></div>
            </div>
          </section>

          <section className="rounded-2xl border border-[#bcd8cc] bg-[#edf7f3] p-5">
            <h2 className="font-bold text-[#174d43]">Completion criteria</h2>
            <div className="mt-2"><Text value={content.completion_criteria} /></div>
          </section>
        </div>
      </article>
    </div>
  );
}
