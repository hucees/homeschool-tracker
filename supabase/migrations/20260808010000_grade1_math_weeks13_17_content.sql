-- Homeschool Tracker
-- Migration 020: Grade 1 Mathematics Weeks 13–17 production curriculum
--
-- Week 13 : Subtraction Within 20 II (1-MATH-07)
-- Week 14 : Fact Fluency Within 10 (1-MATH-08, 90% threshold)
-- Week 15 : Addition and Subtraction Relationships (1-MATH-09)
-- Week 16 : One-Step Word Problems I (1-MATH-10)
-- Week 17 : One-Step Word Problems II (1-MATH-10)
--
-- Installs:
-- * 25 published lesson-content revisions
-- * 375 guided/independent/worksheet items
-- * 50 auto-scored online assessment items
--
-- Historical safety:
-- * all five weeks install inside one transaction
-- * preflight validates every lesson skeleton and Friday template
-- * refuses to overwrite published/superseded lesson content
-- * refuses to alter a lesson frozen to a student delivery
-- * refuses to overwrite existing Week 13–17 assessment banks

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

    -- Full preflight before any write.
    for v_week in 13..17 loop
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
        raise exception 'Grade 1 Math Week % already has published lesson content. Migration 020 will not overwrite curriculum history.', v_week;
      end if;

      if exists (
        select 1
        from public.student_lesson_deliveries sld
        join public.lessons l on l.id = sld.lesson_id
        where l.course_version_id = v_course.course_version_id
          and l.week_number = v_week
      ) then
        raise exception 'Grade 1 Math Week % has already been frozen to a student delivery. Migration 020 will not rewrite delivered curriculum.', v_week;
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
        raise exception 'Grade 1 Math Week % already has an online question bank. Migration 020 will not overwrite assessment history.', v_week;
      end if;
    end loop;

    delete from public.lesson_content_versions lcv
    using public.lessons l
    where lcv.lesson_id = l.id
      and l.course_version_id = v_course.course_version_id
      and l.week_number between 13 and 17
      and lcv.status = 'draft';


    -- Week 13, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W13-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W13-D1 was not found.';
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
      'The student will deepen subtraction within 20 by applying count-back, count-on, and decompose-to-10 strategies to mixed facts.', 'I can choose a subtraction strategy and solve accurately.', '["pencil", "paper", "optional number line 0–20", "optional ten-frame"]'::jsonb, '[{"term": "difference", "definition": "the result of subtraction"}, {"term": "strategy", "definition": "a useful way to solve a problem"}, {"term": "decompose", "definition": "break a number into smaller parts without changing its value"}]'::jsonb,
      'Review the three strategies from Week 12. Ask the student when each might be useful.', 'Model 16−7 using 10, 17−14 by counting on, and 18−4 by counting back. Compare the amount of work in each method.', 'The goal is flexible strategy use, not forcing one procedure on every subtraction fact.',
      'Good subtraction solvers look at the numbers first.

Close numbers → counting on may be efficient.
Small amount subtracted → counting back may be efficient.
Crossing 10 → breaking apart to 10 can help.', 'Choose a strategy together and say why it fits.', 'Solve mixed facts independently using any accurate strategy.', 'Strategy Sort: sort subtraction fact cards by the strategy you would try first.',
      'Subtraction Strategy Practice', 'Solve each subtraction problem and use a strategy that fits.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately use more than one strategy.',
      'Keep a strategy reference card available during instruction.', 'Solve one fact two different ways and compare the steps.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 16 − 7. Use 10 as a stopping point.', 'First ask how far 16 is from 10.', '9', '16−6=10, then subtract 1 more to get 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 14 − 11 by counting on.', 'Count from the smaller number to the larger.', '3', '11→12→13→14 is three steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 18 − 4 by counting back.', 'Take four backward steps.', '14', '18→17→16→15→14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 15 − 8.', null, '7', '15−5=10, then subtract 3 more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 17 − 14.', null, '3', 'Count on 14→15→16→17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 13 − 5.', null, '8', '13−3=10, then subtract 2 more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 19 − 6.', null, '13', 'Count back six or decompose the subtraction amount.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 12 − 7.', null, '5', '12−2=10 and 10−5=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 18 − 15.', null, '3', 'Count on from 15 to 18.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 17 − 8.', null, '9', '17−7=10, then subtract 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 16 − 3.', null, '13', 'Count back three.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 14 − 9.', null, '5', '14−4=10, then subtract 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 20 − 7.', null, '13', '20−7=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 11 − 8.', null, '3', 'Count on 8→9→10→11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 15 − 6.', null, '9', '15−5=10, then subtract 1.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 13, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W13-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W13-D2 was not found.';
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
      'The student will select efficient subtraction strategies within 20 based on the relationship between the two numbers.', 'I can decide which subtraction strategy will be efficient.', '["pencil", "paper", "optional number line"]'::jsonb, '[{"term": "difference", "definition": "the result of subtraction"}, {"term": "strategy", "definition": "a useful way to solve a problem"}, {"term": "decompose", "definition": "break a number into smaller parts without changing its value"}, {"term": "efficient", "definition": "accurate with no unnecessary steps"}]'::jsonb,
      'Show 17−15, 18−3, and 14−6. Ask why the same strategy is not equally convenient for all three.', 'Model choosing count on, count back, or use-10 based on the structure of the fact.', 'Accept other accurate strategies when the student can explain them. Strategy choice should support understanding rather than become another memorization task.',
      'Look at the numbers before solving.

Are they close together?
Is only a small amount being removed?
Would landing on 10 make the problem easier?', 'Choose and justify strategies for three facts.', 'Solve independently and name an efficient strategy.', 'Best Strategy: draw a fact card, choose a strategy, and explain the choice before solving.',
      'Choose a Subtraction Strategy', 'Solve each fact and name an efficient method.', 'Complete at least 7 of 8 worksheet items correctly after corrections and justify at least two strategy choices.',
      'Use visual strategy icons or a short strategy menu.', 'Find a subtraction fact where two different strategies are both efficient.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'For 17 − 15, which is efficient: count on from 15 or count back 15 steps?', null, 'count on from 15', 'The numbers are close, so counting on takes only two steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'For 18 − 3, which is efficient: count back 3 or count on from 3?', null, 'count back 3', 'Subtracting a small amount is quick by counting back.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'For 14 − 6, which strategy uses 10 as a helpful stopping point?', null, 'decompose to 10', 'Subtract 4 to reach 10, then subtract the remaining 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 16 − 13 and name an efficient strategy.', null, '3; count on', '13→14→15→16 is three steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 19 − 4 and name an efficient strategy.', null, '15; count back', 'Four backward steps from 19 land on 15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 13 − 7 and name an efficient strategy.', null, '6; use 10', '13−3=10, then subtract 4 more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 12 − 10 and name an efficient strategy.', null, '2; count on', '10→11→12 is two steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 18 − 16. Name an efficient strategy.', null, '2; count on', '16 to 18 is two steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 17 − 5. Name an efficient strategy.', null, '12; count back', 'Five backward steps from 17 land on 12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 15 − 7. Name an efficient strategy.', null, '8; use 10', '15−5=10, then subtract 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 20 − 2. Name an efficient strategy.', null, '18; count back', 'Two backward steps from 20.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 14 − 12. Name an efficient strategy.', null, '2; count on', '12 to 14 is two steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 16 − 8. Name an efficient strategy.', null, '8; use 10', '16−6=10, then subtract 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 13 − 3. Name an efficient strategy.', null, '10; count back', 'Three backward steps from 13 land on 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 19 − 17. Name an efficient strategy.', null, '2; count on', '17 to 19 is two steps.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 13, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W13-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W13-D3 was not found.';
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
      'The student will solve mixed subtraction facts within 20 independently without a strategy label.', 'I can solve mixed subtraction facts without being told which strategy to use.', '["pencil", "scratch paper", "optional number line"]'::jsonb, '[{"term": "difference", "definition": "the result of subtraction"}, {"term": "strategy", "definition": "a useful way to solve a problem"}, {"term": "decompose", "definition": "break a number into smaller parts without changing its value"}]'::jsonb,
      'Explain that real math problems usually do not tell which strategy to use. The student decides.', 'Model one mixed fact and verbalize the decision process before solving.', 'Do not over-correct a valid alternative strategy. Focus on accuracy and reasoning.',
      'When no strategy is named, pause and look at the numbers. Choose a method, solve, and check whether the answer makes sense.', 'Solve three mixed facts together.', 'Complete the rest independently.', 'Two-Way Check: choose two solved facts and verify them with another strategy.',
      'Mixed Subtraction Within 20', 'Solve each fact using an accurate strategy.', 'Complete at least 7 of 8 worksheet items correctly after corrections and independently choose strategies for mixed facts.',
      'Allow scratch drawings or number-line work.', 'Estimate whether the difference should be small or large before solving each fact.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 18 − 9.', null, '9', '18−8=10, then subtract 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 15 − 12.', null, '3', 'Count on from 12 to 15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 17 − 6.', null, '11', 'Count back six or use a break-apart strategy.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 14 − 5.', null, '9', '14−4=10, then subtract 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 20 − 8.', null, '12', 'Twenty take away eight is twelve.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 16 − 14.', null, '2', 'Count on from 14 to 16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 12 − 6.', null, '6', 'Twelve take away six is six.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 19 − 9.', null, '10', 'Nineteen minus nine equals ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 13 − 8.', null, '5', '13−3=10, then subtract 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 17 − 3.', null, '14', 'Count back three.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 18 − 13.', null, '5', 'Count on 13→14→15→16→17→18.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 15 − 9.', null, '6', '15−5=10, then subtract 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 11 − 4.', null, '7', 'Eleven minus four is seven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 16 − 7.', null, '9', '16−6=10, then subtract 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 20 − 15.', null, '5', 'Count on from 15 to 20.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 13, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W13-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W13-D4 was not found.';
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
      'The student will explain at least one subtraction strategy within 20 using words, equations, drawings, or a number line.', 'I can explain how my subtraction strategy works.', '["pencil", "paper", "optional number line or ten-frame"]'::jsonb, '[{"term": "difference", "definition": "the result of subtraction"}, {"term": "strategy", "definition": "a useful way to solve a problem"}, {"term": "decompose", "definition": "break a number into smaller parts without changing its value"}, {"term": "explain", "definition": "show the mathematical thinking that supports an answer"}]'::jsonb,
      'Tell the student that a correct answer is stronger when they can show why it is correct.', 'Model short explanations using count on, count back, and use-10.', 'Age-appropriate oral explanations are acceptable. The existing mastery system does not require a separate hands-on demonstration.',
      'A subtraction explanation may be a sentence, number-line jumps, or a break-apart equation.

