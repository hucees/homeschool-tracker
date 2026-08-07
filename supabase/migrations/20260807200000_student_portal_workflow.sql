-- Homeschool Tracker
-- Migration 006: Student portal account integrity + atomic daily course logging

begin;

create unique index if not exists student_user_links_student_uq
  on public.student_user_links (organization_id, student_id);

create or replace function public.save_student_daily_course_work(
  p_student_course_enrollment_id uuid,
  p_lesson_id uuid,
  p_record_date date,
  p_minutes_spent integer default null,
  p_student_note text default null,
  p_completed boolean default true
)
returns table (
  daily_record_id uuid,
  learning_entry_id uuid,
  learning_status text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_organization_id uuid;
  v_student_id uuid;
  v_student_academic_year_id uuid;
  v_course_version_id uuid;
  v_daily_record_id uuid;
  v_learning_entry_id uuid;
  v_status text;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  select l.organization_id, l.student_id
    into v_organization_id, v_student_id
  from public.student_user_links l
  where l.profile_id = v_user_id
    and l.is_active = true
  limit 1;

  if not found then
    raise exception 'This account is not linked to an active student.' using errcode = '42501';
  end if;

  if p_record_date is null then
    raise exception 'A school date is required.' using errcode = '22023';
  end if;

  if p_minutes_spent is not null and (p_minutes_spent < 0 or p_minutes_spent > 1440) then
    raise exception 'Minutes worked must be between 0 and 1440.' using errcode = '22023';
  end if;

  select e.student_academic_year_id, e.course_version_id
    into v_student_academic_year_id, v_course_version_id
  from public.student_course_enrollments e
  where e.id = p_student_course_enrollment_id
    and e.organization_id = v_organization_id
    and e.student_id = v_student_id
    and e.status = 'active';

  if not found then
    raise exception 'The selected course is not an active course for this student.' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.student_academic_years y
    where y.id = v_student_academic_year_id
      and y.organization_id = v_organization_id
      and y.student_id = v_student_id
      and y.status = 'active'
      and p_record_date >= y.start_date
      and (y.end_date is null or p_record_date <= y.end_date)
  ) then
    raise exception 'The school date is outside the student''s active academic-year placement.' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.lessons l
    where l.id = p_lesson_id
      and l.organization_id = v_organization_id
      and l.course_version_id = v_course_version_id
      and l.status = 'active'
  ) then
    raise exception 'The selected lesson does not belong to this course.' using errcode = '42501';
  end if;

  insert into public.student_daily_records (
    organization_id,
    student_id,
    student_academic_year_id,
    record_date,
    status
  )
  values (
    v_organization_id,
    v_student_id,
    v_student_academic_year_id,
    p_record_date,
    'draft'
  )
  on conflict (student_id, record_date)
  do update set updated_at = now()
  returning id into v_daily_record_id;

  v_status := case when p_completed then 'completed' else 'partial' end;

  select d.id into v_learning_entry_id
  from public.daily_learning_entries d
  where d.daily_record_id = v_daily_record_id
    and d.student_course_enrollment_id = p_student_course_enrollment_id
    and d.lesson_id = p_lesson_id
    and d.daily_assignment_id is null
  limit 1;

  if v_learning_entry_id is null then
    insert into public.daily_learning_entries (
      organization_id,
      student_id,
      daily_record_id,
      student_course_enrollment_id,
      lesson_id,
      status,
      minutes_spent,
      student_note,
      started_at,
      completed_at
    )
    values (
      v_organization_id,
      v_student_id,
      v_daily_record_id,
      p_student_course_enrollment_id,
      p_lesson_id,
      v_status,
      p_minutes_spent,
      nullif(btrim(coalesce(p_student_note, '')), ''),
      now(),
      case when p_completed then now() else null end
    )
    returning id into v_learning_entry_id;
  else
    update public.daily_learning_entries
    set
      status = v_status,
      minutes_spent = p_minutes_spent,
      student_note = nullif(btrim(coalesce(p_student_note, '')), ''),
      started_at = coalesce(started_at, now()),
      completed_at = case when p_completed then coalesce(completed_at, now()) else null end,
      updated_at = now()
    where id = v_learning_entry_id;
  end if;

  return query select v_daily_record_id, v_learning_entry_id, v_status;
end;
$$;

revoke all on function public.save_student_daily_course_work(uuid, uuid, date, integer, text, boolean) from public;
grant execute on function public.save_student_daily_course_work(uuid, uuid, date, integer, text, boolean) to authenticated;

commit;
