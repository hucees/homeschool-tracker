import Link from "next/link";
import { StudentShell } from "@/components/student-shell";
import { StatusPill } from "@/components/status-pill";
import { TranscriptDocument } from "@/components/transcript-document";
import { requireStudent } from "@/lib/auth";
import { localDateInTimezone } from "@/lib/student-login";
import { buildStudentTranscriptSnapshot } from "@/lib/student-transcript";

export default async function StudentAcademicRecordPage() {
  const { supabase, student, organization } = await requireStudent();
  const today = localDateInTimezone(organization.timezone);
  const studentName = student.preferred_name || student.first_name;

  const [snapshot, { data: transcriptData }, { data: diplomaData }] = await Promise.all([
    buildStudentTranscriptSnapshot({ supabase, organization, studentId: student.id, recordAsOf: today }),
    supabase.from("transcript_snapshots").select("id,version,status,generated_at")
      .eq("organization_id", organization.id).eq("student_id", student.id).eq("status", "official").order("generated_at", { ascending: false }),
    supabase.from("diploma_snapshots").select("id,version,diploma_number,status,graduation_date,issue_date")
      .eq("organization_id", organization.id).eq("student_id", student.id).eq("status", "official").order("issued_at", { ascending: false }),
  ]);

  const transcripts = transcriptData ?? [];
  const diplomas = diplomaData ?? [];

  return (
    <StudentShell studentName={studentName} organizationName={organization.name}>
      <div className="print-hidden mb-5 flex flex-wrap items-center justify-between gap-3">
        <div><div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">Academic record</div><h1 className="mt-1 text-2xl font-bold sm:text-3xl">Your cumulative school record</h1></div>
        <Link href="/student" className="text-sm font-bold text-[#23685a] hover:underline">← Back to school work</Link>
      </div>

      {diplomas.length > 0 && (
        <section className="print-hidden mb-6 rounded-2xl border border-[#dfc994] bg-[#fff9eb] p-5 shadow-sm sm:p-6">
          <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#8a6728]">Diploma</div>
          <h2 className="mt-1 text-xl font-bold">Official homeschool diploma</h2>
          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            {diplomas.map((diploma) => (
              <Link key={diploma.id} href={`/student/diplomas/${diploma.id}`} className="rounded-2xl border border-[#dfc994] bg-white/70 p-4 hover:bg-white">
                <div className="flex items-start justify-between gap-3"><div><div className="font-bold">{diploma.diploma_number}</div><div className="mt-1 text-xs text-[#765f39]">Graduation {diploma.graduation_date}</div></div><StatusPill tone="green">Official</StatusPill></div>
                <div className="mt-3 text-xs font-bold text-[#8a6728]">Open / Save PDF</div>
              </Link>
            ))}
          </div>
        </section>
      )}

      <TranscriptDocument snapshot={snapshot} official={false} />

      <section className="print-hidden mt-8 rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
        <div className="flex flex-wrap items-end justify-between gap-3"><div><div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">Permanent records</div><h2 className="mt-1 text-xl font-bold">Official transcripts</h2><p className="mt-1 text-sm text-[#617078]">Only an instructor can issue an official transcript. You can view and save issued versions here.</p></div><StatusPill tone="blue">{transcripts.length} available</StatusPill></div>
        <div className="mt-4 grid gap-3 sm:grid-cols-2">
          {transcripts.length ? transcripts.map((transcript) => (
            <Link key={transcript.id} href={`/student/transcripts/${transcript.id}`} className="rounded-2xl border border-[#dfe7e3] bg-[#fbfcfb] p-4 transition hover:border-[#b8cdc4] hover:bg-[#f4f9f6]">
              <div className="flex items-start justify-between gap-3"><div><div className="font-bold">Official Academic Transcript</div><div className="mt-1 text-xs text-[#718087]">Generated {new Date(transcript.generated_at).toLocaleString()}</div></div><StatusPill tone="green">Official</StatusPill></div>
              <div className="mt-3 text-xs font-bold text-[#456f91]">Version {transcript.version} · View / Save PDF</div>
            </Link>
          )) : <div className="rounded-xl bg-[#f8faf8] p-4 text-sm text-[#617078] sm:col-span-2">No official transcript has been issued yet.</div>}
        </div>
      </section>
    </StudentShell>
  );
}
