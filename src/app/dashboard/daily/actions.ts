"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireOrganization } from "@/lib/auth";

const attendanceStatuses = new Set([
  "present",
  "partial",
  "absent",
  "excused",
  "holiday",
  "not_scheduled",
]);

const reviewStatuses = new Set(["reviewed", "needs_revision", "approved"]);

function isDate(value: string) {
  return /^\d{4}-\d{2}-\d{2}$/.test(value);
}

export async function reviewStudentDay(formData: FormData) {
  const placementId = String(formData.get("student_academic_year_id") ?? "").trim();
  const recordDate = String(formData.get("record_date") ?? "").trim();
  const attendanceStatus = String(formData.get("attendance_status") ?? "").trim();
  const reviewStatus = String(formData.get("review_status") ?? "approved").trim();
  const minutesRaw = String(formData.get("instructional_minutes") ?? "").trim();
  const teacherSummary = String(formData.get("teacher_summary") ?? "").trim();
  const attendanceNotes = String(formData.get("attendance_notes") ?? "").trim();

  if (!placementId || !isDate(recordDate)) {
    redirect(`/dashboard/daily?error=${encodeURIComponent("Student placement or date is missing.")}`);
  }

  if (!attendanceStatuses.has(attendanceStatus)) {
    redirect(`/dashboard/daily?date=${recordDate}&error=${encodeURIComponent("Choose a valid attendance status.")}`);
  }

  if (!reviewStatuses.has(reviewStatus)) {
    redirect(`/dashboard/daily?date=${recordDate}&error=${encodeURIComponent("Choose a valid review status.")}`);
  }

  const minutes = minutesRaw ? Number.parseInt(minutesRaw, 10) : null;
  if (minutes !== null && (!Number.isFinite(minutes) || minutes < 0 || minutes > 1440)) {
    redirect(`/dashboard/daily?date=${recordDate}&error=${encodeURIComponent("Instructional minutes must be between 0 and 1440.")}`);
  }

  const { supabase } = await requireOrganization();
  const { error } = await supabase.rpc("review_student_day", {
    p_student_academic_year_id: placementId,
    p_record_date: recordDate,
    p_attendance_status: attendanceStatus,
    p_instructional_minutes: minutes,
    p_teacher_summary: teacherSummary || null,
    p_attendance_notes: attendanceNotes || null,
    p_review_status: reviewStatus,
  });

  if (error) {
    redirect(`/dashboard/daily?date=${recordDate}&error=${encodeURIComponent(error.message)}`);
  }

  revalidatePath("/dashboard");
  revalidatePath("/dashboard/daily");
  redirect(`/dashboard/daily?date=${recordDate}&reviewed=1`);
}
