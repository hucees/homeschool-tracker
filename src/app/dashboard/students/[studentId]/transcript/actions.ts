"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireOrganization } from "@/lib/auth";
import { localDateInTimezone } from "@/lib/student-login";
import { buildStudentTranscriptSnapshot } from "@/lib/student-transcript";

export async function generateOfficialTranscript(formData: FormData) {
  const studentId = String(formData.get("student_id") ?? "").trim();

  if (!studentId) {
    redirect("/dashboard/students?error=Student%20is%20required");
  }

  const { supabase, organization } = await requireOrganization();
  const today = localDateInTimezone(organization.timezone);

  let snapshot;
  try {
    snapshot = await buildStudentTranscriptSnapshot({
      supabase,
      organization,
      studentId,
      recordAsOf: today,
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unable to build the academic record.";
    redirect(
      `/dashboard/students/${studentId}/transcript?error=${encodeURIComponent(message)}`
    );
  }

  const { data: transcriptId, error } = await supabase.rpc(
    "create_official_transcript",
    {
      p_student_id: studentId,
      p_snapshot_data: snapshot,
    }
  );

  if (error || !transcriptId) {
    redirect(
      `/dashboard/students/${studentId}/transcript?error=${encodeURIComponent(
        error?.message ?? "The official transcript could not be issued."
      )}`
    );
  }

  revalidatePath(`/dashboard/students/${studentId}`);
  revalidatePath(`/dashboard/students/${studentId}/transcript`);

  redirect(
    `/dashboard/students/${studentId}/transcripts/${transcriptId}?created=1`
  );
}
