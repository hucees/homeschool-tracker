-- Homeschool Tracker
-- Migration 024: Grade 1 Mathematics Weeks 33–36 production curriculum
--
-- Week 33 : Adding Within 100 II (1-MATH-19)
-- Week 34 : Ten More and Ten Less (1-MATH-20, 90% mastery threshold)
-- Week 35 : Subtracting Multiples of 10 (1-MATH-21)
-- Week 36 : Quarter 4 and Year-End Mastery Check (1-MATH-15..21)
--
-- Installs:
-- * 20 published lesson-content revisions
-- * 300 guided/independent/worksheet items
-- * 40 auto-scored online assessment items
--
-- Historical safety:
-- * one transaction
-- * full Weeks 33–36 preflight before writes
-- * refuses to overwrite published/superseded content
-- * refuses to rewrite frozen student deliveries
-- * refuses to overwrite existing assessment banks
--
-- Mastery policy:
-- 1-MATH-20 retains its configured 90% threshold.
-- Other competencies retain their configured thresholds.
-- Optional models/manipulatives support instruction but no separate hands-on
-- mastery evidence requirement is introduced.

begin;

do $seed$
declare
  v_course record;
  v_week integer;
  v_day integer;
  v_lesson_id uuid;
  v_version_id uuid;
  v_template_id uuid;
  v_expected_code text;