Example: 14−8=6 because I subtracted 4 to get 10, then 4 more to get 6.', 'Explain three examples together.', 'Solve and explain independently.', 'Teach Back: choose one subtraction fact and teach the strategy to the instructor.',
      'Explain Your Subtraction Strategy', 'Solve each problem and show or tell how you solved it.', 'Complete at least 7 of 8 worksheet items correctly after corrections and give one mathematically accurate explanation.',
      'Allow oral dictation or drawings instead of full written sentences.', 'Explain the same fact using two different strategies.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 14 − 8 and explain a strategy.', null, '6', 'Example: 14−4=10, then 10−4=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 17 − 14 and explain a strategy.', null, '3', 'Example: count on 14,15,16,17 for three steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 18 − 5 and explain a strategy.', null, '13', 'Example: count back five from 18.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 15 − 6 and give a strategy explanation.', null, '9', 'Example: 15−5=10, then subtract 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 13 − 10 and give a strategy explanation.', null, '3', 'Example: count on from 10 to 13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 19 − 4 and give a strategy explanation.', null, '15', 'Example: count back four.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 12 − 7 and give a strategy explanation.', null, '5', 'Example: 12−2=10, then subtract 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 16 − 9 and explain.', null, '7', 'Example: 16−6=10, then 10−3=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 18 − 16 and explain.', null, '2', 'Example: count on from 16 to 18.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 17 − 7 and explain.', null, '10', 'Example: subtract seven to land on 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 14 − 3 and explain.', null, '11', 'Example: count back three.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 20 − 11 and explain.', null, '9', 'Example: 20−10=10, then subtract 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 13 − 5 and explain.', null, '8', 'Example: 13−3=10, then subtract 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 15 − 13 and explain.', null, '2', 'Example: count on from 13 to 15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 19 − 8 and explain.', null, '11', 'Example: 19−8=11.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 13, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W13-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W13-D5 was not found.';
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
      'The student will independently demonstrate the full 1-MATH-07 subtraction-within-20 objective before the Week 13 online check.', 'I can subtract within 20 and explain a useful strategy.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "difference", "definition": "the result of subtraction"}, {"term": "strategy", "definition": "a useful way to solve a problem"}, {"term": "decompose", "definition": "break a number into smaller parts without changing its value"}]'::jsonb,
      'Ask the student to name three subtraction strategies and give one example where each could help.', 'Model only one neutral example, then transition to independent readiness.', 'Week 13 provides a second independent assessment opportunity for 1-MATH-07. Repeated qualifying evidence may establish mastery; no separate hands-on requirement is imposed.',
      'Choose a strategy that fits the numbers. Check the difference, and be ready to explain how you know.', 'Complete three short warm-up facts.', 'Complete readiness work and the Week 13 online assessment independently.', 'Strategy Reflection: choose one readiness fact and name the strategy you would use before solving it.',
      'Week 13 Subtraction Mastery Readiness', 'Solve the mixed subtraction review before the online check.', 'Complete Week 13 readiness and online assessment independently using the configured 85% threshold and repeated-evidence rules.',
      'Use normal accommodations without supplying strategy or answer.', 'Create one subtraction problem that is especially easy by counting on and one that is easy by using 10.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 18 − 9.', null, '9', '18−8=10, then subtract 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 15 − 12.', null, '3', 'Count on from 12 to 15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 17 − 6.', null, '11', 'Count back six or use a break-apart strategy.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 14 − 5.', null, '9', '14−4=10, then subtract 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 20 − 8.', null, '12', 'Twenty take away eight is twelve.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 16 − 14.', null, '2', 'Count on from 14 to 16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 12 − 6.', null, '6', 'Twelve take away six is six.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 19 − 9.', null, '10', 'Nineteen minus nine equals ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 13 − 8.', null, '5', '13−3=10, then subtract 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 17 − 3.', null, '14', 'Count back three.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 18 − 13.', null, '5', 'Count on 13→14→15→16→17→18.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 15 − 9.', null, '6', '15−5=10, then subtract 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 11 − 4.', null, '7', 'Eleven minus four is seven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 16 − 7.', null, '9', '16−6=10, then subtract 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 20 − 15.', null, '5', 'Count on from 15 to 20.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 14, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W14-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W14-D1 was not found.';
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
      'The student will efficiently solve addition facts with sums through 10 using known facts, doubles, count-on, or related strategies rather than recounting every quantity from 1.', 'I can solve addition facts within 10 efficiently.', '["pencil", "paper", "optional ten-frame during instruction"]'::jsonb, '[{"term": "fact fluency", "definition": "solve basic facts accurately and efficiently"}, {"term": "derive", "definition": "use a known fact or pattern to figure out another fact"}, {"term": "efficient", "definition": "solve without unnecessary recounting from 1"}]'::jsonb,
      'Explain that fluency is not a race. It means the student can solve basic facts accurately with increasingly efficient thinking.', 'Model 4+4 as a double, 5+4 from 5+5, and 6+2 by counting on two.', 'Avoid emphasizing speed alone. The competency specifically values accurate, efficient recall or derivation without recounting every item from one.',
      'Fluent addition can come from facts you remember and facts you derive from something you know.', 'Name a useful strategy for each guided fact.', 'Solve basic addition facts without rebuilding every quantity from 1.', 'Known-Fact Web: place one known fact in the center and write nearby facts it helps solve.',
      'Addition Facts Within 10', 'Solve each fact using a known or efficiently derived fact.', 'Complete at least 7 of 8 worksheet items correctly after corrections and demonstrate at least one efficient derivation.',
      'Use ten-frame images during instruction, then fade them when possible.', 'Explain how one double helps solve two nearby addition facts.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 4 + 3.', null, '7', '4+3=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Use 5 + 5 = 10 to solve 5 + 4.', null, '9', '5+4 is one less than 5+5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 6 + 2.', null, '8', 'Count on two from 6 or use a known fact.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 3 + 5.', null, '8', '3+5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 4 + 4.', null, '8', 'Double 4 is 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 2 + 7.', null, '9', '2+7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 6 + 3.', null, '9', '6+3=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 1 + 8.', null, '9', '1+8=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 2 + 6.', null, '8', '2+6=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 3 + 6.', null, '9', '3+6=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 4 + 5.', null, '9', '4+5=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 5 + 3.', null, '8', '5+3=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 6 + 1.', null, '7', '6+1=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 2 + 7.', null, '9', '2+7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 5 + 5.', null, '10', '5+5=10.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 14, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W14-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W14-D2 was not found.';
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
      'The student will efficiently solve subtraction facts within 10 using known facts, related addition facts, count-back, or part-whole reasoning.', 'I can solve subtraction facts within 10 efficiently.', '["pencil", "paper", "optional ten-frame during instruction"]'::jsonb, '[{"term": "fact fluency", "definition": "solve basic facts accurately and efficiently"}, {"term": "derive", "definition": "use a known fact or pattern to figure out another fact"}, {"term": "efficient", "definition": "solve without unnecessary recounting from 1"}]'::jsonb,
      'Show 8−5 and ask whether the student can use the known relationship 5+3=8 instead of removing and recounting eight objects.', 'Model several subtraction facts as known-part questions.', 'Keep the goal on accurate, efficient derivation rather than timed pressure.',
      'Subtraction facts can come from addition facts you already know.
