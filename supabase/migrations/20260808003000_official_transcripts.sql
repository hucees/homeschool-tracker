-- Homeschool Tracker
-- Migration 013: Official transcript snapshots
--
-- Adds a permanent integrity hash and an instructor-only function for issuing
-- official transcripts. Student RLS from Migration 002 already permits students
-- to read only their own transcript snapshots when status = 'official'.

begin;

alter table public.transcript_snapshots
  add column if not exists snapshot_sha256 text;

create or replace function private.protect_transcript_snapshot_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    if old.status in ('official', 'voided') then
      raise exception 'Official or voided transcript snapshots cannot be deleted';
    end if;
    return old;
  end if;

  if old.status = 'official' then
    if new.status = 'voided'
       and (to_jsonb(new) - 'status') = (to_jsonb(old) - 'status') then
      return new;
    end if;

    raise exception 'Official transcript snapshots are immutable';
  end if;

  if old.status = 'voided' then
    raise exception 'Voided transcript snapshots are immutable';
  end if;

  return new;
end;
$$;

drop trigger if exists protect_transcript_snapshot_history on public.transcript_snapshots;
create trigger protect_transcript_snapshot_history
  before update or delete on public.transcript_snapshots
  for each row execute function private.protect_transcript_snapshot_history();

create or replace function public.create_official_transcript(
  p_student_id uuid,
  p_snapshot_data jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_organization_id uuid;
  v_version integer;
  v_transcript_id uuid;
  v_hash text;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if p_snapshot_data is null or jsonb_typeof(p_snapshot_data) <> 'object' then
    raise exception 'Transcript snapshot data must be a JSON object.' using errcode = '22023';
  end if;

  -- Lock the student row so two simultaneous issue attempts cannot choose the
  -- same transcript version number.
  select s.organization_id
  into v_organization_id
  from public.students s
  where s.id = p_student_id
  for update;

  if not found then
    raise exception 'Student was not found.' using errcode = '22023';
  end if;

  if not private.is_org_staff(v_organization_id) then
    raise exception 'Instructor access is required.' using errcode = '42501';
  end if;

  if coalesce(p_snapshot_data #>> '{student,id}', '') <> p_student_id::text
     or coalesce(p_snapshot_data #>> '{organization,id}', '') <> v_organization_id::text then
    raise exception 'Snapshot identity does not match the requested student record.'
      using errcode = '22023';
  end if;

  select coalesce(max(t.version), 0) + 1
  into v_version
  from public.transcript_snapshots t
  where t.student_id = p_student_id;

  v_hash := encode(public.digest(p_snapshot_data::text, 'sha256'), 'hex');

  perform set_config('app.audit_reason', 'Official transcript issued by instructor', true);

  insert into public.transcript_snapshots (
    organization_id,
    student_id,
    version,
    status,
    snapshot_data,
    snapshot_sha256,
    generated_by,
    generated_at
  )
  values (
    v_organization_id,
    p_student_id,
    v_version,
    'official',
    p_snapshot_data,
    v_hash,
    v_user_id,
    now()
  )
  returning id into v_transcript_id;

  return v_transcript_id;
end;
$$;

revoke all on function public.create_official_transcript(uuid, jsonb) from public;
grant execute on function public.create_official_transcript(uuid, jsonb) to authenticated;

commit;
