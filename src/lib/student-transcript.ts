import type { createClient } from "@/lib/supabase/server";

type AppSupabase = Awaited<ReturnType<typeof createClient>>;

type OrganizationInput = {
  id: string;
  name: string;
  timezone: string;
};

type PlacementRow = {
  id: string;
  academic_year_id: string;
  official_grade_level_id: string;
  status: string;
  start_date: string;
  end_date: string | null;
  academic_years: unknown;
  grade_levels: unknown;
};

type EnrollmentRow = {
  id: string;
  student_academic_year_id: string;
  course_version_id: string;
  status: string;
  attempt_number: number;
  start_date: string;
  end_date: string | null;
  course_versions: unknown;
};

type CompletionRow = {
  id: string;
  student_course_enrollment_id: string;
  completion_status: string;
  final_percentage: number | string | null;
  final_letter_grade: string | null;
  credits_attempted: number | string | null;
  credits_earned: number | string | null;
  competencies_total: number | null;
  competencies_mastered: number | null;
  instructional_minutes: number | null;
  teacher_summary: string | null;
  completed_at: string;
  completion_snapshot: Record<string, unknown> | null;
};

type AttendanceRow = {
  student_academic_year_id: string;
  attendance_date: string;
  status: string;
  instructional_minutes: number | null;
};

type AssignmentRow = {
  id: string;
  student_course_enrollment_id: string;
  weight: number | string | null;
  status: string;
};

type GradeRow = {
  student_assignment_id: string;
  percentage: number | string | null;
};

export type TranscriptCourse = {
  completion_record_id: string | null;
  enrollment_id: string;
  course_version_id: string;
  course_code: string;
  title: string;
  subject_name: string | null;
  course_grade_level: string | null;
  curriculum_release: string | null;
  attempt_number: number;
  start_date: string;
  completion_date: string | null;
  final_percentage: number | null;
  final_letter_grade: string | null;
  credits_attempted: number | null;
  credits_earned: number | null;
  instructional_minutes: number | null;
  competencies_mastered: number | null;
  competencies_total: number | null;
  status: string;
};

export type TranscriptAcademicYear = {
  placement_id: string;
  academic_year_id: string;
  academic_year_name: string;
  official_grade_code: string;
  official_grade_name: string;
  placement_status: string;
  start_date: string;
  end_date: string;
  attendance: {
    present_days: number;
    partial_days: number;
    absent_days: number;
    excused_days: number;
    instructional_days: number;
    instructional_minutes: number;
  };
  completed_courses: TranscriptCourse[];
  current_courses: TranscriptCourse[];
};

export type StudentTranscriptSnapshot = {
  schema_version: 1;
  generated_at: string;
  record_as_of: string;
  organization: {
    id: string;
    name: string;
    timezone: string;
  };
  student: {
    id: string;
    student_number: string;
    first_name: string;
    middle_name: string | null;
    last_name: string;
    preferred_name: string | null;
    date_of_birth: string | null;
    enrollment_date: string;
    graduation_date: string | null;
    status: string;
  };
  academic_years: TranscriptAcademicYear[];
  cumulative: {
    completed_courses: number;
    active_courses: number;
    instructional_days: number;
    instructional_minutes: number;
    credits_attempted: number;
    credits_earned: number;
  };
};

function firstRelation<T>(value: unknown): T | null {
  if (Array.isArray(value)) return (value[0] as T | undefined) ?? null;
  return (value as T | null) ?? null;
}

function numeric(value: number | string | null | undefined) {
  if (value === null || value === undefined || value === "") return null;
  const result = Number(value);
  return Number.isFinite(result) ? result : null;
}

function round1(value: number) {
  return Math.round(value * 10) / 10;
}

function letterGrade(percentage: number | null) {
  if (percentage === null) return null;
  if (percentage >= 90) return "A";
  if (percentage >= 80) return "B";
  if (percentage >= 70) return "C";
  if (percentage >= 60) return "D";
  return "F";
}

