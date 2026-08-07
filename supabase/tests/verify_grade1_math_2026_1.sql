-- Homeschool Tracker
-- Grade 1 Mathematics 2026.1 verification queries
-- Replace <ORGANIZATION_UUID> before running in Supabase SQL Editor.

with target as (
  select cv.id as course_version_id
  from public.course_versions cv
  where cv.organization_id = '<ORGANIZATION_UUID>'::uuid
    and cv.course_code = '1-MATH'
    and exists (
      select 1 from public.curriculum_releases r
      where r.id = cv.curriculum_release_id and r.version = '2026.1'
    )
)
select
  (select count(*) from public.units u join target t on t.course_version_id = u.course_version_id) as units_expected_8,
  (select count(*) from public.competencies c join target t on t.course_version_id = c.course_version_id) as competencies_expected_21,
  (select count(*) from public.course_weeks w join target t on t.course_version_id = w.course_version_id) as weeks_expected_36,
  (select count(*) from public.lessons l join target t on t.course_version_id = l.course_version_id) as lessons_expected_180,
  (select count(*) from public.assignment_templates a join target t on t.course_version_id = a.course_version_id) as assessments_expected_36;

-- Every week should have exactly five daily lessons.
with target as (
  select cv.id as course_version_id
  from public.course_versions cv
  join public.curriculum_releases r on r.id = cv.curriculum_release_id
  where cv.organization_id = '<ORGANIZATION_UUID>'::uuid
    and cv.course_code = '1-MATH'
    and r.version = '2026.1'
)
select week_number, count(*) as lesson_count
from public.lessons l
join target t on t.course_version_id = l.course_version_id
group by week_number
having count(*) <> 5
order by week_number;

-- Expected result: zero rows.

-- Verify quarter mastery weeks.
with target as (
  select cv.id as course_version_id
  from public.course_versions cv
  join public.curriculum_releases r on r.id = cv.curriculum_release_id
  where cv.organization_id = '<ORGANIZATION_UUID>'::uuid
    and cv.course_code = '1-MATH'
    and r.version = '2026.1'
)
select week_number, quarter, title
from public.course_weeks w
join target t on t.course_version_id = w.course_version_id
where w.is_mastery_check = true
order by week_number;

-- Expected weeks: 9, 18, 27, 36.
