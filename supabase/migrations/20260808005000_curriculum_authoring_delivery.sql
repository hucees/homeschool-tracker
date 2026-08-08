-- Homeschool Tracker
-- Migration 015: Curriculum authoring + versioned lesson delivery
--
-- Published lesson content is immutable. A new edit becomes a new revision.
-- A student's first open of a published lesson freezes the exact published
-- revision into student_lesson_deliveries.

begin;

-- -----------------------------------------------------------------------------
-- VERSIONED LESSON CONTENT
-- -----------------------------------------------------------------------------

create table public.lesson_content_versions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  lesson_id uuid not null references public.lessons(id),
  revision_number integer not null check (revision_number > 0),
  status text not null default 'draft'
    check (status in ('draft', 'published', 'superseded')),

  objective text,
  student_goal text,
  materials jsonb not null default '[]'::jsonb
    check (jsonb_typeof(materials) = 'array'),
  vocabulary jsonb not null default '[]'::jsonb
    check (jsonb_typeof(vocabulary) = 'array'),

  teacher_introduction text,
  teacher_modeling text,
  teacher_notes text,

  student_learn text,
  guided_practice text,
  independent_practice text,
  activity text,

  worksheet_title text,
  worksheet_instructions text,
  completion_criteria text,

  accommodations text,
  enrichment text,

  created_by uuid references public.profiles(id) on delete set null,
  published_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz,

  unique (lesson_id, revision_number)
);

create unique index lesson_content_versions_one_published_uq
  on public.lesson_content_versions (lesson_id)
  where status = 'published';

create unique index lesson_content_versions_one_draft_uq
  on public.lesson_content_versions (lesson_id)
  where status = 'draft';

create table public.lesson_content_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  lesson_content_version_id uuid not null
    references public.lesson_content_versions(id) on delete cascade,
  section text not null
    check (section in ('guided_practice', 'independent_practice', 'worksheet')),
  sequence integer not null check (sequence > 0),
  prompt text not null,
  student_support text,
  correct_answer text,
  answer_explanation text,
  points numeric(8,2) check (points is null or points >= 0),
  created_at timestamptz not null default now(),
  unique (lesson_content_version_id, section, sequence)
);

create table public.student_lesson_deliveries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_course_enrollment_id uuid not null
    references public.student_course_enrollments(id),
  lesson_id uuid not null references public.lessons(id),
  lesson_content_version_id uuid not null
    references public.lesson_content_versions(id),
  delivered_at timestamptz not null default now(),
  unique (student_course_enrollment_id, lesson_id)
);

-- -----------------------------------------------------------------------------
-- PUBLISHED CONTENT IMMUTABILITY
-- -----------------------------------------------------------------------------

create or replace function private.protect_lesson_content_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and old.status in ('published', 'superseded') then
    raise exception 'Published lesson content revisions cannot be deleted';
  end if;

  if tg_op = 'UPDATE' and old.status in ('published', 'superseded') then
    if old.status = 'published'
       and new.status = 'superseded'
       and (
         to_jsonb(new)
         - array['status', 'updated_at']
       ) = (
         to_jsonb(old)
         - array['status', 'updated_at']
       ) then
      return new;
    end if;

    raise exception 'Published lesson content revisions are immutable';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists protect_lesson_content_history on public.lesson_content_versions;
create trigger protect_lesson_content_history
  before update or delete on public.lesson_content_versions
  for each row execute function private.protect_lesson_content_history();

create or replace function private.protect_published_lesson_items()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_status text;
  v_version_id uuid;
begin
  v_version_id := case
    when tg_op = 'DELETE' then old.lesson_content_version_id
    else new.lesson_content_version_id
  end;

  select lcv.status
  into v_status
  from public.lesson_content_versions lcv
  where lcv.id = v_version_id;

  if v_status in ('published', 'superseded') then
    raise exception 'Items belonging to published lesson revisions are immutable';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists protect_published_lesson_items on public.lesson_content_items;
create trigger protect_published_lesson_items
  before insert or update or delete on public.lesson_content_items
  for each row execute function private.protect_published_lesson_items();

-- -----------------------------------------------------------------------------
-- AUDIT + RLS
-- -----------------------------------------------------------------------------

drop trigger if exists audit_lesson_content_versions on public.lesson_content_versions;
create trigger audit_lesson_content_versions
  after insert or update or delete on public.lesson_content_versions
  for each row execute function private.audit_row_change();

