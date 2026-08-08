-- Homeschool Tracker
-- Migration 026: Item-level competency mapping + competency-specific scoring
--
-- Why:
-- Multi-competency online assessments currently create the same whole-assignment
-- percentage as evidence for every linked competency. This migration makes
-- competency evidence derive from the exact tagged question responses instead.
--
-- Scope:
-- * all single-competency Grade 1 Math assessment items are mapped automatically
-- * explicit mappings are added for multi-competency Weeks 8, 9, 18, 27, and 36
-- * item mappings are frozen onto student assignment-item snapshots
-- * future competency_evidence rows use competency-specific item percentages
-- * a cumulative competency represented by only one tagged item is diagnostic
--   only (practicing/needs_review) and cannot become a qualifying mastery
--   demonstration from that one question alone
--
-- This does NOT add a hands-on requirement.
-- This does NOT rewrite previous grade records or historical competency evidence.

begin;

-- ---------------------------------------------------------------------------
-- CURRICULUM QUESTION -> COMPETENCY MAP
-- ---------------------------------------------------------------------------

create table public.assessment_template_item_competencies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  assessment_template_item_id uuid not null references public.assessment_template_items(id),
  competency_id uuid not null references public.competencies(id),
  relationship_type text not null default 'assesses'
    check (relationship_type in ('practices', 'assesses', 'reviews')),
  created_at timestamptz not null default now(),
  unique (assessment_template_item_id, competency_id)
);

create index assessment_template_item_competencies_item_idx
  on public.assessment_template_item_competencies (assessment_template_item_id);

create index assessment_template_item_competencies_competency_idx
  on public.assessment_template_item_competencies (competency_id);

alter table public.assessment_template_item_competencies enable row level security;

create policy assessment_template_item_competencies_staff_select
on public.assessment_template_item_competencies for select
to authenticated
using (private.is_org_staff(organization_id));

create policy assessment_template_item_competencies_staff_insert
on public.assessment_template_item_competencies for insert
to authenticated
with check (private.is_org_staff(organization_id));

create policy assessment_template_item_competencies_staff_update
on public.assessment_template_item_competencies for update
to authenticated
using (private.is_org_staff(organization_id))
with check (private.is_org_staff(organization_id));

create policy assessment_template_item_competencies_staff_delete
on public.assessment_template_item_competencies for delete
to authenticated
using (private.is_org_staff(organization_id));

revoke all on public.assessment_template_item_competencies from anon;
grant select, insert, update, delete
  on public.assessment_template_item_competencies to authenticated;
grant all on public.assessment_template_item_competencies to service_role;

create or replace function private.guard_assessment_item_competency_edit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item_id uuid;
  v_release_id uuid;
begin
  v_item_id := case when tg_op = 'DELETE'
    then old.assessment_template_item_id
    else new.assessment_template_item_id
  end;

  select cv.curriculum_release_id
  into v_release_id
  from public.assessment_template_items ati
  join public.assignment_templates at on at.id = ati.assignment_template_id
  join public.course_versions cv on cv.id = at.course_version_id
  where ati.id = v_item_id;

  perform private.assert_release_editable(v_release_id);

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger guard_assessment_template_item_competencies
  before insert or update or delete
  on public.assessment_template_item_competencies
  for each row execute function private.guard_assessment_item_competency_edit();

-- ---------------------------------------------------------------------------
-- PER-STUDENT FROZEN QUESTION -> COMPETENCY MAP
-- ---------------------------------------------------------------------------

create table public.student_assignment_item_competencies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_assignment_id uuid not null references public.student_assignments(id),
  student_assignment_item_id uuid not null references public.student_assignment_items(id),
  competency_id uuid not null references public.competencies(id),
  relationship_type text not null default 'assesses'
    check (relationship_type in ('practices', 'assesses', 'reviews')),
  created_at timestamptz not null default now(),
  unique (student_assignment_item_id, competency_id)
);

create index student_assignment_item_competencies_assignment_idx
  on public.student_assignment_item_competencies (student_assignment_id);

create index student_assignment_item_competencies_student_comp_idx
  on public.student_assignment_item_competencies (student_id, competency_id);

alter table public.student_assignment_item_competencies enable row level security;

create policy student_assignment_item_competencies_select
on public.student_assignment_item_competencies for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

revoke all on public.student_assignment_item_competencies from anon;
grant select on public.student_assignment_item_competencies to authenticated;
grant all on public.student_assignment_item_competencies to service_role;

create trigger audit_student_assignment_item_competencies
  after insert or update or delete
  on public.student_assignment_item_competencies
  for each row execute function private.audit_row_change();

