-- Homeschool Tracker
-- Migration 021: Grade 1 Mathematics Weeks 18–22 production curriculum
--
-- Week 18 : Quarter 2 Mastery Check (1-MATH-06..10)
-- Week 19 : Equations and Unknowns I (1-MATH-11)
-- Week 20 : Equations and Unknowns II (1-MATH-11)
-- Week 21 : Measuring Length I (1-MATH-12)
-- Week 22 : Measuring Length II (1-MATH-12)
--
-- Installs:
-- * 25 published lesson-content revisions
-- * 375 guided/independent/worksheet items
-- * 50 auto-scored online assessment items
--
-- Safety:
-- * one transaction
-- * full Weeks 18–22 preflight before writes
-- * refuses to overwrite published/superseded lesson history
-- * refuses to alter frozen student lesson deliveries
-- * refuses to overwrite existing online question banks
--
-- Mastery policy:
-- Practical models/activities are allowed instructionally, but this migration
-- does not create a separate hands-on mastery requirement. Existing repeated
-- qualifying competency evidence remains authoritative.

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

    -- Full preflight before writing anything.
    for v_week in 18..22 loop
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
        raise exception 'Grade 1 Math Week % already has published lesson content. Migration 021 will not overwrite curriculum history.', v_week;
      end if;

      if exists (
        select 1
        from public.student_lesson_deliveries sld
        join public.lessons l on l.id = sld.lesson_id
        where l.course_version_id = v_course.course_version_id
          and l.week_number = v_week
      ) then
        raise exception 'Grade 1 Math Week % is already frozen to a student delivery. Migration 021 will not rewrite delivered curriculum.', v_week;
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
        raise exception 'Grade 1 Math Week % already has an online question bank. Migration 021 will not overwrite assessment history.', v_week;
      end if;
    end loop;

    delete from public.lesson_content_versions lcv
    using public.lessons l
    where lcv.lesson_id = l.id
      and l.course_version_id = v_course.course_version_id
      and l.week_number between 18 and 22
      and lcv.status = 'draft';


    -- Week 18, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W18-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W18-D1 was not found.';
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
      'The student will independently review addition and subtraction within 20 using efficient strategies from Weeks 10–13.', 'I can add and subtract within 20 using strategies I understand.',
      '["pencil", "scratch paper", "optional number line during review"]'::jsonb, '[{"term": "strategy", "definition": "a useful way to solve a math problem"}, {"term": "fact family", "definition": "related addition and subtraction equations using the same three numbers"}, {"term": "unknown", "definition": "the amount a problem asks you to find"}]'::jsonb,
      'Explain that Quarter 2 mastery week begins by bringing back addition and subtraction strategies without reteaching every lesson.', 'Model one addition and one subtraction problem, naming the strategy and checking whether the answer is reasonable.', 'Keep the review brief enough to reveal retained understanding. Do not coach through the independent portion.',
      'Quarter 2 began with addition and subtraction within 20. Use strategies such as count on, doubles, make ten, count back, count on to find a difference, or break apart through 10.', 'Solve three mixed examples together and name the strategy used.',
      'Complete mixed addition/subtraction work independently.', 'Strategy Match: choose the strategy you would try first for six fact cards, then solve them.',
      'Quarter 2 Review — Add and Subtract Within 20', 'Solve each problem accurately and use a strategy that fits.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and explain one addition or subtraction strategy.', 'Use normal instructional supports during review; fade them for an independent second attempt when appropriate.',
      'Solve one addition and one subtraction problem in two different ways.',
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
      'Solve 8 + 7.', null,
      '15', 'Make ten or use a near double to get 15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Solve 16 − 9.', null,
      '7', '16−6=10, then subtract 3 more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Solve 13 + 5.', null,
      '18', 'Count on five from 13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Solve 9 + 6.', null,
      '15', '9+1=10, then add 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve 18 − 5.', null,
      '13', 'Count back five from 18.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 7 + 8.', null,
      '15', 'Use 7+7=14, then one more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Solve 14 − 11.', null,
      '3', 'Count on from 11 to 14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Solve 6 + 9.', null,
      '15', '6+4=10, then add 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Solve 17 − 8.', null,
      '9', '17−7=10, then subtract 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Solve 12 + 6.', null,
      '18', 'Count on six from 12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Solve 15 − 7.', null,
      '8', '15−5=10, then subtract 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Solve 9 + 9.', null,
      '18', 'Double 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Solve 19 − 16.', null,
      '3', 'Count on from 16 to 19.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Solve 8 + 5.', null,
      '13', 'Make ten: 8+2+3=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Solve 20 − 9.', null,
      '11', '20−9=11.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 18, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W18-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W18-D2 was not found.';
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
      'The student will independently review mixed addition/subtraction fact fluency within 10 and related fact strategies.', 'I can solve facts within 10 accurately and efficiently.',
      '["pencil", "scratch paper"]'::jsonb, '[{"term": "strategy", "definition": "a useful way to solve a math problem"}, {"term": "fact family", "definition": "related addition and subtraction equations using the same three numbers"}, {"term": "unknown", "definition": "the amount a problem asks you to find"}, {"term": "fluency", "definition": "accurate and efficient recall or derivation of facts"}]'::jsonb,
      'Remind the student that fluency means accurate and efficient, not simply fast.', 'Model one fact solved from a known double and one subtraction fact solved from a related addition fact.', '1-MATH-08 has a 90% threshold. Avoid turning review into a speed-only drill.',
      'Use known facts, doubles, near doubles, and related addition/subtraction facts instead of rebuilding every amount from 1.', 'Solve three facts and state the known fact that helps.',
      'Complete the mixed fluency set independently.', 'Anchor-Fact Web: choose one fact you know well and list nearby facts it helps solve.',
      'Quarter 2 Review — Fact Fluency Within 10', 'Solve each mixed fact accurately and efficiently.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and demonstrate efficient derivation on at least one fact.', 'Do not impose a timer unless it is supportive for the learner.',
      'Explain how 5+5 can help solve both 5+4 and 10−5.',
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
      'Solve 4 + 5.', null,
      '9', '4+5=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Solve 9 − 4.', null,
      '5', '9−4=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Use 4+4=8 to solve 4+5.', null,
      '9', 'The near double is one more than 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Solve 3 + 6.', null,
      '9', '3+6=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve 10 − 7.', null,
      '3', '10−7=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 5 + 5.', null,
      '10', 'Double 5 is 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Solve 8 − 5.', null,
      '3', '5+3=8, so 8−5=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Solve 2 + 7.', null,
      '9', '2+7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Solve 9 − 6.', null,
      '3', '9−6=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Solve 4 + 4.', null,
      '8', 'Double 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Solve 8 − 3.', null,
      '5', '8−3=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Solve 6 + 3.', null,
      '9', '6+3=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Solve 7 − 2.', null,
      '5', '7−2=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Solve 5 + 4.', null,
      '9', 'Use 5+5=10 and subtract one.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Solve 10 − 6.', null,
      '4', '6+4=10.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 18, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W18-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W18-D3 was not found.';
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
      'The student will independently review fact families and inverse relationships between addition and subtraction.', 'I can use addition and subtraction together to check and solve facts.',
      '["pencil", "paper"]'::jsonb, '[{"term": "strategy", "definition": "a useful way to solve a math problem"}, {"term": "fact family", "definition": "related addition and subtraction equations using the same three numbers"}, {"term": "unknown", "definition": "the amount a problem asks you to find"}]'::jsonb,
      'Ask the student to explain what makes four equations a fact family.', 'Model one fact family and one inverse check.', 'The review should test retained relationship understanding, not only memorized equation patterns.',
      'Parts and whole connect addition and subtraction. Addition builds the whole; subtraction starts with the whole and finds a part.', 'Build one fact family and check one equation together.',
      'Complete relationship problems independently.', 'Inverse Check: after solving a subtraction fact, write an addition equation that proves it.',
      'Quarter 2 Review — Addition and Subtraction Relationships', 'Use fact families and inverse operations to solve and check.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and explain one inverse relationship.', 'Use a fact-family triangle during guided review if needed.',
      'Create a fact-family puzzle with one number hidden.',
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
      'Write one subtraction fact related to 4 + 5 = 9.', null,
      '9 − 4 = 5', '9−5=4 is also related.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Use 6 + 3 = 9 to solve 9 − 6.', null,
      '3', 'The other part is 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Check 10 − 7 = 3 using addition.', null,
      '3 + 7 = 10', 'The parts rebuild the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Write the fact family for 2, 6, and 8.', null,
      '2+6=8; 6+2=8; 8−2=6; 8−6=2', 'All four use the same parts and whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Use 5 + 4 = 9 to solve 9 − 5.', null,
      '4', 'The other part is 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Check 3 + 6 = 9 using subtraction.', null,
      '9 − 6 = 3', 'The inverse operation recovers an addend.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'What is the whole in 7 − 2 = 5?', null,
      '7', 'Subtraction begins with the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Give an addition fact related to 8 − 3 = 5.', null,
      '3 + 5 = 8', '5+3=8 also works.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Use 7 + 3 = 10 to solve 10 − 3.', null,
      '7', 'The other part is 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Check 9 − 4 = 5 using addition.', null,
      '5 + 4 = 9', 'The two parts rebuild 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'What are the parts in the family 6, 4, 10?', null,
      '6 and 4', '6+4=10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Write one subtraction fact related to 3 + 4 = 7.', null,
      '7 − 3 = 4', '7−4=3 is also correct.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Use 2 + 5 = 7 to solve 7 − 2.', null,
      '5', 'The other part is 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Are 4+4=8 and 8−4=4 related facts?', null,
      'yes', 'They use the same parts and whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Check 6 + 2 = 8 using subtraction.', null,
      '8 − 2 = 6', 'The inverse recovers the other addend.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 18, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W18-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W18-D4 was not found.';
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
      'The student will independently review one-step join, separate, part-part-whole, and compare word problems within 20.', 'I can understand a story, identify the unknown, choose an operation, and solve.',
      '["pencil", "scratch paper"]'::jsonb, '[{"term": "strategy", "definition": "a useful way to solve a math problem"}, {"term": "fact family", "definition": "related addition and subtraction equations using the same three numbers"}, {"term": "unknown", "definition": "the amount a problem asks you to find"}]'::jsonb,
      'Review the four story structures without giving operation keywords as rules.', 'Model one story by naming what the quantities are doing, identifying the unknown, then writing the equation.', 'Keep the focus on structure. The word ''more'' can appear in both join and compare problems.',
      'Understand the relationship first: join, separate, parts-and-whole, or compare. Then identify the unknown, represent the story, and solve.', 'Classify and solve three examples together.',
      'Complete mixed stories independently.', 'Structure Sort: label solved stories Join, Separate, Part-Part-Whole, or Compare.',
      'Quarter 2 Review — One-Step Word Problems', 'Identify what is unknown, choose an equation, and solve.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and justify one operation choice.', 'Directions may be read aloud without identifying the operation.',
      'Write two different story structures that could use the same three numbers.',
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
      'Mia has 8 stickers and gets 5 more. How many now?', null,
      '13', 'Join: 8+5=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'There are 15 balloons and 6 pop. How many remain?', null,
      '9', 'Separate: 15−6=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Ava has 14 cards and Leo has 9. How many more does Ava have?', null,
      '5', 'Compare: 14−9=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'There are 6 red blocks and 7 blue blocks. How many total?', null,
      '13', 'Part-part-whole: 6+7=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'A box has 17 crayons total. 10 are red. How many are not red?', null,
      '7', 'Missing part: 17−10=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Sam has 7 shells and finds 8 more. How many shells?', null,
      '15', 'Join: 7+8=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'There are 18 birds and 5 fly away. How many remain?', null,
      '13', 'Separate: 18−5=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '9 apples and 6 more are added. How many?', null,
      '15', 'Join: 9+6=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '16 toys, 7 put away. How many remain?', null,
      '9', 'Separate: 16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '5 cats and 8 dogs. How many animals total?', null,
      '13', 'Part-part-whole: 5+8=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '18 pencils total; 12 are sharpened. How many are not?', null,
      '6', 'Missing part: 18−12=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '13 stickers versus 8 stickers. How many more?', null,
      '5', 'Compare: 13−8=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '6 shells, 10 more found. How many?', null,
      '16', 'Join: 6+10=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '19 balloons, 4 pop. How many remain?', null,
      '15', 'Separate: 19−4=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '17 counters versus 11 counters. What is the difference?', null,
      '6', 'Compare: 17−11=6.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 18, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W18-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W18-D5 was not found.';
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
      'The student will complete a cumulative Quarter 2 mastery readiness review across 1-MATH-06 through 1-MATH-10 before the Week 18 online mastery check.', 'I can show what I remember from all of Quarter 2.',
      '["pencil", "scratch paper"]'::jsonb, '[{"term": "strategy", "definition": "a useful way to solve a math problem"}, {"term": "fact family", "definition": "related addition and subtraction equations using the same three numbers"}, {"term": "unknown", "definition": "the amount a problem asks you to find"}]'::jsonb,
      'Explain that the Week 18 assessment intentionally mixes operations, fluency, relationships, and story reasoning.', 'Model one neutral mixed item only, then transition to independent work.', 'The Week 18 Friday assignment is already mapped to all five Quarter 2 competencies. Interpret its evidence with the existing per-competency thresholds, including the 90% threshold for 1-MATH-08.',
      'Read carefully, identify the skill being used, solve independently, and check whether the answer makes sense.', 'Complete three mixed warm-ups.',
      'Complete readiness and the cumulative online mastery check independently.', 'Quarter Reflection: name one Quarter 2 skill that feels strongest and one worth practicing again.',
      'Quarter 2 Mastery Readiness', 'Complete the mixed review before the Quarter 2 mastery check.',
      'Complete the Week 18 online mastery assessment independently. Use existing repeated-evidence rules and each competency''s configured threshold.', 'Use normal accommodations without supplying operations, strategies, or answers.',
      'Create one challenge that connects a fact family to a word problem.',
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
      'Solve 8 + 9.', null,
      '17', '8+9=17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Solve 16 − 7.', null,
      '9', '16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Use 5 + 4 = 9 to solve 9 − 5.', null,
      '4', 'The other part is 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Solve 4 + 5.', null,
      '9', 'Fact fluency within 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve 9 − 6.', null,
      '3', 'Fact fluency within 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Check 10 − 6 = 4 using addition.', null,
      '4 + 6 = 10', 'The inverse rebuilds the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'There are 14 birds and 5 fly away. How many remain?', null,
      '9', '14−5=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Solve 7 + 8.', null,
      '15', '7+8=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Solve 18 − 9.', null,
      '9', '18−9=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Solve 3 + 6.', null,
      '9', '3+6=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Solve 10 − 7.', null,
      '3', '10−7=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Give one subtraction fact related to 2+6=8.', null,
      '8 − 2 = 6', '8−6=2 is also correct.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Mia has 7 stickers and gets 6 more. How many?', null,
      '13', 'Join: 7+6=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '15 crayons total; 9 are red. How many are not red?', null,
      '6', 'Missing part: 15−9=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Ava has 12 cards and Leo has 8. How many more?', null,
      '4', 'Compare: 12−8=4.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 19, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W19-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W19-D1 was not found.';
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
      'The student will explain the equals sign as meaning both sides of an equation have the same value and classify simple equations as true or false.', 'I can tell whether both sides of an equation are equal.',
      '["pencil", "paper", "optional balance-scale drawing"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing that two amounts are equal"}, {"term": "equals sign", "definition": "a symbol meaning both sides have the same value"}, {"term": "unknown", "definition": "a number that must be found"}]'::jsonb,
      'Write 5+3=8 and 8=5+3. Ask whether the equals sign means ''the answer comes next'' or ''both sides have the same value.''', 'Model checking each side independently before deciding whether an equation is true.', 'Develop equality meaning before focusing heavily on missing-number procedures.',
      'The equals sign means the left side and right side have the same value. The answer does not always have to be on the right.', 'Evaluate both sides of several equations together.',
      'Mark equations true or false independently.', 'Equation Balance: draw a simple balance with one side labeled by each expression and decide whether the values balance.',
      'What the Equals Sign Means', 'Decide whether each equation is true or false by checking both sides.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and explain that = means same value.', 'Use drawings of balanced and unbalanced scales during instruction.',
      'Write one true equation with the total on the left side.',
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
      'Is 5 + 3 = 8 true or false?', null,
      'true', 'Both sides have value 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Is 6 + 2 = 7 true or false?', null,
      'false', '6+2=8, not 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Which statement is true: 4+5=9 or 4+5=8?', null,
      '4+5=9', 'Both sides of 4+5=9 have value 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Is 9 − 4 = 5 true or false?', null,
      'true', '9−4=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Is 10 − 3 = 8 true or false?', null,
      'false', '10−3=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Is 7 = 3 + 4 true or false?', null,
      'true', '3+4 has value 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Is 6 = 8 − 2 true or false?', null,
      'true', '8−2 has value 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'True or false: 2+6=8.', null,
      'true', '2+6=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'True or false: 5+5=9.', null,
      'false', '5+5=10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'True or false: 7=10−3.', null,
      'true', '10−3=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'True or false: 4=9−4.', null,
      'false', '9−4=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'True or false: 8=3+5.', null,
      'true', '3+5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'True or false: 12−4=8.', null,
      'true', '12−4=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'True or false: 6+7=12.', null,
      'false', '6+7=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'True or false: 15−6=9.', null,
      'true', '15−6=9.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 19, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W19-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W19-D2 was not found.';
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
      'The student will determine result unknowns in addition and subtraction equations within 20, including equations with the result written on either side.', 'I can find an unknown result even when it is written in a different place.',
      '["pencil", "scratch paper"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing that two amounts are equal"}, {"term": "equals sign", "definition": "a symbol meaning both sides have the same value"}, {"term": "unknown", "definition": "a number that must be found"}]'::jsonb,
      'Show 7+5=? and ?=7+5. Explain that both ask for the same value.', 'Model solving the operation first, then replacing the unknown with the result.', 'Avoid teaching the unknown symbol as always meaning ''answer at the end.''',
      'An unknown can appear on either side of the equals sign. Solve the known operation and make both sides equal.', 'Find unknown results together.',
      'Complete result-unknown equations independently.', 'Flip the Equation: rewrite result-unknown equations with the result on the opposite side of =.',
      'Result Unknowns', 'Find the unknown number that makes each equation true.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and solve result unknowns on both sides of =.', 'Let the student cover the unknown and evaluate the known expression first.',
      'Write three equations where the result appears on the left of the equals sign.',
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
      'Find the unknown: 7 + 5 = ?', null,
      '12', '7+5=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Find the unknown: 14 − 6 = ?', null,
      '8', '14−6=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Find the unknown: ? = 8 + 4', null,
      '12', 'The unknown equals the value of 8+4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Find ?: 9 + 6 = ?', null,
      '15', '9+6=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Find ?: 17 − 8 = ?', null,
      '9', '17−8=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Find ?: ? = 6 + 7', null,
      '13', '6+7=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Find ?: ? = 16 − 5', null,
      '11', '16−5=11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '5+4=?', null,
      '9', '5+4=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '13−7=?', null,
      '6', '13−7=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '?=8+8', null,
      '16', '8+8=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '?=18−9', null,
      '9', '18−9=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '7+6=?', null,
      '13', '7+6=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '15−4=?', null,
      '11', '15−4=11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '?=9+9', null,
      '18', '9+9=18.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '?=20−8', null,
      '12', '20−8=12.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 19, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W19-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W19-D3 was not found.';
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
      'The student will determine unknown addends in addition equations within 20 using counting on, related subtraction, or fact-family reasoning.', 'I can find a missing part in an addition equation.',
      '["pencil", "paper", "optional number line"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing that two amounts are equal"}, {"term": "equals sign", "definition": "a symbol meaning both sides have the same value"}, {"term": "unknown", "definition": "a number that must be found"}]'::jsonb,
      'Write 7+?=12. Ask what amount must join 7 to make the whole 12.', 'Model counting on from 7 to 12 and checking with 12−7=5.', 'Encourage relational reasoning rather than guessing.',
      'In 7+?=12, the unknown is a missing addend. You can count on from 7 to 12 or use 12−7.', 'Solve missing-addend equations together.',
      'Find unknown addends independently.', 'Missing-Part Cards: cover one addend in a fact-family triangle and solve for it.',
      'Unknown Addends', 'Find the missing addend that makes each equation true.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and check one answer with subtraction.', 'Use a number line or part-part-whole model.',
      'Solve the same unknown addend using both counting on and subtraction.',
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
      'Find ?: 7 + ? = 12', null,
      '5', '7+5=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Find ?: ? + 4 = 11', null,
      '7', '7+4=11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Find ?: 9 + ? = 15', null,
      '6', '9+6=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Find ?: 6 + ? = 14', null,
      '8', '6+8=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Find ?: ? + 5 = 13', null,
      '8', '8+5=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Find ?: 8 + ? = 17', null,
      '9', '8+9=17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Find ?: ? + 7 = 16', null,
      '9', '9+7=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '4+?=10', null,
      '6', '4+6=10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '?+3=9', null,
      '6', '6+3=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '5+?=12', null,
      '7', '5+7=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '?+8=15', null,
      '7', '7+8=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '9+?=18', null,
      '9', '9+9=18.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '?+6=14', null,
      '8', '8+6=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '7+?=16', null,
      '9', '7+9=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '?+4=13', null,
      '9', '9+4=13.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 19, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W19-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W19-D4 was not found.';
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
      'The student will determine unknowns in subtraction equations within 20 when either the amount removed or the starting whole is unknown.', 'I can find a missing number in a subtraction equation.',
      '["pencil", "paper", "optional number line"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing that two amounts are equal"}, {"term": "equals sign", "definition": "a symbol meaning both sides have the same value"}, {"term": "unknown", "definition": "a number that must be found"}]'::jsonb,
      'Compare 14−?=9 with ?−5=9. Ask what is unknown in each equation.', 'Model solving 14−?=9 by asking the difference between 14 and 9, and ?−5=9 by rebuilding the whole as 9+5.', 'Keep the meaning of each position explicit.',
      'In subtraction, the unknown might be the part removed or the starting whole. Use addition/subtraction relationships to make the equation true.', 'Solve both unknown positions together.',
      'Complete mixed subtraction unknowns independently.', 'Equation Detective: identify whether the missing number is the starting whole or the part being removed before solving.',
      'Unknowns in Subtraction', 'Find the unknown number and check that the completed equation is true.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and solve both subtraction unknown positions.', 'Use part-whole diagrams or inverse addition equations.',
      'Write two different subtraction equations with the same answer but the unknown in different positions.',
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
      'Find ?: 14 − ? = 9', null,
      '5', '14−5=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Find ?: ? − 4 = 8', null,
      '12', '12−4=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Find ?: 17 − ? = 10', null,
      '7', '17−7=10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Find ?: 15 − ? = 7', null,
      '8', '15−8=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Find ?: ? − 6 = 9', null,
      '15', '15−6=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Find ?: 18 − ? = 11', null,
      '7', '18−7=11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Find ?: ? − 5 = 8', null,
      '13', '13−5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '13−?=8', null,
      '5', '13−5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '?−3=9', null,
      '12', '12−3=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '16−?=9', null,
      '7', '16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '?−7=6', null,
      '13', '13−7=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '19−?=12', null,
      '7', '19−7=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '?−8=7', null,
      '15', '15−8=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '12−?=5', null,
      '7', '12−7=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '?−4=10', null,
      '14', '14−4=10.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 19, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W19-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W19-D5 was not found.';
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
      'The student will independently demonstrate introductory equation understanding, true/false reasoning, and unknown solving before the Week 19 online check.', 'I can make an equation true by finding the unknown.',
      '["pencil", "scratch paper"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing that two amounts are equal"}, {"term": "equals sign", "definition": "a symbol meaning both sides have the same value"}, {"term": "unknown", "definition": "a number that must be found"}]'::jsonb,
      'Review the meaning of = and the possible positions of an unknown.', 'Model one neutral example, then transition to independent work.', 'Week 19 is the first of two evidence weeks for 1-MATH-11.',
      'Check both sides of the equals sign. Find the number that makes the equation true.', 'Complete three mixed warm-ups.',
      'Complete readiness work and the Week 19 online check independently.', 'Truth Check: after solving each unknown, substitute it back into the equation.',
      'Week 19 Equation Readiness', 'Find each unknown or decide whether the equation is true.',
      'Complete Week 19 readiness and online assessment independently under the configured 85% threshold.', 'Use normal accommodations without giving the missing number.',
      'Create one true equation and one almost-true equation for the instructor to classify.',
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
      'Find ?: ? + 6 = 14', null,
      '8', '8+6=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Find ?: 16 − ? = 9', null,
      '7', '16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Is 7 + 5 = 13 true or false?', null,
      'false', '7+5=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Find ?: ? − 5 = 8', null,
      '13', '13−5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Find ?: 9 + ? = 17', null,
      '8', '9+8=17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Is 6 = 10 − 4 true or false?', null,
      'true', '10−4=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Find ?: ? = 15 − 7', null,
      '8', '15−7=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '?+4=12', null,
      '8', '8+4=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '14−?=6', null,
      '8', '14−8=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '?−7=9', null,
      '16', '16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '6+?=15', null,
      '9', '6+9=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'True or false: 8=3+5.', null,
      'true', '3+5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'True or false: 9=13−5.', null,
      'false', '13−5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '?=7+8', null,
      '15', '7+8=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '?=18−6', null,
      '12', '18−6=12.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 20, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W20-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W20-D1 was not found.';
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
      'The student will solve unknowns in varied positions across addition and subtraction equations within 20.', 'I can solve for an unknown no matter where it appears.',
      '["pencil", "scratch paper"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing that two amounts are equal"}, {"term": "equals sign", "definition": "a symbol meaning both sides have the same value"}, {"term": "unknown", "definition": "a number that must be found"}]'::jsonb,
      'Display four equations with ? in four different locations and ask what changes and what stays the same.', 'Model identifying the relationship before choosing a strategy.', 'The objective is flexible equation reasoning, not memorizing a separate rule for every position.',
      'The unknown may be a result, an addend, the starting whole, or the amount removed. Make both sides of the equation have the same value.', 'Solve mixed positions together.',
      'Solve varied unknowns independently.', 'Unknown Position Sort: group equation cards by where the unknown appears, then solve them.',
      'Unknowns in Any Position', 'Find the number that makes each equation true.',
      'Complete at least 7 of 8 worksheet items correctly after corrections across multiple unknown positions.', 'Use inverse-operation reminders during guided practice.',
      'Explain which unknown position feels easiest and which requires the most reasoning.',
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
      'Find ?: ? + 6 = 14', null,
      '8', '8+6=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Find ?: 16 − ? = 9', null,
      '7', '16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Is 7 + 5 = 13 true or false?', null,
      'false', '7+5=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Find ?: ? − 5 = 8', null,
      '13', '13−5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Find ?: 9 + ? = 17', null,
      '8', '9+8=17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Is 6 = 10 − 4 true or false?', null,
      'true', '10−4=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Find ?: ? = 15 − 7', null,
      '8', '15−7=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '?+4=12', null,
      '8', '8+4=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '14−?=6', null,
      '8', '14−8=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '?−7=9', null,
      '16', '16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '6+?=15', null,
      '9', '6+9=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'True or false: 8=3+5.', null,
      'true', '3+5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'True or false: 9=13−5.', null,
      'false', '13−5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '?=7+8', null,
      '15', '7+8=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '?=18−6', null,
      '12', '18−6=12.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 20, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W20-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W20-D2 was not found.';
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
      'The student will use addition/subtraction inverse relationships to solve and check unknown equations within 20.', 'I can use the opposite operation to find or check an unknown.',
      '["pencil", "paper"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing that two amounts are equal"}, {"term": "equals sign", "definition": "a symbol meaning both sides have the same value"}, {"term": "unknown", "definition": "a number that must be found"}, {"term": "inverse", "definition": "an operation relationship that can undo another operation"}]'::jsonb,
      'Use 7+?=13. Show how 13−7 finds the missing addend. Then use ?−5=9 and show how 9+5 rebuilds the unknown whole.', 'Model solving and then checking by substitution.', 'Connect this lesson directly to Week 15 relationship work.',
      'Inverse operations can help solve unknowns:
