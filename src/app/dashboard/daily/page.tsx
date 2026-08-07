import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";
import { localDateInTimezone } from "@/lib/student-login";
import { reviewStudentDay } from "./actions";

type Placement = {
  id: string;
  student_id: string;
  start_date: string;
  end_date: string | null;
  students: unknown;
  grade_levels: unknown;
};

type DailyRecord = {
  id: string;
  student_id: string;
  student_academic_year_id: string;
  status: string;
  student_summary: string | null;
};

type Entry = {
  id: string;
  daily_record_id: string;
  student_id: string;
  student_course_enrollment_id: string;
  lesson_id: string | null;
  status: string;
  minutes_spent: number | null;
  student_note: string | null;
};

type Attendance = {
  id: string;
  student_academic_year_id: string;
  status: string;
  instructional_minutes: number | null;
  teacher_confirmed: boolean;
  notes: string | null;
};

type Review = {
  id: string;
  daily_record_id: string;
  review_status: string;
  teacher_summary: string | null;
  reviewed_at: string;
};

function firstRelation<T>(value: unknown): T | null {
  if (Array.isArray(value)) return (value[0] as T | undefined) ?? null;
  return (value as T | null) ?? null;
}

function validDate(value?: string) {
  return value && /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : null;
}

function attendanceLabel(status: string) {
  return status.replaceAll("_", " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

export default async function DailyReviewPage({
  searchParams,
}: {
  searchParams: Promise<{ date?: string; reviewed?: string; error?: string }>;
}) {
  const params = await searchParams;
  const { supabase, organization } = await requireOrganization();
  const recordDate = validDate(params.date) ?? localDateInTimezone(organization.timezone);

  const { data: placementData } = await supabase
    .from("student_academic_years")
    .select("id,student_id,start_date,end_date,students(id,student_number,first_name,last_name,preferred_name,status),grade_levels(name,code)")
    .eq("organization_id", organization.id)
    .eq("status", "active")
    .lte("start_date", recordDate)
    .order("start_date");

  const placements = ((placementData ?? []) as Placement[]).filter((placement) => {
    const student = firstRelation<{ status: string }>(placement.students);
    return student?.status === "active" && (!placement.end_date || placement.end_date >= recordDate);
  });

  const studentIds = placements.map((item) => item.student_id);
  const placementIds = placements.map((item) => item.id);

  let records: DailyRecord[] = [];
  let entries: Entry[] = [];
  let attendance: Attendance[] = [];
  let reviews: Review[] = [];

  if (studentIds.length) {
    const [recordResult, attendanceResult] = await Promise.all([
      supabase
        .from("student_daily_records")
        .select("id,student_id,student_academic_year_id,status,student_summary")
        .eq("organization_id", organization.id)
        .eq("record_date", recordDate)
        .in("student_id", studentIds),
      supabase
        .from("attendance_records")
        .select("id,student_academic_year_id,status,instructional_minutes,teacher_confirmed,notes")
        .eq("organization_id", organization.id)
        .eq("attendance_date", recordDate)
        .in("student_academic_year_id", placementIds),
    ]);

    records = (recordResult.data ?? []) as DailyRecord[];
    attendance = (attendanceResult.data ?? []) as Attendance[];

    const recordIds = records.map((item) => item.id);
    if (recordIds.length) {
      const [entryResult, reviewResult] = await Promise.all([
        supabase
          .from("daily_learning_entries")
          .select("id,daily_record_id,student_id,student_course_enrollment_id,lesson_id,status,minutes_spent,student_note")
          .in("daily_record_id", recordIds)
          .order("created_at"),
        supabase
          .from("daily_record_reviews")
          .select("id,daily_record_id,review_status,teacher_summary,reviewed_at")
          .in("daily_record_id", recordIds),
      ]);
      entries = (entryResult.data ?? []) as Entry[];
      reviews = (reviewResult.data ?? []) as Review[];
    }
  }

  const enrollmentIds = [...new Set(entries.map((item) => item.student_course_enrollment_id))];
  const lessonIds = [...new Set(entries.flatMap((item) => item.lesson_id ? [item.lesson_id] : []))];

  const enrollmentMap = new Map<string, { title: string; code: string }>();
  const lessonMap = new Map<string, { title: string; code: string }>();

  if (enrollmentIds.length) {
    const { data } = await supabase
      .from("student_course_enrollments")
      .select("id,course_versions(title,course_code)")
      .in("id", enrollmentIds);

    for (const row of data ?? []) {
      const course = firstRelation<{ title: string; course_code: string }>((row as { course_versions: unknown }).course_versions);
      if (course) enrollmentMap.set(row.id, { title: course.title, code: course.course_code });
    }
  }

  if (lessonIds.length) {
    const { data } = await supabase
      .from("lessons")
      .select("id,title,code")
      .in("id", lessonIds);

    for (const lesson of data ?? []) {
      lessonMap.set(lesson.id, { title: lesson.title, code: lesson.code });
    }
  }

  const recordByStudent = new Map(records.map((item) => [item.student_id, item]));
  const attendanceByPlacement = new Map(attendance.map((item) => [item.student_academic_year_id, item]));
  const reviewByRecord = new Map(reviews.map((item) => [item.daily_record_id, item]));

  const previous = new Date(`${recordDate}T12:00:00Z`);
  previous.setUTCDate(previous.getUTCDate() - 1);
  const next = new Date(`${recordDate}T12:00:00Z`);
  next.setUTCDate(next.getUTCDate() + 1);
  const previousDate = previous.toISOString().slice(0, 10);
  const nextDate = next.toISOString().slice(0, 10);

  return (
    <AppShell organizationName={organization.name}>
      <div className="grid gap-6">
        <section className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <p className="text-sm font-medium text-[#667085]">Instructor</p>
            <h1 className="mt-1 text-3xl font-bold">Daily review & attendance</h1>
            <p className="mt-2 text-[#667085]">Review student learning records and confirm the official attendance record for the day.</p>
          </div>

          <form method="get" className="flex items-end gap-2">
            <label className="grid gap-1 text-sm font-medium">
              School date
              <input name="date" type="date" defaultValue={recordDate} className="rounded-xl border border-[#d0d5dd] bg-white px-3 py-2.5" />
            </label>
            <button className="rounded-xl border border-[#d0d5dd] bg-white px-4 py-2.5 text-sm font-semibold hover:bg-slate-50">Go</button>
          </form>
        </section>

        <div className="flex items-center justify-between">
          <Link href={`/dashboard/daily?date=${previousDate}`} className="text-sm font-semibold text-[#315c4d] hover:underline">← Previous day</Link>
          <div className="text-sm font-semibold">{recordDate}</div>
          <Link href={`/dashboard/daily?date=${nextDate}`} className="text-sm font-semibold text-[#315c4d] hover:underline">Next day →</Link>
        </div>

        {params.reviewed && (
          <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800">
            Daily review and attendance were saved.
          </div>
        )}
        {params.error && (
          <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{params.error}</div>
        )}

        <section className="grid gap-5">
          {placements.length ? placements.map((placement) => {
            const student = firstRelation<{
              id: string;
              student_number: string;
              first_name: string;
              last_name: string;
              preferred_name: string | null;
            }>(placement.students);
            const grade = firstRelation<{ name: string; code: string }>(placement.grade_levels);

            if (!student) return null;

            const record = recordByStudent.get(placement.student_id);
            const studentEntries = record ? entries.filter((entry) => entry.daily_record_id === record.id) : [];
            const existingAttendance = attendanceByPlacement.get(placement.id);
            const existingReview = record ? reviewByRecord.get(record.id) : undefined;
            const totalMinutes = studentEntries.reduce((sum, entry) => sum + (entry.minutes_spent ?? 0), 0);
            const completedCount = studentEntries.filter((entry) => entry.status === "completed").length;
            const suggestedAttendance = studentEntries.length
              ? (completedCount > 0 ? "present" : "partial")
              : "absent";
            const attendanceDefault = existingAttendance?.status ?? suggestedAttendance;
            const reviewDefault = existingReview?.review_status ?? "approved";

            return (
              <article key={placement.id} className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-xl font-bold">{student.preferred_name || student.first_name} {student.last_name}</h2>
                      {existingReview && (
                        <StatusPill tone={existingReview.review_status === "approved" ? "green" : "amber"}>
                          {attendanceLabel(existingReview.review_status)}
                        </StatusPill>
                      )}
                    </div>
                    <p className="mt-1 text-sm text-[#667085]">{student.student_number} · {grade?.name ?? "No grade"}</p>
                  </div>
                  <StatusPill tone={studentEntries.length ? "green" : "amber"}>
                    {studentEntries.length ? `${completedCount}/${studentEntries.length} completed` : "No work logged"}
                  </StatusPill>
                </div>

                {studentEntries.length ? (
                  <div className="mt-5 grid gap-3">
                    {studentEntries.map((entry) => {
                      const course = enrollmentMap.get(entry.student_course_enrollment_id);
                      const lesson = entry.lesson_id ? lessonMap.get(entry.lesson_id) : undefined;
                      return (
                        <div key={entry.id} className="rounded-xl bg-[#f8faf9] p-4">
                          <div className="flex flex-wrap items-start justify-between gap-3">
                            <div>
                              <div className="text-xs font-semibold uppercase tracking-wide text-[#315c4d]">{course?.code ?? "COURSE"}</div>
                              <div className="mt-1 font-bold">{course?.title ?? "Assigned course"}</div>
                              {lesson && <div className="mt-1 text-sm text-[#667085]">{lesson.code} · {lesson.title}</div>}
                            </div>
                            <div className="text-right text-sm">
                              <div className="font-semibold capitalize">{entry.status}</div>
                              <div className="text-[#667085]">{entry.minutes_spent ?? 0} minutes</div>
                            </div>
                          </div>
                          {entry.student_note && (
                            <div className="mt-3 rounded-lg border border-[#e4e7ec] bg-white p-3 text-sm leading-6">
                              <span className="font-semibold">Student note:</span> {entry.student_note}
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                ) : (
                  <div className="mt-5 rounded-xl bg-[#f8faf9] p-4 text-sm text-[#667085]">
                    This student has not logged academic work for {recordDate}. You can still record an absence, excused day, holiday, or other attendance status.
                  </div>
                )}

                <form action={reviewStudentDay} className="mt-6 grid gap-4 border-t border-[#eaecf0] pt-5">
                  <input type="hidden" name="student_academic_year_id" value={placement.id} />
                  <input type="hidden" name="record_date" value={recordDate} />

                  <div className="grid gap-4 md:grid-cols-3">
                    <label className="grid gap-1.5 text-sm font-medium">
                      Attendance
                      <select name="attendance_status" defaultValue={attendanceDefault} className="rounded-xl border border-[#d0d5dd] bg-white px-3.5 py-3">
                        <option value="present">Present</option>
                        <option value="partial">Partial day</option>
                        <option value="absent">Absent</option>
                        <option value="excused">Excused</option>
                        <option value="holiday">School holiday</option>
                        <option value="not_scheduled">Not scheduled</option>
                      </select>
                    </label>

                    <label className="grid gap-1.5 text-sm font-medium">
                      Instructional minutes
                      <input
                        name="instructional_minutes"
                        type="number"
                        min={0}
                        max={1440}
                        defaultValue={existingAttendance?.instructional_minutes ?? totalMinutes}
                        className="rounded-xl border border-[#d0d5dd] px-3.5 py-3"
                      />
                    </label>

                    <label className="grid gap-1.5 text-sm font-medium">
                      Learning review
                      <select name="review_status" defaultValue={reviewDefault} disabled={!record} className="rounded-xl border border-[#d0d5dd] bg-white px-3.5 py-3 disabled:bg-slate-100">
                        <option value="approved">Approved</option>
                        <option value="reviewed">Reviewed</option>
                        <option value="needs_revision">Needs revision</option>
                      </select>
                      {!record && <input type="hidden" name="review_status" value="approved" />}
                    </label>
                  </div>

                  {record && (
                    <label className="grid gap-1.5 text-sm font-medium">
                      Teacher summary
                      <textarea
                        name="teacher_summary"
                        rows={3}
                        defaultValue={existingReview?.teacher_summary ?? ""}
                        placeholder="What you observed about today's learning..."
                        className="rounded-xl border border-[#d0d5dd] px-3.5 py-3"
                      />
                    </label>
                  )}

                  <label className="grid gap-1.5 text-sm font-medium">
                    Attendance note
                    <textarea
                      name="attendance_notes"
                      rows={2}
                      defaultValue={existingAttendance?.notes ?? ""}
                      placeholder="Optional note about attendance or instructional time..."
                      className="rounded-xl border border-[#d0d5dd] px-3.5 py-3"
                    />
                  </label>

                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div className="text-xs text-[#667085]">
                      Suggested from activity: <strong>{attendanceLabel(suggestedAttendance)}</strong> · Student logged <strong>{totalMinutes} minutes</strong>
                    </div>
                    <button className="rounded-xl bg-[#315c4d] px-5 py-3 font-semibold text-white hover:bg-[#24483c]">
                      Save review & attendance
                    </button>
                  </div>
                </form>
              </article>
            );
          }) : (
            <div className="rounded-2xl border border-[#e4e7ec] bg-white p-8 text-center text-[#667085]">
              No active students are enrolled for this date.
            </div>
          )}
        </section>
      </div>
    </AppShell>
  );
}