-- ---------------------------------------------------------------------------
-- SEED ALL SINGLE-COMPETENCY ASSESSMENT ITEMS
-- ---------------------------------------------------------------------------

insert into public.assessment_template_item_competencies (
  organization_id,
  assessment_template_item_id,
  competency_id,
  relationship_type
)
select
  ati.organization_id,
  ati.id,
  atc.competency_id,
  'assesses'
from public.assessment_template_items ati
join public.assignment_templates at
  on at.id = ati.assignment_template_id
join public.course_versions cv
  on cv.id = at.course_version_id
join public.curriculum_releases cr
  on cr.id = cv.curriculum_release_id
join public.assignment_template_competencies atc
  on atc.assignment_template_id = at.id
where cv.course_code = '1-MATH'
  and cr.version = '2026.1'
  and (
    select count(*)
    from public.assignment_template_competencies x
    where x.assignment_template_id = at.id
  ) = 1
on conflict (assessment_template_item_id, competency_id) do nothing;

-- ---------------------------------------------------------------------------
-- EXPLICIT MULTI-COMPETENCY QUESTION MAPS
-- Codes are frozen production question codes from the approved curriculum.
-- ---------------------------------------------------------------------------

with mappings(question_code, competency_code) as (
  values
    -- Week 8 Quarter 1 spiral review
    ('1-MATH-W08-Q01','1-MATH-01'),
    ('1-MATH-W08-Q01','1-MATH-02'),
    ('1-MATH-W08-Q02','1-MATH-02'),
    ('1-MATH-W08-Q03','1-MATH-03'),
    ('1-MATH-W08-Q04','1-MATH-03'),
    ('1-MATH-W08-Q05','1-MATH-01'),
    ('1-MATH-W08-Q05','1-MATH-04'),
    ('1-MATH-W08-Q06','1-MATH-04'),
    ('1-MATH-W08-Q07','1-MATH-05'),
    ('1-MATH-W08-Q08','1-MATH-05'),
    ('1-MATH-W08-Q09','1-MATH-01'),
    ('1-MATH-W08-Q10','1-MATH-03'),

    -- Week 9 Quarter 1 mastery
    ('1-MATH-W09-Q01','1-MATH-02'),
    ('1-MATH-W09-Q02','1-MATH-01'),
    ('1-MATH-W09-Q03','1-MATH-03'),
    ('1-MATH-W09-Q04','1-MATH-03'),
    ('1-MATH-W09-Q05','1-MATH-01'),
    ('1-MATH-W09-Q05','1-MATH-04'),
    ('1-MATH-W09-Q06','1-MATH-04'),
    ('1-MATH-W09-Q07','1-MATH-05'),
    ('1-MATH-W09-Q08','1-MATH-05'),
    ('1-MATH-W09-Q09','1-MATH-01'),
    ('1-MATH-W09-Q09','1-MATH-04'),
    ('1-MATH-W09-Q10','1-MATH-02'),

    -- Week 18 Quarter 2 mastery
    ('1-MATH-W18-Q01','1-MATH-06'),
    ('1-MATH-W18-Q02','1-MATH-07'),
    ('1-MATH-W18-Q03','1-MATH-08'),
    ('1-MATH-W18-Q04','1-MATH-08'),
    ('1-MATH-W18-Q05','1-MATH-09'),
    ('1-MATH-W18-Q06','1-MATH-09'),
    ('1-MATH-W18-Q07','1-MATH-06'),
    ('1-MATH-W18-Q07','1-MATH-10'),
    ('1-MATH-W18-Q08','1-MATH-07'),
    ('1-MATH-W18-Q08','1-MATH-10'),
    ('1-MATH-W18-Q09','1-MATH-06'),
    ('1-MATH-W18-Q09','1-MATH-10'),
    ('1-MATH-W18-Q10','1-MATH-07'),
    ('1-MATH-W18-Q10','1-MATH-10'),

    -- Week 27 Quarter 3 mastery
    ('1-MATH-W27-Q01','1-MATH-11'),
    ('1-MATH-W27-Q02','1-MATH-11'),
    ('1-MATH-W27-Q03','1-MATH-12'),
    ('1-MATH-W27-Q04','1-MATH-12'),
    ('1-MATH-W27-Q05','1-MATH-13'),
    ('1-MATH-W27-Q06','1-MATH-13'),
    ('1-MATH-W27-Q07','1-MATH-14'),
    ('1-MATH-W27-Q08','1-MATH-14'),
    ('1-MATH-W27-Q09','1-MATH-14'),
    ('1-MATH-W27-Q10','1-MATH-11'),

    -- Week 36 Quarter 4 / year-end mastery
    ('1-MATH-W36-Q01','1-MATH-15'),
    ('1-MATH-W36-Q02','1-MATH-16'),
    ('1-MATH-W36-Q03','1-MATH-17'),
    ('1-MATH-W36-Q04','1-MATH-18'),
    ('1-MATH-W36-Q05','1-MATH-19'),
    ('1-MATH-W36-Q06','1-MATH-19'),
    ('1-MATH-W36-Q07','1-MATH-20'),
    ('1-MATH-W36-Q08','1-MATH-20'),
    ('1-MATH-W36-Q09','1-MATH-21'),
    ('1-MATH-W36-Q10','1-MATH-20')
)
insert into public.assessment_template_item_competencies (
  organization_id,
  assessment_template_item_id,
  competency_id,
  relationship_type
)
select
  ati.organization_id,
  ati.id,
  c.id,
  'assesses'
