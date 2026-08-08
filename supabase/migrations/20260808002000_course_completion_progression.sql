-- Homeschool Tracker
-- Migration 012: Course completion + independent subject progression

begin;

alter table public.course_completion_records
  add column if not exists completion_snapshot jsonb not null default '{}'::jsonb,
  add column if not exists override_reason text;

alter table public.progression_decisions
  add column if not exists target_enrollment_id uuid
    references public.student_course_enrollments(id);

create unique index if not exists progression_decisions_one_per_source_uq
  on public.progression_decisions (source_enrollment_id);

create or replace function private.protect_course_completion_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Course completion records are immutable permanent records';
end;
$$;

drop trigger if exists protect_course_completion_history on public.course_completion_records;
create trigger protect_course_completion_history
  before update or delete on public.course_completion_records
  for each row execute function private.protect_course_completion_history();

create or replace function private.protect_progression_decision_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Course progression decisions are immutable permanent records';
end;
$$;

drop trigger if exists protect_progression_decision_history on public.progression_decisions;
create trigger protect_progression_decision_history
  before update or delete on public.progression_decisions
  for each row execute function private.protect_progression_decision_history();

drop policy if exists course_completion_records_update on public.course_completion_records;

create or replace function public.get_course_completion_readiness(
  p_student_course_enrollment_id uuid
)
returns table (
  enrollment_id uuid,
  organization_id uuid,
  student_id uuid,
  course_version_id uuid,
  enrollment_status text,
  start_date date,
  end_date date,
  course_code text,
  course_title text,
  lessons_total integer,
  lessons_completed integer,
  competencies_total integer,
  competencies_mastered integer,
  current_grade_percent numeric,
  current_letter_grade text,
  instructional_minutes integer,
  ready_to_complete boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_enrollment public.student_course_enrollments%rowtype;
  v_course public.course_versions%rowtype;
  v_lessons_total integer := 0;
  v_lessons_completed integer := 0;
  v_competencies_total integer := 0;
  v_competencies_mastered integer := 0;
  v_grade numeric(6,3);
  v_letter text;
  v_minutes integer := 0;
begin
  select *
  into v_enrollment
  from public.student_course_enrollments e
  where e.id = p_student_course_enrollment_id;

  if not found then
    raise exception 'Course enrollment was not found.' using errcode = '22023';
  end if;

  if not (
    private.is_org_staff(v_enrollment.organization_id)
    or private.is_student_self(v_enrollment.organization_id, v_enrollment.student_id)
  ) then
    raise exception 'Access is denied.' using errcode = '42501';
  end if;

  select *
  into v_course
  from public.course_versions cv
  where cv.id = v_enrollment.course_version_id;

  select count(*)::integer
  into v_lessons_total
  from public.lessons l
  where l.course_version_id = v_enrollment.course_version_id
    and l.status = 'active';

  select count(distinct dle.lesson_id)::integer
  into v_lessons_completed
  from public.daily_learning_entries dle
  join public.lessons l on l.id = dle.lesson_id
  where dle.student_course_enrollment_id = v_enrollment.id
    and dle.status = 'completed'
    and l.course_version_id = v_enrollment.course_version_id
    and l.status = 'active';

  select count(*)::integer
  into v_competencies_total
  from public.competencies c
  where c.course_version_id = v_enrollment.course_version_id
    and c.is_required = true;

  select count(*)::integer
  into v_competencies_mastered
  from public.competencies c
  where c.course_version_id = v_enrollment.course_version_id
    and c.is_required = true
    and (
      select count(*)
      from public.competency_evidence ce
      where ce.student_course_enrollment_id = v_enrollment.id
        and ce.competency_id = c.id
        and ce.is_current = true
        and ce.score is not null
        and ce.score >= coalesce(c.mastery_threshold_percent, 80)
        and ce.rating in ('proficient', 'mastered')
    ) >= coalesce(c.minimum_independent_demonstrations, 1);

  select
    round(
      sum(gr.percentage * case when coalesce(sa.weight, 0) > 0 then sa.weight else 1 end)
      /
      nullif(sum(case when coalesce(sa.weight, 0) > 0 then sa.weight else 1 end), 0),
      3
    )
  into v_grade
  from public.student_assignments sa
  join public.grade_records gr
    on gr.student_assignment_id = sa.id
   and gr.status = 'current'
  where sa.student_course_enrollment_id = v_enrollment.id
    and sa.status <> 'cancelled'
    and gr.percentage is not null;

  v_letter := case
    when v_grade is null then null
    when v_grade >= 90 then 'A'
    when v_grade >= 80 then 'B'
    when v_grade >= 70 then 'C'
    when v_grade >= 60 then 'D'
    else 'F'
  end;

  select coalesce(sum(dle.minutes_spent), 0)::integer
  into v_minutes
  from public.daily_learning_entries dle
  where dle.student_course_enrollment_id = v_enrollment.id;

  return query
  select
    v_enrollment.id,
    v_enrollment.organization_id,
    v_enrollment.student_id,
    v_enrollment.course_version_id,
    v_enrollment.status,
    v_enrollment.start_date,
    v_enrollment.end_date,
    v_course.course_code,
    v_course.title,
    v_lessons_total,
    v_lessons_completed,
    v_competencies_total,
    v_competencies_mastered,
    v_grade,
    v_letter,
    v_minutes,
    (
      v_lessons_total > 0
      and v_competencies_total > 0
      and v_lessons_completed >= v_lessons_total
      and v_competencies_mastered >= v_competencies_total
    );
end;
$$;

revoke all on function public.get_course_completion_readiness(uuid) from public;
grant execute on function public.get_course_completion_readiness(uuid) to authenticated;

create or replace function public.complete_student_course(
  p_student_course_enrollment_id uuid,
  p_completion_date date,
  p_teacher_summary text default null,
  p_override_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_enrollment public.student_course_enrollments%rowtype;
  v_readiness record;
  v_completion_id uuid;
  v_credit numeric(5,2);
  v_release_version text;
  v_year_end date;
  v_snapshot jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if p_completion_date is null then
    raise exception 'Completion date is required.' using errcode = '22023';
  end if;

  select *
  into v_enrollment
  from public.student_course_enrollments e
  where e.id = p_student_course_enrollment_id
  for update;

  if not found then
    raise exception 'Course enrollment was not found.' using errcode = '22023';
  end if;

  if not private.is_org_staff(v_enrollment.organization_id) then
    raise exception 'Instructor access is required.' using errcode = '42501';
  end if;

  if v_enrollment.status = 'completed' then
    select ccr.id
    into v_completion_id
    from public.course_completion_records ccr
    where ccr.student_course_enrollment_id = v_enrollment.id;

    if v_completion_id is not null then
      return v_completion_id;
    end if;
  end if;

  if v_enrollment.status <> 'active' then
    raise exception 'Only an active course enrollment can be completed.'
      using errcode = '22023';
  end if;

  select ay.end_date
  into v_year_end
  from public.student_academic_years say
  join public.academic_years ay on ay.id = say.academic_year_id
  where say.id = v_enrollment.student_academic_year_id;

  if p_completion_date < v_enrollment.start_date
     or (v_year_end is not null and p_completion_date > v_year_end) then
    raise exception 'Completion date must fall within the student''s academic-year placement.'
      using errcode = '22023';
  end if;

  select *
  into v_readiness
  from public.get_course_completion_readiness(v_enrollment.id);

  if v_readiness.ready_to_complete is not true
     and nullif(btrim(coalesce(p_override_reason, '')), '') is null then
    raise exception 'Course requirements are not complete. An instructor override reason is required.'
      using errcode = '22023';
  end if;

  select cv.credit_value, cr.version
  into v_credit, v_release_version
  from public.course_versions cv
  join public.curriculum_releases cr on cr.id = cv.curriculum_release_id
  where cv.id = v_enrollment.course_version_id;

  v_snapshot := jsonb_build_object(
    'schema_version', 1,
    'course_version_id', v_enrollment.course_version_id,
    'course_code', v_readiness.course_code,
    'course_title', v_readiness.course_title,
    'curriculum_release', v_release_version,
    'enrollment_start_date', v_enrollment.start_date,
    'completion_date', p_completion_date,
    'lessons_total', v_readiness.lessons_total,
    'lessons_completed', v_readiness.lessons_completed,
    'competencies_total', v_readiness.competencies_total,
    'competencies_mastered', v_readiness.competencies_mastered,
    'final_percentage', v_readiness.current_grade_percent,
    'final_letter_grade', v_readiness.current_letter_grade,
    'instructional_minutes', v_readiness.instructional_minutes,
    'requirements_met', v_readiness.ready_to_complete,
    'instructor_override', (v_readiness.ready_to_complete is not true)
  );

  perform set_config('app.audit_reason', 'Course completion recorded by instructor', true);

  insert into public.course_completion_records (
    organization_id,
    student_id,
    student_course_enrollment_id,
    completion_status,
    final_percentage,
    final_letter_grade,
    credits_attempted,
    credits_earned,
    grade_points,
    competencies_total,
    competencies_mastered,
    instructional_minutes,
    teacher_summary,
    completed_by,
    completed_at,
    completion_snapshot,
    override_reason
  )
  values (
    v_enrollment.organization_id,
    v_enrollment.student_id,
    v_enrollment.id,
    'completed',
    v_readiness.current_grade_percent,
    v_readiness.current_letter_grade,
    v_credit,
    v_credit,
    null,
    v_readiness.competencies_total,
    v_readiness.competencies_mastered,
    v_readiness.instructional_minutes,
    nullif(btrim(coalesce(p_teacher_summary, '')), ''),
    v_user_id,
    now(),
    v_snapshot,
    nullif(btrim(coalesce(p_override_reason, '')), '')
  )
  returning id into v_completion_id;

  update public.student_course_enrollments
  set
    status = 'completed',
    end_date = p_completion_date,
    completed_at = now()
  where id = v_enrollment.id;

  return v_completion_id;
end;
$$;

revoke all on function public.complete_student_course(uuid, date, text, text) from public;
grant execute on function public.complete_student_course(uuid, date, text, text) to authenticated;

create or replace function public.record_course_progression(
  p_source_enrollment_id uuid,
  p_decision text,
  p_target_course_version_id uuid default null,
  p_target_student_academic_year_id uuid default null,
  p_start_date date default null,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_source public.student_course_enrollments%rowtype;
  v_source_course public.course_versions%rowtype;
  v_target_course public.course_versions%rowtype;
  v_target_year_id uuid;
  v_target_placement_start date;
  v_target_placement_end date;
  v_target_year_end date;
  v_target_version_id uuid;
  v_target_enrollment_id uuid;
  v_attempt integer;
  v_source_grade_order integer;
  v_target_grade_order integer;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if p_decision not in ('advance', 'continue', 'repeat', 'accelerate', 'complete') then
    raise exception 'Unsupported progression decision.' using errcode = '22023';
  end if;

  select *
  into v_source
  from public.student_course_enrollments e
  where e.id = p_source_enrollment_id;

  if not found then
    raise exception 'Source course enrollment was not found.' using errcode = '22023';
  end if;

  if not private.is_org_staff(v_source.organization_id) then
    raise exception 'Instructor access is required.' using errcode = '42501';
  end if;

  if v_source.status <> 'completed'
     or not exists (
       select 1
       from public.course_completion_records ccr
       where ccr.student_course_enrollment_id = v_source.id
         and ccr.completion_status = 'completed'
     ) then
    raise exception 'The source course must have a permanent completion record before progression.'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.progression_decisions pd
    where pd.source_enrollment_id = v_source.id
  ) then
    raise exception 'A progression decision has already been recorded for this completed course.'
      using errcode = '23505';
  end if;

  select *
  into v_source_course
  from public.course_versions cv
  where cv.id = v_source.course_version_id;

  if p_decision = 'complete' then
    perform set_config('app.audit_reason', 'Course progression decision recorded by instructor', true);

    insert into public.progression_decisions (
      organization_id,
      student_id,
      source_enrollment_id,
      decision,
      target_course_version_id,
      target_enrollment_id,
      reason,
      decided_by
    )
    values (
      v_source.organization_id,
      v_source.student_id,
      v_source.id,
      'complete',
      null,
      null,
      nullif(btrim(coalesce(p_reason, '')), ''),
      v_user_id
    );

    return null;
  end if;

  v_target_year_id := coalesce(p_target_student_academic_year_id, v_source.student_academic_year_id);

  select
    say.start_date,
    say.end_date,
    ay.end_date
  into
    v_target_placement_start,
    v_target_placement_end,
    v_target_year_end
  from public.student_academic_years say
  join public.academic_years ay on ay.id = say.academic_year_id
  where say.id = v_target_year_id
    and say.organization_id = v_source.organization_id
    and say.student_id = v_source.student_id
    and say.status in ('planned', 'active');

  if not found then
    raise exception 'Target academic-year placement is not available.'
      using errcode = '22023';
  end if;

  if p_start_date is null then
    raise exception 'A start date is required for the next course enrollment.'
      using errcode = '22023';
  end if;

  if p_start_date < v_target_placement_start
     or p_start_date > coalesce(v_target_placement_end, v_target_year_end) then
    raise exception 'The next course start date must fall within the selected academic-year placement.'
      using errcode = '22023';
  end if;

  if p_decision in ('repeat', 'continue') then
    v_target_version_id := v_source.course_version_id;
  else
    v_target_version_id := p_target_course_version_id;
  end if;

  if v_target_version_id is null then
    raise exception 'A target course is required for this progression decision.'
      using errcode = '22023';
  end if;

  select *
  into v_target_course
  from public.course_versions cv
  where cv.id = v_target_version_id
    and cv.organization_id = v_source.organization_id
    and cv.status <> 'retired';

  if not found then
    raise exception 'Target course version is not available.'
      using errcode = '22023';
  end if;

  if v_target_course.subject_id <> v_source_course.subject_id then
    raise exception 'Course progression must remain within the same subject.'
      using errcode = '22023';
  end if;

  if p_decision in ('advance', 'accelerate') then
    select numeric_order into v_source_grade_order
    from public.grade_levels
    where id = v_source_course.grade_level_id;

    select numeric_order into v_target_grade_order
    from public.grade_levels
    where id = v_target_course.grade_level_id;

    if v_source_grade_order is null or v_target_grade_order is null
       or v_target_grade_order <= v_source_grade_order then
      raise exception 'An advance target must be a higher grade-level course in the same subject.'
        using errcode = '22023';
    end if;

    if p_decision = 'advance' and v_target_grade_order <> v_source_grade_order + 1 then
      raise exception 'Advance must move to the next grade-level course. Use accelerate to skip a level.'
        using errcode = '22023';
    end if;
  end if;

  select coalesce(max(e.attempt_number), 0) + 1
  into v_attempt
  from public.student_course_enrollments e
  where e.student_academic_year_id = v_target_year_id
    and e.course_version_id = v_target_version_id;

  perform set_config('app.audit_reason', 'Course progression decision recorded by instructor', true);

  insert into public.student_course_enrollments (
    organization_id,
    student_id,
    student_academic_year_id,
    course_version_id,
    academic_term_id,
    attempt_number,
    status,
    start_date,
    assigned_by
  )
  values (
    v_source.organization_id,
    v_source.student_id,
    v_target_year_id,
    v_target_version_id,
    null,
    v_attempt,
    'active',
    p_start_date,
    v_user_id
  )
  returning id into v_target_enrollment_id;

  insert into public.progression_decisions (
    organization_id,
    student_id,
    source_enrollment_id,
    decision,
    target_course_version_id,
    target_enrollment_id,
    reason,
    decided_by
  )
  values (
    v_source.organization_id,
    v_source.student_id,
    v_source.id,
    p_decision,
    v_target_version_id,
    v_target_enrollment_id,
    nullif(btrim(coalesce(p_reason, '')), ''),
    v_user_id
  );

  return v_target_enrollment_id;
end;
$$;

revoke all on function public.record_course_progression(uuid, text, uuid, uuid, date, text) from public;
grant execute on function public.record_course_progression(uuid, text, uuid, uuid, date, text) to authenticated;

commit;
