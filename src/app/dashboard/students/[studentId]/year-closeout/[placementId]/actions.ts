"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireOrganization } from "@/lib/auth";

function value(formData: FormData, key: string) {
  return String(formData.get(key) ?? "").trim();
}

export async function closeAcademicYear(formData: FormData) {
  const studentId = value(formData, "student_id");
  const placementId = value(formData, "placement_id");
  const closeDate = value(formData, "close_date");
  const decision = value(formData, "decision");
  const nextAcademicYearId = value(formData, "next_academic_year_id");
  const nextAcademicYearName = value(formData, "next_academic_year_name");
  const nextYearStart = value(formData, "next_year_start");
  const nextYearEnd = value(formData, "next_year_end");
  const nextGradeLevelId = value(formData, "next_grade_level_id");
  const reason = value(formData, "reason");

  const { supabase } = await requireOrganization();
  const { error } = await supabase.rpc("close_student_academic_year", {
    p_student_academic_year_id: placementId,
    p_close_date: closeDate,
    p_decision: decision,
    p_next_academic_year_id: nextAcademicYearId || null,
    p_next_academic_year_name: nextAcademicYearName || null,
    p_next_year_start: nextYearStart || null,
    p_next_year_end: nextYearEnd || null,
    p_next_grade_level_id: nextGradeLevelId || null,
    p_reason: reason || null,
  });

  if (error) {
    redirect(`/dashboard/students/${studentId}/year-closeout/${placementId}?error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath(`/dashboard/students/${studentId}`);
  revalidatePath(`/dashboard/students/${studentId}/transcript`);
  redirect(`/dashboard/students/${studentId}/year-closeout/${placementId}?closed=1`);
}
