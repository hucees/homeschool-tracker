-- Homeschool Tracker
-- Migration 002: Security, RLS, history protection, audit triggers
-- Target: Supabase PostgreSQL

begin;

-- Keep helper functions out of the exposed public API schema.
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- UPDATED_AT SUPPORT
-- -----------------------------------------------------------------------------

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles',
    'organizations',
    'organization_members',
    'grade_levels',
    'subjects',
    'academic_years',
    'academic_terms',
    'school_calendar_days',
    'students',
    'student_user_links',
    'student_academic_years',
    'curriculum_releases',
    'courses',
    'course_versions',
    'units',
    'competencies',
    'lessons',
    'assignment_templates',
    'student_course_enrollments',
    'daily_assignments',
    'student_daily_records',
    'daily_record_reviews',
    'daily_learning_entries',
    'attendance_records',
    'student_assignments',
    'assignment_submissions',
    'student_notes'
  ]
  loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function private.set_updated_at()',
      'set_' || t || '_updated_at',
      t
    );
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- PROFILE CREATION FOR SUPABASE AUTH USERS
-- Authorization must never depend on user_metadata. It is used here only for
-- display names; actual permissions live in organization_members and
-- student_user_links.
-- -----------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, first_name, last_name, display_name)
  values (
    new.id,
    nullif(new.raw_user_meta_data ->> 'first_name', ''),
    nullif(new.raw_user_meta_data ->> 'last_name', ''),
    coalesce(
      nullif(new.raw_user_meta_data ->> 'display_name', ''),
      nullif(trim(concat_ws(' ', new.raw_user_meta_data ->> 'first_name', new.raw_user_meta_data ->> 'last_name')), ''),
      split_part(coalesce(new.email, new.id::text), '@', 1)
    )
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill a profile row for any Auth users that existed before this migration.
insert into public.profiles (id, display_name)
select
  u.id,
  coalesce(
    nullif(u.raw_user_meta_data ->> 'display_name', ''),
    split_part(coalesce(u.email, u.id::text), '@', 1)
  )
from auth.users u
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- RLS HELPER FUNCTIONS
-- These are SECURITY DEFINER so policy checks can safely query membership tables
-- without causing recursive RLS evaluation.
-- -----------------------------------------------------------------------------

create or replace function private.is_org_user(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and (
      exists (
        select 1
        from public.organization_members m
        where m.organization_id = p_organization_id
          and m.profile_id = (select auth.uid())
          and m.status = 'active'
      )
      or exists (
        select 1
        from public.student_user_links l
        where l.organization_id = p_organization_id
          and l.profile_id = (select auth.uid())
          and l.is_active = true
      )
    );
$$;

create or replace function private.is_org_staff(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and exists (
      select 1
      from public.organization_members m
      where m.organization_id = p_organization_id
        and m.profile_id = (select auth.uid())
        and m.status = 'active'
        and m.role in ('owner', 'administrator', 'instructor')
    );
$$;

create or replace function private.is_org_admin(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and exists (
      select 1
      from public.organization_members m
      where m.organization_id = p_organization_id
        and m.profile_id = (select auth.uid())
        and m.status = 'active'
        and m.role in ('owner', 'administrator')
    );
$$;

create or replace function private.org_has_no_members(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1
    from public.organization_members m
    where m.organization_id = p_organization_id
  );
$$;

create or replace function private.is_student_self(p_organization_id uuid, p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and exists (
      select 1
      from public.student_user_links l
      where l.organization_id = p_organization_id
        and l.student_id = p_student_id
        and l.profile_id = (select auth.uid())
        and l.is_active = true
    );
$$;

create or replace function private.staff_can_view_profile(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members me
    where me.profile_id = (select auth.uid())
      and me.status = 'active'
      and me.role in ('owner', 'administrator', 'instructor')
      and (
        exists (
          select 1
          from public.organization_members target_member
          where target_member.organization_id = me.organization_id
            and target_member.profile_id = p_profile_id
        )
        or exists (
          select 1
          from public.student_user_links target_student
          where target_student.organization_id = me.organization_id
            and target_student.profile_id = p_profile_id
        )
      )
  );
$$;

create or replace function private.student_academic_year_belongs_to(
  p_record_id uuid,
  p_organization_id uuid,
  p_student_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.student_academic_years y
    where y.id = p_record_id
      and y.organization_id = p_organization_id
      and y.student_id = p_student_id
  );
$$;

create or replace function private.course_enrollment_belongs_to(
  p_enrollment_id uuid,
  p_organization_id uuid,
  p_student_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.student_course_enrollments e
    where e.id = p_enrollment_id
      and e.organization_id = p_organization_id
      and e.student_id = p_student_id
  );
$$;

create or replace function private.daily_record_belongs_to(
  p_daily_record_id uuid,
  p_organization_id uuid,
  p_student_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.student_daily_records d
    where d.id = p_daily_record_id
      and d.organization_id = p_organization_id
      and d.student_id = p_student_id
  );
$$;

create or replace function private.student_assignment_belongs_to(
  p_assignment_id uuid,
  p_organization_id uuid,
  p_student_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.student_assignments a
    where a.id = p_assignment_id
      and a.organization_id = p_organization_id
      and a.student_id = p_student_id
  );
$$;

grant execute on all functions in schema private to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- PUBLISHED CURRICULUM IMMUTABILITY
-- Once a curriculum release is published, descendants cannot be inserted,
-- edited, or deleted. New curriculum work must happen in a new draft release.
-- -----------------------------------------------------------------------------

create or replace function private.assert_release_editable(p_release_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  select r.status into v_status
  from public.curriculum_releases r
  where r.id = p_release_id;

  if v_status is null then
    raise exception 'Curriculum release % does not exist', p_release_id;
  end if;

  if v_status <> 'draft' then
    raise exception 'Curriculum release % is locked because its status is %', p_release_id, v_status;
  end if;
end;
$$;

create or replace function private.guard_curriculum_release()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    if old.status in ('published', 'retired') then
      raise exception 'Published or retired curriculum releases cannot be deleted';
    end if;
    return old;
  end if;

  if old.status = 'draft' and new.status = 'published' then
    new.published_at = coalesce(new.published_at, now());
    new.locked_at = coalesce(new.locked_at, now());
    return new;
  end if;

  if old.status = 'published' then
    if new.status = 'retired'
       and (to_jsonb(new) - 'status' - 'updated_at') = (to_jsonb(old) - 'status' - 'updated_at') then
      return new;
    end if;

    raise exception 'Published curriculum releases are immutable; create a new release instead';
  end if;

  if old.status = 'retired' then
    raise exception 'Retired curriculum releases are immutable';
  end if;

  return new;
end;
$$;

create trigger guard_curriculum_release
  before update or delete on public.curriculum_releases
  for each row execute function private.guard_curriculum_release();

create or replace function private.guard_course_version_edit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform private.assert_release_editable(new.curriculum_release_id);
    return new;
  end if;

  if tg_op = 'DELETE' then
    perform private.assert_release_editable(old.curriculum_release_id);
    return old;
  end if;

  -- UPDATE: both the old and new release must be editable. This prevents a
  -- locked course version from being moved into a draft release and edited.
  perform private.assert_release_editable(old.curriculum_release_id);
  if new.curriculum_release_id is distinct from old.curriculum_release_id then
    perform private.assert_release_editable(new.curriculum_release_id);
  end if;
  return new;
end;
$$;

create trigger guard_course_versions
  before insert or update or delete on public.course_versions
  for each row execute function private.guard_course_version_edit();

create or replace function private.guard_course_child_edit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_release_id uuid;
  v_new_release_id uuid;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    select cv.curriculum_release_id into v_old_release_id
    from public.course_versions cv
    where cv.id = old.course_version_id;
    perform private.assert_release_editable(v_old_release_id);
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    select cv.curriculum_release_id into v_new_release_id
    from public.course_versions cv
    where cv.id = new.course_version_id;
    perform private.assert_release_editable(v_new_release_id);
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array['units', 'competencies', 'lessons', 'assignment_templates']
  loop
    execute format(
      'create trigger %I before insert or update or delete on public.%I for each row execute function private.guard_course_child_edit()',
      'guard_' || t,
      t
    );
  end loop;
end;
$$;

create or replace function private.guard_lesson_competency_edit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_release_id uuid;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    select cv.curriculum_release_id into v_release_id
    from public.lessons l
    join public.course_versions cv on cv.id = l.course_version_id
    where l.id = old.lesson_id;
    perform private.assert_release_editable(v_release_id);
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    select cv.curriculum_release_id into v_release_id
    from public.lessons l
    join public.course_versions cv on cv.id = l.course_version_id
    where l.id = new.lesson_id;
    perform private.assert_release_editable(v_release_id);
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger guard_lesson_competencies
  before insert or update or delete on public.lesson_competencies
  for each row execute function private.guard_lesson_competency_edit();

create or replace function private.guard_assignment_template_competency_edit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_release_id uuid;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    select cv.curriculum_release_id into v_release_id
    from public.assignment_templates a
    join public.course_versions cv on cv.id = a.course_version_id
    where a.id = old.assignment_template_id;
    perform private.assert_release_editable(v_release_id);
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    select cv.curriculum_release_id into v_release_id
    from public.assignment_templates a
    join public.course_versions cv on cv.id = a.course_version_id
    where a.id = new.assignment_template_id;
    perform private.assert_release_editable(v_release_id);
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger guard_assignment_template_competencies
  before insert or update or delete on public.assignment_template_competencies
  for each row execute function private.guard_assignment_template_competency_edit();

-- -----------------------------------------------------------------------------
-- PERMANENT RECORD IDENTITY PROTECTION
-- A student may update the contents/status of their daily record, but cannot
-- move that record to another student, academic year, or date after creation.
-- -----------------------------------------------------------------------------

create or replace function private.protect_daily_record_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.organization_id <> old.organization_id
     or new.student_id <> old.student_id
     or new.student_academic_year_id <> old.student_academic_year_id
     or new.record_date <> old.record_date then
    raise exception 'Daily record identity fields are immutable';
  end if;
  return new;
end;
$$;

create trigger protect_student_daily_record_identity
  before update on public.student_daily_records
  for each row execute function private.protect_daily_record_identity();

create or replace function private.protect_daily_learning_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.organization_id <> old.organization_id
     or new.student_id <> old.student_id
     or new.daily_record_id <> old.daily_record_id
     or new.student_course_enrollment_id <> old.student_course_enrollment_id
     or new.daily_assignment_id is distinct from old.daily_assignment_id
     or new.lesson_id is distinct from old.lesson_id then
    raise exception 'Daily learning entry identity fields are immutable';
  end if;
  return new;
end;
$$;

create trigger protect_daily_learning_entry_identity
  before update on public.daily_learning_entries
  for each row execute function private.protect_daily_learning_identity();

create or replace function private.protect_submission_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.organization_id <> old.organization_id
     or new.student_id <> old.student_id
     or new.student_assignment_id <> old.student_assignment_id
     or new.attempt_number <> old.attempt_number then
    raise exception 'Assignment submission identity fields are immutable';
  end if;
  return new;
end;
$$;

create trigger protect_assignment_submission_identity
  before update on public.assignment_submissions
  for each row execute function private.protect_submission_identity();

-- Grade rows are append-oriented. A correction creates a new revision. The old
-- row may only transition from current -> superseded/voided.
create or replace function private.protect_grade_record_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status = 'current'
     and new.status in ('superseded', 'voided')
     and (to_jsonb(new) - 'status') = (to_jsonb(old) - 'status') then
    return new;
  end if;

  raise exception 'Grade records are append-only; create a new revision instead of editing the prior grade';
end;
$$;

create trigger protect_grade_record_history
  before update on public.grade_records
  for each row execute function private.protect_grade_record_history();

-- -----------------------------------------------------------------------------
-- AUDITING
-- -----------------------------------------------------------------------------

create or replace function private.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_entity_id uuid;
  v_reason text;
begin
  if tg_op = 'DELETE' then
    v_org := old.organization_id;
    v_entity_id := old.id;
  else
    v_org := new.organization_id;
    v_entity_id := new.id;
  end if;

  v_reason := nullif(current_setting('app.audit_reason', true), '');

  insert into public.audit_log (
    organization_id,
    actor_user_id,
    entity_type,
    entity_id,
    action,
    old_values,
    new_values,
    reason
  )
  values (
    v_org,
    (select auth.uid()),
    tg_table_name,
    v_entity_id,
    lower(tg_op),
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end,
    v_reason
  );

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'students',
    'student_user_links',
    'student_academic_years',
    'student_course_enrollments',
    'daily_assignments',
    'student_daily_records',
    'daily_record_reviews',
    'daily_learning_entries',
    'attendance_records',
    'student_assignments',
    'assignment_submissions',
    'grade_records',
    'competency_evidence',
    'student_notes',
    'course_completion_records',
    'progression_decisions',
    'grade_level_decisions',
    'report_snapshots',
    'transcript_snapshots'
  ]
  loop
    execute format(
      'create trigger %I after insert or update or delete on public.%I for each row execute function private.audit_row_change()',
      'audit_' || t,
      t
    );
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- PRIVILEGES
-- RLS remains the final authority for authenticated users.
-- -----------------------------------------------------------------------------

revoke all on all tables in schema public from anon;

grant usage on schema public to authenticated, service_role;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant all on all tables in schema public to service_role;

-- Authenticated clients must never directly write the audit log.
revoke insert, update, delete on public.audit_log from authenticated;

-- -----------------------------------------------------------------------------
-- ENABLE ROW LEVEL SECURITY
-- -----------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles',
    'organizations',
    'organization_members',
    'grade_levels',
    'subjects',
    'academic_years',
    'academic_terms',
    'school_calendar_days',
    'students',
    'student_user_links',
    'student_academic_years',
    'curriculum_releases',
    'courses',
    'course_versions',
    'units',
    'competencies',
    'lessons',
    'lesson_competencies',
    'assignment_templates',
    'assignment_template_competencies',
    'student_course_enrollments',
    'daily_assignments',
    'student_daily_records',
    'daily_record_reviews',
    'daily_learning_entries',
    'attendance_records',
    'student_assignments',
    'assignment_submissions',
    'grade_records',
    'competency_evidence',
    'student_notes',
    'course_completion_records',
    'progression_decisions',
    'grade_level_decisions',
    'report_snapshots',
    'transcript_snapshots',
    'student_files',
    'audit_log'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- PROFILE / ORGANIZATION POLICIES
-- -----------------------------------------------------------------------------

create policy profiles_select
on public.profiles for select
to authenticated
using (
  id = (select auth.uid())
  or private.staff_can_view_profile(id)
);

create policy profiles_update_self
on public.profiles for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

create policy organizations_select
on public.organizations for select
to authenticated
using (private.is_org_user(id) or created_by = (select auth.uid()));

create policy organizations_insert
on public.organizations for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and created_by = (select auth.uid())
);

create policy organizations_update
on public.organizations for update
to authenticated
using (private.is_org_admin(id))
with check (private.is_org_admin(id));

create policy organization_members_select
on public.organization_members for select
to authenticated
using (
  profile_id = (select auth.uid())
  or private.is_org_staff(organization_id)
);

create policy organization_members_insert
on public.organization_members for insert
to authenticated
with check (
  private.is_org_admin(organization_id)
  or (
    private.is_org_staff(organization_id)
    and role in ('student', 'guardian')
  )
  or (
    profile_id = (select auth.uid())
    and role = 'owner'
    and private.org_has_no_members(organization_id)
  )
);

create policy organization_members_update
on public.organization_members for update
to authenticated
using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));

create policy organization_members_delete
on public.organization_members for delete
to authenticated
using (private.is_org_admin(organization_id));

-- Global reference tables are read-only to normal authenticated users.
create policy grade_levels_select
on public.grade_levels for select
to authenticated
using (true);

create policy subjects_select
on public.subjects for select
to authenticated
using (true);

-- -----------------------------------------------------------------------------
-- ORGANIZATION-WIDE CONFIG / CURRICULUM POLICIES
-- All authenticated users attached to an organization can read these rows.
-- Staff can create/update/delete draft/configuration rows. Published curriculum
-- deletion/update is additionally blocked by the immutability triggers above.
-- -----------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'academic_years',
    'academic_terms',
    'school_calendar_days',
    'curriculum_releases',
    'courses',
    'course_versions',
    'units',
    'competencies',
    'lessons',
    'lesson_competencies',
    'assignment_templates',
    'assignment_template_competencies'
  ]
  loop
    execute format(
      'create policy %I on public.%I for select to authenticated using (private.is_org_user(organization_id))',
      t || '_select', t
    );

    execute format(
      'create policy %I on public.%I for insert to authenticated with check (private.is_org_staff(organization_id))',
      t || '_insert', t
    );

    execute format(
      'create policy %I on public.%I for update to authenticated using (private.is_org_staff(organization_id)) with check (private.is_org_staff(organization_id))',
      t || '_update', t
    );

    execute format(
      'create policy %I on public.%I for delete to authenticated using (private.is_org_staff(organization_id))',
      t || '_delete', t
    );
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- STUDENT IDENTITY / PLACEMENT
-- -----------------------------------------------------------------------------

create policy students_select
on public.students for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, id)
);