7+?=13 → 13−7=6
?−5=9 → 9+5=14', 'Write inverse equations together.',
      'Solve and check unknown equations independently.', 'Inverse Pair: for each unknown equation, write the related equation that finds the unknown.',
      'Use Inverse Operations for Unknowns', 'Write a helpful related equation, find the unknown, and check it.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and use an inverse equation correctly at least twice.', 'Provide a fact-family/parts-whole organizer.',
      'Find two different ways to solve one unknown equation.',
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
      'Find ?: ? + 6 = 14', null,
      '8', '8+6=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Find ?: 16 − ? = 9', null,
      '7', '16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Is 7 + 5 = 13 true or false?', null,
      'false', '7+5=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Find ?: ? − 5 = 8', null,
      '13', '13−5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Find ?: 9 + ? = 17', null,
      '8', '9+8=17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Is 6 = 10 − 4 true or false?', null,
      'true', '10−4=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Find ?: ? = 15 − 7', null,
      '8', '15−7=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '?+4=12', null,
      '8', '8+4=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '14−?=6', null,
      '8', '14−8=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '?−7=9', null,
      '16', '16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '6+?=15', null,
      '9', '6+9=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'True or false: 8=3+5.', null,
      'true', '3+5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'True or false: 9=13−5.', null,
      'false', '13−5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '?=7+8', null,
      '15', '7+8=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '?=18−6', null,
      '12', '18−6=12.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 20, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W20-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W20-D3 was not found.';
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
      'The student will evaluate true/false equations with expressions on either side of the equals sign and correct false equations.', 'I can check whether an equation is balanced and fix it if it is not.',
      '["pencil", "paper"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing that two amounts are equal"}, {"term": "equals sign", "definition": "a symbol meaning both sides have the same value"}, {"term": "unknown", "definition": "a number that must be found"}]'::jsonb,
      'Write 8=5+3 and 9=5+3. Ask which is balanced and why.', 'Model evaluating both sides, then changing one number to repair a false equation.', 'Equality reasoning should remain central; do not reduce this to scanning the right side for an answer.',
      'A true equation has the same value on both sides. If it is false, compare the values to see what must change.', 'Evaluate and repair examples together.',
      'Classify and correct equations independently.', 'Repair Shop: receive a false equation card and make the smallest number change needed to make it true.',
      'True, False, and Fix It', 'Decide whether each equation is true. If false, explain the correct value.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and accurately explain why one false equation is false.', 'Use a balance drawing when useful.',
      'Write a false equation that differs from a true one by exactly 1.',
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
      'Is 5 + 3 = 8 true or false?', null,
      'true', 'Both sides have value 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Is 6 + 2 = 7 true or false?', null,
      'false', '6+2=8, not 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Which statement is true: 4+5=9 or 4+5=8?', null,
      '4+5=9', 'Both sides of 4+5=9 have value 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Is 9 − 4 = 5 true or false?', null,
      'true', '9−4=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Is 10 − 3 = 8 true or false?', null,
      'false', '10−3=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Is 7 = 3 + 4 true or false?', null,
      'true', '3+4 has value 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Is 6 = 8 − 2 true or false?', null,
      'true', '8−2 has value 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'True or false: 2+6=8.', null,
      'true', '2+6=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'True or false: 5+5=9.', null,
      'false', '5+5=10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'True or false: 7=10−3.', null,
      'true', '10−3=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'True or false: 4=9−4.', null,
      'false', '9−4=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'True or false: 8=3+5.', null,
      'true', '3+5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'True or false: 12−4=8.', null,
      'true', '12−4=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'True or false: 6+7=12.', null,
      'false', '6+7=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'True or false: 15−6=9.', null,
      'true', '15−6=9.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 20, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W20-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W20-D4 was not found.';
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
      'The student will explain the meaning of equality and the reasoning used to determine an unknown in an equation within 20.', 'I can explain why my unknown makes an equation true.',
      '["pencil", "paper"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing that two amounts are equal"}, {"term": "equals sign", "definition": "a symbol meaning both sides have the same value"}, {"term": "unknown", "definition": "a number that must be found"}, {"term": "justify", "definition": "give a mathematical reason showing why an answer works"}]'::jsonb,
      'Tell the student that solving an unknown is not finished until the completed equation can be checked.', 'Model substituting an answer into 7+?=12 and explaining that 7+5 and 12 have the same value.', 'Accept oral explanations, drawings, or equations. A separate hands-on balance demonstration is not required for mastery.',
      'To explain an unknown, replace ? with your answer and show that the two sides are equal.', 'Solve and explain three examples.',
      'Complete unknowns independently and justify selected answers.', 'Prove It: choose one completed equation and show its truth using a related fact or both-side evaluation.',
      'Explain Equation Reasoning', 'Find each unknown and explain why at least one answer makes the equation true.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and provide one accurate equality explanation.', 'Allow oral explanation or a drawing instead of a full written sentence.',
      'Find an unknown and prove it using two different checks.',
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
      'Find ?: ? + 6 = 14', null,
      '8', '8+6=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Find ?: 16 − ? = 9', null,
      '7', '16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Is 7 + 5 = 13 true or false?', null,
      'false', '7+5=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Find ?: ? − 5 = 8', null,
      '13', '13−5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Find ?: 9 + ? = 17', null,
      '8', '9+8=17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Is 6 = 10 − 4 true or false?', null,
      'true', '10−4=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Find ?: ? = 15 − 7', null,
      '8', '15−7=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '?+4=12', null,
      '8', '8+4=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '14−?=6', null,
      '8', '14−8=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '?−7=9', null,
      '16', '16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '6+?=15', null,
      '9', '6+9=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'True or false: 8=3+5.', null,
      'true', '3+5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'True or false: 9=13−5.', null,
      'false', '13−5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '?=7+8', null,
      '15', '7+8=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '?=18−6', null,
      '12', '18−6=12.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 20, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W20-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W20-D5 was not found.';
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
      'The student will independently demonstrate the full 1-MATH-11 objective across unknown positions, true/false equations, and equality explanation.', 'I can solve unknown equations and explain what the equals sign means.',
      '["pencil", "scratch paper"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing that two amounts are equal"}, {"term": "equals sign", "definition": "a symbol meaning both sides have the same value"}, {"term": "unknown", "definition": "a number that must be found"}]'::jsonb,
      'Ask the student to explain = in their own words and name different places an unknown can appear.', 'Model one neutral equation only.', 'Week 20 provides a second independent assessment opportunity for 1-MATH-11. Repeated qualifying evidence may establish mastery without a separate hands-on requirement.',
      'Make both sides equal. Use related addition/subtraction facts when they help, and check your answer by putting it back into the equation.', 'Complete three brief warm-ups.',
      'Complete readiness and the Week 20 online assessment independently.', 'After the check, choose one unknown problem and write its inverse relationship.',
      'Week 20 Equations Mastery Readiness', 'Find unknowns, evaluate equations, and think about equality.',
      'Complete Week 20 readiness and online assessment independently using the configured 85% repeated-evidence rules.', 'Use normal accommodations without identifying the unknown value.',
      'Create an equation puzzle with the unknown in an unusual position.',
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
      'Find ?: ? + 6 = 14', null,
      '8', '8+6=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Find ?: 16 − ? = 9', null,
      '7', '16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Is 7 + 5 = 13 true or false?', null,
      'false', '7+5=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Find ?: ? − 5 = 8', null,
      '13', '13−5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Find ?: 9 + ? = 17', null,
      '8', '9+8=17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Is 6 = 10 − 4 true or false?', null,
      'true', '10−4=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Find ?: ? = 15 − 7', null,
      '8', '15−7=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '?+4=12', null,
      '8', '8+4=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '14−?=6', null,
      '8', '14−8=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '?−7=9', null,
      '16', '16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '6+?=15', null,
      '9', '6+9=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'True or false: 8=3+5.', null,
      'true', '3+5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'True or false: 9=13−5.', null,
      'false', '13−5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '?=7+8', null,
      '15', '7+8=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '?=18−6', null,
      '12', '18−6=12.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 21, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W21-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W21-D1 was not found.';
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
      'The student will understand length measurement as iterating equal-size units end to end and counting the units that cover an object''s length.', 'I can measure length by repeating equal-size units.',
      '["pencil", "paper", "optional equal-size cubes, tiles, or paper clips for practice"]'::jsonb, '[{"term": "length", "definition": "how long something is from one end to the other"}, {"term": "unit", "definition": "an equal-size piece used repeatedly to measure"}, {"term": "end to end", "definition": "units touch without gaps or overlaps"}]'::jsonb,
      'Show or describe an object covered by six identical cubes. Ask what is being counted and why the cubes must be the same size.', 'Model placing equal units from one end to the other with no gaps or overlaps, then reporting the count with the unit.', 'Practical measuring is encouraged instructionally, but mastery can be established through repeated qualifying written/online evidence; do not require a separate hands-on evidence type.',
      'To measure length with repeated units:
1. Start at one end.
2. Use units that are the same size.
3. Place them end to end.
4. Count the units.
5. Say the number and unit.', 'Interpret three model measurements together.',
      'Complete visual/text measurement items independently.', 'Optional Measure It: use identical paper clips or blocks to measure a book or pencil, then record the number and unit.',
      'Equal Units Measure Length', 'Count the equal units and report the measurement with the unit name.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and explain why equal-size units matter.', 'Use large, clearly separated unit diagrams and read directions aloud if needed.',
      'Predict how the count would change if the measuring unit became smaller.',
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
      'A strip is covered exactly by 6 same-size cubes placed end to end. What is its length?', null,
      '6 cubes', 'Six equal units cover the strip.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'A row uses 5 same-size paper clips with no gaps. What is the measurement?', null,
      '5 paper clips', 'Count the equal units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Why should measuring units be the same size?', null,
      'so each counted unit represents the same amount', 'Equal units make the count a consistent measurement.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'A pencil picture is covered by 7 equal squares end to end. Length?', null,
      '7 squares', 'Seven equal units cover it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'A ribbon picture spans 9 equal tiles. Length?', null,
      '9 tiles', 'Count the tiles.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Is a measurement reliable if some units are large and some are small?', null,
      'no', 'Different-size units do not represent equal amounts.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Should measuring units overlap?', null,
      'no', 'Overlaps count the same space more than once.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'A line spans 4 equal cubes. Length?', null,
      '4 cubes', 'Count four equal units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'A line spans 8 equal squares. Length?', null,
      '8 squares', 'Eight squares cover it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'A card spans 10 equal tiles. Length?', null,
      '10 tiles', 'Ten equal units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'True or false: gaps between units can make a measurement inaccurate.', null,
      'true', 'Gaps leave unmeasured space.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'True or false: overlaps can make a measurement inaccurate.', null,
      'true', 'Overlaps count space more than once.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Which is better for one measurement: equal-size units or mixed-size units?', null,
      'equal-size units', 'Equal units represent consistent lengths.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'If 6 equal clips cover an object exactly, what number do you report?', null,
      '6', 'The count is six units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'What should be included with the number 7 when reporting a measurement?', null,
      'the unit name', 'A measurement should state both number and unit.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 21, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W21-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W21-D2 was not found.';
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
      'The student will identify and correct measurement arrangements with gaps, overlaps, or incorrect starting/ending positions.', 'I can tell whether measuring units are placed correctly.',
      '["pencil", "paper", "optional equal-size objects for demonstration"]'::jsonb, '[{"term": "length", "definition": "how long something is from one end to the other"}, {"term": "unit", "definition": "an equal-size piece used repeatedly to measure"}, {"term": "end to end", "definition": "units touch without gaps or overlaps"}]'::jsonb,
      'Compare three arrangements: correct end-to-end units, units with a gap, and units that overlap.', 'Model explaining why a gap leaves length unmeasured and an overlap counts length more than once.', 'Accuracy depends on arrangement as well as counting.',
      'A correct measurement covers the length once—no missing spaces and no space counted twice.', 'Classify measurement setups together.',
      'Identify correct and incorrect arrangements independently.', 'Fix the Setup: describe how you would reposition units in an incorrect measurement.',
      'No Gaps, No Overlaps', 'Decide whether each measurement setup is correct and explain why.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and accurately explain one gap and one overlap error.', 'Use color coding to show uncovered and double-covered spaces.',
      'Create a deliberately incorrect measuring arrangement and explain how to repair it.',
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
      'Four equal tiles are placed with spaces between them along a strip. Is the setup correct?', null,
      'no', 'The units must touch end to end.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Six equal cubes overlap one another while measuring. Is the setup correct?', null,
      'no', 'Overlaps double-count some length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Eight equal squares touch end to end from one edge to the other. Is the setup correct?', null,
      'yes', 'There are no gaps or overlaps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Should the first unit begin at the object''s starting edge?', null,
      'yes', 'Measurement begins at one end.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Should the final unit reach the object''s ending edge?', null,
      'yes', 'The units should cover the entire length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'If there is a gap after unit 3, is the count alone enough?', null,
      'no', 'The uncovered space makes the measurement inaccurate.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'If units overlap, should the student reposition them?', null,
      'yes', 'Units should be laid end to end.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Correct or incorrect: 5 equal tiles with no gaps.', null,
      'correct', 'This is a valid arrangement.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Correct or incorrect: 5 equal tiles with a gap between tiles 2 and 3.', null,
      'incorrect', 'There is unmeasured space.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Correct or incorrect: 6 equal cubes where cube 4 overlaps cube 3.', null,
      'incorrect', 'Some space is counted twice.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Correct or incorrect: equal clips start at the left edge and touch end to end.', null,
      'correct', 'The setup follows measurement rules.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Why do gaps cause a problem?', null,
      'some length is not measured', 'Gaps skip part of the object.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Why do overlaps cause a problem?', null,
      'some length is counted more than once', 'Overlap double-counts space.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Where should the first unit start?', null,
      'at one end of the object', 'Begin at the object''s edge.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Where should the last unit end?', null,
      'at the other end of the object', 'Cover the full length.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 21, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W21-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W21-D3 was not found.';
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
      'The student will report a length measurement as a number paired with the repeated unit used.', 'I can report both the measurement number and its unit.',
      '["pencil", "paper"]'::jsonb, '[{"term": "length", "definition": "how long something is from one end to the other"}, {"term": "unit", "definition": "an equal-size piece used repeatedly to measure"}, {"term": "end to end", "definition": "units touch without gaps or overlaps"}]'::jsonb,
      'Write ''7'' and ''7 tiles.'' Ask which communicates a complete measurement and why.', 'Model counting units and writing the measurement with the unit name.', 'Keep vocabulary simple: number tells how many units; unit tells what repeated length was counted.',
      'A measurement needs both parts:
number + unit
Example: 8 cubes.', 'Report measurements together.',
      'Write complete measurements independently.', 'Measurement Label Match: pair number cards with the unit names used in sample measurements.',
      'Report the Measurement', 'Write the number of units and the unit name.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and consistently include the unit name.', 'Provide sentence frames such as ''The length is __ __.''',
      'Explain why ''10'' by itself is not enough information for a length measurement.',
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
      'A book picture spans 9 equal cubes. Report the measurement.', null,
      '9 cubes', 'State the number and unit.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'A strip spans 12 equal squares. Report the measurement.', null,
      '12 squares', 'State 12 and the unit squares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Which is a complete measurement: ''7'' or ''7 tiles''?', null,
      '7 tiles', 'A measurement needs the unit name.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'A card spans 6 equal clips. Report the measurement.', null,
      '6 clips', 'Number plus unit.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'A line spans 10 equal blocks. Report the measurement.', null,
      '10 blocks', 'Number plus unit.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'If the same object is 8 cubes long, what does 8 describe?', null,
      'the number of cube units', 'The number counts units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'If a measurement says 5 paper clips, what is the unit?', null,
      'paper clips', 'Paper clips are the repeated unit.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Object spans 4 tiles. Complete: The length is __ tiles.', null,
      '4', 'Four tiles.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Object spans 7 cubes. Complete: The length is __ cubes.', null,
      '7', 'Seven cubes.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Object spans 11 squares. Complete the measurement.', null,
      '11 squares', 'Number plus unit.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Object spans 5 clips. Complete the measurement.', null,
      '5 clips', 'Number plus unit.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Which is more complete: 9 or 9 blocks?', null,
      '9 blocks', 'The unit identifies what was counted.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'A strip measures 6 tiles. What number was counted?', null,
      '6', 'Six repeated units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'A strip measures 6 tiles. What unit was used?', null,
      'tiles', 'Tiles are the unit.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why name the unit?', null,
      'the number alone does not tell what size unit was used', 'The unit gives meaning to the count.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 21, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W21-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W21-D4 was not found.';
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
      'The student will apply equal-unit measurement rules to varied examples and explain why equal units, end-to-end placement, and unit labels are necessary.', 'I can use all the rules for measuring length with repeated units.',
      '["pencil", "paper", "optional household objects and equal-size units"]'::jsonb, '[{"term": "length", "definition": "how long something is from one end to the other"}, {"term": "unit", "definition": "an equal-size piece used repeatedly to measure"}, {"term": "end to end", "definition": "units touch without gaps or overlaps"}]'::jsonb,
      'Review the complete measurement checklist.', 'Model evaluating one measurement from start position through final label.', 'This lesson integrates procedure and reasoning rather than adding a new measurement concept.',
      'Measurement checklist:
