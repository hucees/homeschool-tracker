-- Homeschool Tracker
-- Migration 007: Instructor daily review + attendance confirmation

begin;

-- If learning evidence changes after a day has already been approved,
-- automatically reopen the daily record and flag the review.
create or replace function private.invalidate_daily_review_after_learning_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_changed boolean := true;
begin
  if tg_op = 'UPDATE' then
    v_changed :=
      old.status is distinct from new.status
      or old.minutes_spent is distinct from new.minutes_spent
      or old.student_note is distinct from new.student_note
      or old.lesson_id is distinct from new.lesson_id
      or old.student_course_enrollment_id is distinct from new.student_course_enrollment_id;
  end if;

  if not v_changed then
    return new;
  end if;

  update public.daily_record_reviews
  set
    review_status = 'needs_revision',
    updated_at = now()
  where daily_record_id = new.daily_record_id
    and review_status = 'approved';

  if found then
    update public.student_daily_records
    set
      status = 'reopened',
      updated_at = now()
    where id = new.daily_record_id;
  end if;

  return new;
end;
$$;

drop trigger if exists invalidate_daily_review_after_learning_change
  on public.daily_learning_entries;

create trigger invalidate_daily_review_after_learning_change
after insert or update on public.daily_learning_entries
for each row execute function private.invalidate_daily_review_after_learning_change();

create or replace function public.review_student_day(
  p_student_academic_year_id uuid,
  p_record_date date,
  p_attendance_status text,
  p_instructional_minutes integer default null,
  p_teacher_summary text default null,
  p_attendance_notes text default null,
  p_review_status text default 'approved'
)
returns table (
  attendance_record_id uuid,
  daily_review_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_organization_id uuid;
  v_student_id uuid;
  v_start_date date;
  v_end_date date;
  v_daily_record_id uuid;
  v_attendance_id uuid;
  v_review_id uuid;
  v_minutes integer;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if p_record_date is null then
    raise exception 'A school date is required.' using errcode = '22023';
  end if;

  if p_attendance_status not in (
    'present', 'partial', 'absent', 'excused', 'holiday', 'not_scheduled'
  ) then
    raise exception 'Invalid attendance status.' using errcode = '22023';
  end if;

  if p_review_status not in ('reviewed', 'needs_revision', 'approved') then
    raise exception 'Invalid review status.' using errcode = '22023';
  end if;

  if p_instructional_minutes is not null
     and (p_instructional_minutes < 0 or p_instructional_minutes > 1440) then
    raise exception 'Instructional minutes must be between 0 and 1440.'
      using errcode = '22023';
  end if;

  select
    y.organization_id,
    y.student_id,
    y.start_date,
    y.end_date
  into
    v_organization_id,
    v_student_id,
    v_start_date,
    v_end_date
  from public.student_academic_years y
  where y.id = p_student_academic_year_id;

  if not found then
    raise exception 'Student academic-year placement was not found.'
      using errcode = '22023';
  end if;

  if not private.is_org_staff(v_organization_id) then
    raise exception 'Instructor access is required.' using errcode = '42501';
  end if;

  if p_record_date < v_start_date
     or (v_end_date is not null and p_record_date > v_end_date) then
    raise exception 'The selected date is outside this student''s academic-year placement.'
      using errcode = '22023';
  end if;

  select d.id
  into v_daily_record_id
  from public.student_daily_records d
  where d.organization_id = v_organization_id
    and d.student_id = v_student_id
    and d.student_academic_year_id = p_student_academic_year_id
    and d.record_date = p_record_date
  limit 1;

  if p_instructional_minutes is not null then
    v_minutes := p_instructional_minutes;
  elsif v_daily_record_id is not null then
    select coalesce(sum(coalesce(e.minutes_spent, 0)), 0)::integer
    into v_minutes
    from public.daily_learning_entries e
    where e.daily_record_id = v_daily_record_id;
  else
    v_minutes := 0;
  end if;

  insert into public.attendance_records (
    organization_id,
    student_id,
    student_academic_year_id,
    attendance_date,
    status,
    instructional_minutes,
    source,
    teacher_confirmed,
    confirmed_by,
    confirmed_at,
    notes
  )
  values (
    v_organization_id,
    v_student_id,
    p_student_academic_year_id,
    p_record_date,
    p_attendance_status,
    v_minutes,
    case when v_daily_record_id is null then 'manual' else 'activity_suggested' end,
    true,
    v_user_id,
    now(),
    nullif(btrim(coalesce(p_attendance_notes, '')), '')
  )
  on conflict (student_academic_year_id, attendance_date)
  do update set
    status = excluded.status,
    instructional_minutes = excluded.instructional_minutes,
    source = excluded.source,
    teacher_confirmed = true,
    confirmed_by = v_user_id,
    confirmed_at = now(),
    notes = excluded.notes,
    updated_at = now()
  returning id into v_attendance_id;

  if v_daily_record_id is not null then
    insert into public.daily_record_reviews (
      organization_id,
      student_id,
      daily_record_id,
      review_status,
      teacher_summary,
      reviewed_by,
      reviewed_at
    )
    values (
      v_organization_id,
      v_student_id,
      v_daily_record_id,
      p_review_status,
      nullif(btrim(coalesce(p_teacher_summary, '')), ''),
      v_user_id,
      now()
    )
    on conflict (daily_record_id)
    do update set
      review_status = excluded.review_status,
      teacher_summary = excluded.teacher_summary,
      reviewed_by = v_user_id,
      reviewed_at = now(),
      updated_at = now()
    returning id into v_review_id;

    update public.student_daily_records
    set
      status = case
        when p_review_status = 'needs_revision' then 'reopened'
        else 'submitted'
      end,
      submitted_at = case
        when p_review_status = 'needs_revision' then submitted_at
        else coalesce(submitted_at, now())
      end,
      updated_at = now()
    where id = v_daily_record_id;
  end if;

  return query select v_attendance_id, v_review_id;
end;
$$;

revoke all on function public.review_student_day(
  uuid, date, text, integer, text, text, text
) from public;

grant execute on function public.review_student_day(
  uuid, date, text, integer, text, text, text
) to authenticated;

commit;
