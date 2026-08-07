-- Homeschool Tracker
-- Migration 004: Curriculum instruction model + Grade 1 Mathematics 2026.1 installer
-- Target: Supabase PostgreSQL
--
-- This migration extends versioned curriculum with:
--   * explicit weekly structure
--   * measurable mastery objectives
--   * planned competency windows and lesson counts/types
--   * prerequisite relationships (including unresolved cross-course codes)
--   * structured mastery-evidence requirements
--   * daily lesson types
--
-- It then installs an idempotent staff-only function that seeds the revised
-- 21-competency Grade 1 Mathematics course for a specific organization.
-- The curriculum release remains DRAFT so the rest of the 2026.1 curriculum
-- can be added before the release is permanently published/locked.

begin;

-- -----------------------------------------------------------------------------
-- EXTEND COMPETENCY / LESSON DETAIL
-- -----------------------------------------------------------------------------

alter table public.competencies
  add column if not exists start_week integer,
  add column if not exists end_week integer,
  add column if not exists mastery_objective text,
  add column if not exists mastery_threshold_percent numeric(5,2),
  add column if not exists recommended_lesson_count integer,
  add column if not exists lesson_type_plan jsonb not null default '{}'::jsonb,
  add column if not exists minimum_independent_demonstrations integer not null default 2,
  add column if not exists mastery_evidence_summary text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'competencies_valid_week_window') then
    alter table public.competencies
      add constraint competencies_valid_week_window
      check (
        (start_week is null and end_week is null)
        or (start_week between 1 and 52 and end_week between start_week and 52)
      );
  end if;

  if not exists (select 1 from pg_constraint where conname = 'competencies_valid_mastery_threshold') then
    alter table public.competencies
      add constraint competencies_valid_mastery_threshold
      check (mastery_threshold_percent is null or mastery_threshold_percent between 0 and 100);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'competencies_valid_lesson_count') then
    alter table public.competencies
      add constraint competencies_valid_lesson_count
      check (recommended_lesson_count is null or recommended_lesson_count > 0);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'competencies_valid_demo_count') then
    alter table public.competencies
      add constraint competencies_valid_demo_count
      check (minimum_independent_demonstrations > 0);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'competencies_lesson_type_plan_object') then
    alter table public.competencies
      add constraint competencies_lesson_type_plan_object
      check (jsonb_typeof(lesson_type_plan) = 'object');
  end if;
end;
$$;

alter table public.lessons
  add column if not exists lesson_type text not null default 'instruction',
  add column if not exists is_mastery_check boolean not null default false;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'lessons_valid_lesson_type') then
    alter table public.lessons
      add constraint lessons_valid_lesson_type
      check (lesson_type in ('instruction', 'guided_practice', 'independent_practice', 'application', 'assessment', 'review'));
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- VERSIONED WEEK / PREREQUISITE / MASTERY-EVIDENCE TABLES
-- -----------------------------------------------------------------------------

create table if not exists public.course_weeks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  course_version_id uuid not null references public.course_versions(id),
  unit_id uuid references public.units(id),
  week_number integer not null check (week_number between 1 and 52),
  quarter integer not null check (quarter between 1 and 4),
  title text not null,
  focus_summary text,
  week_mode text not null default 'teach'
    check (week_mode in ('teach', 'continue', 'review', 'mastery')),
  is_mastery_check boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_version_id, week_number)
);

create table if not exists public.competency_prerequisites (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  competency_id uuid not null references public.competencies(id),
  prerequisite_competency_id uuid references public.competencies(id),
  prerequisite_code text not null,
  prerequisite_type text not null default 'required'
    check (prerequisite_type in ('required', 'recommended')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (competency_id, prerequisite_code),
  check (prerequisite_competency_id is null or prerequisite_competency_id <> competency_id)
);

create table if not exists public.competency_mastery_evidence_requirements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  competency_id uuid not null references public.competencies(id),
  sequence integer not null check (sequence > 0),
  evidence_type text not null
    check (evidence_type in ('written_assessment', 'oral_response', 'teacher_observation', 'performance_task', 'student_explanation', 'work_sample', 'fluency_check')),
  description text not null,
  minimum_count integer not null default 1 check (minimum_count > 0),
  minimum_score_percent numeric(5,2)
    check (minimum_score_percent is null or minimum_score_percent between 0 and 100),
  is_required boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (competency_id, sequence)
);

alter table public.lessons
  add column if not exists course_week_id uuid references public.course_weeks(id);

create index if not exists course_weeks_course_version_idx
  on public.course_weeks (course_version_id, week_number);
create index if not exists competency_prerequisites_competency_idx
  on public.competency_prerequisites (competency_id, prerequisite_code);
create index if not exists competency_prerequisites_resolved_idx
  on public.competency_prerequisites (prerequisite_competency_id)
  where prerequisite_competency_id is not null;
create index if not exists competency_mastery_evidence_competency_idx
  on public.competency_mastery_evidence_requirements (competency_id, sequence);
create index if not exists lessons_course_week_idx
  on public.lessons (course_week_id, day_number);

-- updated_at support for new tables
create trigger set_course_weeks_updated_at
  before update on public.course_weeks
  for each row execute function private.set_updated_at();
create trigger set_competency_prerequisites_updated_at
  before update on public.competency_prerequisites
  for each row execute function private.set_updated_at();
create trigger set_competency_mastery_evidence_requirements_updated_at
  before update on public.competency_mastery_evidence_requirements
  for each row execute function private.set_updated_at();

-- Published-release immutability for the new versioned tables.
create trigger guard_course_weeks
  before insert or update or delete on public.course_weeks
  for each row execute function private.guard_course_child_edit();

create or replace function private.guard_competency_child_edit()
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
    from public.competencies c
    join public.course_versions cv on cv.id = c.course_version_id
    where c.id = old.competency_id;
    perform private.assert_release_editable(v_release_id);
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    select cv.curriculum_release_id into v_release_id
    from public.competencies c
    join public.course_versions cv on cv.id = c.course_version_id
    where c.id = new.competency_id;
    perform private.assert_release_editable(v_release_id);
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger guard_competency_prerequisites
  before insert or update or delete on public.competency_prerequisites
  for each row execute function private.guard_competency_child_edit();

create trigger guard_competency_mastery_evidence_requirements
  before insert or update or delete on public.competency_mastery_evidence_requirements
  for each row execute function private.guard_competency_child_edit();

