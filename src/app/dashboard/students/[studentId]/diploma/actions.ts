"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireOrganization } from "@/lib/auth";
import { localDateInTimezone } from "@/lib/student-login";
import { buildDiplomaSnapshot } from "@/lib/student-diploma";
import { buildStudentTranscriptSnapshot } from "@/lib/student-transcript";

function value(formData: FormData, key: string) {
  return String(formData.get(key) ?? "").trim();
}

export async function issueDiploma(formData: FormData) {
  const studentId = value(formData, "student_id");
  const graduationDate = value(formData, "graduation_date");
  const issueDate = value(formData, "issue_date");
  const title = value(formData, "diploma_title") || "Homeschool High School Diploma";
  const statement = value(formData, "statement") || "has satisfactorily completed the course of study prescribed by this homeschool and is hereby awarded this diploma.";
  const honors = value(formData, "honors");
  const signatoryName = value(formData, "signatory_name");
  const signatoryTitle = value(formData, "signatory_title") || "Homeschool Administrator";
  const attestation = value(formData, "attestation");
  const markGraduated = value(formData, "mark_graduated") === "on";

  if (!studentId || !graduationDate || !issueDate || !signatoryName) {
    redirect(`/dashboard/students/${studentId}/diploma?error=${encodeURIComponent("Graduation date, issue date, and signatory name are required.")}`);
  }

  if (attestation !== "on") {
    redirect(`/dashboard/students/${studentId}/diploma?error=${encodeURIComponent("You must confirm the administrator attestation before issuing an official diploma.")}`);
  }

  const { supabase, organization } = await requireOrganization();
  const today = localDateInTimezone(organization.timezone);

  let transcript;
  try {
    transcript = await buildStudentTranscriptSnapshot({
      supabase,
      organization,
      studentId,
      recordAsOf: today,
    });
  } catch (error) {
    redirect(`/dashboard/students/${studentId}/diploma?error=${encodeURIComponent(error instanceof Error ? error.message : "Unable to build the student's academic record.")}`);
  }

  const snapshot = buildDiplomaSnapshot({
    transcript,
    title,
    statement,
    honors: honors || null,
    signatoryName,
    signatoryTitle,
    graduationDate,
    markGraduated,
  });

  const { data: diplomaId, error } = await supabase.rpc("issue_homeschool_diploma", {
    p_student_id: studentId,
    p_graduation_date: graduationDate,
    p_issue_date: issueDate,
    p_snapshot_data: snapshot,
    p_mark_graduated: markGraduated,
  });

  if (error || !diplomaId) {
    redirect(`/dashboard/students/${studentId}/diploma?error=${encodeURIComponent(error?.message ?? "The diploma could not be issued.")}`);
  }

  revalidatePath(`/dashboard/students/${studentId}`);
  revalidatePath(`/dashboard/students/${studentId}/diploma`);
  revalidatePath(`/dashboard/students/${studentId}/transcript`);
  redirect(`/dashboard/students/${studentId}/diplomas/${diplomaId}?created=1`);
}
