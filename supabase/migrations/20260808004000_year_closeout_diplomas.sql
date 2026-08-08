-- Homeschool Tracker
-- Migration 014: Academic-year closeout, official grade decisions, and diplomas

begin;

alter table public.grade_level_decisions
  add column if not exists next_student_academic_year_id uuid
    references public.student_academic_years(id),
  add column if not exists closeout_snapshot jsonb not null default '{}'::jsonb;

create unique index if not exists grade_level_decisions_one_per_placement_uq
  on public.grade_level_decisions (student_academic_year_id);

create or replace function private.protect_grade_level_decision_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Grade-level decisions are immutable permanent records';
end;
$$;

drop trigger if exists protect_grade_level_decision_history on public.grade_level_decisions;
create trigger protect_grade_level_decision_history
  before update or delete on public.grade_level_decisions
  for each row execute function private.protect_grade_level_decision_history();

create table if not exists public.diploma_snapshots (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  version integer not null check (version > 0),
  diploma_number text not null,
  status text not null default 'official'
    check (status in ('official', 'voided')),
  graduation_date date not null,
  issue_date date not null,
  snapshot_data jsonb not null,
  snapshot_sha256 text not null,
  issued_by uuid references public.profiles(id) on delete set null,
  issued_at timestamptz not null default now(),
  unique (student_id, version),
  unique (organization_id, diploma_number)
);

alter table public.diploma_snapshots enable row level security;
grant select on public.diploma_snapshots to authenticated;
grant all on public.diploma_snapshots to service_role;

create policy diploma_snapshots_select
on public.diploma_snapshots for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or (
    private.is_student_self(organization_id, student_id)
    and status = 'official'
  )
);

create or replace function private.protect_diploma_snapshot_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Diploma records cannot be deleted';
  end if;

  if old.status = 'official'
     and new.status = 'voided'
     and (to_jsonb(new) - 'status') = (to_jsonb(old) - 'status') then
    return new;
  end if;

  raise exception 'Official or voided diploma records are immutable';
end;
$$;

drop trigger if exists protect_diploma_snapshot_history on public.diploma_snapshots;
create trigger protect_diploma_snapshot_history
  before update or delete on public.diploma_snapshots
  for each row execute function private.protect_diploma_snapshot_history();

drop trigger if exists audit_diploma_snapshots on public.diploma_snapshots;
create trigger audit_diploma_snapshots
  after insert or update or delete on public.diploma_snapshots
  for each row execute function private.audit_row_change();

