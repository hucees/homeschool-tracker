import Link from "next/link";
import { notFound } from "next/navigation";
import { DiplomaDocument } from "@/components/diploma-document";
import { requireOrganization } from "@/lib/auth";
import type { DiplomaSnapshot } from "@/lib/student-diploma";

export default async function InstructorDiplomaPage({ params, searchParams }: { params: Promise<{ studentId: string; diplomaId: string }>; searchParams: Promise<{ created?: string }> }) {
  const { studentId, diplomaId } = await params;
  const query = await searchParams;
  const { supabase, organization } = await requireOrganization();
  const { data: diploma } = await supabase.from("diploma_snapshots")
    .select("id,version,diploma_number,status,snapshot_data,snapshot_sha256,issued_at")
    .eq("organization_id", organization.id).eq("student_id", studentId).eq("id", diplomaId).maybeSingle();
  if (!diploma) notFound();

  return (
    <main className="min-h-screen px-3 py-4 sm:px-5 sm:py-6">
      <div className="mx-auto max-w-7xl">
        <div className="print-hidden mb-5 flex flex-wrap items-center justify-between gap-3"><Link href={`/dashboard/students/${studentId}/diploma`} className="text-sm font-bold text-[#23685a] hover:underline">← Back to diploma control</Link><div className="text-xs font-semibold text-[#718087]">{organization.name}</div></div>
        {query.created && <div className="print-hidden mb-5 rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm font-semibold text-emerald-800">Official homeschool diploma issued successfully.</div>}
        <DiplomaDocument snapshot={diploma.snapshot_data as DiplomaSnapshot} status={diploma.status} snapshotSha256={diploma.snapshot_sha256} />
      </div>
    </main>
  );
}