create policy students_insert
on public.students for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy students_update
on public.students for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

create policy student_user_links_select
on public.student_user_links for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or profile_id = (select auth.uid())
);

create policy student_user_links_insert
on public.student_user_links for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy student_user_links_update
on public.student_user_links for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

create policy student_academic_years_select
on public.student_academic_years for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy student_academic_years_insert
on public.student_academic_years for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy student_academic_years_update
on public.student_academic_years for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

create policy student_course_enrollments_select
on public.student_course_enrollments for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy student_course_enrollments_insert
on public.student_course_enrollments for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy student_course_enrollments_update
on public.student_course_enrollments for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

-- -----------------------------------------------------------------------------
-- DAILY PLAN / DAILY LEARNING
-- -----------------------------------------------------------------------------

create policy daily_assignments_select
on public.daily_assignments for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy daily_assignments_insert
on public.daily_assignments for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy daily_assignments_update
on public.daily_assignments for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

create policy student_daily_records_select
on public.student_daily_records for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy student_daily_records_insert
on public.student_daily_records for insert
to authenticated
with check (
  private.is_org_staff(organization_id)
  or (
    private.is_student_self(organization_id, student_id)
    and private.student_academic_year_belongs_to(student_academic_year_id, organization_id, student_id)
  )
);

create policy student_daily_records_update
on public.student_daily_records for update
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
)
with check (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy daily_record_reviews_select
on public.daily_record_reviews for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy daily_record_reviews_insert
on public.daily_record_reviews for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy daily_record_reviews_update
on public.daily_record_reviews for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

create policy daily_learning_entries_select
on public.daily_learning_entries for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy daily_learning_entries_insert
on public.daily_learning_entries for insert
to authenticated
with check (
  private.is_org_staff(organization_id)
  or (
    private.is_student_self(organization_id, student_id)
    and private.daily_record_belongs_to(daily_record_id, organization_id, student_id)
    and private.course_enrollment_belongs_to(student_course_enrollment_id, organization_id, student_id)
  )
);

create policy daily_learning_entries_update
on public.daily_learning_entries for update
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
)
with check (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

-- -----------------------------------------------------------------------------
-- ATTENDANCE: student read-only, staff write
-- -----------------------------------------------------------------------------

create policy attendance_records_select
on public.attendance_records for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy attendance_records_insert
on public.attendance_records for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy attendance_records_update
on public.attendance_records for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

-- -----------------------------------------------------------------------------
-- ASSIGNMENTS / SUBMISSIONS / GRADES
-- -----------------------------------------------------------------------------

create policy student_assignments_select
on public.student_assignments for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy student_assignments_insert
on public.student_assignments for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy student_assignments_update
on public.student_assignments for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

create policy assignment_submissions_select
on public.assignment_submissions for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy assignment_submissions_insert
on public.assignment_submissions for insert
to authenticated
with check (
  private.is_org_staff(organization_id)
  or (
    private.is_student_self(organization_id, student_id)
    and private.student_assignment_belongs_to(student_assignment_id, organization_id, student_id)
  )
);

create policy assignment_submissions_update_staff
on public.assignment_submissions for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

create policy grade_records_select
on public.grade_records for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy grade_records_insert
on public.grade_records for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy grade_records_update
on public.grade_records for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

-- -----------------------------------------------------------------------------
-- COMPETENCY EVIDENCE: student read-only, staff write
-- -----------------------------------------------------------------------------

create policy competency_evidence_select
on public.competency_evidence for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy competency_evidence_insert
on public.competency_evidence for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy competency_evidence_update
on public.competency_evidence for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

-- -----------------------------------------------------------------------------
-- NOTES
-- Instructor-only notes are never visible to student accounts.
-- -----------------------------------------------------------------------------

create policy student_notes_select
on public.student_notes for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or (
    private.is_student_self(organization_id, student_id)
    and visibility = 'student_and_teacher'
  )
);

