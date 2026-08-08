import Link from "next/link";
import { notFound } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";
import { localDateInTimezone } from "@/lib/student-login";
import { completeCourse, recordProgression } from "./actions";

type Readiness = {
  enrollment_id: string;
  enrollment_status: string;
  start_date: string;
  course_code: string;
  course_title: string;
  lessons_total: number;
  lessons_completed: number;
  competencies_total: number;
  competencies_mastered: number;
  current_grade_percent: number | null;
  current_letter_grade: string | null;
  instructional_minutes: number;
  ready_to_complete: boolean;
};

type GradeRelation = { id: string; code: string; name: string; numeric_order: number };
type CourseVersion = {
  id: string;
  title: string;
  course_code: string;
  subject_id: string;
  grade_level_id: string | null;
  status: string;
  grade_levels: unknown;
  curriculum_releases: unknown;
};
type Placement = {
  id: string;
  status: string;
  start_date: string;
  end_date: string | null;
  academic_years: unknown;
  grade_levels: unknown;
};

function firstRelation<T>(value: unknown): T | null {
  if (Array.isArray(value)) return (value[0] as T | undefined) ?? null;
  return (value as T | null) ?? null;
}

function decisionLabel(value: string) {
  return {
    advance: "Advance to next course",
    accelerate: "Accelerate to a higher course",
    repeat: "Repeat this course",
    continue: "Continue this course",
    complete: "End subject enrollment here",
  }[value] ?? value;
}