from mappings m
join public.assessment_template_items ati
  on ati.code = m.question_code
join public.assignment_templates at
  on at.id = ati.assignment_template_id
join public.course_versions cv
  on cv.id = at.course_version_id
join public.curriculum_releases cr
  on cr.id = cv.curriculum_release_id
join public.competencies c
  on c.course_version_id = cv.id
 and c.code = m.competency_code
where cv.course_code = '1-MATH'
  and cr.version = '2026.1'
on conflict (assessment_template_item_id, competency_id) do nothing;

-- Every Grade 1 Math online item must now have at least one competency tag.
do $validate$
declare
  v_unmapped integer;
  v_invalid integer;
begin
  select count(*)
  into v_unmapped
  from public.assessment_template_items ati
  join public.assignment_templates at on at.id = ati.assignment_template_id
  join public.course_versions cv on cv.id = at.course_version_id
  join public.curriculum_releases cr on cr.id = cv.curriculum_release_id
  where cv.course_code = '1-MATH'
    and cr.version = '2026.1'
    and not exists (
      select 1
      from public.assessment_template_item_competencies aic
      where aic.assessment_template_item_id = ati.id
    );

  if v_unmapped <> 0 then
    raise exception 'Found % unmapped Grade 1 Math assessment item(s).', v_unmapped;
  end if;

  -- A question may only tag a competency that its parent assignment template
  -- already declares as assessed/reviewed.
  select count(*)
  into v_invalid
  from public.assessment_template_item_competencies aic
  join public.assessment_template_items ati
    on ati.id = aic.assessment_template_item_id
  join public.assignment_templates at
    on at.id = ati.assignment_template_id
  join public.course_versions cv
    on cv.id = at.course_version_id
  join public.curriculum_releases cr
    on cr.id = cv.curriculum_release_id
  where cv.course_code = '1-MATH'
    and cr.version = '2026.1'
    and not exists (
      select 1
      from public.assignment_template_competencies atc
      where atc.assignment_template_id = at.id
        and atc.competency_id = aic.competency_id
    );

  if v_invalid <> 0 then
    raise exception 'Found % item competency tag(s) outside the parent assessment competency set.', v_invalid;
  end if;
end;
$validate$;

-- ---------------------------------------------------------------------------
-- BACKFILL EXISTING FROZEN STUDENT QUESTION SNAPSHOTS
-- ---------------------------------------------------------------------------

insert into public.student_assignment_item_competencies (
  organization_id,
  student_id,
  student_assignment_id,
  student_assignment_item_id,
  competency_id,
  relationship_type
)
select
  sai.organization_id,
  sai.student_id,
  sai.student_assignment_id,
  sai.id,
  aic.competency_id,
  aic.relationship_type
from public.student_assignment_items sai
join public.assessment_template_item_competencies aic
  on aic.assessment_template_item_id = sai.source_template_item_id
join public.student_assignments sa
  on sa.id = sai.student_assignment_id
join public.student_course_enrollments sce
  on sce.id = sa.student_course_enrollment_id
join public.course_versions cv
  on cv.id = sce.course_version_id
join public.curriculum_releases cr
  on cr.id = cv.curriculum_release_id
where cv.course_code = '1-MATH'
  and cr.version = '2026.1'
on conflict (student_assignment_item_id, competency_id) do nothing;

-- Future frozen question snapshots automatically freeze their competency tags too.
create or replace function private.snapshot_student_assignment_item_competencies()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.source_template_item_id is null then
    return new;
  end if;

  insert into public.student_assignment_item_competencies (
    organization_id,
    student_id,
    student_assignment_id,
    student_assignment_item_id,
    competency_id,
    relationship_type
  )
  select
    new.organization_id,
    new.student_id,
    new.student_assignment_id,
    new.id,
    aic.competency_id,
    aic.relationship_type
  from public.assessment_template_item_competencies aic
  where aic.assessment_template_item_id = new.source_template_item_id
  on conflict (student_assignment_item_id, competency_id) do nothing;

  return new;