create policy student_notes_insert
on public.student_notes for insert
to authenticated
with check (
  private.is_org_staff(organization_id)
  or (
    private.is_student_self(organization_id, student_id)
    and author_profile_id = (select auth.uid())
    and visibility = 'student_and_teacher'
    and note_type in ('student_daily', 'general', 'academic')
  )
);

create policy student_notes_update
on public.student_notes for update
to authenticated
using (
  private.is_org_staff(organization_id)
  or (
    private.is_student_self(organization_id, student_id)
    and author_profile_id = (select auth.uid())
    and visibility = 'student_and_teacher'
  )
)
with check (
  private.is_org_staff(organization_id)
  or (
    private.is_student_self(organization_id, student_id)
    and author_profile_id = (select auth.uid())
    and visibility = 'student_and_teacher'
    and note_type in ('student_daily', 'general', 'academic')
  )
);

-- -----------------------------------------------------------------------------
-- COMPLETION / PROGRESSION / PERMANENT REPORTS
-- -----------------------------------------------------------------------------

create policy course_completion_records_select
on public.course_completion_records for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy course_completion_records_insert
on public.course_completion_records for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy course_completion_records_update
on public.course_completion_records for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

create policy progression_decisions_select
on public.progression_decisions for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy progression_decisions_insert
on public.progression_decisions for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy grade_level_decisions_select
on public.grade_level_decisions for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy grade_level_decisions_insert
on public.grade_level_decisions for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy report_snapshots_select
on public.report_snapshots for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or (
    private.is_student_self(organization_id, student_id)
    and status = 'official'
  )
);