If 5+3=8, then 8−5=3 and 8−3=5.', 'Connect subtraction to known facts.', 'Solve basic subtraction facts independently.', 'Fact Partner Match: match an addition fact card with a related subtraction fact.',
      'Subtraction Facts Within 10', 'Solve each fact without recounting the entire starting amount from 1.', 'Complete at least 7 of 8 worksheet items correctly after corrections and use at least one related addition fact efficiently.',
      'Allow a fact-family triangle during guided practice.', 'Find all subtraction facts connected to 4+5=9.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 9 − 4.', null, '5', '9−4=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 8 − 3.', null, '5', '8−3=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Use 5 + 3 = 8 to solve 8 − 5.', null, '3', 'The related addition fact shows the missing part.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 7 − 2.', null, '5', '7−2=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 10 − 6.', null, '4', '10−6=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 9 − 6.', null, '3', '9−6=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 8 − 5.', null, '3', '8−5=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 6 − 1.', null, '5', '6−1=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 7 − 3.', null, '4', '7−3=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 8 − 2.', null, '6', '8−2=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 9 − 5.', null, '4', '9−5=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 10 − 3.', null, '7', '10−3=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 7 − 5.', null, '2', '7−5=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 6 − 4.', null, '2', '6−4=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 10 − 8.', null, '2', '10−8=2.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 14, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W14-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W14-D3 was not found.';
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
      'The student will solve mixed addition and subtraction facts within 10 while switching operations accurately.', 'I can solve mixed + and − facts without getting the operations mixed up.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "fact fluency", "definition": "solve basic facts accurately and efficiently"}, {"term": "derive", "definition": "use a known fact or pattern to figure out another fact"}, {"term": "efficient", "definition": "solve without unnecessary recounting from 1"}]'::jsonb,
      'Explain that mixed practice tests whether the student notices the operation sign before using a fact.', 'Model scanning the sign first, then selecting a known/derived fact.', 'Fluency should remain accurate when operations are mixed.',
      'Before solving, notice the operation sign. Then use what you know about the numbers.', 'Solve a mixed set together.', 'Complete mixed facts independently.', 'Operation Flip: draw a card marked + or −, then solve a fact using that operation.',
      'Mixed Facts Within 10', 'Watch the operation sign and solve each fact efficiently.', 'Complete at least 7 of 8 worksheet items correctly after corrections and maintain accuracy across mixed operations.',
      'Use enlarged + and − symbols if visual discrimination is difficult.', 'Rewrite several addition facts as related subtraction facts.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 5 + 4.', null, '9', '5+4=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 9 − 3.', null, '6', '9−3=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 4 + 4.', null, '8', 'Double 4 is 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 8 − 5.', null, '3', '8−5=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 3 + 6.', null, '9', '3+6=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 10 − 7.', null, '3', '10−7=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 2 + 7.', null, '9', '2+7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 6 + 3.', null, '9', '6+3=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 9 − 5.', null, '4', '9−5=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 5 + 5.', null, '10', 'Double 5 is 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 8 − 2.', null, '6', '8−2=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 4 + 5.', null, '9', '4+5=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 7 − 4.', null, '3', '7−4=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 3 + 3.', null, '6', 'Double 3 is 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 10 − 6.', null, '4', '10−6=4.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 14, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W14-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W14-D4 was not found.';
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
      'The student will derive unknown basic facts within 10 from doubles, near doubles, and related addition/subtraction facts.', 'I can use a fact I know to figure out another fact.', '["pencil", "paper"]'::jsonb, '[{"term": "fact fluency", "definition": "solve basic facts accurately and efficiently"}, {"term": "derive", "definition": "use a known fact or pattern to figure out another fact"}, {"term": "efficient", "definition": "solve without unnecessary recounting from 1"}]'::jsonb,
      'Ask the student what 4+5 is if 4+4=8 is already known. Emphasize using structure instead of recounting.', 'Model near doubles and inverse facts.', 'This lesson directly targets the ''recall or derive'' language in 1-MATH-08.',
      'You do not have to memorize every fact separately. One fact can help you derive another.

4+4=8 helps with 4+5=9.
3+5=8 helps with 8−3=5.', 'State the known fact, then derive the new fact.', 'Use known facts independently.', 'Fact Ladder: start with one double and build three facts that can be derived from it.',
      'Derive Facts Efficiently', 'Use the fact given to solve the related fact.', 'Complete at least 7 of 8 worksheet items correctly after corrections and correctly explain at least two derivations.',
      'Keep the known fact visible beside the related fact.', 'Find more than one known fact that could help solve 5+4.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'If 4 + 4 = 8, what is 4 + 5?', null, '9', 'A near double is one more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'If 3 + 5 = 8, what is 8 − 3?', null, '5', 'Use the related addition fact.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'If 5 + 2 = 7, what is 7 − 5?', null, '2', 'The missing part is 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Use 5+5=10 to solve 5+4.', null, '9', 'One less than the double.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Use 6+3=9 to solve 9−6.', null, '3', 'The related part is 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Use 4+2=6 to solve 6−2.', null, '4', 'The related part is 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Use 3+3=6 to solve 3+4.', null, '7', 'One more than the double.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Use 4+4=8 to solve 4+3.', null, '7', 'One less than the double.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Use 2+6=8 to solve 8−2.', null, '6', 'Use the related addition fact.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Use 5+3=8 to solve 8−5.', null, '3', 'Use the related addition fact.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Use 4+5=9 to solve 9−4.', null, '5', 'Use the related addition fact.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Use 3+3=6 to solve 3+2.', null, '5', 'One less than the double.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Use 5+5=10 to solve 10−5.', null, '5', 'The two equal parts are 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Use 6+2=8 to solve 8−6.', null, '2', 'Use the related addition fact.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Use 4+3=7 to solve 7−3.', null, '4', 'Use the related addition fact.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 14, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W14-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W14-D5 was not found.';
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
      'The student will independently complete a mixed fact-fluency check within 10 at the configured 90% competency threshold.', 'I can solve addition and subtraction facts within 10 accurately and efficiently.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "fact fluency", "definition": "solve basic facts accurately and efficiently"}, {"term": "derive", "definition": "use a known fact or pattern to figure out another fact"}, {"term": "efficient", "definition": "solve without unnecessary recounting from 1"}]'::jsonb,
      'Remind the student that fluency means accurate and efficient, not anxious or rushed.', 'Model one neutral example of deriving a fact, then stop modeling.', '1-MATH-08 uses a 90% mastery threshold. Repeated qualifying checks can supply the required evidence; do not require a separate hands-on performance.',
      'Look at the sign, use a fact you know, and avoid restarting from 1 for every problem.', 'Complete three brief warm-ups.', 'Complete the readiness set and Week 14 online check independently.', 'After the check, choose two facts and explain what known fact or pattern helped.',
      'Week 14 Fact Fluency Check', 'Solve the mixed facts accurately and efficiently.', 'Complete the Week 14 online assessment independently. A qualifying score for this competency is 90%, and mastery requires repeated qualifying evidence under the existing system.',
      'Do not impose a speed timer unless it is helpful and non-disruptive for the learner. Use normal accommodations.', 'Build a personal list of five ''anchor facts'' that help derive many other facts.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve: 4+5, 9−4, 3+3.', null, '9, 5, 6', 'Use known facts or efficient related facts.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve: 8−3, 2+6, 10−7.', null, '5, 8, 3', 'Each result comes from a basic fact within 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Which is more efficient for 5+4: recounting nine objects from 1 or using 5+5=10?', null, 'using 5+5=10', 'The known double gives the answer with fewer steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve: 6+3, 8−5.', null, '9, 3', 'Mixed fact fluency.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve: 4+4, 10−6.', null, '8, 4', 'Mixed fact fluency.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve: 7−2, 3+5.', null, '5, 8', 'Mixed fact fluency.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve: 9−6, 5+2.', null, '3, 7', 'Mixed fact fluency.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 3+6.', null, '9', '3+6=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 10−4.', null, '6', '10−4=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 5+4.', null, '9', '5+4=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 8−3.', null, '5', '8−3=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 4+4.', null, '8', 'Double 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 9−5.', null, '4', '9−5=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 2+7.', null, '9', '2+7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 7−3.', null, '4', '7−3=4.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 15, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W15-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W15-D1 was not found.';
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
      'The student will identify parts and whole and generate the four related addition/subtraction equations in a fact family.', 'I can make addition and subtraction facts from the same three numbers.', '["pencil", "paper", "optional fact-family triangle"]'::jsonb, '[{"term": "fact family", "definition": "related addition and subtraction equations made from the same three numbers"}, {"term": "inverse operations", "definition": "operations that can undo each other"}, {"term": "whole", "definition": "the total amount"}, {"term": "parts", "definition": "amounts that combine to make the whole"}]'::jsonb,
      'Use three number cards 3, 5, 8. Ask how they can make both addition and subtraction equations.', 'Model the four equations and label 8 as the whole and 3,5 as parts.', 'For equal addends such as 4,4,8, there are fewer unique-looking equations, but the relationship is still valid.',
      'A fact family uses the same parts and whole.

3+5=8
5+3=8
8−3=5
8−5=3', 'Build fact families together.', 'Generate related equations independently.', 'Fact-Family House: put the whole on top and the two parts below, then write the related equations.',
      'Build Fact Families', 'Use each set of three numbers to write related addition and subtraction facts.', 'Complete at least 7 of 8 worksheet items correctly after corrections and identify parts/whole accurately.',
      'Use a visual fact-family triangle.', 'Create a fact family with a whole of 10 and explain how all four equations connect.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Use 3, 5, and 8. Write the two addition facts.', null, '3+5=8; 5+3=8', 'Both parts combine to make the whole 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Use 3, 5, and 8. Write the two subtraction facts.', null, '8−3=5; 8−5=3', 'Start with the whole and remove one part.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'What is the whole in the fact family 4, 6, 10?', null, '10', '4 and 6 are the parts; 10 is the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Write a fact family for 2, 7, 9.', null, '2+7=9; 7+2=9; 9−2=7; 9−7=2', 'The same three numbers make four related facts.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Write a fact family for 4, 5, 9.', null, '4+5=9; 5+4=9; 9−4=5; 9−5=4', 'The whole is 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'What are the parts in the fact family 6, 3, 9?', null, '6 and 3', 'The parts add to the whole 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'What is the whole in 8−5=3?', null, '8', 'Subtraction starts with the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Write the four facts for 1, 6, 7.', null, '1+6=7; 6+1=7; 7−1=6; 7−6=1', 'The whole is 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Write the four facts for 2, 5, 7.', null, '2+5=7; 5+2=7; 7−2=5; 7−5=2', 'The whole is 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Write the four facts for 3, 6, 9.', null, '3+6=9; 6+3=9; 9−3=6; 9−6=3', 'The whole is 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'What is the whole: 4, 4, 8?', null, '8', '4+4=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'What are the parts: 10−7=3?', null, '7 and 3', '7 and 3 combine to make 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Give one subtraction fact related to 5+4=9.', null, '9−5=4', '9−4=5 is also correct.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Give one addition fact related to 8−2=6.', null, '2+6=8', '6+2=8 is also correct.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Is 10−6=4 in the same fact family as 6+4=10?', null, 'yes', 'Both use parts 6 and 4 and whole 10.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 15, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W15-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W15-D2 was not found.';
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
      'The student will use a known addition fact to solve a related subtraction fact.', 'I can use addition to help me subtract.', '["pencil", "paper"]'::jsonb, '[{"term": "fact family", "definition": "related addition and subtraction equations made from the same three numbers"}, {"term": "inverse operations", "definition": "operations that can undo each other"}, {"term": "whole", "definition": "the total amount"}, {"term": "parts", "definition": "amounts that combine to make the whole"}]'::jsonb,
      'Ask: if you already know 6+3=9, do you need to solve 9−6 from scratch?', 'Model using the known whole and part to identify the missing part.', 'This lesson strengthens efficient derivation and the inverse relationship.',
      'Addition and subtraction are connected.
