-- Homeschool Tracker
-- Migration 005: Atomic student creation + initial academic placement
--
-- This RPC keeps the first student record, academic-year placement, and optional
-- course enrollment in one transaction so a partially-created student cannot be
-- left behind if one of the later inserts fails.

begin;

create or replace function public.create_student_with_initial_enrollment(
  p_organization_id uuid,
  p_first_name text,
  p_last_name text,
  p_official_grade_level_id uuid,
  p_academic_year_id uuid,
  p_enrollment_date date,
  p_middle_name text default null,
  p_preferred_name text default null,
  p_date_of_birth date default null,
  p_course_version_id uuid default null
)
returns table (
  student_id uuid,
  student_academic_year_id uuid,
  course_enrollment_id uuid,
  student_number text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_student_id uuid := gen_random_uuid();
  v_student_number text := 'STU-' || upper(substr(replace(v_student_id::text, '-', ''), 1, 8));
  v_student_academic_year_id uuid;
  v_course_enrollment_id uuid;
  v_year_start date;
  v_year_end date;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if not private.is_org_staff(p_organization_id) then
    raise exception 'You do not have permission to add students to this homeschool.' using errcode = '42501';
  end if;

  if nullif(btrim(p_first_name), '') is null then
    raise exception 'First name is required.' using errcode = '22023';
  end if;

  if nullif(btrim(p_last_name), '') is null then
    raise exception 'Last name is required.' using errcode = '22023';
  end if;

  select y.start_date, y.end_date
    into v_year_start, v_year_end
  from public.academic_years y
  where y.id = p_academic_year_id
    and y.organization_id = p_organization_id
    and y.status in ('planned', 'active');

  if not found then
    raise exception 'The selected academic year is not available for this homeschool.' using errcode = '22023';
  end if;

  if p_enrollment_date is null or p_enrollment_date < v_year_start or p_enrollment_date > v_year_end then
    raise exception 'Enrollment date must fall within the selected academic year.' using errcode = '22023';
  end if;

  if p_date_of_birth is not null and p_date_of_birth > current_date then
    raise exception 'Date of birth cannot be in the future.' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.grade_levels g
    where g.id = p_official_grade_level_id
      and g.active = true
  ) then
    raise exception 'The selected grade level is not available.' using errcode = '22023';
  end if;

  if p_course_version_id is not null and not exists (
    select 1
    from public.course_versions cv
    where cv.id = p_course_version_id
      and cv.organization_id = p_organization_id
      and cv.status in ('draft', 'published')
  ) then
    raise exception 'The selected course version is not available for this homeschool.' using errcode = '22023';
  end if;

  insert into public.students (
    id,
    organization_id,
    student_number,
    first_name,
    middle_name,
    last_name,
    preferred_name,
    date_of_birth,
    enrollment_date,
    status,
    created_by
  )
  values (
    v_student_id,
    p_organization_id,
    v_student_number,
    btrim(p_first_name),
    nullif(btrim(coalesce(p_middle_name, '')), ''),
    btrim(p_last_name),
    nullif(btrim(coalesce(p_preferred_name, '')), ''),
    p_date_of_birth,
    p_enrollment_date,
    'active',
    v_user_id
  );

  insert into public.student_academic_years (
    organization_id,
    student_id,
    academic_year_id,
    official_grade_level_id,
    status,
    start_date
  )
  values (
    p_organization_id,
    v_student_id,
    p_academic_year_id,
    p_official_grade_level_id,
    'active',
    p_enrollment_date
  )
  returning id into v_student_academic_year_id;

  if p_course_version_id is not null then
    insert into public.student_course_enrollments (
      organization_id,
      student_id,
      student_academic_year_id,
      course_version_id,
      attempt_number,
      status,
      start_date,
      assigned_by
    )
    values (
      p_organization_id,
      v_student_id,
      v_student_academic_year_id,
      p_course_version_id,
      1,
      'active',
      p_enrollment_date,
      v_user_id
    )
    returning id into v_course_enrollment_id;
  end if;

  return query
  select
    v_student_id,
    v_student_academic_year_id,
    v_course_enrollment_id,
    v_student_number;
end;
$$;

revoke all on function public.create_student_with_initial_enrollment(
  uuid, text, text, uuid, uuid, date, text, text, date, uuid
) from public;

grant execute on function public.create_student_with_initial_enrollment(
  uuid, text, text, uuid, uuid, date, text, text, date, uuid
) to authenticated;

commit;
