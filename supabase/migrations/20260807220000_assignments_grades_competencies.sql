-- Homeschool Tracker
-- Migration 008: Assignments + grades + competency evidence
--
-- Goals:
--   * Assign versioned curriculum assessment templates to a student.
--   * Freeze the competencies assessed by that assignment at assignment time.
--   * Enter grades as append-only revisions instead of overwriting history.
--   * Keep competency evidence from corrected grades without double-counting it.
--   * Allow students to read their own assignments, grades, and competency evidence.

begin;

-- -----------------------------------------------------------------------------
-- SNAPSHOT THE COMPETENCIES ATTACHED TO EACH STUDENT ASSIGNMENT
-- -----------------------------------------------------------------------------

create table public.student_assignment_competencies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_assignment_id uuid not null references public.student_assignments(id),
  competency_id uuid not null references public.competencies(id),
  relationship_type text not null default 'assesses'
    check (relationship_type in ('practices', 'assesses', 'reviews')),
  created_at timestamptz not null default now(),
  unique (student_assignment_id, competency_id)
);

create index student_assignment_competencies_assignment_idx
  on public.student_assignment_competencies (student_assignment_id);

create index student_assignment_competencies_student_competency_idx
  on public.student_assignment_competencies (student_id, competency_id);

alter table public.student_assignment_competencies enable row level security;

create policy student_assignment_competencies_select
on public.student_assignment_competencies for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

create policy student_assignment_competencies_insert
on public.student_assignment_competencies for insert
to authenticated
with check (private.is_org_staff(organization_id));

revoke all on public.student_assignment_competencies from anon;
grant select, insert on public.student_assignment_competencies to authenticated;
grant all on public.student_assignment_competencies to service_role;

create trigger audit_student_assignment_competencies
  after insert or update or delete on public.student_assignment_competencies
  for each row execute function private.audit_row_change();

-- -----------------------------------------------------------------------------
-- COMPETENCY EVIDENCE REVISION SUPPORT
-- -----------------------------------------------------------------------------

alter table public.competency_evidence
  add column if not exists grade_record_id uuid references public.grade_records(id),
  add column if not exists is_current boolean not null default true;

create index if not exists competency_evidence_grade_record_idx
  on public.competency_evidence (grade_record_id);

create index if not exists competency_evidence_current_progress_idx
  on public.competency_evidence (
    student_course_enrollment_id,
    competency_id,
    is_current,
    recorded_at desc
  );

create unique index if not exists competency_evidence_one_current_assignment_competency_uq
  on public.competency_evidence (student_assignment_id, competency_id)
  where student_assignment_id is not null
    and grade_record_id is not null
    and is_current = true;

-- -----------------------------------------------------------------------------
-- ASSIGN A VERSIONED CURRICULUM ASSESSMENT
-- -----------------------------------------------------------------------------