begin
  for v_course in
    select cv.organization_id, cv.id as course_version_id
    from public.course_versions cv
    join public.curriculum_releases cr on cr.id = cv.curriculum_release_id
    where cv.course_code = '1-MATH'
      and cr.version = '2026.1'
  loop

    for v_week in 33..36 loop
      for v_day in 1..5 loop
        v_expected_code := format('1-MATH-W%s-D%s', lpad(v_week::text, 2, '0'), v_day);

        if not exists (
          select 1
          from public.lessons l
          where l.course_version_id = v_course.course_version_id
            and l.code = v_expected_code
        ) then
          raise exception 'Expected lesson % was not found.', v_expected_code;
        end if;
      end loop;

      if exists (
        select 1
        from public.lesson_content_versions lcv
        join public.lessons l on l.id = lcv.lesson_id
        where l.course_version_id = v_course.course_version_id
          and l.week_number = v_week
          and lcv.status in ('published', 'superseded')
      ) then
        raise exception 'Grade 1 Math Week % already has published lesson content. Migration 024 will not overwrite curriculum history.', v_week;
      end if;

      if exists (
        select 1
        from public.student_lesson_deliveries sld
        join public.lessons l on l.id = sld.lesson_id
        where l.course_version_id = v_course.course_version_id
          and l.week_number = v_week
      ) then
        raise exception 'Grade 1 Math Week % has frozen student deliveries. Migration 024 will not rewrite delivered curriculum.', v_week;
      end if;

      select a.id
      into v_template_id
      from public.assignment_templates a
      join public.lessons l on l.id = a.lesson_id
      where a.course_version_id = v_course.course_version_id
        and a.sequence = v_week
        and l.week_number = v_week
        and l.day_number = 5
        and a.active is true
      limit 1;

      if v_template_id is null then
        raise exception 'Expected Grade 1 Math Week % assessment template was not found.', v_week;
      end if;

      if exists (
        select 1
        from public.assessment_template_items ati
        where ati.assignment_template_id = v_template_id
      ) then
        raise exception 'Grade 1 Math Week % already has an online question bank. Migration 024 will not overwrite assessment history.', v_week;
      end if;
    end loop;

    delete from public.lesson_content_versions lcv
    using public.lessons l
    where lcv.lesson_id = l.id
      and l.course_version_id = v_course.course_version_id
      and l.week_number between 33 and 36
      and lcv.status = 'draft';


    -- Week 33, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W33-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W33-D1 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will add within 100 using place-value reasoning, including two-digit plus one-digit and two-digit plus a multiple of 10, and explain how tens and ones change.', 'I can add a one-digit number or a multiple of 10 to a two-digit number.',
      '["pencil", "paper", "optional tens/ones chart or base-ten drawing"]'::jsonb, '[{"term": "tens", "definition": "groups of ten"}, {"term": "ones", "definition": "single units"}, {"term": "place value", "definition": "the value a digit has because of its position"}, {"term": "strategy", "definition": "a useful way to solve a problem"}]'::jsonb,
      'Continue Week 32 by mixing addition types and adding one-digit numbers that may create a new ten.', 'Model one addition that stays within the same ten and one that creates a new ten, then connect each to tens and ones.', 'Week 33 is the second planned evidence week for 1-MATH-19. Repeated qualifying written/online evidence may establish mastery without a separate model-performance requirement.',
      'Use place value: add ones to ones and tens to tens. When the ones total 10 or more, regroup 10 ones as one new ten.', 'Solve three mixed examples together and name the place-value change.', 'Complete mixed addition within 100 independently.',
      'Optional Place-Value Sketch: draw tens and ones before and after one addition problem.', 'Mixed Addition Within 100',
      'Solve each problem and use place-value reasoning to check the result.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately explain one tens-and-ones change.',
      'Use a tens/ones chart during guided work and fade it for independent evidence where appropriate.', 'Create one problem that creates a new ten and explain why.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      'Solve 46 + 3.', null,
      '49', 'Add 3 ones to 6 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Solve 46 + 20.', null,
      '66', 'Add 2 tens; the 6 ones stay the same.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Solve 71 + 8.', null,
      '79', 'Add 8 ones to 1 one.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Solve 32 + 7.', null,
      '39', 'Add 7 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve 32 + 40.', null,
      '72', 'Add 4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 55 + 4.', null,
      '59', 'Add 4 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Solve 55 + 30.', null,
      '85', 'Add 3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '24+5', null,
      '29', 'Add five ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '24+50', null,
      '74', 'Add five tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '61+8', null,
      '69', 'Add eight ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '61+20', null,
      '81', 'Add two tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '73+6', null,
      '79', 'Add six ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '43+40', null,
      '83', 'Add four tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '82+7', null,
      '89', 'Add seven ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '16+70', null,
      '86', 'Add seven tens.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 33, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W33-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W33-D2 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will add within 100 using place-value reasoning, including two-digit plus one-digit and two-digit plus a multiple of 10, and explain how tens and ones change.', 'I can explain how place value changes when I add.',
      '["pencil", "paper", "optional tens/ones chart or base-ten drawing"]'::jsonb, '[{"term": "tens", "definition": "groups of ten"}, {"term": "ones", "definition": "single units"}, {"term": "place value", "definition": "the value a digit has because of its position"}, {"term": "strategy", "definition": "a useful way to solve a problem"}]'::jsonb,
      'Continue Week 32 by mixing addition types and adding one-digit numbers that may create a new ten.', 'Model one addition that stays within the same ten and one that creates a new ten, then connect each to tens and ones.', 'Week 33 is the second planned evidence week for 1-MATH-19. Repeated qualifying written/online evidence may establish mastery without a separate model-performance requirement.',
      'Use place value: add ones to ones and tens to tens. When the ones total 10 or more, regroup 10 ones as one new ten.', 'Solve three mixed examples together and name the place-value change.', 'Complete mixed addition within 100 independently.',
      'Optional Place-Value Sketch: draw tens and ones before and after one addition problem.', 'Explain Tens and Ones',
      'Solve each problem and use place-value reasoning to check the result.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately explain one tens-and-ones change.',
      'Use a tens/ones chart during guided work and fade it for independent evidence where appropriate.', 'Create one problem that creates a new ten and explain why.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      'Explain 34 + 5 using tens and ones.', null,
      '39', '3 tens stay the same; 4 ones + 5 ones = 9 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Explain 34 + 20 using tens and ones.', null,
      '54', '3 tens + 2 tens = 5 tens; 4 ones stay the same.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'In 62 + 7, which place changes?', null,
      'ones', 'The ones change from 2 to 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'In 62 + 30, which place changes?', null,
      'tens', 'The tens change from 6 to 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve 41 + 8 and name the place that changes.', null,
      '49; ones', '4 tens remain; ones become 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 41 + 50 and name the place that changes.', null,
      '91; tens', '1 one stays; tens become 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Why does the ones digit stay the same in 27+40?', null,
      'because 40 adds only tens', 'Four tens are added and no ones are added.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '35+4', null,
      '39', 'Only ones change.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '35+40', null,
      '75', 'Only tens change.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '52+7', null,
      '59', 'Only ones change.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '52+30', null,
      '82', 'Only tens change.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Which place changes in 68+1?', null,
      'ones', 'One one is added.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Which place changes in 68+20?', null,
      'tens', 'Two tens are added.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Explain 23+60.', null,
      '83', '2 tens + 6 tens = 8 tens; 3 ones stay.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Explain 74+5.', null,
      '79', '7 tens stay; 4 ones + 5 ones = 9 ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 33, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W33-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W33-D3 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will add within 100 using place-value reasoning, including two-digit plus one-digit and two-digit plus a multiple of 10, and explain how tens and ones change.', 'I can add ones even when the ones make a new ten.',
      '["pencil", "paper", "optional tens/ones chart or base-ten drawing"]'::jsonb, '[{"term": "tens", "definition": "groups of ten"}, {"term": "ones", "definition": "single units"}, {"term": "place value", "definition": "the value a digit has because of its position"}, {"term": "strategy", "definition": "a useful way to solve a problem"}]'::jsonb,
      'Continue Week 32 by mixing addition types and adding one-digit numbers that may create a new ten.', 'Model one addition that stays within the same ten and one that creates a new ten, then connect each to tens and ones.', 'Week 33 is the second planned evidence week for 1-MATH-19. Repeated qualifying written/online evidence may establish mastery without a separate model-performance requirement.',
      'Use place value: add ones to ones and tens to tens. When the ones total 10 or more, regroup 10 ones as one new ten.', 'Solve three mixed examples together and name the place-value change.', 'Complete mixed addition within 100 independently.',
      'Optional Place-Value Sketch: draw tens and ones before and after one addition problem.', 'Add Ones Across a New Ten',
      'Solve each problem and use place-value reasoning to check the result.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately explain one tens-and-ones change.',
      'Use a tens/ones chart during guided work and fade it for independent evidence where appropriate.', 'Create one problem that creates a new ten and explain why.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      'For 28+6, should you think mainly about tens or ones?', null,
      'ones', 'A one-digit addend changes the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'For 28+40, should you think mainly about tens or ones?', null,
      'tens', 'A multiple of 10 changes the tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Solve 28+6.', null,
      '34', '8+6=14 ones, which makes 1 more ten and 4 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Solve 47+5.', null,
      '52', '7+5=12 ones, so regroup as 1 ten 2 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve 58+4.', null,
      '62', '8+4=12 ones, making one new ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 39+30.', null,
      '69', 'Add three tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Solve 26+50.', null,
      '76', 'Add five tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '29+4', null,
      '33', '9+4=13 ones; regroup.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '38+5', null,
      '43', '8+5=13 ones; regroup.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '49+3', null,
      '52', '9+3=12 ones; regroup.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '57+6', null,
      '63', '7+6=13 ones; regroup.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '36+40', null,
      '76', 'Add four tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '45+30', null,
      '75', 'Add three tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '18+70', null,
      '88', 'Add seven tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '64+20', null,
      '84', 'Add two tens.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 33, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W33-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W33-D4 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will add within 100 using place-value reasoning, including two-digit plus one-digit and two-digit plus a multiple of 10, and explain how tens and ones change.', 'I can choose a useful place-value strategy and explain it.',
      '["pencil", "paper", "optional tens/ones chart or base-ten drawing"]'::jsonb, '[{"term": "tens", "definition": "groups of ten"}, {"term": "ones", "definition": "single units"}, {"term": "place value", "definition": "the value a digit has because of its position"}, {"term": "strategy", "definition": "a useful way to solve a problem"}]'::jsonb,
      'Continue Week 32 by mixing addition types and adding one-digit numbers that may create a new ten.', 'Model one addition that stays within the same ten and one that creates a new ten, then connect each to tens and ones.', 'Week 33 is the second planned evidence week for 1-MATH-19. Repeated qualifying written/online evidence may establish mastery without a separate model-performance requirement.',
      'Use place value: add ones to ones and tens to tens. When the ones total 10 or more, regroup 10 ones as one new ten.', 'Solve three mixed examples together and name the place-value change.', 'Complete mixed addition within 100 independently.',
      'Optional Place-Value Sketch: draw tens and ones before and after one addition problem.', 'Apply Place-Value Addition Strategies',
      'Solve each problem and use place-value reasoning to check the result.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately explain one tens-and-ones change.',
      'Use a tens/ones chart during guided work and fade it for independent evidence where appropriate.', 'Create one problem that creates a new ten and explain why.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      'Solve 37+5.', null,
      '42', 'Regroup 12 ones as 1 ten 2 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Solve 37+40.', null,
      '77', 'Add four tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Solve 64+8.', null,
      '72', '4+8=12 ones, making another ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Solve 29+6.', null,
      '35', '9+6=15 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve 53+30.', null,
      '83', 'Add three tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 48+4.', null,
      '52', '8+4=12 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Solve 17+60.', null,
      '77', 'Add six tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '26+7', null,
      '33', '6+7=13 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '26+50', null,
      '76', 'Add five tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '39+5', null,
      '44', '9+5=14 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '42+40', null,
      '82', 'Add four tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '58+3', null,
      '61', '8+3=11 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '71+20', null,
      '91', 'Add two tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '67+6', null,
      '73', '7+6=13 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '14+80', null,
      '94', 'Add eight tens.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 33, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W33-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W33-D5 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will add within 100 using place-value reasoning, including two-digit plus one-digit and two-digit plus a multiple of 10, and explain how tens and ones change.', 'I can independently add within 100 using place value.',
      '["pencil", "paper", "optional tens/ones chart or base-ten drawing"]'::jsonb, '[{"term": "tens", "definition": "groups of ten"}, {"term": "ones", "definition": "single units"}, {"term": "place value", "definition": "the value a digit has because of its position"}, {"term": "strategy", "definition": "a useful way to solve a problem"}]'::jsonb,
      'Continue Week 32 by mixing addition types and adding one-digit numbers that may create a new ten.', 'Model one addition that stays within the same ten and one that creates a new ten, then connect each to tens and ones.', 'Week 33 is the second planned evidence week for 1-MATH-19. Repeated qualifying written/online evidence may establish mastery without a separate model-performance requirement.',
      'Use place value: add ones to ones and tens to tens. When the ones total 10 or more, regroup 10 ones as one new ten.', 'Solve three mixed examples together and name the place-value change.', 'Complete mixed addition within 100 independently.',
      'Optional Place-Value Sketch: draw tens and ones before and after one addition problem.', 'Week 33 Addition Mastery Readiness',
      'Solve each problem and use place-value reasoning to check the result.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately explain one tens-and-ones change.',
      'Use a tens/ones chart during guided work and fade it for independent evidence where appropriate.', 'Create one problem that creates a new ten and explain why.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      'Solve 37+5.', null,
      '42', 'Regroup 12 ones as 1 ten 2 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Solve 37+40.', null,
      '77', 'Add four tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Solve 64+8.', null,
      '72', '4+8=12 ones, making another ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Solve 29+6.', null,
      '35', '9+6=15 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve 53+30.', null,
      '83', 'Add three tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 48+4.', null,
      '52', '8+4=12 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Solve 17+60.', null,
      '77', 'Add six tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '26+7', null,
      '33', '6+7=13 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '26+50', null,
      '76', 'Add five tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '39+5', null,
      '44', '9+5=14 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '42+40', null,
      '82', 'Add four tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '58+3', null,
      '61', '8+3=11 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '71+20', null,
      '91', 'Add two tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '67+6', null,
      '73', '7+6=13 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '14+80', null,
      '94', 'Add eight tens.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 34, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W34-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W34-D1 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will mentally determine 10 more or 10 less than a two-digit number and explain that the tens digit changes while the ones digit remains the same.', 'I can mentally find 10 more than a two-digit number.',
      '["pencil", "paper", "optional hundred chart for instruction only"]'::jsonb, '[{"term": "10 more", "definition": "one more group of ten"}, {"term": "10 less", "definition": "one fewer group of ten"}, {"term": "tens digit", "definition": "the digit showing how many tens"}, {"term": "ones digit", "definition": "the digit showing how many ones"}]'::jsonb,
      'Connect the task to place value rather than teaching it as a memorized number pattern.', 'Model adding or removing one group of ten while leaving the ones untouched.', '1-MATH-20 uses a 90% mastery threshold across two demonstrations. Accuracy and place-value understanding matter more than speed alone.',
      'For 10 more, add one ten. For 10 less, remove one ten. The ones digit stays the same because no ones are added or removed.', 'Solve three examples together and identify what changes.', 'Complete mixed 10-more/10-less work independently.',
      'Number Shift: write a number, then its 10-less and 10-more neighbors.', 'Find 10 More',
      'Find 10 more or 10 less mentally and notice the place-value pattern.', 'Complete at least 8 of 8 worksheet items correctly after corrections during practice; Week 34 mastery evidence uses the configured 90% threshold.',
      'Use a place-value chart or hundred chart during instruction, then fade it for independent evidence.', 'Explain why 47, 57, and 67 all have the same ones digit.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      'What is 10 more than 24?', null,
      '34', 'Add one ten; ones stay 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'What is 10 more than 51?', null,
      '61', 'Add one ten; ones stay 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'What is 10 more than 68?', null,
      '78', 'Add one ten; ones stay 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      '10 more than 13?', null,
      '23', 'Increase tens by 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      '10 more than 37?', null,
      '47', 'Increase tens by 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      '10 more than 72?', null,
      '82', 'Increase tens by 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      '10 more than 85?', null,
      '95', 'Increase tens by 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '10 more than 12', null,
      '22', 'Tens increase; ones stay 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '10 more than 25', null,
      '35', 'Ones stay 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '10 more than 33', null,
      '43', 'Ones stay 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '10 more than 46', null,
      '56', 'Ones stay 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '10 more than 57', null,
      '67', 'Ones stay 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '10 more than 64', null,
      '74', 'Ones stay 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '10 more than 79', null,
      '89', 'Ones stay 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '10 more than 88', null,
      '98', 'Ones stay 8.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 34, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W34-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W34-D2 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will mentally determine 10 more or 10 less than a two-digit number and explain that the tens digit changes while the ones digit remains the same.', 'I can mentally find 10 less than a two-digit number.',
      '["pencil", "paper", "optional hundred chart for instruction only"]'::jsonb, '[{"term": "10 more", "definition": "one more group of ten"}, {"term": "10 less", "definition": "one fewer group of ten"}, {"term": "tens digit", "definition": "the digit showing how many tens"}, {"term": "ones digit", "definition": "the digit showing how many ones"}]'::jsonb,
      'Connect the task to place value rather than teaching it as a memorized number pattern.', 'Model adding or removing one group of ten while leaving the ones untouched.', '1-MATH-20 uses a 90% mastery threshold across two demonstrations. Accuracy and place-value understanding matter more than speed alone.',
      'For 10 more, add one ten. For 10 less, remove one ten. The ones digit stays the same because no ones are added or removed.', 'Solve three examples together and identify what changes.', 'Complete mixed 10-more/10-less work independently.',
      'Number Shift: write a number, then its 10-less and 10-more neighbors.', 'Find 10 Less',
      'Find 10 more or 10 less mentally and notice the place-value pattern.', 'Complete at least 8 of 8 worksheet items correctly after corrections during practice; Week 34 mastery evidence uses the configured 90% threshold.',
      'Use a place-value chart or hundred chart during instruction, then fade it for independent evidence.', 'Explain why 47, 57, and 67 all have the same ones digit.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      'What is 10 less than 34?', null,
      '24', 'Remove one ten; ones stay 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'What is 10 less than 61?', null,
      '51', 'Remove one ten; ones stay 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'What is 10 less than 78?', null,
      '68', 'Remove one ten; ones stay 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      '10 less than 23?', null,
      '13', 'Decrease tens by 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      '10 less than 47?', null,
      '37', 'Decrease tens by 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      '10 less than 82?', null,
      '72', 'Decrease tens by 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      '10 less than 95?', null,
      '85', 'Decrease tens by 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '10 less than 22', null,
      '12', 'Tens decrease; ones stay 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '10 less than 35', null,
      '25', 'Ones stay 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '10 less than 43', null,
      '33', 'Ones stay 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '10 less than 56', null,
      '46', 'Ones stay 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '10 less than 67', null,
      '57', 'Ones stay 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '10 less than 74', null,
      '64', 'Ones stay 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '10 less than 89', null,
      '79', 'Ones stay 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '10 less than 98', null,
      '88', 'Ones stay 8.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 34, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W34-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W34-D3 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will mentally determine 10 more or 10 less than a two-digit number and explain that the tens digit changes while the ones digit remains the same.', 'I can switch between 10 more and 10 less.',
      '["pencil", "paper", "optional hundred chart for instruction only"]'::jsonb, '[{"term": "10 more", "definition": "one more group of ten"}, {"term": "10 less", "definition": "one fewer group of ten"}, {"term": "tens digit", "definition": "the digit showing how many tens"}, {"term": "ones digit", "definition": "the digit showing how many ones"}]'::jsonb,
      'Connect the task to place value rather than teaching it as a memorized number pattern.', 'Model adding or removing one group of ten while leaving the ones untouched.', '1-MATH-20 uses a 90% mastery threshold across two demonstrations. Accuracy and place-value understanding matter more than speed alone.',
      'For 10 more, add one ten. For 10 less, remove one ten. The ones digit stays the same because no ones are added or removed.', 'Solve three examples together and identify what changes.', 'Complete mixed 10-more/10-less work independently.',
      'Number Shift: write a number, then its 10-less and 10-more neighbors.', 'Mix 10 More and 10 Less',
      'Find 10 more or 10 less mentally and notice the place-value pattern.', 'Complete at least 8 of 8 worksheet items correctly after corrections during practice; Week 34 mastery evidence uses the configured 90% threshold.',
      'Use a place-value chart or hundred chart during instruction, then fade it for independent evidence.', 'Explain why 47, 57, and 67 all have the same ones digit.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      '10 more than 32?', null,
      '42', 'Tens increase by 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      '10 less than 32?', null,
      '22', 'Tens decrease by 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'What stays the same when finding 10 more or 10 less?', null,
      'ones digit', 'Only the tens count changes by one group of ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      '10 more than 45?', null,
      '55', 'Ones remain 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      '10 less than 45?', null,
      '35', 'Ones remain 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      '10 more than 76?', null,
      '86', 'Tens increase.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      '10 less than 76?', null,
      '66', 'Tens decrease.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '10 more than 14', null,
      '24', 'One more ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '10 less than 24', null,
      '14', 'One fewer ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '10 more than 39', null,
      '49', 'Ones remain 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '10 less than 49', null,
      '39', 'Ones remain 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '10 more than 63', null,
      '73', 'One more ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '10 less than 73', null,
      '63', 'One fewer ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'In 52→62, which digit changed?', null,
      'tens digit', '5 tens became 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'In 87→77, which digit stayed the same?', null,
      'ones digit', 'The 7 ones remained 7.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 34, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W34-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W34-D4 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will mentally determine 10 more or 10 less than a two-digit number and explain that the tens digit changes while the ones digit remains the same.', 'I can explain why the tens digit changes and the ones digit stays the same.',
      '["pencil", "paper", "optional hundred chart for instruction only"]'::jsonb, '[{"term": "10 more", "definition": "one more group of ten"}, {"term": "10 less", "definition": "one fewer group of ten"}, {"term": "tens digit", "definition": "the digit showing how many tens"}, {"term": "ones digit", "definition": "the digit showing how many ones"}]'::jsonb,
      'Connect the task to place value rather than teaching it as a memorized number pattern.', 'Model adding or removing one group of ten while leaving the ones untouched.', '1-MATH-20 uses a 90% mastery threshold across two demonstrations. Accuracy and place-value understanding matter more than speed alone.',
      'For 10 more, add one ten. For 10 less, remove one ten. The ones digit stays the same because no ones are added or removed.', 'Solve three examples together and identify what changes.', 'Complete mixed 10-more/10-less work independently.',
      'Number Shift: write a number, then its 10-less and 10-more neighbors.', 'Explain the Place-Value Pattern',
      'Find 10 more or 10 less mentally and notice the place-value pattern.', 'Complete at least 8 of 8 worksheet items correctly after corrections during practice; Week 34 mastery evidence uses the configured 90% threshold.',
      'Use a place-value chart or hundred chart during instruction, then fade it for independent evidence.', 'Explain why 47, 57, and 67 all have the same ones digit.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      '10 more than 27?', null,
      '37', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      '10 less than 57?', null,
      '47', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      '10 more than 64?', null,
      '74', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      '10 less than 84?', null,
      '74', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      '10 more than 18?', null,
      '28', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      '10 less than 68?', null,
      '58', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      '10 more than 71?', null,
      '81', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '10 more than 31', null,
      '41', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '10 less than 41', null,
      '31', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '10 more than 56', null,
      '66', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '10 less than 66', null,
      '56', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '10 more than 79', null,
      '89', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '10 less than 89', null,
      '79', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '10 more than 42', null,
      '52', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '10 less than 92', null,
      '82', 'Subtract one ten.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 34, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W34-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W34-D5 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will mentally determine 10 more or 10 less than a two-digit number and explain that the tens digit changes while the ones digit remains the same.', 'I can find 10 more and 10 less accurately and efficiently.',
      '["pencil", "paper", "optional hundred chart for instruction only"]'::jsonb, '[{"term": "10 more", "definition": "one more group of ten"}, {"term": "10 less", "definition": "one fewer group of ten"}, {"term": "tens digit", "definition": "the digit showing how many tens"}, {"term": "ones digit", "definition": "the digit showing how many ones"}]'::jsonb,
      'Connect the task to place value rather than teaching it as a memorized number pattern.', 'Model adding or removing one group of ten while leaving the ones untouched.', '1-MATH-20 uses a 90% mastery threshold across two demonstrations. Accuracy and place-value understanding matter more than speed alone.',
      'For 10 more, add one ten. For 10 less, remove one ten. The ones digit stays the same because no ones are added or removed.', 'Solve three examples together and identify what changes.', 'Complete mixed 10-more/10-less work independently.',
      'Number Shift: write a number, then its 10-less and 10-more neighbors.', 'Week 34 Ten More/Ten Less Mastery Readiness',
      'Find 10 more or 10 less mentally and notice the place-value pattern.', 'Complete at least 8 of 8 worksheet items correctly after corrections during practice; Week 34 mastery evidence uses the configured 90% threshold.',
      'Use a place-value chart or hundred chart during instruction, then fade it for independent evidence.', 'Explain why 47, 57, and 67 all have the same ones digit.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      '10 more than 27?', null,
      '37', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      '10 less than 57?', null,
      '47', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      '10 more than 64?', null,
      '74', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      '10 less than 84?', null,
      '74', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      '10 more than 18?', null,
      '28', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      '10 less than 68?', null,
      '58', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      '10 more than 71?', null,
      '81', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '10 more than 31', null,
      '41', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '10 less than 41', null,
      '31', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '10 more than 56', null,
      '66', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '10 less than 66', null,
      '56', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '10 more than 79', null,
      '89', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '10 less than 89', null,
      '79', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '10 more than 42', null,
      '52', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '10 less than 92', null,
      '82', 'Subtract one ten.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 35, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W35-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W35-D1 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will subtract multiples of 10 within 10–90 using place-value reasoning or related facts and explain the tens-based strategy.', 'I can subtract multiples of 10 by thinking in tens.',
      '["pencil", "paper", "optional tens rods or tens drawings"]'::jsonb, '[{"term": "multiple of 10", "definition": "a number made of whole tens, such as 20, 50, or 80"}, {"term": "difference", "definition": "the result of subtraction"}, {"term": "tens", "definition": "groups of ten"}, {"term": "related fact", "definition": "a basic fact that helps solve a larger place-value problem"}]'::jsonb,
      'Connect 60−20 to the familiar basic fact 6−2, while making clear that the quantities are tens.', 'Model renaming each number as tens, subtracting the tens, then translating the result back to a multiple of 10.', 'Models are optional instructional supports. Repeated qualifying evidence remains sufficient for mastery.',
      'Treat each multiple of 10 as a number of tens. Example: 80−30 means 8 tens−3 tens=5 tens=50.', 'Solve three tens-subtraction examples together.', 'Complete multiples-of-10 subtraction independently.',
      'Tens Fact Match: pair a problem such as 70−30 with the related basic fact 7−3.', 'Subtract Whole Tens',
      'Subtract each multiple of 10 and use place value to check.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one answer in tens.',
      'Use tens drawings or related basic facts during guided instruction.', 'Create three different subtraction-of-tens equations with the same difference.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      'Solve 60 − 20.', null,
      '40', '6 tens − 2 tens = 4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Solve 80 − 30.', null,
      '50', '8 tens − 3 tens = 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Solve 50 − 10.', null,
      '40', '5 tens − 1 ten = 4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      '70−20', null,
      '50', '7 tens − 2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      '90−40', null,
      '50', '9 tens − 4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      '40−30', null,
      '10', '4 tens − 3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      '30−10', null,
      '20', '3 tens − 1 ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '20−10', null,
      '10', '2 tens − 1 ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '40−20', null,
      '20', '4 tens − 2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '60−30', null,
      '30', '6 tens − 3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '80−50', null,
      '30', '8 tens − 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '90−20', null,
      '70', '9 tens − 2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '70−40', null,
      '30', '7 tens − 4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '50−30', null,
      '20', '5 tens − 3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '90−60', null,
      '30', '9 tens − 6 tens.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 35, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W35-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W35-D2 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will subtract multiples of 10 within 10–90 using place-value reasoning or related facts and explain the tens-based strategy.', 'I can use a basic subtraction fact to subtract tens.',
      '["pencil", "paper", "optional tens rods or tens drawings"]'::jsonb, '[{"term": "multiple of 10", "definition": "a number made of whole tens, such as 20, 50, or 80"}, {"term": "difference", "definition": "the result of subtraction"}, {"term": "tens", "definition": "groups of ten"}, {"term": "related fact", "definition": "a basic fact that helps solve a larger place-value problem"}]'::jsonb,
      'Connect 60−20 to the familiar basic fact 6−2, while making clear that the quantities are tens.', 'Model renaming each number as tens, subtracting the tens, then translating the result back to a multiple of 10.', 'Models are optional instructional supports. Repeated qualifying evidence remains sufficient for mastery.',
      'Treat each multiple of 10 as a number of tens. Example: 80−30 means 8 tens−3 tens=5 tens=50.', 'Solve three tens-subtraction examples together.', 'Complete multiples-of-10 subtraction independently.',
      'Tens Fact Match: pair a problem such as 70−30 with the related basic fact 7−3.', 'Use Related Basic Facts',
      'Subtract each multiple of 10 and use place value to check.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one answer in tens.',
      'Use tens drawings or related basic facts during guided instruction.', 'Create three different subtraction-of-tens equations with the same difference.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      'Use 6−2=4 to solve 60−20.', null,
      '40', 'The basic fact works with tens: 6 tens−2 tens=4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Use 8−3=5 to solve 80−30.', null,
      '50', '8 tens−3 tens=5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Use 9−4=5 to solve 90−40.', null,
      '50', '9 tens−4 tens=5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Use 7−2=5 to solve 70−20.', null,
      '50', '5 tens=50.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Use 5−3=2 to solve 50−30.', null,
      '20', '2 tens=20.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Use 9−6=3 to solve 90−60.', null,
      '30', '3 tens=30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Use 4−1=3 to solve 40−10.', null,
      '30', '3 tens=30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '3−1=2 helps solve 30−10 = ?', null,
      '20', '2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '6−4=2 helps solve 60−40 = ?', null,
      '20', '2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '8−6=2 helps solve 80−60 = ?', null,
      '20', '2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '9−7=2 helps solve 90−70 = ?', null,
      '20', '2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '7−3=4 helps solve 70−30 = ?', null,
      '40', '4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '5−2=3 helps solve 50−20 = ?', null,
      '30', '3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '8−5=3 helps solve 80−50 = ?', null,
      '30', '3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '9−2=7 helps solve 90−20 = ?', null,
      '70', '7 tens.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 35, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W35-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W35-D3 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will subtract multiples of 10 within 10–90 using place-value reasoning or related facts and explain the tens-based strategy.', 'I can explain subtraction with tens and place value.',
      '["pencil", "paper", "optional tens rods or tens drawings"]'::jsonb, '[{"term": "multiple of 10", "definition": "a number made of whole tens, such as 20, 50, or 80"}, {"term": "difference", "definition": "the result of subtraction"}, {"term": "tens", "definition": "groups of ten"}, {"term": "related fact", "definition": "a basic fact that helps solve a larger place-value problem"}]'::jsonb,
      'Connect 60−20 to the familiar basic fact 6−2, while making clear that the quantities are tens.', 'Model renaming each number as tens, subtracting the tens, then translating the result back to a multiple of 10.', 'Models are optional instructional supports. Repeated qualifying evidence remains sufficient for mastery.',
      'Treat each multiple of 10 as a number of tens. Example: 80−30 means 8 tens−3 tens=5 tens=50.', 'Solve three tens-subtraction examples together.', 'Complete multiples-of-10 subtraction independently.',
      'Tens Fact Match: pair a problem such as 70−30 with the related basic fact 7−3.', 'Explain the Tens Strategy',
      'Subtract each multiple of 10 and use place value to check.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one answer in tens.',
      'Use tens drawings or related basic facts during guided instruction.', 'Create three different subtraction-of-tens equations with the same difference.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      'Explain 70−30 in tens.', null,
      '40', '7 tens−3 tens=4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Explain 90−50 in tens.', null,
      '40', '9 tens−5 tens=4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'What stays zero in 80−20?', null,
      'ones', 'Both numbers have 0 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Solve and explain 60−40.', null,
      '20', '6 tens−4 tens=2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve and explain 50−20.', null,
      '30', '5 tens−2 tens=3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve and explain 90−30.', null,
      '60', '9 tens−3 tens=6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Why can 8−3 help with 80−30?', null,
      'because the larger problem is 8 tens minus 3 tens', 'Place value scales the basic fact by tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '40−10', null,
      '30', '4 tens−1 ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '50−40', null,
      '10', '5 tens−4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '70−50', null,
      '20', '7 tens−5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '80−30', null,
      '50', '8 tens−3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '90−70', null,
      '20', '9 tens−7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'What unit are we subtracting in 60−20?', null,
      'tens', 'Both are whole tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Related basic fact for 70−20?', null,
      '7−2=5', 'The tens fact matches the ones fact.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Explain 30−20.', null,
      '10', '3 tens−2 tens=1 ten.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 35, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W35-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W35-D4 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will subtract multiples of 10 within 10–90 using place-value reasoning or related facts and explain the tens-based strategy.', 'I can solve mixed whole-tens subtraction problems.',
      '["pencil", "paper", "optional tens rods or tens drawings"]'::jsonb, '[{"term": "multiple of 10", "definition": "a number made of whole tens, such as 20, 50, or 80"}, {"term": "difference", "definition": "the result of subtraction"}, {"term": "tens", "definition": "groups of ten"}, {"term": "related fact", "definition": "a basic fact that helps solve a larger place-value problem"}]'::jsonb,
      'Connect 60−20 to the familiar basic fact 6−2, while making clear that the quantities are tens.', 'Model renaming each number as tens, subtracting the tens, then translating the result back to a multiple of 10.', 'Models are optional instructional supports. Repeated qualifying evidence remains sufficient for mastery.',
      'Treat each multiple of 10 as a number of tens. Example: 80−30 means 8 tens−3 tens=5 tens=50.', 'Solve three tens-subtraction examples together.', 'Complete multiples-of-10 subtraction independently.',
      'Tens Fact Match: pair a problem such as 70−30 with the related basic fact 7−3.', 'Practice Multiples-of-10 Subtraction',
      'Subtract each multiple of 10 and use place value to check.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one answer in tens.',
      'Use tens drawings or related basic facts during guided instruction.', 'Create three different subtraction-of-tens equations with the same difference.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      '60−10', null,
      '50', '6 tens−1 ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      '80−40', null,
      '40', '8 tens−4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      '90−30', null,
      '60', '9 tens−3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      '50−20', null,
      '30', '5 tens−2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      '70−60', null,
      '10', '7 tens−6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      '40−30', null,
      '10', '4 tens−3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      '90−50', null,
      '40', '9 tens−5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '20−10', null,
      '10', '2 tens−1 ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '30−20', null,
      '10', '3 tens−2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '60−50', null,
      '10', '6 tens−5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '70−40', null,
      '30', '7 tens−4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '80−20', null,
      '60', '8 tens−2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '90−80', null,
      '10', '9 tens−8 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '50−10', null,
      '40', '5 tens−1 ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '90−40', null,
      '50', '9 tens−4 tens.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 35, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W35-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W35-D5 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will subtract multiples of 10 within 10–90 using place-value reasoning or related facts and explain the tens-based strategy.', 'I can subtract multiples of 10 independently.',
      '["pencil", "paper", "optional tens rods or tens drawings"]'::jsonb, '[{"term": "multiple of 10", "definition": "a number made of whole tens, such as 20, 50, or 80"}, {"term": "difference", "definition": "the result of subtraction"}, {"term": "tens", "definition": "groups of ten"}, {"term": "related fact", "definition": "a basic fact that helps solve a larger place-value problem"}]'::jsonb,
      'Connect 60−20 to the familiar basic fact 6−2, while making clear that the quantities are tens.', 'Model renaming each number as tens, subtracting the tens, then translating the result back to a multiple of 10.', 'Models are optional instructional supports. Repeated qualifying evidence remains sufficient for mastery.',
      'Treat each multiple of 10 as a number of tens. Example: 80−30 means 8 tens−3 tens=5 tens=50.', 'Solve three tens-subtraction examples together.', 'Complete multiples-of-10 subtraction independently.',
      'Tens Fact Match: pair a problem such as 70−30 with the related basic fact 7−3.', 'Week 35 Subtraction Mastery Readiness',
      'Subtract each multiple of 10 and use place value to check.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one answer in tens.',
      'Use tens drawings or related basic facts during guided instruction.', 'Create three different subtraction-of-tens equations with the same difference.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      '60−10', null,
      '50', '6 tens−1 ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      '80−40', null,
      '40', '8 tens−4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      '90−30', null,
      '60', '9 tens−3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      '50−20', null,
      '30', '5 tens−2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      '70−60', null,
      '10', '7 tens−6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      '40−30', null,
      '10', '4 tens−3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      '90−50', null,
      '40', '9 tens−5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '20−10', null,
      '10', '2 tens−1 ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '30−20', null,
      '10', '3 tens−2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '60−50', null,
      '10', '6 tens−5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '70−40', null,
      '30', '7 tens−4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '80−20', null,
      '60', '8 tens−2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '90−80', null,
      '10', '9 tens−8 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '50−10', null,
      '40', '5 tens−1 ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '90−40', null,
      '50', '9 tens−4 tens.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 36, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W36-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W36-D1 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently review and demonstrate Quarter 4 competencies 1-MATH-15 through 1-MATH-21 in preparation for the year-end mastery check.', 'I can organize, represent, and interpret data.',
      '["pencil", "scratch paper"]'::jsonb, '[{"term": "data", "definition": "collected information"}, {"term": "attribute", "definition": "a feature that describes a shape"}, {"term": "equal shares", "definition": "parts of a whole that are the same size"}, {"term": "place value", "definition": "the value of a digit based on its position"}]'::jsonb,
      'Explain that Week 36 is cumulative: the goal is to show retained understanding across the final-quarter skills.', 'Model one neutral example from the day''s focus, then transition quickly to independent work.', 'Week 36 is mapped to 1-MATH-15 through 1-MATH-21. Interpret evidence using each competency''s configured threshold; 1-MATH-20 remains 90% while the others in this group are 85%. No separate hands-on evidence requirement is introduced.',
      'Use the skill that fits the problem: organize data, reason from shape attributes/equal shares, use place value for addition, find 10 more/less, or subtract whole tens.', 'Complete three brief review examples together.', 'Complete cumulative review work independently.',
      'Year-End Reflection: name one Grade 1 Math skill you can now explain to someone else.', 'Year-End Review — Data and Graphs',
      'Complete each year-end review item independently and check your reasoning.', 'Complete the Week 36 online year-end mastery assessment independently. Apply existing repeated-evidence rules and each competency''s configured mastery threshold.',
      'Use normal accommodations without supplying operations, categories, attributes, or answers.', 'Create one question from a Quarter 4 skill and solve it two ways when possible.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      'Table: Red=5, Blue=3. How many more Red?', null,
      '2', '5−3=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Graph counts: Cats=2, Dogs=4, Fish=1. Total?', null,
      '7', '2+4+1=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Data A=3, B=6. Which graph row should be longer?', null,
      'B', '6>3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Table: Books=4, Games=2. Difference?', null,
      '2', '4−2=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Graph: Apples=3, Pears=3. Compare.', null,
      'same number', 'Equal counts.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Data Red=2, Blue=5, Green=1. Total?', null,
      '8', '2+5+1=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'If 1 symbol=1 response and a category has 6 responses, symbols needed?', null,
      '6', 'One-for-one graphing.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Cats=5, Dogs=2. How many fewer Dogs?', null,
      '3', '5−2=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'A=4, B=4. Compare.', null,
      'same number', 'Equal counts.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'A=2, B=7. Which graph row is longest?', null,
      'B', '7 is greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Red=3, Blue=2, Green=4. Total?', null,
      '9', '3+2+4=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'A graph row has 5 one-for-one symbols. What count?', null,
      '5', 'Each symbol represents one.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Why label categories?', null,
      'so the reader knows what the data groups represent', 'Labels identify the groups.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Table A=6, B=1. Difference?', null,
      '5', '6−1=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Which is least: 4, 2, 5?', null,
      '2', '2 is smallest.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 36, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W36-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W36-D2 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently review and demonstrate Quarter 4 competencies 1-MATH-15 through 1-MATH-21 in preparation for the year-end mastery check.', 'I can reason about shapes, halves, and fourths.',
      '["pencil", "scratch paper"]'::jsonb, '[{"term": "data", "definition": "collected information"}, {"term": "attribute", "definition": "a feature that describes a shape"}, {"term": "equal shares", "definition": "parts of a whole that are the same size"}, {"term": "place value", "definition": "the value of a digit based on its position"}]'::jsonb,
      'Explain that Week 36 is cumulative: the goal is to show retained understanding across the final-quarter skills.', 'Model one neutral example from the day''s focus, then transition quickly to independent work.', 'Week 36 is mapped to 1-MATH-15 through 1-MATH-21. Interpret evidence using each competency''s configured threshold; 1-MATH-20 remains 90% while the others in this group are 85%. No separate hands-on evidence requirement is introduced.',
      'Use the skill that fits the problem: organize data, reason from shape attributes/equal shares, use place value for addition, find 10 more/less, or subtract whole tens.', 'Complete three brief review examples together.', 'Complete cumulative review work independently.',
      'Year-End Reflection: name one Grade 1 Math skill you can now explain to someone else.', 'Year-End Review — Shapes and Equal Shares',
      'Complete each year-end review item independently and check your reasoning.', 'Complete the Week 36 online year-end mastery assessment independently. Apply existing repeated-evidence rules and each competency''s configured mastery threshold.',
      'Use normal accommodations without supplying operations, categories, attributes, or answers.', 'Create one question from a Quarter 4 skill and solve it two ways when possible.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      'Which 2D shape has 3 sides?', null,
      'triangle', 'Three sides define a triangle.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Which 3D shape has 6 square faces?', null,
      'cube', 'A cube has six square faces.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Two equal shares of a whole are called what?', null,
      'halves', 'Two equal shares are halves.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Four equal shares are called what?', null,
      'fourths', 'Also called quarters.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Can unequal pieces be halves?', null,
      'no', 'Halves must be equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Which shape has no vertices: triangle or circle?', null,
      'circle', 'A circle has no corners.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'A square cut diagonally forms two what?', null,
      'triangles', 'The diagonal divides it into two triangles.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'How many sides on a rectangle?', null,
      '4', 'Four sides.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'How many vertices on a triangle?', null,
      '3', 'Three vertices.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Which resembles a ball?', null,
      'sphere', 'A ball is sphere-shaped.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Which has two circular faces?', null,
      'cylinder', 'A cylinder has circular ends.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'How many halves make a whole?', null,
      '2', 'Two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'How many fourths make a whole?', null,
      '4', 'Four.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Same whole: which is larger, half or fourth?', null,
      'half', 'Half is one of two equal shares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why must fraction shares be equal?', null,
      'so each share represents the same part of the whole', 'Fraction names require equal partitioning.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 36, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W36-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W36-D3 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently review and demonstrate Quarter 4 competencies 1-MATH-15 through 1-MATH-21 in preparation for the year-end mastery check.', 'I can add within 100 using place value.',
      '["pencil", "scratch paper"]'::jsonb, '[{"term": "data", "definition": "collected information"}, {"term": "attribute", "definition": "a feature that describes a shape"}, {"term": "equal shares", "definition": "parts of a whole that are the same size"}, {"term": "place value", "definition": "the value of a digit based on its position"}]'::jsonb,
      'Explain that Week 36 is cumulative: the goal is to show retained understanding across the final-quarter skills.', 'Model one neutral example from the day''s focus, then transition quickly to independent work.', 'Week 36 is mapped to 1-MATH-15 through 1-MATH-21. Interpret evidence using each competency''s configured threshold; 1-MATH-20 remains 90% while the others in this group are 85%. No separate hands-on evidence requirement is introduced.',
      'Use the skill that fits the problem: organize data, reason from shape attributes/equal shares, use place value for addition, find 10 more/less, or subtract whole tens.', 'Complete three brief review examples together.', 'Complete cumulative review work independently.',
      'Year-End Reflection: name one Grade 1 Math skill you can now explain to someone else.', 'Year-End Review — Add Within 100',
      'Complete each year-end review item independently and check your reasoning.', 'Complete the Week 36 online year-end mastery assessment independently. Apply existing repeated-evidence rules and each competency''s configured mastery threshold.',
      'Use normal accommodations without supplying operations, categories, attributes, or answers.', 'Create one question from a Quarter 4 skill and solve it two ways when possible.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      'Solve 37+5.', null,
      '42', 'Add ones and regroup one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Solve 37+40.', null,
      '77', 'Add four tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'In 52+6, which place changes?', null,
      'ones', 'Six ones are added.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Solve 48+4.', null,
      '52', '8+4=12 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve 26+50.', null,
      '76', 'Add five tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 63+20.', null,
      '83', 'Add two tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Explain 34+20.', null,
      '54', '3 tens+2 tens=5 tens; 4 ones stay.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '29+4', null,
      '33', '9+4=13 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '45+30', null,
      '75', 'Add three tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '58+3', null,
      '61', '8+3=11 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '71+20', null,
      '91', 'Add two tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '32+7', null,
      '39', 'Add seven ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '16+70', null,
      '86', 'Add seven tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Which place changes in 64+20?', null,
      'tens', 'Add two tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Which place usually changes in 64+3?', null,
      'ones', 'Add three ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 36, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W36-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W36-D4 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently review and demonstrate Quarter 4 competencies 1-MATH-15 through 1-MATH-21 in preparation for the year-end mastery check.', 'I can use tens mentally and in subtraction.',
      '["pencil", "scratch paper"]'::jsonb, '[{"term": "data", "definition": "collected information"}, {"term": "attribute", "definition": "a feature that describes a shape"}, {"term": "equal shares", "definition": "parts of a whole that are the same size"}, {"term": "place value", "definition": "the value of a digit based on its position"}]'::jsonb,
      'Explain that Week 36 is cumulative: the goal is to show retained understanding across the final-quarter skills.', 'Model one neutral example from the day''s focus, then transition quickly to independent work.', 'Week 36 is mapped to 1-MATH-15 through 1-MATH-21. Interpret evidence using each competency''s configured threshold; 1-MATH-20 remains 90% while the others in this group are 85%. No separate hands-on evidence requirement is introduced.',
      'Use the skill that fits the problem: organize data, reason from shape attributes/equal shares, use place value for addition, find 10 more/less, or subtract whole tens.', 'Complete three brief review examples together.', 'Complete cumulative review work independently.',
      'Year-End Reflection: name one Grade 1 Math skill you can now explain to someone else.', 'Year-End Review — 10 More/Less and Tens Subtraction',
      'Complete each year-end review item independently and check your reasoning.', 'Complete the Week 36 online year-end mastery assessment independently. Apply existing repeated-evidence rules and each competency''s configured mastery threshold.',
      'Use normal accommodations without supplying operations, categories, attributes, or answers.', 'Create one question from a Quarter 4 skill and solve it two ways when possible.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      '10 more than 46?', null,
      '56', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      '10 less than 46?', null,
      '36', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Solve 70−30.', null,
      '40', '7 tens−3 tens=4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      '10 more than 78?', null,
      '88', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      '10 less than 78?', null,
      '68', 'Remove one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 90−40.', null,
      '50', '9 tens−4 tens=5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'What stays the same when finding 10 more/less?', null,
      'ones digit', 'Only the tens count changes.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '10 more than 25', null,
      '35', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '10 less than 35', null,
      '25', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '60−20', null,
      '40', '6 tens−2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '80−50', null,
      '30', '8 tens−5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '10 more than 69', null,
      '79', 'Ones stay 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '10 less than 89', null,
      '79', 'Ones stay 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Related fact for 70−30', null,
      '7−3=4', 'The problem is 7 tens−3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Explain 50−20', null,
      '30', '5 tens−2 tens=3 tens.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 36, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W36-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W36-D5 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    )
    values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently review and demonstrate Quarter 4 competencies 1-MATH-15 through 1-MATH-21 in preparation for the year-end mastery check.', 'I can show what I learned in Grade 1 Math.',
      '["pencil", "scratch paper"]'::jsonb, '[{"term": "data", "definition": "collected information"}, {"term": "attribute", "definition": "a feature that describes a shape"}, {"term": "equal shares", "definition": "parts of a whole that are the same size"}, {"term": "place value", "definition": "the value of a digit based on its position"}]'::jsonb,
      'Explain that Week 36 is cumulative: the goal is to show retained understanding across the final-quarter skills.', 'Model one neutral example from the day''s focus, then transition quickly to independent work.', 'Week 36 is mapped to 1-MATH-15 through 1-MATH-21. Interpret evidence using each competency''s configured threshold; 1-MATH-20 remains 90% while the others in this group are 85%. No separate hands-on evidence requirement is introduced.',
      'Use the skill that fits the problem: organize data, reason from shape attributes/equal shares, use place value for addition, find 10 more/less, or subtract whole tens.', 'Complete three brief review examples together.', 'Complete cumulative review work independently.',
      'Year-End Reflection: name one Grade 1 Math skill you can now explain to someone else.', 'Grade 1 Math Year-End Mastery Readiness',
      'Complete each year-end review item independently and check your reasoning.', 'Complete the Week 36 online year-end mastery assessment independently. Apply existing repeated-evidence rules and each competency''s configured mastery threshold.',
      'Use normal accommodations without supplying operations, categories, attributes, or answers.', 'Create one question from a Quarter 4 skill and solve it two ways when possible.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 1,
      'Table A=5, B=3. Difference?', null,
      '2', 'Data comparison.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'A square divided into 4 equal shares creates what?', null,
      'fourths', 'Four equal shares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Solve 36+5.', null,
      '41', 'Add ones and regroup.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      '10 more than 54?', null,
      '64', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      '10 less than 54?', null,
      '44', 'Subtract one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 80−30.', null,
      '50', '8 tens−3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Which 3D shape is like a ball?', null,
      'sphere', 'Sphere.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Graph count A=6, B=4. Difference?', null,
      '2', '6−4=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'How many sides on triangle?', null,
      '3', 'Three.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Two equal shares are called ___.', null,
      'halves', 'Two halves.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '42+7', null,
      '49', 'Add seven ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '42+30', null,
      '72', 'Add three tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '10 more than 67', null,
      '77', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '90−50', null,
      '40', '9 tens−5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'What does one-for-one graphing mean?', null,
      'each symbol represents one data item', 'One symbol per item.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 33 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 33
      and l.week_number = 33
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W33-Q01', 1, 'short_answer', 'Solve 46 + 3.', '[]'::jsonb, '49', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W33-Q02', 2, 'short_answer', 'Solve 46 + 20.', '[]'::jsonb, '66', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W33-Q03', 3, 'short_answer', 'Solve 37 + 5.', '[]'::jsonb, '42', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W33-Q04', 4, 'short_answer', 'Solve 48 + 4.', '[]'::jsonb, '52', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W33-Q05', 5, 'short_answer', 'Solve 26 + 50.', '[]'::jsonb, '76', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W33-Q06', 6, 'short_answer', 'Solve 63 + 20.', '[]'::jsonb, '83', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W33-Q07', 7, 'multiple_choice', 'In 52 + 6, which place changes most directly?', '[{"id": "a", "label": "tens"}, {"id": "b", "label": "ones"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W33-Q08', 8, 'multiple_choice', 'In 52 + 30, which place changes?', '[{"id": "a", "label": "tens"}, {"id": "b", "label": "ones"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W33-Q09', 9, 'short_answer', 'Solve 58 + 3.', '[]'::jsonb, '61', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W33-Q10', 10, 'short_answer', 'Solve 17 + 60.', '[]'::jsonb, '77', 1);


    insert into public.student_assignment_items (
      organization_id, student_id, student_assignment_id,
      source_template_item_id, source_code, sequence, question_type,
      prompt, options, correct_answer, points
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
    join public.assessment_template_items ati
      on ati.assignment_template_id = sa.assignment_template_id
    where sa.assignment_template_id = v_template_id
      and sa.status = 'assigned'
      and not exists (
        select 1
        from public.student_assignment_items sai
        where sai.student_assignment_id = sa.id
          and sai.source_template_item_id = ati.id
      );


    -- Week 34 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 34
      and l.week_number = 34
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W34-Q01', 1, 'short_answer', 'What is 10 more than 24?', '[]'::jsonb, '34', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W34-Q02', 2, 'short_answer', 'What is 10 less than 34?', '[]'::jsonb, '24', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W34-Q03', 3, 'short_answer', 'What is 10 more than 51?', '[]'::jsonb, '61', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W34-Q04', 4, 'short_answer', 'What is 10 less than 61?', '[]'::jsonb, '51', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W34-Q05', 5, 'short_answer', 'What is 10 more than 68?', '[]'::jsonb, '78', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W34-Q06', 6, 'short_answer', 'What is 10 less than 78?', '[]'::jsonb, '68', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W34-Q07', 7, 'short_answer', 'What is 10 more than 37?', '[]'::jsonb, '47', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W34-Q08', 8, 'short_answer', 'What is 10 less than 47?', '[]'::jsonb, '37', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W34-Q09', 9, 'multiple_choice', 'When finding 10 more or 10 less, which digit stays the same?', '[{"id": "a", "label": "tens digit"}, {"id": "b", "label": "ones digit"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W34-Q10', 10, 'multiple_choice', 'When finding 10 more, what happens to the tens count?', '[{"id": "a", "label": "increases by 1"}, {"id": "b", "label": "decreases by 1"}]'::jsonb, 'a', 1);


    insert into public.student_assignment_items (
      organization_id, student_id, student_assignment_id,
      source_template_item_id, source_code, sequence, question_type,
      prompt, options, correct_answer, points
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
    join public.assessment_template_items ati
      on ati.assignment_template_id = sa.assignment_template_id
    where sa.assignment_template_id = v_template_id
      and sa.status = 'assigned'
      and not exists (
        select 1
        from public.student_assignment_items sai
        where sai.student_assignment_id = sa.id
          and sai.source_template_item_id = ati.id
      );


    -- Week 35 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 35
      and l.week_number = 35
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W35-Q01', 1, 'short_answer', 'Solve 60 − 20.', '[]'::jsonb, '40', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W35-Q02', 2, 'short_answer', 'Solve 80 − 30.', '[]'::jsonb, '50', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W35-Q03', 3, 'short_answer', 'Solve 90 − 40.', '[]'::jsonb, '50', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W35-Q04', 4, 'short_answer', 'Solve 70 − 20.', '[]'::jsonb, '50', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W35-Q05', 5, 'short_answer', 'Solve 50 − 30.', '[]'::jsonb, '20', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W35-Q06', 6, 'short_answer', 'Solve 90 − 60.', '[]'::jsonb, '30', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W35-Q07', 7, 'multiple_choice', 'Which basic fact helps solve 70−30?', '[{"id": "a", "label": "7−3=4"}, {"id": "b", "label": "7+3=10"}, {"id": "c", "label": "3−7=4"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W35-Q08', 8, 'multiple_choice', 'In 80−20, what place-value units are being subtracted?', '[{"id": "a", "label": "ones"}, {"id": "b", "label": "tens"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W35-Q09', 9, 'short_answer', 'Solve 40 − 10.', '[]'::jsonb, '30', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W35-Q10', 10, 'short_answer', 'Solve 90 − 70.', '[]'::jsonb, '20', 1);


    insert into public.student_assignment_items (
      organization_id, student_id, student_assignment_id,
      source_template_item_id, source_code, sequence, question_type,
      prompt, options, correct_answer, points
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
    join public.assessment_template_items ati
      on ati.assignment_template_id = sa.assignment_template_id
    where sa.assignment_template_id = v_template_id
      and sa.status = 'assigned'
      and not exists (
        select 1
        from public.student_assignment_items sai
        where sai.student_assignment_id = sa.id
          and sai.source_template_item_id = ati.id
      );


    -- Week 36 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 36
      and l.week_number = 36
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W36-Q01', 1, 'short_answer', 'Table: Red=5, Blue=3. How many more Red?', '[]'::jsonb, '2', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W36-Q02', 2, 'multiple_choice', 'If 1 graph symbol represents 1 item and a category has 4 items, how many symbols are needed?', '[{"id": "a", "label": "2"}, {"id": "b", "label": "4"}, {"id": "c", "label": "8"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W36-Q03', 3, 'multiple_choice', 'Which 3D shape has 6 square faces?', '[{"id": "a", "label": "sphere"}, {"id": "b", "label": "cube"}, {"id": "c", "label": "cylinder"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W36-Q04', 4, 'multiple_choice', 'A rectangle divided into 4 equal shares creates what?', '[{"id": "a", "label": "halves"}, {"id": "b", "label": "fourths"}, {"id": "c", "label": "unequal pieces"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W36-Q05', 5, 'short_answer', 'Solve 37 + 5.', '[]'::jsonb, '42', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W36-Q06', 6, 'short_answer', 'Solve 26 + 50.', '[]'::jsonb, '76', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W36-Q07', 7, 'short_answer', 'What is 10 more than 46?', '[]'::jsonb, '56', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W36-Q08', 8, 'short_answer', 'What is 10 less than 46?', '[]'::jsonb, '36', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W36-Q09', 9, 'short_answer', 'Solve 80 − 30.', '[]'::jsonb, '50', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W36-Q10', 10, 'multiple_choice', 'When finding 10 more or 10 less, which digit stays the same?', '[{"id": "a", "label": "tens digit"}, {"id": "b", "label": "ones digit"}]'::jsonb, 'b', 1);


    insert into public.student_assignment_items (
      organization_id, student_id, student_assignment_id,
      source_template_item_id, source_code, sequence, question_type,
      prompt, options, correct_answer, points
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
    join public.assessment_template_items ati
      on ati.assignment_template_id = sa.assignment_template_id
    where sa.assignment_template_id = v_template_id
      and sa.status = 'assigned'
      and not exists (
        select 1
        from public.student_assignment_items sai
        where sai.student_assignment_id = sa.id
          and sai.source_template_item_id = ati.id
      );


  end loop;
end;
$seed$;

commit;
