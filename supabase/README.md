# Supabase workspace

The four database migrations are already versioned in `migrations/`.

`config.toml` is intentionally not pre-generated because it should be produced by the Supabase CLI version installed on your machine when we initialize the real workspace. This avoids shipping a stale local-stack configuration.

When we reach that step, we will preserve these migration files and run `npx supabase init` / `npx supabase link` carefully.