create policy report_snapshots_insert
on public.report_snapshots for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy report_snapshots_update
on public.report_snapshots for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

create policy transcript_snapshots_select
on public.transcript_snapshots for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or (
    private.is_student_self(organization_id, student_id)
    and status = 'official'
  )
);

create policy transcript_snapshots_insert
on public.transcript_snapshots for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy transcript_snapshots_update
on public.transcript_snapshots for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

-- -----------------------------------------------------------------------------
-- STUDENT FILE METADATA
-- Storage bucket/object RLS must be configured separately when file uploads are
-- added to the application.
-- -----------------------------------------------------------------------------

create policy student_files_select
on public.student_files for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy student_files_insert
on public.student_files for insert
to authenticated
with check (
  private.is_org_staff(organization_id)
  or (
    private.is_student_self(organization_id, student_id)
    and (student_assignment_id is null or private.student_assignment_belongs_to(student_assignment_id, organization_id, student_id))
    and (daily_record_id is null or private.daily_record_belongs_to(daily_record_id, organization_id, student_id))
  )
);

-- -----------------------------------------------------------------------------
-- AUDIT LOG: staff may read; only SECURITY DEFINER audit triggers may write.
-- -----------------------------------------------------------------------------

create policy audit_log_select
on public.audit_log for select
to authenticated
using (private.is_org_staff(organization_id));

commit;
