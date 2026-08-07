"use server";

import { redirect } from "next/navigation";
import { requireOrganization } from "@/lib/auth";

function optionalText(formData: FormData, name: string) {
  const value = String(formData.get(name) ?? "").trim();
  return value || null;
}

export async function createStudent(formData: FormData) {
  const { supabase, organization } = await requireOrganization();

  const firstName = String(formData.get("first_name") ?? "").trim();
  const lastName = String(formData.get("last_name") ?? "").trim();
  const academicYearId = String(formData.get("academic_year_id") ?? "").trim();
  const officialGradeLevelId = String(formData.get("official_grade_level_id") ?? "").trim();
  const enrollmentDate = String(formData.get("enrollment_date") ?? "").trim();
  const assignGrade1Math = formData.get("assign_grade1_math") === "on";

  if (!firstName || !lastName || !academicYearId || !officialGradeLevelId || !enrollmentDate) {
    redirect("/dashboard/students/new?error=Please%20complete%20all%20required%20fields.");
  }

  let courseVersionId: string | null = null;

  if (assignGrade1Math) {
    const { data: courseVersion, error: courseError } = await supabase
      .from("course_versions")
      .select("id")
      .eq("organization_id", organization.id)
      .eq("course_code", "1-MATH")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (courseError || !courseVersion) {
      redirect(
        `/dashboard/students/new?error=${encodeURIComponent(
          courseError?.message ?? "Grade 1 Mathematics is not installed for this homeschool."
        )}`
      );
    }

    courseVersionId = courseVersion.id;
  }

  const dateOfBirth = optionalText(formData, "date_of_birth");

  const { data, error } = await supabase.rpc("create_student_with_initial_enrollment", {
    p_organization_id: organization.id,
    p_first_name: firstName,
    p_last_name: lastName,
    p_official_grade_level_id: officialGradeLevelId,
    p_academic_year_id: academicYearId,
    p_enrollment_date: enrollmentDate,
    p_middle_name: optionalText(formData, "middle_name"),
    p_preferred_name: optionalText(formData, "preferred_name"),
    p_date_of_birth: dateOfBirth,
    p_course_version_id: courseVersionId,
  });

  if (error) {
    redirect(`/dashboard/students/new?error=${encodeURIComponent(error.message)}`);
  }

  const result = Array.isArray(data) ? data[0] : data;
  const studentNumber = result?.student_number ? String(result.student_number) : "Student";

  redirect(`/dashboard/students?created=${encodeURIComponent(studentNumber)}`);
}