If 6+3=9, then 9−6=3 and 9−3=6.', 'Use addition facts to answer related subtraction facts.', 'Solve independently using related facts.', 'Cover One Part: build a fact family, cover one part, and use the addition fact to determine it.',
      'Use Addition to Subtract', 'Use the given addition fact to solve the related subtraction.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one inverse relationship.',
      'Keep a parts/whole diagram visible.', 'Find two subtraction facts that can be derived from each addition fact.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Use 6+3=9 to solve 9−6.', null, '3', 'The related addition fact shows the missing part.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Use 5+4=9 to solve 9−4.', null, '5', 'If 5 and 4 make 9, removing 4 leaves 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Use 7+2=9 to solve 9−7.', null, '2', 'The other part is 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Use 6+4=10 to solve 10−6.', null, '4', 'The related addition fact gives the other part.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Use 3+5=8 to solve 8−5.', null, '3', 'The other part is 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Use 2+7=9 to solve 9−2.', null, '7', 'The other part is 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Use 4+4=8 to solve 8−4.', null, '4', 'The two equal parts are 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Use 1+6=7 to solve 7−1.', null, '6', 'The other part is 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Use 2+5=7 to solve 7−5.', null, '2', 'The other part is 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Use 3+6=9 to solve 9−3.', null, '6', 'The other part is 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Use 5+5=10 to solve 10−5.', null, '5', 'The other equal part is 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Use 4+3=7 to solve 7−4.', null, '3', 'The other part is 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Use 6+2=8 to solve 8−6.', null, '2', 'The other part is 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Use 7+3=10 to solve 10−3.', null, '7', 'The other part is 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Use 4+5=9 to solve 9−5.', null, '4', 'The other part is 4.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 15, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W15-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W15-D3 was not found.';
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
      'The student will use inverse operations to check addition and subtraction equations.', 'I can use the opposite operation to check my answer.', '["pencil", "paper"]'::jsonb, '[{"term": "fact family", "definition": "related addition and subtraction equations made from the same three numbers"}, {"term": "inverse operations", "definition": "operations that can undo each other"}, {"term": "whole", "definition": "the total amount"}, {"term": "parts", "definition": "amounts that combine to make the whole"}]'::jsonb,
      'Show 9−4=5 and ask how addition could prove the result.', 'Model 5+4=9 as the check. Then reverse the process for 6+3=9 using 9−3=6.', 'Checking should reinforce meaning, not become an unrelated rule.',
      'Addition can check subtraction, and subtraction can check addition because the operations undo each other.', 'Write a related checking equation together.', 'Check equations independently.', 'Check Partner: one person writes a fact; the other writes an inverse equation that checks it.',
      'Check with the Inverse Operation', 'Write a related equation that proves each answer.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately check both addition and subtraction examples.',
      'Use arrows showing parts→whole for addition and whole→parts for subtraction.', 'Explain why a wrong answer would fail the inverse check.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Check 9−4=5 with addition.', null, '5+4=9', 'Add the difference and removed part to recover the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Check 6+3=9 with subtraction.', null, '9−3=6', 'Subtract one addend from the sum to recover the other.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Check 10−7=3 with addition.', null, '3+7=10', 'The related addition returns to the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Check 8−2=6 with addition.', null, '6+2=8', 'The check rebuilds the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Check 5+4=9 with subtraction.', null, '9−4=5', 'The inverse operation recovers an addend.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Check 7−3=4 with addition.', null, '4+3=7', 'The two parts rebuild the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Check 2+6=8 with subtraction.', null, '8−6=2', 'The inverse recovers the other addend.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Check 9−5=4 with addition.', null, '4+5=9', 'Rebuild the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Check 3+4=7 with subtraction.', null, '7−4=3', 'Recover an addend.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Check 10−6=4 with addition.', null, '4+6=10', 'Rebuild 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Check 5+3=8 with subtraction.', null, '8−3=5', 'Recover an addend.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Check 8−3=5 with addition.', null, '5+3=8', 'Rebuild 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Check 6+2=8 with subtraction.', null, '8−2=6', 'Recover an addend.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Check 7−5=2 with addition.', null, '2+5=7', 'Rebuild 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Check 4+5=9 with subtraction.', null, '9−5=4', 'Recover an addend.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 15, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W15-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W15-D4 was not found.';
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
      'The student will apply fact families, inverse reasoning, and operation checks in mixed addition/subtraction relationship problems.', 'I can use addition and subtraction together to reason about facts.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "fact family", "definition": "related addition and subtraction equations made from the same three numbers"}, {"term": "inverse operations", "definition": "operations that can undo each other"}, {"term": "whole", "definition": "the total amount"}, {"term": "parts", "definition": "amounts that combine to make the whole"}]'::jsonb,
      'Review that a problem may ask for a family, a related fact, a check, or the parts/whole.', 'Model identifying the requested relationship before solving.', 'The target is relational understanding, not just writing four equations mechanically.',
      'Look for the same three numbers and ask how addition and subtraction connect them.', 'Solve mixed relationship problems together.', 'Complete mixed items independently.', 'Relationship Sort: sort cards into Fact Family, Use Addition to Subtract, or Check an Answer.',
      'Mixed Addition–Subtraction Relationships', 'Read each prompt and use the relationship between the operations.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one relationship in words.',
      'Use a fact-family organizer when needed.', 'Create a wrong equation and use the inverse operation to prove why it is wrong.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Write the fact family for 3, 4, 7.', null, '3+4=7; 4+3=7; 7−3=4; 7−4=3', 'All four equations use the same parts and whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Use 6+2=8 to solve 8−6.', null, '2', 'The addition fact identifies the other part.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Check 9−5=4 using addition.', null, '4+5=9', 'The inverse operation rebuilds the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Give one addition fact related to 10−6=4.', null, '6+4=10', '4+6=10 also works.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Give one subtraction fact related to 3+5=8.', null, '8−3=5', '8−5=3 also works.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'What is the whole in 7−2=5?', null, '7', 'Subtraction begins with the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Are 2+6=8 and 8−6=2 related?', null, 'yes', 'They use the same parts and whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Fact family for 2, 4, 6.', null, '2+4=6; 4+2=6; 6−2=4; 6−4=2', 'Same parts and whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Use 5+3=8 to solve 8−3.', null, '5', 'The other part is 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Check 10−8=2 with addition.', null, '2+8=10', 'Rebuild the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Give an addition fact related to 9−4=5.', null, '4+5=9', '5+4=9 also works.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Give a subtraction fact related to 4+3=7.', null, '7−4=3', '7−3=4 also works.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'What is the whole in the family 5, 4, 9?', null, '9', '5+4=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'What are the parts in the family 3, 7, 10?', null, '3 and 7', 'The parts make 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Use 6+4=10 to solve 10−4.', null, '6', 'The other part is 6.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 15, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W15-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W15-D5 was not found.';
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
      'The student will independently demonstrate 1-MATH-09 by generating related equations and using one operation to solve or check the other.', 'I can show how addition and subtraction are connected.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "fact family", "definition": "related addition and subtraction equations made from the same three numbers"}, {"term": "inverse operations", "definition": "operations that can undo each other"}, {"term": "whole", "definition": "the total amount"}, {"term": "parts", "definition": "amounts that combine to make the whole"}]'::jsonb,
      'Ask the student to explain a fact family without looking at notes.', 'Model one neutral family and one inverse check, then stop modeling.', 'Week 15 is one instructional week, but the competency still requires repeated qualifying evidence. The online check can contribute one qualifying demonstration alongside other independent evidence.',
      'Think parts and whole. Addition builds the whole; subtraction starts with the whole and finds a part.', 'Complete three brief relationship warm-ups.', 'Complete the readiness work and Week 15 online check independently.', 'Explain One Family: choose a fact family and describe how one equation helps solve another.',
      'Week 15 Relationship Readiness', 'Use fact families and inverse operations to complete the review.', 'Complete the Week 15 online assessment independently using the configured 85% threshold and repeated-evidence rules.',
      'Use normal accommodations without identifying related equations for the student.', 'Make a fact family puzzle where one of the three numbers is hidden.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Write the fact family for 3, 4, 7.', null, '3+4=7; 4+3=7; 7−3=4; 7−4=3', 'All four equations use the same parts and whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Use 6+2=8 to solve 8−6.', null, '2', 'The addition fact identifies the other part.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Check 9−5=4 using addition.', null, '4+5=9', 'The inverse operation rebuilds the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Give one addition fact related to 10−6=4.', null, '6+4=10', '4+6=10 also works.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Give one subtraction fact related to 3+5=8.', null, '8−3=5', '8−5=3 also works.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'What is the whole in 7−2=5?', null, '7', 'Subtraction begins with the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Are 2+6=8 and 8−6=2 related?', null, 'yes', 'They use the same parts and whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Fact family for 2, 4, 6.', null, '2+4=6; 4+2=6; 6−2=4; 6−4=2', 'Same parts and whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Use 5+3=8 to solve 8−3.', null, '5', 'The other part is 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Check 10−8=2 with addition.', null, '2+8=10', 'Rebuild the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Give an addition fact related to 9−4=5.', null, '4+5=9', '5+4=9 also works.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Give a subtraction fact related to 4+3=7.', null, '7−4=3', '7−3=4 also works.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'What is the whole in the family 5, 4, 9?', null, '9', '5+4=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'What are the parts in the family 3, 7, 10?', null, '3 and 7', 'The parts make 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Use 6+4=10 to solve 10−4.', null, '6', 'The other part is 6.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 16, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W16-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W16-D1 was not found.';
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
      'The student will represent and solve one-step join situations within 20 with the result unknown.', 'I can tell when a story is joining more and solve it with addition.', '["pencil", "paper", "optional counters or drawing space"]'::jsonb, '[{"term": "join", "definition": "a situation where an amount is added to another amount"}, {"term": "separate", "definition": "a situation where some amount is taken away"}, {"term": "part-part-whole", "definition": "two parts combine to make one whole"}, {"term": "compare", "definition": "find how much more or less one amount is than another"}, {"term": "unknown", "definition": "the value the problem asks you to find"}]'::jsonb,
      'Act out a simple story: 7 objects are present and 5 more arrive. Ask what changed.', 'Model identifying the starting amount, amount joined, and unknown result, then write 7+5=12.', 'Teach the story structure, not keyword hunting. ''More'' can appear in compare problems later, so focus on what happens to the quantities.',
      'In a join story, an amount starts and more joins it. When the final total is unknown, addition finds the result.', 'Identify the quantities and unknown together.', 'Solve join stories independently.', 'Story Model: draw a before box, an added box, and an after box for each join story.',
      'Join Word Problems', 'Find what is unknown, write an equation, and solve.', 'Complete at least 7 of 8 worksheet items correctly after corrections and correctly identify the unknown in a join situation.',
      'Read stories aloud if decoding text interferes with math reasoning.', 'Write a join story for 8+7=15 without using the word ''plus.''',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Mia has 7 stickers. She gets 5 more. How many stickers does she have now?', null, '12', '7+5=12 because the amount increases.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'There are 6 birds on a fence. 4 more land. How many birds are there?', null, '10', '6+4=10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Leo has 9 blocks and gets 3 more. What is the unknown?', null, 'the total number of blocks', 'The problem gives the starting amount and amount added; the final total is unknown.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'A jar has 8 buttons. You add 6. How many buttons now?', null, '14', '8+6=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Nina read 5 pages, then 7 more pages. How many pages did she read?', null, '12', '5+7=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'There are 10 toy cars. 4 more are added. How many in all?', null, '14', '10+4=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Sam has 6 crayons and gets 8 more. Write the equation and answer.', null, '6+8=14', 'The join action means addition.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'A basket has 4 apples. 5 more are added. How many apples?', null, '9', '4+5=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Ava has 8 beads. She gets 4 more. How many beads?', null, '12', '8+4=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'There are 9 ducks. 6 more arrive. How many ducks?', null, '15', '9+6=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'A shelf has 7 books. 3 more are placed there. How many books?', null, '10', '7+3=10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Noah has 11 cards and gets 5 more. How many cards?', null, '16', '11+5=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'There are 6 balloons. 7 more are added. How many?', null, '13', '6+7=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'A box has 12 pencils. 4 more are put in. How many pencils?', null, '16', '12+4=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Lia has 5 shells and finds 9 more. How many shells?', null, '14', '5+9=14.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 16, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W16-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W16-D2 was not found.';
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
      'The student will represent and solve one-step separate/take-away situations within 20 with the result unknown.', 'I can tell when a story is taking some away and solve it with subtraction.', '["pencil", "paper", "optional counters or drawing space"]'::jsonb, '[{"term": "join", "definition": "a situation where an amount is added to another amount"}, {"term": "separate", "definition": "a situation where some amount is taken away"}, {"term": "part-part-whole", "definition": "two parts combine to make one whole"}, {"term": "compare", "definition": "find how much more or less one amount is than another"}, {"term": "unknown", "definition": "the value the problem asks you to find"}]'::jsonb,
      'Act out 14 objects with 5 removed. Ask what changed and what remains unknown.', 'Model starting amount, amount removed, and remaining result, then write 14−5=9.', 'Focus on the action in the situation rather than single keywords.',
      'In a separate story, you start with a whole amount and some is removed. Subtraction finds what remains.', 'Model and solve together.', 'Solve separate stories independently.', 'Cross-Out Model: draw the starting amount, cross out the removed amount, then record the equation.',
      'Separate Word Problems', 'Find the unknown, write a subtraction equation, and solve.', 'Complete at least 7 of 8 worksheet items correctly after corrections and identify the remaining amount as the unknown.',
      'Use counters or drawings during instruction.', 'Write two different separate stories that both match 15−6=9.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'There are 14 cookies. 5 are eaten. How many remain?', null, '9', '14−5=9 because some are removed.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'A box has 12 crayons. 4 are taken out. How many stay in the box?', null, '8', '12−4=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'There are 16 balloons and 6 pop. What is the unknown?', null, 'the number of balloons remaining', 'The starting amount and amount removed are known; the remaining amount is unknown.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Maya has 15 stickers and gives away 7. How many remain?', null, '8', '15−7=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'There are 18 birds. 5 fly away. How many are left?', null, '13', '18−5=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'A shelf has 13 books. 3 are removed. How many remain?', null, '10', '13−3=10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Sam has 17 blocks and puts away 8. Write the equation and answer.', null, '17−8=9', 'The separate action means subtraction.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'There are 10 apples. 3 are eaten. How many remain?', null, '7', '10−3=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'A jar has 14 buttons. 6 are removed. How many remain?', null, '8', '14−6=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'There are 19 toy cars. 7 are put away. How many remain?', null, '12', '19−7=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Ava has 12 beads and gives away 5. How many remain?', null, '7', '12−5=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'There are 16 ducks. 4 swim away. How many remain?', null, '12', '16−4=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'A box has 15 pencils. 9 are used. How many remain?', null, '6', '15−9=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Leo has 18 cards and loses 8. How many remain?', null, '10', '18−8=10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'There are 13 balloons. 5 pop. How many remain?', null, '8', '13−5=8.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 16, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W16-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W16-D3 was not found.';
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
      'The student will choose addition or subtraction for one-step join and separate situations and represent the situation with an equation or model.', 'I can decide whether a story needs addition or subtraction.', '["pencil", "paper"]'::jsonb, '[{"term": "join", "definition": "a situation where an amount is added to another amount"}, {"term": "separate", "definition": "a situation where some amount is taken away"}, {"term": "part-part-whole", "definition": "two parts combine to make one whole"}, {"term": "compare", "definition": "find how much more or less one amount is than another"}, {"term": "unknown", "definition": "the value the problem asks you to find"}]'::jsonb,
      'Mix one join and one separate story. Ask what is happening to the amount before choosing an operation.', 'Model the decision: amount grows/joined versus amount decreases/separated.', 'Avoid relying on keywords alone. Have the student describe the action first.',
      'Ask: What is happening?
