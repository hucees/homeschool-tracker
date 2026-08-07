-- Homeschool Tracker
-- Migration 009: Student assessment delivery + automatic scoring
--
-- This migration adds a versioned assessment item bank, freezes exact question
-- snapshots onto each student assignment, stores item-by-item responses, and
-- automatically scores objective assessments without exposing answer keys to
-- student accounts.

begin;

-- -----------------------------------------------------------------------------
-- VERSIONED CURRICULUM ASSESSMENT ITEMS
-- Correct answers live here, so student accounts do NOT receive table SELECT.
-- -----------------------------------------------------------------------------

create table public.assessment_template_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  assignment_template_id uuid not null references public.assignment_templates(id),
  code text not null,
  sequence integer not null check (sequence > 0),
  question_type text not null
    check (question_type in ('multiple_choice', 'short_answer')),
  prompt text not null,
  options jsonb not null default '[]'::jsonb
    check (jsonb_typeof(options) = 'array'),
  correct_answer text not null,
  points numeric(10,2) not null default 1 check (points > 0),
  created_at timestamptz not null default now(),
  unique (assignment_template_id, code),
  unique (assignment_template_id, sequence)
);

create index assessment_template_items_template_idx
  on public.assessment_template_items (assignment_template_id, sequence);

alter table public.assessment_template_items enable row level security;

create policy assessment_template_items_staff_select
on public.assessment_template_items for select
to authenticated
using (private.is_org_staff(organization_id));

create policy assessment_template_items_staff_insert
on public.assessment_template_items for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy assessment_template_items_staff_update
on public.assessment_template_items for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

create policy assessment_template_items_staff_delete
on public.assessment_template_items for delete
to authenticated
using (private.is_org_staff(organization_id));

revoke all on public.assessment_template_items from anon;
grant select, insert, update, delete on public.assessment_template_items to authenticated;
grant all on public.assessment_template_items to service_role;

-- Keep question-bank edits tied to the same curriculum-release immutability rules.
create or replace function private.guard_assessment_template_item_edit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_release_id uuid;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    select cv.curriculum_release_id
    into v_release_id
    from public.assignment_templates a
    join public.course_versions cv on cv.id = a.course_version_id
    where a.id = old.assignment_template_id;

    perform private.assert_release_editable(v_release_id);
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    select cv.curriculum_release_id
    into v_release_id
    from public.assignment_templates a
    join public.course_versions cv on cv.id = a.course_version_id
    where a.id = new.assignment_template_id;

    perform private.assert_release_editable(v_release_id);
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger guard_assessment_template_items
  before insert or update or delete on public.assessment_template_items
  for each row execute function private.guard_assessment_template_item_edit();

-- -----------------------------------------------------------------------------
-- EXACT PER-STUDENT QUESTION SNAPSHOT
-- These rows are append-only permanent evidence of what the student actually saw.
-- Students receive safe fields only through an RPC that omits correct_answer.
-- -----------------------------------------------------------------------------

create table public.student_assignment_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_assignment_id uuid not null references public.student_assignments(id),
  source_template_item_id uuid references public.assessment_template_items(id),
  source_code text not null,
  sequence integer not null check (sequence > 0),
  question_type text not null
    check (question_type in ('multiple_choice', 'short_answer')),
  prompt text not null,
  options jsonb not null default '[]'::jsonb
    check (jsonb_typeof(options) = 'array'),
  correct_answer text not null,
  points numeric(10,2) not null check (points > 0),
  created_at timestamptz not null default now(),
  unique (student_assignment_id, sequence)
);

create index student_assignment_items_assignment_idx
  on public.student_assignment_items (student_assignment_id, sequence);

alter table public.student_assignment_items enable row level security;

create policy student_assignment_items_staff_select
on public.student_assignment_items for select
to authenticated
using (private.is_org_staff(organization_id));

-- Inserts happen only through security-definer assignment functions.
revoke all on public.student_assignment_items from anon;
grant select on public.student_assignment_items to authenticated;
grant all on public.student_assignment_items to service_role;

