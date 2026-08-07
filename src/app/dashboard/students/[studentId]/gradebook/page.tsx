import Link from "next/link";
import { notFound } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";
import { localDateInTimezone } from "@/lib/student-login";
import { assignAssessment, gradeAssignment } from "./actions";

type Enrollment = {
  id: string;
  course_version_id: string;
  status: string;
  start_date: string;
  course_versions: unknown;
};

type Template = {
  id: string;
  course_version_id: string;
  code: string;
  title: string;
  assignment_type: string;
  max_points: number | null;
  sequence: number | null;
};

type Assignment = {
  id: string;
  student_course_enrollment_id: string;
  assignment_template_id: string | null;
  title: string;
  assignment_type: string;
  max_points: number | null;
  assigned_date: string;
  due_date: string | null;
  status: string;
};

type Grade = {
  id: string;
  student_assignment_id: string;
  revision_number: number;
  points_earned: number | null;
  points_possible: number | null;
  percentage: number | null;
  letter_grade: string | null;
  teacher_feedback: string | null;
  graded_at: string;
};

type Competency = {
  id: string;
  course_version_id: string;
  code: string;
  title: string;
  sequence: number;
  mastery_threshold_percent: number | null;
  minimum_independent_demonstrations: number;
};

type Evidence = {
  id: string;
  competency_id: string;
  rating: string;
  score: number | null;
  recorded_at: string;
};

function firstRelation<T>(value: unknown): T | null {
  if (Array.isArray(value)) return (value[0] as T | undefined) ?? null;
  return (value as T | null) ?? null;
}

function progressFor(competency: Competency, evidence: Evidence[]) {
  const rows = evidence.filter((row) => row.competency_id === competency.id);
  if (!rows.length) return { label: "Not started", tone: "gray" as const };

  const threshold = competency.mastery_threshold_percent ?? 80;
  const qualifying = rows.filter((row) =>
    row.score !== null &&
    row.score >= threshold &&
    (row.rating === "proficient" || row.rating === "mastered")
  );

  if (qualifying.length >= competency.minimum_independent_demonstrations) {
    return { label: "Mastered", tone: "green" as const };
  }
  if (qualifying.length >= 1) {
    return { label: "Proficient", tone: "green" as const };
  }
  if (rows.some((row) => row.rating === "practicing")) {
    return { label: "Practicing", tone: "amber" as const };
  }
  return { label: "Needs review", tone: "amber" as const };
}

