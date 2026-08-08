"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireOrganization } from "@/lib/auth";
import { buildStudentProgressSnapshot } from "@/lib/student-progress";

const REPORT_TYPES = new Set([
  "progress_report",
  "quarter_report",
  "semester_report",
  "annual_report",
  "attendance_report",
  "competency_report",
]);

function dateValue(value: FormDataEntryValue | null) {
  const text = String(value ?? "").trim();
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : null;
}

export async function generateOfficialReport(formData: FormData) {
  const studentId = String(formData.get("student_id") ?? "").trim();
  const reportType = String(formData.get("report_type") ?? "").trim();
  const periodStart = dateValue(formData.get("period_start"));
  const periodEnd = dateValue(formData.get("period_end"));
  const teacherComments = String(formData.get("teacher_comments") ?? "").trim();

  if (!studentId || !REPORT_TYPES.has(reportType) || !periodStart || !periodEnd) {
    redirect(
      `/dashboard/students/${studentId}/progress?error=${encodeURIComponent(
        "Choose a valid report type and reporting period."
      )}`
    );
  }

  if (periodEnd < periodStart) {
    redirect(
      `/dashboard/students/${studentId}/progress?error=${encodeURIComponent(
        "Report end date cannot be before the start date."
      )}`
    );
  }

  const { supabase, organization } = await requireOrganization();

  let snapshot;
  try {
    snapshot = await buildStudentProgressSnapshot({
      supabase,
      organization,
      studentId,
      periodStart,
      periodEnd,
      reportType,
      teacherComments: teacherComments || null,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unable to calculate the report.";
    redirect(
      `/dashboard/students/${studentId}/progress?error=${encodeURIComponent(message)}`
    );
  }

  const { data: reportId, error } = await supabase.rpc(
    "create_official_progress_report",
    {
      p_student_id: studentId,
      p_academic_year_id: snapshot.academic_year.id,
      p_report_type: reportType,
      p_period_start: periodStart,
      p_period_end: periodEnd,
      p_snapshot_data: snapshot,
    }
  );

  if (error || !reportId) {
    redirect(
      `/dashboard/students/${studentId}/progress?error=${encodeURIComponent(
        error?.message ?? "The official report could not be saved."
      )}`
    );
  }

  revalidatePath(`/dashboard/students/${studentId}`);
  revalidatePath(`/dashboard/students/${studentId}/progress`);

  redirect(
    `/dashboard/students/${studentId}/reports/${reportId}?created=1`
  );
}
