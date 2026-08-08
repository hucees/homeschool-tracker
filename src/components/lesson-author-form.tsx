"use client";

import { useMemo, useState } from "react";
import type {
  LessonContentRecord,
  LessonPracticeItem,
} from "@/lib/lesson-content";

type EditableItem = {
  section: LessonPracticeItem["section"];
  sequence: number;
  prompt: string;
  student_support: string;
  correct_answer: string;
  answer_explanation: string;
  points: string;
};

const sections: Array<{
  key: LessonPracticeItem["section"];
  title: string;
  description: string;
}> = [
  {
    key: "guided_practice",
    title: "Guided practice items",
    description: "Problems worked with the instructor.",
  },
  {
    key: "independent_practice",
    title: "Independent practice items",
    description: "Problems the student completes independently.",
  },
  {
    key: "worksheet",
    title: "Worksheet items",
    description: "Printable/on-screen worksheet problems.",
  },
];

function blankItem(
  section: LessonPracticeItem["section"],
  sequence: number
): EditableItem {
  return {
    section,
    sequence,
    prompt: "",
    student_support: "",
    correct_answer: "",
    answer_explanation: "",
    points: "",
  };
}

export function LessonAuthorForm({
  lessonId,
  base,
  initialItems,
  action,
}: {
  lessonId: string;
  base: LessonContentRecord | null;
  initialItems: LessonPracticeItem[];
  action: (formData: FormData) => void | Promise<void>;
}) {
  const [items, setItems] = useState<EditableItem[]>(
    initialItems.map((item) => ({
      section: item.section,
      sequence: item.sequence,
      prompt: item.prompt,
      student_support: item.student_support ?? "",
      correct_answer: item.correct_answer ?? "",
      answer_explanation: item.answer_explanation ?? "",
      points: item.points === null ? "" : String(item.points),
    }))
  );

  const initialMaterials = useMemo(
    () => (base?.materials ?? []).join("\n"),
    [base]
  );
  const initialVocabulary = useMemo(
    () =>
      (base?.vocabulary ?? [])
        .map((item) => `${item.term} | ${item.definition}`)
        .join("\n"),
    [base]
  );

  function updateItem(index: number, key: keyof EditableItem, value: string) {
    setItems((current) =>
      current.map((item, itemIndex) =>
        itemIndex === index ? { ...item, [key]: value } : item
      )
    );
  }

  function addItem(section: LessonPracticeItem["section"]) {
    setItems((current) => {
      const count = current.filter((item) => item.section === section).length;
      return [...current, blankItem(section, count + 1)];
    });
  }

  function removeItem(index: number) {
    setItems((current) => {
      const removedSection = current[index].section;
      const filtered = current.filter((_, itemIndex) => itemIndex !== index);
      let sequence = 0;
      return filtered.map((item) => {
        if (item.section !== removedSection) return item;
        sequence += 1;
        return { ...item, sequence };
      });
    });
  }

  const cleanItems = items
    .filter((item) => item.prompt.trim())
    .map((item) => ({
      ...item,
      points: item.points.trim() ? Number(item.points) : null,
    }));

  return (
    <form action={action} className="grid gap-6">
      <input type="hidden" name="lesson_id" value={lessonId} />
      <input type="hidden" name="items_json" value={JSON.stringify(cleanItems)} />

      <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
        <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
          Foundation
        </div>
        <div className="mt-4 grid gap-4 md:grid-cols-2">
          <label className="grid gap-1.5 text-sm font-semibold">
            Teacher objective
            <textarea
              name="objective"
              rows={3}
              defaultValue={base?.objective ?? ""}
              placeholder="What should the student be able to do by the end of this lesson?"
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
          <label className="grid gap-1.5 text-sm font-semibold">
            Student-friendly goal
            <textarea
              name="student_goal"
              rows={3}
              defaultValue={base?.student_goal ?? ""}
              placeholder='Example: "I can count and show numbers to 20."'
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
        </div>

        <div className="mt-4 grid gap-4 md:grid-cols-2">
          <label className="grid gap-1.5 text-sm font-semibold">
            Materials
            <textarea
              name="materials_text"
              rows={5}
              defaultValue={initialMaterials}
              placeholder={"One item per line\nCounters\nNumber cards\nPencil"}
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
          <label className="grid gap-1.5 text-sm font-semibold">
            Vocabulary
            <textarea
              name="vocabulary_text"
              rows={5}
              defaultValue={initialVocabulary}
              placeholder={"One per line: term | definition\nnumeral | a symbol used to write a number"}
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
        </div>
      </section>

      <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
        <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#8a6728]">
          Teacher guide
        </div>
        <div className="mt-4 grid gap-4">
          <label className="grid gap-1.5 text-sm font-semibold">
            Introduction / warm-up
            <textarea
              name="teacher_introduction"
              rows={4}
              defaultValue={base?.teacher_introduction ?? ""}
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
          <label className="grid gap-1.5 text-sm font-semibold">
            Modeling / direct instruction
            <textarea
              name="teacher_modeling"
              rows={5}
              defaultValue={base?.teacher_modeling ?? ""}
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
          <label className="grid gap-1.5 text-sm font-semibold">
            Teaching notes
            <textarea
              name="teacher_notes"
              rows={4}
              defaultValue={base?.teacher_notes ?? ""}
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
        </div>
      </section>

      <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
        <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#23685a]">
          Student lesson
        </div>
        <div className="mt-4 grid gap-4">
          <label className="grid gap-1.5 text-sm font-semibold">
            Learn / explanation
            <textarea
              name="student_learn"
              rows={7}
              defaultValue={base?.student_learn ?? ""}
              placeholder="The actual explanation the student reads or follows."
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
          <label className="grid gap-1.5 text-sm font-semibold">
            Guided practice directions
            <textarea
              name="guided_practice"
              rows={4}
              defaultValue={base?.guided_practice ?? ""}
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
          <label className="grid gap-1.5 text-sm font-semibold">
            Independent practice directions
            <textarea
              name="independent_practice"
              rows={4}
              defaultValue={base?.independent_practice ?? ""}
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
          <label className="grid gap-1.5 text-sm font-semibold">
            Activity / application
            <textarea
              name="activity"
              rows={4}
              defaultValue={base?.activity ?? ""}
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
        </div>
      </section>

      {sections.map((section) => {
        const sectionItems = items
          .map((item, index) => ({ item, index }))
          .filter(({ item }) => item.section === section.key);

        return (
          <section
            key={section.key}
            className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6"
          >
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h2 className="text-lg font-bold">{section.title}</h2>
                <p className="mt-1 text-sm text-[#617078]">{section.description}</p>
              </div>
              <button
                type="button"
                onClick={() => addItem(section.key)}
                className="rounded-xl border border-[#b9cec5] bg-white px-3.5 py-2 text-sm font-bold text-[#23685a] hover:bg-[#edf7f3]"
              >
                + Add item
              </button>
            </div>

            <div className="mt-4 grid gap-4">
              {sectionItems.map(({ item, index }) => (
                <div
                  key={`${section.key}-${index}`}
                  className="rounded-2xl border border-[#e1e8e4] bg-[#f8faf8] p-4"
                >
                  <div className="flex items-center justify-between gap-3">
                    <div className="font-bold">Item {item.sequence}</div>
                    <button
                      type="button"
                      onClick={() => removeItem(index)}
                      className="text-xs font-bold text-[#a54c4c] hover:underline"
                    >
                      Remove
                    </button>
                  </div>

                  <div className="mt-3 grid gap-3">
                    <label className="grid gap-1 text-sm font-semibold">
                      Student prompt
                      <textarea
                        value={item.prompt}
                        onChange={(event) => updateItem(index, "prompt", event.target.value)}
                        rows={2}
                        className="rounded-xl border border-[#cbd8d2] bg-white px-3 py-2.5"
                      />
                    </label>

                    <div className="grid gap-3 md:grid-cols-2">
                      <label className="grid gap-1 text-sm font-semibold">
                        Student hint / support
                        <input
                          value={item.student_support}
                          onChange={(event) =>
                            updateItem(index, "student_support", event.target.value)
                          }
                          className="rounded-xl border border-[#cbd8d2] bg-white px-3 py-2.5"
                        />
                      </label>
                      <label className="grid gap-1 text-sm font-semibold">
                        Correct answer
                        <input
                          value={item.correct_answer}
                          onChange={(event) =>
                            updateItem(index, "correct_answer", event.target.value)
                          }
                          className="rounded-xl border border-[#cbd8d2] bg-white px-3 py-2.5"
                        />
                      </label>
                    </div>

                    <div className="grid gap-3 md:grid-cols-[1fr_130px]">
                      <label className="grid gap-1 text-sm font-semibold">
                        Answer explanation
                        <input
                          value={item.answer_explanation}
                          onChange={(event) =>
                            updateItem(index, "answer_explanation", event.target.value)
                          }
                          className="rounded-xl border border-[#cbd8d2] bg-white px-3 py-2.5"
                        />
                      </label>
                      <label className="grid gap-1 text-sm font-semibold">
                        Points
                        <input
                          type="number"
                          min="0"
                          step="0.5"
                          value={item.points}
                          onChange={(event) => updateItem(index, "points", event.target.value)}
                          className="rounded-xl border border-[#cbd8d2] bg-white px-3 py-2.5"
                        />
                      </label>
                    </div>
                  </div>
                </div>
              ))}

              {!sectionItems.length && (
                <div className="rounded-xl bg-[#f8faf8] p-4 text-sm text-[#718087]">
                  No structured items yet. You can still use the narrative directions above.
                </div>
              )}
            </div>
          </section>
        );
      })}

      <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
        <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
          Worksheet & completion
        </div>
        <div className="mt-4 grid gap-4">
          <label className="grid gap-1.5 text-sm font-semibold">
            Worksheet title
            <input
              name="worksheet_title"
              defaultValue={base?.worksheet_title ?? ""}
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
          <label className="grid gap-1.5 text-sm font-semibold">
            Worksheet directions
            <textarea
              name="worksheet_instructions"
              rows={3}
              defaultValue={base?.worksheet_instructions ?? ""}
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
          <label className="grid gap-1.5 text-sm font-semibold">
            Completion criteria
            <textarea
              name="completion_criteria"
              rows={4}
              defaultValue={base?.completion_criteria ?? ""}
              placeholder="What must the student do before this lesson should be marked complete?"
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
        </div>
      </section>

      <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
        <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
          Differentiation
        </div>
        <div className="mt-4 grid gap-4 md:grid-cols-2">
          <label className="grid gap-1.5 text-sm font-semibold">
            Accommodations / extra support
            <textarea
              name="accommodations"
              rows={5}
              defaultValue={base?.accommodations ?? ""}
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
          <label className="grid gap-1.5 text-sm font-semibold">
            Enrichment / extension
            <textarea
              name="enrichment"
              rows={5}
              defaultValue={base?.enrichment ?? ""}
              className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3"
            />
          </label>
        </div>
      </section>

      <div className="sticky bottom-3 z-20 flex justify-end rounded-2xl border border-[#dfe7e3] bg-white/95 p-3 shadow-lg backdrop-blur">
        <button className="w-full rounded-xl bg-[#23685a] px-5 py-3 font-bold text-white hover:bg-[#174d43] sm:w-auto">
          Save lesson draft
        </button>
      </div>
    </form>
  );
}