Are amounts joining, or is part being separated?
Then choose the operation and write the equation.', 'Choose operations for guided stories.', 'Represent and solve independently.', 'Operation Sort: sort story cards by Join or Separate before solving them.',
      'Choose the Operation', 'Decide what is happening, write an equation, and solve.', 'Complete at least 7 of 8 worksheet items correctly after corrections and choose the correct operation in mixed join/separate situations.',
      'Provide a two-column Join / Separate organizer.', 'Rewrite one join story as a separate story using the same three numbers.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Lia has 6 shells and finds 5 more. Choose the operation and solve.', null, 'addition; 11', 'The amount grows, so 6+5=11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'There are 15 pencils and 6 are taken away. Choose the operation and solve.', null, 'subtraction; 9', 'The amount decreases, so 15−6=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'A story says 8 birds are present and 4 more arrive. Write an equation.', null, '8+4=12', 'Arrival joins more to the starting amount.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'A jar has 13 buttons and 5 are removed. Write an equation and solve.', null, '13−5=8', 'Removal is subtraction.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Mia has 7 stickers and gets 9 more. Write an equation and solve.', null, '7+9=16', 'Getting more is addition.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'There are 18 blocks and 7 are put away. Write an equation and solve.', null, '18−7=11', 'Putting away separates part of the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'A shelf has 9 books and 6 more are added. Write an equation and solve.', null, '9+6=15', 'Adding books joins the amounts.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      '12 birds, 3 fly away. Equation and answer?', null, '12−3=9', 'Fly away signals separation.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      '8 apples, 7 more added. Equation and answer?', null, '8+7=15', 'Added means join.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      '16 crayons, 8 removed. Equation and answer?', null, '16−8=8', 'Removed means separate.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      '6 shells, 9 more found. Equation and answer?', null, '6+9=15', 'Found more means join.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      '14 cards, 4 given away. Equation and answer?', null, '14−4=10', 'Given away means separate.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      '10 balloons, 6 more added. Equation and answer?', null, '10+6=16', 'Added means join.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      '19 toys, 5 put away. Equation and answer?', null, '19−5=14', 'Put away means separate.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      '7 pencils, 8 more received. Equation and answer?', null, '7+8=15', 'Received more means join.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 16, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W16-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W16-D4 was not found.';
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
      'The student will identify the unknown in one-step word problems and show the situation using an equation, drawing, objects, or number line.', 'I can show what a story problem is asking me to find.', '["pencil", "paper", "optional counters or number line"]'::jsonb, '[{"term": "join", "definition": "a situation where an amount is added to another amount"}, {"term": "separate", "definition": "a situation where some amount is taken away"}, {"term": "part-part-whole", "definition": "two parts combine to make one whole"}, {"term": "compare", "definition": "find how much more or less one amount is than another"}, {"term": "unknown", "definition": "the value the problem asks you to find"}]'::jsonb,
      'Give a story and ask only: ''What do we know, and what are we trying to find?'' before solving.', 'Model circling known quantities, describing the unknown in words, and then choosing a representation.', 'The competency explicitly requires identifying the unknown. Encourage students to name it before computing.',
      'Before solving a story problem:
