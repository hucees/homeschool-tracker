import { AppShell } from "@/components/app-shell";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";

export default async function StudentsPage() {
  const { supabase, organization } = await requireOrganization();
  const { data: students } = await supabase
    .from("students")
    .select("id,student_number,first_name,last_name,preferred_name,status,enrollment_date")
    .eq("organization_id", organization.id)
    .order("last_name");

  return (
    <AppShell organizationName={organization.name}>
      <section className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
        <div className="flex flex-wrap items-center justify-between gap-4"><div><p className="text-sm font-medium text-[#667085]">Instructor</p><h1 className="text-3xl font-bold">Students</h1></div><button disabled className="rounded-xl bg-slate-200 px-4 py-2.5 text-sm font-semibold text-slate-500">+ Add student (next build step)</button></div>
        <div className="mt-6 overflow-hidden rounded-xl border border-[#e4e7ec]">
          {students?.length ? students.map((student) => (
            <div key={student.id} className="flex items-center justify-between border-b border-[#eaecf0] px-4 py-4 last:border-b-0"><div><div className="font-semibold">{student.preferred_name || student.first_name} {student.last_name}</div><div className="mt-1 text-xs text-[#667085]">{student.student_number} · Enrolled {student.enrollment_date}</div></div><StatusPill>{student.status}</StatusPill></div>
          )) : <div className="p-8 text-center"><div className="font-semibold">No students yet</div><p className="mt-2 text-sm text-[#667085]">Once the database is connected, our next application step is the Add Student workflow.</p></div>}
        </div>
      </section>
    </AppShell>
  );
}
