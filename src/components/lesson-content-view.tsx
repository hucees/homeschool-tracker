import type { StudentLessonDelivery } from "@/lib/lesson-content";

function TextBlock({ children }: { children: string | null | undefined }) {
  if (!children) return null;
  return (
    <div className="whitespace-pre-wrap text-sm leading-7 text-[#405158] sm:text-base">
      {children}
    </div>
  );
}

function PracticeSection({
  title,
  intro,
  items,
}: {
  title: string;
  intro?: string | null;
  items: NonNullable<StudentLessonDelivery["items"]>;
}) {
  if (!intro && !items.length) return null;

  return (
    <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
      <h2 className="text-xl font-bold">{title}</h2>
      {intro && <div className="mt-3"><TextBlock>{intro}</TextBlock></div>}
      {items.length > 0 && (
        <ol className="mt-4 grid gap-3">
          {items.map((item) => (
            <li key={`${item.section}-${item.sequence}`} className="rounded-xl bg-[#f7faf8] p-4">
              <div className="flex gap-3">
                <div className="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-[#dff1ea] text-xs font-bold text-[#23685a]">
                  {item.sequence}
                </div>
                <div className="min-w-0">
                  <div className="font-semibold leading-6">{item.prompt}</div>
                  {item.student_support && (
                    <div className="mt-2 text-sm leading-6 text-[#617078]">
                      Hint: {item.student_support}
                    </div>
                  )}
                </div>
              </div>
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}

export function LessonContentView({
  delivery,
}: {
  delivery: StudentLessonDelivery;
}) {
  const content = delivery.content;
  const items = delivery.items ?? [];
  if (!delivery.available || !content) return null;

  const guided = items.filter((item) => item.section === "guided_practice");
  const independent = items.filter((item) => item.section === "independent_practice");
  const worksheet = items.filter((item) => item.section === "worksheet");

  return (
    <div className="grid gap-5">
      {content.student_goal && (
        <section className="rounded-2xl border border-[#bcd8cc] bg-[#edf7f3] p-5 sm:p-6">
          <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#23685a]">
            Today&apos;s goal
          </div>
          <div className="mt-2 text-lg font-bold leading-7 text-[#174d43]">
            {content.student_goal}
          </div>
        </section>
      )}

      {(content.materials?.length > 0 || content.vocabulary?.length > 0) && (
        <section className="grid gap-4 sm:grid-cols-2">
          {content.materials?.length > 0 && (
            <div className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm">
              <h2 className="font-bold">Materials</h2>
              <ul className="mt-3 grid gap-2 text-sm text-[#405158]">
                {content.materials.map((material) => (
                  <li key={material}>• {material}</li>
                ))}
              </ul>
            </div>
          )}

          {content.vocabulary?.length > 0 && (
            <div className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm">
              <h2 className="font-bold">Vocabulary</h2>
              <div className="mt-3 grid gap-2 text-sm">
                {content.vocabulary.map((item) => (
                  <div key={`${item.term}-${item.definition}`}>
                    <span className="font-bold">{item.term}</span>
                    {item.definition ? ` — ${item.definition}` : ""}
                  </div>
                ))}
              </div>
            </div>
          )}
        </section>
      )}

      {content.student_learn && (
        <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
          <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
            Learn
          </div>
          <h2 className="mt-1 text-xl font-bold">Lesson</h2>
          <div className="mt-4"><TextBlock>{content.student_learn}</TextBlock></div>
        </section>
      )}

      <PracticeSection title="Practice together" intro={content.guided_practice} items={guided} />
      <PracticeSection title="Try it yourself" intro={content.independent_practice} items={independent} />

      {content.activity && (
        <section className="rounded-2xl border border-[#e7d2af] bg-[#fff9ee] p-5 sm:p-6">
          <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#9a641f]">
            Activity
          </div>
          <div className="mt-3"><TextBlock>{content.activity}</TextBlock></div>
        </section>
      )}

      {(content.worksheet_title || content.worksheet_instructions || worksheet.length > 0) && (
        <section className="rounded-2xl border border-[#cfdde6] bg-[#f5f9fc] p-5 sm:p-6">
          <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
            Worksheet
          </div>
          <h2 className="mt-1 text-xl font-bold">
            {content.worksheet_title || "Student worksheet"}
          </h2>
          {content.worksheet_instructions && (
            <div className="mt-3"><TextBlock>{content.worksheet_instructions}</TextBlock></div>
          )}
          {worksheet.length > 0 && (
            <ol className="mt-5 grid gap-4">
              {worksheet.map((item) => (
                <li key={`worksheet-${item.sequence}`} className="rounded-xl border border-[#d8e3ea] bg-white p-4">
                  <div className="font-semibold">{item.sequence}. {item.prompt}</div>
                  <div className="mt-5 border-b border-[#9aaeb9]" />
                </li>
              ))}
            </ol>
          )}
        </section>
      )}

      {content.completion_criteria && (
        <section className="rounded-2xl border border-[#bcd8cc] bg-[#edf7f3] p-5 sm:p-6">
          <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#23685a]">
            Before you finish
          </div>
          <div className="mt-3"><TextBlock>{content.completion_criteria}</TextBlock></div>
        </section>
      )}
    </div>
  );
}
