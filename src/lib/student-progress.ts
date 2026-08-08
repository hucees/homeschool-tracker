import type { createClient } from "@/lib/supabase/server";

type AppSupabase = Awaited<ReturnType<typeof createClient>>;

type OrganizationInput = {
  id: string;
  name: string;
  timezone: string;
};

type AcademicYearRelation = {
  id: string;
  name: string;
  start_date: string;
  end_date: string;
  status: string;
};

type GradeLevelRelation = {
  id: string;
  code: string;
  name: string;
};

type PlacementRow = {
  id: string;
  academic_year_id: string;
  status: string;
  start_date: string;
  end_date: string | null;
  academic_years: unknown;
  grade_levels: unknown;
};

type EnrollmentRow = {
  id: string;
  course_version_id: string;
  status: string;
  start_date: string;
  end_date: string | null;
  course_versions: unknown;
};

type LessonRow = {
  id: string;
  course_version_id: string;
  week_number: number;
};

type DailyRecordRow = {
  id: string;
  record_date: string;
};

type DailyEntryRow = {
  daily_record_id: string;
  student_course_enrollment_id: string;
  lesson_id: string | null;
  status: string;
  minutes_spent: number | null;
};

type AssignmentRow = {
  id: string;
  student_course_enrollment_id: string;
  title: string;
  weight: number | string | null;
  assigned_date: string;
  status: string;
};

type GradeRow = {
  student_assignment_id: string;
  percentage: number | string | null;
};

type CompetencyRow = {
  id: string;
  course_version_id: string;
  code: string;
  title: string;
  sequence: number;
  mastery_threshold_percent: number | string | null;
  minimum_independent_demonstrations: number;
};

type EvidenceRow = {
  student_course_enrollment_id: string;
  competency_id: string;
  rating: string;
  score: number | string | null;
  recorded_at: string;
};

type AttendanceRow = {
  attendance_date: string;
  status: string;
  instructional_minutes: number | null;
  teacher_confirmed: boolean;
};

export type CompetencyProgressSnapshot = {
  code: string;
  title: string;
  status: "Mastered" | "Proficient" | "Practicing" | "Needs review" | "Not started";
  qualifying_demonstrations: number;
  required_demonstrations: number;
  threshold_percent: number;
};

export type CourseProgressSnapshot = {
  enrollment_id: string;
  course_version_id: string;
  course_code: string;
  title: string;
  enrollment_status: string;
  start_date: string;
  end_date: string | null;
  instructional_weeks: number;
  current_week: number;
  lessons_completed: number;
  lessons_total: number;
  lesson_progress_percent: number;
  period_instructional_minutes: number;
  graded_assignments: number;
  current_grade_percent: number | null;
  current_letter_grade: string | null;
  competency_counts: {
    mastered: number;
    proficient: number;
    practicing: number;
    needs_review: number;
    not_started: number;
    total: number;
  };
  competencies: CompetencyProgressSnapshot[];
};