create trigger audit_student_assignment_items
  after insert or update or delete on public.student_assignment_items
  for each row execute function private.audit_row_change();

-- -----------------------------------------------------------------------------
-- STRUCTURED STUDENT RESPONSES
-- -----------------------------------------------------------------------------

alter table public.assignment_submissions
  add column if not exists response_data jsonb,
  add column if not exists auto_points_earned numeric(10,2),
  add column if not exists auto_points_possible numeric(10,2),
  add column if not exists auto_percentage numeric(6,3),
  add column if not exists auto_graded boolean not null default false;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'assignment_submissions_auto_percentage_check'
  ) then
    alter table public.assignment_submissions
      add constraint assignment_submissions_auto_percentage_check
      check (auto_percentage is null or auto_percentage between 0 and 100);
  end if;
end;
$$;

create table public.assignment_item_responses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  assignment_submission_id uuid not null references public.assignment_submissions(id),
  student_assignment_item_id uuid not null references public.student_assignment_items(id),
  response_value text,
  is_correct boolean not null,
  points_earned numeric(10,2) not null default 0 check (points_earned >= 0),
  answered_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (assignment_submission_id, student_assignment_item_id)
);

create index assignment_item_responses_submission_idx
  on public.assignment_item_responses (assignment_submission_id);

alter table public.assignment_item_responses enable row level security;

create policy assignment_item_responses_select
on public.assignment_item_responses for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

-- Writes happen only through the security-definer submission function.
revoke all on public.assignment_item_responses from anon;
grant select on public.assignment_item_responses to authenticated;
grant all on public.assignment_item_responses to service_role;

create trigger audit_assignment_item_responses
  after insert or update or delete on public.assignment_item_responses
  for each row execute function private.audit_row_change();

-- Distinguish automatic grades from instructor-entered grades.
alter table public.grade_records
  add column if not exists grading_source text not null default 'instructor';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'grade_records_grading_source_check'
  ) then
    alter table public.grade_records
      add constraint grade_records_grading_source_check
      check (grading_source in ('instructor', 'automatic'));
  end if;
end;
$$;

-- Allow repeated use of a curriculum assessment after a prior instance is complete.
alter table public.student_assignments
  add column if not exists curriculum_instance_number integer not null default 1;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'student_assignments_curriculum_instance_positive'
  ) then
    alter table public.student_assignments
      add constraint student_assignments_curriculum_instance_positive
      check (curriculum_instance_number > 0);
  end if;
end;
$$;

create unique index if not exists student_assignments_template_instance_uq
  on public.student_assignments (
    student_course_enrollment_id,
    assignment_template_id,
    curriculum_instance_number
  )
  where assignment_template_id is not null;

-- -----------------------------------------------------------------------------
-- WEEK 1 GRADE 1 MATH ONLINE ASSESSMENT
-- Aligned to 1-MATH-01:
-- count/read/write/order/represent whole numbers 0-120, including >100.
-- This is the written/visual evidence component; it does not replace the separate
-- oral/hands-on demonstration required by the curriculum for mastery.
-- -----------------------------------------------------------------------------

insert into public.assessment_template_items (
  organization_id,
  assignment_template_id,
  code,
  sequence,
  question_type,
  prompt,
  options,
  correct_answer,
  points
)
select
  a.organization_id,
  a.id,
  q.code,
  q.sequence,
  q.question_type,
  q.prompt,
  q.options,
  q.correct_answer,
  1
