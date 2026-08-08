import { PrintButton } from "@/components/print-button";
import { StatusPill } from "@/components/status-pill";
import type { DiplomaSnapshot } from "@/lib/student-diploma";

export function DiplomaDocument({
  snapshot,
  status,
  snapshotSha256,
}: {
  snapshot: DiplomaSnapshot;
  status: string;
  snapshotSha256: string;
}) {
  return (
    <div className="grid gap-4">
      <style>{`
        @media print {
          @page { size: landscape; margin: 0.35in; }
          .diploma-page { min-height: 7in !important; }
        }
      `}</style>

      <div className="print-hidden flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-[#dfe7e3] bg-white/85 p-4 shadow-sm">
        <div>
          <div className="font-bold text-[#26363d]">Official homeschool diploma</div>
          <div className="mt-0.5 text-xs text-[#718087]">Permanent diploma #{snapshot.diploma_number}</div>
        </div>
        <PrintButton label="Print / Save PDF" />
      </div>

      <article className="diploma-page print-document relative overflow-hidden rounded-[28px] border-[10px] border-[#1f5f53] bg-[#fffdf8] p-3 shadow-[0_28px_80px_rgba(30,68,56,0.14)]">
        <div className="absolute inset-5 rounded-[18px] border border-[#c9a96d]" />
        <div className="absolute inset-8 rounded-[14px] border border-[#e5d4ad]" />

        <div className="relative z-10 flex min-h-[620px] flex-col items-center justify-center px-5 py-12 text-center sm:px-10 lg:px-16">
          <div className="text-xs font-bold uppercase tracking-[0.28em] text-[#7a6843]">{snapshot.organization.name}</div>
          <div className="mt-6 text-sm font-semibold uppercase tracking-[0.2em] text-[#456f91]">Official Homeschool Diploma</div>
          <h1 className="mt-3 font-serif text-4xl font-bold tracking-tight text-[#1c3f37] sm:text-5xl lg:text-6xl">{snapshot.diploma.title}</h1>
          <p className="mt-8 max-w-3xl font-serif text-lg leading-8 text-[#4c514e] sm:text-xl">This certifies that</p>
          <div className="mt-3 border-b-2 border-[#c9a96d] px-8 pb-2 font-serif text-3xl font-bold text-[#172329] sm:text-4xl">{snapshot.student.legal_name}</div>
          <p className="mt-6 max-w-3xl font-serif text-base leading-8 text-[#4c514e] sm:text-lg">{snapshot.diploma.statement}</p>

          {snapshot.diploma.honors && (
            <div className="mt-4 rounded-full border border-[#d9c597] bg-[#fff9eb] px-5 py-2 text-sm font-bold text-[#7a5c25]">{snapshot.diploma.honors}</div>
          )}

          <div className="mt-10 grid w-full max-w-4xl gap-8 sm:grid-cols-3">
            <div>
              <div className="border-b border-[#7a8681] pb-2 font-serif font-semibold">{snapshot.graduation_date}</div>
              <div className="mt-2 text-xs uppercase tracking-wide text-[#718087]">Graduation date</div>
            </div>
            <div>
              <div className="border-b border-[#7a8681] pb-2 font-serif font-semibold">{snapshot.diploma.signatory_name}</div>
              <div className="mt-2 text-xs uppercase tracking-wide text-[#718087]">{snapshot.diploma.signatory_title}</div>
            </div>
            <div>
              <div className="border-b border-[#7a8681] pb-2 font-serif font-semibold">{snapshot.diploma_number}</div>
              <div className="mt-2 text-xs uppercase tracking-wide text-[#718087]">Diploma number</div>
            </div>
          </div>

          <div className="mt-8 flex flex-wrap items-center justify-center gap-3 text-xs text-[#718087]">
            <StatusPill tone={status === "official" ? "green" : "gray"}>{status}</StatusPill>
            <span>Version {snapshot.version}</span>
            <span>Issued {snapshot.issue_date}</span>
          </div>
          <div className="mt-4 max-w-4xl break-all font-mono text-[9px] leading-4 text-[#9aa4a0]">SHA-256 {snapshotSha256}</div>
        </div>
      </article>
    </div>
  );
}
