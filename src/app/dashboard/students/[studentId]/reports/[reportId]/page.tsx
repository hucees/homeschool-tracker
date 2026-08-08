import Link from "next/link";
import { notFound } from "next/navigation";
import { ProgressReportDocument } from "@/components/progress-report-document";
import { requireOrganization } from "@/lib/auth";
import type { StudentProgressSnapshot } from "@/lib/student-progress";

export default async function OfficialReportPage({
  params,
  searchParams,
}: {
  params: Promise<{ studentId: string; reportId: string }>;
  searchParams: Promise<{ created?: string }>;
}) {
  const { studentId, reportId } = await params;
  const query = await searchParams;
  const { supabase, organization } = await requireOrganization();

  const { data: report } = await supabase
    .from("report_snapshots")
    .select("id,student_id,version,report_type,status,period_start,period_end,snapshot_data,snapshot_sha256,generated_at")
    .eq("organization_id", organization.id)
    .eq("student_id", studentId)
    .eq("id", reportId)
    .maybeSingle();

  if (!report) notFound();

  return (
    <main className="min-h-screen px-3 py-4 sm:px-5 sm:py-6">
      <div className="mx-auto max-w-5xl">
        <div className="print-hidden mb-5 flex flex-wrap items-center justify-between gap-3">
          <Link
            href={`/dashboard/students/${studentId}/progress`}
            className="text-sm font-bold text-[#23685a] hover:underline"
          >
            ← Back to progress
          </Link>
          <div className="text-xs font-semibold text-[#718087]">{organization.name}</div>
        </div>

        {query.created && (
          <div className="print-hidden mb-5 rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm font-semibold text-emerald-800">
            Official report created and frozen successfully.
          </div>
        )}

        <ProgressReportDocument
          snapshot={report.snapshot_data as StudentProgressSnapshot}
          official
          version={report.version}
          status={report.status}
          snapshotSha256={report.snapshot_sha256}
          generatedAt={report.generated_at}
        />
      </div>
    </main>
  );
}
