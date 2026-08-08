import Link from "next/link";
import { notFound } from "next/navigation";
import { StudentShell } from "@/components/student-shell";
import { TranscriptDocument } from "@/components/transcript-document";
import { requireStudent } from "@/lib/auth";
import type { StudentTranscriptSnapshot } from "@/lib/student-transcript";

export default async function StudentOfficialTranscriptPage({
  params,
}: {
  params: Promise<{ transcriptId: string }>;
}) {
  const { transcriptId } = await params;
  const { supabase, student, organization } = await requireStudent();
  const studentName = student.preferred_name || student.first_name;

  const { data: transcript } = await supabase
    .from("transcript_snapshots")
    .select("id,version,status,snapshot_data,snapshot_sha256,generated_at")
    .eq("organization_id", organization.id)
    .eq("student_id", student.id)
    .eq("id", transcriptId)
    .eq("status", "official")
    .maybeSingle();

  if (!transcript) notFound();

  return (
    <StudentShell studentName={studentName} organizationName={organization.name}>
      <div className="print-hidden mb-5">
        <Link
          href="/student/academic-record"
          className="text-sm font-bold text-[#23685a] hover:underline"
        >
          ← Back to academic record
        </Link>
      </div>

      <TranscriptDocument
        snapshot={transcript.snapshot_data as StudentTranscriptSnapshot}
        official
        version={transcript.version}
        status={transcript.status}
        snapshotSha256={transcript.snapshot_sha256}
        generatedAt={transcript.generated_at}
      />
    </StudentShell>
  );
}