create or replace function public.assign_curriculum_assessment(
  p_student_course_enrollment_id uuid,
  p_assignment_template_id uuid,
  p_assigned_date date,
  p_due_date date default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_organization_id uuid;
  v_student_id uuid;
  v_course_version_id uuid;
  v_academic_term_id uuid;
  v_template record;
  v_assignment_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if p_assigned_date is null then
    raise exception 'Assigned date is required.' using errcode = '22023';
  end if;

  if p_due_date is not null and p_due_date < p_assigned_date then
    raise exception 'Due date cannot be before the assigned date.' using errcode = '22023';
  end if;

  select
    e.organization_id,
    e.student_id,
    e.course_version_id,
    e.academic_term_id
  into
    v_organization_id,
    v_student_id,
    v_course_version_id,
    v_academic_term_id
  from public.student_course_enrollments e
  where e.id = p_student_course_enrollment_id
    and e.status in ('planned', 'active');

  if not found then
    raise exception 'Active student course enrollment was not found.' using errcode = '22023';
  end if;

  if not private.is_org_staff(v_organization_id) then
    raise exception 'Instructor access is required.' using errcode = '42501';
  end if;

  select
    a.id,
    a.course_version_id,
    a.lesson_id,
    a.title,
    a.description,
    a.assignment_type,
    a.max_points,
    a.weight,
    a.active
  into v_template
  from public.assignment_templates a
  where a.id = p_assignment_template_id
    and a.organization_id = v_organization_id;

  if not found or v_template.active is not true then
    raise exception 'Assignment template was not found or is inactive.' using errcode = '22023';
  end if;

  if v_template.course_version_id <> v_course_version_id then
    raise exception 'The assessment does not belong to the student''s enrolled curriculum version.'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.student_assignments a
    where a.student_course_enrollment_id = p_student_course_enrollment_id
      and a.assignment_template_id = p_assignment_template_id
      and a.status <> 'cancelled'
  ) then
    raise exception 'This curriculum assessment is already assigned to the student.'
      using errcode = '23505';
  end if;

  perform set_config('app.audit_reason', 'Curriculum assessment assigned by instructor', true);

  insert into public.student_assignments (
    organization_id,
    student_id,
    student_course_enrollment_id,
    assignment_template_id,
    lesson_id,
    academic_term_id,
    title,
    instructions,
    assignment_type,
    max_points,
    weight,
    assigned_date,
    due_date,
    status,
    assigned_by
  )
  values (
    v_organization_id,
    v_student_id,
    p_student_course_enrollment_id,
    p_assignment_template_id,
    v_template.lesson_id,
    v_academic_term_id,
    v_template.title,
    v_template.description,
    v_template.assignment_type,
    v_template.max_points,
    v_template.weight,
    p_assigned_date,
    p_due_date,
    'assigned',
    v_user_id
  )
  returning id into v_assignment_id;

  insert into public.student_assignment_competencies (
    organization_id,
    student_id,
    student_assignment_id,
    competency_id,
    relationship_type
  )
  select
    v_organization_id,
    v_student_id,
    v_assignment_id,
    atc.competency_id,
    atc.relationship_type
  from public.assignment_template_competencies atc
  where atc.assignment_template_id = p_assignment_template_id;

  return v_assignment_id;
end;
$$;

revoke all on function public.assign_curriculum_assessment(uuid, uuid, date, date) from public;
grant execute on function public.assign_curriculum_assessment(uuid, uuid, date, date) to authenticated;

-- -----------------------------------------------------------------------------
-- GRADE AN ASSIGNMENT WITH APPEND-ONLY REVISION HISTORY
-- -----------------------------------------------------------------------------

