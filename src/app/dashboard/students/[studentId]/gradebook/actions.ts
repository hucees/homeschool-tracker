"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireOrganization } from "@/lib/auth";

function dateValue(value: FormDataEntryValue | null) {
  const text = String(value ?? "").trim();
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : null;
}

export async function assignAssessment(formData: FormData) {
  const studentId = String(formData.get("student_id") ?? "").trim();
  const enrollmentId = String(formData.get("enrollment_id") ?? "").trim();
  const templateId = String(formData.get("template_id") ?? "").trim();
  const assignedDate = dateValue(formData.get("assigned_date"));
  const dueDate = dateValue(formData.get("due_date"));

  if (!studentId || !enrollmentId || !templateId || !assignedDate) {
    redirect(`/dashboard/students/${studentId}/gradebook?error=${encodeURIComponent("Choose an assessment and assigned date.")}`);
  }

  const { supabase } = await requireOrganization();
  const { error } = await supabase.rpc("assign_curriculum_assessment", {
    p_student_course_enrollment_id: enrollmentId,
    p_assignment_template_id: templateId,
    p_assigned_date: assignedDate,
    p_due_date: dueDate,
  });

  if (error) {
    redirect(`/dashboard/students/${studentId}/gradebook?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath(`/dashboard/students/${studentId}`);
  revalidatePath(`/dashboard/students/${studentId}/gradebook`);
  revalidatePath("/student");
  redirect(`/dashboard/students/${studentId}/gradebook?assigned=1`);
}

export async function gradeAssignment(formData: FormData) {
  const studentId = String(formData.get("student_id") ?? "").trim();
  const assignmentId = String(formData.get("assignment_id") ?? "").trim();
  const pointsRaw = String(formData.get("points_earned") ?? "").trim();
  const teacherFeedback = String(formData.get("teacher_feedback") ?? "").trim();
  const changeReason = String(formData.get("change_reason") ?? "").trim();

  const points = Number(pointsRaw);
  if (!studentId || !assignmentId || !pointsRaw || !Number.isFinite(points) || points < 0) {
    redirect(`/dashboard/students/${studentId}/gradebook?error=${encodeURIComponent("Enter a valid score.")}`);
  }

  const { supabase } = await requireOrganization();
  const { error } = await supabase.rpc("grade_student_assignment", {
    p_student_assignment_id: assignmentId,
    p_points_earned: points,
    p_teacher_feedback: teacherFeedback || null,
    p_change_reason: changeReason || null,
  });

  if (error) {
    redirect(`/dashboard/students/${studentId}/gradebook?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath(`/dashboard/students/${studentId}`);
  revalidatePath(`/dashboard/students/${studentId}/gradebook`);
  revalidatePath("/student");
  redirect(`/dashboard/students/${studentId}/gradebook?graded=1`);
}