create or replace function public.close_student_academic_year(
  p_student_academic_year_id uuid,
  p_close_date date,
  p_decision text,
  p_next_academic_year_id uuid default null,
  p_next_academic_year_name text default null,
  p_next_year_start date default null,
  p_next_year_end date default null,
  p_next_grade_level_id uuid default null,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_placement public.student_academic_years%rowtype;
  v_current_year public.academic_years%rowtype;
  v_current_grade public.grade_levels%rowtype;
  v_next_grade public.grade_levels%rowtype;
  v_next_year public.academic_years%rowtype;
  v_next_placement_id uuid;
  v_decision_id uuid;
  v_snapshot jsonb;
  v_course record;
  v_target_enrollment_id uuid;
  v_next_attempt integer;
  v_unfinished integer := 0;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if p_decision not in ('promote', 'retain', 'graduate', 'continue', 'instructor_override') then
    raise exception 'Unsupported academic-year decision.' using errcode = '22023';
  end if;

  select * into v_placement
  from public.student_academic_years say
  where say.id = p_student_academic_year_id
  for update;

  if not found then
    raise exception 'Academic-year placement was not found.' using errcode = '22023';
  end if;

  if not private.is_org_staff(v_placement.organization_id) then
    raise exception 'Instructor access is required.' using errcode = '42501';
  end if;

  if v_placement.status <> 'active' then
    raise exception 'Only an active academic-year placement can be closed.' using errcode = '22023';
  end if;

  if exists (
    select 1 from public.grade_level_decisions g
    where g.student_academic_year_id = v_placement.id
  ) then
    raise exception 'This academic year already has a permanent closeout decision.' using errcode = '23505';
  end if;

  select * into v_current_year
  from public.academic_years ay
  where ay.id = v_placement.academic_year_id;

  select * into v_current_grade
  from public.grade_levels gl
  where gl.id = v_placement.official_grade_level_id;

  if p_close_date is null
     or p_close_date < v_placement.start_date
     or p_close_date > v_current_year.end_date then
    raise exception 'Closeout date must fall within the academic year.' using errcode = '22023';
  end if;

  select count(*)::integer into v_unfinished
  from public.student_course_enrollments e
  where e.student_academic_year_id = v_placement.id
    and e.status in ('active', 'planned');

  if p_decision = 'graduate' then
    if v_unfinished > 0 then
      raise exception 'Graduate closeout requires all active/planned course enrollments to be resolved first.' using errcode = '22023';
    end if;

    v_next_placement_id := null;
  else
    if p_decision = 'promote' then
      select * into v_next_grade
      from public.grade_levels gl
      where gl.numeric_order = v_current_grade.numeric_order + 1
        and gl.active = true;

      if not found then
        raise exception 'No next official grade level is configured.' using errcode = '22023';
      end if;

      if p_next_grade_level_id is not null and p_next_grade_level_id <> v_next_grade.id then
        raise exception 'Promote must use the next official grade level.' using errcode = '22023';
      end if;
    elsif p_decision in ('retain', 'continue') then
      v_next_grade := v_current_grade;

      if p_next_grade_level_id is not null and p_next_grade_level_id <> v_current_grade.id then
        raise exception 'Retain/continue must keep the same official grade level.' using errcode = '22023';
      end if;
    else
      if p_next_grade_level_id is null then
        raise exception 'Instructor override requires a target official grade level.' using errcode = '22023';
      end if;

      if nullif(btrim(coalesce(p_reason, '')), '') is null then
        raise exception 'Instructor override requires a reason.' using errcode = '22023';
      end if;

      select * into v_next_grade
      from public.grade_levels gl
      where gl.id = p_next_grade_level_id and gl.active = true;

      if not found then
        raise exception 'Target official grade level is not available.' using errcode = '22023';
      end if;
    end if;

    if p_next_academic_year_id is not null then
      select * into v_next_year
      from public.academic_years ay
      where ay.id = p_next_academic_year_id
        and ay.organization_id = v_placement.organization_id
        and ay.status in ('planned', 'active');

      if not found then
        raise exception 'Selected next academic year is not available.' using errcode = '22023';
      end if;
    else
      if nullif(btrim(coalesce(p_next_academic_year_name, '')), '') is null
         or p_next_year_start is null
         or p_next_year_end is null then
        raise exception 'Choose an existing next academic year or provide a new year name and dates.' using errcode = '22023';
      end if;

      if p_next_year_end < p_next_year_start then
        raise exception 'Next academic-year end date cannot be before its start date.' using errcode = '22023';
      end if;

      select * into v_next_year
      from public.academic_years ay
      where ay.organization_id = v_placement.organization_id
        and ay.name = btrim(p_next_academic_year_name);

      if found then
        if v_next_year.start_date <> p_next_year_start
           or v_next_year.end_date <> p_next_year_end
           or v_next_year.status not in ('planned', 'active') then
          raise exception 'An academic year with that name already exists with different dates or status.' using errcode = '22023';
        end if;
      else
        insert into public.academic_years (
          organization_id, name, start_date, end_date, status
        ) values (
          v_placement.organization_id,
          btrim(p_next_academic_year_name),
          p_next_year_start,
          p_next_year_end,
          case when p_next_year_start <= current_date then 'active' else 'planned' end
        ) returning * into v_next_year;
      end if;
    end if;

    if v_next_year.start_date <= p_close_date then
      raise exception 'The next academic year must start after the current closeout date.' using errcode = '22023';
    end if;

    if exists (
      select 1 from public.student_academic_years say
      where say.student_id = v_placement.student_id
        and say.academic_year_id = v_next_year.id
    ) then
      raise exception 'The student already has a placement for the selected next academic year.' using errcode = '23505';
    end if;

    insert into public.student_academic_years (
      organization_id, student_id, academic_year_id, official_grade_level_id,
      status, start_date, end_date
    ) values (
      v_placement.organization_id,
      v_placement.student_id,
      v_next_year.id,
      v_next_grade.id,
      case when v_next_year.start_date <= current_date then 'active' else 'planned' end,
      v_next_year.start_date,
      null
    ) returning id into v_next_placement_id;
  end if;

  v_snapshot := jsonb_build_object(
    'schema_version', 1,
    'student_academic_year_id', v_placement.id,
    'academic_year_id', v_current_year.id,
    'academic_year_name', v_current_year.name,
    'official_grade_level_id', v_current_grade.id,
    'official_grade_code', v_current_grade.code,
    'official_grade_name', v_current_grade.name,
    'close_date', p_close_date,
    'decision', p_decision,
    'next_grade_level_id', case when p_decision = 'graduate' then null else v_next_grade.id end,
    'next_grade_code', case when p_decision = 'graduate' then null else v_next_grade.code end,
    'next_grade_name', case when p_decision = 'graduate' then null else v_next_grade.name end,
    'next_academic_year_id', case when p_decision = 'graduate' then null else v_next_year.id end,
    'next_academic_year_name', case when p_decision = 'graduate' then null else v_next_year.name end,
    'attendance', jsonb_build_object(
      'present_days', (select count(*) from public.attendance_records a where a.student_academic_year_id = v_placement.id and a.teacher_confirmed = true and a.status = 'present'),
      'partial_days', (select count(*) from public.attendance_records a where a.student_academic_year_id = v_placement.id and a.teacher_confirmed = true and a.status = 'partial'),
      'absent_days', (select count(*) from public.attendance_records a where a.student_academic_year_id = v_placement.id and a.teacher_confirmed = true and a.status = 'absent'),
      'instructional_minutes', (select coalesce(sum(a.instructional_minutes), 0) from public.attendance_records a where a.student_academic_year_id = v_placement.id and a.teacher_confirmed = true)
    ),
    'course_counts', jsonb_build_object(
      'completed', (select count(*) from public.student_course_enrollments e where e.student_academic_year_id = v_placement.id and e.status = 'completed'),
      'continued', v_unfinished
    ),
    'official_reports', (select count(*) from public.report_snapshots r where r.student_id = v_placement.student_id and r.academic_year_id = v_current_year.id and r.status = 'official')
  );

  perform set_config('app.audit_reason', 'Academic-year closeout recorded by instructor', true);

  insert into public.grade_level_decisions (
    organization_id, student_id, student_academic_year_id,
    current_grade_level_id, next_grade_level_id, decision, reason,
    decided_by, next_student_academic_year_id, closeout_snapshot
  ) values (
    v_placement.organization_id,
    v_placement.student_id,
    v_placement.id,
    v_current_grade.id,
    case when p_decision = 'graduate' then null else v_next_grade.id end,
    p_decision,
    nullif(btrim(coalesce(p_reason, '')), ''),
    v_user_id,
    v_next_placement_id,
    v_snapshot
  ) returning id into v_decision_id;

  if p_decision <> 'graduate' then
    for v_course in
      select * from public.student_course_enrollments e
      where e.student_academic_year_id = v_placement.id
        and e.status in ('active', 'planned')
      order by e.start_date, e.created_at
    loop
      select coalesce(max(e.attempt_number), 0) + 1 into v_next_attempt
      from public.student_course_enrollments e
      where e.student_academic_year_id = v_next_placement_id
        and e.course_version_id = v_course.course_version_id;

      insert into public.student_course_enrollments (
        organization_id, student_id, student_academic_year_id, course_version_id,
        academic_term_id, attempt_number, status, start_date, assigned_by
      ) values (
        v_course.organization_id,
        v_course.student_id,
        v_next_placement_id,
        v_course.course_version_id,
        null,
        v_next_attempt,
        case when v_next_year.start_date <= current_date then 'active' else 'planned' end,
        v_next_year.start_date,
        v_user_id
      ) returning id into v_target_enrollment_id;

      update public.student_course_enrollments
      set status = case when v_course.status = 'active' then 'continued' else 'superseded' end,
          end_date = p_close_date
      where id = v_course.id;

      if not exists (
        select 1 from public.progression_decisions pd
        where pd.source_enrollment_id = v_course.id
      ) then
        insert into public.progression_decisions (
          organization_id, student_id, source_enrollment_id, decision,
          target_course_version_id, target_enrollment_id, reason, decided_by
        ) values (
          v_course.organization_id,
          v_course.student_id,
          v_course.id,
          'continue',
          v_course.course_version_id,
          v_target_enrollment_id,
          'Carried forward during academic-year closeout',
          v_user_id
        );
      end if;
    end loop;
  end if;

  update public.student_academic_years
  set status = 'completed', end_date = p_close_date, completed_at = now()
  where id = v_placement.id;

  if p_decision = 'graduate' then
    update public.students
    set status = 'graduated', graduation_date = p_close_date
    where id = v_placement.student_id;
  end if;

  return v_decision_id;
end;
$$;

revoke all on function public.close_student_academic_year(uuid, date, text, uuid, text, date, date, uuid, text) from public;
grant execute on function public.close_student_academic_year(uuid, date, text, uuid, text, date, date, uuid, text) to authenticated;

create or replace function public.issue_homeschool_diploma(
  p_student_id uuid,
  p_graduation_date date,
  p_issue_date date,
  p_snapshot_data jsonb,
  p_mark_graduated boolean default true
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
  v_diploma_id uuid;
  v_diploma_number text;
  v_final_snapshot jsonb;
  v_hash text;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if p_graduation_date is null or p_issue_date is null then
    raise exception 'Graduation date and issue date are required.' using errcode = '22023';
  end if;

  if p_snapshot_data is null or jsonb_typeof(p_snapshot_data) <> 'object' then
    raise exception 'Diploma snapshot data must be a JSON object.' using errcode = '22023';
  end if;

  select s.organization_id into v_organization_id
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
    raise exception 'Diploma snapshot identity does not match the requested student.' using errcode = '22023';
  end if;

  select coalesce(max(d.version), 0) + 1 into v_version
  from public.diploma_snapshots d
  where d.student_id = p_student_id;

  v_diploma_number :=
    'HSD-' ||
    extract(year from p_issue_date)::integer::text ||
    '-' ||
    upper(substr(md5(clock_timestamp()::text || p_student_id::text || v_version::text), 1, 8));

  v_final_snapshot := p_snapshot_data || jsonb_build_object(
    'diploma_number', v_diploma_number,
    'version', v_version,
    'graduation_date', p_graduation_date,
    'issue_date', p_issue_date,
    'issued_at', now()
  );

  v_hash := encode(public.digest(v_final_snapshot::text, 'sha256'), 'hex');

  perform set_config('app.audit_reason', 'Official homeschool diploma issued by administrator', true);

  insert into public.diploma_snapshots (
    organization_id, student_id, version, diploma_number, status,
    graduation_date, issue_date, snapshot_data, snapshot_sha256,
    issued_by, issued_at
  ) values (
    v_organization_id,
    p_student_id,
    v_version,
    v_diploma_number,
    'official',
    p_graduation_date,
    p_issue_date,
    v_final_snapshot,
    v_hash,
    v_user_id,
    now()
  ) returning id into v_diploma_id;

  if p_mark_graduated then
    update public.students
    set status = 'graduated', graduation_date = p_graduation_date
    where id = p_student_id;
  end if;

  return v_diploma_id;
end;
$$;

revoke all on function public.issue_homeschool_diploma(uuid, date, date, jsonb, boolean) from public;
grant execute on function public.issue_homeschool_diploma(uuid, date, date, jsonb, boolean) to authenticated;

commit;
