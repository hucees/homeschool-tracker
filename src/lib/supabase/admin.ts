import { createClient as createSupabaseClient } from "@supabase/supabase-js";
import { getSupabaseEnv } from "@/lib/env";

export function createAdminClient() {
  const secretKey = process.env.SUPABASE_SECRET_KEY;

  if (!secretKey || secretKey.includes("REPLACE_ME")) {
    throw new Error(
      "SUPABASE_SECRET_KEY is not configured. Add the server-only secret key to .env.local before creating student logins."
    );
  }

  const { url } = getSupabaseEnv();

  return createSupabaseClient(url, secretKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}
