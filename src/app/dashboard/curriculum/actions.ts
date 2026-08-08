"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireOrganization } from "@/lib/auth";

function text(formData: FormData, key: string) {
  return String(formData.get(key) ?? "").trim();
}

function lines(value: string) {
  return value
    .split("\n")
    .map((item) => item.trim())
    .filter(Boolean);
}

export async function saveLessonDraft(formData: FormData) {
  const lessonId = text(formData, "lesson_id");

  const vocabulary = lines(text(formData, "vocabulary_text")).map((line) => {
    const [term, ...definitionParts] = line.split("|");
    return {
      term: term.trim(),
      definition: definitionParts.join("|").trim(),
    };
  }).filter((item) => item.term);

  let items: unknown[] = [];
  try {
    const parsed = JSON.parse(text(formData, "items_json") || "[]");
    if (Array.isArray(parsed)) items = parsed;
  } catch {
    redirect(
      `/dashboard/curriculum/lessons/${lessonId}?error=${encodeURIComponent(
        "Practice-item data could not be read."
      )}`
    );
  }

  const content = {
    objective: text(formData, "objective"),
    student_goal: text(formData, "student_goal"),
    materials: lines(text(formData, "materials_text")),
    vocabulary,
    teacher_introduction: text(formData, "teacher_introduction"),
    teacher_modeling: text(formData, "teacher_modeling"),
    teacher_notes: text(formData, "teacher_notes"),
    student_learn: text(formData, "student_learn"),
    guided_practice: text(formData, "guided_practice"),
    independent_practice: text(formData, "independent_practice"),
    activity: text(formData, "activity"),
    worksheet_title: text(formData, "worksheet_title"),
    worksheet_instructions: text(formData, "worksheet_instructions"),
    completion_criteria: text(formData, "completion_criteria"),
    accommodations: text(formData, "accommodations"),
    enrichment: text(formData, "enrichment"),
  };

  const { supabase } = await requireOrganization();
  const { error } = await supabase.rpc("save_lesson_content_draft", {
    p_lesson_id: lessonId,
    p_content: content,
    p_items: items,
  });

  if (error) {
    redirect(
      `/dashboard/curriculum/lessons/${lessonId}?error=${encodeURIComponent(
        error.message
      )}`
    );
  }

  revalidatePath(`/dashboard/curriculum/lessons/${lessonId}`);
  revalidatePath("/dashboard/curriculum");
  redirect(`/dashboard/curriculum/lessons/${lessonId}?saved=1`);
}

export async function publishLessonContent(formData: FormData) {
  const lessonId = text(formData, "lesson_id");
  const courseVersionId = text(formData, "course_version_id");
  const { supabase } = await requireOrganization();

  const { error } = await supabase.rpc("publish_lesson_content", {
    p_lesson_id: lessonId,
  });

  if (error) {
    redirect(
      `/dashboard/curriculum/lessons/${lessonId}?error=${encodeURIComponent(
        error.message
      )}`
    );
  }

  revalidatePath(`/dashboard/curriculum/lessons/${lessonId}`);
  revalidatePath(`/dashboard/curriculum/${courseVersionId}`);
  revalidatePath("/dashboard/curriculum");

  redirect(`/dashboard/curriculum/lessons/${lessonId}?published=1`);
}
