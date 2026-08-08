import Link from "next/link";
import { notFound } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { StatusPill } from "@/components/status-pill";
import { TranscriptDocument } from "@/components/transcript-document";
import { requireOrganization } from "@/lib/auth";
import { localDateInTimezone } from "@/lib/student-login";
import { buildStudentTranscriptSnapshot } from "@/lib/student-transcript";
import { generateOfficialTranscript } from "./actions";

export default async function StudentTranscriptPage({
  params,
  searchParams,
}: {
  params: Promise<{ studentId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { studentId } = await params;
  const query = await searchParams;
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
  } catch {
    notFound();
  }

  const { data: transcriptData } = await supabase
    .from("transcript_snapshots")
    .select("id,version,status,generated_at,snapshot_sha256")
    .eq("organization_id", organization.id)
    .eq("student_id", studentId)
    .order("generated_at", { ascending: false });

  const transcripts = transcriptData ?? [];

  return (
    <AppShell organizationName={organization.name}>
      <div className="grid gap-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <Link
            href={`/dashboard/students/${studentId}`}
            className="text-sm font-bold text-[#23685a] hover:underline"
          >
            ← Back to student
          </Link>
          <div className="text-xs font-semibold text-[#718087]">
            Permanent academic record
          </div>
        </div>

        {query.error && (
          <div className="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
            {query.error}
          </div>
        )}

        <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
          <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
            <div>
              <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
                Transcript control
              </div>
              <h1 className="mt-1 text-2xl font-bold sm:text-3xl">
                Academic record & transcripts
              </h1>
              <p className="mt-2 max-w-3xl text-sm leading-6 text-[#617078]">
                The live record below updates from permanent academic history. Issuing an official transcript freezes the exact record into a numbered immutable snapshot.
              </p>
            </div>
            <form action={generateOfficialTranscript}>
              <input type="hidden" name="student_id" value={studentId} />
              <button className="w-full rounded-xl bg-[#23685a] px-5 py-3 text-sm font-bold text-white hover:bg-[#174d43] sm:w-auto">
                Issue official transcript
              </button>
            </form>
          </div>

          {snapshot.cumulative.completed_courses === 0 && (
            <div className="mt-4 rounded-2xl border border-[#cfdde6] bg-[#eef5fa] p-4 text-sm leading-6 text-[#345f80]">
              This student does not have a completed course record yet. An official transcript can still be issued for testing or record purposes, but the completed-course section will remain empty until a course is genuinely completed.
            </div>
          )}
        </section>

        <TranscriptDocument snapshot={snapshot} official={false} />

        <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
          <div className="flex flex-wrap items-end justify-between gap-3">
            <div>
              <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">
                Issued records
              </div>
              <h2 className="mt-1 text-xl font-bold">Official transcripts</h2>
            </div>
            <StatusPill tone="blue">{transcripts.length} version(s)</StatusPill>
          </div>

          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            {transcripts.length ? (
              transcripts.map((transcript) => (
                <Link
                  key={transcript.id}
                  href={`/dashboard/students/${studentId}/transcripts/${transcript.id}`}
                  className="rounded-2xl border border-[#dfe7e3] bg-[#fbfcfb] p-4 transition hover:border-[#b8cdc4] hover:bg-[#f4f9f6]"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <div className="font-bold">Official Transcript</div>
                      <div className="mt-1 text-xs text-[#718087]">
                        Generated {new Date(transcript.generated_at).toLocaleString()}
                      </div>
                    </div>
                    <StatusPill tone={transcript.status === "official" ? "green" : "gray"}>
                      {transcript.status}
                    </StatusPill>
                  </div>
                  <div className="mt-3 text-xs font-bold text-[#456f91]">
                    Version {transcript.version} · View / Save PDF
                  </div>
                </Link>
              ))
            ) : (
              <div className="rounded-xl bg-[#f8faf8] p-4 text-sm text-[#617078] sm:col-span-2">
                No official transcript has been issued yet.
              </div>
            )}
          </div>
        </section>
      </div>
    </AppShell>
  );
}
