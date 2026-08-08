-- Homeschool Tracker
-- Migration 011: Fix report snapshot SHA-256 hashing on Supabase
--
-- Supabase commonly installs pgcrypto in the `extensions` schema. Migration 010
-- called public.digest(), which fails when pgcrypto already exists elsewhere.
-- Keep the applied Migration 010 unchanged and add this compatibility wrapper.

begin;

create or replace function public.digest(p_data text, p_type text)
returns bytea
language sql
immutable
strict
parallel safe
set search_path = ''
as $$
  select extensions.digest(p_data, p_type);
$$;

-- This is an internal compatibility function used by the SECURITY DEFINER report
-- generator. Do not expose it as an application RPC.
revoke all on function public.digest(text, text) from public;
revoke all on function public.digest(text, text) from anon;
revoke all on function public.digest(text, text) from authenticated;

commit;
