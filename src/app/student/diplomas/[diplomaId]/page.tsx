import Link from "next/link";
import { notFound } from "next/navigation";
import { DiplomaDocument } from "@/components/diploma-document";
import { StudentShell } from "@/components/student-shell";
import { requireStudent } from "@/lib/auth";
import type { DiplomaSnapshot } from "@/lib/student-diploma";

export default async function StudentDiplomaPage({ params }: { params: Promise<{ diplomaId: string }> }) {
  const { diplomaId } = await params;
  const { supabase, student, organization } = await requireStudent();
  const studentName = student.preferred_name || student.first_name;
  const { data: diploma } = await supabase.from("diploma_snapshots")
    .select("id,status,snapshot_data,snapshot_sha256")
    .eq("organization_id", organization.id).eq("student_id", student.id).eq("id", diplomaId).eq("status", "official").maybeSingle();
  if (!diploma) notFound();

  return (
    <StudentShell studentName={studentName} organizationName={organization.name}>
      <div className="print-hidden mb-5"><Link href="/student/academic-record" className="text-sm font-bold text-[#23685a] hover:underline">← Back to academic record</Link></div>
      <DiplomaDocument snapshot={diploma.snapshot_data as DiplomaSnapshot} status={diploma.status} snapshotSha256={diploma.snapshot_sha256} />
    </StudentShell>
  );
}