drop trigger if exists audit_lesson_content_items on public.lesson_content_items;
create trigger audit_lesson_content_items
  after insert or update or delete on public.lesson_content_items
  for each row execute function private.audit_row_change();

drop trigger if exists audit_student_lesson_deliveries on public.student_lesson_deliveries;
create trigger audit_student_lesson_deliveries
  after insert or update or delete on public.student_lesson_deliveries
  for each row execute function private.audit_row_change();

alter table public.lesson_content_versions enable row level security;
alter table public.lesson_content_items enable row level security;
alter table public.student_lesson_deliveries enable row level security;

grant select on public.lesson_content_versions to authenticated;
grant select on public.lesson_content_items to authenticated;
grant select on public.student_lesson_deliveries to authenticated;
grant all on public.lesson_content_versions to service_role;
grant all on public.lesson_content_items to service_role;
grant all on public.student_lesson_deliveries to service_role;

create policy lesson_content_versions_staff_select
on public.lesson_content_versions for select
to authenticated
using (private.is_org_staff(organization_id));

create policy lesson_content_items_staff_select
on public.lesson_content_items for select
to authenticated
using (private.is_org_staff(organization_id));

create policy student_lesson_deliveries_select
on public.student_lesson_deliveries for select
to authenticated
using (
  private.is_org_staff(organization_id)
  or private.is_student_self(organization_id, student_id)
);

-- -----------------------------------------------------------------------------
-- AUTHORING RPC: SAVE / REVISE DRAFT
-- -----------------------------------------------------------------------------

create or replace function public.save_lesson_content_draft(
  p_lesson_id uuid,
  p_content jsonb,
  p_items jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_org_id uuid;
  v_course_version_id uuid;
  v_draft_id uuid;
  v_revision integer;
  v_item jsonb;
  v_section text;
  v_sequence integer;
  v_materials jsonb;
  v_vocabulary jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if p_content is null or jsonb_typeof(p_content) <> 'object' then
    raise exception 'Lesson content must be a JSON object.' using errcode = '22023';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Lesson items must be a JSON array.' using errcode = '22023';
  end if;

  select l.organization_id, l.course_version_id
  into v_org_id, v_course_version_id
  from public.lessons l
  where l.id = p_lesson_id;

  if not found then
    raise exception 'Lesson was not found.' using errcode = '22023';
  end if;

  if not private.is_org_staff(v_org_id) then
    raise exception 'Instructor access is required.' using errcode = '42501';
  end if;

  v_materials := coalesce(p_content->'materials', '[]'::jsonb);
  v_vocabulary := coalesce(p_content->'vocabulary', '[]'::jsonb);

  if jsonb_typeof(v_materials) <> 'array'
     or jsonb_typeof(v_vocabulary) <> 'array' then
    raise exception 'Materials and vocabulary must be JSON arrays.'
      using errcode = '22023';
  end if;

  select lcv.id
  into v_draft_id
  from public.lesson_content_versions lcv
  where lcv.lesson_id = p_lesson_id
    and lcv.status = 'draft'
  order by lcv.revision_number desc
  limit 1
  for update;

  if v_draft_id is null then
    select coalesce(max(lcv.revision_number), 0) + 1
    into v_revision
    from public.lesson_content_versions lcv
    where lcv.lesson_id = p_lesson_id;

    insert into public.lesson_content_versions (
      organization_id,
      lesson_id,
      revision_number,
      status,
      created_by
    )
    values (
      v_org_id,
      p_lesson_id,
      v_revision,
      'draft',
      v_user_id
    )
    returning id into v_draft_id;
  end if;

  perform set_config('app.audit_reason', 'Lesson content draft saved by instructor', true);

  update public.lesson_content_versions
  set
    objective = nullif(btrim(coalesce(p_content->>'objective', '')), ''),
    student_goal = nullif(btrim(coalesce(p_content->>'student_goal', '')), ''),
    materials = v_materials,
    vocabulary = v_vocabulary,
    teacher_introduction = nullif(btrim(coalesce(p_content->>'teacher_introduction', '')), ''),
    teacher_modeling = nullif(btrim(coalesce(p_content->>'teacher_modeling', '')), ''),
    teacher_notes = nullif(btrim(coalesce(p_content->>'teacher_notes', '')), ''),
    student_learn = nullif(btrim(coalesce(p_content->>'student_learn', '')), ''),
    guided_practice = nullif(btrim(coalesce(p_content->>'guided_practice', '')), ''),
    independent_practice = nullif(btrim(coalesce(p_content->>'independent_practice', '')), ''),
    activity = nullif(btrim(coalesce(p_content->>'activity', '')), ''),
    worksheet_title = nullif(btrim(coalesce(p_content->>'worksheet_title', '')), ''),
    worksheet_instructions = nullif(btrim(coalesce(p_content->>'worksheet_instructions', '')), ''),
    completion_criteria = nullif(btrim(coalesce(p_content->>'completion_criteria', '')), ''),
    accommodations = nullif(btrim(coalesce(p_content->>'accommodations', '')), ''),
    enrichment = nullif(btrim(coalesce(p_content->>'enrichment', '')), ''),
    updated_at = now()
  where id = v_draft_id;

  delete from public.lesson_content_items
  where lesson_content_version_id = v_draft_id;

  for v_item in
    select value
    from jsonb_array_elements(p_items)
  loop
    v_section := v_item->>'section';
    v_sequence := nullif(v_item->>'sequence', '')::integer;

    if v_section not in ('guided_practice', 'independent_practice', 'worksheet') then
      raise exception 'Unsupported lesson item section: %', v_section
        using errcode = '22023';
    end if;

    if v_sequence is null or v_sequence < 1 then
      raise exception 'Every lesson item needs a positive sequence number.'
        using errcode = '22023';
    end if;

    if nullif(btrim(coalesce(v_item->>'prompt', '')), '') is null then
      raise exception 'Every lesson item needs a prompt.'
        using errcode = '22023';
    end if;

    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_org_id,
      v_draft_id,
      v_section,
      v_sequence,
      btrim(v_item->>'prompt'),
      nullif(btrim(coalesce(v_item->>'student_support', '')), ''),
      nullif(btrim(coalesce(v_item->>'correct_answer', '')), ''),
      nullif(btrim(coalesce(v_item->>'answer_explanation', '')), ''),
      nullif(v_item->>'points', '')::numeric
    );
  end loop;

  return v_draft_id;
