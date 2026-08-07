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
