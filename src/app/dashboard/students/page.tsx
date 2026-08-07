import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";

type Placement = {
  student_id: string;
  status: string;
  grade_levels: unknown;
  academic_years: unknown;
};

type CourseEnrollment = {
  student_id: string;
  status: string;
  course_versions: unknown;
};

function firstRelation<T>(value: unknown): T | null {
  if (Array.isArray(value)) return (value[0] as T | undefined) ?? null;
  return (value as T | null) ?? null;
}

export default async function StudentsPage({
  searchParams,
}: {
  searchParams: Promise<{ created?: string; error?: string }>;
}) {
  const params = await searchParams;
  const { supabase, organization } = await requireOrganization();

  const { data: students } = await supabase
    .from("students")
    .select("id,student_number,first_name,last_name,preferred_name,status,enrollment_date")
    .eq("organization_id", organization.id)
    .order("last_name");

  const studentIds = students?.map((student) => student.id) ?? [];
  let placements: Placement[] = [];
  let courseEnrollments: CourseEnrollment[] = [];

  if (studentIds.length) {
    const [placementResult, courseResult] = await Promise.all([
      supabase
        .from("student_academic_years")
        .select("student_id,status,grade_levels(name,code),academic_years(name,status)")
        .eq("organization_id", organization.id)
        .in("student_id", studentIds)
        .eq("status", "active"),
      supabase
        .from("student_course_enrollments")
        .select("student_id,status,course_versions(title,course_code)")
        .eq("organization_id", organization.id)
        .in("student_id", studentIds)
        .eq("status", "active"),
    ]);

    placements = (placementResult.data ?? []) as Placement[];
    courseEnrollments = (courseResult.data ?? []) as CourseEnrollment[];
  }

  const placementByStudent = new Map(placements.map((placement) => [placement.student_id, placement]));
  const coursesByStudent = new Map<string, string[]>();

  for (const enrollment of courseEnrollments) {
    const course = firstRelation<{ title: string; course_code: string }>(enrollment.course_versions);
    if (!course) continue;
    const existing = coursesByStudent.get(enrollment.student_id) ?? [];
    existing.push(course.title);
    coursesByStudent.set(enrollment.student_id, existing);
  }

  return (
    <AppShell organizationName={organization.name}>
      <section className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div>
            <p className="text-sm font-medium text-[#667085]">Instructor</p>
            <h1 className="text-3xl font-bold">Students</h1>
          </div>
          <Link href="/dashboard/students/new" className="rounded-xl bg-[#315c4d] px-4 py-2.5 text-sm font-semibold text-white hover:bg-[#24483c]">
            + Add student
          </Link>
        </div>

        {params.created && (
          <div className="mt-5 rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800">
            Student created successfully. Permanent student number: <strong>{params.created}</strong>
          </div>
        )}

        {params.error && <div className="mt-5 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{params.error}</div>}

        <div className="mt-6 overflow-hidden rounded-xl border border-[#e4e7ec]">
          {students?.length ? (
            students.map((student) => {
              const placement = placementByStudent.get(student.id);
              const grade = firstRelation<{ name: string; code: string }>(placement?.grade_levels);
              const academicYear = firstRelation<{ name: string; status: string }>(placement?.academic_years);
              const courseTitles = coursesByStudent.get(student.id) ?? [];

              return (
                <div key={student.id} className="flex flex-wrap items-center justify-between gap-4 border-b border-[#eaecf0] px-4 py-4 last:border-b-0">
                  <div>
                    <div className="font-semibold">
                      {student.preferred_name || student.first_name} {student.last_name}
                    </div>
                    <div className="mt-1 text-xs text-[#667085]">
                      {student.student_number} · Enrolled {student.enrollment_date}
                    </div>
                    <div className="mt-2 text-sm text-[#475467]">
                      {grade?.name ?? "Grade placement pending"}
                      {academicYear?.name ? ` · ${academicYear.name}` : ""}
                    </div>
                    <div className="mt-1 text-xs text-[#667085]">
                      {courseTitles.length ? `Active courses: ${courseTitles.join(", ")}` : "No active course assignments yet"}
                    </div>
                  </div>
                  <StatusPill>{student.status}</StatusPill>
                </div>
              );
            })
          ) : (
            <div className="p-8 text-center">
              <div className="font-semibold">No students yet</div>
              <p className="mt-2 text-sm text-[#667085]">Create the first student to begin tracking official grade placement and course work.</p>
              <Link href="/dashboard/students/new" className="mt-4 inline-block rounded-xl bg-[#315c4d] px-4 py-2.5 text-sm font-semibold text-white hover:bg-[#24483c]">
                + Add first student
              </Link>
            </div>
          )}
        </div>
      </section>
    </AppShell>
  );
}
