import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { isSupabaseConfigured } from "@/lib/env";

export async function requireAuthenticatedUser() {
  if (!isSupabaseConfigured()) redirect("/login");
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  const userId = data?.claims?.sub;
  if (!userId) redirect("/login");
  return { supabase, userId };
}

export async function requireOrganization() {
  const { supabase, userId } = await requireAuthenticatedUser();
  const { data: membership } = await supabase
    .from("organization_members")
    .select("organization_id, role, organizations(id,name,slug,timezone)")
    .eq("profile_id", userId)
    .eq("status", "active")
    .in("role", ["owner", "administrator", "instructor"])
    .limit(1)
    .maybeSingle();

  if (!membership) redirect("/setup");
  const organizationValue = membership.organizations as unknown;
  const organization = (Array.isArray(organizationValue) ? organizationValue[0] : organizationValue) as
    | { id: string; name: string; slug: string; timezone: string }
    | null;
  if (!organization) redirect("/setup");
  return { supabase, userId, membership, organization };
}


export async function requireStudent() {
  if (!isSupabaseConfigured()) redirect("/student/login");
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;
  if (!userId) redirect("/student/login");
  const { data: link } = await supabase
    .from("student_user_links")
    .select("organization_id,student_id,login_username,students(id,student_number,first_name,last_name,preferred_name,status),organizations(id,name,slug,timezone)")
    .eq("profile_id", userId)
    .eq("is_active", true)
    .limit(1)
    .maybeSingle();

  if (!link) {
    const { data: membership } = await supabase
      .from("organization_members")
      .select("id")
      .eq("profile_id", userId)
      .eq("status", "active")
      .limit(1)
      .maybeSingle();
    if (membership) redirect("/dashboard");
    redirect("/student/login");
  }

  const studentValue = link.students as unknown;
  const organizationValue = link.organizations as unknown;
  const student = (Array.isArray(studentValue) ? studentValue[0] : studentValue) as
    | { id: string; student_number: string; first_name: string; last_name: string; preferred_name: string | null; status: string }
    | null;
  const organization = (Array.isArray(organizationValue) ? organizationValue[0] : organizationValue) as
    | { id: string; name: string; slug: string; timezone: string }
    | null;

  if (!student || !organization || student.status !== "active") redirect("/student/login");

  return { supabase, userId, link, student, organization };
}