end;
$$;

create trigger snapshot_student_assignment_item_competencies
  after insert on public.student_assignment_items
  for each row execute function private.snapshot_student_assignment_item_competencies();

-- ---------------------------------------------------------------------------
-- COMPETENCY-SPECIFIC EVIDENCE SCORING
-- ---------------------------------------------------------------------------
-- Existing grade functions may still calculate an overall assignment grade.
-- This BEFORE INSERT trigger makes the competency evidence score itself use
-- only the student's responses to questions tagged to that competency.

create or replace function private.apply_item_level_competency_score()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_submission_id uuid;
  v_item_count integer;
  v_response_count integer;
  v_points_possible numeric(10,2);
  v_points_earned numeric(10,2);
  v_score numeric(6,3);
  v_threshold numeric(5,2);
  v_note text;
begin
  if new.student_assignment_id is null
     or new.competency_id is null
     or new.grade_record_id is null then
    return new;
  end if;

  select gr.assignment_submission_id
  into v_submission_id
  from public.grade_records gr
  where gr.id = new.grade_record_id;

  if v_submission_id is null then
    return new;
  end if;

  select
    count(distinct sai.id),
    count(distinct air.id),
    coalesce(sum(distinct case when sai.points is not null then sai.points end), 0)
  into
    v_item_count,
    v_response_count,
    v_points_possible
  from public.student_assignment_item_competencies saic
  join public.student_assignment_items sai
    on sai.id = saic.student_assignment_item_id
  left join public.assignment_item_responses air
    on air.student_assignment_item_id = sai.id
   and air.assignment_submission_id = v_submission_id
  where saic.student_assignment_id = new.student_assignment_id
    and saic.competency_id = new.competency_id;

  -- Recalculate possible points without DISTINCT-point-value ambiguity.
  select coalesce(sum(x.points), 0)
  into v_points_possible
  from (
    select distinct sai.id, sai.points
    from public.student_assignment_item_competencies saic
    join public.student_assignment_items sai
      on sai.id = saic.student_assignment_item_id
    where saic.student_assignment_id = new.student_assignment_id
      and saic.competency_id = new.competency_id
  ) x;

  select coalesce(sum(x.points_earned), 0)
  into v_points_earned
  from (
    select distinct air.id, air.points_earned
    from public.student_assignment_item_competencies saic
    join public.student_assignment_items sai
      on sai.id = saic.student_assignment_item_id
    join public.assignment_item_responses air
      on air.student_assignment_item_id = sai.id
     and air.assignment_submission_id = v_submission_id
    where saic.student_assignment_id = new.student_assignment_id
      and saic.competency_id = new.competency_id
  ) x;

  -- Only override whole-assignment evidence when a complete tagged-response
  -- subset exists for this competency.
  if v_item_count <= 0
     or v_response_count <> v_item_count
     or v_points_possible <= 0 then
    return new;
  end if;

  v_score := round((v_points_earned / v_points_possible) * 100.0, 3);

  select coalesce(c.mastery_threshold_percent, 80)
  into v_threshold
  from public.competencies c
  where c.id = new.competency_id;

  new.score := v_score;

  if v_item_count < 2 then
    -- One-question cumulative samples are useful diagnostics, but should not
    -- become the second "independent demonstration" needed for mastery.
    new.rating := case
      when v_score >= greatest(v_threshold - 15, 60) then 'practicing'
      else 'needs_review'
    end;

    v_note := format(
      'Item-level diagnostic: %s%% on 1 tagged cumulative question; this single-item sample does not count as a qualifying mastery demonstration.',
      trim(to_char(v_score, 'FM990.000'))
    );
  else
    new.rating := case
      when v_score >= v_threshold then 'proficient'
      when v_score >= greatest(v_threshold - 15, 60) then 'practicing'
      else 'needs_review'
    end;

    v_note := format(
      'Item-level competency score: %s%% across %s tagged questions.',
      trim(to_char(v_score, 'FM990.000')),
      v_item_count
    );
  end if;

  new.notes := case
    when nullif(btrim(coalesce(new.notes, '')), '') is null then v_note
    else new.notes || E'\n' || v_note
  end;

  return new;
end;
$$;

create trigger apply_item_level_competency_score
  before insert on public.competency_evidence
  for each row execute function private.apply_item_level_competency_score();

commit;
