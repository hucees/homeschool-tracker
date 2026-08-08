# Report Hash Fix

Migration 011 fixes the official-report SHA-256 error:

`function public.digest(text, unknown) does not exist`

Supabase commonly keeps the pgcrypto extension in the `extensions` schema.
Migration 010 is intentionally left unchanged because it has already been
recorded in migration history.

Migration 011 provides a locked-down compatibility wrapper used only by the
security-definer report function.

Install:

1. Copy this update into the existing project.
2. `npm run check:starter`
3. `npx supabase db push --dry-run`
4. Confirm only `20260808001000_fix_report_digest.sql` is pending.
5. `npx supabase db push`
6. Retry Generate official report.
