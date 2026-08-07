export function isSupabaseConfigured() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  return Boolean(
    url &&
      key &&
      !url.includes("YOUR_PROJECT_REF") &&
      !key.includes("REPLACE_ME")
  );
}

export function getSupabaseEnv() {
  if (!isSupabaseConfigured()) {
    throw new Error(
      "Supabase is not configured. Copy .env.example to .env.local and add the project URL and publishable key."
    );
  }

  return {
    url: process.env.NEXT_PUBLIC_SUPABASE_URL!,
    publishableKey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  };
}
