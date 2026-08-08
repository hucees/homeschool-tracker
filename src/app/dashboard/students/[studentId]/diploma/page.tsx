import Link from "next/link";
import { notFound } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";
import { localDateInTimezone } from "@/lib/student-login";
import { buildStudentTranscriptSnapshot } from "@/lib/student-transcript";
import { issueDiploma } from "./actions";

export default async function DiplomaControlPage({
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

  const [{ data: student }, { data: diplomaData }] = await Promise.all([
    supabase.from("students")
      .select("id,student_number,first_name,middle_name,last_name,preferred_name,status,graduation_date")
      .eq("organization_id", organization.id).eq("id", studentId).maybeSingle(),
    supabase.from("diploma_snapshots")
      .select("id,version,diploma_number,status,graduation_date,issue_date,issued_at")
      .eq("organization_id", organization.id).eq("student_id", studentId).order("issued_at", { ascending: false }),
  ]);

  if (!student) notFound();

  const transcript = await buildStudentTranscriptSnapshot({ supabase, organization, studentId, recordAsOf: today });
  const legalName = [student.first_name, student.middle_name, student.last_name].filter(Boolean).join(" ");

  return (
    <AppShell organizationName={organization.name}>
      <div className="grid gap-6">
        <Link href={`/dashboard/students/${studentId}`} className="text-sm font-bold text-[#23685a] hover:underline">← Back to student</Link>

        {query.error && <div className="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{query.error}</div>}

        <section className="overflow-hidden rounded-[26px] border border-[#d7e2dd] bg-white shadow-sm">
          <div className="bg-gradient-to-br from-[#fff8e9] via-white to-[#eef7f3] p-5 sm:p-7">
            <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-start">
              <div>
                <div className="text-xs font-bold uppercase tracking-[0.18em] text-[#8a6728]">Official diploma issuance</div>
                <h1 className="mt-2 text-2xl font-bold sm:text-3xl">{legalName}</h1>
                <p className="mt-2 text-sm text-[#617078]">{student.student_number} · Current status: {student.status}</p>
              </div>
              <StatusPill tone="amber">Administrator controlled</StatusPill>
            </div>
          </div>
          <div className="grid gap-3 p-5 sm:grid-cols-2 sm:p-7 lg:grid-cols-4">
            <div className="rounded-2xl bg-[#f8faf8] p-4"><div className="text-xs text-[#718087]">Completed courses</div><div className="mt-1 text-2xl font-bold">{transcript.cumulative.completed_courses}</div></div>
            <div className="rounded-2xl bg-[#f8faf8] p-4"><div className="text-xs text-[#718087]">Current courses</div><div className="mt-1 text-2xl font-bold">{transcript.cumulative.active_courses}</div></div>
            <div className="rounded-2xl bg-[#f8faf8] p-4"><div className="text-xs text-[#718087]">Credits earned</div><div className="mt-1 text-2xl font-bold">{transcript.cumulative.credits_earned}</div></div>
            <div className="rounded-2xl bg-[#f8faf8] p-4"><div className="text-xs text-[#718087]">Diplomas issued</div><div className="mt-1 text-2xl font-bold">{diplomaData?.length ?? 0}</div></div>
          </div>
        </section>

        <section className="rounded-2xl border border-amber-200 bg-amber-50 p-5 text-sm leading-6 text-amber-950">
          The software allows an authorized homeschool administrator to issue a diploma for any student record. It does not automatically determine whether a diploma satisfies a particular outside institution&apos;s or jurisdiction&apos;s legal requirements. Review the record and use the attestation below intentionally.
        </section>

        <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
          <h2 className="text-xl font-bold">Issue official homeschool diploma</h2>
          <p className="mt-1 text-sm leading-6 text-[#617078]">Issuing creates an immutable diploma snapshot with its own diploma number, version, dates, and SHA-256 integrity hash.</p>

          <form action={issueDiploma} className="mt-5 grid gap-4">
            <input type="hidden" name="student_id" value={studentId} />
            <div className="grid gap-4 md:grid-cols-2">
              <label className="grid gap-1.5 text-sm font-semibold">Diploma title<input name="diploma_title" defaultValue="Homeschool High School Diploma" className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
              <label className="grid gap-1.5 text-sm font-semibold">Honors / distinction<input name="honors" placeholder="Optional" className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
            </div>
            <label className="grid gap-1.5 text-sm font-semibold">Diploma statement<textarea name="statement" rows={3} defaultValue="has satisfactorily completed the course of study prescribed by this homeschool and is hereby awarded this diploma." className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
            <div className="grid gap-4 md:grid-cols-2">
              <label className="grid gap-1.5 text-sm font-semibold">Graduation date<input name="graduation_date" type="date" defaultValue={student.graduation_date ?? today} required className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
              <label className="grid gap-1.5 text-sm font-semibold">Issue date<input name="issue_date" type="date" defaultValue={today} required className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
            </div>
            <div className="grid gap-4 md:grid-cols-2">
              <label className="grid gap-1.5 text-sm font-semibold">Signatory name<input name="signatory_name" placeholder="Parent / administrator name" required className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
              <label className="grid gap-1.5 text-sm font-semibold">Signatory title<input name="signatory_title" defaultValue="Homeschool Administrator" className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
            </div>
            <label className="flex items-start gap-3 rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-4 text-sm">
              <input name="mark_graduated" type="checkbox" defaultChecked className="mt-0.5 h-5 w-5 accent-[#23685a]" />
              <span><strong>Mark student as graduated.</strong><span className="mt-1 block text-[#617078]">This updates the student&apos;s current status and graduation date. The diploma itself remains permanent either way.</span></span>
            </label>
            <label className="flex items-start gap-3 rounded-2xl border border-amber-300 bg-[#fffaf1] p-4 text-sm">
              <input name="attestation" type="checkbox" required className="mt-0.5 h-5 w-5 accent-[#8a6728]" />
              <span><strong>I authorize issuance of this official homeschool diploma.</strong><span className="mt-1 block text-[#765f39]">I have reviewed this student&apos;s academic record and intentionally approve this diploma as the homeschool administrator.</span></span>
            </label>
            <button className="w-full rounded-xl bg-[#8a6728] px-5 py-3 font-bold text-white hover:bg-[#6f511d] sm:w-fit">Issue permanent diploma</button>
          </form>
        </section>

        <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
          <div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">Issued diplomas</div>
          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            {diplomaData?.length ? diplomaData.map((diploma) => (
              <Link key={diploma.id} href={`/dashboard/students/${studentId}/diplomas/${diploma.id}`} className="rounded-2xl border border-[#dfe7e3] bg-[#fbfcfb] p-4 hover:border-[#c9a96d]">
                <div className="flex items-start justify-between gap-3"><div><div className="font-bold">{diploma.diploma_number}</div><div className="mt-1 text-xs text-[#718087]">Graduated {diploma.graduation_date} · Issued {diploma.issue_date}</div></div><StatusPill tone={diploma.status === "official" ? "green" : "gray"}>{diploma.status}</StatusPill></div>
                <div className="mt-3 text-xs font-bold text-[#456f91]">Version {diploma.version} · View / Save PDF</div>
              </Link>
            )) : <div className="rounded-xl bg-[#f8faf8] p-4 text-sm text-[#617078] sm:col-span-2">No diploma has been issued for this student.</div>}
          </div>
        </section>
      </div>
    </AppShell>
  );
}
