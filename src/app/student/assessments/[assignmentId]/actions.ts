"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireStudent } from "@/lib/auth";

export async function submitAssessment(formData: FormData) {
  const assignmentId = String(formData.get("assignment_id") ?? "").trim();

  if (!assignmentId) {
    redirect("/student?error=Assessment%20information%20is%20missing.");
  }

  const answers: Record<string, string> = {};
  for (const [key, value] of formData.entries()) {
    if (!key.startsWith("answer_")) continue;
    const itemId = key.slice("answer_".length);
    if (itemId) answers[itemId] = String(value).trim();
  }

  const { supabase } = await requireStudent();
  const { error } = await supabase.rpc("submit_student_assessment", {
    p_student_assignment_id: assignmentId,
    p_answers: answers,
  });

  if (error) {
    redirect(`/student/assessments/${assignmentId}?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/student");
  revalidatePath(`/student/assessments/${assignmentId}`);
  redirect(`/student/assessments/${assignmentId}?submitted=1`);
}
