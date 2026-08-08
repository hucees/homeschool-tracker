import Link from "next/link";
import { notFound } from "next/navigation";
import { TranscriptDocument } from "@/components/transcript-document";
import { requireOrganization } from "@/lib/auth";
import type { StudentTranscriptSnapshot } from "@/lib/student-transcript";

export default async function OfficialTranscriptPage({
  params,
  searchParams,
}: {
  params: Promise<{ studentId: string; transcriptId: string }>;
  searchParams: Promise<{ created?: string }>;
}) {
  const { studentId, transcriptId } = await params;
  const query = await searchParams;
  const { supabase, organization } = await requireOrganization();

  const { data: transcript } = await supabase
    .from("transcript_snapshots")
    .select("id,student_id,version,status,snapshot_data,snapshot_sha256,generated_at")
    .eq("organization_id", organization.id)
    .eq("student_id", studentId)
    .eq("id", transcriptId)
    .maybeSingle();

  if (!transcript) notFound();

  return (
    <main className="min-h-screen px-3 py-4 sm:px-5 sm:py-6">
      <div className="mx-auto max-w-6xl">
        <div className="print-hidden mb-5 flex flex-wrap items-center justify-between gap-3">
          <Link
            href={`/dashboard/students/${studentId}/transcript`}
            className="text-sm font-bold text-[#23685a] hover:underline"
          >
            ← Back to academic record
          </Link>
          <div className="text-xs font-semibold text-[#718087]">
            {organization.name}
          </div>
        </div>

        {query.created && (
          <div className="print-hidden mb-5 rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm font-semibold text-emerald-800">
            Official transcript issued and frozen successfully.
          </div>
        )}

        <TranscriptDocument
          snapshot={transcript.snapshot_data as StudentTranscriptSnapshot}
          official
          version={transcript.version}
          status={transcript.status}
          snapshotSha256={transcript.snapshot_sha256}
          generatedAt={transcript.generated_at}
        />
      </div>
    </main>
  );
}