create or replace function public.grade_student_assignment(
  p_student_assignment_id uuid,
  p_points_earned numeric,
  p_teacher_feedback text default null,
  p_change_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_organization_id uuid;
  v_student_id uuid;
  v_enrollment_id uuid;
  v_assignment_type text;
  v_points_possible numeric(10,2);
  v_percentage numeric(6,3);
  v_letter_grade text;
  v_previous public.grade_records%rowtype;
  v_revision integer := 1;
  v_submission_id uuid;
  v_grade_id uuid;
  v_reason text;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  select
    a.organization_id,
    a.student_id,
    a.student_course_enrollment_id,
    a.assignment_type,
    a.max_points
  into
    v_organization_id,
    v_student_id,
    v_enrollment_id,
    v_assignment_type,
    v_points_possible
  from public.student_assignments a
  where a.id = p_student_assignment_id
    and a.status <> 'cancelled';

  if not found then
    raise exception 'Student assignment was not found.' using errcode = '22023';
  end if;

  if not private.is_org_staff(v_organization_id) then
    raise exception 'Instructor access is required.' using errcode = '42501';
  end if;

  if v_points_possible is null or v_points_possible <= 0 then
    raise exception 'This assignment needs a positive maximum point value before it can be graded.'
      using errcode = '22023';
  end if;

  if p_points_earned is null
     or p_points_earned < 0
     or p_points_earned > v_points_possible then
    raise exception 'Points earned must be between 0 and %.', v_points_possible
      using errcode = '22023';
  end if;

  v_percentage := round((p_points_earned / v_points_possible) * 100.0, 3);

  v_letter_grade := case
    when v_percentage >= 90 then 'A'
    when v_percentage >= 80 then 'B'
    when v_percentage >= 70 then 'C'
    when v_percentage >= 60 then 'D'
    else 'F'
  end;

  select *
  into v_previous
  from public.grade_records g
  where g.student_assignment_id = p_student_assignment_id
    and g.status = 'current'
  order by g.revision_number desc
  limit 1
  for update;

  if found then
    if nullif(btrim(coalesce(p_change_reason, '')), '') is null then
      raise exception 'A correction reason is required when changing an existing grade.'
        using errcode = '22023';
    end if;
    v_revision := v_previous.revision_number + 1;
    v_reason := btrim(p_change_reason);
  else
    v_reason := coalesce(
      nullif(btrim(coalesce(p_change_reason, '')), ''),
      'Initial grade entered by instructor'
    );
  end if;

  perform set_config('app.audit_reason', v_reason, true);

  select s.id
  into v_submission_id
  from public.assignment_submissions s
  where s.student_assignment_id = p_student_assignment_id
  order by s.attempt_number desc
  limit 1;

  if v_submission_id is null then
    insert into public.assignment_submissions (
      organization_id,
      student_id,
      student_assignment_id,
      attempt_number,
      student_response,
      status,
      submitted_at
    )
    values (
      v_organization_id,
      v_student_id,
      p_student_assignment_id,
      1,
      null,
      'submitted',
      now()
    )
    returning id into v_submission_id;
  end if;

  if v_previous.id is not null then
    update public.grade_records
    set status = 'superseded'
    where id = v_previous.id;
  end if;

  insert into public.grade_records (
    organization_id,
    student_id,
    student_assignment_id,
    assignment_submission_id,
    revision_number,
    supersedes_grade_record_id,
    points_earned,
    points_possible,
    percentage,
    letter_grade,
    passed,
    status,
    teacher_feedback,
    change_reason,
    graded_by,
    graded_at
  )
  values (
    v_organization_id,
    v_student_id,
    p_student_assignment_id,
    v_submission_id,
    v_revision,
    v_previous.id,
    p_points_earned,
    v_points_possible,
    v_percentage,
    v_letter_grade,
    v_percentage >= 60,
    'current',
    nullif(btrim(coalesce(p_teacher_feedback, '')), ''),
    v_reason,
    v_user_id,
    now()
  )
  returning id into v_grade_id;

  update public.student_assignments
  set status = 'graded'
  where id = p_student_assignment_id;

  -- Keep old evidence for history, but only the newest grade revision contributes
  -- to current competency progress.
  update public.competency_evidence
  set is_current = false
  where student_assignment_id = p_student_assignment_id
    and grade_record_id is not null
    and is_current = true;

  insert into public.competency_evidence (
    organization_id,
    student_id,
    student_course_enrollment_id,
    competency_id,
    lesson_id,
    student_assignment_id,
    evidence_type,
    rating,
    score,
    recorded_by,
    recorded_at,
    notes,
    grade_record_id,
    is_current
  )
  select
    v_organization_id,
    v_student_id,
    v_enrollment_id,
    sac.competency_id,
    a.lesson_id,
    p_student_assignment_id,
    case
      when v_assignment_type = 'quiz' then 'quiz'
      when v_assignment_type = 'test' then 'test'
      when v_assignment_type = 'project' then 'project'
      else 'assignment'
    end,
    case
      when v_percentage >= coalesce(c.mastery_threshold_percent, 80) then 'proficient'
      when v_percentage >= greatest(coalesce(c.mastery_threshold_percent, 80) - 15, 60) then 'practicing'
      else 'needs_review'
    end,
    v_percentage,
    v_user_id,
    now(),
    nullif(btrim(coalesce(p_teacher_feedback, '')), ''),
    v_grade_id,
    true
  from public.student_assignment_competencies sac
  join public.student_assignments a on a.id = sac.student_assignment_id
  join public.competencies c on c.id = sac.competency_id
  where sac.student_assignment_id = p_student_assignment_id;

  return v_grade_id;
end;
$$;

revoke all on function public.grade_student_assignment(uuid, numeric, text, text) from public;
grant execute on function public.grade_student_assignment(uuid, numeric, text, text) to authenticated;

commit;