1. Name what you know.
2. Name what is unknown.
3. Choose a model or equation.
4. Solve and check the answer in the story.', 'Identify unknowns together.', 'Solve and represent independently.', 'Unknown Label: write a short phrase such as ''stickers now'' or ''books remaining'' beside the question mark.',
      'Identify and Represent the Unknown', 'State what is unknown, choose a representation, and solve.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately state the unknown in at least three problems.',
      'Allow oral identification of the unknown if writing is a barrier.', 'Create a story where the same equation represents a different real-world context.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Mia has 8 stickers and gets 5 more. How many now?', null, '13', 'Join: 8+5=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'There are 16 balloons and 7 pop. How many remain?', null, '9', 'Separate: 16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Ava has 14 beads and Leo has 9. How many more does Ava have?', null, '5', 'Compare: 14−9=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'There are 6 red blocks and 8 blue blocks. How many total?', null, '14', 'Part-part-whole: 6+8=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'A box has 18 crayons total; 11 are red. How many are not red?', null, '7', 'Missing part: 18−11=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'There are 12 birds and 4 fly away. How many remain?', null, '8', 'Separate: 12−4=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Sam has 7 cards and gets 9 more. How many cards?', null, '16', 'Join: 7+9=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      '9 apples, 6 more added. How many?', null, '15', 'Join: 9+6=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      '17 toys, 8 put away. How many remain?', null, '9', 'Separate: 17−8=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      '5 cats and 7 dogs. How many animals?', null, '12', 'Part-part-whole: 5+7=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      '15 books total; 9 fiction. How many not fiction?', null, '6', 'Missing part: 15−9=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      '13 stickers vs 8 stickers. How many more?', null, '5', 'Compare: 13−8=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      '6 shells, 10 more found. How many?', null, '16', 'Join: 6+10=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      '19 balloons, 5 pop. How many remain?', null, '14', 'Separate: 19−5=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      '18 counters vs 12 counters. Difference?', null, '6', 'Compare: 18−12=6.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 16, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W16-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W16-D5 was not found.';
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
      'The student will independently solve mixed join and separate one-step word problems within 20 before the Week 16 online check.', 'I can read a story, identify the unknown, choose an operation, and solve.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "join", "definition": "a situation where an amount is added to another amount"}, {"term": "separate", "definition": "a situation where some amount is taken away"}, {"term": "part-part-whole", "definition": "two parts combine to make one whole"}, {"term": "compare", "definition": "find how much more or less one amount is than another"}, {"term": "unknown", "definition": "the value the problem asks you to find"}]'::jsonb,
      'Review the four-step routine without solving an assessment-like problem.', 'Model one neutral story and then remove support.', 'Week 16 is the first of two evidence weeks for 1-MATH-10. Week 17 expands to part-part-whole and compare situations.',
      'Understand the story before doing arithmetic. Identify the unknown and choose the operation because of the relationship between quantities.', 'Complete three warm-up stories.', 'Complete readiness and Week 16 online assessment independently.', 'After solving, label each problem Join or Separate.',
      'Week 16 Word-Problem Readiness', 'Identify the unknown, choose an operation, and solve each story.', 'Complete Week 16 readiness and online assessment independently using the configured 85% threshold.',
      'Directions may be read aloud. Do not identify the operation or unknown for the learner during assessment.', 'Write one join and one separate story that use the same three numbers.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Mia has 8 stickers and gets 5 more. How many now?', null, '13', 'Join: 8+5=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'There are 16 balloons and 7 pop. How many remain?', null, '9', 'Separate: 16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Ava has 14 beads and Leo has 9. How many more does Ava have?', null, '5', 'Compare: 14−9=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'There are 6 red blocks and 8 blue blocks. How many total?', null, '14', 'Part-part-whole: 6+8=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'A box has 18 crayons total; 11 are red. How many are not red?', null, '7', 'Missing part: 18−11=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'There are 12 birds and 4 fly away. How many remain?', null, '8', 'Separate: 12−4=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Sam has 7 cards and gets 9 more. How many cards?', null, '16', 'Join: 7+9=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      '9 apples, 6 more added. How many?', null, '15', 'Join: 9+6=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      '17 toys, 8 put away. How many remain?', null, '9', 'Separate: 17−8=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      '5 cats and 7 dogs. How many animals?', null, '12', 'Part-part-whole: 5+7=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      '15 books total; 9 fiction. How many not fiction?', null, '6', 'Missing part: 15−9=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      '13 stickers vs 8 stickers. How many more?', null, '5', 'Compare: 13−8=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      '6 shells, 10 more found. How many?', null, '16', 'Join: 6+10=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      '19 balloons, 5 pop. How many remain?', null, '14', 'Separate: 19−5=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      '18 counters vs 12 counters. Difference?', null, '6', 'Compare: 18−12=6.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 17, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W17-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W17-D1 was not found.';
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
      'The student will represent and solve part-part-whole situations within 20 with either the whole or one part unknown.', 'I can use parts and a whole to solve a story problem.', '["pencil", "paper", "optional part-part-whole mat"]'::jsonb, '[{"term": "join", "definition": "a situation where an amount is added to another amount"}, {"term": "separate", "definition": "a situation where some amount is taken away"}, {"term": "part-part-whole", "definition": "two parts combine to make one whole"}, {"term": "compare", "definition": "find how much more or less one amount is than another"}, {"term": "unknown", "definition": "the value the problem asks you to find"}]'::jsonb,
      'Show 7 red blocks and 5 blue blocks. Identify the two parts and the whole. Then reverse the situation by giving the whole and one part.', 'Model addition when the whole is unknown and subtraction when one part is unknown.', 'This is the same part/whole reasoning used in fact families, now applied to stories.',
      'Part-part-whole stories have two parts and one total.
If the whole is unknown, add the parts.
If one part is unknown, subtract the known part from the whole.', 'Fill a part-part-whole model together.', 'Solve mixed whole-unknown and part-unknown stories independently.', 'Part-Whole Mat: write each known amount in the correct section before choosing an equation.',
      'Part-Part-Whole Problems', 'Identify the parts and whole, then solve for the unknown.', 'Complete at least 7 of 8 worksheet items correctly after corrections and correctly identify whether the unknown is a part or the whole.',
      'Use a labeled part-part-whole diagram.', 'Write two different questions about the same set of quantities—one asking for the whole and one for a part.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'There are 7 red blocks and 5 blue blocks. How many blocks altogether?', null, '12', 'The two parts 7 and 5 make the whole 12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'A box has 13 crayons total. 8 are red and the rest are blue. How many are blue?', null, '5', '13−8=5 to find the missing part.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'There are 16 children. 9 are wearing hats. The rest are not. What is the unknown?', null, 'the number not wearing hats', 'The whole and one part are known; the other part is unknown.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'There are 6 cats and 7 dogs. How many animals total?', null, '13', '6+7=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'There are 15 books total. 9 are fiction. How many are not fiction?', null, '6', '15−9=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'A bowl has 18 pieces of fruit. 10 are apples. How many are other fruit?', null, '8', '18−10=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'There are 8 large buttons and 4 small buttons. Write the equation and total.', null, '8+4=12', 'Add the two parts to find the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      '5 red marbles and 6 blue marbles. How many total?', null, '11', '5+6=11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      '14 socks total; 8 are white. How many are not white?', null, '6', '14−8=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      '7 birds and 9 squirrels. How many animals total?', null, '16', '7+9=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      '17 pencils total; 12 are sharpened. How many are not?', null, '5', '17−12=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      '6 yellow blocks and 8 green blocks. Total?', null, '14', '6+8=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      '13 flowers total; 5 are red. How many are another color?', null, '8', '13−5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      '9 toy cars and 4 toy trucks. Total vehicles?', null, '13', '9+4=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      '20 counters total; 11 are blue. How many are not blue?', null, '9', '20−11=9.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 17, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W17-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W17-D2 was not found.';
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
      'The student will represent and solve compare situations within 20 by finding the difference between two quantities.', 'I can find how many more or how many fewer.', '["pencil", "paper", "optional comparison bars or number line"]'::jsonb, '[{"term": "join", "definition": "a situation where an amount is added to another amount"}, {"term": "separate", "definition": "a situation where some amount is taken away"}, {"term": "part-part-whole", "definition": "two parts combine to make one whole"}, {"term": "compare", "definition": "find how much more or less one amount is than another"}, {"term": "unknown", "definition": "the value the problem asks you to find"}]'::jsonb,
      'Show groups of 12 and 8. Pair items one-to-one and ask how many are unmatched.', 'Model 12−8=4 as the difference and connect to ''4 more'' / ''4 fewer.''', 'Compare problems can contain the word ''more'' but still require subtraction. This is why structural reasoning is more reliable than keywords.',
      'A compare problem asks how far apart two amounts are.
