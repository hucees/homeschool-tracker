"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { normalizeStudentUsername, studentAuthEmail } from "@/lib/student-login";

export async function studentLogin(formData: FormData) {
  const schoolCode = String(formData.get("school_code") ?? "").trim().toLowerCase();
  const username = normalizeStudentUsername(String(formData.get("username") ?? ""));
  const password = String(formData.get("password") ?? "");

  if (!schoolCode || !username || !password) {
    redirect("/student/login?error=Enter%20your%20school%20code,%20username,%20and%20password.");
  }

  let admin;
  try {
    admin = createAdminClient();
  } catch {
    redirect("/student/login?error=Student%20login%20is%20not%20configured%20yet.");
  }

  const { data: organization } = await admin
    .from("organizations")
    .select("id")
    .eq("slug", schoolCode)
    .eq("status", "active")
    .maybeSingle();

  if (!organization) {
    redirect("/student/login?error=School%20code,%20username,%20or%20password%20is%20incorrect.");
  }

  const { data: link } = await admin
    .from("student_user_links")
    .select("id")
    .eq("organization_id", organization.id)
    .eq("login_username", username)
    .eq("is_active", true)
    .maybeSingle();

  if (!link) {
    redirect("/student/login?error=School%20code,%20username,%20or%20password%20is%20incorrect.");
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: studentAuthEmail(organization.id, username),
    password,
  });

  if (error) {
    redirect("/student/login?error=School%20code,%20username,%20or%20password%20is%20incorrect.");
  }

  redirect("/student");
}
