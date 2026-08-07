import Link from "next/link";
import { redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { requireOrganization } from "@/lib/auth";
import { createStudent } from "./actions";

export default async function NewStudentPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const { supabase, organization } = await requireOrganization();

  const [{ data: academicYears }, { data: gradeLevels }, { data: grade1Math }] = await Promise.all([
    supabase
      .from("academic_years")
      .select("id,name,start_date,end_date,status")
      .eq("organization_id", organization.id)
      .in("status", ["planned", "active"])
      .order("start_date", { ascending: false }),
    supabase.from("grade_levels").select("id,code,name,numeric_order").eq("active", true).order("numeric_order"),
    supabase
      .from("course_versions")
      .select("id,title,course_code,status")
      .eq("organization_id", organization.id)
      .eq("course_code", "1-MATH")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
  ]);

  if (!academicYears?.length) {
    redirect("/dashboard/students?error=Create%20an%20active%20academic%20year%20before%20adding%20students.");
  }

  const defaultYear = academicYears.find((year) => year.status === "active") ?? academicYears[0];
  const defaultGrade = gradeLevels?.find((grade) => grade.code === "1") ?? gradeLevels?.[0];

  return (
    <AppShell organizationName={organization.name}>
      <div className="mx-auto max-w-3xl">
        <div className="mb-5">
          <Link href="/dashboard/students" className="text-sm font-semibold text-[#315c4d] hover:underline">
            ← Back to students
          </Link>
        </div>

        <section className="rounded-2xl border border-[#e4e7ec] bg-white p-6 sm:p-8">
          <p className="text-sm font-medium text-[#667085]">Instructor</p>
          <h1 className="mt-1 text-3xl font-bold">Add student</h1>
          <p className="mt-2 max-w-2xl leading-7 text-[#667085]">
            This creates the student&apos;s permanent identity and their official placement for the selected academic year.
            Grade 1 Math can also be assigned now without tying the student&apos;s official grade to their Math level.
          </p>

          {params.error && (
            <div className="mt-6 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{params.error}</div>
          )}

          <form action={createStudent} className="mt-7 grid gap-5 sm:grid-cols-2">
            <label className="grid gap-1.5 text-sm font-medium">
              First name <span className="text-red-600">*</span>
              <input name="first_name" required autoComplete="given-name" className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" />
            </label>

            <label className="grid gap-1.5 text-sm font-medium">
              Last name <span className="text-red-600">*</span>
              <input name="last_name" required autoComplete="family-name" className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" />
            </label>

            <label className="grid gap-1.5 text-sm font-medium">
              Middle name
              <input name="middle_name" autoComplete="additional-name" className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" />
            </label>

            <label className="grid gap-1.5 text-sm font-medium">
              Preferred name
              <input name="preferred_name" className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" />
            </label>

            <label className="grid gap-1.5 text-sm font-medium">
              Date of birth
              <input name="date_of_birth" type="date" className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" />
            </label>

            <label className="grid gap-1.5 text-sm font-medium">
              Enrollment date <span className="text-red-600">*</span>
              <input
                name="enrollment_date"
                type="date"
                required
                defaultValue={defaultYear.start_date}
                className="rounded-xl border border-[#d0d5dd] px-3.5 py-3"
              />
            </label>

            <label className="grid gap-1.5 text-sm font-medium">
              Academic year <span className="text-red-600">*</span>
              <select
                name="academic_year_id"
                required
                defaultValue={defaultYear.id}
                className="rounded-xl border border-[#d0d5dd] bg-white px-3.5 py-3"
              >
                {academicYears.map((year) => (
                  <option key={year.id} value={year.id}>
                    {year.name} {year.status === "active" ? "(Active)" : ""}
                  </option>
                ))}
              </select>
            </label>

            <label className="grid gap-1.5 text-sm font-medium">
              Official grade level <span className="text-red-600">*</span>
              <select
                name="official_grade_level_id"
                required
                defaultValue={defaultGrade?.id ?? ""}
                className="rounded-xl border border-[#d0d5dd] bg-white px-3.5 py-3"
              >
                <option value="" disabled>
                  Select grade level
                </option>
                {gradeLevels?.map((grade) => (
                  <option key={grade.id} value={grade.id}>
                    {grade.name}
                  </option>
                ))}
              </select>
            </label>

            <div className="sm:col-span-2 rounded-2xl border border-[#dfe8e3] bg-[#f5faf7] p-5">
              <label className="flex items-start gap-3">
                <input
                  name="assign_grade1_math"
                  type="checkbox"
                  defaultChecked={Boolean(grade1Math)}
                  disabled={!grade1Math}
                  className="mt-1 h-4 w-4"
                />
                <span>
                  <span className="block font-semibold">Assign Grade 1 Mathematics — 2026.1</span>
                  <span className="mt-1 block text-sm leading-6 text-[#667085]">
                    {grade1Math
                      ? "Creates an active Math course enrollment at the same time as the student record. You can leave this unchecked if the student should not start Grade 1 Math yet."
                      : "Grade 1 Mathematics is not currently installed for this homeschool."}
                  </span>
                </span>
              </label>
            </div>

            <div className="flex flex-wrap gap-3 sm:col-span-2">
              <button className="rounded-xl bg-[#315c4d] px-5 py-3 font-semibold text-white hover:bg-[#24483c]">Create student</button>
              <Link href="/dashboard/students" className="rounded-xl border border-[#d0d5dd] bg-white px-5 py-3 font-semibold hover:bg-slate-50">
                Cancel
              </Link>
            </div>
          </form>
        </section>
      </div>
    </AppShell>
  );
}