export async function buildStudentTranscriptSnapshot({
  supabase,
  organization,
  studentId,
  recordAsOf,
}: {
  supabase: AppSupabase;
  organization: OrganizationInput;
  studentId: string;
  recordAsOf: string;
}): Promise<StudentTranscriptSnapshot> {
  const [
    { data: student },
    { data: placementData },
    { data: enrollmentData },
    { data: completionData },
    { data: attendanceData },
  ] = await Promise.all([
    supabase
      .from("students")
      .select("id,student_number,first_name,middle_name,last_name,preferred_name,date_of_birth,enrollment_date,graduation_date,status")
      .eq("organization_id", organization.id)
      .eq("id", studentId)
      .maybeSingle(),
    supabase
      .from("student_academic_years")
      .select("id,academic_year_id,official_grade_level_id,status,start_date,end_date,academic_years(id,name,start_date,end_date,status),grade_levels(id,code,name,numeric_order)")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .lte("start_date", recordAsOf)
      .order("start_date"),
    supabase
      .from("student_course_enrollments")
      .select("id,student_academic_year_id,course_version_id,status,attempt_number,start_date,end_date,course_versions(id,title,course_code,subject_id,grade_level_id,credit_value,grade_levels(id,code,name),subjects(id,code,name),curriculum_releases(version))")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .lte("start_date", recordAsOf)
      .neq("status", "superseded")
      .order("start_date"),
    supabase
      .from("course_completion_records")
      .select("id,student_course_enrollment_id,completion_status,final_percentage,final_letter_grade,credits_attempted,credits_earned,competencies_total,competencies_mastered,instructional_minutes,teacher_summary,completed_at,completion_snapshot")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .lte("completed_at", `${recordAsOf}T23:59:59.999Z`)
      .order("completed_at"),
    supabase
      .from("attendance_records")
      .select("student_academic_year_id,attendance_date,status,instructional_minutes")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .eq("teacher_confirmed", true)
      .lte("attendance_date", recordAsOf)
      .order("attendance_date"),
  ]);

  if (!student) throw new Error("Student record was not found.");

  const placements = (placementData ?? []) as PlacementRow[];
  const enrollments = (enrollmentData ?? []) as EnrollmentRow[];
  const completions = (completionData ?? []) as CompletionRow[];
  const attendance = (attendanceData ?? []) as AttendanceRow[];

  const activeEnrollmentIds = enrollments
    .filter((row) => row.status === "active" || row.status === "planned")
    .map((row) => row.id);

  let assignments: AssignmentRow[] = [];
  let grades: GradeRow[] = [];

  if (activeEnrollmentIds.length) {
    const { data: assignmentData } = await supabase
      .from("student_assignments")
      .select("id,student_course_enrollment_id,weight,status")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .in("student_course_enrollment_id", activeEnrollmentIds)
      .neq("status", "cancelled");

    assignments = (assignmentData ?? []) as AssignmentRow[];
    const assignmentIds = assignments.map((row) => row.id);

    if (assignmentIds.length) {
      const { data: gradeData } = await supabase
        .from("grade_records")
        .select("student_assignment_id,percentage")
        .eq("organization_id", organization.id)
        .eq("student_id", studentId)
        .eq("status", "current")
        .in("student_assignment_id", assignmentIds);

      grades = (gradeData ?? []) as GradeRow[];
    }
  }

  const completionByEnrollment = new Map(
    completions.map((row) => [row.student_course_enrollment_id, row])
  );
  const gradeByAssignment = new Map(
    grades.map((row) => [row.student_assignment_id, row])
  );

  function liveGradeFor(enrollmentId: string) {
    const rows = assignments.filter(
      (assignment) => assignment.student_course_enrollment_id === enrollmentId
    );

    let total = 0;
    let totalWeight = 0;

    for (const assignment of rows) {
      const percentage = numeric(gradeByAssignment.get(assignment.id)?.percentage);
      if (percentage === null) continue;
      const rawWeight = numeric(assignment.weight);
      const weight = rawWeight !== null && rawWeight > 0 ? rawWeight : 1;
      total += percentage * weight;
      totalWeight += weight;
    }

    return totalWeight > 0 ? round1(total / totalWeight) : null;
  }

  function courseFromEnrollment(
    enrollment: EnrollmentRow,
    completion: CompletionRow | null
  ): TranscriptCourse {
    const course = firstRelation<{
      id: string;
      title: string;
      course_code: string;
      credit_value: number | string | null;
      grade_levels: unknown;
      subjects: unknown;
      curriculum_releases: unknown;
    }>(enrollment.course_versions);

    const grade = firstRelation<{ name: string }>(course?.grade_levels);
    const subject = firstRelation<{ name: string }>(course?.subjects);
    const release = firstRelation<{ version: string }>(course?.curriculum_releases);
    const frozen = completion?.completion_snapshot ?? {};

    const frozenCode =
      typeof frozen.course_code === "string" ? frozen.course_code : null;
    const frozenTitle =
      typeof frozen.course_title === "string" ? frozen.course_title : null;
    const frozenRelease =
      typeof frozen.curriculum_release === "string" ? frozen.curriculum_release : null;
    const frozenCompletionDate =
      typeof frozen.completion_date === "string" ? frozen.completion_date : null;

    const liveGrade = completion ? null : liveGradeFor(enrollment.id);

    return {
      completion_record_id: completion?.id ?? null,
      enrollment_id: enrollment.id,
      course_version_id: enrollment.course_version_id,
      course_code: frozenCode ?? course?.course_code ?? "COURSE",
      title: frozenTitle ?? course?.title ?? "Course",
      subject_name: subject?.name ?? null,
      course_grade_level: grade?.name ?? null,
      curriculum_release: frozenRelease ?? release?.version ?? null,
      attempt_number: enrollment.attempt_number,
      start_date: enrollment.start_date,
      completion_date:
        frozenCompletionDate ??
        (completion ? completion.completed_at.slice(0, 10) : enrollment.end_date),
      final_percentage: completion
        ? numeric(completion.final_percentage)
        : liveGrade,
      final_letter_grade: completion
        ? completion.final_letter_grade
        : letterGrade(liveGrade),
      credits_attempted: completion
        ? numeric(completion.credits_attempted)
        : numeric(course?.credit_value),
      credits_earned: completion ? numeric(completion.credits_earned) : null,
      instructional_minutes: completion?.instructional_minutes ?? null,
      competencies_mastered: completion?.competencies_mastered ?? null,
      competencies_total: completion?.competencies_total ?? null,
      status: completion ? "completed" : enrollment.status,
    };
  }

  const academicYears: TranscriptAcademicYear[] = placements.map((placement) => {
    const academicYear = firstRelation<{
      id: string;
      name: string;
      start_date: string;
      end_date: string;
    }>(placement.academic_years);
    const gradeLevel = firstRelation<{ code: string; name: string }>(
      placement.grade_levels
    );

    if (!academicYear || !gradeLevel) {
      throw new Error("Academic-year placement is incomplete.");
    }

    const placementAttendance = attendance.filter(
      (row) => row.student_academic_year_id === placement.id
    );

    const placementEnrollments = enrollments.filter(
      (row) => row.student_academic_year_id === placement.id
    );

    const completedCourses = placementEnrollments
      .map((enrollment) => {
        const completion = completionByEnrollment.get(enrollment.id) ?? null;
        return completion ? courseFromEnrollment(enrollment, completion) : null;
      })
      .filter((row): row is TranscriptCourse => row !== null);

    const currentCourses = placementEnrollments
      .filter((enrollment) => !completionByEnrollment.has(enrollment.id))
      .filter(
        (enrollment) =>
          enrollment.status === "active" || enrollment.status === "planned"
      )
      .map((enrollment) => courseFromEnrollment(enrollment, null));

    return {
      placement_id: placement.id,
      academic_year_id: academicYear.id,
      academic_year_name: academicYear.name,
      official_grade_code: gradeLevel.code,
      official_grade_name: gradeLevel.name,
      placement_status: placement.status,
      start_date: placement.start_date,
      end_date: placement.end_date ?? academicYear.end_date,
      attendance: {
        present_days: placementAttendance.filter((row) => row.status === "present").length,
        partial_days: placementAttendance.filter((row) => row.status === "partial").length,
        absent_days: placementAttendance.filter((row) => row.status === "absent").length,
        excused_days: placementAttendance.filter((row) => row.status === "excused").length,
        instructional_days: placementAttendance.filter(
          (row) => row.status === "present" || row.status === "partial"
        ).length,
        instructional_minutes: placementAttendance.reduce(
          (sum, row) => sum + (row.instructional_minutes ?? 0),
          0
        ),
      },
      completed_courses: completedCourses,
      current_courses: currentCourses,
    };
  });

  const allCompleted = academicYears.flatMap((year) => year.completed_courses);
  const allCurrent = academicYears.flatMap((year) => year.current_courses);

  return {
    schema_version: 1,
    generated_at: new Date().toISOString(),
    record_as_of: recordAsOf,
    organization: {
      id: organization.id,
      name: organization.name,
      timezone: organization.timezone,
    },
    student: {
      id: student.id,
      student_number: student.student_number,
      first_name: student.first_name,
      middle_name: student.middle_name,
      last_name: student.last_name,
      preferred_name: student.preferred_name,
      date_of_birth: student.date_of_birth,
      enrollment_date: student.enrollment_date,
      graduation_date: student.graduation_date,
      status: student.status,
    },
    academic_years: academicYears,
    cumulative: {
      completed_courses: allCompleted.length,
      active_courses: allCurrent.length,
      instructional_days: academicYears.reduce(
        (sum, year) => sum + year.attendance.instructional_days,
        0
      ),
      instructional_minutes: academicYears.reduce(
        (sum, year) => sum + year.attendance.instructional_minutes,
        0
      ),
      credits_attempted: round1(
        allCompleted.reduce((sum, course) => sum + (course.credits_attempted ?? 0), 0)
      ),
      credits_earned: round1(
        allCompleted.reduce((sum, course) => sum + (course.credits_earned ?? 0), 0)
      ),
    },
  };
}
