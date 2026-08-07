"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

function normalizeSlug(value: string) {
  return value.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

export async function createHomeschool(formData: FormData) {
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const userId = claimsData?.claims?.sub;
  if (!userId) redirect("/login");

  const name = String(formData.get("name") ?? "").trim();
  const slug = normalizeSlug(String(formData.get("slug") ?? name));
  const yearName = String(formData.get("year_name") ?? "2026–2027").trim();
  const startDate = String(formData.get("start_date") ?? "2026-08-10");
  const endDate = String(formData.get("end_date") ?? "2027-05-21");

  if (!name || !slug) redirect("/setup?error=School%20name%20is%20required.");

  const { data: organization, error: orgError } = await supabase
    .from("organizations")
    .insert({ name, slug, timezone: "America/Denver", created_by: userId })
    .select("id")
    .single();

  if (orgError || !organization) redirect(`/setup?error=${encodeURIComponent(orgError?.message ?? "Could not create organization")}`);

  const { error: membershipError } = await supabase.from("organization_members").insert({
    organization_id: organization.id,
    profile_id: userId,
    role: "owner",
    status: "active",
  });
  if (membershipError) redirect(`/setup?error=${encodeURIComponent(membershipError.message)}`);

  const { error: yearError } = await supabase.from("academic_years").insert({
    organization_id: organization.id,
    name: yearName,
    start_date: startDate,
    end_date: endDate,
    status: "active",
  });
  if (yearError) redirect(`/setup?error=${encodeURIComponent(yearError.message)}`);

  const { error: curriculumError } = await supabase.rpc("install_grade1_math_2026_1", {
    p_organization_id: organization.id,
  });
  if (curriculumError) redirect(`/setup?error=${encodeURIComponent(curriculumError.message)}`);

  redirect("/dashboard?setup=complete");
}