export default async function StudentGradebookPage({
  params,
  searchParams,
}: {
  params: Promise<{ studentId: string }>;
  searchParams: Promise<{ assigned?: string; graded?: string; error?: string }>;
}) {
  const { studentId } = await params;
  const query = await searchParams;
  const { supabase, organization } = await requireOrganization();
  const today = localDateInTimezone(organization.timezone);

  const [{ data: student }, { data: enrollmentData }] = await Promise.all([
    supabase
      .from("students")
      .select("id,student_number,first_name,last_name,preferred_name,status")
      .eq("organization_id", organization.id)
      .eq("id", studentId)
      .maybeSingle(),
    supabase
      .from("student_course_enrollments")
      .select("id,course_version_id,status,start_date,course_versions(title,course_code)")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .in("status", ["planned", "active"])
      .order("start_date"),
  ]);

  if (!student) notFound();

  const enrollments = (enrollmentData ?? []) as Enrollment[];
  const enrollmentIds = enrollments.map((row) => row.id);
  const courseVersionIds = [...new Set(enrollments.map((row) => row.course_version_id))];

  let templates: Template[] = [];
  let assignments: Assignment[] = [];
  let grades: Grade[] = [];
  let competencies: Competency[] = [];
  let evidence: Evidence[] = [];

  if (courseVersionIds.length) {
    const [templateResult, competencyResult] = await Promise.all([
      supabase
        .from("assignment_templates")
        .select("id,course_version_id,code,title,assignment_type,max_points,sequence")
        .eq("organization_id", organization.id)
        .in("course_version_id", courseVersionIds)
        .eq("active", true)
        .order("sequence"),
      supabase
        .from("competencies")
        .select("id,course_version_id,code,title,sequence,mastery_threshold_percent,minimum_independent_demonstrations")
        .eq("organization_id", organization.id)
        .in("course_version_id", courseVersionIds)
        .order("sequence"),
    ]);
    templates = (templateResult.data ?? []) as Template[];
    competencies = (competencyResult.data ?? []) as Competency[];
  }

  if (enrollmentIds.length) {
    const [{ data: assignmentData }, { data: evidenceData }] = await Promise.all([
      supabase
        .from("student_assignments")
        .select("id,student_course_enrollment_id,assignment_template_id,title,assignment_type,max_points,assigned_date,due_date,status")
        .eq("organization_id", organization.id)
        .eq("student_id", studentId)
        .in("student_course_enrollment_id", enrollmentIds)
        .order("assigned_date", { ascending: false }),
      supabase
        .from("competency_evidence")
        .select("id,competency_id,rating,score,recorded_at")
        .eq("organization_id", organization.id)
        .eq("student_id", studentId)
        .in("student_course_enrollment_id", enrollmentIds)
        .eq("is_current", true)
        .order("recorded_at", { ascending: false }),
    ]);
    assignments = (assignmentData ?? []) as Assignment[];
    evidence = (evidenceData ?? []) as Evidence[];
  }

  const assignmentIds = assignments.map((row) => row.id);
  if (assignmentIds.length) {
    const { data } = await supabase
      .from("grade_records")
      .select("id,student_assignment_id,revision_number,points_earned,points_possible,percentage,letter_grade,teacher_feedback,graded_at")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .eq("status", "current")
      .in("student_assignment_id", assignmentIds);
    grades = (data ?? []) as Grade[];
  }

  const gradeByAssignment = new Map(grades.map((grade) => [grade.student_assignment_id, grade]));
  const enrollmentById = new Map(enrollments.map((enrollment) => [enrollment.id, enrollment]));

  return (
    <AppShell organizationName={organization.name}>
      <div className="grid gap-6">
        <div>
          <Link href={`/dashboard/students/${studentId}`} className="text-sm font-semibold text-[#315c4d] hover:underline">
            ← Back to student
          </Link>
        </div>

        <section>
          <p className="text-sm font-medium text-[#667085]">Gradebook</p>
          <h1 className="mt-1 text-3xl font-bold">{student.preferred_name || student.first_name} {student.last_name}</h1>
          <p className="mt-2 text-[#667085]">{student.student_number} · Assign curriculum assessments, record grades, and review competency evidence.</p>
        </section>

        {query.assigned && (
          <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800">
            Assessment assigned successfully.
          </div>
        )}
        {query.graded && (
          <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800">
            Grade saved and competency evidence updated.
          </div>
        )}
        {query.error && (
          <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{query.error}</div>
        )}

        <section className="grid gap-4">
          <div>
            <h2 className="text-xl font-bold">Assign an assessment</h2>
            <p className="mt-1 text-sm text-[#667085]">These assessments come directly from the student&apos;s versioned curriculum.</p>
          </div>

          {enrollments.length ? enrollments.map((enrollment) => {
            const course = firstRelation<{ title: string; course_code: string }>(enrollment.course_versions);
            const courseTemplates = templates.filter((template) => template.course_version_id === enrollment.course_version_id);
            const alreadyAssignedTemplateIds = new Set(
              assignments
                .filter((assignment) => assignment.student_course_enrollment_id === enrollment.id && assignment.assignment_template_id)
                .map((assignment) => assignment.assignment_template_id as string)
            );
            const availableTemplates = courseTemplates.filter((template) => !alreadyAssignedTemplateIds.has(template.id));

            return (
              <form action={assignAssessment} key={enrollment.id} className="rounded-2xl border border-[#e4e7ec] bg-white p-5">
                <input type="hidden" name="student_id" value={studentId} />
                <input type="hidden" name="enrollment_id" value={enrollment.id} />

                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <div className="text-sm font-semibold text-[#315c4d]">{course?.course_code ?? "COURSE"}</div>
                    <div className="mt-1 text-lg font-bold">{course?.title ?? "Assigned course"}</div>
                  </div>
                  <StatusPill>{enrollment.status}</StatusPill>
                </div>

                {availableTemplates.length ? (
                  <div className="mt-5 grid gap-4 lg:grid-cols-[1fr_170px_170px_auto] lg:items-end">
                    <label className="grid gap-1.5 text-sm font-medium">
                      Curriculum assessment
                      <select name="template_id" required className="rounded-xl border border-[#d0d5dd] bg-white px-3.5 py-3">
                        {availableTemplates.map((template) => (
                          <option key={template.id} value={template.id}>
                            {template.code} · {template.title} · {template.max_points ?? 0} pts
                          </option>
                        ))}
                      </select>
                    </label>

                    <label className="grid gap-1.5 text-sm font-medium">
                      Assigned date
                      <input name="assigned_date" type="date" defaultValue={today} required className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" />
                    </label>

                    <label className="grid gap-1.5 text-sm font-medium">
                      Due date
                      <input name="due_date" type="date" defaultValue={today} className="rounded-xl border border-[#d0d5dd] px-3.5 py-3" />
                    </label>

                    <button className="rounded-xl bg-[#315c4d] px-5 py-3 font-semibold text-white hover:bg-[#24483c]">
                      Assign
                    </button>
                  </div>
                ) : (
                  <div className="mt-4 rounded-xl bg-[#f8faf9] p-4 text-sm text-[#667085]">
                    All curriculum assessments for this course are already assigned.
                  </div>
                )}
              </form>
            );
          }) : (
            <div className="rounded-2xl border border-[#e4e7ec] bg-white p-6 text-sm text-[#667085]">No active courses are available.</div>
          )}
        </section>

        <section className="grid gap-4">
          <div>
            <h2 className="text-xl font-bold">Assignments & grades</h2>
            <p className="mt-1 text-sm text-[#667085]">A changed grade creates a new revision; the prior grade remains in permanent history.</p>
          </div>

          {assignments.length ? assignments.map((assignment) => {
            const grade = gradeByAssignment.get(assignment.id);
            const enrollment = enrollmentById.get(assignment.student_course_enrollment_id);
            const course = firstRelation<{ title: string; course_code: string }>(enrollment?.course_versions);

            return (
              <article key={assignment.id} className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <div className="text-xs font-semibold uppercase tracking-wide text-[#315c4d]">
                      {course?.course_code ?? "COURSE"} · {assignment.assignment_type}
                    </div>
                    <h3 className="mt-1 text-lg font-bold">{assignment.title}</h3>
                    <div className="mt-1 text-sm text-[#667085]">
                      Assigned {assignment.assigned_date}
                      {assignment.due_date ? ` · Due ${assignment.due_date}` : ""}
                      {assignment.max_points !== null ? ` · ${assignment.max_points} points` : ""}
                    </div>
                  </div>

                  {grade ? (
                    <div className="text-right">
                      <div className="text-2xl font-bold">{grade.percentage?.toFixed(1)}%</div>
                      <div className="text-sm text-[#667085]">
                        {grade.points_earned}/{grade.points_possible} · {grade.letter_grade}
                      </div>
                    </div>
                  ) : (
                    <StatusPill tone="amber">Needs grade</StatusPill>
                  )}
                </div>

                {grade?.teacher_feedback && (
                  <div className="mt-4 rounded-xl bg-[#f8faf9] p-4 text-sm leading-6">
                    <span className="font-semibold">Teacher feedback:</span> {grade.teacher_feedback}
                  </div>
                )}

                <form action={gradeAssignment} className="mt-5 grid gap-4 border-t border-[#eaecf0] pt-5">
                  <input type="hidden" name="student_id" value={studentId} />
                  <input type="hidden" name="assignment_id" value={assignment.id} />

                  <div className="grid gap-4 md:grid-cols-[180px_1fr]">
                    <label className="grid gap-1.5 text-sm font-medium">
                      Points earned
                      <div className="flex items-center gap-2">
                        <input
                          name="points_earned"
                          type="number"
                          min={0}
                          max={assignment.max_points ?? undefined}
                          step="0.01"
                          defaultValue={grade?.points_earned ?? ""}
                          required
                          className="min-w-0 flex-1 rounded-xl border border-[#d0d5dd] px-3.5 py-3"
                        />
                        <span className="text-sm text-[#667085]">/ {assignment.max_points ?? "?"}</span>
                      </div>
                    </label>

                    <label className="grid gap-1.5 text-sm font-medium">
                      Teacher feedback
                      <input
                        name="teacher_feedback"
                        defaultValue={grade?.teacher_feedback ?? ""}
                        placeholder="Good work. Continue practicing..."
                        className="rounded-xl border border-[#d0d5dd] px-3.5 py-3"
                      />
                    </label>
                  </div>

                  {grade && (
                    <label className="grid gap-1.5 text-sm font-medium">
                      Reason for grade correction
                      <input
                        name="change_reason"
                        required
                        placeholder="Example: Corrected scoring error on question 4"
                        className="rounded-xl border border-[#d0d5dd] px-3.5 py-3"
                      />
                      <span className="text-xs font-normal text-[#667085]">
                        Required because revision {grade.revision_number + 1} will preserve revision {grade.revision_number} in history.
                      </span>
                    </label>
                  )}

                  <button className="w-fit rounded-xl bg-[#315c4d] px-5 py-3 font-semibold text-white hover:bg-[#24483c]">
                    {grade ? "Save corrected grade" : "Save grade"}
                  </button>
                </form>
              </article>
            );
          }) : (
            <div className="rounded-2xl border border-[#e4e7ec] bg-white p-6 text-sm text-[#667085]">
              No assessments have been assigned yet.
            </div>
          )}
        </section>

        <section className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
          <div className="flex flex-wrap items-end justify-between gap-3">
            <div>
              <h2 className="text-xl font-bold">Competency progress</h2>
              <p className="mt-1 text-sm text-[#667085]">
                A competency becomes Mastered only after it meets its required number of qualifying demonstrations.
              </p>
            </div>
            <div className="text-xs text-[#667085]">{competencies.length} competencies in active courses</div>
          </div>

          <div className="mt-5 grid gap-2">
            {competencies.map((competency) => {
              const status = progressFor(competency, evidence);
              const rows = evidence.filter((row) => row.competency_id === competency.id);
              const threshold = competency.mastery_threshold_percent ?? 80;
              const qualifying = rows.filter((row) => row.score !== null && row.score >= threshold).length;

              return (
                <div key={competency.id} className="grid gap-2 rounded-xl border border-[#eaecf0] p-4 md:grid-cols-[130px_1fr_auto] md:items-center">
                  <div className="font-mono text-sm font-semibold">{competency.code}</div>
                  <div>
                    <div className="font-medium">{competency.title}</div>
                    <div className="mt-1 text-xs text-[#667085]">
                      {qualifying}/{competency.minimum_independent_demonstrations} qualifying demonstrations · threshold {threshold}%
                    </div>
                  </div>
                  <StatusPill tone={status.tone}>{status.label}</StatusPill>
                </div>
              );
            })}
          </div>
        </section>
      </div>
    </AppShell>
  );
}
