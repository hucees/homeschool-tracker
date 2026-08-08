-- Homeschool Tracker
-- Migration 025: Grade 1 Math quarterly mastery max-points consistency fix
--
-- Corrects the four quarterly mastery templates from 20 max points to the
-- actual 10-point question-bank total.
--
-- Historical safety:
-- * Verifies all four target templates exist.
-- * Verifies each target bank has exactly 10 items totaling 10 points.
-- * Refuses to proceed if any target student assignment already has a grade.
-- * Normalizes already-created ungraded student assignments to 10 points.
-- * Does not alter questions, answers, earned grades, competency evidence,
--   lesson content, or frozen lesson deliveries.

begin;

do $fix$
declare
  v_course record;
  v_target_count integer;
  v_bad_bank_count integer;
  v_graded_assignment_count integer;
begin
  for v_course in
    select cv.id as course_version_id, cv.organization_id
    from public.course_versions cv
    join public.curriculum_releases cr
      on cr.id = cv.curriculum_release_id
    where cv.course_code = '1-MATH'
      and cr.version = '2026.1'
  loop

    select count(*)
    into v_target_count
    from public.assignment_templates at
    where at.course_version_id = v_course.course_version_id
      and at.code in (
        '1-MATH-Q1-MASTERY',
        '1-MATH-Q2-MASTERY',
        '1-MATH-Q3-MASTERY',
        '1-MATH-Q4-MASTERY'
      );

    if v_target_count <> 4 then
      raise exception
        'Expected exactly 4 Grade 1 Math quarterly mastery templates; found %.',
        v_target_count;
    end if;

    select count(*)
    into v_bad_bank_count
    from (
      select
        at.id,
        count(ati.id) as item_count,
        coalesce(sum(ati.points), 0) as point_total
      from public.assignment_templates at
      left join public.assessment_template_items ati
        on ati.assignment_template_id = at.id
      where at.course_version_id = v_course.course_version_id
        and at.code in (
          '1-MATH-Q1-MASTERY',
          '1-MATH-Q2-MASTERY',
          '1-MATH-Q3-MASTERY',
          '1-MATH-Q4-MASTERY'
        )
      group by at.id
      having count(ati.id) <> 10
         or coalesce(sum(ati.points), 0) <> 10
    ) bad_banks;

    if v_bad_bank_count <> 0 then
      raise exception
        'One or more Grade 1 Math quarterly mastery question banks are not exactly 10 items / 10 points.';
    end if;

    select count(*)
    into v_graded_assignment_count
    from public.student_assignments sa
    join public.assignment_templates at
      on at.id = sa.assignment_template_id
    where at.course_version_id = v_course.course_version_id
      and at.code in (
        '1-MATH-Q1-MASTERY',
        '1-MATH-Q2-MASTERY',
        '1-MATH-Q3-MASTERY',
        '1-MATH-Q4-MASTERY'
      )
      and exists (
        select 1
        from public.grade_records gr
        where gr.student_assignment_id = sa.id
      );

    if v_graded_assignment_count <> 0 then
      raise exception
        'Found % already-graded student quarterly mastery assignment(s). Historical scoring requires explicit review.',
        v_graded_assignment_count;
    end if;

    update public.student_assignments sa
    set max_points = 10,
        updated_at = now()
    from public.assignment_templates at
    where at.id = sa.assignment_template_id
      and at.course_version_id = v_course.course_version_id
      and at.code in (
        '1-MATH-Q1-MASTERY',
        '1-MATH-Q2-MASTERY',
        '1-MATH-Q3-MASTERY',
        '1-MATH-Q4-MASTERY'
      )
      and sa.max_points is distinct from 10;

    update public.assignment_templates at
    set max_points = 10,
        updated_at = now()
    where at.course_version_id = v_course.course_version_id
      and at.code in (
        '1-MATH-Q1-MASTERY',
        '1-MATH-Q2-MASTERY',
        '1-MATH-Q3-MASTERY',
        '1-MATH-Q4-MASTERY'
      )
      and at.max_points is distinct from 10;

    if exists (
      select 1
      from public.assignment_templates at
      join lateral (
        select
          count(*) as item_count,
          coalesce(sum(ati.points), 0) as point_total
        from public.assessment_template_items ati
        where ati.assignment_template_id = at.id
      ) bank on true
      where at.course_version_id = v_course.course_version_id
        and at.code in (
          '1-MATH-Q1-MASTERY',
          '1-MATH-Q2-MASTERY',
          '1-MATH-Q3-MASTERY',
          '1-MATH-Q4-MASTERY'
        )
        and (
          at.max_points <> bank.point_total
          or bank.item_count <> 10
          or bank.point_total <> 10
        )
    ) then
      raise exception 'Grade 1 Math mastery max-points postcondition failed.';
    end if;

  end loop;
end;
$fix$;

commit;
