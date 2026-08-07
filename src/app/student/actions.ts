"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { requireStudent } from "@/lib/auth";
import { localDateInTimezone } from "@/lib/student-login";

export async function saveDailyCourseWork(formData: FormData) {
  const enrollmentId = String(formData.get("enrollment_id") ?? "").trim();
  const lessonId = String(formData.get("lesson_id") ?? "").trim();
  const minutesRaw = String(formData.get("minutes_spent") ?? "").trim();
  const note = String(formData.get("student_note") ?? "").trim();
  const completed = formData.get("completed") === "on";

  if (!enrollmentId || !lessonId) redirect("/student?error=Lesson%20information%20is%20missing.");

  const minutes = minutesRaw ? Number.parseInt(minutesRaw, 10) : null;
  if (minutes !== null && (!Number.isFinite(minutes) || minutes < 0 || minutes > 1440)) {
    redirect("/student?error=Minutes%20worked%20must%20be%20between%200%20and%201440.");
  }

  const { supabase, organization } = await requireStudent();
  const recordDate = localDateInTimezone(organization.timezone);

  const { error } = await supabase.rpc("save_student_daily_course_work", {
    p_student_course_enrollment_id: enrollmentId,
    p_lesson_id: lessonId,
    p_record_date: recordDate,
    p_minutes_spent: minutes,
    p_student_note: note || null,
    p_completed: completed,
  });

  if (error) redirect(`/student?error=${encodeURIComponent(error.message)}`);

  revalidatePath("/student");
  redirect("/student?saved=1");
}

export async function studentSignOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/student/login");
}
