"use server";

import { redirect } from "next/navigation";
import { requireOrganization } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import { isValidStudentUsername, normalizeStudentUsername, studentAuthEmail } from "@/lib/student-login";

function detailUrl(studentId: string, message: string) {
  return `/dashboard/students/${studentId}?error=${encodeURIComponent(message)}`;
}

export async function createStudentLogin(formData: FormData) {
  const studentId = String(formData.get("student_id") ?? "").trim();
  const username = normalizeStudentUsername(String(formData.get("username") ?? ""));
  const password = String(formData.get("password") ?? "");
  const confirmPassword = String(formData.get("confirm_password") ?? "");

  if (!studentId) redirect("/dashboard/students");
  if (!isValidStudentUsername(username)) {
    redirect(detailUrl(studentId, "Username must be 3–20 characters using lowercase letters, numbers, dots, underscores, or hyphens."));
  }
  if (password.length < 8) redirect(detailUrl(studentId, "Student password must be at least 8 characters."));
  if (password !== confirmPassword) redirect(detailUrl(studentId, "The two passwords do not match."));

  const { supabase, organization } = await requireOrganization();

  const [{ data: student }, { data: existingStudentLink }, { data: existingUsername }] = await Promise.all([
    supabase
      .from("students")
      .select("id,first_name,last_name,preferred_name")
      .eq("organization_id", organization.id)
      .eq("id", studentId)
      .maybeSingle(),
    supabase
      .from("student_user_links")
      .select("id")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .maybeSingle(),
    supabase
      .from("student_user_links")
      .select("id")
      .eq("organization_id", organization.id)
      .ilike("login_username", username)
      .maybeSingle(),
  ]);

  if (!student) redirect(detailUrl(studentId, "Student record was not found."));
  if (existingStudentLink) redirect(detailUrl(studentId, "This student already has a login account."));
  if (existingUsername) redirect(detailUrl(studentId, "That username is already in use for this homeschool."));

  let admin;
  try {
    admin = createAdminClient();
  } catch (error) {
    redirect(detailUrl(studentId, error instanceof Error ? error.message : "Supabase admin access is not configured."));
  }

  const email = studentAuthEmail(organization.id, username);
  const displayName = student.preferred_name || student.first_name;
  const { data: created, error: authError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      first_name: student.first_name,
      last_name: student.last_name,
      display_name: displayName,
      account_type: "student",
    },
  });

  if (authError || !created.user) {
    redirect(detailUrl(studentId, authError?.message ?? "Could not create the student authentication account."));
  }

  const { error: linkError } = await supabase.from("student_user_links").insert({
    organization_id: organization.id,
    student_id: studentId,
    profile_id: created.user.id,
    login_username: username,
    is_active: true,
  });

  if (linkError) {
    await admin.auth.admin.deleteUser(created.user.id);
    redirect(detailUrl(studentId, linkError.message));
  }

  redirect(`/dashboard/students/${studentId}?login_created=${encodeURIComponent(username)}`);
}

export async function resetStudentPassword(formData: FormData) {
  const studentId = String(formData.get("student_id") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  const confirmPassword = String(formData.get("confirm_password") ?? "");

  if (!studentId) redirect("/dashboard/students");
  if (password.length < 8) redirect(detailUrl(studentId, "Student password must be at least 8 characters."));
  if (password !== confirmPassword) redirect(detailUrl(studentId, "The two passwords do not match."));

  const { supabase, organization } = await requireOrganization();
  const { data: link } = await supabase
    .from("student_user_links")
    .select("profile_id")
    .eq("organization_id", organization.id)
    .eq("student_id", studentId)
    .eq("is_active", true)
    .maybeSingle();

  if (!link?.profile_id) redirect(detailUrl(studentId, "This student does not have an active login account."));

  let admin;
  try {
    admin = createAdminClient();
  } catch (error) {
    redirect(detailUrl(studentId, error instanceof Error ? error.message : "Supabase admin access is not configured."));
  }

  const { error } = await admin.auth.admin.updateUserById(link.profile_id, { password });
  if (error) redirect(detailUrl(studentId, error.message));

  redirect(`/dashboard/students/${studentId}?password_reset=1`);
}