from public.assignment_templates a
cross join (
  values
    (
      '1-MATH-W01-Q01', 1, 'multiple_choice',
      'Which numeral means ninety-six?',
      '[{"id":"a","label":"69"},{"id":"b","label":"96"},{"id":"c","label":"90"}]'::jsonb,
      'b'
    ),
    (
      '1-MATH-W01-Q02', 2, 'short_answer',
      'What number comes right after 109?',
      '[]'::jsonb,
      '110'
    ),
    (
      '1-MATH-W01-Q03', 3, 'short_answer',
      'What number comes right before 73?',
      '[]'::jsonb,
      '72'
    ),
    (
      '1-MATH-W01-Q04', 4, 'multiple_choice',
      'Which list is ordered from least to greatest?',
      '[{"id":"a","label":"84, 64, 48"},{"id":"b","label":"48, 64, 84"},{"id":"c","label":"64, 48, 84"}]'::jsonb,
      'b'
    ),
    (
      '1-MATH-W01-Q05', 5, 'multiple_choice',
      'Which place-value model shows 42?',
      '[{"id":"a","label":"4 tens and 2 ones"},{"id":"b","label":"2 tens and 4 ones"},{"id":"c","label":"4 ones and 2 hundreds"}]'::jsonb,
      'a'
    ),
    (
      '1-MATH-W01-Q06', 6, 'short_answer',
      '1 hundred, 1 ten, and 7 ones make what number?',
      '[]'::jsonb,
      '117'
    ),
    (
      '1-MATH-W01-Q07', 7, 'multiple_choice',
      'Which number is between 99 and 101?',
      '[{"id":"a","label":"98"},{"id":"b","label":"100"},{"id":"c","label":"102"}]'::jsonb,
      'b'
    ),
    (
      '1-MATH-W01-Q08', 8, 'short_answer',
      'Complete the number pattern: 112, 113, __, 115',
      '[]'::jsonb,
      '114'
    ),
    (
      '1-MATH-W01-Q09', 9, 'multiple_choice',
      'Which number is greatest?',
      '[{"id":"a","label":"78"},{"id":"b","label":"87"},{"id":"c","label":"80"}]'::jsonb,
      'b'
    ),
    (
      '1-MATH-W01-Q10', 10, 'short_answer',
      '6 tens and 5 ones make what number?',
      '[]'::jsonb,
      '65'
    )
) as q(code, sequence, question_type, prompt, options, correct_answer)
where a.code = '1-MATH-W01-CHECK'
on conflict (assignment_template_id, sequence) do nothing;

-- Freeze the newly added Week 1 items onto any pre-existing Week 1 assignments.
-- Existing manually graded assignments remain graded and are NOT reopened.
insert into public.student_assignment_items (
  organization_id,
  student_id,
  student_assignment_id,
  source_template_item_id,
  source_code,
  sequence,
  question_type,
  prompt,
  options,
  correct_answer,
  points
)
select
  sa.organization_id,
  sa.student_id,
  sa.id,
  ati.id,
  ati.code,
  ati.sequence,
  ati.question_type,
  ati.prompt,
  ati.options,
  ati.correct_answer,
  ati.points
from public.student_assignments sa
join public.assignment_templates at
  on at.id = sa.assignment_template_id
join public.assessment_template_items ati
  on ati.assignment_template_id = at.id
where at.code = '1-MATH-W01-CHECK'
  and not exists (
    select 1
    from public.student_assignment_items existing
    where existing.student_assignment_id = sa.id
  );