-- RLS / privileges for new versioned curriculum tables.
alter table public.course_weeks enable row level security;
alter table public.competency_prerequisites enable row level security;
alter table public.competency_mastery_evidence_requirements enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array[
    'course_weeks',
    'competency_prerequisites',
    'competency_mastery_evidence_requirements'
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

revoke all on public.course_weeks from anon;
revoke all on public.competency_prerequisites from anon;
revoke all on public.competency_mastery_evidence_requirements from anon;

grant select, insert, update, delete on public.course_weeks to authenticated;
grant select, insert, update, delete on public.competency_prerequisites to authenticated;
grant select, insert, update, delete on public.competency_mastery_evidence_requirements to authenticated;
grant all on public.course_weeks to service_role;
grant all on public.competency_prerequisites to service_role;
grant all on public.competency_mastery_evidence_requirements to service_role;

-- -----------------------------------------------------------------------------
-- GRADE 1 MATH 2026.1 SEED IMPLEMENTATION
-- -----------------------------------------------------------------------------

create or replace function private.seed_grade1_math_2026_1(
  p_organization_id uuid,
  p_actor_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_release_id uuid;
  v_course_id uuid;
  v_course_version_id uuid;
  v_subject_id uuid;
  v_grade_level_id uuid;
  v_status text;
  v_enrollment_count integer;
begin
  if not exists (select 1 from public.organizations o where o.id = p_organization_id) then
    raise exception 'Organization % does not exist', p_organization_id;
  end if;

  select id into v_subject_id from public.subjects where code = 'MATH';
  select id into v_grade_level_id from public.grade_levels where code = '1';

  if v_subject_id is null or v_grade_level_id is null then
    raise exception 'Run Migration 003 reference-data seed before installing Grade 1 Math';
  end if;

  select id, status into v_release_id, v_status
  from public.curriculum_releases
  where organization_id = p_organization_id and version = '2026.1';

  if v_release_id is null then
    insert into public.curriculum_releases (
      organization_id, version, name, status, effective_date, created_by
    ) values (
      p_organization_id,
      '2026.1',
      'Homeschool Curriculum 2026.1',
      'draft',
      date '2026-08-01',
      p_actor_id
    )
    returning id, status into v_release_id, v_status;
  end if;

  if v_status <> 'draft' then
    raise exception 'Curriculum release 2026.1 is % and cannot be reseeded', v_status;
  end if;

  insert into public.courses (
    organization_id, code, subject_id, grade_level_id, canonical_name, course_type, active
  ) values (
    p_organization_id, '1-MATH', v_subject_id, v_grade_level_id,
    'Grade 1 Mathematics', 'standard', true
  )
  on conflict (organization_id, code) do update
  set subject_id = excluded.subject_id,
      grade_level_id = excluded.grade_level_id,
      canonical_name = excluded.canonical_name,
      course_type = excluded.course_type,
      active = true,
      updated_at = now()
  returning id into v_course_id;

  insert into public.course_versions (
    organization_id, course_id, curriculum_release_id,
    course_code, title, subject_id, grade_level_id,
    description, instructional_weeks, recommended_minutes_per_week,
    credit_value, grading_method, status
  ) values (
    p_organization_id, v_course_id, v_release_id,
    '1-MATH', 'Grade 1 Mathematics — 2026.1', v_subject_id, v_grade_level_id,
    'A 36-week Grade 1 mathematics course organized around measurable competency mastery, daily instruction, spiral review, and quarterly mastery checks.',
    36, 150, null, 'mixed', 'draft'
  )
  on conflict (course_id, curriculum_release_id) do update
  set course_code = excluded.course_code,
      title = excluded.title,
      subject_id = excluded.subject_id,
      grade_level_id = excluded.grade_level_id,
      description = excluded.description,
      instructional_weeks = excluded.instructional_weeks,
      recommended_minutes_per_week = excluded.recommended_minutes_per_week,
      grading_method = excluded.grading_method,
      status = 'draft',
      updated_at = now()
  returning id into v_course_version_id;

  select count(*) into v_enrollment_count
  from public.student_course_enrollments e
  where e.course_version_id = v_course_version_id;

  if v_enrollment_count > 0 then
    raise exception 'Cannot reseed Grade 1 Math because % student enrollment(s) already reference this draft course version', v_enrollment_count;
  end if;

  -- Exact reseed is allowed only while the release is draft and unused.
  delete from public.assignment_template_competencies atc
   using public.assignment_templates a
   where atc.assignment_template_id = a.id and a.course_version_id = v_course_version_id;
  delete from public.assignment_templates where course_version_id = v_course_version_id;
  delete from public.lesson_competencies lc
   using public.lessons l
   where lc.lesson_id = l.id and l.course_version_id = v_course_version_id;
  delete from public.lessons where course_version_id = v_course_version_id;
  delete from public.competency_mastery_evidence_requirements mer
   using public.competencies c
   where mer.competency_id = c.id and c.course_version_id = v_course_version_id;
  delete from public.competency_prerequisites cp
   using public.competencies c
   where cp.competency_id = c.id and c.course_version_id = v_course_version_id;
  delete from public.competencies where course_version_id = v_course_version_id;
  delete from public.course_weeks where course_version_id = v_course_version_id;
  delete from public.units where course_version_id = v_course_version_id;

  -- Units
  insert into public.units (
    organization_id, course_version_id, code, title, description, sequence, quarter
  )
  select p_organization_id, v_course_version_id, v.code, v.title, v.description, v.sequence, v.quarter
  from (values
    ('1-MATH-U01', 'Numbers and Counting', 'Build number sense through 120 and recognize counting patterns.', 1, 1),
    ('1-MATH-U02', 'Place Value and Comparison', 'Understand tens and ones and compare two-digit numbers.', 2, 1),
    ('1-MATH-U03', 'Addition and Subtraction Within 20', 'Develop strategies, fluency, operation relationships, and one-step problem solving.', 3, 2),
    ('1-MATH-U04', 'Equations and Unknowns', 'Understand equality and find unknown values in addition and subtraction equations.', 4, 3),
    ('1-MATH-U05', 'Measurement and Time', 'Measure and compare length and tell time to the hour and half-hour.', 5, 3),
    ('1-MATH-U06', 'Data', 'Organize, represent, and interpret simple data sets.', 6, 4),
    ('1-MATH-U07', 'Geometry and Equal Shares', 'Reason about 2D/3D shapes and partition shapes into equal shares.', 7, 4),
    ('1-MATH-U08', 'Place-Value Operations Within 100', 'Use tens-and-ones reasoning to add within 100, find 10 more/less, and subtract multiples of 10.', 8, 4)
  ) as v(code, title, description, sequence, quarter);

  -- Revised 21 competencies with locked mastery specifications.
  insert into public.competencies (
    organization_id, course_version_id, unit_id,
    code, title, description, sequence, quarter, is_required,
    start_week, end_week, mastery_objective, mastery_threshold_percent,
    recommended_lesson_count, lesson_type_plan, minimum_independent_demonstrations,
    mastery_evidence_summary
  )
  select
    p_organization_id,
    v_course_version_id,
    u.id,
    v.code,
    v.title,
    v.mastery_objective,
    v.sequence,
    v.quarter,
    true,
    v.start_week,
    v.end_week,
    v.mastery_objective,
    v.mastery_threshold_percent,
    v.recommended_lesson_count,
    v.lesson_type_plan,
    v.minimum_independent_demonstrations,
    v.mastery_evidence_summary
  from (values
    (1, '1-MATH-01', 'Count, read, write, and represent numbers to 120', '1-MATH-U01', 1, 1, 1, 5, 85, 'Independently count, read, write, order, and represent whole numbers from 0 through 120 using numerals, objects, base-ten representations, or number lines with at least 85% accuracy across two separate demonstrations.', '{"instruction":1,"guided_practice":1,"independent_practice":1,"application":1,"assessment":1}'::jsonb, 2, 'A written/visual number-representation check plus an oral or hands-on counting task that includes numbers above 100.'),
    (2, '1-MATH-02', 'Count forward and backward from different starting numbers', '1-MATH-U01', 1, 2, 2, 5, 85, 'Given teacher-selected starting numbers within 0–120, count forward and backward by ones across a stated range without needing to restart at 0 or 1, with at least 85% accuracy across two separate demonstrations.', '{"instruction":1,"guided_practice":1,"independent_practice":1,"application":1,"assessment":1}'::jsonb, 2, 'An oral counting demonstration from multiple starting points plus a written missing-number or number-line task.'),
    (3, '1-MATH-03', 'Recognize and use counting patterns by 2s, 5s, and 10s', '1-MATH-U01', 1, 3, 3, 5, 85, 'Identify, continue, and generate counting patterns by 2s, 5s, and 10s and explain the repeating pattern in the ones digits with at least 85% accuracy across two separate demonstrations.', '{"instruction":1,"guided_practice":1,"independent_practice":1,"application":1,"assessment":1}'::jsonb, 2, 'A skip-counting performance task plus a written pattern-completion check using 2s, 5s, and 10s.'),
    (4, '1-MATH-04', 'Understand tens and ones', '1-MATH-U02', 1, 4, 5, 10, 85, 'Represent any two-digit number as groups of tens and leftover ones, state the value of each digit, and compose/decompose the number in at least two forms with at least 85% accuracy across two separate demonstrations.', '{"instruction":2,"guided_practice":2,"independent_practice":2,"application":2,"assessment":2}'::jsonb, 2, 'A base-ten model or drawing task plus a written place-value check requiring composition and decomposition of two-digit numbers.'),
    (5, '1-MATH-05', 'Compare two-digit numbers using >, <, and =', '1-MATH-U02', 1, 6, 7, 10, 85, 'Compare pairs of two-digit numbers by reasoning about tens first and ones second and correctly record the relationship using >, <, or = with at least 85% accuracy across two separate demonstrations.', '{"instruction":2,"guided_practice":2,"independent_practice":2,"application":2,"assessment":2}'::jsonb, 2, 'A written comparison check plus an oral explanation using place-value reasoning for at least three comparison problems.'),
    (6, '1-MATH-06', 'Add within 20', '1-MATH-U03', 2, 10, 11, 10, 85, 'Solve addition problems with sums through 20 using drawings, objects, number lines, making-ten, doubles, or related strategies and explain at least one strategy, with at least 85% accuracy across two separate demonstrations.', '{"instruction":2,"guided_practice":2,"independent_practice":2,"application":2,"assessment":2}'::jsonb, 2, 'A mixed written addition check within 20 plus a strategy demonstration or student explanation using a model.'),
    (7, '1-MATH-07', 'Subtract within 20', '1-MATH-U03', 2, 12, 13, 10, 85, 'Solve subtraction problems within 20 using drawings, objects, number lines, decomposing, counting on, or related strategies and explain at least one strategy, with at least 85% accuracy across two separate demonstrations.', '{"instruction":2,"guided_practice":2,"independent_practice":2,"application":2,"assessment":2}'::jsonb, 2, 'A mixed written subtraction check within 20 plus a strategy demonstration or student explanation using a model.'),
    (8, '1-MATH-08', 'Develop addition and subtraction fact fluency within 10', '1-MATH-U03', 2, 14, 14, 5, 90, 'Accurately and efficiently recall or derive mixed addition and subtraction facts within 10 with at least 90% accuracy across two separate fluency checks without relying on counting every item from one.', '{"instruction":1,"guided_practice":1,"independent_practice":1,"application":1,"assessment":1}'::jsonb, 2, 'Two mixed fact-fluency checks on different days, supported by teacher observation that the student uses efficient strategies rather than recounting every fact.'),
    (9, '1-MATH-09', 'Use the relationship between addition and subtraction', '1-MATH-U03', 2, 15, 15, 5, 85, 'Use inverse relationships and fact families to connect addition and subtraction, generate related equations, and use one operation to check the other with at least 85% accuracy across two separate demonstrations.', '{"instruction":1,"guided_practice":1,"independent_practice":1,"application":1,"assessment":1}'::jsonb, 2, 'A fact-family/equation check plus an oral or written explanation showing how an addition fact can solve or verify a related subtraction fact.'),
    (10, '1-MATH-10', 'Solve one-step addition and subtraction word problems', '1-MATH-U03', 2, 16, 17, 10, 85, 'Represent and solve one-step join, separate, part-part-whole, and compare situations within 20 using an equation, drawing, object model, or number line and identify the unknown, with at least 85% accuracy across two separate demonstrations.', '{"instruction":2,"guided_practice":2,"independent_practice":2,"application":2,"assessment":2}'::jsonb, 2, 'A mixed one-step word-problem assessment plus one independent model-and-explain task in which the student chooses the operation and justifies it.'),
    (11, '1-MATH-11', 'Understand equations and determine unknowns', '1-MATH-U04', 3, 19, 20, 10, 85, 'Determine an unknown whole number in an addition or subtraction equation within 20, recognize whether simple equations are true or false, and explain the meaning of the equals sign, with at least 85% accuracy across two separate demonstrations.', '{"instruction":2,"guided_practice":2,"independent_practice":2,"application":2,"assessment":2}'::jsonb, 2, 'A written unknown-equation check plus an oral or hands-on balance/equality explanation using equations in more than one unknown position.'),
    (12, '1-MATH-12', 'Measure length using repeated equal-size units', '1-MATH-U05', 3, 21, 22, 10, 85, 'Measure the length of an object by laying equal-size units end-to-end with no gaps or overlaps, report the measurement with its unit, and explain why equal units are required, with at least 85% accuracy across two separate demonstrations.', '{"instruction":2,"guided_practice":2,"independent_practice":2,"application":2,"assessment":2}'::jsonb, 2, 'A hands-on measurement task using repeated units plus a recorded measurement sheet or teacher check of several objects.'),
    (13, '1-MATH-13', 'Compare and order lengths', '1-MATH-U05', 3, 23, 23, 5, 85, 'Directly or indirectly compare and order the lengths of at least three objects using longer than, shorter than, and equal/same length language with at least 85% accuracy across two separate demonstrations.', '{"instruction":1,"guided_practice":1,"independent_practice":1,"application":1,"assessment":1}'::jsonb, 2, 'A hands-on ordering task plus a written or oral comparison check using direct and indirect comparisons.'),
    (14, '1-MATH-14', 'Tell and write time to the hour and half-hour', '1-MATH-U05', 3, 24, 26, 15, 85, 'Read, model, and write times to the hour and half-hour on analog and digital clocks and connect the hour and minute hands to the stated time with at least 85% accuracy across two separate demonstrations.', '{"instruction":3,"guided_practice":3,"independent_practice":3,"application":3,"assessment":3}'::jsonb, 2, 'An analog/digital clock matching assessment plus a hands-on clock-setting task covering both hour and half-hour times.'),
    (15, '1-MATH-15', 'Organize and interpret data', '1-MATH-U06', 4, 28, 28, 5, 85, 'Sort data into categories, count the number in each category, and answer comparison questions about how many more, how many fewer, or how many total, with at least 85% accuracy across two separate demonstrations.', '{"instruction":1,"guided_practice":1,"independent_practice":1,"application":1,"assessment":1}'::jsonb, 2, 'A category-sorting/data table task plus an interpretation check requiring totals and comparison questions.'),
    (16, '1-MATH-16', 'Represent data with pictures, charts, and simple graphs', '1-MATH-U06', 4, 29, 29, 5, 85, 'Create or complete a picture representation, chart, or simple graph from a small data set and accurately use the representation to answer questions with at least 85% accuracy across two separate demonstrations.', '{"instruction":1,"guided_practice":1,"independent_practice":1,"application":1,"assessment":1}'::jsonb, 2, 'A student-created data display plus a short written or oral interpretation check based on that display.'),
    (17, '1-MATH-17', 'Reason with, draw, build, and compose 2D and 3D shapes', '1-MATH-U07', 4, 30, 30, 5, 85, 'Identify defining attributes of common 2D and 3D shapes, draw or build examples, and compose larger shapes from smaller shapes while explaining the attributes used, with at least 85% accuracy across two separate demonstrations.', '{"instruction":1,"guided_practice":1,"independent_practice":1,"application":1,"assessment":1}'::jsonb, 2, 'A shape identification/attribute check plus a hands-on drawing, building, or composing performance task.'),
    (18, '1-MATH-18', 'Partition shapes into halves and fourths', '1-MATH-U07', 4, 31, 31, 5, 85, 'Partition circles and rectangles into two and four equal shares, describe the shares as halves/fourths or quarters, and explain that equal shares of the same whole must be the same size, with at least 85% accuracy across two separate demonstrations.', '{"instruction":1,"guided_practice":1,"independent_practice":1,"application":1,"assessment":1}'::jsonb, 2, 'A draw-and-partition task plus an oral or written explanation distinguishing equal shares from unequal pieces.'),
    (19, '1-MATH-19', 'Add within 100 using place-value strategies', '1-MATH-U08', 4, 32, 33, 10, 85, 'Add within 100 using place-value reasoning and concrete or visual models, including a two-digit number plus a one-digit number and a two-digit number plus a multiple of 10, and explain how tens and ones change, with at least 85% accuracy across two separate demonstrations.', '{"instruction":2,"guided_practice":2,"independent_practice":2,"application":2,"assessment":2}'::jsonb, 2, 'A mixed written addition-within-100 check plus a base-ten/modeling task requiring the student to explain tens-and-ones reasoning.'),
    (20, '1-MATH-20', 'Find 10 more and 10 less mentally', '1-MATH-U08', 4, 34, 34, 5, 90, 'Given a two-digit number, mentally determine the number that is 10 more or 10 less and explain that the tens digit changes while the ones digit remains the same, with at least 90% accuracy across two separate demonstrations.', '{"instruction":1,"guided_practice":1,"independent_practice":1,"application":1,"assessment":1}'::jsonb, 2, 'Two short mental-math checks on different days plus an oral place-value explanation for selected items.'),
    (21, '1-MATH-21', 'Subtract multiples of 10 using place-value reasoning', '1-MATH-U08', 4, 35, 35, 5, 85, 'Subtract a multiple of 10 from a multiple of 10 within the range 10–90 using place-value reasoning, models, or related facts and explain the tens-based strategy, with at least 85% accuracy across two separate demonstrations.', '{"instruction":1,"guided_practice":1,"independent_practice":1,"application":1,"assessment":1}'::jsonb, 2, 'A written multiples-of-10 subtraction check plus a model or oral explanation connecting the problem to tens and related basic facts.')
  ) as v(
    sequence, code, title, unit_code, quarter, start_week, end_week,
    recommended_lesson_count, mastery_threshold_percent, mastery_objective,
    lesson_type_plan, minimum_independent_demonstrations, mastery_evidence_summary
  )
  join public.units u
    on u.course_version_id = v_course_version_id and u.code = v.unit_code;

  -- Prerequisite codes are durable even when the prerequisite lives in another
  -- course version that has not yet been installed. Internal prerequisites are
  -- resolved to UUIDs immediately; K-MATH codes will resolve later when that
  -- curriculum is loaded.
  insert into public.competency_prerequisites (
    organization_id, competency_id, prerequisite_competency_id,
    prerequisite_code, prerequisite_type
  )
  select
    p_organization_id,
    c.id,
    pc.id,
    v.prerequisite_code,
    v.prerequisite_type
  from (values
    ('1-MATH-01', 'K-MATH-01', 'required'),
    ('1-MATH-01', 'K-MATH-02', 'required'),
    ('1-MATH-01', 'K-MATH-03', 'required'),
    ('1-MATH-01', 'K-MATH-04', 'required'),
    ('1-MATH-02', '1-MATH-01', 'required'),
    ('1-MATH-02', 'K-MATH-06', 'required'),
    ('1-MATH-03', '1-MATH-01', 'required'),
    ('1-MATH-03', '1-MATH-02', 'required'),
    ('1-MATH-04', '1-MATH-01', 'required'),
    ('1-MATH-04', 'K-MATH-07', 'required'),
    ('1-MATH-05', '1-MATH-04', 'required'),
    ('1-MATH-06', '1-MATH-01', 'required'),
    ('1-MATH-06', 'K-MATH-08', 'required'),
    ('1-MATH-07', '1-MATH-01', 'required'),
    ('1-MATH-07', 'K-MATH-09', 'required'),
    ('1-MATH-08', '1-MATH-06', 'required'),
    ('1-MATH-08', '1-MATH-07', 'required'),
    ('1-MATH-09', '1-MATH-06', 'required'),
    ('1-MATH-09', '1-MATH-07', 'required'),
    ('1-MATH-10', '1-MATH-06', 'required'),
    ('1-MATH-10', '1-MATH-07', 'required'),
    ('1-MATH-10', '1-MATH-09', 'required'),
    ('1-MATH-11', '1-MATH-06', 'required'),
    ('1-MATH-11', '1-MATH-07', 'required'),
    ('1-MATH-11', '1-MATH-09', 'required'),
    ('1-MATH-12', '1-MATH-01', 'required'),
    ('1-MATH-12', 'K-MATH-13', 'required'),
    ('1-MATH-13', '1-MATH-12', 'required'),
    ('1-MATH-14', '1-MATH-01', 'required'),
    ('1-MATH-15', '1-MATH-01', 'required'),
    ('1-MATH-15', 'K-MATH-14', 'required'),
    ('1-MATH-16', '1-MATH-15', 'required'),
    ('1-MATH-17', 'K-MATH-11', 'required'),
    ('1-MATH-18', '1-MATH-17', 'required'),
    ('1-MATH-19', '1-MATH-04', 'required'),
    ('1-MATH-19', '1-MATH-06', 'required'),
    ('1-MATH-19', '1-MATH-09', 'required'),
    ('1-MATH-20', '1-MATH-04', 'required'),
    ('1-MATH-20', '1-MATH-05', 'required'),
    ('1-MATH-21', '1-MATH-04', 'required'),
    ('1-MATH-21', '1-MATH-07', 'required'),
    ('1-MATH-21', '1-MATH-20', 'required')
  ) as v(competency_code, prerequisite_code, prerequisite_type)
  join public.competencies c
    on c.course_version_id = v_course_version_id and c.code = v.competency_code
  left join public.competencies pc
    on pc.organization_id = p_organization_id
   and pc.code = v.prerequisite_code
   and exists (
     select 1
     from public.course_versions pcv
     where pcv.id = pc.course_version_id
       and pcv.curriculum_release_id = v_release_id
   );

  -- Two required evidence channels per competency: a direct aligned check and
  -- an independent second-day application. The competency row stores the exact
  -- course-specific evidence summary and threshold.
  insert into public.competency_mastery_evidence_requirements (
    organization_id, competency_id, sequence, evidence_type, description,
    minimum_count, minimum_score_percent, is_required
  )
  select
    p_organization_id,
    c.id,
    1,
    case when c.code = '1-MATH-08' then 'fluency_check' else 'written_assessment' end,
    'Complete an instructor-selected assessment directly aligned to the competency mastery objective.',
    1,
    c.mastery_threshold_percent,
    true
  from public.competencies c
  where c.course_version_id = v_course_version_id;

  insert into public.competency_mastery_evidence_requirements (
    organization_id, competency_id, sequence, evidence_type, description,
    minimum_count, minimum_score_percent, is_required
  )
  select
    p_organization_id,
    c.id,
    2,
    case
      when c.code in ('1-MATH-02','1-MATH-03','1-MATH-08','1-MATH-14','1-MATH-20') then 'oral_response'
      when c.code in ('1-MATH-12','1-MATH-13','1-MATH-17','1-MATH-18') then 'performance_task'
      else 'student_explanation'
    end,
    c.mastery_evidence_summary,
    1,
    null,
    true
  from public.competencies c
  where c.course_version_id = v_course_version_id;

  -- 36-week course plan.
  insert into public.course_weeks (
    organization_id, course_version_id, unit_id, week_number, quarter,
    title, focus_summary, week_mode, is_mastery_check
  )
  select
    p_organization_id,
    v_course_version_id,
    u.id,
    v.week_number,
    v.quarter,
    v.title,
    array_to_string(v.focus_codes, ', '),
    v.week_mode,
    (v.week_mode = 'mastery')
  from (values
    (1, 1, '1-MATH-U01', 'Numbers to 120', array['1-MATH-01']::text[], 'teach'),
    (2, 1, '1-MATH-U01', 'Counting Forward and Backward', array['1-MATH-02']::text[], 'teach'),
    (3, 1, '1-MATH-U01', 'Counting Patterns by 2s, 5s, and 10s', array['1-MATH-03']::text[], 'teach'),
    (4, 1, '1-MATH-U02', 'Tens and Ones I', array['1-MATH-04']::text[], 'teach'),
    (5, 1, '1-MATH-U02', 'Tens and Ones II', array['1-MATH-04']::text[], 'continue'),
    (6, 1, '1-MATH-U02', 'Comparing Two-Digit Numbers I', array['1-MATH-05']::text[], 'teach'),
    (7, 1, '1-MATH-U02', 'Comparing Two-Digit Numbers II', array['1-MATH-05']::text[], 'continue'),
    (8, 1, null, 'Quarter 1 Spiral Review', array['1-MATH-01','1-MATH-02','1-MATH-03','1-MATH-04','1-MATH-05']::text[], 'review'),
    (9, 1, null, 'Quarter 1 Mastery Check', array['1-MATH-01','1-MATH-02','1-MATH-03','1-MATH-04','1-MATH-05']::text[], 'mastery'),
    (10, 2, '1-MATH-U03', 'Addition Within 20 I', array['1-MATH-06']::text[], 'teach'),
    (11, 2, '1-MATH-U03', 'Addition Within 20 II', array['1-MATH-06']::text[], 'continue'),
    (12, 2, '1-MATH-U03', 'Subtraction Within 20 I', array['1-MATH-07']::text[], 'teach'),
    (13, 2, '1-MATH-U03', 'Subtraction Within 20 II', array['1-MATH-07']::text[], 'continue'),
    (14, 2, '1-MATH-U03', 'Fact Fluency Within 10', array['1-MATH-08']::text[], 'teach'),
    (15, 2, '1-MATH-U03', 'Addition and Subtraction Relationships', array['1-MATH-09']::text[], 'teach'),
    (16, 2, '1-MATH-U03', 'One-Step Word Problems I', array['1-MATH-10']::text[], 'teach'),
    (17, 2, '1-MATH-U03', 'One-Step Word Problems II', array['1-MATH-10']::text[], 'continue'),
    (18, 2, '1-MATH-U03', 'Quarter 2 Mastery Check', array['1-MATH-06','1-MATH-07','1-MATH-08','1-MATH-09','1-MATH-10']::text[], 'mastery'),
    (19, 3, '1-MATH-U04', 'Equations and Unknowns I', array['1-MATH-11']::text[], 'teach'),
    (20, 3, '1-MATH-U04', 'Equations and Unknowns II', array['1-MATH-11']::text[], 'continue'),
    (21, 3, '1-MATH-U05', 'Measuring Length I', array['1-MATH-12']::text[], 'teach'),
    (22, 3, '1-MATH-U05', 'Measuring Length II', array['1-MATH-12']::text[], 'continue'),
    (23, 3, '1-MATH-U05', 'Comparing and Ordering Lengths', array['1-MATH-13']::text[], 'teach'),
    (24, 3, '1-MATH-U05', 'Time to the Hour and Half-Hour I', array['1-MATH-14']::text[], 'teach'),
    (25, 3, '1-MATH-U05', 'Time to the Hour and Half-Hour II', array['1-MATH-14']::text[], 'continue'),
    (26, 3, '1-MATH-U05', 'Time Application and Review', array['1-MATH-14']::text[], 'continue'),
    (27, 3, '1-MATH-U05', 'Quarter 3 Mastery Check', array['1-MATH-11','1-MATH-12','1-MATH-13','1-MATH-14']::text[], 'mastery'),
    (28, 4, '1-MATH-U06', 'Organizing and Interpreting Data', array['1-MATH-15']::text[], 'teach'),
    (29, 4, '1-MATH-U06', 'Representing Data', array['1-MATH-16']::text[], 'teach'),
    (30, 4, '1-MATH-U07', '2D and 3D Shapes', array['1-MATH-17']::text[], 'teach'),
    (31, 4, '1-MATH-U07', 'Halves and Fourths', array['1-MATH-18']::text[], 'teach'),
    (32, 4, '1-MATH-U08', 'Adding Within 100 I', array['1-MATH-19']::text[], 'teach'),
    (33, 4, '1-MATH-U08', 'Adding Within 100 II', array['1-MATH-19']::text[], 'continue'),
    (34, 4, '1-MATH-U08', 'Ten More and Ten Less', array['1-MATH-20']::text[], 'teach'),
    (35, 4, '1-MATH-U08', 'Subtracting Multiples of 10', array['1-MATH-21']::text[], 'teach'),
    (36, 4, '1-MATH-U08', 'Quarter 4 and Year-End Mastery Check', array['1-MATH-15','1-MATH-16','1-MATH-17','1-MATH-18','1-MATH-19','1-MATH-20','1-MATH-21']::text[], 'mastery')
  ) as v(week_number, quarter, unit_code, title, focus_codes, week_mode)
  left join public.units u
    on u.course_version_id = v_course_version_id and u.code = v.unit_code;

  -- Five daily math lessons per week = 180 lessons.
  with week_plan(week_number, quarter, unit_code, week_title, focus_codes, week_mode) as (
    values
    (1, 1, '1-MATH-U01', 'Numbers to 120', array['1-MATH-01']::text[], 'teach'),
    (2, 1, '1-MATH-U01', 'Counting Forward and Backward', array['1-MATH-02']::text[], 'teach'),
    (3, 1, '1-MATH-U01', 'Counting Patterns by 2s, 5s, and 10s', array['1-MATH-03']::text[], 'teach'),
    (4, 1, '1-MATH-U02', 'Tens and Ones I', array['1-MATH-04']::text[], 'teach'),
    (5, 1, '1-MATH-U02', 'Tens and Ones II', array['1-MATH-04']::text[], 'continue'),
    (6, 1, '1-MATH-U02', 'Comparing Two-Digit Numbers I', array['1-MATH-05']::text[], 'teach'),
    (7, 1, '1-MATH-U02', 'Comparing Two-Digit Numbers II', array['1-MATH-05']::text[], 'continue'),
    (8, 1, null, 'Quarter 1 Spiral Review', array['1-MATH-01','1-MATH-02','1-MATH-03','1-MATH-04','1-MATH-05']::text[], 'review'),
    (9, 1, null, 'Quarter 1 Mastery Check', array['1-MATH-01','1-MATH-02','1-MATH-03','1-MATH-04','1-MATH-05']::text[], 'mastery'),
    (10, 2, '1-MATH-U03', 'Addition Within 20 I', array['1-MATH-06']::text[], 'teach'),
    (11, 2, '1-MATH-U03', 'Addition Within 20 II', array['1-MATH-06']::text[], 'continue'),
    (12, 2, '1-MATH-U03', 'Subtraction Within 20 I', array['1-MATH-07']::text[], 'teach'),
    (13, 2, '1-MATH-U03', 'Subtraction Within 20 II', array['1-MATH-07']::text[], 'continue'),
    (14, 2, '1-MATH-U03', 'Fact Fluency Within 10', array['1-MATH-08']::text[], 'teach'),
    (15, 2, '1-MATH-U03', 'Addition and Subtraction Relationships', array['1-MATH-09']::text[], 'teach'),
    (16, 2, '1-MATH-U03', 'One-Step Word Problems I', array['1-MATH-10']::text[], 'teach'),
    (17, 2, '1-MATH-U03', 'One-Step Word Problems II', array['1-MATH-10']::text[], 'continue'),
    (18, 2, '1-MATH-U03', 'Quarter 2 Mastery Check', array['1-MATH-06','1-MATH-07','1-MATH-08','1-MATH-09','1-MATH-10']::text[], 'mastery'),
    (19, 3, '1-MATH-U04', 'Equations and Unknowns I', array['1-MATH-11']::text[], 'teach'),
    (20, 3, '1-MATH-U04', 'Equations and Unknowns II', array['1-MATH-11']::text[], 'continue'),
    (21, 3, '1-MATH-U05', 'Measuring Length I', array['1-MATH-12']::text[], 'teach'),
    (22, 3, '1-MATH-U05', 'Measuring Length II', array['1-MATH-12']::text[], 'continue'),
    (23, 3, '1-MATH-U05', 'Comparing and Ordering Lengths', array['1-MATH-13']::text[], 'teach'),
    (24, 3, '1-MATH-U05', 'Time to the Hour and Half-Hour I', array['1-MATH-14']::text[], 'teach'),
    (25, 3, '1-MATH-U05', 'Time to the Hour and Half-Hour II', array['1-MATH-14']::text[], 'continue'),
    (26, 3, '1-MATH-U05', 'Time Application and Review', array['1-MATH-14']::text[], 'continue'),
    (27, 3, '1-MATH-U05', 'Quarter 3 Mastery Check', array['1-MATH-11','1-MATH-12','1-MATH-13','1-MATH-14']::text[], 'mastery'),
    (28, 4, '1-MATH-U06', 'Organizing and Interpreting Data', array['1-MATH-15']::text[], 'teach'),
    (29, 4, '1-MATH-U06', 'Representing Data', array['1-MATH-16']::text[], 'teach'),
    (30, 4, '1-MATH-U07', '2D and 3D Shapes', array['1-MATH-17']::text[], 'teach'),
    (31, 4, '1-MATH-U07', 'Halves and Fourths', array['1-MATH-18']::text[], 'teach'),
    (32, 4, '1-MATH-U08', 'Adding Within 100 I', array['1-MATH-19']::text[], 'teach'),
    (33, 4, '1-MATH-U08', 'Adding Within 100 II', array['1-MATH-19']::text[], 'continue'),
    (34, 4, '1-MATH-U08', 'Ten More and Ten Less', array['1-MATH-20']::text[], 'teach'),
    (35, 4, '1-MATH-U08', 'Subtracting Multiples of 10', array['1-MATH-21']::text[], 'teach'),
    (36, 4, '1-MATH-U08', 'Quarter 4 and Year-End Mastery Check', array['1-MATH-15','1-MATH-16','1-MATH-17','1-MATH-18','1-MATH-19','1-MATH-20','1-MATH-21']::text[], 'mastery')
  ),
  day_types(day_number, normal_type, mastery_type, prefix) as (
    values
      (1, 'instruction',          'review',               'Learn'),
      (2, 'guided_practice',      'guided_practice',      'Guided Practice'),
      (3, 'independent_practice', 'independent_practice', 'Independent Practice'),
      (4, 'application',          'application',           'Apply'),
      (5, 'assessment',           'assessment',            'Check')
  )
  insert into public.lessons (
    organization_id, course_version_id, unit_id, course_week_id,
    code, title, description, week_number, day_number, sequence,
    estimated_minutes, status, lesson_type, is_mastery_check
  )
  select
    p_organization_id,
    v_course_version_id,
    u.id,
    cw.id,
    format('1-MATH-W%s-D%s', lpad(wp.week_number::text, 2, '0'), dt.day_number),
    dt.prefix || ': ' || wp.week_title,
    case
      when wp.week_mode = 'mastery' and dt.day_number = 5 then 'Quarter mastery check and evidence collection.'
      when wp.week_mode = 'mastery' then 'Cumulative review and application before the quarterly mastery check.'
      when wp.week_mode = 'review' then 'Spiral review of the quarter competencies.'
      else 'Daily Grade 1 mathematics lesson in the planned teach → practice → apply → assess cycle.'
    end,
    wp.week_number,
    dt.day_number,
    ((wp.week_number - 1) * 5) + dt.day_number,
    30,
    'active',
    case when wp.week_mode in ('mastery','review') and dt.day_number = 1 then 'review' else dt.normal_type end,
    (wp.week_mode = 'mastery' and dt.day_number = 5)
  from week_plan wp
  cross join day_types dt
  join public.course_weeks cw
    on cw.course_version_id = v_course_version_id and cw.week_number = wp.week_number
  left join public.units u
    on u.course_version_id = v_course_version_id and u.code = wp.unit_code;

  -- Lesson ↔ competency mappings.
  with week_plan(week_number, quarter, unit_code, week_title, focus_codes, week_mode) as (
    values
    (1, 1, '1-MATH-U01', 'Numbers to 120', array['1-MATH-01']::text[], 'teach'),
    (2, 1, '1-MATH-U01', 'Counting Forward and Backward', array['1-MATH-02']::text[], 'teach'),
    (3, 1, '1-MATH-U01', 'Counting Patterns by 2s, 5s, and 10s', array['1-MATH-03']::text[], 'teach'),
    (4, 1, '1-MATH-U02', 'Tens and Ones I', array['1-MATH-04']::text[], 'teach'),
    (5, 1, '1-MATH-U02', 'Tens and Ones II', array['1-MATH-04']::text[], 'continue'),
    (6, 1, '1-MATH-U02', 'Comparing Two-Digit Numbers I', array['1-MATH-05']::text[], 'teach'),
    (7, 1, '1-MATH-U02', 'Comparing Two-Digit Numbers II', array['1-MATH-05']::text[], 'continue'),
    (8, 1, null, 'Quarter 1 Spiral Review', array['1-MATH-01','1-MATH-02','1-MATH-03','1-MATH-04','1-MATH-05']::text[], 'review'),
    (9, 1, null, 'Quarter 1 Mastery Check', array['1-MATH-01','1-MATH-02','1-MATH-03','1-MATH-04','1-MATH-05']::text[], 'mastery'),
    (10, 2, '1-MATH-U03', 'Addition Within 20 I', array['1-MATH-06']::text[], 'teach'),
    (11, 2, '1-MATH-U03', 'Addition Within 20 II', array['1-MATH-06']::text[], 'continue'),
    (12, 2, '1-MATH-U03', 'Subtraction Within 20 I', array['1-MATH-07']::text[], 'teach'),
    (13, 2, '1-MATH-U03', 'Subtraction Within 20 II', array['1-MATH-07']::text[], 'continue'),
    (14, 2, '1-MATH-U03', 'Fact Fluency Within 10', array['1-MATH-08']::text[], 'teach'),
    (15, 2, '1-MATH-U03', 'Addition and Subtraction Relationships', array['1-MATH-09']::text[], 'teach'),
    (16, 2, '1-MATH-U03', 'One-Step Word Problems I', array['1-MATH-10']::text[], 'teach'),
    (17, 2, '1-MATH-U03', 'One-Step Word Problems II', array['1-MATH-10']::text[], 'continue'),
    (18, 2, '1-MATH-U03', 'Quarter 2 Mastery Check', array['1-MATH-06','1-MATH-07','1-MATH-08','1-MATH-09','1-MATH-10']::text[], 'mastery'),
    (19, 3, '1-MATH-U04', 'Equations and Unknowns I', array['1-MATH-11']::text[], 'teach'),
    (20, 3, '1-MATH-U04', 'Equations and Unknowns II', array['1-MATH-11']::text[], 'continue'),
    (21, 3, '1-MATH-U05', 'Measuring Length I', array['1-MATH-12']::text[], 'teach'),
    (22, 3, '1-MATH-U05', 'Measuring Length II', array['1-MATH-12']::text[], 'continue'),
    (23, 3, '1-MATH-U05', 'Comparing and Ordering Lengths', array['1-MATH-13']::text[], 'teach'),
    (24, 3, '1-MATH-U05', 'Time to the Hour and Half-Hour I', array['1-MATH-14']::text[], 'teach'),
    (25, 3, '1-MATH-U05', 'Time to the Hour and Half-Hour II', array['1-MATH-14']::text[], 'continue'),
    (26, 3, '1-MATH-U05', 'Time Application and Review', array['1-MATH-14']::text[], 'continue'),
    (27, 3, '1-MATH-U05', 'Quarter 3 Mastery Check', array['1-MATH-11','1-MATH-12','1-MATH-13','1-MATH-14']::text[], 'mastery'),
    (28, 4, '1-MATH-U06', 'Organizing and Interpreting Data', array['1-MATH-15']::text[], 'teach'),
    (29, 4, '1-MATH-U06', 'Representing Data', array['1-MATH-16']::text[], 'teach'),
    (30, 4, '1-MATH-U07', '2D and 3D Shapes', array['1-MATH-17']::text[], 'teach'),
    (31, 4, '1-MATH-U07', 'Halves and Fourths', array['1-MATH-18']::text[], 'teach'),
    (32, 4, '1-MATH-U08', 'Adding Within 100 I', array['1-MATH-19']::text[], 'teach'),
    (33, 4, '1-MATH-U08', 'Adding Within 100 II', array['1-MATH-19']::text[], 'continue'),
    (34, 4, '1-MATH-U08', 'Ten More and Ten Less', array['1-MATH-20']::text[], 'teach'),
    (35, 4, '1-MATH-U08', 'Subtracting Multiples of 10', array['1-MATH-21']::text[], 'teach'),
    (36, 4, '1-MATH-U08', 'Quarter 4 and Year-End Mastery Check', array['1-MATH-15','1-MATH-16','1-MATH-17','1-MATH-18','1-MATH-19','1-MATH-20','1-MATH-21']::text[], 'mastery')
  )
  insert into public.lesson_competencies (
    organization_id, lesson_id, competency_id, relationship_type
  )
  select
    p_organization_id,
    l.id,
    c.id,
    case
      when l.day_number = 5 then 'assesses'
      when wp.week_mode in ('review','mastery') then 'reviews'
      when l.day_number = 1 and wp.week_mode = 'teach' then 'introduces'
      else 'practices'
    end
  from week_plan wp
  join public.lessons l
    on l.course_version_id = v_course_version_id and l.week_number = wp.week_number
  cross join lateral unnest(wp.focus_codes) as f(code)
  join public.competencies c
    on c.course_version_id = v_course_version_id and c.code = f.code;

  -- Weekly Friday checks; weeks 9/18/27/36 are cumulative mastery assessments.
  with week_plan(week_number, quarter, unit_code, week_title, focus_codes, week_mode) as (
    values
    (1, 1, '1-MATH-U01', 'Numbers to 120', array['1-MATH-01']::text[], 'teach'),
    (2, 1, '1-MATH-U01', 'Counting Forward and Backward', array['1-MATH-02']::text[], 'teach'),
    (3, 1, '1-MATH-U01', 'Counting Patterns by 2s, 5s, and 10s', array['1-MATH-03']::text[], 'teach'),
    (4, 1, '1-MATH-U02', 'Tens and Ones I', array['1-MATH-04']::text[], 'teach'),
    (5, 1, '1-MATH-U02', 'Tens and Ones II', array['1-MATH-04']::text[], 'continue'),
    (6, 1, '1-MATH-U02', 'Comparing Two-Digit Numbers I', array['1-MATH-05']::text[], 'teach'),
    (7, 1, '1-MATH-U02', 'Comparing Two-Digit Numbers II', array['1-MATH-05']::text[], 'continue'),
    (8, 1, null, 'Quarter 1 Spiral Review', array['1-MATH-01','1-MATH-02','1-MATH-03','1-MATH-04','1-MATH-05']::text[], 'review'),
    (9, 1, null, 'Quarter 1 Mastery Check', array['1-MATH-01','1-MATH-02','1-MATH-03','1-MATH-04','1-MATH-05']::text[], 'mastery'),
    (10, 2, '1-MATH-U03', 'Addition Within 20 I', array['1-MATH-06']::text[], 'teach'),
    (11, 2, '1-MATH-U03', 'Addition Within 20 II', array['1-MATH-06']::text[], 'continue'),
    (12, 2, '1-MATH-U03', 'Subtraction Within 20 I', array['1-MATH-07']::text[], 'teach'),
    (13, 2, '1-MATH-U03', 'Subtraction Within 20 II', array['1-MATH-07']::text[], 'continue'),
    (14, 2, '1-MATH-U03', 'Fact Fluency Within 10', array['1-MATH-08']::text[], 'teach'),
    (15, 2, '1-MATH-U03', 'Addition and Subtraction Relationships', array['1-MATH-09']::text[], 'teach'),
    (16, 2, '1-MATH-U03', 'One-Step Word Problems I', array['1-MATH-10']::text[], 'teach'),
    (17, 2, '1-MATH-U03', 'One-Step Word Problems II', array['1-MATH-10']::text[], 'continue'),
    (18, 2, '1-MATH-U03', 'Quarter 2 Mastery Check', array['1-MATH-06','1-MATH-07','1-MATH-08','1-MATH-09','1-MATH-10']::text[], 'mastery'),
    (19, 3, '1-MATH-U04', 'Equations and Unknowns I', array['1-MATH-11']::text[], 'teach'),
    (20, 3, '1-MATH-U04', 'Equations and Unknowns II', array['1-MATH-11']::text[], 'continue'),
    (21, 3, '1-MATH-U05', 'Measuring Length I', array['1-MATH-12']::text[], 'teach'),
    (22, 3, '1-MATH-U05', 'Measuring Length II', array['1-MATH-12']::text[], 'continue'),
    (23, 3, '1-MATH-U05', 'Comparing and Ordering Lengths', array['1-MATH-13']::text[], 'teach'),
    (24, 3, '1-MATH-U05', 'Time to the Hour and Half-Hour I', array['1-MATH-14']::text[], 'teach'),
    (25, 3, '1-MATH-U05', 'Time to the Hour and Half-Hour II', array['1-MATH-14']::text[], 'continue'),
    (26, 3, '1-MATH-U05', 'Time Application and Review', array['1-MATH-14']::text[], 'continue'),
    (27, 3, '1-MATH-U05', 'Quarter 3 Mastery Check', array['1-MATH-11','1-MATH-12','1-MATH-13','1-MATH-14']::text[], 'mastery'),
    (28, 4, '1-MATH-U06', 'Organizing and Interpreting Data', array['1-MATH-15']::text[], 'teach'),
    (29, 4, '1-MATH-U06', 'Representing Data', array['1-MATH-16']::text[], 'teach'),
    (30, 4, '1-MATH-U07', '2D and 3D Shapes', array['1-MATH-17']::text[], 'teach'),
    (31, 4, '1-MATH-U07', 'Halves and Fourths', array['1-MATH-18']::text[], 'teach'),
    (32, 4, '1-MATH-U08', 'Adding Within 100 I', array['1-MATH-19']::text[], 'teach'),
    (33, 4, '1-MATH-U08', 'Adding Within 100 II', array['1-MATH-19']::text[], 'continue'),
    (34, 4, '1-MATH-U08', 'Ten More and Ten Less', array['1-MATH-20']::text[], 'teach'),
    (35, 4, '1-MATH-U08', 'Subtracting Multiples of 10', array['1-MATH-21']::text[], 'teach'),
    (36, 4, '1-MATH-U08', 'Quarter 4 and Year-End Mastery Check', array['1-MATH-15','1-MATH-16','1-MATH-17','1-MATH-18','1-MATH-19','1-MATH-20','1-MATH-21']::text[], 'mastery')
  )
  insert into public.assignment_templates (
    organization_id, course_version_id, lesson_id, code, title, description,
    assignment_type, max_points, weight, sequence, active
  )
  select
    p_organization_id,
    v_course_version_id,
    l.id,
    case when wp.week_mode = 'mastery'
      then format('1-MATH-Q%s-MASTERY', wp.quarter)
      else format('1-MATH-W%s-CHECK', lpad(wp.week_number::text, 2, '0'))
    end,
    case when wp.week_mode = 'mastery'
      then format('Quarter %s Mathematics Mastery Check', wp.quarter)
      else format('Week %s Mathematics Check', wp.week_number)
    end,
    case when wp.week_mode = 'mastery'
      then 'Cumulative quarterly mastery evidence aligned to the quarter competencies.'
      else 'Weekly evidence check aligned to the current mathematics focus.'
    end,
    case when wp.week_mode = 'mastery' then 'test' else 'quiz' end,
    case when wp.week_mode = 'mastery' then 20 else 10 end,
    1.0,
    wp.week_number,
    true
  from week_plan wp
  join public.lessons l
    on l.course_version_id = v_course_version_id
   and l.week_number = wp.week_number
   and l.day_number = 5;

  with week_plan(week_number, quarter, unit_code, week_title, focus_codes, week_mode) as (
    values
    (1, 1, '1-MATH-U01', 'Numbers to 120', array['1-MATH-01']::text[], 'teach'),
    (2, 1, '1-MATH-U01', 'Counting Forward and Backward', array['1-MATH-02']::text[], 'teach'),
    (3, 1, '1-MATH-U01', 'Counting Patterns by 2s, 5s, and 10s', array['1-MATH-03']::text[], 'teach'),
    (4, 1, '1-MATH-U02', 'Tens and Ones I', array['1-MATH-04']::text[], 'teach'),
    (5, 1, '1-MATH-U02', 'Tens and Ones II', array['1-MATH-04']::text[], 'continue'),
    (6, 1, '1-MATH-U02', 'Comparing Two-Digit Numbers I', array['1-MATH-05']::text[], 'teach'),
    (7, 1, '1-MATH-U02', 'Comparing Two-Digit Numbers II', array['1-MATH-05']::text[], 'continue'),
    (8, 1, null, 'Quarter 1 Spiral Review', array['1-MATH-01','1-MATH-02','1-MATH-03','1-MATH-04','1-MATH-05']::text[], 'review'),
    (9, 1, null, 'Quarter 1 Mastery Check', array['1-MATH-01','1-MATH-02','1-MATH-03','1-MATH-04','1-MATH-05']::text[], 'mastery'),
    (10, 2, '1-MATH-U03', 'Addition Within 20 I', array['1-MATH-06']::text[], 'teach'),
    (11, 2, '1-MATH-U03', 'Addition Within 20 II', array['1-MATH-06']::text[], 'continue'),
    (12, 2, '1-MATH-U03', 'Subtraction Within 20 I', array['1-MATH-07']::text[], 'teach'),
    (13, 2, '1-MATH-U03', 'Subtraction Within 20 II', array['1-MATH-07']::text[], 'continue'),
    (14, 2, '1-MATH-U03', 'Fact Fluency Within 10', array['1-MATH-08']::text[], 'teach'),
    (15, 2, '1-MATH-U03', 'Addition and Subtraction Relationships', array['1-MATH-09']::text[], 'teach'),
    (16, 2, '1-MATH-U03', 'One-Step Word Problems I', array['1-MATH-10']::text[], 'teach'),
    (17, 2, '1-MATH-U03', 'One-Step Word Problems II', array['1-MATH-10']::text[], 'continue'),
    (18, 2, '1-MATH-U03', 'Quarter 2 Mastery Check', array['1-MATH-06','1-MATH-07','1-MATH-08','1-MATH-09','1-MATH-10']::text[], 'mastery'),
    (19, 3, '1-MATH-U04', 'Equations and Unknowns I', array['1-MATH-11']::text[], 'teach'),
    (20, 3, '1-MATH-U04', 'Equations and Unknowns II', array['1-MATH-11']::text[], 'continue'),
    (21, 3, '1-MATH-U05', 'Measuring Length I', array['1-MATH-12']::text[], 'teach'),
    (22, 3, '1-MATH-U05', 'Measuring Length II', array['1-MATH-12']::text[], 'continue'),
    (23, 3, '1-MATH-U05', 'Comparing and Ordering Lengths', array['1-MATH-13']::text[], 'teach'),
    (24, 3, '1-MATH-U05', 'Time to the Hour and Half-Hour I', array['1-MATH-14']::text[], 'teach'),
    (25, 3, '1-MATH-U05', 'Time to the Hour and Half-Hour II', array['1-MATH-14']::text[], 'continue'),
    (26, 3, '1-MATH-U05', 'Time Application and Review', array['1-MATH-14']::text[], 'continue'),
    (27, 3, '1-MATH-U05', 'Quarter 3 Mastery Check', array['1-MATH-11','1-MATH-12','1-MATH-13','1-MATH-14']::text[], 'mastery'),
    (28, 4, '1-MATH-U06', 'Organizing and Interpreting Data', array['1-MATH-15']::text[], 'teach'),
    (29, 4, '1-MATH-U06', 'Representing Data', array['1-MATH-16']::text[], 'teach'),
    (30, 4, '1-MATH-U07', '2D and 3D Shapes', array['1-MATH-17']::text[], 'teach'),
    (31, 4, '1-MATH-U07', 'Halves and Fourths', array['1-MATH-18']::text[], 'teach'),
    (32, 4, '1-MATH-U08', 'Adding Within 100 I', array['1-MATH-19']::text[], 'teach'),
    (33, 4, '1-MATH-U08', 'Adding Within 100 II', array['1-MATH-19']::text[], 'continue'),
    (34, 4, '1-MATH-U08', 'Ten More and Ten Less', array['1-MATH-20']::text[], 'teach'),
    (35, 4, '1-MATH-U08', 'Subtracting Multiples of 10', array['1-MATH-21']::text[], 'teach'),
    (36, 4, '1-MATH-U08', 'Quarter 4 and Year-End Mastery Check', array['1-MATH-15','1-MATH-16','1-MATH-17','1-MATH-18','1-MATH-19','1-MATH-20','1-MATH-21']::text[], 'mastery')
  )
  insert into public.assignment_template_competencies (
    organization_id, assignment_template_id, competency_id, relationship_type
  )
  select
    p_organization_id,
    a.id,
    c.id,
    'assesses'
  from week_plan wp
  join public.assignment_templates a
    on a.course_version_id = v_course_version_id
   and a.sequence = wp.week_number
  cross join lateral unnest(wp.focus_codes) as f(code)
  join public.competencies c
    on c.course_version_id = v_course_version_id and c.code = f.code;

  return jsonb_build_object(
    'curriculum_release_id', v_release_id,
    'course_id', v_course_id,
    'course_version_id', v_course_version_id,
    'status', 'draft',
    'units', (select count(*) from public.units where course_version_id = v_course_version_id),
    'competencies', (select count(*) from public.competencies where course_version_id = v_course_version_id),
    'weeks', (select count(*) from public.course_weeks where course_version_id = v_course_version_id),
    'lessons', (select count(*) from public.lessons where course_version_id = v_course_version_id),
    'assessment_templates', (select count(*) from public.assignment_templates where course_version_id = v_course_version_id)
  );
end;
$$;

-- Authenticated wrapper: only active organization staff can install/reseed the
-- draft curriculum for their own organization.
create or replace function public.install_grade1_math_2026_1(p_organization_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_org_staff(p_organization_id) then
    raise exception 'Only active organization staff can install Grade 1 Math curriculum';
  end if;

  return private.seed_grade1_math_2026_1(p_organization_id, (select auth.uid()));
end;
$$;

revoke all on function private.seed_grade1_math_2026_1(uuid, uuid) from public;
revoke all on function public.install_grade1_math_2026_1(uuid) from public;
revoke all on function public.install_grade1_math_2026_1(uuid) from anon;
grant execute on function public.install_grade1_math_2026_1(uuid) to authenticated;
grant execute on function private.seed_grade1_math_2026_1(uuid, uuid) to service_role;

commit;