• start at one end
• equal-size units
• no gaps
• no overlaps
• cover to the other end
• count units
• name the unit', 'Apply the checklist together.',
      'Complete mixed measurement reasoning independently.', 'Optional Home Measurement: choose one object and measure it with identical clips, cubes, or homemade paper units. Record the result.',
      'Measure Carefully', 'Apply the measurement checklist to each example.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and explain at least two measurement rules.', 'Use the checklist as a visual support.',
      'Design a short ''measurement mistake'' puzzle for someone else to diagnose.',
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
      'A marker is exactly 8 equal cube units long. What is the measurement?', null,
      '8 cubes', 'Eight equal units cover it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'A card is exactly 6 equal tile units long. What is the measurement?', null,
      '6 tiles', 'Six equal units cover it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'A strip uses 7 equal units but has one visible gap. Is 7 a valid measurement yet?', null,
      'no', 'The gap must be removed before counting the measurement.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'An object is covered by 10 equal squares with no gaps. Length?', null,
      '10 squares', 'Count the units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'An object is covered by 5 equal clips with overlap. Is the setup valid?', null,
      'no', 'Overlap makes the arrangement invalid.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Why should units be equal in size?', null,
      'to make each counted unit represent the same length', 'Equal units make the measure consistent.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'A line is 9 blocks long. What must be reported with 9?', null,
      'blocks', 'The unit name belongs with the number.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Seven equal cubes cover a strip exactly. Measurement?', null,
      '7 cubes', 'Seven cube units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Twelve equal squares cover a picture. Measurement?', null,
      '12 squares', 'Twelve square units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Five clips have gaps. Valid setup?', null,
      'no', 'Gaps skip length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Eight cubes overlap. Valid setup?', null,
      'no', 'Overlaps double-count length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Nine tiles touch end to end. Valid setup?', null,
      'yes', 'No gaps or overlaps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Where should measuring begin?', null,
      'at one end of the object', 'Start at the edge.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'What makes a measurement complete?', null,
      'a number and unit', 'Both are needed.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why use equal-size units?', null,
      'so every counted unit represents the same amount of length', 'Consistency makes measurement meaningful.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 21, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W21-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W21-D5 was not found.';
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
      'The student will independently demonstrate introductory repeated-unit length measurement before the Week 21 online check.', 'I can measure length with equal units and explain the measurement rules.',
      '["pencil", "scratch paper"]'::jsonb, '[{"term": "length", "definition": "how long something is from one end to the other"}, {"term": "unit", "definition": "an equal-size piece used repeatedly to measure"}, {"term": "end to end", "definition": "units touch without gaps or overlaps"}]'::jsonb,
      'Review the measurement checklist without solving assessment items.', 'Model one neutral example, then remove support.', 'Week 21 is the first of two evidence weeks for 1-MATH-12. A separate hands-on mastery requirement is not imposed.',
      'Count equal-size units placed end to end, check for gaps or overlaps, and report the number with its unit.', 'Complete three brief warm-ups.',
      'Complete readiness and the Week 21 online assessment independently.', 'Rule Reflection: choose one measurement rule and explain what error it prevents.',
      'Week 21 Measurement Readiness', 'Use equal-unit measurement rules to answer each item.',
      'Complete Week 21 readiness and online assessment independently under the configured 85% threshold.', 'Use normal accommodations without supplying the unit count or measurement rule.',
      'Predict two different unit counts the same object might have with two different-size units.',
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
      'A marker is exactly 8 equal cube units long. What is the measurement?', null,
      '8 cubes', 'Eight equal units cover it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'A card is exactly 6 equal tile units long. What is the measurement?', null,
      '6 tiles', 'Six equal units cover it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'A strip uses 7 equal units but has one visible gap. Is 7 a valid measurement yet?', null,
      'no', 'The gap must be removed before counting the measurement.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'An object is covered by 10 equal squares with no gaps. Length?', null,
      '10 squares', 'Count the units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'An object is covered by 5 equal clips with overlap. Is the setup valid?', null,
      'no', 'Overlap makes the arrangement invalid.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Why should units be equal in size?', null,
      'to make each counted unit represent the same length', 'Equal units make the measure consistent.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'A line is 9 blocks long. What must be reported with 9?', null,
      'blocks', 'The unit name belongs with the number.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Seven equal cubes cover a strip exactly. Measurement?', null,
      '7 cubes', 'Seven cube units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Twelve equal squares cover a picture. Measurement?', null,
      '12 squares', 'Twelve square units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Five clips have gaps. Valid setup?', null,
      'no', 'Gaps skip length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Eight cubes overlap. Valid setup?', null,
      'no', 'Overlaps double-count length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Nine tiles touch end to end. Valid setup?', null,
      'yes', 'No gaps or overlaps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Where should measuring begin?', null,
      'at one end of the object', 'Start at the edge.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'What makes a measurement complete?', null,
      'a number and unit', 'Both are needed.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why use equal-size units?', null,
      'so every counted unit represents the same amount of length', 'Consistency makes measurement meaningful.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 22, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W22-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W22-D1 was not found.';
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
      'The student will deepen repeated-unit measurement by measuring or interpreting lengths using consistent unit placement from endpoint to endpoint.', 'I can measure carefully from one end to the other.',
      '["pencil", "paper", "optional equal-size units and household objects"]'::jsonb, '[{"term": "length", "definition": "how long something is from one end to the other"}, {"term": "unit", "definition": "an equal-size piece used repeatedly to measure"}, {"term": "end to end", "definition": "units touch without gaps or overlaps"}]'::jsonb,
      'Ask the student to state the measurement checklist from memory.', 'Model a longer measurement and verify each rule in order.', 'The second week should emphasize independent setup and explanation rather than merely counting more units.',
      'A trustworthy length measurement depends on both the unit count and how the units were placed.', 'Verify measurement arrangements together.',
      'Interpret measurements independently.', 'Optional Measurement Lab: independently measure two objects using the same repeated unit and record each number and unit.',
      'Endpoint-to-Endpoint Measurement', 'Check the setup, count the units, and report the measurement.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and independently apply the full measurement checklist.', 'Provide a printed checklist without worked answers.',
      'Explain which measurement error would make a result too large and which could make it too small.',
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
      'A marker is exactly 8 equal cube units long. What is the measurement?', null,
      '8 cubes', 'Eight equal units cover it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'A card is exactly 6 equal tile units long. What is the measurement?', null,
      '6 tiles', 'Six equal units cover it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'A strip uses 7 equal units but has one visible gap. Is 7 a valid measurement yet?', null,
      'no', 'The gap must be removed before counting the measurement.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'An object is covered by 10 equal squares with no gaps. Length?', null,
      '10 squares', 'Count the units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'An object is covered by 5 equal clips with overlap. Is the setup valid?', null,
      'no', 'Overlap makes the arrangement invalid.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Why should units be equal in size?', null,
      'to make each counted unit represent the same length', 'Equal units make the measure consistent.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'A line is 9 blocks long. What must be reported with 9?', null,
      'blocks', 'The unit name belongs with the number.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Seven equal cubes cover a strip exactly. Measurement?', null,
      '7 cubes', 'Seven cube units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Twelve equal squares cover a picture. Measurement?', null,
      '12 squares', 'Twelve square units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Five clips have gaps. Valid setup?', null,
      'no', 'Gaps skip length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Eight cubes overlap. Valid setup?', null,
      'no', 'Overlaps double-count length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Nine tiles touch end to end. Valid setup?', null,
      'yes', 'No gaps or overlaps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Where should measuring begin?', null,
      'at one end of the object', 'Start at the edge.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'What makes a measurement complete?', null,
      'a number and unit', 'Both are needed.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why use equal-size units?', null,
      'so every counted unit represents the same amount of length', 'Consistency makes measurement meaningful.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 22, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W22-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W22-D2 was not found.';
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
      'The student will explain how changing the size of a repeated measurement unit changes the numerical count for the same object.', 'I can explain why the same object can have different measurement numbers with different units.',
      '["pencil", "paper", "optional large and small equal-size units"]'::jsonb, '[{"term": "length", "definition": "how long something is from one end to the other"}, {"term": "unit", "definition": "an equal-size piece used repeatedly to measure"}, {"term": "end to end", "definition": "units touch without gaps or overlaps"}, {"term": "unit size", "definition": "the length of one repeated measuring unit"}]'::jsonb,
      'Describe the same strip measured by six large blocks and twelve small blocks. Ask whether the strip changed.', 'Model the inverse relationship: smaller units require more units; larger units require fewer units for the same length.', 'This is conceptual measurement reasoning; do not treat unlike unit counts as directly comparable without knowing the units.',
      'The object can stay the same length while the measurement number changes because the unit changed.', 'Compare large-unit and small-unit measurements together.',
      'Reason about unit size independently.', 'Unit Swap: predict whether the count will rise or fall when replacing a large measuring unit with a smaller one.',
      'How Unit Size Changes the Count', 'Reason about the same length measured with different unit sizes.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and explain why smaller units usually produce a larger count.', 'Use simple drawings of large versus small repeated units.',
      'Explain why ''12 is longer than 6'' is not necessarily true when the units differ.',
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
      'The same strip measures 6 large blocks or 12 small blocks. Which unit is smaller?', null,
      'small blocks', 'More small units are needed to cover the same length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'The same card measures 5 long clips or 10 short clips. Which unit is longer?', null,
      'long clips', 'Fewer longer units cover the same object.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Can the same object have different measurement numbers when different unit sizes are used?', null,
      'yes', 'The number depends on unit size.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'An object is 4 large tiles or 8 small tiles long. Which measurement uses smaller units?', null,
      '8 small tiles', 'Smaller units require a larger count.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'If equal unit size changes, can the numeric measurement change?', null,
      'yes', 'Different-size units produce different counts.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'For the same object, which usually gives a larger count: smaller units or larger units?', null,
      'smaller units', 'More small units fit along the same length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Does a different numeric count automatically mean the object''s length changed?', null,
      'no', 'The unit may have changed.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Same strip: 3 big blocks or 9 small blocks. Which units are smaller?', null,
      'small blocks', 'Nine smaller units fit where three big units fit.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Same strip: 4 long clips or 8 short clips. Which units are longer?', null,
      'long clips', 'Fewer long clips are needed.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Same object measures 5 tiles and 10 cubes. Can both be correct?', null,
      'yes', 'They may use different-size units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Which likely gives a bigger number for the same length: tiny units or large units?', null,
      'tiny units', 'More tiny units are needed.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'If an object is 6 large units and 12 small units long, did the object change length?', null,
      'no', 'Only the unit size changed.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'What must stay the same within one measurement?', null,
      'the size of the repeated unit', 'All units in one measurement must be equal-size.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Can you compare 6 cubes and 6 clips without knowing their sizes?', null,
      'not reliably', 'Different unit types may have different lengths.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why state the unit name?', null,
      'because the number depends on the unit used', 'The unit makes the measurement interpretable.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 22, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W22-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W22-D3 was not found.';
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
      'The student will identify invalid measurement results caused by mixed unit sizes, gaps, overlaps, or missing unit labels and explain how to correct them.', 'I can find and fix mistakes in a length measurement.',
      '["pencil", "paper"]'::jsonb, '[{"term": "length", "definition": "how long something is from one end to the other"}, {"term": "unit", "definition": "an equal-size piece used repeatedly to measure"}, {"term": "end to end", "definition": "units touch without gaps or overlaps"}]'::jsonb,
      'Present a measurement with one mistake and ask the student to diagnose it before recounting.', 'Model a systematic error check: unit size, start, gaps, overlaps, endpoint, label.', 'Error analysis strengthens the competency''s explanation requirement.',
      'When a measurement looks wrong, check the setup before checking the arithmetic.', 'Diagnose measurement mistakes together.',
      'Find and explain mistakes independently.', 'Measurement Inspector: label each sample Valid or Fix Needed and state the reason.',
      'Find the Measurement Mistake', 'Decide whether each setup is valid and explain how to correct invalid examples.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and diagnose at least three kinds of measurement error.', 'Use a checklist and visual highlighting.',
      'Design a measurement example containing exactly two errors.',
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
      'Four equal tiles are placed with spaces between them along a strip. Is the setup correct?', null,
      'no', 'The units must touch end to end.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Six equal cubes overlap one another while measuring. Is the setup correct?', null,
      'no', 'Overlaps double-count some length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Eight equal squares touch end to end from one edge to the other. Is the setup correct?', null,
      'yes', 'There are no gaps or overlaps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Should the first unit begin at the object''s starting edge?', null,
      'yes', 'Measurement begins at one end.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Should the final unit reach the object''s ending edge?', null,
      'yes', 'The units should cover the entire length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'If there is a gap after unit 3, is the count alone enough?', null,
      'no', 'The uncovered space makes the measurement inaccurate.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'If units overlap, should the student reposition them?', null,
      'yes', 'Units should be laid end to end.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Correct or incorrect: 5 equal tiles with no gaps.', null,
      'correct', 'This is a valid arrangement.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Correct or incorrect: 5 equal tiles with a gap between tiles 2 and 3.', null,
      'incorrect', 'There is unmeasured space.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Correct or incorrect: 6 equal cubes where cube 4 overlaps cube 3.', null,
      'incorrect', 'Some space is counted twice.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Correct or incorrect: equal clips start at the left edge and touch end to end.', null,
      'correct', 'The setup follows measurement rules.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Why do gaps cause a problem?', null,
      'some length is not measured', 'Gaps skip part of the object.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Why do overlaps cause a problem?', null,
      'some length is counted more than once', 'Overlap double-counts space.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Where should the first unit start?', null,
      'at one end of the object', 'Begin at the object''s edge.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Where should the last unit end?', null,
      'at the other end of the object', 'Cover the full length.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 22, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W22-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W22-D4 was not found.';
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
      'The student will explain and apply the full repeated-unit measurement process, including equal units, endpoint alignment, no gaps/overlaps, counting, and unit reporting.', 'I can explain how to make a reliable length measurement.',
      '["pencil", "paper", "optional equal-size units"]'::jsonb, '[{"term": "length", "definition": "how long something is from one end to the other"}, {"term": "unit", "definition": "an equal-size piece used repeatedly to measure"}, {"term": "end to end", "definition": "units touch without gaps or overlaps"}]'::jsonb,
      'Ask the student to teach the measuring process from beginning to end.', 'Model a concise explanation using a sample row of equal units.', 'Accept written, oral, or diagram-based explanations. Separate physical performance evidence is not required for mastery.',
      'A reliable measurement is a process: choose equal units, cover the length once from end to end, count, and name the unit.', 'Explain one complete measurement together.',
      'Complete measurement reasoning independently.', 'Teach Back: explain to the instructor how to measure a pencil with identical cubes without making a gap or overlap error.',
      'Explain a Reliable Measurement', 'Answer the measurement questions and explain why the method is reliable.',
      'Complete at least 7 of 8 worksheet items correctly after corrections and provide one complete measurement explanation.', 'Allow oral explanation or a labeled diagram.',
      'Explain what could go wrong if every measurement rule except equal unit size were followed.',
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
      'A marker is exactly 8 equal cube units long. What is the measurement?', null,
      '8 cubes', 'Eight equal units cover it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'A card is exactly 6 equal tile units long. What is the measurement?', null,
      '6 tiles', 'Six equal units cover it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'A strip uses 7 equal units but has one visible gap. Is 7 a valid measurement yet?', null,
      'no', 'The gap must be removed before counting the measurement.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'An object is covered by 10 equal squares with no gaps. Length?', null,
      '10 squares', 'Count the units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'An object is covered by 5 equal clips with overlap. Is the setup valid?', null,
      'no', 'Overlap makes the arrangement invalid.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Why should units be equal in size?', null,
      'to make each counted unit represent the same length', 'Equal units make the measure consistent.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'A line is 9 blocks long. What must be reported with 9?', null,
      'blocks', 'The unit name belongs with the number.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Seven equal cubes cover a strip exactly. Measurement?', null,
      '7 cubes', 'Seven cube units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Twelve equal squares cover a picture. Measurement?', null,
      '12 squares', 'Twelve square units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Five clips have gaps. Valid setup?', null,
      'no', 'Gaps skip length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Eight cubes overlap. Valid setup?', null,
      'no', 'Overlaps double-count length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Nine tiles touch end to end. Valid setup?', null,
      'yes', 'No gaps or overlaps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Where should measuring begin?', null,
      'at one end of the object', 'Start at the edge.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'What makes a measurement complete?', null,
      'a number and unit', 'Both are needed.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why use equal-size units?', null,
      'so every counted unit represents the same amount of length', 'Consistency makes measurement meaningful.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 22, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W22-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W22-D5 was not found.';
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
      'The student will independently demonstrate the full 1-MATH-12 repeated-unit length measurement objective before the Week 22 online check.', 'I can measure and explain length using equal repeated units.',
      '["pencil", "scratch paper"]'::jsonb, '[{"term": "length", "definition": "how long something is from one end to the other"}, {"term": "unit", "definition": "an equal-size piece used repeatedly to measure"}, {"term": "end to end", "definition": "units touch without gaps or overlaps"}]'::jsonb,
      'Ask the student to state why equal units, no gaps, no overlaps, and unit labels matter.', 'Model one neutral example only.', 'Week 22 supplies a second independent assessment opportunity for 1-MATH-12. Repeated qualifying evidence may establish mastery without a separate hands-on evidence requirement.',
      'Use the complete measurement process and explain the reasoning behind it.', 'Complete three brief warm-ups.',
      'Complete readiness and the Week 22 online assessment independently.', 'Measurement Reflection: explain why an answer such as ''8'' is incomplete until the unit is named.',
      'Week 22 Measurement Mastery Readiness', 'Apply all repeated-unit measurement rules.',
      'Complete Week 22 readiness and online assessment independently using the configured 85% repeated-evidence rules.', 'Use normal accommodations without giving the unit count or reasoning.',
      'Compare two hypothetical measurements of the same object made with different-size units and explain both.',
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
      'A marker is exactly 8 equal cube units long. What is the measurement?', null,
      '8 cubes', 'Eight equal units cover it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'A card is exactly 6 equal tile units long. What is the measurement?', null,
      '6 tiles', 'Six equal units cover it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'A strip uses 7 equal units but has one visible gap. Is 7 a valid measurement yet?', null,
      'no', 'The gap must be removed before counting the measurement.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'An object is covered by 10 equal squares with no gaps. Length?', null,
      '10 squares', 'Count the units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'An object is covered by 5 equal clips with overlap. Is the setup valid?', null,
      'no', 'Overlap makes the arrangement invalid.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Why should units be equal in size?', null,
      'to make each counted unit represent the same length', 'Equal units make the measure consistent.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'A line is 9 blocks long. What must be reported with 9?', null,
      'blocks', 'The unit name belongs with the number.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Seven equal cubes cover a strip exactly. Measurement?', null,
      '7 cubes', 'Seven cube units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Twelve equal squares cover a picture. Measurement?', null,
      '12 squares', 'Twelve square units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Five clips have gaps. Valid setup?', null,
      'no', 'Gaps skip length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Eight cubes overlap. Valid setup?', null,
      'no', 'Overlaps double-count length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Nine tiles touch end to end. Valid setup?', null,
      'yes', 'No gaps or overlaps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Where should measuring begin?', null,
      'at one end of the object', 'Start at the edge.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'What makes a measurement complete?', null,
      'a number and unit', 'Both are needed.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why use equal-size units?', null,
      'so every counted unit represents the same amount of length', 'Consistency makes measurement meaningful.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 18 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 18
      and l.week_number = 18
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W18-Q01', 1, 'short_answer', 'Solve 8 + 7.', '[]'::jsonb, '15', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W18-Q02', 2, 'short_answer', 'Solve 16 − 9.', '[]'::jsonb, '7', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W18-Q03', 3, 'short_answer', 'Solve 4 + 5.', '[]'::jsonb, '9', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W18-Q04', 4, 'short_answer', 'Solve 9 − 6.', '[]'::jsonb, '3', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W18-Q05', 5, 'multiple_choice', 'Which subtraction fact belongs with 3 + 5 = 8?', '[{"id": "a", "label": "8 − 3 = 5"}, {"id": "b", "label": "8 − 3 = 6"}, {"id": "c", "label": "5 − 3 = 8"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W18-Q06', 6, 'multiple_choice', 'Which addition fact checks 10 − 7 = 3?', '[{"id": "a", "label": "3 + 7 = 10"}, {"id": "b", "label": "10 + 7 = 17"}, {"id": "c", "label": "7 + 10 = 17"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W18-Q07', 7, 'short_answer', 'Mia has 7 stickers and gets 6 more. How many stickers?', '[]'::jsonb, '13', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W18-Q08', 8, 'short_answer', 'There are 15 balloons and 6 pop. How many remain?', '[]'::jsonb, '9', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W18-Q09', 9, 'short_answer', 'There are 6 red blocks and 8 blue blocks. How many blocks total?', '[]'::jsonb, '14', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W18-Q10', 10, 'short_answer', 'Ava has 13 cards and Leo has 8. How many more does Ava have?', '[]'::jsonb, '5', 1);


    -- Freeze the newly installed question bank onto still-open assignments
    -- that may already exist for this Friday template.
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


    -- Week 19 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 19
      and l.week_number = 19
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W19-Q01', 1, 'multiple_choice', 'Is 5 + 3 = 8 true or false?', '[{"id": "a", "label": "true"}, {"id": "b", "label": "false"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W19-Q02', 2, 'multiple_choice', 'Is 6 + 2 = 7 true or false?', '[{"id": "a", "label": "true"}, {"id": "b", "label": "false"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W19-Q03', 3, 'short_answer', 'Find ?: 7 + ? = 12', '[]'::jsonb, '5', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W19-Q04', 4, 'short_answer', 'Find ?: ? + 4 = 11', '[]'::jsonb, '7', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W19-Q05', 5, 'short_answer', 'Find ?: 14 − ? = 9', '[]'::jsonb, '5', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W19-Q06', 6, 'short_answer', 'Find ?: ? − 4 = 8', '[]'::jsonb, '12', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W19-Q07', 7, 'short_answer', 'Find ?: ? = 8 + 5', '[]'::jsonb, '13', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W19-Q08', 8, 'short_answer', 'Find ?: 17 − 8 = ?', '[]'::jsonb, '9', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W19-Q09', 9, 'multiple_choice', 'What does the equals sign mean?', '[{"id": "a", "label": "the answer always comes next"}, {"id": "b", "label": "both sides have the same value"}, {"id": "c", "label": "add the two sides"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W19-Q10', 10, 'multiple_choice', 'Is 7 = 3 + 4 true or false?', '[{"id": "a", "label": "true"}, {"id": "b", "label": "false"}]'::jsonb, 'a', 1);


    -- Freeze the newly installed question bank onto still-open assignments
    -- that may already exist for this Friday template.
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


    -- Week 20 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 20
      and l.week_number = 20
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W20-Q01', 1, 'short_answer', 'Find ?: ? + 6 = 14', '[]'::jsonb, '8', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W20-Q02', 2, 'short_answer', 'Find ?: 16 − ? = 9', '[]'::jsonb, '7', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W20-Q03', 3, 'short_answer', 'Find ?: ? − 5 = 8', '[]'::jsonb, '13', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W20-Q04', 4, 'short_answer', 'Find ?: 9 + ? = 17', '[]'::jsonb, '8', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W20-Q05', 5, 'short_answer', 'Find ?: ? = 15 − 7', '[]'::jsonb, '8', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W20-Q06', 6, 'multiple_choice', 'Is 6 = 10 − 4 true or false?', '[{"id": "a", "label": "true"}, {"id": "b", "label": "false"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W20-Q07', 7, 'multiple_choice', 'Is 9 = 13 − 5 true or false?', '[{"id": "a", "label": "true"}, {"id": "b", "label": "false"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W20-Q08', 8, 'multiple_choice', 'Which equation can help solve 7 + ? = 13?', '[{"id": "a", "label": "13 − 7 = 6"}, {"id": "b", "label": "13 + 7 = 20"}, {"id": "c", "label": "7 − 13 = 6"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W20-Q09', 9, 'multiple_choice', 'Which equation can help solve ? − 5 = 9?', '[{"id": "a", "label": "9 + 5 = 14"}, {"id": "b", "label": "9 − 5 = 4"}, {"id": "c", "label": "5 − 9 = 4"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W20-Q10', 10, 'short_answer', 'Find ?: ? − 7 = 9', '[]'::jsonb, '16', 1);


    -- Freeze the newly installed question bank onto still-open assignments
    -- that may already exist for this Friday template.
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


    -- Week 21 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 21
      and l.week_number = 21
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W21-Q01', 1, 'short_answer', 'A strip is covered exactly by 6 equal cubes end to end. What is its length? Include the unit.', '[]'::jsonb, '6 cubes', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W21-Q02', 2, 'multiple_choice', 'Should measuring units be the same size?', '[{"id": "a", "label": "yes"}, {"id": "b", "label": "no"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W21-Q03', 3, 'multiple_choice', 'Should repeated measuring units have gaps between them?', '[{"id": "a", "label": "yes"}, {"id": "b", "label": "no"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W21-Q04', 4, 'multiple_choice', 'Should repeated measuring units overlap?', '[{"id": "a", "label": "yes"}, {"id": "b", "label": "no"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W21-Q05', 5, 'short_answer', 'A line spans 8 equal tiles end to end. What is its length? Include the unit.', '[]'::jsonb, '8 tiles', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W21-Q06', 6, 'multiple_choice', 'Which is a complete measurement?', '[{"id": "a", "label": "7"}, {"id": "b", "label": "7 blocks"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W21-Q07', 7, 'multiple_choice', 'Where should the first unit begin?', '[{"id": "a", "label": "at one end of the object"}, {"id": "b", "label": "somewhere in the middle"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W21-Q08', 8, 'multiple_choice', 'Why are gaps a problem?', '[{"id": "a", "label": "they leave some length unmeasured"}, {"id": "b", "label": "they make every unit equal"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W21-Q09', 9, 'multiple_choice', 'Why are overlaps a problem?', '[{"id": "a", "label": "they count some length more than once"}, {"id": "b", "label": "they make the units too small"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W21-Q10', 10, 'short_answer', 'A card spans 10 equal squares. Report the measurement.', '[]'::jsonb, '10 squares', 1);


    -- Freeze the newly installed question bank onto still-open assignments
    -- that may already exist for this Friday template.
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


    -- Week 22 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 22
      and l.week_number = 22
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W22-Q01', 1, 'multiple_choice', 'The same strip measures 6 large blocks or 12 small blocks. Which units are smaller?', '[{"id": "a", "label": "large blocks"}, {"id": "b", "label": "small blocks"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W22-Q02', 2, 'multiple_choice', 'Can the same object have different measurement numbers when different unit sizes are used?', '[{"id": "a", "label": "yes"}, {"id": "b", "label": "no"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W22-Q03', 3, 'multiple_choice', 'For the same length, which usually gives a larger count?', '[{"id": "a", "label": "smaller units"}, {"id": "b", "label": "larger units"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W22-Q04', 4, 'multiple_choice', 'Five equal tiles have a gap between tiles 2 and 3. Is the setup valid?', '[{"id": "a", "label": "yes"}, {"id": "b", "label": "no"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W22-Q05', 5, 'multiple_choice', 'Six equal cubes overlap. Is the setup valid?', '[{"id": "a", "label": "yes"}, {"id": "b", "label": "no"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W22-Q06', 6, 'short_answer', 'Nine equal tiles touch end to end across an object. Report the measurement.', '[]'::jsonb, '9 tiles', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W22-Q07', 7, 'multiple_choice', 'What must stay the same within one repeated-unit measurement?', '[{"id": "a", "label": "the unit size"}, {"id": "b", "label": "the object color"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W22-Q08', 8, 'multiple_choice', 'If the unit changes size, can the numeric measurement change?', '[{"id": "a", "label": "yes"}, {"id": "b", "label": "no"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W22-Q09', 9, 'multiple_choice', 'Does a different unit count always mean the object''s actual length changed?', '[{"id": "a", "label": "yes"}, {"id": "b", "label": "no"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W22-Q10', 10, 'multiple_choice', 'Why should a measurement include the unit name?', '[{"id": "a", "label": "because the number depends on the unit used"}, {"id": "b", "label": "because every object must have the same unit count"}]'::jsonb, 'a', 1);


    -- Freeze the newly installed question bank onto still-open assignments
    -- that may already exist for this Friday template.
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