end;
$$;

revoke all on function public.save_lesson_content_draft(uuid, jsonb, jsonb) from public;
grant execute on function public.save_lesson_content_draft(uuid, jsonb, jsonb) to authenticated;

-- -----------------------------------------------------------------------------
-- AUTHORING RPC: PUBLISH
-- -----------------------------------------------------------------------------

create or replace function public.publish_lesson_content(
  p_lesson_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_org_id uuid;
  v_draft public.lesson_content_versions%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  select l.organization_id
  into v_org_id
  from public.lessons l
  where l.id = p_lesson_id;

  if not found then
    raise exception 'Lesson was not found.' using errcode = '22023';
  end if;

  if not private.is_org_staff(v_org_id) then
    raise exception 'Instructor access is required.' using errcode = '42501';
  end if;

  select *
  into v_draft
  from public.lesson_content_versions lcv
  where lcv.lesson_id = p_lesson_id
    and lcv.status = 'draft'
  order by lcv.revision_number desc
  limit 1
  for update;

  if not found then
    raise exception 'Save a draft before publishing this lesson.'
      using errcode = '22023';
  end if;

  if nullif(btrim(coalesce(v_draft.objective, '')), '') is null
     or nullif(btrim(coalesce(v_draft.student_goal, '')), '') is null
     or nullif(btrim(coalesce(v_draft.student_learn, '')), '') is null
     or nullif(btrim(coalesce(v_draft.completion_criteria, '')), '') is null then
    raise exception 'Objective, student goal, student lesson, and completion criteria are required before publishing.'
      using errcode = '22023';
  end if;

  perform set_config('app.audit_reason', 'Lesson content published by instructor', true);

  update public.lesson_content_versions
  set
    status = 'superseded',
    updated_at = now()
  where lesson_id = p_lesson_id
    and status = 'published';

  update public.lesson_content_versions
  set
    status = 'published',
    published_by = v_user_id,
    published_at = now(),
    updated_at = now()
  where id = v_draft.id;

  return v_draft.id;
end;
$$;

revoke all on function public.publish_lesson_content(uuid) from public;
grant execute on function public.publish_lesson_content(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- STUDENT DELIVERY RPC
-- -----------------------------------------------------------------------------

create or replace function public.get_my_lesson_delivery(
  p_student_course_enrollment_id uuid,
  p_lesson_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_enrollment public.student_course_enrollments%rowtype;
  v_lesson public.lessons%rowtype;
  v_content public.lesson_content_versions%rowtype;
  v_delivery_id uuid;
  v_items jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  select *
  into v_enrollment
  from public.student_course_enrollments e
  where e.id = p_student_course_enrollment_id;

  if not found then
    raise exception 'Course enrollment was not found.' using errcode = '22023';
  end if;

  if not private.is_student_self(v_enrollment.organization_id, v_enrollment.student_id) then
    raise exception 'Student access is required.' using errcode = '42501';
  end if;

  if v_enrollment.status <> 'active' then
    raise exception 'This course enrollment is not currently active.'
      using errcode = '22023';
  end if;

  select *
  into v_lesson
  from public.lessons l
  where l.id = p_lesson_id
    and l.course_version_id = v_enrollment.course_version_id
    and l.status = 'active';

  if not found then
    raise exception 'Lesson is not part of this active course.'
      using errcode = '22023';
  end if;

  select sld.id, sld.lesson_content_version_id
  into v_delivery_id, v_content.id
  from public.student_lesson_deliveries sld
  where sld.student_course_enrollment_id = v_enrollment.id
    and sld.lesson_id = v_lesson.id;

  if v_delivery_id is not null then
    select *
    into v_content
    from public.lesson_content_versions lcv
    where lcv.id = v_content.id;
  end if;

  if v_delivery_id is null then
    select *
    into v_content
    from public.lesson_content_versions lcv
    where lcv.lesson_id = v_lesson.id
      and lcv.status = 'published'
    order by lcv.revision_number desc
    limit 1;

    if not found then
      return jsonb_build_object(
        'available', false,
        'lesson', jsonb_build_object(
          'id', v_lesson.id,
          'code', v_lesson.code,
          'title', v_lesson.title,
          'description', v_lesson.description,
          'week_number', v_lesson.week_number,
          'day_number', v_lesson.day_number,
          'sequence', v_lesson.sequence,
          'estimated_minutes', v_lesson.estimated_minutes,
          'lesson_type', v_lesson.lesson_type
        )
      );
    end if;

    perform set_config('app.audit_reason', 'Published lesson revision delivered to student', true);

    insert into public.student_lesson_deliveries (
      organization_id,
      student_id,
      student_course_enrollment_id,
      lesson_id,
      lesson_content_version_id
    )
    values (
      v_enrollment.organization_id,
      v_enrollment.student_id,
      v_enrollment.id,
      v_lesson.id,
      v_content.id
    )
    returning id into v_delivery_id;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'section', i.section,
        'sequence', i.sequence,
        'prompt', i.prompt,
        'student_support', i.student_support,
        'points', i.points
      )
      order by i.section, i.sequence
    ),
    '[]'::jsonb
  )
  into v_items
  from public.lesson_content_items i
  where i.lesson_content_version_id = v_content.id;

  return jsonb_build_object(
    'available', true,
    'delivery_id', v_delivery_id,
    'revision_number', v_content.revision_number,
    'lesson', jsonb_build_object(
      'id', v_lesson.id,
      'code', v_lesson.code,
      'title', v_lesson.title,
      'description', v_lesson.description,
      'week_number', v_lesson.week_number,
      'day_number', v_lesson.day_number,
      'sequence', v_lesson.sequence,
      'estimated_minutes', v_lesson.estimated_minutes,
      'lesson_type', v_lesson.lesson_type
    ),
    'content', jsonb_build_object(
      'student_goal', v_content.student_goal,
      'materials', v_content.materials,
      'vocabulary', v_content.vocabulary,
      'student_learn', v_content.student_learn,
      'guided_practice', v_content.guided_practice,
      'independent_practice', v_content.independent_practice,
      'activity', v_content.activity,
      'worksheet_title', v_content.worksheet_title,
      'worksheet_instructions', v_content.worksheet_instructions,
      'completion_criteria', v_content.completion_criteria
    ),
    'items', v_items
  );
end;
$$;

revoke all on function public.get_my_lesson_delivery(uuid, uuid) from public;
grant execute on function public.get_my_lesson_delivery(uuid, uuid) to authenticated;

commit;