-- -----------------------------------------------------------------------------
-- REPLACE ASSIGNMENT FUNCTION
-- New instances freeze exact curriculum questions at assignment time.
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
  v_instance_number integer;
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

  -- Do not allow two simultaneously open copies, but a completed/graded assessment
  -- may be assigned again as a separate permanent instance.
  if exists (
    select 1
    from public.student_assignments a
    where a.student_course_enrollment_id = p_student_course_enrollment_id
      and a.assignment_template_id = p_assignment_template_id
      and a.status in ('assigned', 'submitted')
  ) then
    raise exception 'An open copy of this curriculum assessment is already assigned.'
      using errcode = '23505';
  end if;

  select coalesce(max(a.curriculum_instance_number), 0) + 1
  into v_instance_number
  from public.student_assignments a
  where a.student_course_enrollment_id = p_student_course_enrollment_id
    and a.assignment_template_id = p_assignment_template_id;

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
    assigned_by,
    curriculum_instance_number
  )
  values (
    v_organization_id,
    v_student_id,
    p_student_course_enrollment_id,
    p_assignment_template_id,
    v_template.lesson_id,
    v_academic_term_id,
    case
      when v_instance_number > 1
        then format('%s — Attempt %s', v_template.title, v_instance_number)
      else v_template.title
    end,
    v_template.description,
    v_template.assignment_type,
    v_template.max_points,
    v_template.weight,
    p_assigned_date,
    p_due_date,
    'assigned',
    v_user_id,
    v_instance_number
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

  insert into public.student_assignment_items (
    organization_id,
    student_id,
    student_assignment_id,
    source_template_item_id,
    source_code,
    sequence,
    question_type,
    prompt,
    options,
    correct_answer,
    points
  )
  select
    v_organization_id,
    v_student_id,
    v_assignment_id,
    ati.id,
    ati.code,
    ati.sequence,
    ati.question_type,
    ati.prompt,
    ati.options,
    ati.correct_answer,
    ati.points
  from public.assessment_template_items ati
  where ati.assignment_template_id = p_assignment_template_id
  order by ati.sequence;

  return v_assignment_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- SAFE STUDENT ASSESSMENT READ FUNCTIONS
-- -----------------------------------------------------------------------------

create or replace function public.get_my_online_assessments()
returns table (
  student_assignment_id uuid,
  question_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    a.id,
    count(i.id)
  from public.student_assignments a
  join public.student_assignment_items i
    on i.student_assignment_id = a.id
  where a.status = 'assigned'
    and private.is_student_self(a.organization_id, a.student_id)
  group by a.id;
$$;

revoke all on function public.get_my_online_assessments() from public;
grant execute on function public.get_my_online_assessments() to authenticated;

create or replace function public.get_student_assessment_items(
  p_student_assignment_id uuid
)
returns table (
  item_id uuid,
  sequence integer,
  question_type text,
  prompt text,
  options jsonb,
  points numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_organization_id uuid;
  v_student_id uuid;
begin
  select a.organization_id, a.student_id
  into v_organization_id, v_student_id
  from public.student_assignments a
  where a.id = p_student_assignment_id
    and a.status <> 'cancelled';

  if not found
     or not private.is_student_self(v_organization_id, v_student_id) then
    raise exception 'Assessment was not found.' using errcode = '42501';
  end if;

  return query
  select
    i.id,
    i.sequence,
    i.question_type,
    i.prompt,
    i.options,
    i.points
  from public.student_assignment_items i
  where i.student_assignment_id = p_student_assignment_id
  order by i.sequence;
end;
$$;

revoke all on function public.get_student_assessment_items(uuid) from public;
grant execute on function public.get_student_assessment_items(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- AUTOMATIC SCORING
-- -----------------------------------------------------------------------------

create or replace function private.normalize_assessment_answer(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select lower(btrim(regexp_replace(coalesce(p_value, ''), '\s+', ' ', 'g')));
$$;

create or replace function public.submit_student_assessment(
  p_student_assignment_id uuid,
  p_answers jsonb
)
returns table (
  assignment_submission_id uuid,
  grade_record_id uuid,
  points_earned numeric,
  points_possible numeric,
  percentage numeric,
  letter_grade text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_assignment public.student_assignments%rowtype;
  v_submission_id uuid;
  v_grade_id uuid;
  v_points_earned numeric(10,2);
  v_points_possible numeric(10,2);
  v_percentage numeric(6,3);
  v_letter_grade text;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if p_answers is null or jsonb_typeof(p_answers) <> 'object' then
    raise exception 'Assessment answers must be submitted as an object.'
      using errcode = '22023';
  end if;

  select *
  into v_assignment
  from public.student_assignments a
  where a.id = p_student_assignment_id
  for update;

  if not found
     or not private.is_student_self(v_assignment.organization_id, v_assignment.student_id) then
    raise exception 'Assessment was not found.' using errcode = '42501';
  end if;

  if v_assignment.status <> 'assigned' then
    raise exception 'This assessment is no longer open for submission.'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.assignment_submissions s
    where s.student_assignment_id = p_student_assignment_id
  ) then
    raise exception 'This assessment has already been submitted.'
      using errcode = '23505';
  end if;

  select
    coalesce(sum(i.points), 0),
    coalesce(sum(
      case
        when private.normalize_assessment_answer(p_answers ->> i.id::text)
           = private.normalize_assessment_answer(i.correct_answer)
          then i.points
        else 0
      end
    ), 0)
  into v_points_possible, v_points_earned
  from public.student_assignment_items i
  where i.student_assignment_id = p_student_assignment_id;

  if v_points_possible <= 0 then
    raise exception 'This assignment does not contain an online assessment.'
      using errcode = '22023';
  end if;

  v_percentage := round((v_points_earned / v_points_possible) * 100.0, 3);

  v_letter_grade := case
    when v_percentage >= 90 then 'A'
    when v_percentage >= 80 then 'B'
    when v_percentage >= 70 then 'C'
    when v_percentage >= 60 then 'D'
    else 'F'
  end;

  perform set_config('app.audit_reason', 'Student submitted automatically scored assessment', true);

  insert into public.assignment_submissions (
    organization_id,
    student_id,
    student_assignment_id,
    attempt_number,
    student_response,
    response_data,
    status,
    submitted_at,
    auto_points_earned,
    auto_points_possible,
    auto_percentage,
    auto_graded
  )
  values (
    v_assignment.organization_id,
    v_assignment.student_id,
    p_student_assignment_id,
    1,
    null,
    p_answers,
    'submitted',
    now(),
    v_points_earned,
    v_points_possible,
    v_percentage,
    true
  )
  returning id into v_submission_id;

  insert into public.assignment_item_responses (
    organization_id,
    student_id,
    assignment_submission_id,
    student_assignment_item_id,
    response_value,
    is_correct,
    points_earned
  )
  select
    v_assignment.organization_id,
    v_assignment.student_id,
    v_submission_id,
    i.id,
    nullif(btrim(coalesce(p_answers ->> i.id::text, '')), ''),
    private.normalize_assessment_answer(p_answers ->> i.id::text)
      = private.normalize_assessment_answer(i.correct_answer),
    case
      when private.normalize_assessment_answer(p_answers ->> i.id::text)
         = private.normalize_assessment_answer(i.correct_answer)
        then i.points
      else 0
    end
  from public.student_assignment_items i
  where i.student_assignment_id = p_student_assignment_id
  order by i.sequence;

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
    graded_at,
    grading_source
  )
  values (
    v_assignment.organization_id,
    v_assignment.student_id,
    p_student_assignment_id,
    v_submission_id,
    1,
    null,
    v_points_earned,
    v_points_possible,
    v_percentage,
    v_letter_grade,
    v_percentage >= 60,
    'current',
    null,
    'Automatically scored from student assessment submission',
    null,
    now(),
    'automatic'
  )
  returning id into v_grade_id;

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
    v_assignment.organization_id,
    v_assignment.student_id,
    v_assignment.student_course_enrollment_id,
    sac.competency_id,
    v_assignment.lesson_id,
    p_student_assignment_id,
    case
      when v_assignment.assignment_type = 'quiz' then 'quiz'
      when v_assignment.assignment_type = 'test' then 'test'
      when v_assignment.assignment_type = 'project' then 'project'
      else 'assignment'
    end,
    case
      when v_percentage >= coalesce(c.mastery_threshold_percent, 80) then 'proficient'
      when v_percentage >= greatest(coalesce(c.mastery_threshold_percent, 80) - 15, 60) then 'practicing'
      else 'needs_review'
    end,
    v_percentage,
    null,
    now(),
    'Automatically scored online assessment',
    v_grade_id,
    true
  from public.student_assignment_competencies sac
  join public.competencies c on c.id = sac.competency_id
  where sac.student_assignment_id = p_student_assignment_id;

  update public.student_assignments
  set status = 'graded'
  where id = p_student_assignment_id;

  return query
  select
    v_submission_id,
    v_grade_id,
    v_points_earned,
    v_points_possible,
    v_percentage,
    v_letter_grade;
end;
$$;

revoke all on function public.submit_student_assessment(uuid, jsonb) from public;
grant execute on function public.submit_student_assessment(uuid, jsonb) to authenticated;

commit;