Larger amount − smaller amount = difference.', 'Use paired drawings or bars together.', 'Solve comparison stories independently.', 'Comparison Bars: draw two bars starting at the same point and mark the extra portion.',
      'Compare Word Problems', 'Find the difference and state how many more or fewer.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain why subtraction finds the difference.',
      'Use aligned bars or paired counters to make the difference visible.', 'Write a compare story where the word ''more'' appears but subtraction is needed.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Ava has 12 stickers. Leo has 8. How many more stickers does Ava have?', null, '4', '12−8=4 finds the difference.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'One tower is 15 blocks tall and another is 11 blocks tall. How many taller is the first?', null, '4', '15−11=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Nina has 7 shells and Mia has 10. What is the unknown in ''How many more does Mia have?''', null, 'the difference between 10 and 7', 'A compare problem asks how far apart the amounts are.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Sam has 14 cards and Leo has 9. How many more does Sam have?', null, '5', '14−9=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'One basket has 16 apples and another has 12. How many fewer are in the second?', null, '4', '16−12=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Maya has 8 beads and Ava has 13. How many more does Ava have?', null, '5', '13−8=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'A red line is 17 units long and a blue line is 10. Write the comparison equation.', null, '17−10=7', 'The difference is 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      '15 books vs 11 books. How many more?', null, '4', '15−11=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      '9 crayons vs 13 crayons. How many fewer does the first group have?', null, '4', '13−9=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      '18 blocks vs 12 blocks. Difference?', null, '6', '18−12=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      '7 shells vs 10 shells. How many more in the larger group?', null, '3', '10−7=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      '16 cards vs 9 cards. Difference?', null, '7', '16−9=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      '14 apples vs 8 apples. How many fewer in the smaller group?', null, '6', '14−8=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      '20 counters vs 15 counters. Difference?', null, '5', '20−15=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      '11 balloons vs 6 balloons. How many more in the larger group?', null, '5', '11−6=5.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 17, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W17-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W17-D3 was not found.';
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
      'The student will distinguish join, separate, part-part-whole, and compare structures and choose an equation that represents each.', 'I can tell what kind of story problem I am solving.', '["pencil", "paper", "optional story-structure organizer"]'::jsonb, '[{"term": "join", "definition": "a situation where an amount is added to another amount"}, {"term": "separate", "definition": "a situation where some amount is taken away"}, {"term": "part-part-whole", "definition": "two parts combine to make one whole"}, {"term": "compare", "definition": "find how much more or less one amount is than another"}, {"term": "unknown", "definition": "the value the problem asks you to find"}]'::jsonb,
      'Present four short stories—one of each structure—and compare what the quantities are doing.', 'Model identifying the structure before choosing the operation.', 'Do not require the student to memorize labels perfectly if the mathematical representation is correct; the labels support reasoning.',
      'Ask what relationship the story describes:
Join: amount grows.
Separate: amount decreases.
Part-part-whole: parts make a whole.
Compare: two amounts are measured against each other.', 'Classify and represent examples together.', 'Solve mixed structures independently.', 'Four-Corner Sort: sort story cards into Join, Separate, Part-Part-Whole, or Compare.',
      'Identify the Story Structure', 'Identify the relationship, write an equation, and solve.', 'Complete at least 7 of 8 worksheet items correctly after corrections and correctly represent all four story structures.',
      'Keep a four-structure visual organizer available.', 'Take one equation and invent two different story structures that could match it.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Mia has 8 stickers and gets 5 more. How many now?', null, '13', 'Join: 8+5=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'There are 16 balloons and 7 pop. How many remain?', null, '9', 'Separate: 16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Ava has 14 beads and Leo has 9. How many more does Ava have?', null, '5', 'Compare: 14−9=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'There are 6 red blocks and 8 blue blocks. How many total?', null, '14', 'Part-part-whole: 6+8=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'A box has 18 crayons total; 11 are red. How many are not red?', null, '7', 'Missing part: 18−11=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'There are 12 birds and 4 fly away. How many remain?', null, '8', 'Separate: 12−4=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Sam has 7 cards and gets 9 more. How many cards?', null, '16', 'Join: 7+9=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      '9 apples, 6 more added. How many?', null, '15', 'Join: 9+6=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      '17 toys, 8 put away. How many remain?', null, '9', 'Separate: 17−8=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      '5 cats and 7 dogs. How many animals?', null, '12', 'Part-part-whole: 5+7=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      '15 books total; 9 fiction. How many not fiction?', null, '6', 'Missing part: 15−9=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      '13 stickers vs 8 stickers. How many more?', null, '5', 'Compare: 13−8=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      '6 shells, 10 more found. How many?', null, '16', 'Join: 6+10=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      '19 balloons, 5 pop. How many remain?', null, '14', 'Separate: 19−5=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      '18 counters vs 12 counters. Difference?', null, '6', 'Compare: 18−12=6.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 17, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W17-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W17-D4 was not found.';
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
      'The student will independently model and explain one-step addition/subtraction word problems within 20, including operation choice and unknown identification.', 'I can show why my equation matches the story.', '["pencil", "paper", "optional drawing/model space"]'::jsonb, '[{"term": "join", "definition": "a situation where an amount is added to another amount"}, {"term": "separate", "definition": "a situation where some amount is taken away"}, {"term": "part-part-whole", "definition": "two parts combine to make one whole"}, {"term": "compare", "definition": "find how much more or less one amount is than another"}, {"term": "unknown", "definition": "the value the problem asks you to find"}, {"term": "justify", "definition": "give a reason that shows why an answer or method fits"}]'::jsonb,
      'Explain that the goal is not only getting a number; the equation should match what happens in the story.', 'Model one story with an equation and a one-sentence justification.', 'Accept drawings, equations, objects, number lines, or oral explanations as valid representations. Repeated qualifying evidence remains sufficient; no separate hands-on requirement is imposed.',
      'A strong word-problem solution shows:
• what is unknown
• a matching equation or model
• the correct answer
• a reason the operation fits', 'Explain why equations match guided stories.', 'Solve and justify independently.', 'Equation Defense: choose one solved story and explain why the other operation would not match the situation.',
      'Explain Your Word-Problem Model', 'Solve each story and explain why your equation fits.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately justify one operation choice.',
      'Allow oral explanations or diagrams instead of full written sentences.', 'Write a misleading-keyword story and explain how structure reveals the correct operation.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Mia has 8 stickers and gets 5 more. How many now?', null, '13', 'Join: 8+5=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'There are 16 balloons and 7 pop. How many remain?', null, '9', 'Separate: 16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Ava has 14 beads and Leo has 9. How many more does Ava have?', null, '5', 'Compare: 14−9=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'There are 6 red blocks and 8 blue blocks. How many total?', null, '14', 'Part-part-whole: 6+8=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'A box has 18 crayons total; 11 are red. How many are not red?', null, '7', 'Missing part: 18−11=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'There are 12 birds and 4 fly away. How many remain?', null, '8', 'Separate: 12−4=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Sam has 7 cards and gets 9 more. How many cards?', null, '16', 'Join: 7+9=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      '9 apples, 6 more added. How many?', null, '15', 'Join: 9+6=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      '17 toys, 8 put away. How many remain?', null, '9', 'Separate: 17−8=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      '5 cats and 7 dogs. How many animals?', null, '12', 'Part-part-whole: 5+7=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      '15 books total; 9 fiction. How many not fiction?', null, '6', 'Missing part: 15−9=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      '13 stickers vs 8 stickers. How many more?', null, '5', 'Compare: 13−8=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      '6 shells, 10 more found. How many?', null, '16', 'Join: 6+10=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      '19 balloons, 5 pop. How many remain?', null, '14', 'Separate: 19−5=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      '18 counters vs 12 counters. Difference?', null, '6', 'Compare: 18−12=6.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 17, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W17-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W17-D5 was not found.';
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
      'The student will independently demonstrate the full 1-MATH-10 objective across join, separate, part-part-whole, and compare situations before the Week 17 online check.', 'I can solve different kinds of one-step addition and subtraction stories.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "join", "definition": "a situation where an amount is added to another amount"}, {"term": "separate", "definition": "a situation where some amount is taken away"}, {"term": "part-part-whole", "definition": "two parts combine to make one whole"}, {"term": "compare", "definition": "find how much more or less one amount is than another"}, {"term": "unknown", "definition": "the value the problem asks you to find"}]'::jsonb,
      'Ask the student to name the four story structures and one clue about the relationship in each.', 'Model one neutral mixed example only.', 'Week 17 supplies a second assessment opportunity for 1-MATH-10 and should be interpreted with Week 16 and other independent evidence.',
      'Do not choose an operation from a single word. Understand what the quantities are doing, identify the unknown, then represent and solve.', 'Complete three mixed warm-up stories.', 'Complete the readiness set and Week 17 online assessment independently.', 'Story Reflection: label several solved problems by structure after completing them.',
      'Week 17 Word-Problem Mastery Readiness', 'Identify the relationship, unknown, equation, and answer.', 'Complete Week 17 readiness and online assessment independently under the configured 85% repeated-evidence rules.',
      'Directions may be read aloud, but do not identify the operation, structure, or unknown during assessment.', 'Create one original problem for each of the four story structures.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Mia has 8 stickers and gets 5 more. How many now?', null, '13', 'Join: 8+5=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'There are 16 balloons and 7 pop. How many remain?', null, '9', 'Separate: 16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Ava has 14 beads and Leo has 9. How many more does Ava have?', null, '5', 'Compare: 14−9=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'There are 6 red blocks and 8 blue blocks. How many total?', null, '14', 'Part-part-whole: 6+8=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'A box has 18 crayons total; 11 are red. How many are not red?', null, '7', 'Missing part: 18−11=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'There are 12 birds and 4 fly away. How many remain?', null, '8', 'Separate: 12−4=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Sam has 7 cards and gets 9 more. How many cards?', null, '16', 'Join: 7+9=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      '9 apples, 6 more added. How many?', null, '15', 'Join: 9+6=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      '17 toys, 8 put away. How many remain?', null, '9', 'Separate: 17−8=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      '5 cats and 7 dogs. How many animals?', null, '12', 'Part-part-whole: 5+7=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      '15 books total; 9 fiction. How many not fiction?', null, '6', 'Missing part: 15−9=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      '13 stickers vs 8 stickers. How many more?', null, '5', 'Compare: 13−8=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      '6 shells, 10 more found. How many?', null, '16', 'Join: 6+10=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      '19 balloons, 5 pop. How many remain?', null, '14', 'Separate: 19−5=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      '18 counters vs 12 counters. Difference?', null, '6', 'Compare: 18−12=6.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 13 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 13
      and l.week_number = 13
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W13-Q01', 1, 'short_answer', 'Solve 16 − 7.', '[]'::jsonb, '9', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W13-Q02', 2, 'short_answer', 'Solve 18 − 15.', '[]'::jsonb, '3', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W13-Q03', 3, 'short_answer', 'Solve 14 − 6.', '[]'::jsonb, '8', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W13-Q04', 4, 'short_answer', 'Solve 19 − 4.', '[]'::jsonb, '15', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W13-Q05', 5, 'short_answer', 'Solve 13 − 8.', '[]'::jsonb, '5', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W13-Q06', 6, 'multiple_choice', 'For 17 − 15, which strategy is especially efficient?', '[{"id": "a", "label": "count on from 15"}, {"id": "b", "label": "count back 15 steps"}, {"id": "c", "label": "add 17 and 15"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W13-Q07', 7, 'multiple_choice', 'For 18 − 3, which strategy is especially efficient?', '[{"id": "a", "label": "count back 3"}, {"id": "b", "label": "count on from 3 to 18"}, {"id": "c", "label": "add 3"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W13-Q08', 8, 'multiple_choice', 'For 14 − 6, which strategy uses 10 as a stopping point?', '[{"id": "a", "label": "subtract 4 to reach 10, then subtract 2"}, {"id": "b", "label": "add 6 to 14"}, {"id": "c", "label": "count by tens"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W13-Q09', 9, 'short_answer', 'Solve 20 − 11.', '[]'::jsonb, '9', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W13-Q10', 10, 'short_answer', 'Solve 15 − 13.', '[]'::jsonb, '2', 1);


    -- Freeze the new question bank onto any still-open assignment generated
    -- before this migration.
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


    -- Week 14 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 14
      and l.week_number = 14
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W14-Q01', 1, 'short_answer', 'Solve 4 + 5.', '[]'::jsonb, '9', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W14-Q02', 2, 'short_answer', 'Solve 9 − 4.', '[]'::jsonb, '5', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W14-Q03', 3, 'short_answer', 'Solve 3 + 3.', '[]'::jsonb, '6', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W14-Q04', 4, 'short_answer', 'Solve 8 − 5.', '[]'::jsonb, '3', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W14-Q05', 5, 'short_answer', 'Solve 2 + 7.', '[]'::jsonb, '9', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W14-Q06', 6, 'short_answer', 'Solve 10 − 6.', '[]'::jsonb, '4', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W14-Q07', 7, 'multiple_choice', 'If 4 + 4 = 8, what is 4 + 5?', '[{"id": "a", "label": "7"}, {"id": "b", "label": "8"}, {"id": "c", "label": "9"}]'::jsonb, 'c', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W14-Q08', 8, 'multiple_choice', 'If 3 + 5 = 8, what is 8 − 3?', '[{"id": "a", "label": "3"}, {"id": "b", "label": "5"}, {"id": "c", "label": "8"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W14-Q09', 9, 'short_answer', 'Solve 6 + 3.', '[]'::jsonb, '9', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W14-Q10', 10, 'short_answer', 'Solve 7 − 3.', '[]'::jsonb, '4', 1);


    -- Freeze the new question bank onto any still-open assignment generated
    -- before this migration.
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


    -- Week 15 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 15
      and l.week_number = 15
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W15-Q01', 1, 'multiple_choice', 'Which subtraction fact belongs with 3 + 5 = 8?', '[{"id": "a", "label": "8 − 3 = 5"}, {"id": "b", "label": "8 − 3 = 6"}, {"id": "c", "label": "5 − 3 = 8"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W15-Q02', 2, 'multiple_choice', 'Which addition fact checks 9 − 4 = 5?', '[{"id": "a", "label": "5 + 4 = 9"}, {"id": "b", "label": "9 + 4 = 13"}, {"id": "c", "label": "5 + 9 = 14"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W15-Q03', 3, 'short_answer', 'Use 6 + 3 = 9 to solve 9 − 6.', '[]'::jsonb, '3', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W15-Q04', 4, 'short_answer', 'Use 4 + 5 = 9 to solve 9 − 5.', '[]'::jsonb, '4', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W15-Q05', 5, 'multiple_choice', 'What is the whole in the fact family 2, 7, 9?', '[{"id": "a", "label": "2"}, {"id": "b", "label": "7"}, {"id": "c", "label": "9"}]'::jsonb, 'c', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W15-Q06', 6, 'multiple_choice', 'What are the parts in 10 − 6 = 4?', '[{"id": "a", "label": "10 and 6"}, {"id": "b", "label": "6 and 4"}, {"id": "c", "label": "10 and 4"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W15-Q07', 7, 'multiple_choice', 'Are 2 + 6 = 8 and 8 − 6 = 2 related facts?', '[{"id": "a", "label": "yes"}, {"id": "b", "label": "no"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W15-Q08', 8, 'short_answer', 'Give the subtraction fact that checks 5 + 3 = 8 by subtracting 3.', '[]'::jsonb, '8 − 3 = 5', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W15-Q09', 9, 'short_answer', 'Use 7 + 2 = 9 to solve 9 − 7.', '[]'::jsonb, '2', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W15-Q10', 10, 'short_answer', 'Check 10 − 7 = 3 using addition.', '[]'::jsonb, '3 + 7 = 10', 1);


    -- Freeze the new question bank onto any still-open assignment generated
    -- before this migration.
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


    -- Week 16 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 16
      and l.week_number = 16
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W16-Q01', 1, 'short_answer', 'Mia has 7 stickers and gets 5 more. How many stickers now?', '[]'::jsonb, '12', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W16-Q02', 2, 'short_answer', 'There are 14 cookies and 5 are eaten. How many remain?', '[]'::jsonb, '9', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W16-Q03', 3, 'multiple_choice', 'A jar has 8 buttons and 6 more are added. Which operation matches?', '[{"id": "a", "label": "addition"}, {"id": "b", "label": "subtraction"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W16-Q04', 4, 'multiple_choice', 'There are 16 balloons and 7 pop. Which operation matches?', '[{"id": "a", "label": "addition"}, {"id": "b", "label": "subtraction"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W16-Q05', 5, 'short_answer', 'There are 10 toy cars and 4 more are added. How many in all?', '[]'::jsonb, '14', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W16-Q06', 6, 'short_answer', 'A shelf has 13 books and 3 are removed. How many remain?', '[]'::jsonb, '10', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W16-Q07', 7, 'multiple_choice', 'In ''Leo has 9 blocks and gets 3 more,'' what is unknown?', '[{"id": "a", "label": "the starting number"}, {"id": "b", "label": "the number added"}, {"id": "c", "label": "the final total"}]'::jsonb, 'c', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W16-Q08', 8, 'multiple_choice', 'In ''18 birds are present and 5 fly away,'' what is unknown?', '[{"id": "a", "label": "the number remaining"}, {"id": "b", "label": "the starting number"}, {"id": "c", "label": "the number that flew away"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W16-Q09', 9, 'short_answer', 'Sam has 6 crayons and gets 8 more. How many crayons?', '[]'::jsonb, '14', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W16-Q10', 10, 'short_answer', 'Ava has 12 beads and gives away 5. How many remain?', '[]'::jsonb, '7', 1);


    -- Freeze the new question bank onto any still-open assignment generated
    -- before this migration.
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


    -- Week 17 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 17
      and l.week_number = 17
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W17-Q01', 1, 'short_answer', 'There are 7 red blocks and 5 blue blocks. How many blocks total?', '[]'::jsonb, '12', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W17-Q02', 2, 'short_answer', 'A box has 13 crayons total. 8 are red. How many are not red?', '[]'::jsonb, '5', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W17-Q03', 3, 'short_answer', 'Ava has 12 stickers and Leo has 8. How many more does Ava have?', '[]'::jsonb, '4', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W17-Q04', 4, 'short_answer', 'Sam has 14 cards and Leo has 9. How many more does Sam have?', '[]'::jsonb, '5', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W17-Q05', 5, 'multiple_choice', 'Which structure describes ''6 cats and 7 dogs; how many animals total''?', '[{"id": "a", "label": "join over time"}, {"id": "b", "label": "part-part-whole"}, {"id": "c", "label": "compare"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W17-Q06', 6, 'multiple_choice', 'Which structure describes ''15 blocks versus 11 blocks; how many more''?', '[{"id": "a", "label": "compare"}, {"id": "b", "label": "join"}, {"id": "c", "label": "separate"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W17-Q07', 7, 'short_answer', 'There are 17 pencils total and 12 are sharpened. How many are not sharpened?', '[]'::jsonb, '5', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W17-Q08', 8, 'short_answer', 'There are 9 apples and 6 more are added. How many apples?', '[]'::jsonb, '15', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W17-Q09', 9, 'short_answer', 'There are 19 toys and 5 are put away. How many remain?', '[]'::jsonb, '14', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W17-Q10', 10, 'multiple_choice', 'A story asks how far apart two quantities are. Which operation usually finds the difference?', '[{"id": "a", "label": "addition"}, {"id": "b", "label": "subtraction"}]'::jsonb, 'b', 1);


    -- Freeze the new question bank onto any still-open assignment generated
    -- before this migration.
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