export default async function CourseCompletionPage({
  params,
  searchParams,
}: {
  params: Promise<{ studentId: string; enrollmentId: string }>;
  searchParams: Promise<{ completed?: string; progressed?: string; error?: string }>;
}) {
  const { studentId, enrollmentId } = await params;
  const query = await searchParams;
  const { supabase, organization } = await requireOrganization();
  const today = localDateInTimezone(organization.timezone);

  const [
    { data: student },
    { data: readinessData, error: readinessError },
    { data: enrollment },
    { data: completion },
    { data: progression },
    { data: placementData },
  ] = await Promise.all([
    supabase.from("students").select("id,student_number,first_name,last_name,preferred_name").eq("organization_id", organization.id).eq("id", studentId).maybeSingle(),
    supabase.rpc("get_course_completion_readiness", { p_student_course_enrollment_id: enrollmentId }),
    supabase.from("student_course_enrollments")
      .select("id,student_id,student_academic_year_id,course_version_id,status,start_date,end_date,attempt_number,course_versions(id,title,course_code,subject_id,grade_level_id,status,grade_levels(id,code,name,numeric_order),curriculum_releases(version))")
      .eq("organization_id", organization.id).eq("student_id", studentId).eq("id", enrollmentId).maybeSingle(),
    supabase.from("course_completion_records")
      .select("id,completion_status,final_percentage,final_letter_grade,competencies_total,competencies_mastered,instructional_minutes,teacher_summary,completed_at,completion_snapshot,override_reason")
      .eq("organization_id", organization.id).eq("student_id", studentId).eq("student_course_enrollment_id", enrollmentId).maybeSingle(),
    supabase.from("progression_decisions")
      .select("id,decision,target_course_version_id,target_enrollment_id,reason,decided_at")
      .eq("organization_id", organization.id).eq("student_id", studentId).eq("source_enrollment_id", enrollmentId).maybeSingle(),
    supabase.from("student_academic_years")
      .select("id,status,start_date,end_date,academic_years(id,name,start_date,end_date,status),grade_levels(id,code,name)")
      .eq("organization_id", organization.id).eq("student_id", studentId).in("status", ["planned", "active"]).order("start_date"),
  ]);

  if (!student || !enrollment || readinessError || !readinessData?.length) notFound();

  const readiness = readinessData[0] as Readiness;
  const sourceCourse = firstRelation<CourseVersion>(enrollment.course_versions);
  if (!sourceCourse) notFound();

  const sourceGrade = firstRelation<GradeRelation>(sourceCourse.grade_levels);

  const { data: targetCourseData } = await supabase
    .from("course_versions")
    .select("id,title,course_code,subject_id,grade_level_id,status,grade_levels(id,code,name,numeric_order),curriculum_releases(version)")
    .eq("organization_id", organization.id)
    .eq("subject_id", sourceCourse.subject_id)
    .neq("status", "retired");

  const targetCourses = ((targetCourseData ?? []) as CourseVersion[])
    .filter((course) => {
      if (course.id === sourceCourse.id) return false;
      const grade = firstRelation<GradeRelation>(course.grade_levels);
      return sourceGrade && grade && grade.numeric_order > sourceGrade.numeric_order;
    })
    .sort((a, b) => (firstRelation<GradeRelation>(a.grade_levels)?.numeric_order ?? 999) - (firstRelation<GradeRelation>(b.grade_levels)?.numeric_order ?? 999));

  const nextGradeOrder = sourceGrade ? sourceGrade.numeric_order + 1 : null;
  const nextCourses = targetCourses.filter((course) => firstRelation<GradeRelation>(course.grade_levels)?.numeric_order === nextGradeOrder);
  const higherCourses = targetCourses.filter((course) => nextGradeOrder !== null && (firstRelation<GradeRelation>(course.grade_levels)?.numeric_order ?? 0) > nextGradeOrder);
  const placements = (placementData ?? []) as Placement[];
  const studentName = student.preferred_name || student.first_name;

  return (
    <AppShell organizationName={organization.name}>
      <div className="grid gap-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <Link href={`/dashboard/students/${studentId}`} className="text-sm font-bold text-[#23685a] hover:underline">← Back to student</Link>
          <Link href={`/dashboard/students/${studentId}/progress`} className="text-sm font-bold text-[#456f91] hover:underline">View progress</Link>
        </div>

        {query.completed && <div className="rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm font-semibold text-emerald-800">Course completion record created successfully.</div>}
        {query.progressed && <div className="rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm font-semibold text-emerald-800">Subject progression decision recorded successfully.</div>}
        {query.error && <div className="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{query.error}</div>}

        <section className="overflow-hidden rounded-[26px] border border-[#d7e2dd] bg-white shadow-[0_20px_55px_rgba(32,66,55,0.08)]">
          <div className="bg-gradient-to-br from-[#eef7f3] via-white to-[#eef4f8] p-5 sm:p-7">
            <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-start">
              <div>
                <div className="text-xs font-bold uppercase tracking-[0.18em] text-[#23685a]">Course completion</div>
                <h1 className="mt-2 text-2xl font-bold sm:text-3xl">{readiness.course_title}</h1>
                <p className="mt-2 text-sm text-[#617078]">{studentName} {student.last_name} · {student.student_number} · {readiness.course_code}</p>
              </div>
              <StatusPill tone={readiness.enrollment_status === "completed" || readiness.ready_to_complete ? "green" : "amber"}>
                {readiness.enrollment_status === "completed" ? "Completed" : readiness.ready_to_complete ? "Ready to complete" : "In progress"}
              </StatusPill>
            </div>
          </div>

          <div className="grid gap-3 p-5 sm:grid-cols-2 sm:p-7 lg:grid-cols-4">
            <div className="rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-4"><div className="text-xs font-semibold text-[#718087]">Lessons</div><div className="mt-1 text-2xl font-bold">{readiness.lessons_completed}/{readiness.lessons_total}</div><div className="mt-1 text-xs text-[#617078]">completed</div></div>
            <div className="rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-4"><div className="text-xs font-semibold text-[#718087]">Competencies</div><div className="mt-1 text-2xl font-bold">{readiness.competencies_mastered}/{readiness.competencies_total}</div><div className="mt-1 text-xs text-[#617078]">mastered</div></div>
            <div className="rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-4"><div className="text-xs font-semibold text-[#718087]">Current grade</div><div className="mt-1 text-2xl font-bold">{readiness.current_grade_percent !== null ? `${Number(readiness.current_grade_percent).toFixed(1)}%` : "—"}</div><div className="mt-1 text-xs text-[#617078]">{readiness.current_letter_grade ?? "No grade yet"}</div></div>
            <div className="rounded-2xl border border-[#dfe7e3] bg-[#f8faf8] p-4"><div className="text-xs font-semibold text-[#718087]">Instructional time</div><div className="mt-1 text-2xl font-bold">{readiness.instructional_minutes}</div><div className="mt-1 text-xs text-[#617078]">minutes recorded</div></div>
          </div>
        </section>

        {!completion ? (
          <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h2 className="text-xl font-bold">Complete this course</h2>
                <p className="mt-1 max-w-3xl text-sm leading-6 text-[#617078]">Completion freezes the final grade, competency count, instructional time, curriculum version, and completion date into the permanent academic record.</p>
              </div>
              <StatusPill tone={readiness.ready_to_complete ? "green" : "amber"}>{readiness.ready_to_complete ? "Requirements met" : "Requirements incomplete"}</StatusPill>
            </div>

            {!readiness.ready_to_complete && <div className="mt-4 rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm leading-6 text-amber-900">This course is not ready for normal completion yet. An instructor override is possible, but the permanent record will preserve that the override was used and why.</div>}

            <form action={completeCourse} className="mt-5 grid gap-4">
              <input type="hidden" name="student_id" value={studentId} />
              <input type="hidden" name="enrollment_id" value={enrollmentId} />
              <div className="grid gap-4 md:grid-cols-[200px_minmax(0,1fr)]">
                <label className="grid gap-1.5 text-sm font-semibold">Completion date<input name="completion_date" type="date" defaultValue={today} min={readiness.start_date} required className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
                <label className="grid gap-1.5 text-sm font-semibold">Teacher summary<input name="teacher_summary" placeholder="Final course summary (optional)" className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
              </div>

              {!readiness.ready_to_complete && <label className="grid gap-1.5 text-sm font-semibold">Instructor override reason<textarea name="override_reason" rows={3} required placeholder="Explain why the course is being completed before all configured requirements are met." className="rounded-xl border border-amber-300 bg-[#fffaf2] px-3.5 py-3" /></label>}

              <button className="w-full rounded-xl bg-[#23685a] px-5 py-3 font-bold text-white hover:bg-[#174d43] sm:w-fit">Create permanent completion record</button>
            </form>
          </section>
        ) : (
          <section className="rounded-2xl border border-emerald-200 bg-[#f3fbf7] p-5 sm:p-6">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div><div className="text-xs font-bold uppercase tracking-[0.16em] text-[#23685a]">Permanent completion record</div><h2 className="mt-1 text-xl font-bold">Course completed</h2></div>
              <StatusPill tone="green">{completion.completion_status}</StatusPill>
            </div>
            <div className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <div><div className="text-xs font-semibold text-[#718087]">Final grade</div><div className="mt-1 font-bold">{completion.final_percentage !== null ? `${Number(completion.final_percentage).toFixed(1)}% ${completion.final_letter_grade ?? ""}` : "No percentage grade"}</div></div>
              <div><div className="text-xs font-semibold text-[#718087]">Competencies</div><div className="mt-1 font-bold">{completion.competencies_mastered}/{completion.competencies_total} mastered</div></div>
              <div><div className="text-xs font-semibold text-[#718087]">Instructional time</div><div className="mt-1 font-bold">{completion.instructional_minutes ?? 0} minutes</div></div>
              <div><div className="text-xs font-semibold text-[#718087]">Recorded</div><div className="mt-1 font-bold">{new Date(completion.completed_at).toLocaleDateString()}</div></div>
            </div>
            {completion.teacher_summary && <div className="mt-4 rounded-xl bg-white/70 p-4 text-sm leading-6 text-[#405158]"><span className="font-bold">Teacher summary:</span> {completion.teacher_summary}</div>}
            {completion.override_reason && <div className="mt-4 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm leading-6 text-amber-900"><span className="font-bold">Instructor override:</span> {completion.override_reason}</div>}
          </section>
        )}

        {completion && !progression && (
          <section className="rounded-2xl border border-[#dfe7e3] bg-white p-5 shadow-sm sm:p-6">
            <h2 className="text-xl font-bold">Choose what happens next</h2>
            <p className="mt-1 max-w-3xl text-sm leading-6 text-[#617078]">This is a subject-level decision. It does not promote or change the student&apos;s official grade placement.</p>

            <form action={recordProgression} className="mt-5 grid gap-4">
              <input type="hidden" name="student_id" value={studentId} />
              <input type="hidden" name="source_enrollment_id" value={enrollmentId} />
              <div className="grid gap-4 md:grid-cols-2">
                <label className="grid gap-1.5 text-sm font-semibold">Progression decision<select name="decision" defaultValue={nextCourses.length ? "advance" : "complete"} className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3">
                  {nextCourses.length > 0 && <option value="advance">Advance to next course</option>}
                  {higherCourses.length > 0 && <option value="accelerate">Accelerate / skip a level</option>}
                  <option value="continue">Continue same course in a new enrollment</option>
                  <option value="repeat">Repeat same course</option>
                  <option value="complete">End subject enrollment here</option>
                </select></label>

                <label className="grid gap-1.5 text-sm font-semibold">Next course<select name="target_course_version_id" defaultValue={nextCourses[0]?.id ?? higherCourses[0]?.id ?? ""} className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3">
                  <option value="">Not needed for repeat / continue / end</option>
                  {[...nextCourses, ...higherCourses].map((course) => {
                    const grade = firstRelation<GradeRelation>(course.grade_levels);
                    const release = firstRelation<{ version: string }>(course.curriculum_releases);
                    return <option key={course.id} value={course.id}>{course.course_code} · {course.title} · {grade?.name ?? "No grade"} · {release?.version ?? "version"}</option>;
                  })}
                </select></label>
              </div>

              <div className="grid gap-4 md:grid-cols-2">
                <label className="grid gap-1.5 text-sm font-semibold">Academic-year placement for next enrollment<select name="target_student_academic_year_id" defaultValue={enrollment.student_academic_year_id} className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3">
                  {placements.map((placement) => {
                    const year = firstRelation<{ name: string }>(placement.academic_years);
                    const grade = firstRelation<{ name: string }>(placement.grade_levels);
                    return <option key={placement.id} value={placement.id}>{year?.name ?? "Academic year"} · Official {grade?.name ?? "grade"}</option>;
                  })}
                </select></label>
                <label className="grid gap-1.5 text-sm font-semibold">Next course start date<input name="start_date" type="date" defaultValue={today} className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>
              </div>

              <label className="grid gap-1.5 text-sm font-semibold">Decision reason / note<textarea name="reason" rows={3} placeholder="Optional note explaining the progression decision." className="rounded-xl border border-[#cbd8d2] bg-white px-3.5 py-3" /></label>

              {!nextCourses.length && <div className="rounded-2xl border border-[#cfdde6] bg-[#eef5fa] p-4 text-sm leading-6 text-[#345f80]">No next-grade course version exists for this subject yet. Once that curriculum is added, it will automatically become available here as an advancement target.</div>}

              <button className="w-full rounded-xl bg-[#456f91] px-5 py-3 font-bold text-white hover:bg-[#345f80] sm:w-fit">Record permanent progression decision</button>
            </form>
          </section>
        )}

        {progression && (
          <section className="rounded-2xl border border-[#cfdde6] bg-[#f3f8fb] p-5 sm:p-6">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div><div className="text-xs font-bold uppercase tracking-[0.16em] text-[#456f91]">Subject progression</div><h2 className="mt-1 text-xl font-bold">{decisionLabel(progression.decision)}</h2></div>
              <StatusPill tone="blue">Recorded</StatusPill>
            </div>
            <p className="mt-3 text-sm leading-6 text-[#536a78]">This decision is permanent and separate from the student&apos;s official grade-level placement.</p>
            {progression.reason && <div className="mt-4 rounded-xl bg-white/70 p-4 text-sm text-[#405158]"><span className="font-bold">Reason:</span> {progression.reason}</div>}
            {progression.target_enrollment_id && <Link href={`/dashboard/students/${studentId}/courses/${progression.target_enrollment_id}`} className="mt-4 inline-flex rounded-xl bg-[#456f91] px-4 py-2.5 text-sm font-bold text-white hover:bg-[#345f80]">Open next course enrollment</Link>}
          </section>
        )}
      </div>
    </AppShell>
  );
}
