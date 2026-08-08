"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireOrganization } from "@/lib/auth";

function value(formData: FormData, key: string) {
  return String(formData.get(key) ?? "").trim();
}

export async function completeCourse(formData: FormData) {
  const studentId = value(formData, "student_id");
  const enrollmentId = value(formData, "enrollment_id");
  const completionDate = value(formData, "completion_date");
  const teacherSummary = value(formData, "teacher_summary");
  const overrideReason = value(formData, "override_reason");

  if (!studentId || !enrollmentId || !completionDate) {
    redirect(`/dashboard/students/${studentId}/courses/${enrollmentId}?error=${encodeURIComponent("Student, course, and completion date are required.")}`);
  }

  const { supabase } = await requireOrganization();
  const { error } = await supabase.rpc("complete_student_course", {
    p_student_course_enrollment_id: enrollmentId,
    p_completion_date: completionDate,
    p_teacher_summary: teacherSummary || null,
    p_override_reason: overrideReason || null,
  });

  if (error) {
    redirect(`/dashboard/students/${studentId}/courses/${enrollmentId}?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath(`/dashboard/students/${studentId}`);
  revalidatePath(`/dashboard/students/${studentId}/progress`);
  revalidatePath(`/dashboard/students/${studentId}/courses/${enrollmentId}`);
  redirect(`/dashboard/students/${studentId}/courses/${enrollmentId}?completed=1`);
}

export async function recordProgression(formData: FormData) {
  const studentId = value(formData, "student_id");
  const sourceEnrollmentId = value(formData, "source_enrollment_id");
  const decision = value(formData, "decision");
  const targetCourseVersionId = value(formData, "target_course_version_id");
  const targetStudentAcademicYearId = value(formData, "target_student_academic_year_id");
  const startDate = value(formData, "start_date");
  const reason = value(formData, "reason");

  if (!studentId || !sourceEnrollmentId || !decision) {
    redirect(`/dashboard/students/${studentId}/courses/${sourceEnrollmentId}?error=${encodeURIComponent("A progression decision is required.")}`);
  }

  const { supabase } = await requireOrganization();
  const { error } = await supabase.rpc("record_course_progression", {
    p_source_enrollment_id: sourceEnrollmentId,
    p_decision: decision,
    p_target_course_version_id: targetCourseVersionId || null,
    p_target_student_academic_year_id: targetStudentAcademicYearId || null,
    p_start_date: startDate || null,
    p_reason: reason || null,
  });

  if (error) {
    redirect(`/dashboard/students/${studentId}/courses/${sourceEnrollmentId}?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath(`/dashboard/students/${studentId}`);
  revalidatePath(`/dashboard/students/${studentId}/progress`);
  revalidatePath(`/dashboard/students/${studentId}/courses/${sourceEnrollmentId}`);
  redirect(`/dashboard/students/${studentId}/courses/${sourceEnrollmentId}?progressed=1`);
}
