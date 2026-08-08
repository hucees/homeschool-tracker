import Link from "next/link";
import { notFound } from "next/navigation";
import { ProgressReportDocument } from "@/components/progress-report-document";
import { StudentShell } from "@/components/student-shell";
import { requireStudent } from "@/lib/auth";
import type { StudentProgressSnapshot } from "@/lib/student-progress";

export default async function StudentOfficialReportPage({
  params,
}: {
  params: Promise<{ reportId: string }>;
}) {
  const { reportId } = await params;
  const { supabase, student, organization } = await requireStudent();
  const studentName = student.preferred_name || student.first_name;

  const { data: report } = await supabase
    .from("report_snapshots")
    .select("id,version,report_type,status,snapshot_data,snapshot_sha256,generated_at")
    .eq("organization_id", organization.id)
    .eq("student_id", student.id)
    .eq("id", reportId)
    .eq("status", "official")
    .maybeSingle();

  if (!report) notFound();

  return (
    <StudentShell
      studentName={studentName}
      organizationName={organization.name}
    >
      <div className="print-hidden mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
          <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">Official report</div>
          <h1 className="mt-1 text-2xl font-bold sm:text-3xl">Saved academic record</h1>
        </div>
        <Link href="/student/progress" className="text-sm font-bold text-[#23685a] hover:underline">
          ← Back to reports
        </Link>
      </div>

      <ProgressReportDocument
        snapshot={report.snapshot_data as StudentProgressSnapshot}
        official
        version={report.version}
        status={report.status}
        snapshotSha256={report.snapshot_sha256}
        generatedAt={report.generated_at}
      />
    </StudentShell>
  );
}