export type StudentProgressSnapshot = {
  schema_version: 1;
  generated_at: string;
  organization: {
    id: string;
    name: string;
    timezone: string;
  };
  student: {
    id: string;
    student_number: string;
    first_name: string;
    last_name: string;
    preferred_name: string | null;
  };
  academic_year: {
    id: string;
    name: string;
    placement_id: string;
    official_grade_code: string;
    official_grade_name: string;
    start_date: string;
    end_date: string;
  };
  report: {
    report_type: string;
    period_start: string;
    period_end: string;
    teacher_comments: string | null;
  };
  attendance: {
    present_days: number;
    partial_days: number;
    absent_days: number;
    excused_days: number;
    holiday_days: number;
    not_scheduled_days: number;
    confirmed_records: number;
    instructional_days: number;
    instructional_minutes: number;
  };
  courses: CourseProgressSnapshot[];
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

function competencyStatus(
  competency: CompetencyRow,
  evidence: EvidenceRow[]
): CompetencyProgressSnapshot {
  const rows = evidence.filter((row) => row.competency_id === competency.id);
  const threshold = numeric(competency.mastery_threshold_percent) ?? 80;

  const qualifying = rows.filter((row) => {
    const score = numeric(row.score);
    return (
      score !== null &&
      score >= threshold &&
      (row.rating === "proficient" || row.rating === "mastered")
    );
  }).length;

  let status: CompetencyProgressSnapshot["status"];
  if (qualifying >= competency.minimum_independent_demonstrations) {
    status = "Mastered";
  } else if (qualifying >= 1) {
    status = "Proficient";
  } else if (rows.some((row) => row.rating === "practicing")) {
    status = "Practicing";
  } else if (rows.length) {
    status = "Needs review";
  } else {
    status = "Not started";
  }

  return {
    code: competency.code,
    title: competency.title,
    status,
    qualifying_demonstrations: qualifying,
    required_demonstrations: competency.minimum_independent_demonstrations,
    threshold_percent: threshold,
  };
}

export async function buildStudentProgressSnapshot({
  supabase,
  organization,
  studentId,
  periodStart,
  periodEnd,
  reportType = "progress_report",
  teacherComments = null,
}: {
  supabase: AppSupabase;
  organization: OrganizationInput;
  studentId: string;
  periodStart?: string;
  periodEnd: string;
  reportType?: string;
  teacherComments?: string | null;
}): Promise<StudentProgressSnapshot> {
  const [{ data: student }, { data: placementData }] = await Promise.all([
    supabase
      .from("students")
      .select("id,student_number,first_name,last_name,preferred_name")
      .eq("organization_id", organization.id)
      .eq("id", studentId)
      .maybeSingle(),
    supabase
      .from("student_academic_years")
      .select("id,academic_year_id,status,start_date,end_date,academic_years(id,name,start_date,end_date,status),grade_levels(id,code,name)")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .order("start_date", { ascending: false }),
  ]);

  if (!student) throw new Error("Student record was not found.");

  const placements = (placementData ?? []) as PlacementRow[];

  const overlapping = placements.find((placement) => {
    const year = firstRelation<AcademicYearRelation>(placement.academic_years);
    if (!year) return false;
    const effectiveStart = placement.start_date;
    const effectiveEnd = placement.end_date ?? year.end_date;
    const requestedStart = periodStart ?? effectiveStart;
    return effectiveStart <= periodEnd && effectiveEnd >= requestedStart;
  });

  const placement =
    overlapping ??
    placements.find((row) => row.status === "active") ??
    placements[0];

  if (!placement) throw new Error("No academic year placement exists for this student.");

  const academicYear = firstRelation<AcademicYearRelation>(placement.academic_years);
  const gradeLevel = firstRelation<GradeLevelRelation>(placement.grade_levels);

  if (!academicYear || !gradeLevel) {
    throw new Error("The student's academic year or grade level is incomplete.");
  }

  const effectivePeriodStart = periodStart ?? placement.start_date;
  if (effectivePeriodStart > periodEnd) {
    throw new Error("Report end date cannot be before the start date.");
  }

  const placementEnd = placement.end_date ?? academicYear.end_date;
  if (effectivePeriodStart < placement.start_date || periodEnd > placementEnd) {
    throw new Error(
      `The reporting period must stay within this placement (${placement.start_date} through ${placementEnd}).`
    );
  }

  const { data: enrollmentData } = await supabase
    .from("student_course_enrollments")
    .select("id,course_version_id,status,start_date,end_date,course_versions(title,course_code,instructional_weeks)")
    .eq("organization_id", organization.id)
    .eq("student_id", studentId)
    .eq("student_academic_year_id", placement.id)
    .neq("status", "withdrawn")
    .neq("status", "superseded")
    .order("start_date");

  const enrollments = (enrollmentData ?? []) as EnrollmentRow[];
  const enrollmentIds = enrollments.map((row) => row.id);
  const courseVersionIds = [...new Set(enrollments.map((row) => row.course_version_id))];

  let lessons: LessonRow[] = [];
  let competencies: CompetencyRow[] = [];
  let dailyRecords: DailyRecordRow[] = [];
  let dailyEntries: DailyEntryRow[] = [];
  let assignments: AssignmentRow[] = [];
  let grades: GradeRow[] = [];
  let evidence: EvidenceRow[] = [];
  let attendance: AttendanceRow[] = [];

  if (courseVersionIds.length) {
    const [lessonResult, competencyResult] = await Promise.all([
      supabase
        .from("lessons")
        .select("id,course_version_id,week_number")
        .eq("organization_id", organization.id)
        .in("course_version_id", courseVersionIds)
        .eq("status", "active"),
      supabase
        .from("competencies")
        .select("id,course_version_id,code,title,sequence,mastery_threshold_percent,minimum_independent_demonstrations")
        .eq("organization_id", organization.id)
        .in("course_version_id", courseVersionIds)
        .order("sequence"),
    ]);

    lessons = (lessonResult.data ?? []) as LessonRow[];
    competencies = (competencyResult.data ?? []) as CompetencyRow[];
  }

  const { data: dailyRecordData } = await supabase
    .from("student_daily_records")
    .select("id,record_date")
    .eq("organization_id", organization.id)
    .eq("student_id", studentId)
    .gte("record_date", placement.start_date)
    .lte("record_date", periodEnd)
    .order("record_date");

  dailyRecords = (dailyRecordData ?? []) as DailyRecordRow[];
  const dailyRecordIds = dailyRecords.map((row) => row.id);

  if (dailyRecordIds.length && enrollmentIds.length) {
    const { data } = await supabase
      .from("daily_learning_entries")
      .select("daily_record_id,student_course_enrollment_id,lesson_id,status,minutes_spent")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .in("daily_record_id", dailyRecordIds)
      .in("student_course_enrollment_id", enrollmentIds);

    dailyEntries = (data ?? []) as DailyEntryRow[];
  }

  if (enrollmentIds.length) {
    const [assignmentResult, evidenceResult] = await Promise.all([
      supabase
        .from("student_assignments")
        .select("id,student_course_enrollment_id,title,weight,assigned_date,status")
        .eq("organization_id", organization.id)
        .eq("student_id", studentId)
        .in("student_course_enrollment_id", enrollmentIds)
        .gte("assigned_date", effectivePeriodStart)
        .lte("assigned_date", periodEnd)
        .neq("status", "cancelled"),
      supabase
        .from("competency_evidence")
        .select("student_course_enrollment_id,competency_id,rating,score,recorded_at")
        .eq("organization_id", organization.id)
        .eq("student_id", studentId)
        .in("student_course_enrollment_id", enrollmentIds)
        .eq("is_current", true)
        .lte("recorded_at", `${periodEnd}T23:59:59.999Z`),
    ]);

    assignments = (assignmentResult.data ?? []) as AssignmentRow[];
    evidence = (evidenceResult.data ?? []) as EvidenceRow[];
  }

  const assignmentIds = assignments.map((row) => row.id);
  if (assignmentIds.length) {
    const { data } = await supabase
      .from("grade_records")
      .select("student_assignment_id,percentage")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .eq("status", "current")
      .in("student_assignment_id", assignmentIds);

    grades = (data ?? []) as GradeRow[];
  }

  const { data: attendanceData } = await supabase
    .from("attendance_records")
    .select("attendance_date,status,instructional_minutes,teacher_confirmed")
    .eq("organization_id", organization.id)
    .eq("student_id", studentId)
    .gte("attendance_date", effectivePeriodStart)
    .lte("attendance_date", periodEnd)
    .eq("teacher_confirmed", true)
    .order("attendance_date");

  attendance = (attendanceData ?? []) as AttendanceRow[];

  const recordDateById = new Map(dailyRecords.map((row) => [row.id, row.record_date]));
  const lessonById = new Map(lessons.map((lesson) => [lesson.id, lesson]));
  const gradeByAssignment = new Map(grades.map((grade) => [grade.student_assignment_id, grade]));

  const courses: CourseProgressSnapshot[] = enrollments.map((enrollment) => {
    const course = firstRelation<{
      title: string;
      course_code: string;
      instructional_weeks: number;
    }>(enrollment.course_versions);

    const courseLessons = lessons.filter(
      (lesson) => lesson.course_version_id === enrollment.course_version_id
    );

    const courseEntries = dailyEntries.filter(
      (entry) => entry.student_course_enrollment_id === enrollment.id
    );

    const completedEntries = courseEntries.filter(
      (entry) => entry.status === "completed" && entry.lesson_id
    );

    const completedLessonIds = new Set(
      completedEntries.map((entry) => entry.lesson_id as string)
    );

    const completedWeeks = [...completedLessonIds]
      .map((lessonId) => lessonById.get(lessonId)?.week_number ?? 0)
      .filter((week) => week > 0);

    const currentWeek = completedWeeks.length ? Math.max(...completedWeeks) : 0;

    const periodMinutes = courseEntries
      .filter((entry) => {
        const recordDate = recordDateById.get(entry.daily_record_id);
        return (
          recordDate !== undefined &&
          recordDate >= effectivePeriodStart &&
          recordDate <= periodEnd
        );
      })
      .reduce((sum, entry) => sum + (entry.minutes_spent ?? 0), 0);

    const courseAssignments = assignments.filter(
      (assignment) => assignment.student_course_enrollment_id === enrollment.id
    );

    let weightedTotal = 0;
    let weightTotal = 0;
    let gradedAssignments = 0;

    for (const assignment of courseAssignments) {
      const grade = gradeByAssignment.get(assignment.id);
      const percentage = numeric(grade?.percentage);
      if (percentage === null) continue;

      const rawWeight = numeric(assignment.weight);
      const weight = rawWeight !== null && rawWeight > 0 ? rawWeight : 1;
      weightedTotal += percentage * weight;
      weightTotal += weight;
      gradedAssignments += 1;
    }

    const currentGrade =
      weightTotal > 0 ? round1(weightedTotal / weightTotal) : null;

    const courseCompetencies = competencies
      .filter((competency) => competency.course_version_id === enrollment.course_version_id)
      .map((competency) =>
        competencyStatus(
          competency,
          evidence.filter(
            (row) => row.student_course_enrollment_id === enrollment.id
          )
        )
      );

    const counts = {
      mastered: courseCompetencies.filter((row) => row.status === "Mastered").length,
      proficient: courseCompetencies.filter((row) => row.status === "Proficient").length,
      practicing: courseCompetencies.filter((row) => row.status === "Practicing").length,
      needs_review: courseCompetencies.filter((row) => row.status === "Needs review").length,
      not_started: courseCompetencies.filter((row) => row.status === "Not started").length,
      total: courseCompetencies.length,
    };

    const lessonTotal = courseLessons.length;
    const lessonCompleted = completedLessonIds.size;

    return {
      enrollment_id: enrollment.id,
      course_version_id: enrollment.course_version_id,
      course_code: course?.course_code ?? "COURSE",
      title: course?.title ?? "Assigned course",
      enrollment_status: enrollment.status,
      start_date: enrollment.start_date,
      end_date: enrollment.end_date,
      instructional_weeks: course?.instructional_weeks ?? 36,
      current_week: currentWeek,
      lessons_completed: lessonCompleted,
      lessons_total: lessonTotal,
      lesson_progress_percent:
        lessonTotal > 0 ? round1((lessonCompleted / lessonTotal) * 100) : 0,
      period_instructional_minutes: periodMinutes,
      graded_assignments: gradedAssignments,
      current_grade_percent: currentGrade,
      current_letter_grade: letterGrade(currentGrade),
      competency_counts: counts,
      competencies: courseCompetencies,
    };
  });

  const attendanceCounts = {
    present_days: attendance.filter((row) => row.status === "present").length,
    partial_days: attendance.filter((row) => row.status === "partial").length,
    absent_days: attendance.filter((row) => row.status === "absent").length,
    excused_days: attendance.filter((row) => row.status === "excused").length,
    holiday_days: attendance.filter((row) => row.status === "holiday").length,
    not_scheduled_days: attendance.filter((row) => row.status === "not_scheduled").length,
    confirmed_records: attendance.length,
    instructional_days: attendance.filter(
      (row) => row.status === "present" || row.status === "partial"
    ).length,
    instructional_minutes: attendance.reduce(
      (sum, row) => sum + (row.instructional_minutes ?? 0),
      0
    ),
  };

  return {
    schema_version: 1,
    generated_at: new Date().toISOString(),
    organization: {
      id: organization.id,
      name: organization.name,
      timezone: organization.timezone,
    },
    student: {
      id: student.id,
      student_number: student.student_number,
      first_name: student.first_name,
      last_name: student.last_name,
      preferred_name: student.preferred_name,
    },
    academic_year: {
      id: academicYear.id,
      name: academicYear.name,
      placement_id: placement.id,
      official_grade_code: gradeLevel.code,
      official_grade_name: gradeLevel.name,
      start_date: placement.start_date,
      end_date: placementEnd,
    },
    report: {
      report_type: reportType,
      period_start: effectivePeriodStart,
      period_end: periodEnd,
      teacher_comments: teacherComments?.trim() || null,
    },
    attendance: attendanceCounts,
    courses,
  };
}
