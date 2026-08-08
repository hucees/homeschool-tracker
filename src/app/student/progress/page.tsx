import Link from "next/link";
import { StudentShell } from "@/components/student-shell";
import { ProgressReportDocument } from "@/components/progress-report-document";
import { StatusPill } from "@/components/status-pill";
import { requireStudent } from "@/lib/auth";
import { localDateInTimezone } from "@/lib/student-login";
import { buildStudentProgressSnapshot } from "@/lib/student-progress";

type Report = {
  id: string;
  version: number;
  report_type: string;
  period_start: string;
  period_end: string;
  generated_at: string;
};

function reportLabel(value: string) {
  return {
    progress_report: "Progress Report",
    quarter_report: "Quarter Report",
    semester_report: "Semester Report",
    annual_report: "Annual Report",
    attendance_report: "Attendance Report",
    competency_report: "Competency Report",
  }[value] ?? value;
}

export default async function StudentProgressPage() {
  const { supabase, student, organization } = await requireStudent();
  const today = localDateInTimezone(organization.timezone);
  const studentName = student.preferred_name || student.first_name;

  const [snapshot, { data: reportData }] = await Promise.all([
    buildStudentProgressSnapshot({
      supabase,
      organization,
      studentId: student.id,
      periodEnd: today,
      reportType: "progress_report",
    }),
    supabase
      .from("report_snapshots")
      .select("id,version,report_type,period_start,period_end,generated_at")
      .eq("organization_id", organization.id)
      .eq("student_id", student.id)
      .eq("status", "official")
      .order("generated_at", { ascending: false }),
  ]);

  const reports = (reportData ?? []) as Report[];

  return (
    <StudentShell
      studentName={studentName}
      organizationName={organization.name}
    >
      <div className="print-hidden mb-5 flex flex-wrap items-center justify-between gap-3">
        <div>
          <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">Progress & reports</div>
          <h1 className="mt-1 text-2xl font-bold sm:text-3xl">Your progress report</h1>
        </div>
        <Link href="/student" className="text-sm font-bold text-[#23685a] hover:underline">
          ← Back to school work
        </Link>
      </div>

      <ProgressReportDocument
        snapshot={snapshot}
        official={false}
      />

      <section className="print-hidden mt-8 rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">Permanent records</div>
            <h2 className="mt-1 text-xl font-bold">Official reports</h2>
            <p className="mt-1 text-sm text-[#617078]">
              Official reports are issued by your instructor and remain frozen exactly as they were generated.
            </p>
          </div>
          <StatusPill tone="blue">{reports.length} available</StatusPill>
        </div>

        <div className="mt-4 grid gap-3 sm:grid-cols-2">
          {reports.length ? reports.map((report) => (
            <Link
              key={report.id}
              href={`/student/reports/${report.id}`}
              className="rounded-2xl border border-[#dfe7e3] bg-[#fbfcfb] p-4 transition hover:border-[#b8cdc4] hover:bg-[#f4f9f6]"
            >
              <div className="flex items-start justify-between gap-3">
                <div>
                  <div className="font-bold">{reportLabel(report.report_type)}</div>
                  <div className="mt-1 text-xs text-[#718087]">
                    {report.period_start} through {report.period_end}
                  </div>
                </div>
                <StatusPill tone="green">Official</StatusPill>
              </div>
              <div className="mt-3 text-xs font-bold text-[#456f91]">
                Version {report.version} · View / Save PDF
              </div>
            </Link>
          )) : (
            <div className="rounded-xl bg-[#f8faf8] p-4 text-sm text-[#617078] sm:col-span-2">
              No official reports have been issued yet. Your live report above is still available anytime.
            </div>
          )}
        </div>
      </section>
    </StudentShell>
  );
}
