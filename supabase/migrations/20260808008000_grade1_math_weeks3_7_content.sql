-- Homeschool Tracker
-- Migration 018: Grade 1 Mathematics Weeks 3–7 production curriculum
--
-- Installs:
--   Week 3: 1-MATH-03 Counting Patterns by 2s, 5s, and 10s
--   Weeks 4–5: 1-MATH-04 Tens and Ones
--   Weeks 6–7: 1-MATH-05 Compare Two-Digit Numbers
--
-- 25 published lesson-content revisions
-- 375 lesson-content practice/worksheet items
-- 5 online Friday checks x 10 questions = 50 assessment items
--
-- Historical safety:
-- * refuses to overwrite published/superseded Week 3–7 lesson content
-- * refuses to alter a lesson already frozen to a student delivery
-- * refuses to overwrite an existing Week 3–7 online question bank
-- * all five weeks install inside one transaction

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

    -- -----------------------------------------------------------------------
    -- PREFLIGHT: verify all 25 lesson skeletons and all five Friday templates
    -- before inserting anything.
    -- -----------------------------------------------------------------------
    for v_week in 3..7 loop
      for v_day in 1..5 loop
        v_expected_code := format('1-MATH-W%s-D%s', lpad(v_week::text, 2, '0'), v_day);
        if not exists (
          select 1 from public.lessons l
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
        raise exception 'Grade 1 Math Week % already contains published lesson content. Migration 018 will not overwrite curriculum history.', v_week;
      end if;

      if exists (
        select 1
        from public.student_lesson_deliveries sld
        join public.lessons l on l.id = sld.lesson_id
        where l.course_version_id = v_course.course_version_id
          and l.week_number = v_week
      ) then
        raise exception 'Grade 1 Math Week % has already been frozen to a student delivery. Migration 018 will not rewrite delivered curriculum.', v_week;
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
        raise exception 'Grade 1 Math Week % already has an online question bank. Migration 018 will not overwrite assessment history.', v_week;
      end if;
    end loop;

    -- Remove only temporary/unpublished drafts for these still-undelivered weeks.
    delete from public.lesson_content_versions lcv
    using public.lessons l
    where lcv.lesson_id = l.id
      and l.course_version_id = v_course.course_version_id
      and l.week_number between 3 and 7
      and lcv.status = 'draft';


    -- Week 3, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W03-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W03-D1 was not found.';
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
      'The student will identify, continue, and generate counting patterns by 10s through 120 and describe the repeating ones-digit pattern.', 'I can count by 10s and explain what stays the same.', '["pencil", "paper", "optional 0–120 number chart", "optional counters arranged in equal groups"]'::jsonb, '[{"term": "skip count", "definition": "count by the same amount each time"}, {"term": "pattern", "definition": "a rule that repeats or continues"}, {"term": "ones digit", "definition": "the digit in the ones place"}]'::jsonb,
      'Write 0, 10, 20, 30. Ask what changes from one number to the next. Explain that skip counting lets us move by equal jumps instead of counting every number.', 'Model jumps of 10 on a number chart: 0→10→20→30→40. Circle the ones digit in each number. Show that it stays 0. Then start at 20 and continue 20, 30, 40, 50 so the student sees that a pattern can begin after 0.', 'Focus on the rule +10 and the ones digit. The student does not need multiplication language for this lesson.',
      'When you count by 10s, add 10 each time.

0, 10, 20, 30, 40, 50 ...

The tens digit changes, but the ones digit stays 0. You can also begin later: 30, 40, 50, 60.', 'Say the pattern aloud together before writing missing numbers.', 'Complete the sequences without counting every number by ones.', 'Make a 10s chain from 0 to 120 on small slips. Mix them, rebuild the chain, then remove three slips for the student to identify.',
      'Counting by 10s', 'Count by 10s. Fill in each missing number.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain that numbers in the basic 10s pattern end in 0.',
      'Keep a 0–120 chart visible during instruction. Highlight only the multiples of 10 if the full chart is distracting.', 'Start at 20, 30, or 40 and ask the student to generate six numbers in the pattern without returning to 0.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Continue: 0, 10, __, __.', 'Count by 10s.', '20, 30', 'Add 10 each time.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'What number comes next when counting by 10s: 10, 20, 30, __?', 'Add 10.', '40', 'The next number is 10 more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Start at 20 and count forward by 10s three times. Where do you land?', 'Take three jumps of 10.', '50', '20 → 30 → 40 → 50.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Continue: 30, 40, 50, __.', null, '60', 'Add 10 to 50.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Fill in the missing number: 40, __, 60.', null, '50', '50 is 10 more than 40.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Start at 50 and count by 10s four times. Where do you land?', null, '90', 'Four jumps of 10 from 50 land on 90.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'What are the next three numbers after 60 when counting by 10s?', null, '70, 80, 90', 'Each number is 10 more than the previous number.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Continue: 0, 10, __, __.', null, '20, 30', 'Count by 10s from 0.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Fill in the missing number: 10, __, 30.', null, '20', 'Count by 10s from 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Start at 20 and count by 10s two times. Where do you land?', null, '40', 'Count by 10s from 20.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'What are the next two numbers after 30 when counting by 10s?', null, '40, 50', 'Count by 10s from 30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Continue: 40, 50, __, __.', null, '60, 70', 'Count by 10s from 40.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Fill in the missing number: 50, __, 70.', null, '60', 'Count by 10s from 50.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Start at 60 and count by 10s two times. Where do you land?', null, '80', 'Count by 10s from 60.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'What are the next two numbers after 70 when counting by 10s?', null, '80, 90', 'Count by 10s from 70.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 3, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W03-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W03-D2 was not found.';
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
      'The student will identify, continue, and generate counting patterns by 5s through 120 and describe the alternating 0/5 ones-digit pattern.', 'I can count by 5s and notice the 0, 5 pattern.', '["pencil", "paper", "optional 0–120 number chart", "optional counters arranged in equal groups"]'::jsonb, '[{"term": "skip count", "definition": "count by the same amount each time"}, {"term": "pattern", "definition": "a rule that repeats or continues"}, {"term": "ones digit", "definition": "the digit in the ones place"}]'::jsonb,
      'Count five fingers on one hand, then another five. Write 5, 10, 15, 20 and ask what the ones digits are doing.', 'Model 5, 10, 15, 20, 25, 30. Circle the ones digits and read them: 5, 0, 5, 0, 5, 0. Then begin at 25 and continue by 5s to show the rule still works from another valid point.', 'The most useful pattern is that multiples of 5 end in 0 or 5. Keep the focus on recognizing and continuing the pattern rather than memorizing a chant only.',
      'When you count by 5s, add 5 each time.

5, 10, 15, 20, 25, 30 ...

Look at the ones digits: 5, 0, 5, 0. They alternate.', 'Count aloud together and point out every switch between an ending of 5 and an ending of 0.', 'Complete the sequences independently and identify whether the missing number should end in 0 or 5.', 'Make pairs of five counters or draw five dots in each box. Label the running totals 5, 10, 15, 20, and so on.',
      'Counting by 5s', 'Count by 5s and use the 0/5 ones-digit pattern to help.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and state that counting-by-5 numbers end in 0 or 5.',
      'Use a highlighted 5s number strip. Allow the student to say the sequence before writing.', 'Ask the student to decide whether numbers such as 35, 42, 70, and 93 can appear in a basic count-by-5 pattern and explain why.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Continue: 5, 10, __, __.', 'Count by 5s.', '15, 20', 'Add 5 each time.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'What number comes next when counting by 5s: 10, 15, 20, __?', 'Add 5.', '25', 'The next number is 5 more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Start at 15 and count forward by 5s three times. Where do you land?', 'Take three jumps of 5.', '30', '15 → 20 → 25 → 30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Continue: 20, 25, 30, __.', null, '35', 'Add 5 to 30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Fill in the missing number: 25, __, 35.', null, '30', '30 is 5 more than 25.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Start at 30 and count by 5s four times. Where do you land?', null, '50', 'Four jumps of 5 from 30 land on 50.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'What are the next three numbers after 35 when counting by 5s?', null, '40, 45, 50', 'Each number is 5 more than the previous number.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Continue: 5, 10, __, __.', null, '15, 20', 'Count by 5s from 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Fill in the missing number: 10, __, 20.', null, '15', 'Count by 5s from 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Start at 15 and count by 5s two times. Where do you land?', null, '25', 'Count by 5s from 15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'What are the next two numbers after 20 when counting by 5s?', null, '25, 30', 'Count by 5s from 20.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Continue: 25, 30, __, __.', null, '35, 40', 'Count by 5s from 25.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Fill in the missing number: 30, __, 40.', null, '35', 'Count by 5s from 30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Start at 35 and count by 5s two times. Where do you land?', null, '45', 'Count by 5s from 35.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'What are the next two numbers after 40 when counting by 5s?', null, '45, 50', 'Count by 5s from 40.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 3, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W03-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W03-D3 was not found.';
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
      'The student will identify, continue, and generate counting patterns by 2s through 120 and recognize the repeating even ones digits 0, 2, 4, 6, 8.', 'I can count by 2s and use the ones-digit pattern.', '["pencil", "paper", "optional 0–120 number chart", "optional counters arranged in equal groups"]'::jsonb, '[{"term": "skip count", "definition": "count by the same amount each time"}, {"term": "pattern", "definition": "a rule that repeats or continues"}, {"term": "ones digit", "definition": "the digit in the ones place"}]'::jsonb,
      'Make pairs of objects or draw pairs of dots. Count the total after each pair: 2, 4, 6, 8, 10. Explain that counting by 2s is counting equal pairs.', 'Model 2, 4, 6, 8, 10, 12, 14. Circle the ones digits: 2, 4, 6, 8, 0, then the pattern repeats. Model starting at 20 and counting 20, 22, 24, 26.', 'Students may accidentally switch to counting by ones near a decade boundary. Ask for the rule before giving a correction: ''What are we adding each time?''',
      'When you count by 2s, add 2 each time.

2, 4, 6, 8, 10, 12 ...

The ones digits repeat 2, 4, 6, 8, 0. Then the pattern starts again.', 'Say the sequence together, especially across 8→10, 18→20, and 28→30.', 'Use the +2 rule rather than counting every number in between aloud.', 'Pair Walk: draw or place pairs in a row. Touch one pair at a time and say the running total by 2s.',
      'Counting by 2s', 'Count by 2s. Watch the repeating ones digits.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and name at least three possible ones digits in a count-by-2 pattern.',
      'Use pairs of counters or a highlighted even-number strip. Reduce the length of oral sequences while keeping the same +2 rule.', 'Ask the student to predict the ones digit of the next number before calculating it.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Continue: 2, 4, __, __.', 'Count by 2s.', '6, 8', 'Add 2 each time.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'What number comes next when counting by 2s: 8, 10, 12, __?', 'Add 2.', '14', 'The next number is 2 more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Start at 14 and count forward by 2s three times. Where do you land?', 'Take three jumps of 2.', '20', '14 → 16 → 18 → 20.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Continue: 20, 22, 24, __.', null, '26', 'Add 2 to 24.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Fill in the missing number: 26, __, 30.', null, '28', '28 is 2 more than 26.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Start at 32 and count by 2s four times. Where do you land?', null, '40', 'Four jumps of 2 from 32 land on 40.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'What are the next three numbers after 38 when counting by 2s?', null, '40, 42, 44', 'Each number is 2 more than the previous number.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Continue: 2, 4, __, __.', null, '6, 8', 'Count by 2s from 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Fill in the missing number: 8, __, 12.', null, '10', 'Count by 2s from 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Start at 14 and count by 2s two times. Where do you land?', null, '18', 'Count by 2s from 14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'What are the next two numbers after 20 when counting by 2s?', null, '22, 24', 'Count by 2s from 20.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Continue: 26, 28, __, __.', null, '30, 32', 'Count by 2s from 26.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Fill in the missing number: 32, __, 36.', null, '34', 'Count by 2s from 32.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Start at 38 and count by 2s two times. Where do you land?', null, '42', 'Count by 2s from 38.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'What are the next two numbers after 44 when counting by 2s?', null, '46, 48', 'Count by 2s from 44.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 3, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W03-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W03-D4 was not found.';
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
      'The student will distinguish counting-by-2, counting-by-5, and counting-by-10 patterns, continue each pattern, and explain the rule from the changing numbers and ones digits.', 'I can figure out whether a pattern counts by 2s, 5s, or 10s.', '["pencil", "paper", "optional 0–120 number chart", "optional counters arranged in equal groups"]'::jsonb, '[{"term": "skip count", "definition": "count by the same amount each time"}, {"term": "pattern", "definition": "a rule that repeats or continues"}, {"term": "ones digit", "definition": "the digit in the ones place"}]'::jsonb,
      'Write three rows: 12,14,16; 20,25,30; 30,40,50. Ask what amount is being added in each row.', 'Model how to identify a rule by comparing neighboring numbers. Show that ones-digit clues can help: 2s use repeating even endings, 5s end in 0 or 5, and 10s keep the same ones digit when starting on a multiple of 10.', 'Require the student to name the rule before filling a missing number. This strengthens pattern recognition instead of isolated arithmetic.',
      'First find the rule.

12, 14, 16 counts by 2s.
25, 30, 35 counts by 5s.
40, 50, 60 counts by 10s.

Then use the same jump again and again.', 'For every sequence, say the rule aloud before solving.', 'Identify the rule and complete each pattern independently.', 'Pattern Sort: write short sequences on cards and sort them into ''by 2s,'' ''by 5s,'' and ''by 10s.''',
      'Mixed Skip-Counting Patterns', 'Name the counting rule, then complete each pattern.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and correctly identify all three skip-counting rules in oral examples.',
      'Provide a reference card showing +2, +5, +10 and one example of each during guided practice.', 'Ask the student to create one new sequence for each rule and remove a number for the instructor to solve.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Continue by 2s: 24, 26, __, 30.', 'Count by 2s.', '28', 'Add 2 each time.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Continue by 5s: 35, 40, __, 50.', 'Count by 5s.', '45', 'Add 5 each time.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Continue by 10s: 40, 50, __, 70.', 'Count by 10s.', '60', 'Add 10 each time.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Which rule fits 12, 14, 16, 18: count by 2s, 5s, or 10s?', null, 'count by 2s', 'Each number increases by 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Which rule fits 25, 30, 35, 40: count by 2s, 5s, or 10s?', null, 'count by 5s', 'Each number increases by 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Which rule fits 30, 40, 50, 60: count by 2s, 5s, or 10s?', null, 'count by 10s', 'Each number increases by 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Continue: 82, 84, 86, __.', null, '88', 'The pattern counts by 2s.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Continue by 2s: 42, 44, __, 48.', null, '46', '46 is 2 more than 44.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Continue by 5s: 55, 60, __, 70.', null, '65', '65 is 5 more than 60.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Continue by 10s: 60, 70, __, 90.', null, '80', '80 is 10 more than 70.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Which rule fits 6, 8, 10, 12?', null, 'count by 2s', 'The numbers increase by 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Which rule fits 45, 50, 55, 60?', null, 'count by 5s', 'The numbers increase by 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Which rule fits 20, 30, 40, 50?', null, 'count by 10s', 'The numbers increase by 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Continue: 90, 95, 100, __.', null, '105', 'This pattern counts by 5s.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Continue: 96, 98, 100, __.', null, '102', 'This pattern counts by 2s.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 3, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W03-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W03-D5 was not found.';
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
      'The student will independently demonstrate identifying, continuing, and generating patterns by 2s, 5s, and 10s before completing the Week 3 online competency check.', 'I can show what I know about counting patterns by 2s, 5s, and 10s.', '["pencil", "scratch paper", "no number chart during the final check unless normally provided as an accommodation"]'::jsonb, '[{"term": "skip count", "definition": "count by the same amount each time"}, {"term": "pattern", "definition": "a rule that repeats or continues"}, {"term": "ones digit", "definition": "the digit in the ones place"}]'::jsonb,
      'Review the three rules briefly. Ask the student to give one example sequence for each: by 2s, by 5s, and by 10s.', 'Model one neutral example for each rule that does not duplicate the online check. Keep the review brief so the assessment reflects the student''s own pattern recognition.', 'The online Week 3 check is intended to provide independent evidence for 1-MATH-03. A qualifying result may contribute to mastery under the existing repeated-evidence rules.',
      'Remember the clues:

By 2s: add 2; even ones digits repeat.
By 5s: add 5; ones digits end in 0 or 5.
By 10s: add 10.

Find the rule first, then continue the pattern.', 'Use the guided questions only as a warm-up.', 'Complete the readiness work without help, then complete the Week 3 online check.', 'Explain the Pattern: choose one sequence and tell the instructor how the ones digits helped identify the rule.',
      'Week 3 Readiness Review', 'Complete the mixed review before the online Week 3 Check.', 'Complete the readiness review and the Week 3 online assessment independently. Use the configured competency threshold and repeated qualifying evidence rules.',
      'Read directions aloud if needed. Do not identify the rule or supply the next number during the assessment.', 'Create a mystery skip-counting sequence with one missing number for the instructor.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Continue by 2s: 24, 26, __, 30.', 'Count by 2s.', '28', 'Add 2 each time.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Continue by 5s: 35, 40, __, 50.', 'Count by 5s.', '45', 'Add 5 each time.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Continue by 10s: 40, 50, __, 70.', 'Count by 10s.', '60', 'Add 10 each time.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Which rule fits 12, 14, 16, 18: count by 2s, 5s, or 10s?', null, 'count by 2s', 'Each number increases by 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Which rule fits 25, 30, 35, 40: count by 2s, 5s, or 10s?', null, 'count by 5s', 'Each number increases by 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Which rule fits 30, 40, 50, 60: count by 2s, 5s, or 10s?', null, 'count by 10s', 'Each number increases by 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Continue: 82, 84, 86, __.', null, '88', 'The pattern counts by 2s.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Continue by 2s: 42, 44, __, 48.', null, '46', '46 is 2 more than 44.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Continue by 5s: 55, 60, __, 70.', null, '65', '65 is 5 more than 60.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Continue by 10s: 60, 70, __, 90.', null, '80', '80 is 10 more than 70.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Which rule fits 6, 8, 10, 12?', null, 'count by 2s', 'The numbers increase by 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Which rule fits 45, 50, 55, 60?', null, 'count by 5s', 'The numbers increase by 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Which rule fits 20, 30, 40, 50?', null, 'count by 10s', 'The numbers increase by 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Continue: 90, 95, 100, __.', null, '105', 'This pattern counts by 5s.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Continue: 96, 98, 100, __.', null, '102', 'This pattern counts by 2s.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 4, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W04-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W04-D1 was not found.';
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
      'The student will represent two-digit numbers as groups of ten and leftover ones.', 'I can break a two-digit number into tens and ones.', '["pencil", "paper", "optional base-ten blocks or bundled craft sticks", "optional tens-and-ones chart"]'::jsonb, '[{"term": "ten", "definition": "a group of 10 ones"}, {"term": "ones", "definition": "single units left after making groups of ten"}, {"term": "digit", "definition": "a symbol used to write a number"}, {"term": "place", "definition": "a digit''s position in a number"}]'::jsonb,
      'Make 24 using drawings or objects. Group 20 as two groups of ten and leave 4 single ones. Explain that organizing objects into tens makes larger quantities easier to see.', 'Model 36 as 3 tens and 6 ones, then 50 as 5 tens and 0 ones. Connect each model to the written numeral: the left digit records tens and the right digit records ones.', 'Use models as a support, but the goal is to connect the model to the numeral. Zero ones is an important case.',
      'A two-digit number can be organized into tens and ones.

36 = 3 tens and 6 ones
50 = 5 tens and 0 ones

The tens digit tells how many groups of ten. The ones digit tells how many single ones are left.', 'Build or draw the tens first, then count the leftover ones.', 'Write each number as tens and ones without teacher prompting.', 'Tens Builder: choose five two-digit numbers and build or sketch each with long tens and single ones.',
      'Tens and Ones Models', 'Write each number as groups of tens and leftover ones.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and accurately represent at least two teacher-selected numbers.',
      'Use real bundles, base-ten blocks, or drawn sticks. Let the student touch/count the tens separately from the ones.', 'Have the student choose a number, represent it, then cover the numeral and ask the instructor to identify it from the model.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'How many tens and ones are in 34?', null, '3 tens and 4 ones', '34 has 3 tens and 4 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'How many tens and ones are in 52?', null, '5 tens and 2 ones', '52 has 5 tens and 2 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'How many tens and ones are in 70?', null, '7 tens and 0 ones', '70 has 7 tens and 0 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Write 46 as tens and ones.', null, '4 tens and 6 ones', '46 = 4 tens and 6 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Write 81 as tens and ones.', null, '8 tens and 1 one', '81 = 8 tens and 1 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Write 29 as tens and ones.', null, '2 tens and 9 ones', '29 = 2 tens and 9 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Write 60 as tens and ones.', null, '6 tens and 0 ones', '60 = 6 tens and 0 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Show 13 as tens and ones.', null, '1 tens and 3 ones', '13 has 1 groups of ten and 3 leftover ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Show 25 as tens and ones.', null, '2 tens and 5 ones', '25 has 2 groups of ten and 5 leftover ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Show 38 as tens and ones.', null, '3 tens and 8 ones', '38 has 3 groups of ten and 8 leftover ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Show 41 as tens and ones.', null, '4 tens and 1 ones', '41 has 4 groups of ten and 1 leftover ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Show 57 as tens and ones.', null, '5 tens and 7 ones', '57 has 5 groups of ten and 7 leftover ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Show 64 as tens and ones.', null, '6 tens and 4 ones', '64 has 6 groups of ten and 4 leftover ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Show 72 as tens and ones.', null, '7 tens and 2 ones', '72 has 7 groups of ten and 2 leftover ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Show 99 as tens and ones.', null, '9 tens and 9 ones', '99 has 9 groups of ten and 9 leftover ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 4, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W04-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W04-D2 was not found.';
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
      'The student will identify the tens digit and ones digit in two-digit numbers and connect each digit to its place.', 'I can tell which digit is tens and which digit is ones.', '["pencil", "paper", "optional base-ten blocks or bundled craft sticks", "optional tens-and-ones chart"]'::jsonb, '[{"term": "ten", "definition": "a group of 10 ones"}, {"term": "ones", "definition": "single units left after making groups of ten"}, {"term": "digit", "definition": "a symbol used to write a number"}, {"term": "place", "definition": "a digit''s position in a number"}]'::jsonb,
      'Write 47. Ask whether the 4 means four single ones or four groups of ten. Use a quick model to show why position matters.', 'Draw a TENS | ONES chart. Place 4 under tens and 7 under ones for 47. Repeat with 63 and 20. Emphasize that a digit''s place changes what it represents.', 'Keep language consistent: ''4 is the tens digit; there are 4 tens.'' Value of the digit is developed more deeply next week.',
      'In 47:
4 is in the tens place.
7 is in the ones place.

The left digit tells the tens. The right digit tells the ones.', 'Place each digit into a tens-and-ones chart before answering.', 'Identify the two places directly from the numeral.', 'Digit Cards: make two columns labeled Tens and Ones. Draw a two-digit number card and place each digit in the correct column.',
      'Find the Tens and Ones Digits', 'Name the tens digit and the ones digit in each number.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and correctly identify both places in three oral examples.',
      'Color-code tens and ones consistently during guided practice, such as blue tens and green ones.', 'Ask how the meaning changes between 27 and 72 even though the same digits are used.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'In 47, what digit is in the tens place and what digit is in the ones place?', null, '4 tens, 7 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'In 63, what digit is in the tens place and what digit is in the ones place?', null, '6 tens, 3 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'In 28, what digit is in the tens place and what digit is in the ones place?', null, '2 tens, 8 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'In 91, what digit is in the tens place and what digit is in the ones place?', null, '9 tens, 1 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'In 35, what digit is in the tens place and what digit is in the ones place?', null, '3 tens, 5 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'In 76, what digit is in the tens place and what digit is in the ones place?', null, '7 tens, 6 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'In 54, what digit is in the tens place and what digit is in the ones place?', null, '5 tens, 4 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'In 82, what digit is in the tens place and what digit is in the ones place?', null, '8 tens, 2 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'In 19, what digit is in the tens place and what digit is in the ones place?', null, '1 tens, 9 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'In 68, what digit is in the tens place and what digit is in the ones place?', null, '6 tens, 8 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'In 43, what digit is in the tens place and what digit is in the ones place?', null, '4 tens, 3 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'In 97, what digit is in the tens place and what digit is in the ones place?', null, '9 tens, 7 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'In 31, what digit is in the tens place and what digit is in the ones place?', null, '3 tens, 1 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'In 56, what digit is in the tens place and what digit is in the ones place?', null, '5 tens, 6 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'In 84, what digit is in the tens place and what digit is in the ones place?', null, '8 tens, 4 ones', 'The left digit tells the tens; the right digit tells the ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 4, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W04-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W04-D3 was not found.';
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
      'The student will compose two-digit numbers when given a number of tens and ones.', 'I can make a number from tens and ones.', '["pencil", "paper", "optional base-ten blocks or bundled craft sticks", "optional tens-and-ones chart"]'::jsonb, '[{"term": "ten", "definition": "a group of 10 ones"}, {"term": "ones", "definition": "single units left after making groups of ten"}, {"term": "digit", "definition": "a symbol used to write a number"}, {"term": "place", "definition": "a digit''s position in a number"}]'::jsonb,
      'Say ''4 tens and 3 ones'' without showing a numeral. Ask the student to build or draw it, then determine the numeral.', 'Model 4 tens = 40 and 3 ones = 3, so 40 + 3 = 43. Repeat with 7 tens and 0 ones to show 70.', 'Watch for reversed digits, such as writing 34 for 4 tens and 3 ones. Return to the place-value chart when that happens.',
      'To make a two-digit number:
1. Find the number of tens.
2. Put that digit in the tens place.
3. Put the ones in the ones place.

4 tens and 3 ones = 43.', 'Build the number, say the tens and ones, then write the numeral.', 'Compose each numeral from the stated tens and ones.', 'Number Factory: the instructor calls out tens and ones; the student writes the numeral on a card and checks it with a model.',
      'Compose Two-Digit Numbers', 'Write the numeral made by the given tens and ones.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and compose at least three oral examples without reversing digits.',
      'Keep a place-value chart visible. Let the student write the tens digit first and point to the ones column before writing the second digit.', 'Include numbers with 0 ones and ask why the zero must still be written.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'What number is 2 tens and 7 ones?', null, '27', '2 tens = 20; add 7 ones to make 27.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'What number is 4 tens and 3 ones?', null, '43', '4 tens = 40; add 3 ones to make 43.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'What number is 6 tens and 5 ones?', null, '65', '6 tens = 60; add 5 ones to make 65.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'What number is 8 tens and 1 ones?', null, '81', '8 tens = 80; add 1 ones to make 81.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'What number is 3 tens and 9 ones?', null, '39', '3 tens = 30; add 9 ones to make 39.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'What number is 5 tens and 4 ones?', null, '54', '5 tens = 50; add 4 ones to make 54.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'What number is 7 tens and 2 ones?', null, '72', '7 tens = 70; add 2 ones to make 72.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'What number is 1 tens and 6 ones?', null, '16', '1 tens = 10; add 6 ones to make 16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'What number is 2 tens and 5 ones?', null, '25', '2 tens = 20; add 5 ones to make 25.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'What number is 4 tens and 8 ones?', null, '48', '4 tens = 40; add 8 ones to make 48.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'What number is 6 tens and 1 ones?', null, '61', '6 tens = 60; add 1 ones to make 61.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'What number is 7 tens and 7 ones?', null, '77', '7 tens = 70; add 7 ones to make 77.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'What number is 8 tens and 3 ones?', null, '83', '8 tens = 80; add 3 ones to make 83.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'What number is 9 tens and 0 ones?', null, '90', '9 tens = 90; add 0 ones to make 90.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'What number is 5 tens and 9 ones?', null, '59', '5 tens = 50; add 9 ones to make 59.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 4, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W04-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W04-D4 was not found.';
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
      'The student will decompose two-digit numbers into tens value plus ones value using expanded form.', 'I can split a number into tens and ones values.', '["pencil", "paper", "optional base-ten blocks or bundled craft sticks", "optional tens-and-ones chart"]'::jsonb, '[{"term": "ten", "definition": "a group of 10 ones"}, {"term": "ones", "definition": "single units left after making groups of ten"}, {"term": "digit", "definition": "a symbol used to write a number"}, {"term": "place", "definition": "a digit''s position in a number"}, {"term": "expanded form", "definition": "a number written as the value of its tens plus the value of its ones"}]'::jsonb,
      'Write 58. Ask what the 5 tens are worth altogether. Connect 5 tens to 50, then add the 8 ones.', 'Model 58 = 50 + 8, 72 = 70 + 2, and 40 = 40 + 0. Link each expanded form back to a tens-and-ones representation.', 'Do not skip the meaning of expanded form. It is not just inserting a zero; it records the value contributed by each place.',
      'Expanded form shows the value of each place.

58 = 50 + 8
72 = 70 + 2
40 = 40 + 0

The tens part is worth groups of ten. The ones part keeps its ones value.', 'Say the tens-and-ones form first, then write expanded form.', 'Write each number in expanded form independently.', 'Expanded-Form Match: make numeral cards and expanded-form cards, mix them, and match the pairs.',
      'Expanded Form', 'Write each two-digit number as tens value + ones value.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain one expanded form using tens and ones.',
      'Use a place-value chart and write the total value beneath each digit before combining the parts.', 'Ask the student to write the same number in numeral, tens-and-ones, and expanded forms.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Write 36 in expanded form.', null, '30 + 6', '3 tens are worth 30; add 6 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Write 58 in expanded form.', null, '50 + 8', '5 tens are worth 50; add 8 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Write 72 in expanded form.', null, '70 + 2', '7 tens are worth 70; add 2 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Write 45 in expanded form.', null, '40 + 5', '4 tens are worth 40; add 5 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Write 83 in expanded form.', null, '80 + 3', '8 tens are worth 80; add 3 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Write 27 in expanded form.', null, '20 + 7', '2 tens are worth 20; add 7 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Write 90 in expanded form.', null, '90 + 0', '9 tens are worth 90; add 0 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Write 14 in expanded form.', null, '10 + 4', '1 tens are worth 10; add 4 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Write 69 in expanded form.', null, '60 + 9', '6 tens are worth 60; add 9 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Write 51 in expanded form.', null, '50 + 1', '5 tens are worth 50; add 1 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Write 78 in expanded form.', null, '70 + 8', '7 tens are worth 70; add 8 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Write 32 in expanded form.', null, '30 + 2', '3 tens are worth 30; add 2 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Write 96 in expanded form.', null, '90 + 6', '9 tens are worth 90; add 6 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Write 40 in expanded form.', null, '40 + 0', '4 tens are worth 40; add 0 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Write 65 in expanded form.', null, '60 + 5', '6 tens are worth 60; add 5 ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 4, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W04-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W04-D5 was not found.';
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
      'The student will review foundational tens-and-ones representation, composition, and decomposition before completing the Week 4 online check.', 'I can show a two-digit number with tens and ones in different ways.', '["pencil", "scratch paper", "optional base-ten drawing space"]'::jsonb, '[{"term": "ten", "definition": "a group of 10 ones"}, {"term": "ones", "definition": "single units left after making groups of ten"}, {"term": "digit", "definition": "a symbol used to write a number"}, {"term": "place", "definition": "a digit''s position in a number"}]'::jsonb,
      'Review the week with one example: 46 = 4 tens and 6 ones = 40 + 6. Ask the student to explain each part.', 'Model only one neutral number such as 32. Then remove supports for the independent readiness items unless they are part of normal accommodations.', 'This is the first of two weeks on 1-MATH-04. The Week 4 check measures foundational understanding; Week 5 deepens digit value and multiple representations.',
      'Remember:
The left digit tells tens.
The right digit tells ones.
6 tens and 3 ones = 63.
63 = 60 + 3.', 'Use guided items to review the connection among numeral, tens-and-ones form, and expanded form.', 'Complete readiness items independently before the online check.', 'Three Ways: choose one two-digit number and show it as a numeral, tens-and-ones statement, and expanded form.',
      'Week 4 Readiness Review', 'Use tens and ones to complete each problem.', 'Complete the readiness review and Week 4 online assessment independently. A perfect score is not required; use configured mastery evidence rules.',
      'Normal testing supports are allowed. Do not tell the student which digit belongs in which place during the assessment.', 'Choose a two-digit number and write three different clues that identify it by place value.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Show 64 as tens and ones.', null, '6 tens and 4 ones', '64 has six tens and four ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Write 53 in expanded form.', null, '50 + 3', 'Five tens are worth 50, plus 3 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'What number is 8 tens and 2 ones?', null, '82', '80 + 2 = 82.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'In 47, what is the value of the 4?', null, '40', 'The 4 is in the tens place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'In 47, what is the value of the 7?', null, '7', 'The 7 is in the ones place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'What number is 3 tens and 9 ones?', null, '39', '30 + 9 = 39.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Write 70 in expanded form.', null, '70 + 0', 'Seven tens are 70 and there are zero ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Show 28 as tens and ones.', null, '2 tens and 8 ones', '28 has two tens and eight ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Write 61 in expanded form.', null, '60 + 1', 'Six tens are 60, plus one.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'What number is 4 tens and 5 ones?', null, '45', '40 + 5 = 45.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'In 92, what is the value of the 9?', null, '90', 'The 9 is in the tens place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'In 92, what is the value of the 2?', null, '2', 'The 2 is in the ones place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Show 50 as tens and ones.', null, '5 tens and 0 ones', '50 is five tens and zero ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Write 37 in expanded form.', null, '30 + 7', '37 is three tens and seven ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'What number is 7 tens and 6 ones?', null, '76', '70 + 6 = 76.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 5, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W05-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W05-D1 was not found.';
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
      'The student will state the value of individual tens and ones digits in two-digit numbers.', 'I can tell what each digit is worth.', '["pencil", "paper", "optional base-ten blocks or bundled craft sticks", "optional tens-and-ones chart"]'::jsonb, '[{"term": "ten", "definition": "a group of 10 ones"}, {"term": "ones", "definition": "single units left after making groups of ten"}, {"term": "digit", "definition": "a symbol used to write a number"}, {"term": "place", "definition": "a digit''s position in a number"}, {"term": "value", "definition": "how much a digit represents because of its place"}]'::jsonb,
      'Write 47. Ask: ''Is the 4 worth 4 or 40?'' Build four tens to show that the tens digit represents 40.', 'Model 62: the 6 is worth 60 and the 2 is worth 2. Compare 26 to show that the same digits have different values when their places switch.', 'Separate digit from value in your wording. A digit may be 6, but its value in the tens place is 60.',
      'A digit''s value depends on its place.

In 47:
4 is in the tens place, so it is worth 40.
7 is in the ones place, so it is worth 7.

In 74, the values switch: 7 is worth 70 and 4 is worth 4.', 'Name the place first, then say the value.', 'State the requested digit value without building every number.', 'Value Flip: compare pairs like 27 and 72, 36 and 63. Tell how the value of each digit changes.',
      'Digit Value', 'Write the value of the named digit.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain why a tens digit is worth groups of ten.',
      'Write a small T above the tens digit and O above the ones digit until the student can identify place automatically.', 'Ask the student how much greater the value of a digit is when the same nonzero digit moves from ones to tens.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'In 47, what is the value of the 4 in the tens place?', null, '40', 'The 4 is in the tens place, so its value is 40.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'In 62, what is the value of the 2 in the ones place?', null, '2', 'The 2 is in the ones place, so its value is 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'In 85, what is the value of the 8 in the tens place?', null, '80', 'The 8 is in the tens place, so its value is 80.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'In 34, what is the value of the 4 in the ones place?', null, '4', 'The 4 is in the ones place, so its value is 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'In 71, what is the value of the 7 in the tens place?', null, '70', 'The 7 is in the tens place, so its value is 70.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'In 96, what is the value of the 6 in the ones place?', null, '6', 'The 6 is in the ones place, so its value is 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'In 28, what is the value of the 2 in the tens place?', null, '20', 'The 2 is in the tens place, so its value is 20.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'In 53, what is the value of the 3 in the ones place?', null, '3', 'The 3 is in the ones place, so its value is 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'In 79, what is the value of the 7 in the tens place?', null, '70', 'The 7 is in the tens place, so its value is 70.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'In 41, what is the value of the 1 in the ones place?', null, '1', 'The 1 is in the ones place, so its value is 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'In 68, what is the value of the 6 in the tens place?', null, '60', 'The 6 is in the tens place, so its value is 60.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'In 92, what is the value of the 2 in the ones place?', null, '2', 'The 2 is in the ones place, so its value is 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'In 36, what is the value of the 3 in the tens place?', null, '30', 'The 3 is in the tens place, so its value is 30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'In 57, what is the value of the 7 in the ones place?', null, '7', 'The 7 is in the ones place, so its value is 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'In 84, what is the value of the 8 in the tens place?', null, '80', 'The 8 is in the tens place, so its value is 80.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 5, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W05-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W05-D2 was not found.';
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
      'The student will represent the same two-digit number in numeral, tens-and-ones, and expanded forms.', 'I can show the same number in more than one place-value form.', '["pencil", "paper", "optional base-ten blocks or bundled craft sticks", "optional tens-and-ones chart"]'::jsonb, '[{"term": "ten", "definition": "a group of 10 ones"}, {"term": "ones", "definition": "single units left after making groups of ten"}, {"term": "digit", "definition": "a symbol used to write a number"}, {"term": "place", "definition": "a digit''s position in a number"}, {"term": "equivalent", "definition": "different forms that show the same amount"}]'::jsonb,
      'Display 42, ''4 tens and 2 ones,'' and ''40 + 2.'' Ask what all three have in common.', 'Model moving among forms in both directions. Start with 67, write 6 tens and 7 ones, then 60 + 7. Then start with 30 + 8 and return to 38.', 'The competency requires composition/decomposition in multiple forms. Ask the student to explain why the forms are equal, not just copy a pattern.',
      'One number can be shown in several equivalent forms.

42
4 tens and 2 ones
40 + 2

All three represent the same amount.', 'Translate one form at a time and check that the amount stays the same.', 'Give two place-value forms for each numeral independently.', 'Representation Triangle: write a numeral at one corner, tens-and-ones form at another, and expanded form at the third.',
      'Multiple Place-Value Forms', 'For each numeral, write tens-and-ones form and expanded form.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain one set of equivalent forms.',
      'Provide a three-column organizer labeled Numeral / Tens and Ones / Expanded Form.', 'Give one form, such as 70 + 4, and ask the student to generate all other forms without seeing the numeral first.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Give two place-value forms for 42: tens-and-ones form and expanded form.', null, '4 tens and 2 ones; 40 + 2', '42 has 4 tens and 2 ones, so 42 = 40 + 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Give two place-value forms for 67: tens-and-ones form and expanded form.', null, '6 tens and 7 ones; 60 + 7', '67 has 6 tens and 7 ones, so 67 = 60 + 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Give two place-value forms for 31: tens-and-ones form and expanded form.', null, '3 tens and 1 ones; 30 + 1', '31 has 3 tens and 1 ones, so 31 = 30 + 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Give two place-value forms for 85: tens-and-ones form and expanded form.', null, '8 tens and 5 ones; 80 + 5', '85 has 8 tens and 5 ones, so 85 = 80 + 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Give two place-value forms for 29: tens-and-ones form and expanded form.', null, '2 tens and 9 ones; 20 + 9', '29 has 2 tens and 9 ones, so 29 = 20 + 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Give two place-value forms for 54: tens-and-ones form and expanded form.', null, '5 tens and 4 ones; 50 + 4', '54 has 5 tens and 4 ones, so 54 = 50 + 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Give two place-value forms for 73: tens-and-ones form and expanded form.', null, '7 tens and 3 ones; 70 + 3', '73 has 7 tens and 3 ones, so 73 = 70 + 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Give two place-value forms for 16: tens-and-ones form and expanded form.', null, '1 tens and 6 ones; 10 + 6', '16 has 1 tens and 6 ones, so 16 = 10 + 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Give two place-value forms for 48: tens-and-ones form and expanded form.', null, '4 tens and 8 ones; 40 + 8', '48 has 4 tens and 8 ones, so 48 = 40 + 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Give two place-value forms for 62: tens-and-ones form and expanded form.', null, '6 tens and 2 ones; 60 + 2', '62 has 6 tens and 2 ones, so 62 = 60 + 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Give two place-value forms for 91: tens-and-ones form and expanded form.', null, '9 tens and 1 ones; 90 + 1', '91 has 9 tens and 1 ones, so 91 = 90 + 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Give two place-value forms for 35: tens-and-ones form and expanded form.', null, '3 tens and 5 ones; 30 + 5', '35 has 3 tens and 5 ones, so 35 = 30 + 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Give two place-value forms for 77: tens-and-ones form and expanded form.', null, '7 tens and 7 ones; 70 + 7', '77 has 7 tens and 7 ones, so 77 = 70 + 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Give two place-value forms for 24: tens-and-ones form and expanded form.', null, '2 tens and 4 ones; 20 + 4', '24 has 2 tens and 4 ones, so 24 = 20 + 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Give two place-value forms for 58: tens-and-ones form and expanded form.', null, '5 tens and 8 ones; 50 + 8', '58 has 5 tens and 8 ones, so 58 = 50 + 8.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 5, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W05-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W05-D3 was not found.';
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
      'The student will accurately represent multiples of ten and teen numbers using tens and ones, including zero ones.', 'I can use tens and ones even when the ones digit is zero or the number is a teen.', '["pencil", "paper", "optional base-ten blocks or bundled craft sticks", "optional tens-and-ones chart"]'::jsonb, '[{"term": "ten", "definition": "a group of 10 ones"}, {"term": "ones", "definition": "single units left after making groups of ten"}, {"term": "digit", "definition": "a symbol used to write a number"}, {"term": "place", "definition": "a digit''s position in a number"}]'::jsonb,
      'Compare 50 and 15. Ask how many tens and ones are in each. Explain that zero in the ones place still carries important information.', 'Model 30 = 3 tens and 0 ones, 70 = 7 tens and 0 ones, 14 = 1 ten and 4 ones, and 19 = 1 ten and 9 ones.', 'Common errors include omitting the zero in 40 or treating 14 as 4 tens and 1 one. Return to the place-value chart.',
      'Multiples of ten have 0 leftover ones:
50 = 5 tens and 0 ones.

Teen numbers have 1 ten:
14 = 1 ten and 4 ones.
19 = 1 ten and 9 ones.', 'Use models to compare a multiple of ten with a teen number.', 'Work without a model first, then check with one if needed.', 'Zero Matters: sort number cards into ''0 ones'' and ''some ones,'' then identify the tens in each.',
      'Zero Ones and Teen Numbers', 'Use place value carefully. Watch the position of zero and the teen digits.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and correctly represent both a multiple of ten and a teen number.',
      'Keep a tens/ones mat visible and physically place a 0 card in the ones column for multiples of ten.', 'Ask why 50 cannot be written 5 even though it has five tens.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'How many tens and ones are in 40?', null, '4 tens and 0 ones', 'The zero means there are no leftover ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'What number is 7 tens and 0 ones?', null, '70', 'Seven tens make 70.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'In 60, what is the value of the 6?', null, '60', 'The 6 is in the tens place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Write 30 in expanded form.', null, '30 + 0', '3 tens are worth 30 and there are 0 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'What number is 9 tens and 0 ones?', null, '90', 'Nine tens make 90.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'How many tens and ones are in 14?', null, '1 ten and 4 ones', '14 is one ten and four ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'How many tens and ones are in 19?', null, '1 ten and 9 ones', '19 is one ten and nine ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'How many tens and ones are in 20?', null, '2 tens and 0 ones', '20 has two tens and no leftover ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'What number is 5 tens and 0 ones?', null, '50', 'Five tens make 50.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Write 80 in expanded form.', null, '80 + 0', 'Eight tens are worth 80.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'In 70, what is the value of the 7?', null, '70', 'The 7 is in the tens place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'How many tens and ones are in 12?', null, '1 ten and 2 ones', '12 has one ten and two ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Write 16 in expanded form.', null, '10 + 6', '16 is one ten and six ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'What number is 1 ten and 8 ones?', null, '18', '10 + 8 = 18.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'In 90, what is the value of the 0?', null, '0', 'There are zero ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 5, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W05-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W05-D4 was not found.';
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
      'The student will apply place-value knowledge to compose, decompose, and state digit values in mixed two-digit problems.', 'I can use place value to solve different kinds of tens-and-ones problems.', '["pencil", "paper", "optional base-ten blocks or bundled craft sticks", "optional tens-and-ones chart"]'::jsonb, '[{"term": "ten", "definition": "a group of 10 ones"}, {"term": "ones", "definition": "single units left after making groups of ten"}, {"term": "digit", "definition": "a symbol used to write a number"}, {"term": "place", "definition": "a digit''s position in a number"}]'::jsonb,
      'Review that one number can be approached several ways. Use 64: 6 tens 4 ones, 60+4, value of 6 is 60, value of 4 is 4.', 'Model a mixed set where the task changes each time. Teach the student to read the question first: ''Am I finding the number, breaking it apart, or finding a digit''s value?''', 'Mixed practice is intentionally less predictable. Encourage the student to name the task before calculating.',
      'Place-value problems may ask you to:
• find tens and ones
• make a numeral
• write expanded form
• tell a digit''s value

Read the question carefully and use the place of each digit.', 'Name the type of problem before solving.', 'Complete the mixed problems independently.', 'Place-Value Detective: the instructor gives clues such as ''6 tens, 2 ones'' or ''my tens digit is worth 70.'' The student identifies the number.',
      'Mixed Place-Value Practice', 'Read each question carefully and use the correct place-value form.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and correctly solve examples from at least three different place-value task types.',
      'Use a reference strip listing the four task types without giving worked answers.', 'Have the student create a place-value riddle for a two-digit number and include both digit values.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Show 64 as tens and ones.', null, '6 tens and 4 ones', '64 has six tens and four ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Write 53 in expanded form.', null, '50 + 3', 'Five tens are worth 50, plus 3 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'What number is 8 tens and 2 ones?', null, '82', '80 + 2 = 82.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'In 47, what is the value of the 4?', null, '40', 'The 4 is in the tens place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'In 47, what is the value of the 7?', null, '7', 'The 7 is in the ones place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'What number is 3 tens and 9 ones?', null, '39', '30 + 9 = 39.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Write 70 in expanded form.', null, '70 + 0', 'Seven tens are 70 and there are zero ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Show 28 as tens and ones.', null, '2 tens and 8 ones', '28 has two tens and eight ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Write 61 in expanded form.', null, '60 + 1', 'Six tens are 60, plus one.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'What number is 4 tens and 5 ones?', null, '45', '40 + 5 = 45.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'In 92, what is the value of the 9?', null, '90', 'The 9 is in the tens place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'In 92, what is the value of the 2?', null, '2', 'The 2 is in the ones place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Show 50 as tens and ones.', null, '5 tens and 0 ones', '50 is five tens and zero ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Write 37 in expanded form.', null, '30 + 7', '37 is three tens and seven ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'What number is 7 tens and 6 ones?', null, '76', '70 + 6 = 76.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 5, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W05-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W05-D5 was not found.';
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
      'The student will independently demonstrate the full 1-MATH-04 place-value objective across tens-and-ones representation, digit value, composition, and decomposition before the Week 5 online check.', 'I can show what I know about tens and ones.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "ten", "definition": "a group of 10 ones"}, {"term": "ones", "definition": "single units left after making groups of ten"}, {"term": "digit", "definition": "a symbol used to write a number"}, {"term": "place", "definition": "a digit''s position in a number"}]'::jsonb,
      'Ask the student to show 58 in as many place-value forms as possible. Use the response to review terminology, not to reteach the assessment.', 'Model one neutral number such as 43 in numeral, tens-and-ones, and expanded form, then identify each digit''s value.', 'Week 5 is the second competency check for 1-MATH-04. It should function as additional independent evidence rather than replacing the Week 4 result.',
      'Check every part of the question:
58 = 5 tens and 8 ones
58 = 50 + 8
The 5 is worth 50.
The 8 is worth 8.', 'Use the guided questions as a brief readiness check.', 'Complete the readiness work and online check independently.', 'Explain One Number: choose one number and explain its tens, ones, expanded form, and both digit values.',
      'Week 5 Place-Value Readiness', 'Complete the mixed place-value review before the online Week 5 Check.', 'Complete the readiness review and Week 5 online assessment independently using the existing competency threshold and repeated evidence rules.',
      'Use normal accommodations, but do not identify places, values, or forms for the student during the assessment.', 'Create a four-clue place-value puzzle for a number from 10–99.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Show 64 as tens and ones.', null, '6 tens and 4 ones', '64 has six tens and four ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Write 53 in expanded form.', null, '50 + 3', 'Five tens are worth 50, plus 3 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'What number is 8 tens and 2 ones?', null, '82', '80 + 2 = 82.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'In 47, what is the value of the 4?', null, '40', 'The 4 is in the tens place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'In 47, what is the value of the 7?', null, '7', 'The 7 is in the ones place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'What number is 3 tens and 9 ones?', null, '39', '30 + 9 = 39.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Write 70 in expanded form.', null, '70 + 0', 'Seven tens are 70 and there are zero ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Show 28 as tens and ones.', null, '2 tens and 8 ones', '28 has two tens and eight ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Write 61 in expanded form.', null, '60 + 1', 'Six tens are 60, plus one.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'What number is 4 tens and 5 ones?', null, '45', '40 + 5 = 45.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'In 92, what is the value of the 9?', null, '90', 'The 9 is in the tens place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'In 92, what is the value of the 2?', null, '2', 'The 2 is in the ones place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Show 50 as tens and ones.', null, '5 tens and 0 ones', '50 is five tens and zero ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Write 37 in expanded form.', null, '30 + 7', '37 is three tens and seven ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'What number is 7 tens and 6 ones?', null, '76', '70 + 6 = 76.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 6, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W06-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W06-D1 was not found.';
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
      'The student will use >, <, and = to record comparisons between two-digit numbers, connecting each symbol to greater than, less than, or equal.', 'I can use >, <, and = to compare numbers.', '["pencil", "paper", "optional tens-and-ones chart", "optional number line"]'::jsonb, '[{"term": "greater than", "definition": "a number has a larger value"}, {"term": "less than", "definition": "a number has a smaller value"}, {"term": "equal", "definition": "two values are the same"}, {"term": "compare", "definition": "decide how two values relate"}]'::jsonb,
      'Write 24 and 31. Ask which number is larger. Then introduce the comparison statement 24 < 31. Repeat with equal numbers such as 45 = 45.', 'Model the symbols with words first: 52 is greater than 37, so 52 > 37. Read every statement from left to right. Avoid relying only on an ''alligator mouth'' trick; connect the symbol to actual number value.', 'The student should learn the meaning of the symbols, not only their shape. Have them read finished comparisons aloud.',
      '> means greater than.
< means less than.
= means equal.

Read left to right:
42 > 36 means 42 is greater than 36.
24 < 31 means 24 is less than 31.
55 = 55 means the values are equal.', 'Say the relationship in words before choosing a symbol.', 'Choose the correct comparison symbol independently.', 'Symbol Match: make cards for >, <, = and place the correct card between pairs of two-digit numbers.',
      'Comparison Symbols', 'Choose >, <, or = to make each statement true.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and correctly read at least three symbol statements aloud.',
      'Keep a reference showing symbol + words. Let the student say ''greater than'' or ''less than'' before writing the symbol.', 'Write a true comparison for each symbol using numbers of the student''s choice.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Compare 24 and 31. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 2 tens versus 3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Compare 42 and 36. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 4 tens versus 3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Compare 55 and 55. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 55, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Compare 18 and 27. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 1 tens versus 2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Compare 63 and 52. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 6 tens versus 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Compare 40 and 40. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 40, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Compare 71 and 79. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 1 ones with 9 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Compare 32 and 23. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 3 tens versus 2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Compare 66 and 60. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 6 ones with 0 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Compare 45 and 54. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 4 tens versus 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Compare 80 and 78. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 8 tens versus 7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Compare 29 and 29. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 29, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Compare 57 and 61. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 5 tens versus 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Compare 73 and 37. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 7 tens versus 3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Compare 48 and 48. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 48, so they are equal.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 6, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W06-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W06-D2 was not found.';
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
      'The student will compare two-digit numbers with different tens digits by reasoning about tens before ones.', 'I can compare the tens first.', '["pencil", "paper", "optional tens-and-ones chart", "optional number line"]'::jsonb, '[{"term": "greater than", "definition": "a number has a larger value"}, {"term": "less than", "definition": "a number has a smaller value"}, {"term": "equal", "definition": "two values are the same"}, {"term": "compare", "definition": "decide how two values relate"}]'::jsonb,
      'Compare 32 and 47 using tens blocks or quick drawings. Ask whether the ones need to be compared once we know 3 tens is less than 4 tens.', 'Model 61 vs 25: 6 tens is greater than 2 tens, so 61 > 25. Explain that when tens differ, the larger number of tens decides the larger number.', 'Discourage comparing ones first. In 28 vs 45, 8 ones is greater than 5 ones, but 2 tens is still less than 4 tens, so 28 < 45.',
      'Compare tens first.

32 vs 47:
3 tens < 4 tens
so 32 < 47.

If the tens are different, you already know which two-digit number is greater.', 'State the tens in each number before choosing the symbol.', 'Compare using tens reasoning without a model when possible.', 'Tens Battle: draw two number cards. Say the tens in each and decide which number is greater before looking closely at the ones.',
      'Compare the Tens', 'Compare each pair by looking at the tens first.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain three comparisons using tens reasoning.',
      'Underline or color the tens digits during guided work.', 'Ask the student to create two numbers where the first has fewer ones but is still greater because it has more tens.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Compare 32 and 47. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 3 tens versus 4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Compare 61 and 25. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 6 tens versus 2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Compare 54 and 73. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 5 tens versus 7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Compare 28 and 45. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 2 tens versus 4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Compare 82 and 39. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 8 tens versus 3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Compare 16 and 64. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 1 tens versus 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Compare 71 and 52. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 7 tens versus 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Compare 43 and 68. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 4 tens versus 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Compare 95 and 41. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 9 tens versus 4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Compare 22 and 87. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 2 tens versus 8 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Compare 76 and 31. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 7 tens versus 3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Compare 58 and 92. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 5 tens versus 9 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Compare 35 and 69. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 3 tens versus 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Compare 84 and 20. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 8 tens versus 2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Compare 63 and 49. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 6 tens versus 4 tens.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 6, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W06-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W06-D3 was not found.';
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
      'The student will compare two-digit numbers with equal tens by comparing the ones digits.', 'I can compare the ones when the tens are the same.', '["pencil", "paper", "optional tens-and-ones chart", "optional number line"]'::jsonb, '[{"term": "greater than", "definition": "a number has a larger value"}, {"term": "less than", "definition": "a number has a smaller value"}, {"term": "equal", "definition": "two values are the same"}, {"term": "compare", "definition": "decide how two values relate"}]'::jsonb,
      'Write 42 and 47. Ask what is the same. Once the student sees both have 4 tens, ask what decides the comparison.', 'Model 68 vs 63: both have 6 tens; compare 8 ones with 3 ones, so 68 > 63. Include equality such as 55 = 55.', 'If tens match, the ones decide. Continue to verbalize both steps so the student builds a consistent comparison routine.',
      'Step 1: Compare tens.
Step 2: If the tens are equal, compare ones.

42 and 47 both have 4 tens.
2 ones < 7 ones.
So 42 < 47.', 'Confirm that the tens match before moving to ones.', 'Use the two-step routine independently.', 'Same-Tens Sort: group cards by tens digit, then order each small group by the ones digit.',
      'Compare the Ones', 'The tens match in many problems. Use the ones to decide.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain why ones matter only after equal tens.',
      'Use a TENS | ONES chart and cover the ones column until the tens comparison is complete.', 'Create three numbers with the same tens digit and order them from least to greatest.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Compare 42 and 47. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 2 ones with 7 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Compare 68 and 63. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 8 ones with 3 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Compare 55 and 55. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 55, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Compare 31 and 39. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 1 ones with 9 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Compare 74 and 71. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 4 ones with 1 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Compare 26 and 28. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 6 ones with 8 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Compare 83 and 80. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 3 ones with 0 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Compare 47 and 49. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 7 ones with 9 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Compare 62 and 61. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 2 ones with 1 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Compare 95 and 98. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 5 ones with 8 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Compare 33 and 30. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 3 ones with 0 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Compare 79 and 72. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 9 ones with 2 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Compare 54 and 54. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 54, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Compare 86 and 89. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 6 ones with 9 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Compare 21 and 27. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 1 ones with 7 ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 6, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W06-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W06-D4 was not found.';
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
      'The student will apply the full comparison routine, including equality and checking whether written >, <, or = statements are true.', 'I can compare tens, compare ones if needed, and use the correct symbol.', '["pencil", "paper", "optional tens-and-ones chart", "optional number line"]'::jsonb, '[{"term": "greater than", "definition": "a number has a larger value"}, {"term": "less than", "definition": "a number has a smaller value"}, {"term": "equal", "definition": "two values are the same"}, {"term": "compare", "definition": "decide how two values relate"}]'::jsonb,
      'Review the decision routine: tens first, ones second, equality if both digits match. Show 71 and 71 as a case where neither number is greater.', 'Model checking a statement such as 48 > 51. Compare tens and conclude it is false. Then rewrite it as 48 < 51.', 'Truth-check problems require evaluating the numbers, not trusting the symbol already printed.',
      'Comparison routine:
1. Compare tens.
2. If tens match, compare ones.
3. If both places match, use =.
4. Read the finished statement to make sure it makes sense.', 'Explain each decision using the routine.', 'Solve comparison and true/false statements independently.', 'True or Fix It: write comparison statements on cards. The student says true or false and fixes every false statement.',
      'Apply >, <, and =', 'Compare carefully. Some problems ask whether a statement is true.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and correctly repair at least two false comparisons.',
      'Let the student circle tens digits first and ones digits second.', 'Ask the student to write one true statement and one false statement for another person to check.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Compare 44 and 44: >, <, or =?', null, '=', 'The numbers are the same.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Compare 37 and 39: >, <, or =?', null, '<', 'Both have 3 tens; 7 ones is less than 9 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Compare 62 and 52: >, <, or =?', null, '>', '6 tens is greater than 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Is 71 = 71 true or false?', null, 'true', 'Both sides are the same number.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Is 48 > 51 true or false?', null, 'false', '4 tens is less than 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Is 66 < 63 true or false?', null, 'false', 'With equal tens, 6 ones is greater than 3 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Choose the symbol: 80 __ 80.', null, '=', 'The numbers are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Choose the symbol: 29 __ 29.', null, '=', 'The numbers are the same.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Choose the symbol: 45 __ 54.', null, '<', '4 tens is less than 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Choose the symbol: 78 __ 72.', null, '>', 'The tens match; 8 ones is greater than 2 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Is 61 > 58 true or false?', null, 'true', '6 tens is greater than 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Is 33 < 33 true or false?', null, 'false', 'Equal numbers use =.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Choose the symbol: 90 __ 89.', null, '>', '9 tens is greater than 8 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Choose the symbol: 24 __ 27.', null, '<', 'The tens match; 4 ones is less than 7 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Choose the symbol: 56 __ 56.', null, '=', 'The numbers are equal.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 6, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W06-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W06-D5 was not found.';
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
      'The student will independently demonstrate introductory comparison of two-digit numbers using >, <, and = with tens-first reasoning before the Week 6 online check.', 'I can compare two-digit numbers and use the correct symbol.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "greater than", "definition": "a number has a larger value"}, {"term": "less than", "definition": "a number has a smaller value"}, {"term": "equal", "definition": "two values are the same"}, {"term": "compare", "definition": "decide how two values relate"}]'::jsonb,
      'Review one example with different tens, one with equal tens, and one equality example. Ask the student to say the reasoning aloud.', 'Model only neutral examples. The assessment should reflect the student''s own comparison routine.', 'Week 6 is the first check for 1-MATH-05. Week 7 will add ordering and explanation/application while continuing the same core comparison objective.',
      'Remember: compare tens first. If they match, compare ones. If both digits match, the numbers are equal.', 'Use guided items as a short warm-up.', 'Complete readiness items and the online Week 6 Check independently.', 'Comparison Explanation: choose one problem and explain why the symbol is correct using tens and ones.',
      'Week 6 Readiness Review', 'Choose >, <, or = and use place value to check each answer.', 'Complete the readiness review and Week 6 online assessment independently under the configured evidence rules.',
      'Normal testing accommodations are allowed. Do not tell the student which symbol to choose.', 'Create three comparisons—one for >, one for <, and one for =.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Compare 47 and 52. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 4 tens versus 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Compare 68 and 63. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 8 ones with 3 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Compare 55 and 55. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 55, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Compare 29 and 31. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 2 tens versus 3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Compare 74 and 71. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 4 ones with 1 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Compare 86 and 92. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 8 tens versus 9 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Compare 43 and 43. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 43, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Compare 67 and 76. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 6 tens versus 7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Compare 80 and 79. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 8 tens versus 7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Compare 35 and 39. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 5 ones with 9 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Compare 62 and 26. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 6 tens versus 2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Compare 91 and 91. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 91, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Compare 58 and 61. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 5 tens versus 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Compare 44 and 40. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 4 ones with 0 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Compare 73 and 78. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 3 ones with 8 ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 7, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W07-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W07-D1 was not found.';
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
      'The student will fluently compare mixed pairs of two-digit numbers using tens-first, ones-second reasoning.', 'I can compare any two two-digit numbers using place value.', '["pencil", "paper", "optional tens-and-ones chart", "optional number line"]'::jsonb, '[{"term": "greater than", "definition": "a number has a larger value"}, {"term": "less than", "definition": "a number has a smaller value"}, {"term": "equal", "definition": "two values are the same"}, {"term": "compare", "definition": "decide how two values relate"}]'::jsonb,
      'Mix examples with different tens, same tens, and equal numbers. Ask the student to identify which comparison step decides each one.', 'Model 47 vs 52, 68 vs 63, and 55 vs 55. Label the deciding evidence: tens, ones, or equality.', 'The goal this week is flexible application and explanation, not a new symbol rule.',
      'Every comparison uses the same place-value routine.

Different tens? Tens decide.
Same tens? Ones decide.
Same tens and ones? Equal.', 'Name which place decides each comparison.', 'Compare mixed pairs independently.', 'Decision Sort: after solving comparison cards, sort them into ''tens decided,'' ''ones decided,'' and ''equal.''',
      'Mixed Two-Digit Comparisons', 'Use >, <, or = and decide which place proves your answer.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and correctly identify the deciding place in three examples.',
      'Use a two-step checklist: 1 Tens? 2 Ones? Let the student mark each step.', 'Ask the student to create one pair for each decision category.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Compare 47 and 52. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 4 tens versus 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Compare 68 and 63. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 8 ones with 3 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Compare 55 and 55. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 55, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Compare 29 and 31. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 2 tens versus 3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Compare 74 and 71. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 4 ones with 1 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Compare 86 and 92. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 8 tens versus 9 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Compare 43 and 43. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 43, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Compare 67 and 76. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 6 tens versus 7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Compare 80 and 79. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 8 tens versus 7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Compare 35 and 39. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 5 ones with 9 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Compare 62 and 26. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 6 tens versus 2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Compare 91 and 91. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 91, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Compare 58 and 61. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 5 tens versus 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Compare 44 and 40. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 4 ones with 0 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Compare 73 and 78. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 3 ones with 8 ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 7, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W07-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W07-D2 was not found.';
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
      'The student will use pairwise place-value comparisons to order sets of three two-digit numbers from least to greatest or greatest to least.', 'I can put several two-digit numbers in order.', '["pencil", "paper", "optional tens-and-ones chart", "optional number line"]'::jsonb, '[{"term": "greater than", "definition": "a number has a larger value"}, {"term": "less than", "definition": "a number has a smaller value"}, {"term": "equal", "definition": "two values are the same"}, {"term": "compare", "definition": "decide how two values relate"}, {"term": "least", "definition": "smallest value"}, {"term": "greatest", "definition": "largest value"}]'::jsonb,
      'Write 42, 27, 35. Ask which is least and which is greatest. Explain that ordering several numbers is repeated comparison.', 'Model finding the least number by tens first, then compare the remaining two. Repeat with same-tens numbers such as 61, 68, 64.', 'Although the competency is written around comparing pairs, ordering three numbers strengthens the same place-value comparison reasoning.',
      'To order numbers:
1. Find the least or greatest using tens.
2. If tens match, use ones.
3. Compare the numbers that remain.

Check the final list from left to right.', 'Talk through which number belongs first, then compare the remaining pair.', 'Order each set independently.', 'Number Lineup: write three numbers on cards and physically arrange them least-to-greatest, then reverse them.',
      'Order Two-Digit Numbers', 'Put each set in the requested order using tens and ones.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain the first comparison used in one ordering problem.',
      'Use individual number cards so the student can move them while reasoning.', 'Order sets of four two-digit numbers after mastering sets of three.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Order from least to greatest: 42, 27, 35.', null, '27, 35, 42', 'Compare tens first: 2 tens, then 3 tens, then 4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Order from greatest to least: 61, 68, 64.', null, '68, 64, 61', 'All have 6 tens, so compare ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Order from least to greatest: 50, 45, 54.', null, '45, 50, 54', '45 has 4 tens; then compare the numbers with 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Order from least to greatest: 73, 37, 70.', null, '37, 70, 73', '3 tens is least; then compare 70 and 73.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Order from greatest to least: 29, 92, 59.', null, '92, 59, 29', 'Compare the tens digits 9, 5, and 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Order from least to greatest: 66, 60, 63.', null, '60, 63, 66', 'All have 6 tens; compare ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Order from greatest to least: 41, 44, 40.', null, '44, 41, 40', 'All have 4 tens; compare ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Order least to greatest: 18, 31, 24.', null, '18, 24, 31', 'Compare tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Order greatest to least: 72, 27, 70.', null, '72, 70, 27', '7 tens beats 2 tens; then compare ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Order least to greatest: 55, 51, 58.', null, '51, 55, 58', 'Same tens; compare ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Order greatest to least: 83, 38, 80.', null, '83, 80, 38', '8 tens beats 3 tens; compare 83 and 80.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Order least to greatest: 46, 64, 44.', null, '44, 46, 64', '44 and 46 have 4 tens; 64 has 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Order greatest to least: 90, 89, 99.', null, '99, 90, 89', 'Compare tens, then ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Order least to greatest: 32, 23, 33.', null, '23, 32, 33', '2 tens is least; then compare 32 and 33.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Order greatest to least: 77, 71, 75.', null, '77, 75, 71', 'Same tens; compare ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 7, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W07-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W07-D3 was not found.';
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
      'The student will justify two-digit comparisons orally or in writing using explicit tens-and-ones reasoning.', 'I can explain why one two-digit number is greater, less, or equal.', '["pencil", "paper", "optional tens-and-ones chart", "optional number line"]'::jsonb, '[{"term": "greater than", "definition": "a number has a larger value"}, {"term": "less than", "definition": "a number has a smaller value"}, {"term": "equal", "definition": "two values are the same"}, {"term": "compare", "definition": "decide how two values relate"}]'::jsonb,
      'Show 64 > 59 and ask, ''How do you know without counting from 1?'' Guide the student toward tens reasoning.', 'Model a complete explanation: ''64 > 59 because 6 tens is greater than 5 tens.'' For same tens: ''72 < 78 because both have 7 tens, and 2 ones is less than 8 ones.''', 'Accept age-appropriate wording, but require the explanation to reference number value, tens, or ones rather than symbol shape alone.',
      'A strong comparison answer has two parts:
1. the correct symbol
2. a reason using tens and ones

Example: 72 < 78 because the tens are equal and 2 ones is less than 8 ones.', 'Say the comparison and reason together.', 'Write or say a place-value reason for each comparison.', 'Reason Recorder: solve five comparison cards and record a one-sentence explanation for each.',
      'Explain Your Comparison', 'Write >, <, or = and give a short place-value reason.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and give accurate place-value reasoning on at least three items.',
      'Allow oral explanations to be dictated to the instructor if writing load interferes with demonstrating math reasoning.', 'Ask for two different ways to prove one comparison, such as place value and number-line position.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Compare 64 and 59. Write >, <, or = and explain using tens first, then ones.', null, '>; 6 tens is greater than 5 tens.', '64 > 59 because 6 tens is greater than 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Compare 72 and 78. Write >, <, or = and explain using tens first, then ones.', null, '<; both have 7 tens, so compare 2 ones with 8 ones.', '72 < 78; both have 7 tens, so compare 2 ones with 8 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Compare 43 and 43. Write >, <, or = and explain using tens first, then ones.', null, '=; both numbers have the same tens and ones.', '43 = 43 because both numbers have the same tens and ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Compare 81 and 76. Write >, <, or = and explain using tens first, then ones.', null, '>; 8 tens is greater than 7 tens.', '81 > 76 because 8 tens is greater than 7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Compare 35 and 39. Write >, <, or = and explain using tens first, then ones.', null, '<; both have 3 tens, so compare 5 ones with 9 ones.', '35 < 39; both have 3 tens, so compare 5 ones with 9 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Compare 92 and 29. Write >, <, or = and explain using tens first, then ones.', null, '>; 9 tens is greater than 2 tens.', '92 > 29 because 9 tens is greater than 2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Compare 57 and 54. Write >, <, or = and explain using tens first, then ones.', null, '>; both have 5 tens, so compare 7 ones with 4 ones.', '57 > 54; both have 5 tens, so compare 7 ones with 4 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Compare 66 and 66. Write >, <, or = and explain using tens first, then ones.', null, '=; both numbers have the same tens and ones.', '66 = 66 because both numbers have the same tens and ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Compare 48 and 51. Write >, <, or = and explain using tens first, then ones.', null, '<; 4 tens is less than 5 tens.', '48 < 51 because 4 tens is less than 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Compare 73 and 70. Write >, <, or = and explain using tens first, then ones.', null, '>; both have 7 tens, so compare 3 ones with 0 ones.', '73 > 70; both have 7 tens, so compare 3 ones with 0 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Compare 24 and 42. Write >, <, or = and explain using tens first, then ones.', null, '<; 2 tens is less than 4 tens.', '24 < 42 because 2 tens is less than 4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Compare 89 and 87. Write >, <, or = and explain using tens first, then ones.', null, '>; both have 8 tens, so compare 9 ones with 7 ones.', '89 > 87; both have 8 tens, so compare 9 ones with 7 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Compare 31 and 36. Write >, <, or = and explain using tens first, then ones.', null, '<; both have 3 tens, so compare 1 ones with 6 ones.', '31 < 36; both have 3 tens, so compare 1 ones with 6 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Compare 95 and 95. Write >, <, or = and explain using tens first, then ones.', null, '=; both numbers have the same tens and ones.', '95 = 95 because both numbers have the same tens and ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Compare 60 and 59. Write >, <, or = and explain using tens first, then ones.', null, '>; 6 tens is greater than 5 tens.', '60 > 59 because 6 tens is greater than 5 tens.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 7, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W07-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W07-D4 was not found.';
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
      'The student will apply two-digit comparison reasoning in simple real-world and true-statement contexts.', 'I can use comparison to decide which amount is more, less, or the same.', '["pencil", "paper", "optional tens-and-ones chart", "optional number line"]'::jsonb, '[{"term": "greater than", "definition": "a number has a larger value"}, {"term": "less than", "definition": "a number has a smaller value"}, {"term": "equal", "definition": "two values are the same"}, {"term": "compare", "definition": "decide how two values relate"}]'::jsonb,
      'Give a simple context: one jar has 38 counters and another has 42. Ask which jar has more and how place value proves it.', 'Model translating ''more,'' ''fewer,'' and ''same'' into comparison statements. Example: 67 stickers vs 61 stickers gives 67 > 61.', 'Keep contexts mathematically simple so reading does not become the main difficulty. The target is comparison reasoning.',
      'Comparison words appear in real situations:
more → greater
fewer → less
same → equal

Use the numbers first, then write the symbol statement.', 'Translate each situation into a number comparison.', 'Solve mixed comparison situations independently.', 'Comparison Stories: choose two number cards and invent a one-sentence story where those numbers are compared.',
      'Apply Comparison', 'Use >, <, or = to represent each pair or situation.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and accurately translate one verbal comparison into symbols.',
      'Read story problems aloud if needed. Keep the numbers visible while the student chooses the relationship.', 'Have the student write a comparison story where the smaller-looking ones digit belongs to the greater number because the tens are larger.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Compare 38 and 42. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 3 tens versus 4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Compare 67 and 61. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 7 ones with 1 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Compare 50 and 50. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 50, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Compare 29 and 34. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 2 tens versus 3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Compare 75 and 72. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 5 ones with 2 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Compare 46 and 64. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 4 tens versus 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Compare 88 and 81. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 8 ones with 1 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Compare 33 and 33. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 33, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Compare 57 and 60. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 5 tens versus 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Compare 92 and 89. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 9 tens versus 8 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Compare 41 and 45. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 1 ones with 5 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Compare 76 and 67. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 7 tens versus 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Compare 54 and 54. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 54, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Compare 63 and 70. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 6 tens versus 7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Compare 85 and 82. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 5 ones with 2 ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 7, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W07-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W07-D5 was not found.';
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
      'The student will independently demonstrate the full 1-MATH-05 objective by comparing two-digit numbers with >, <, and = and explaining place-value reasoning before the Week 7 online check.', 'I can compare two-digit numbers and explain my reasoning.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "greater than", "definition": "a number has a larger value"}, {"term": "less than", "definition": "a number has a smaller value"}, {"term": "equal", "definition": "two values are the same"}, {"term": "compare", "definition": "decide how two values relate"}]'::jsonb,
      'Ask the student to state the full comparison routine without looking at notes. Then solve one neutral example together.', 'Model one different-tens example and one same-tens example, emphasizing the reason instead of a memorized symbol trick.', 'Week 7 provides another independent opportunity to demonstrate 1-MATH-05. Use the existing repeated-evidence rules rather than requiring a separate hands-on mastery requirement.',
      'Before choosing a symbol:
• compare tens
• compare ones only if needed
• use = if both values are the same
• read the statement and check that it makes sense.', 'Use guided items as a brief readiness check.', 'Complete the readiness review and Week 7 online check independently.', 'Defend One Answer: after the readiness review, choose one answer and prove it using tens and ones.',
      'Week 7 Comparison Readiness', 'Complete the mixed comparison review before the online Week 7 Check.', 'Complete the readiness review and Week 7 online assessment independently using the configured threshold and repeated evidence rules.',
      'Use normal accommodations. Directions may be read aloud, but do not identify the correct relationship.', 'Create a three-number ordering challenge and explain every comparison needed to solve it.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Compare 47 and 52. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 4 tens versus 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Compare 68 and 63. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 8 ones with 3 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Compare 55 and 55. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 55, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Compare 29 and 31. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 2 tens versus 3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Compare 74 and 71. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 4 ones with 1 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Compare 86 and 92. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 8 tens versus 9 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Compare 43 and 43. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 43, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Compare 67 and 76. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 6 tens versus 7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Compare 80 and 79. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 8 tens versus 7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Compare 35 and 39. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 5 ones with 9 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Compare 62 and 26. Which symbol makes the statement true: >, <, or =?', null, '>', 'Compare tens first: 6 tens versus 2 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Compare 91 and 91. Which symbol makes the statement true: >, <, or =?', null, '=', 'Both numbers are 91, so they are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Compare 58 and 61. Which symbol makes the statement true: >, <, or =?', null, '<', 'Compare tens first: 5 tens versus 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Compare 44 and 40. Which symbol makes the statement true: >, <, or =?', null, '>', 'The tens are equal, so compare 4 ones with 0 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Compare 73 and 78. Which symbol makes the statement true: >, <, or =?', null, '<', 'The tens are equal, so compare 3 ones with 8 ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 3 online Friday check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 3
      and l.week_number = 3
      and l.day_number = 5
      and a.active is true
    limit 1;

    if v_template_id is null then
      raise exception 'Expected Grade 1 Math Week 3 assessment template was not found.';
    end if;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W03-Q01', 1, 'short_answer', 'Continue by 10s: 30, 40, 50, __', '[]'::jsonb, '60', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W03-Q02', 2, 'short_answer', 'Continue by 5s: 20, 25, 30, __', '[]'::jsonb, '35', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W03-Q03', 3, 'short_answer', 'Continue by 2s: 42, 44, 46, __', '[]'::jsonb, '48', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W03-Q04', 4, 'multiple_choice', 'Which rule fits 14, 16, 18, 20?', '[{"id": "a", "label": "count by 2s"}, {"id": "b", "label": "count by 5s"}, {"id": "c", "label": "count by 10s"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W03-Q05', 5, 'multiple_choice', 'Which rule fits 35, 40, 45, 50?', '[{"id": "a", "label": "count by 2s"}, {"id": "b", "label": "count by 5s"}, {"id": "c", "label": "count by 10s"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W03-Q06', 6, 'multiple_choice', 'Which rule fits 50, 60, 70, 80?', '[{"id": "a", "label": "count by 2s"}, {"id": "b", "label": "count by 5s"}, {"id": "c", "label": "count by 10s"}]'::jsonb, 'c', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W03-Q07', 7, 'short_answer', 'Fill in the missing number: 90, 95, __, 105', '[]'::jsonb, '100', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W03-Q08', 8, 'short_answer', 'Fill in the missing number: 96, 98, __, 102', '[]'::jsonb, '100', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W03-Q09', 9, 'multiple_choice', 'Which ones digits appear in a basic count-by-5 pattern?', '[{"id": "a", "label": "0 and 5"}, {"id": "b", "label": "1 and 6"}, {"id": "c", "label": "2, 4, 6, and 8"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W03-Q10', 10, 'multiple_choice', 'Which list shows counting by 10s?', '[{"id": "a", "label": "20, 25, 30, 35"}, {"id": "b", "label": "20, 30, 40, 50"}, {"id": "c", "label": "20, 22, 24, 26"}]'::jsonb, 'b', 1);


    -- Freeze the new question bank onto any still-open assignment that was
    -- generated before this migration.
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


    -- Week 4 online Friday check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 4
      and l.week_number = 4
      and l.day_number = 5
      and a.active is true
    limit 1;

    if v_template_id is null then
      raise exception 'Expected Grade 1 Math Week 4 assessment template was not found.';
    end if;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W04-Q01', 1, 'multiple_choice', 'Which shows 34 correctly?', '[{"id": "a", "label": "3 tens and 4 ones"}, {"id": "b", "label": "4 tens and 3 ones"}, {"id": "c", "label": "3 tens and 0 ones"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W04-Q02', 2, 'short_answer', 'What number is 5 tens and 2 ones?', '[]'::jsonb, '52', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W04-Q03', 3, 'multiple_choice', 'In 67, which digit is in the tens place?', '[{"id": "a", "label": "6"}, {"id": "b", "label": "7"}, {"id": "c", "label": "0"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W04-Q04', 4, 'multiple_choice', 'In 67, which digit is in the ones place?', '[{"id": "a", "label": "6"}, {"id": "b", "label": "7"}, {"id": "c", "label": "60"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W04-Q05', 5, 'short_answer', 'What number is 8 tens and 0 ones?', '[]'::jsonb, '80', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W04-Q06', 6, 'multiple_choice', 'Which is the expanded form of 46?', '[{"id": "a", "label": "4 + 6"}, {"id": "b", "label": "40 + 6"}, {"id": "c", "label": "46 + 0"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W04-Q07', 7, 'short_answer', 'How many tens are in 73?', '[]'::jsonb, '7', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W04-Q08', 8, 'short_answer', 'How many ones are in 73?', '[]'::jsonb, '3', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W04-Q09', 9, 'multiple_choice', 'Which shows 90 correctly?', '[{"id": "a", "label": "9 tens and 0 ones"}, {"id": "b", "label": "0 tens and 9 ones"}, {"id": "c", "label": "9 tens and 9 ones"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W04-Q10', 10, 'multiple_choice', 'Which numeral is 2 tens and 8 ones?', '[{"id": "a", "label": "82"}, {"id": "b", "label": "28"}, {"id": "c", "label": "208"}]'::jsonb, 'b', 1);


    -- Freeze the new question bank onto any still-open assignment that was
    -- generated before this migration.
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


    -- Week 5 online Friday check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 5
      and l.week_number = 5
      and l.day_number = 5
      and a.active is true
    limit 1;

    if v_template_id is null then
      raise exception 'Expected Grade 1 Math Week 5 assessment template was not found.';
    end if;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W05-Q01', 1, 'multiple_choice', 'In 47, what is the value of the 4?', '[{"id": "a", "label": "4"}, {"id": "b", "label": "40"}, {"id": "c", "label": "47"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W05-Q02', 2, 'multiple_choice', 'In 47, what is the value of the 7?', '[{"id": "a", "label": "7"}, {"id": "b", "label": "70"}, {"id": "c", "label": "47"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W05-Q03', 3, 'multiple_choice', 'Which two forms both show 63?', '[{"id": "a", "label": "6 tens 3 ones; 60 + 3"}, {"id": "b", "label": "3 tens 6 ones; 30 + 6"}, {"id": "c", "label": "6 tens 0 ones; 60 + 0"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W05-Q04', 4, 'short_answer', 'What number is 7 tens and 5 ones?', '[]'::jsonb, '75', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W05-Q05', 5, 'multiple_choice', 'Which is the expanded form of 82?', '[{"id": "a", "label": "8 + 2"}, {"id": "b", "label": "80 + 2"}, {"id": "c", "label": "82 + 2"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W05-Q06', 6, 'multiple_choice', 'How many tens and ones are in 50?', '[{"id": "a", "label": "5 tens and 0 ones"}, {"id": "b", "label": "0 tens and 5 ones"}, {"id": "c", "label": "5 tens and 5 ones"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W05-Q07', 7, 'multiple_choice', 'How many tens and ones are in 14?', '[{"id": "a", "label": "4 tens and 1 one"}, {"id": "b", "label": "1 ten and 4 ones"}, {"id": "c", "label": "1 ten and 0 ones"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W05-Q08', 8, 'short_answer', 'Write the numeral for 9 tens and 1 one.', '[]'::jsonb, '91', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W05-Q09', 9, 'multiple_choice', 'In 36, the digit 3 is worth:', '[{"id": "a", "label": "3"}, {"id": "b", "label": "30"}, {"id": "c", "label": "6"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W05-Q10', 10, 'multiple_choice', 'Which pair is equivalent?', '[{"id": "a", "label": "58 and 50 + 8"}, {"id": "b", "label": "58 and 5 + 8"}, {"id": "c", "label": "58 and 8 tens 5 ones"}]'::jsonb, 'a', 1);


    -- Freeze the new question bank onto any still-open assignment that was
    -- generated before this migration.
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


    -- Week 6 online Friday check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 6
      and l.week_number = 6
      and l.day_number = 5
      and a.active is true
    limit 1;

    if v_template_id is null then
      raise exception 'Expected Grade 1 Math Week 6 assessment template was not found.';
    end if;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W06-Q01', 1, 'multiple_choice', 'Choose the correct symbol: 24 __ 31', '[{"id": "a", "label": "<"}, {"id": "b", "label": ">"}, {"id": "c", "label": "="}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W06-Q02', 2, 'multiple_choice', 'Choose the correct symbol: 52 __ 37', '[{"id": "a", "label": "<"}, {"id": "b", "label": ">"}, {"id": "c", "label": "="}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W06-Q03', 3, 'multiple_choice', 'Choose the correct symbol: 45 __ 45', '[{"id": "a", "label": "<"}, {"id": "b", "label": ">"}, {"id": "c", "label": "="}]'::jsonb, 'c', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W06-Q04', 4, 'multiple_choice', 'Choose the correct symbol: 68 __ 63', '[{"id": "a", "label": "<"}, {"id": "b", "label": ">"}, {"id": "c", "label": "="}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W06-Q05', 5, 'multiple_choice', 'Choose the correct symbol: 42 __ 47', '[{"id": "a", "label": "<"}, {"id": "b", "label": ">"}, {"id": "c", "label": "="}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W06-Q06', 6, 'multiple_choice', 'Which comparison is true?', '[{"id": "a", "label": "28 > 45"}, {"id": "b", "label": "28 < 45"}, {"id": "c", "label": "28 = 45"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W06-Q07', 7, 'multiple_choice', 'Which comparison is true?', '[{"id": "a", "label": "71 < 52"}, {"id": "b", "label": "71 = 52"}, {"id": "c", "label": "71 > 52"}]'::jsonb, 'c', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W06-Q08', 8, 'multiple_choice', 'Choose the correct symbol: 80 __ 80', '[{"id": "a", "label": "<"}, {"id": "b", "label": ">"}, {"id": "c", "label": "="}]'::jsonb, 'c', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W06-Q09', 9, 'multiple_choice', 'When comparing 61 and 25, which place decides first?', '[{"id": "a", "label": "ones"}, {"id": "b", "label": "tens"}, {"id": "c", "label": "neither"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W06-Q10', 10, 'multiple_choice', 'When comparing 74 and 71, which place decides after the tens match?', '[{"id": "a", "label": "ones"}, {"id": "b", "label": "hundreds"}, {"id": "c", "label": "neither"}]'::jsonb, 'a', 1);


    -- Freeze the new question bank onto any still-open assignment that was
    -- generated before this migration.
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


    -- Week 7 online Friday check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 7
      and l.week_number = 7
      and l.day_number = 5
      and a.active is true
    limit 1;

    if v_template_id is null then
      raise exception 'Expected Grade 1 Math Week 7 assessment template was not found.';
    end if;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W07-Q01', 1, 'multiple_choice', 'Choose the correct symbol: 47 __ 52', '[{"id": "a", "label": "<"}, {"id": "b", "label": ">"}, {"id": "c", "label": "="}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W07-Q02', 2, 'multiple_choice', 'Choose the correct symbol: 68 __ 63', '[{"id": "a", "label": "<"}, {"id": "b", "label": ">"}, {"id": "c", "label": "="}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W07-Q03', 3, 'multiple_choice', 'Choose the correct symbol: 55 __ 55', '[{"id": "a", "label": "<"}, {"id": "b", "label": ">"}, {"id": "c", "label": "="}]'::jsonb, 'c', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W07-Q04', 4, 'multiple_choice', 'Which explanation proves 64 > 59?', '[{"id": "a", "label": "6 tens is greater than 5 tens"}, {"id": "b", "label": "4 ones is less than 9 ones"}, {"id": "c", "label": "Both numbers have 6 tens"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W07-Q05', 5, 'multiple_choice', 'Which explanation proves 72 < 78?', '[{"id": "a", "label": "7 tens is less than 7 tens"}, {"id": "b", "label": "The tens match and 2 ones is less than 8 ones"}, {"id": "c", "label": "2 tens is less than 8 tens"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W07-Q06', 6, 'multiple_choice', 'Order least to greatest: 42, 27, 35', '[{"id": "a", "label": "42, 35, 27"}, {"id": "b", "label": "27, 35, 42"}, {"id": "c", "label": "35, 27, 42"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W07-Q07', 7, 'multiple_choice', 'Order greatest to least: 61, 68, 64', '[{"id": "a", "label": "68, 64, 61"}, {"id": "b", "label": "61, 64, 68"}, {"id": "c", "label": "64, 68, 61"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W07-Q08', 8, 'multiple_choice', 'One box has 38 counters and another has 42. Which statement is true?', '[{"id": "a", "label": "38 > 42"}, {"id": "b", "label": "38 = 42"}, {"id": "c", "label": "38 < 42"}]'::jsonb, 'c', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W07-Q09', 9, 'multiple_choice', 'Which statement is true?', '[{"id": "a", "label": "90 < 89"}, {"id": "b", "label": "90 > 89"}, {"id": "c", "label": "90 = 89"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W07-Q10', 10, 'multiple_choice', 'Which comparison uses the ones place to decide?', '[{"id": "a", "label": "32 vs 47"}, {"id": "b", "label": "83 vs 80"}, {"id": "c", "label": "61 vs 25"}]'::jsonb, 'b', 1);


    -- Freeze the new question bank onto any still-open assignment that was
    -- generated before this migration.
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
