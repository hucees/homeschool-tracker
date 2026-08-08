-- Homeschool Tracker
-- Migration 022: Grade 1 Mathematics Weeks 23–27 production curriculum
--
-- Week 23 : Comparing and Ordering Lengths (1-MATH-13)
-- Weeks 24–26 : Tell and Write Time to Hour/Half-Hour (1-MATH-14)
-- Week 27 : Quarter 3 Mastery Check (1-MATH-11..14)
--
-- 25 published lesson revisions
-- 375 lesson items
-- 50 auto-scored Friday assessment items
--
-- Safety: one transaction, full preflight, no overwrite of published history,
-- no rewrite of frozen student deliveries, no overwrite of question banks.
-- Optional physical measurement/clock activities are instructional only;
-- no separate hands-on mastery evidence requirement is introduced.

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
    for v_week in 23..27 loop
      for v_day in 1..5 loop
        v_expected_code := format('1-MATH-W%s-D%s', lpad(v_week::text,2,'0'), v_day);
        if not exists (
          select 1 from public.lessons l
          where l.course_version_id=v_course.course_version_id
            and l.code=v_expected_code
        ) then
          raise exception 'Expected lesson % was not found.', v_expected_code;
        end if;
      end loop;

      if exists (
        select 1 from public.lesson_content_versions lcv
        join public.lessons l on l.id=lcv.lesson_id
        where l.course_version_id=v_course.course_version_id
          and l.week_number=v_week
          and lcv.status in ('published','superseded')
      ) then
        raise exception 'Grade 1 Math Week % already has published lesson content. Migration 022 will not overwrite curriculum history.', v_week;
      end if;

      if exists (
        select 1 from public.student_lesson_deliveries sld
        join public.lessons l on l.id=sld.lesson_id
        where l.course_version_id=v_course.course_version_id
          and l.week_number=v_week
      ) then
        raise exception 'Grade 1 Math Week % has frozen student deliveries. Migration 022 will not rewrite them.', v_week;
      end if;

      select a.id into v_template_id
      from public.assignment_templates a
      join public.lessons l on l.id=a.lesson_id
      where a.course_version_id=v_course.course_version_id
        and a.sequence=v_week
        and l.week_number=v_week
        and l.day_number=5
        and a.active is true
      limit 1;

      if v_template_id is null then
        raise exception 'Expected Grade 1 Math Week % assessment template was not found.', v_week;
      end if;

      if exists (
        select 1 from public.assessment_template_items ati
        where ati.assignment_template_id=v_template_id
      ) then
        raise exception 'Grade 1 Math Week % already has an online question bank. Migration 022 will not overwrite it.', v_week;
      end if;
    end loop;

    delete from public.lesson_content_versions lcv
    using public.lessons l
    where lcv.lesson_id=l.id
      and l.course_version_id=v_course.course_version_id
      and l.week_number between 23 and 27
      and lcv.status='draft';


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W23-D1';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will compare and order lengths using longer than, shorter than, and same/equal length language, including direct and indirect comparisons.', 'I can compare two lengths as longer, shorter, or the same.', '["pencil", "paper", "optional same-unit length strips"]'::jsonb, '[{"term": "longer than", "definition": "having more length"}, {"term": "shorter than", "definition": "having less length"}, {"term": "same length", "definition": "having equal length"}, {"term": "compare", "definition": "look at two lengths to decide how they relate"}]'::jsonb,
      'Connect today''s work to Weeks 21–22: once lengths can be measured reliably, they can also be compared and ordered.', 'Model the target relationship using same-unit measurements and verbal comparison language.', 'Use direct or indirect reasoning as appropriate. Optional physical objects may support instruction, but no separate hands-on mastery evidence is required.',
      'Compare lengths by asking which is longer, shorter, or the same. For three objects, identify shortest, middle, and longest.', 'Work through the first three comparisons together.', 'Complete the remaining comparisons independently.', 'Length Lineup: arrange three labeled length cards from shortest to longest and explain the order.',
      'Direct Length Comparisons', 'Compare or order each length and use precise length language.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain at least one comparison.',
      'Use same-unit numerical lengths or simple reference chains when visual comparison is difficult.', 'Create a three-object length puzzle for the instructor.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'A red ribbon is 9 equal units long. A blue ribbon is 6 equal units long. Which is longer?', null, 'red ribbon', '9 units is longer than 6 units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'A pencil is 7 units long and a crayon is 7 units long. Compare their lengths.', null, 'same length', 'Both measure 7 units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'A strip is 5 units long and a card is 8 units long. Which is shorter?', null, 'strip', '5 units is shorter than 8 units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Compare 10 units and 7 units. Which length is longer?', null, '10 units', '10 is greater than 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Compare 4 units and 6 units. Which is shorter?', null, '4 units', '4 is less than 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Compare 8 units and 8 units.', null, 'same length', 'The measurements are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'A book is 12 cubes long and a folder is 9 cubes long. Which is longer?', null, 'book', '12 cubes is longer than 9 cubes.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Which is longer: 6 units or 9 units?', null, '9 units', '9 is greater than 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Which is shorter: 11 units or 8 units?', null, '8 units', '8 is less than 11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Compare 5 units and 5 units.', null, 'same length', 'Equal measurements mean same length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'A spoon is 7 blocks long. A fork is 10 blocks long. Which is longer?', null, 'fork', '10 blocks is greater than 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'A ribbon is 12 clips long. A string is 9 clips long. Which is shorter?', null, 'string', '9 clips is less than 12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Complete: 8 units is ___ than 6 units.', null, 'longer', '8 is greater than 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Complete: 4 units is ___ than 7 units.', null, 'shorter', '4 is less than 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Complete: 10 units and 10 units are the ___.', null, 'same length', 'The measurements match.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W23-D2';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will compare and order lengths using longer than, shorter than, and same/equal length language, including direct and indirect comparisons.', 'I can compare lengths using a common reference.', '["pencil", "paper", "optional same-unit length strips"]'::jsonb, '[{"term": "longer than", "definition": "having more length"}, {"term": "shorter than", "definition": "having less length"}, {"term": "same length", "definition": "having equal length"}, {"term": "compare", "definition": "look at two lengths to decide how they relate"}]'::jsonb,
      'Connect today''s work to Weeks 21–22: once lengths can be measured reliably, they can also be compared and ordered.', 'Model the target relationship using same-unit measurements and verbal comparison language.', 'Use direct or indirect reasoning as appropriate. Optional physical objects may support instruction, but no separate hands-on mastery evidence is required.',
      'Compare lengths by asking which is longer, shorter, or the same. For three objects, identify shortest, middle, and longest.', 'Work through the first three comparisons together.', 'Complete the remaining comparisons independently.', 'Length Lineup: arrange three labeled length cards from shortest to longest and explain the order.',
      'Indirect Length Comparisons', 'Compare or order each length and use precise length language.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain at least one comparison.',
      'Use same-unit numerical lengths or simple reference chains when visual comparison is difficult.', 'Create a three-object length puzzle for the instructor.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'A pencil is longer than a crayon. The crayon is longer than an eraser. Which is longest?', null, 'pencil', 'If pencil > crayon and crayon > eraser, pencil is longest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'A red strip is shorter than a blue strip. The blue strip is shorter than a green strip. Which is shortest?', null, 'red strip', 'Red is shorter than blue, and blue is shorter than green.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'A book and folder are each the same length as a 9-unit reference strip. How do the book and folder compare?', null, 'same length', 'Both match the same reference length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'A is longer than B. B is longer than C. Which is shortest?', null, 'C', 'C is below both in the length order.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'X is shorter than Y. Y is shorter than Z. Which is longest?', null, 'Z', 'Z is longer than Y and X.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Two objects each match a 6-block reference. Compare them.', null, 'same length', 'Both equal the same reference.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'A spoon is longer than a 7-unit strip. A fork is shorter than the same 7-unit strip. Which is longer, spoon or fork?', null, 'spoon', 'The spoon is above the reference while the fork is below it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'A is longer than B; B is longer than C. Order longest to shortest.', null, 'A, B, C', 'The statements give the chain A>B>C.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'D is shorter than E; E is shorter than F. Order shortest to longest.', null, 'D, E, F', 'The statements give D<E<F.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'P and Q both equal an 8-unit reference. Compare P and Q.', null, 'same length', 'Both equal 8 units.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'M is longer than a 5-unit strip; N equals the strip. Which is longer?', null, 'M', 'M is greater than the reference; N equals it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'R is shorter than a 10-unit strip; S is longer than the strip. Which is shorter?', null, 'R', 'R is below the reference; S is above it.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'A equals B. B is longer than C. Which two are the same length?', null, 'A and B', 'A and B are stated equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'K is shorter than L. L equals M. Which is shortest?', null, 'K', 'K is shorter than both equal lengths.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'T is longer than U. U equals V. Which is longest?', null, 'T', 'T is longer than the equal U/V length.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W23-D3';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will compare and order lengths using longer than, shorter than, and same/equal length language, including direct and indirect comparisons.', 'I can put three objects in order by length.', '["pencil", "paper", "optional same-unit length strips"]'::jsonb, '[{"term": "longer than", "definition": "having more length"}, {"term": "shorter than", "definition": "having less length"}, {"term": "same length", "definition": "having equal length"}, {"term": "compare", "definition": "look at two lengths to decide how they relate"}]'::jsonb,
      'Connect today''s work to Weeks 21–22: once lengths can be measured reliably, they can also be compared and ordered.', 'Model the target relationship using same-unit measurements and verbal comparison language.', 'Use direct or indirect reasoning as appropriate. Optional physical objects may support instruction, but no separate hands-on mastery evidence is required.',
      'Compare lengths by asking which is longer, shorter, or the same. For three objects, identify shortest, middle, and longest.', 'Work through the first three comparisons together.', 'Complete the remaining comparisons independently.', 'Length Lineup: arrange three labeled length cards from shortest to longest and explain the order.',
      'Order Three Lengths', 'Compare or order each length and use precise length language.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain at least one comparison.',
      'Use same-unit numerical lengths or simple reference chains when visual comparison is difficult.', 'Create a three-object length puzzle for the instructor.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Order shortest to longest: 5 units, 8 units, 6 units.', null, '5, 6, 8', 'Sort the measurements from least to greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Order longest to shortest: 9 units, 4 units, 7 units.', null, '9, 7, 4', 'Sort greatest to least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Three strips measure 6, 6, and 10 units. Which are tied for shortest?', null, 'the two 6-unit strips', 'Both 6-unit lengths are equal and shorter than 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Order shortest to longest: 12, 7, 9 units.', null, '7, 9, 12', 'Least to greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Order longest to shortest: 3, 8, 5 units.', null, '8, 5, 3', 'Greatest to least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Order shortest to longest: 4, 10, 6 units.', null, '4, 6, 10', 'Least to greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Which is middle in length: 5, 9, 7 units?', null, '7 units', '7 lies between 5 and 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Order shortest to longest: 2, 5, 4 units.', null, '2, 4, 5', 'Least to greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Order longest to shortest: 11, 8, 10 units.', null, '11, 10, 8', 'Greatest to least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Order shortest to longest: 6, 3, 9 units.', null, '3, 6, 9', 'Least to greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Order longest to shortest: 7, 12, 4 units.', null, '12, 7, 4', 'Greatest to least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Which is middle: 4, 8, 6 units?', null, '6 units', '6 lies between 4 and 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Which is shortest: 13, 9, 11 units?', null, '9 units', '9 is least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Which is longest: 5, 10, 7 units?', null, '10 units', '10 is greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Three objects measure 8, 8, 6 units. Order shortest to longest.', null, '6, 8, 8', '6 is shortest; the two 8-unit objects tie.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W23-D4';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will compare and order lengths using longer than, shorter than, and same/equal length language, including direct and indirect comparisons.', 'I can compare, order, and explain length relationships.', '["pencil", "paper", "optional same-unit length strips"]'::jsonb, '[{"term": "longer than", "definition": "having more length"}, {"term": "shorter than", "definition": "having less length"}, {"term": "same length", "definition": "having equal length"}, {"term": "compare", "definition": "look at two lengths to decide how they relate"}]'::jsonb,
      'Connect today''s work to Weeks 21–22: once lengths can be measured reliably, they can also be compared and ordered.', 'Model the target relationship using same-unit measurements and verbal comparison language.', 'Use direct or indirect reasoning as appropriate. Optional physical objects may support instruction, but no separate hands-on mastery evidence is required.',
      'Compare lengths by asking which is longer, shorter, or the same. For three objects, identify shortest, middle, and longest.', 'Work through the first three comparisons together.', 'Complete the remaining comparisons independently.', 'Length Lineup: arrange three labeled length cards from shortest to longest and explain the order.',
      'Explain Length Comparisons', 'Compare or order each length and use precise length language.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain at least one comparison.',
      'Use same-unit numerical lengths or simple reference chains when visual comparison is difficult.', 'Create a three-object length puzzle for the instructor.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'A is 8 units; B is 11 units. Write a comparison sentence.', null, 'A is shorter than B', '8<11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'C is longer than D; D is longer than E. Which is longest?', null, 'C', 'C>D>E.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Order 9, 6, 12 units from shortest to longest.', null, '6, 9, 12', 'Least to greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Two objects each measure 7 blocks. Compare them.', null, 'same length', 'Equal counts with same unit mean equal length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'A is shorter than a reference; B is longer than the same reference. Which is longer?', null, 'B', 'B is above the reference.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Order 10, 4, 8 units longest to shortest.', null, '10, 8, 4', 'Greatest to least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Which is middle: 3, 9, 6 units?', null, '6 units', '6 is between 3 and 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Compare 12 and 9 units.', null, '12 units is longer', '12>9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Compare 5 and 5 units.', null, 'same length', 'The measurements are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'A>B and B>C. Which is shortest?', null, 'C', 'C is below both.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Order 4, 7, 6 units shortest to longest.', null, '4, 6, 7', 'Least to greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Order 11, 8, 9 units longest to shortest.', null, '11, 9, 8', 'Greatest to least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'A and B equal a 10-unit reference. Compare A and B.', null, 'same length', 'Both equal the same reference.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'M is shorter than N. N equals P. Which is shortest?', null, 'M', 'M<N=P.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Complete: If 9 units > 6 units, the 9-unit object is ___.', null, 'longer', 'Greater measurement with the same unit means longer.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W23-D5';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will compare and order lengths using longer than, shorter than, and same/equal length language, including direct and indirect comparisons.', 'I can compare and order lengths independently.', '["pencil", "paper", "optional same-unit length strips"]'::jsonb, '[{"term": "longer than", "definition": "having more length"}, {"term": "shorter than", "definition": "having less length"}, {"term": "same length", "definition": "having equal length"}, {"term": "compare", "definition": "look at two lengths to decide how they relate"}]'::jsonb,
      'Connect today''s work to Weeks 21–22: once lengths can be measured reliably, they can also be compared and ordered.', 'Model the target relationship using same-unit measurements and verbal comparison language.', 'Use direct or indirect reasoning as appropriate. Optional physical objects may support instruction, but no separate hands-on mastery evidence is required.',
      'Compare lengths by asking which is longer, shorter, or the same. For three objects, identify shortest, middle, and longest.', 'Work through the first three comparisons together.', 'Complete the remaining comparisons independently.', 'Length Lineup: arrange three labeled length cards from shortest to longest and explain the order.',
      'Week 23 Length Comparison Readiness', 'Compare or order each length and use precise length language.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain at least one comparison.',
      'Use same-unit numerical lengths or simple reference chains when visual comparison is difficult.', 'Create a three-object length puzzle for the instructor.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'A is 8 units; B is 11 units. Write a comparison sentence.', null, 'A is shorter than B', '8<11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'C is longer than D; D is longer than E. Which is longest?', null, 'C', 'C>D>E.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Order 9, 6, 12 units from shortest to longest.', null, '6, 9, 12', 'Least to greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Two objects each measure 7 blocks. Compare them.', null, 'same length', 'Equal counts with same unit mean equal length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'A is shorter than a reference; B is longer than the same reference. Which is longer?', null, 'B', 'B is above the reference.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Order 10, 4, 8 units longest to shortest.', null, '10, 8, 4', 'Greatest to least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Which is middle: 3, 9, 6 units?', null, '6 units', '6 is between 3 and 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Compare 12 and 9 units.', null, '12 units is longer', '12>9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Compare 5 and 5 units.', null, 'same length', 'The measurements are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'A>B and B>C. Which is shortest?', null, 'C', 'C is below both.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Order 4, 7, 6 units shortest to longest.', null, '4, 6, 7', 'Least to greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Order 11, 8, 9 units longest to shortest.', null, '11, 9, 8', 'Greatest to least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'A and B equal a 10-unit reference. Compare A and B.', null, 'same length', 'Both equal the same reference.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'M is shorter than N. N equals P. Which is shortest?', null, 'M', 'M<N=P.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Complete: If 9 units > 6 units, the 9-unit object is ___.', null, 'longer', 'Greater measurement with the same unit means longer.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W24-D1';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will read, model, and write times to the hour using analog and digital representations.', 'I can use the hour and minute hands to read o''clock times.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Introduce or review the hour hand, minute hand, and the meaning of an exact hour.', 'Model several o''clock times, emphasizing minute hand on 12 and hour hand on the stated hour.', 'Use clock manipulation as optional instruction. A separate physical clock-setting demonstration is not required for mastery.',
      'At an exact hour, the minute hand points to 12 and the digital minutes are :00. The hour hand points to the hour.', 'Read and write three o''clock examples together.', 'Complete hour-time items independently.', 'Optional Clock Match: set or sketch an analog clock to match a digital o''clock time.',
      'Clock Hands and Exact Hours', 'Read, write, or describe each o''clock time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and correctly explain the two hands on one example.',
      'Use a labeled analog-clock diagram during instruction.', 'Create three o''clock times for the instructor to identify.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Minute hand is on 12 and hour hand is on 3. What time is it?', null, '3:00', 'Minute hand on 12 means :00; hour hand shows 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Minute hand is on 12 and hour hand is on 7. Time?', null, '7:00', 'This is seven o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Which hand tells the hour?', null, 'hour hand', 'The shorter hour hand points to the hour number.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Minute hand on 12, hour hand on 5. Time?', null, '5:00', 'Five o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Minute hand on 12, hour hand on 9. Time?', null, '9:00', 'Nine o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Write two o''clock digitally.', null, '2:00', 'Exact hour is written :00.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Write eleven o''clock digitally.', null, '11:00', 'Exact hour is written 11:00.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Hour hand 1, minute hand 12.', null, '1:00', 'One o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Hour hand 4, minute hand 12.', null, '4:00', 'Four o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Hour hand 6, minute hand 12.', null, '6:00', 'Six o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Hour hand 8, minute hand 12.', null, '8:00', 'Eight o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Hour hand 10, minute hand 12.', null, '10:00', 'Ten o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Write 12 o''clock digitally.', null, '12:00', 'Exact hour uses :00.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At an exact hour, where does the minute hand point?', null, '12', 'Minute hand on 12 means zero minutes.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'At 3:00, where does the hour hand point?', null, '3', 'The hour hand shows the current hour.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W24-D2';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will read, model, and write times to the hour using analog and digital representations.', 'I can read analog clocks to the hour.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Introduce or review the hour hand, minute hand, and the meaning of an exact hour.', 'Model several o''clock times, emphasizing minute hand on 12 and hour hand on the stated hour.', 'Use clock manipulation as optional instruction. A separate physical clock-setting demonstration is not required for mastery.',
      'At an exact hour, the minute hand points to 12 and the digital minutes are :00. The hour hand points to the hour.', 'Read and write three o''clock examples together.', 'Complete hour-time items independently.', 'Optional Clock Match: set or sketch an analog clock to match a digital o''clock time.',
      'Read Times to the Hour', 'Read, write, or describe each o''clock time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and correctly explain the two hands on one example.',
      'Use a labeled analog-clock diagram during instruction.', 'Create three o''clock times for the instructor to identify.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Minute hand is on 12 and hour hand is on 3. What time is it?', null, '3:00', 'Minute hand on 12 means :00; hour hand shows 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Minute hand is on 12 and hour hand is on 7. Time?', null, '7:00', 'This is seven o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Which hand tells the hour?', null, 'hour hand', 'The shorter hour hand points to the hour number.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Minute hand on 12, hour hand on 5. Time?', null, '5:00', 'Five o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Minute hand on 12, hour hand on 9. Time?', null, '9:00', 'Nine o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Write two o''clock digitally.', null, '2:00', 'Exact hour is written :00.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Write eleven o''clock digitally.', null, '11:00', 'Exact hour is written 11:00.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Hour hand 1, minute hand 12.', null, '1:00', 'One o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Hour hand 4, minute hand 12.', null, '4:00', 'Four o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Hour hand 6, minute hand 12.', null, '6:00', 'Six o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Hour hand 8, minute hand 12.', null, '8:00', 'Eight o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Hour hand 10, minute hand 12.', null, '10:00', 'Ten o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Write 12 o''clock digitally.', null, '12:00', 'Exact hour uses :00.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At an exact hour, where does the minute hand point?', null, '12', 'Minute hand on 12 means zero minutes.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'At 3:00, where does the hour hand point?', null, '3', 'The hour hand shows the current hour.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W24-D3';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will read, model, and write times to the hour using analog and digital representations.', 'I can match o''clock times in different forms.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Introduce or review the hour hand, minute hand, and the meaning of an exact hour.', 'Model several o''clock times, emphasizing minute hand on 12 and hour hand on the stated hour.', 'Use clock manipulation as optional instruction. A separate physical clock-setting demonstration is not required for mastery.',
      'At an exact hour, the minute hand points to 12 and the digital minutes are :00. The hour hand points to the hour.', 'Read and write three o''clock examples together.', 'Complete hour-time items independently.', 'Optional Clock Match: set or sketch an analog clock to match a digital o''clock time.',
      'Match Analog, Digital, and Words', 'Read, write, or describe each o''clock time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and correctly explain the two hands on one example.',
      'Use a labeled analog-clock diagram during instruction.', 'Create three o''clock times for the instructor to identify.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Which description matches 4:00?', null, 'hour hand on 4, minute hand on 12', 'Exact hour has minute hand on 12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Which digital time matches ''nine o''clock''?', null, '9:00', 'Nine o''clock is 9:00.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Clock shows hour hand 2 and minute hand 12. Write the digital time.', null, '2:00', 'Two o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Match seven o''clock to digital time.', null, '7:00', 'Seven o''clock is 7:00.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Match 11:00 to words.', null, 'eleven o''clock', '11:00 is eleven o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Which hand should point to 6 at 6:00?', null, 'hour hand', 'The hour hand shows 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Which hand points to 12 at 6:00?', null, 'minute hand', 'The minute hand shows zero minutes.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Write 5:00 in words.', null, 'five o''clock', '5:00 is five o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Write eight o''clock digitally.', null, '8:00', 'Exact hour is :00.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Describe the hands at 1:00.', null, 'hour hand on 1, minute hand on 12', 'That represents one o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Describe the hands at 10:00.', null, 'hour hand on 10, minute hand on 12', 'That represents ten o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Clock: hour 12, minute 12. Time?', null, '12:00', 'Twelve o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Clock: hour 3, minute 12. Time?', null, '3:00', 'Three o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At any o''clock time, what are the minutes?', null, '00', 'Exact hour has zero minutes.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Is 7:00 an hour time or half-hour time?', null, 'hour time', 'It is exactly seven o''clock.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W24-D4';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will read, model, and write times to the hour using analog and digital representations.', 'I can write hour times and explain the clock hands.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Introduce or review the hour hand, minute hand, and the meaning of an exact hour.', 'Model several o''clock times, emphasizing minute hand on 12 and hour hand on the stated hour.', 'Use clock manipulation as optional instruction. A separate physical clock-setting demonstration is not required for mastery.',
      'At an exact hour, the minute hand points to 12 and the digital minutes are :00. The hour hand points to the hour.', 'Read and write three o''clock examples together.', 'Complete hour-time items independently.', 'Optional Clock Match: set or sketch an analog clock to match a digital o''clock time.',
      'Write and Explain Hour Times', 'Read, write, or describe each o''clock time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and correctly explain the two hands on one example.',
      'Use a labeled analog-clock diagram during instruction.', 'Create three o''clock times for the instructor to identify.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Which description matches 4:00?', null, 'hour hand on 4, minute hand on 12', 'Exact hour has minute hand on 12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Which digital time matches ''nine o''clock''?', null, '9:00', 'Nine o''clock is 9:00.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Clock shows hour hand 2 and minute hand 12. Write the digital time.', null, '2:00', 'Two o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Match seven o''clock to digital time.', null, '7:00', 'Seven o''clock is 7:00.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Match 11:00 to words.', null, 'eleven o''clock', '11:00 is eleven o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Which hand should point to 6 at 6:00?', null, 'hour hand', 'The hour hand shows 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Which hand points to 12 at 6:00?', null, 'minute hand', 'The minute hand shows zero minutes.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Write 5:00 in words.', null, 'five o''clock', '5:00 is five o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Write eight o''clock digitally.', null, '8:00', 'Exact hour is :00.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Describe the hands at 1:00.', null, 'hour hand on 1, minute hand on 12', 'That represents one o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Describe the hands at 10:00.', null, 'hour hand on 10, minute hand on 12', 'That represents ten o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Clock: hour 12, minute 12. Time?', null, '12:00', 'Twelve o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Clock: hour 3, minute 12. Time?', null, '3:00', 'Three o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At any o''clock time, what are the minutes?', null, '00', 'Exact hour has zero minutes.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Is 7:00 an hour time or half-hour time?', null, 'hour time', 'It is exactly seven o''clock.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W24-D5';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will read, model, and write times to the hour using analog and digital representations.', 'I can read and write o''clock times independently.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Introduce or review the hour hand, minute hand, and the meaning of an exact hour.', 'Model several o''clock times, emphasizing minute hand on 12 and hour hand on the stated hour.', 'Use clock manipulation as optional instruction. A separate physical clock-setting demonstration is not required for mastery.',
      'At an exact hour, the minute hand points to 12 and the digital minutes are :00. The hour hand points to the hour.', 'Read and write three o''clock examples together.', 'Complete hour-time items independently.', 'Optional Clock Match: set or sketch an analog clock to match a digital o''clock time.',
      'Week 24 Hour-Time Readiness', 'Read, write, or describe each o''clock time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and correctly explain the two hands on one example.',
      'Use a labeled analog-clock diagram during instruction.', 'Create three o''clock times for the instructor to identify.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Minute hand 12, hour hand 6. Time?', null, '6:00', 'Minute 12 means exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Minute hand 6, hour hand halfway between 6 and 7. Time?', null, '6:30', 'Minute 6 means half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Which is later: 4:00 or 4:30?', null, '4:30', 'Half past 4 occurs after 4 o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Write 8 o''clock digitally.', null, '8:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Write half past 8 digitally.', null, '8:30', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Clock: minute 12, hour 11.', null, '11:00', 'Eleven o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Clock: minute 6, hour between 11 and 12.', null, '11:30', 'Half past eleven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Time: hour 2, minute 12.', null, '2:00', 'Two o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Time: hour between 2 and 3, minute 6.', null, '2:30', 'Half past two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Which comes first: 7:00 or 7:30?', null, '7:00', 'Seven o''clock comes before half past seven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Write 9:30 in words.', null, 'half past nine', 'Thirty minutes after nine.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Write five o''clock digitally.', null, '5:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'At 10:30, where is minute hand?', null, '6', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At 10:00, where is minute hand?', null, '12', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Is 3:30 an hour or half-hour time?', null, 'half-hour time', 'The minutes are 30.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W25-D1';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will read, model, and write times to the half-hour, connecting the minute hand on 6 with 30 minutes after the hour.', 'I can recognize a half-hour as 30 minutes after an hour.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Connect a half-hour to 30 minutes after the named hour and to the minute hand pointing at 6.', 'Model the hour hand moving halfway toward the next hour while the minute hand moves to 6.', 'Do not teach the hour hand as remaining exactly on the hour number at :30.',
      'At a half-hour, the minute hand points to 6. The hour hand sits halfway between the current hour and the next hour. Digital time ends in :30.', 'Read and write three half-hour examples together.', 'Complete half-hour items independently.', 'Optional Clock Match: set or sketch an analog clock for a :30 digital time.',
      'What Half Past Means', 'Read, write, or describe each half-hour time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain why the hour hand is between two numbers at :30.',
      'Use a labeled clock diagram with the halfway hour-hand position shown.', 'Create three half-hour times and explain where both hands belong.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Minute hand is on 6 and hour hand is halfway between 3 and 4. Time?', null, '3:30', 'Minute hand on 6 means 30 minutes after 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Minute hand on 6; hour hand halfway between 7 and 8. Time?', null, '7:30', 'This is half past 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'At a half-hour, where does the minute hand point?', null, '6', 'Six marks 30 minutes.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Hour hand halfway between 1 and 2; minute hand on 6.', null, '1:30', 'Half past 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Hour hand halfway between 9 and 10; minute hand on 6.', null, '9:30', 'Half past 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Write half past 5 digitally.', null, '5:30', 'Half-hour is :30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Write 11:30 in words.', null, 'half past eleven', '11:30 is half past 11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Hour hand between 2 and 3; minute hand 6.', null, '2:30', 'Half past 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Hour hand between 4 and 5; minute hand 6.', null, '4:30', 'Half past 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Hour hand between 6 and 7; minute hand 6.', null, '6:30', 'Half past 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Write half past eight digitally.', null, '8:30', 'Half past 8 is 8:30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Write 10:30 in words.', null, 'half past ten', '10:30 is half past 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'At 3:30, is the hour hand exactly on 3?', null, 'no', 'It has moved halfway toward 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At 12:30, where is the minute hand?', null, '6', 'Half-hour means minute hand on 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'How many minutes are in a half-hour?', null, '30', 'A half-hour is 30 minutes.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W25-D2';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will read, model, and write times to the half-hour, connecting the minute hand on 6 with 30 minutes after the hour.', 'I can read analog clocks to the half-hour.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Connect a half-hour to 30 minutes after the named hour and to the minute hand pointing at 6.', 'Model the hour hand moving halfway toward the next hour while the minute hand moves to 6.', 'Do not teach the hour hand as remaining exactly on the hour number at :30.',
      'At a half-hour, the minute hand points to 6. The hour hand sits halfway between the current hour and the next hour. Digital time ends in :30.', 'Read and write three half-hour examples together.', 'Complete half-hour items independently.', 'Optional Clock Match: set or sketch an analog clock for a :30 digital time.',
      'Read Half-Hour Times', 'Read, write, or describe each half-hour time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain why the hour hand is between two numbers at :30.',
      'Use a labeled clock diagram with the halfway hour-hand position shown.', 'Create three half-hour times and explain where both hands belong.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Minute hand is on 6 and hour hand is halfway between 3 and 4. Time?', null, '3:30', 'Minute hand on 6 means 30 minutes after 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Minute hand on 6; hour hand halfway between 7 and 8. Time?', null, '7:30', 'This is half past 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'At a half-hour, where does the minute hand point?', null, '6', 'Six marks 30 minutes.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Hour hand halfway between 1 and 2; minute hand on 6.', null, '1:30', 'Half past 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Hour hand halfway between 9 and 10; minute hand on 6.', null, '9:30', 'Half past 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Write half past 5 digitally.', null, '5:30', 'Half-hour is :30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Write 11:30 in words.', null, 'half past eleven', '11:30 is half past 11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Hour hand between 2 and 3; minute hand 6.', null, '2:30', 'Half past 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Hour hand between 4 and 5; minute hand 6.', null, '4:30', 'Half past 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Hour hand between 6 and 7; minute hand 6.', null, '6:30', 'Half past 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Write half past eight digitally.', null, '8:30', 'Half past 8 is 8:30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Write 10:30 in words.', null, 'half past ten', '10:30 is half past 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'At 3:30, is the hour hand exactly on 3?', null, 'no', 'It has moved halfway toward 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At 12:30, where is the minute hand?', null, '6', 'Half-hour means minute hand on 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'How many minutes are in a half-hour?', null, '30', 'A half-hour is 30 minutes.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W25-D3';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will read, model, and write times to the half-hour, connecting the minute hand on 6 with 30 minutes after the hour.', 'I can write half-hour times digitally and in words.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Connect a half-hour to 30 minutes after the named hour and to the minute hand pointing at 6.', 'Model the hour hand moving halfway toward the next hour while the minute hand moves to 6.', 'Do not teach the hour hand as remaining exactly on the hour number at :30.',
      'At a half-hour, the minute hand points to 6. The hour hand sits halfway between the current hour and the next hour. Digital time ends in :30.', 'Read and write three half-hour examples together.', 'Complete half-hour items independently.', 'Optional Clock Match: set or sketch an analog clock for a :30 digital time.',
      'Write Half-Hour Times', 'Read, write, or describe each half-hour time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain why the hour hand is between two numbers at :30.',
      'Use a labeled clock diagram with the halfway hour-hand position shown.', 'Create three half-hour times and explain where both hands belong.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Minute hand is on 6 and hour hand is halfway between 3 and 4. Time?', null, '3:30', 'Minute hand on 6 means 30 minutes after 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Minute hand on 6; hour hand halfway between 7 and 8. Time?', null, '7:30', 'This is half past 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'At a half-hour, where does the minute hand point?', null, '6', 'Six marks 30 minutes.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Hour hand halfway between 1 and 2; minute hand on 6.', null, '1:30', 'Half past 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Hour hand halfway between 9 and 10; minute hand on 6.', null, '9:30', 'Half past 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Write half past 5 digitally.', null, '5:30', 'Half-hour is :30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Write 11:30 in words.', null, 'half past eleven', '11:30 is half past 11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Hour hand between 2 and 3; minute hand 6.', null, '2:30', 'Half past 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Hour hand between 4 and 5; minute hand 6.', null, '4:30', 'Half past 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Hour hand between 6 and 7; minute hand 6.', null, '6:30', 'Half past 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Write half past eight digitally.', null, '8:30', 'Half past 8 is 8:30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Write 10:30 in words.', null, 'half past ten', '10:30 is half past 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'At 3:30, is the hour hand exactly on 3?', null, 'no', 'It has moved halfway toward 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At 12:30, where is the minute hand?', null, '6', 'Half-hour means minute hand on 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'How many minutes are in a half-hour?', null, '30', 'A half-hour is 30 minutes.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W25-D4';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will read, model, and write times to the half-hour, connecting the minute hand on 6 with 30 minutes after the hour.', 'I can tell whether a time is on the hour or half-hour.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Connect a half-hour to 30 minutes after the named hour and to the minute hand pointing at 6.', 'Model the hour hand moving halfway toward the next hour while the minute hand moves to 6.', 'Do not teach the hour hand as remaining exactly on the hour number at :30.',
      'At a half-hour, the minute hand points to 6. The hour hand sits halfway between the current hour and the next hour. Digital time ends in :30.', 'Read and write three half-hour examples together.', 'Complete half-hour items independently.', 'Optional Clock Match: set or sketch an analog clock for a :30 digital time.',
      'Hour or Half-Hour?', 'Read, write, or describe each half-hour time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain why the hour hand is between two numbers at :30.',
      'Use a labeled clock diagram with the halfway hour-hand position shown.', 'Create three half-hour times and explain where both hands belong.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Minute hand 12, hour hand 6. Time?', null, '6:00', 'Minute 12 means exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Minute hand 6, hour hand halfway between 6 and 7. Time?', null, '6:30', 'Minute 6 means half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Which is later: 4:00 or 4:30?', null, '4:30', 'Half past 4 occurs after 4 o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Write 8 o''clock digitally.', null, '8:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Write half past 8 digitally.', null, '8:30', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Clock: minute 12, hour 11.', null, '11:00', 'Eleven o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Clock: minute 6, hour between 11 and 12.', null, '11:30', 'Half past eleven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Time: hour 2, minute 12.', null, '2:00', 'Two o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Time: hour between 2 and 3, minute 6.', null, '2:30', 'Half past two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Which comes first: 7:00 or 7:30?', null, '7:00', 'Seven o''clock comes before half past seven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Write 9:30 in words.', null, 'half past nine', 'Thirty minutes after nine.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Write five o''clock digitally.', null, '5:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'At 10:30, where is minute hand?', null, '6', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At 10:00, where is minute hand?', null, '12', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Is 3:30 an hour or half-hour time?', null, 'half-hour time', 'The minutes are 30.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W25-D5';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will read, model, and write times to the half-hour, connecting the minute hand on 6 with 30 minutes after the hour.', 'I can read and write half-hour times independently.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Connect a half-hour to 30 minutes after the named hour and to the minute hand pointing at 6.', 'Model the hour hand moving halfway toward the next hour while the minute hand moves to 6.', 'Do not teach the hour hand as remaining exactly on the hour number at :30.',
      'At a half-hour, the minute hand points to 6. The hour hand sits halfway between the current hour and the next hour. Digital time ends in :30.', 'Read and write three half-hour examples together.', 'Complete half-hour items independently.', 'Optional Clock Match: set or sketch an analog clock for a :30 digital time.',
      'Week 25 Half-Hour Readiness', 'Read, write, or describe each half-hour time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain why the hour hand is between two numbers at :30.',
      'Use a labeled clock diagram with the halfway hour-hand position shown.', 'Create three half-hour times and explain where both hands belong.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Minute hand 12, hour hand 6. Time?', null, '6:00', 'Minute 12 means exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Minute hand 6, hour hand halfway between 6 and 7. Time?', null, '6:30', 'Minute 6 means half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Which is later: 4:00 or 4:30?', null, '4:30', 'Half past 4 occurs after 4 o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Write 8 o''clock digitally.', null, '8:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Write half past 8 digitally.', null, '8:30', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Clock: minute 12, hour 11.', null, '11:00', 'Eleven o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Clock: minute 6, hour between 11 and 12.', null, '11:30', 'Half past eleven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Time: hour 2, minute 12.', null, '2:00', 'Two o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Time: hour between 2 and 3, minute 6.', null, '2:30', 'Half past two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Which comes first: 7:00 or 7:30?', null, '7:00', 'Seven o''clock comes before half past seven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Write 9:30 in words.', null, 'half past nine', 'Thirty minutes after nine.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Write five o''clock digitally.', null, '5:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'At 10:30, where is minute hand?', null, '6', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At 10:00, where is minute hand?', null, '12', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Is 3:30 an hour or half-hour time?', null, 'half-hour time', 'The minutes are 30.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W26-D1';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently read, write, compare, and apply hour and half-hour times using analog and digital clocks.', 'I can switch between hour and half-hour times.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Mix :00 and :30 times so the student must inspect the minute hand rather than assume the lesson type.', 'Model identifying minutes first from the minute hand, then identifying the hour from the hour-hand position.', 'Week 26 provides another independent opportunity for 1-MATH-14. Repeated qualifying evidence may establish mastery without a separate clock-setting requirement.',
      'First check the minute hand: 12 means :00; 6 means :30. Then read the hour hand carefully.', 'Complete mixed examples together.', 'Complete mixed hour/half-hour items independently.', 'Schedule Sort: place simple daily-event cards in order using :00 and :30 times.',
      'Mixed Hour and Half-Hour Practice', 'Read, write, compare, or apply each hour/half-hour time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one analog-to-digital match.',
      'Use a clock-face reference during guided practice, then fade it where appropriate.', 'Design a four-event schedule using both :00 and :30 times.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Minute hand 12, hour hand 6. Time?', null, '6:00', 'Minute 12 means exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Minute hand 6, hour hand halfway between 6 and 7. Time?', null, '6:30', 'Minute 6 means half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Which is later: 4:00 or 4:30?', null, '4:30', 'Half past 4 occurs after 4 o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Write 8 o''clock digitally.', null, '8:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Write half past 8 digitally.', null, '8:30', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Clock: minute 12, hour 11.', null, '11:00', 'Eleven o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Clock: minute 6, hour between 11 and 12.', null, '11:30', 'Half past eleven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Time: hour 2, minute 12.', null, '2:00', 'Two o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Time: hour between 2 and 3, minute 6.', null, '2:30', 'Half past two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Which comes first: 7:00 or 7:30?', null, '7:00', 'Seven o''clock comes before half past seven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Write 9:30 in words.', null, 'half past nine', 'Thirty minutes after nine.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Write five o''clock digitally.', null, '5:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'At 10:30, where is minute hand?', null, '6', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At 10:00, where is minute hand?', null, '12', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Is 3:30 an hour or half-hour time?', null, 'half-hour time', 'The minutes are 30.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W26-D2';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently read, write, compare, and apply hour and half-hour times using analog and digital clocks.', 'I can use hour and half-hour times in a simple schedule.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Mix :00 and :30 times so the student must inspect the minute hand rather than assume the lesson type.', 'Model identifying minutes first from the minute hand, then identifying the hour from the hour-hand position.', 'Week 26 provides another independent opportunity for 1-MATH-14. Repeated qualifying evidence may establish mastery without a separate clock-setting requirement.',
      'First check the minute hand: 12 means :00; 6 means :30. Then read the hour hand carefully.', 'Complete mixed examples together.', 'Complete mixed hour/half-hour items independently.', 'Schedule Sort: place simple daily-event cards in order using :00 and :30 times.',
      'Time in a Daily Schedule', 'Read, write, compare, or apply each hour/half-hour time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one analog-to-digital match.',
      'Use a clock-face reference during guided practice, then fade it where appropriate.', 'Design a four-event schedule using both :00 and :30 times.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Breakfast is at 8:00 and reading is at 8:30. Which happens first?', null, 'breakfast', '8:00 comes before 8:30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Lunch is at 12:00. Write the time in words.', null, 'twelve o''clock', '12:00 is twelve o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Practice starts at 3:30. Is that an hour or half-hour time?', null, 'half-hour', 'The minutes are 30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Math is at 9:00 and break is at 9:30. Which is later?', null, 'break', '9:30 is later.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Write half past one digitally.', null, '1:30', 'Half-hour uses :30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Write 6:00 in words.', null, 'six o''clock', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'At 7:30, where is the minute hand?', null, '6', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'School starts 8:00; snack 10:30. Which is earlier?', null, '8:00', '8:00 comes first.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Write 2:30 in words.', null, 'half past two', 'Thirty minutes after two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Write four o''clock digitally.', null, '4:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Clock has minute hand 6 and hour hand between 4 and 5.', null, '4:30', 'Half past four.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Clock has minute hand 12 and hour hand 4.', null, '4:00', 'Four o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Which is later: 11:00 or 11:30?', null, '11:30', 'Half past eleven is later.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'How many minutes after 5:00 is 5:30?', null, '30 minutes', 'Half-hour later.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'At 1:00, which number does minute hand point to?', null, '12', 'Exact hour.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W26-D3';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently read, write, compare, and apply hour and half-hour times using analog and digital clocks.', 'I can explain how clock hands match digital time.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Mix :00 and :30 times so the student must inspect the minute hand rather than assume the lesson type.', 'Model identifying minutes first from the minute hand, then identifying the hour from the hour-hand position.', 'Week 26 provides another independent opportunity for 1-MATH-14. Repeated qualifying evidence may establish mastery without a separate clock-setting requirement.',
      'First check the minute hand: 12 means :00; 6 means :30. Then read the hour hand carefully.', 'Complete mixed examples together.', 'Complete mixed hour/half-hour items independently.', 'Schedule Sort: place simple daily-event cards in order using :00 and :30 times.',
      'Analog and Digital Time Reasoning', 'Read, write, compare, or apply each hour/half-hour time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one analog-to-digital match.',
      'Use a clock-face reference during guided practice, then fade it where appropriate.', 'Design a four-event schedule using both :00 and :30 times.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Minute hand 12, hour hand 6. Time?', null, '6:00', 'Minute 12 means exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Minute hand 6, hour hand halfway between 6 and 7. Time?', null, '6:30', 'Minute 6 means half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Which is later: 4:00 or 4:30?', null, '4:30', 'Half past 4 occurs after 4 o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Write 8 o''clock digitally.', null, '8:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Write half past 8 digitally.', null, '8:30', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Clock: minute 12, hour 11.', null, '11:00', 'Eleven o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Clock: minute 6, hour between 11 and 12.', null, '11:30', 'Half past eleven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Time: hour 2, minute 12.', null, '2:00', 'Two o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Time: hour between 2 and 3, minute 6.', null, '2:30', 'Half past two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Which comes first: 7:00 or 7:30?', null, '7:00', 'Seven o''clock comes before half past seven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Write 9:30 in words.', null, 'half past nine', 'Thirty minutes after nine.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Write five o''clock digitally.', null, '5:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'At 10:30, where is minute hand?', null, '6', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At 10:00, where is minute hand?', null, '12', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Is 3:30 an hour or half-hour time?', null, 'half-hour time', 'The minutes are 30.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W26-D4';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently read, write, compare, and apply hour and half-hour times using analog and digital clocks.', 'I can solve simple time-reading situations.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Mix :00 and :30 times so the student must inspect the minute hand rather than assume the lesson type.', 'Model identifying minutes first from the minute hand, then identifying the hour from the hour-hand position.', 'Week 26 provides another independent opportunity for 1-MATH-14. Repeated qualifying evidence may establish mastery without a separate clock-setting requirement.',
      'First check the minute hand: 12 means :00; 6 means :30. Then read the hour hand carefully.', 'Complete mixed examples together.', 'Complete mixed hour/half-hour items independently.', 'Schedule Sort: place simple daily-event cards in order using :00 and :30 times.',
      'Apply Hour and Half-Hour Time', 'Read, write, compare, or apply each hour/half-hour time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one analog-to-digital match.',
      'Use a clock-face reference during guided practice, then fade it where appropriate.', 'Design a four-event schedule using both :00 and :30 times.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Breakfast is at 8:00 and reading is at 8:30. Which happens first?', null, 'breakfast', '8:00 comes before 8:30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Lunch is at 12:00. Write the time in words.', null, 'twelve o''clock', '12:00 is twelve o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Practice starts at 3:30. Is that an hour or half-hour time?', null, 'half-hour', 'The minutes are 30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Math is at 9:00 and break is at 9:30. Which is later?', null, 'break', '9:30 is later.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Write half past one digitally.', null, '1:30', 'Half-hour uses :30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Write 6:00 in words.', null, 'six o''clock', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'At 7:30, where is the minute hand?', null, '6', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'School starts 8:00; snack 10:30. Which is earlier?', null, '8:00', '8:00 comes first.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Write 2:30 in words.', null, 'half past two', 'Thirty minutes after two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Write four o''clock digitally.', null, '4:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Clock has minute hand 6 and hour hand between 4 and 5.', null, '4:30', 'Half past four.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Clock has minute hand 12 and hour hand 4.', null, '4:00', 'Four o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Which is later: 11:00 or 11:30?', null, '11:30', 'Half past eleven is later.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'How many minutes after 5:00 is 5:30?', null, '30 minutes', 'Half-hour later.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'At 1:00, which number does minute hand point to?', null, '12', 'Exact hour.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W26-D5';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently read, write, compare, and apply hour and half-hour times using analog and digital clocks.', 'I can read and write hour and half-hour times independently.', '["pencil", "paper", "optional teaching clock"]'::jsonb, '[{"term": "hour hand", "definition": "the shorter hand that shows the hour"}, {"term": "minute hand", "definition": "the longer hand that shows minutes"}, {"term": "o''clock", "definition": "an exact hour when the minute hand points to 12"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Mix :00 and :30 times so the student must inspect the minute hand rather than assume the lesson type.', 'Model identifying minutes first from the minute hand, then identifying the hour from the hour-hand position.', 'Week 26 provides another independent opportunity for 1-MATH-14. Repeated qualifying evidence may establish mastery without a separate clock-setting requirement.',
      'First check the minute hand: 12 means :00; 6 means :30. Then read the hour hand carefully.', 'Complete mixed examples together.', 'Complete mixed hour/half-hour items independently.', 'Schedule Sort: place simple daily-event cards in order using :00 and :30 times.',
      'Week 26 Time Mastery Readiness', 'Read, write, compare, or apply each hour/half-hour time.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one analog-to-digital match.',
      'Use a clock-face reference during guided practice, then fade it where appropriate.', 'Design a four-event schedule using both :00 and :30 times.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Minute hand 12, hour hand 6. Time?', null, '6:00', 'Minute 12 means exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Minute hand 6, hour hand halfway between 6 and 7. Time?', null, '6:30', 'Minute 6 means half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Which is later: 4:00 or 4:30?', null, '4:30', 'Half past 4 occurs after 4 o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Write 8 o''clock digitally.', null, '8:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Write half past 8 digitally.', null, '8:30', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Clock: minute 12, hour 11.', null, '11:00', 'Eleven o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Clock: minute 6, hour between 11 and 12.', null, '11:30', 'Half past eleven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Time: hour 2, minute 12.', null, '2:00', 'Two o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Time: hour between 2 and 3, minute 6.', null, '2:30', 'Half past two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Which comes first: 7:00 or 7:30?', null, '7:00', 'Seven o''clock comes before half past seven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Write 9:30 in words.', null, 'half past nine', 'Thirty minutes after nine.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Write five o''clock digitally.', null, '5:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'At 10:30, where is minute hand?', null, '6', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At 10:00, where is minute hand?', null, '12', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Is 3:30 an hour or half-hour time?', null, 'half-hour time', 'The minutes are 30.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W27-D1';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently review Quarter 3 competencies 1-MATH-11 through 1-MATH-14 in preparation for the cumulative mastery check.', 'I can solve unknown equations and check equality.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing equal values"}, {"term": "length", "definition": "how long an object is"}, {"term": "compare", "definition": "decide how quantities or lengths relate"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Explain that Quarter 3 mastery week brings back equations, measurement, length comparisons, and time.', 'Model one neutral example from the day''s focus, then transition quickly to independent work.', 'The Week 27 Friday assessment is cumulative. Interpret results with each competency''s existing 85% threshold and repeated-evidence rules.',
      'Quarter 3 skills include unknown equations, equal-unit measurement, comparing/ordering lengths, and telling time to the hour and half-hour.', 'Complete three brief examples together.', 'Complete review work independently.', 'Quarter 3 Reflection: identify the skill used in each problem before solving it.',
      'Quarter 3 Review — Equations and Unknowns', 'Complete the Quarter 3 review independently.', 'Complete at least 7 of 8 worksheet items correctly after corrections and prepare for the cumulative online assessment.',
      'Use normal accommodations without giving the mathematical answer.', 'Create one challenge question from today''s Quarter 3 skill.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Find ?: 7 + ? = 13', null, '6', '7+6=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Find ?: ? − 5 = 9', null, '14', '14−5=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'True or false: 8 = 3 + 5', null, 'true', 'Both sides equal 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Find ?: 16 − ? = 9', null, '7', '16−7=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Find ?: ? + 4 = 12', null, '8', '8+4=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'True or false: 9 = 13 − 5', null, 'false', '13−5=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Find ?: ? = 7 + 8', null, '15', '7+8=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      '?+6=14', null, '8', '8+6=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      '15−?=8', null, '7', '15−7=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      '?−4=10', null, '14', '14−4=10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'True or false: 6=10−4', null, 'true', '10−4=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'True or false: 12=5+6', null, 'false', '5+6=11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      '?=9+8', null, '17', '9+8=17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      '?=18−7', null, '11', '18−7=11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'What does = mean?', null, 'both sides have the same value', 'Equality means same value.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W27-D2';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently review Quarter 3 competencies 1-MATH-11 through 1-MATH-14 in preparation for the cumulative mastery check.', 'I can use repeated equal units correctly.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing equal values"}, {"term": "length", "definition": "how long an object is"}, {"term": "compare", "definition": "decide how quantities or lengths relate"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Explain that Quarter 3 mastery week brings back equations, measurement, length comparisons, and time.', 'Model one neutral example from the day''s focus, then transition quickly to independent work.', 'The Week 27 Friday assessment is cumulative. Interpret results with each competency''s existing 85% threshold and repeated-evidence rules.',
      'Quarter 3 skills include unknown equations, equal-unit measurement, comparing/ordering lengths, and telling time to the hour and half-hour.', 'Complete three brief examples together.', 'Complete review work independently.', 'Quarter 3 Reflection: identify the skill used in each problem before solving it.',
      'Quarter 3 Review — Measure Length', 'Complete the Quarter 3 review independently.', 'Complete at least 7 of 8 worksheet items correctly after corrections and prepare for the cumulative online assessment.',
      'Use normal accommodations without giving the mathematical answer.', 'Create one challenge question from today''s Quarter 3 skill.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'A strip is covered by 7 equal tiles end to end. Measurement?', null, '7 tiles', 'Count units and name unit.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Are gaps allowed in repeated-unit measurement?', null, 'no', 'Gaps leave length unmeasured.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Why should units be equal size?', null, 'so each counted unit represents the same length', 'Equal units make measurement consistent.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'A line spans 9 equal cubes. Measurement?', null, '9 cubes', 'Number plus unit.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Are overlaps allowed?', null, 'no', 'They count some length twice.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Which likely gives a larger count for same object: smaller or larger units?', null, 'smaller units', 'More small units fit.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Is ''8'' alone a complete length measurement?', null, 'no', 'The unit must be named.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Object spans 6 equal clips. Measurement?', null, '6 clips', 'Number plus unit.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Five units have a gap. Valid setup?', null, 'no', 'Unmeasured space remains.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Seven units overlap. Valid setup?', null, 'no', 'Space is double-counted.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Where should the first unit begin?', null, 'at one end of the object', 'Begin at endpoint.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Same object is 4 large blocks or 8 small blocks. Which unit is smaller?', null, 'small blocks', 'More smaller units are required.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Must units within one measurement be equal size?', null, 'yes', 'Consistency is required.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Why name the unit?', null, 'the number depends on the unit used', 'Unit gives meaning to count.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Does changing unit size necessarily change object''s actual length?', null, 'no', 'Only the numeric measurement may change.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W27-D3';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently review Quarter 3 competencies 1-MATH-11 through 1-MATH-14 in preparation for the cumulative mastery check.', 'I can compare and order lengths.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing equal values"}, {"term": "length", "definition": "how long an object is"}, {"term": "compare", "definition": "decide how quantities or lengths relate"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Explain that Quarter 3 mastery week brings back equations, measurement, length comparisons, and time.', 'Model one neutral example from the day''s focus, then transition quickly to independent work.', 'The Week 27 Friday assessment is cumulative. Interpret results with each competency''s existing 85% threshold and repeated-evidence rules.',
      'Quarter 3 skills include unknown equations, equal-unit measurement, comparing/ordering lengths, and telling time to the hour and half-hour.', 'Complete three brief examples together.', 'Complete review work independently.', 'Quarter 3 Reflection: identify the skill used in each problem before solving it.',
      'Quarter 3 Review — Compare Lengths', 'Complete the Quarter 3 review independently.', 'Complete at least 7 of 8 worksheet items correctly after corrections and prepare for the cumulative online assessment.',
      'Use normal accommodations without giving the mathematical answer.', 'Create one challenge question from today''s Quarter 3 skill.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'A is 8 units; B is 11 units. Write a comparison sentence.', null, 'A is shorter than B', '8<11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'C is longer than D; D is longer than E. Which is longest?', null, 'C', 'C>D>E.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Order 9, 6, 12 units from shortest to longest.', null, '6, 9, 12', 'Least to greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Two objects each measure 7 blocks. Compare them.', null, 'same length', 'Equal counts with same unit mean equal length.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'A is shorter than a reference; B is longer than the same reference. Which is longer?', null, 'B', 'B is above the reference.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Order 10, 4, 8 units longest to shortest.', null, '10, 8, 4', 'Greatest to least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Which is middle: 3, 9, 6 units?', null, '6 units', '6 is between 3 and 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Compare 12 and 9 units.', null, '12 units is longer', '12>9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Compare 5 and 5 units.', null, 'same length', 'The measurements are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'A>B and B>C. Which is shortest?', null, 'C', 'C is below both.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Order 4, 7, 6 units shortest to longest.', null, '4, 6, 7', 'Least to greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Order 11, 8, 9 units longest to shortest.', null, '11, 9, 8', 'Greatest to least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'A and B equal a 10-unit reference. Compare A and B.', null, 'same length', 'Both equal the same reference.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'M is shorter than N. N equals P. Which is shortest?', null, 'M', 'M<N=P.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Complete: If 9 units > 6 units, the 9-unit object is ___.', null, 'longer', 'Greater measurement with the same unit means longer.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W27-D4';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently review Quarter 3 competencies 1-MATH-11 through 1-MATH-14 in preparation for the cumulative mastery check.', 'I can read hour and half-hour times.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing equal values"}, {"term": "length", "definition": "how long an object is"}, {"term": "compare", "definition": "decide how quantities or lengths relate"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Explain that Quarter 3 mastery week brings back equations, measurement, length comparisons, and time.', 'Model one neutral example from the day''s focus, then transition quickly to independent work.', 'The Week 27 Friday assessment is cumulative. Interpret results with each competency''s existing 85% threshold and repeated-evidence rules.',
      'Quarter 3 skills include unknown equations, equal-unit measurement, comparing/ordering lengths, and telling time to the hour and half-hour.', 'Complete three brief examples together.', 'Complete review work independently.', 'Quarter 3 Reflection: identify the skill used in each problem before solving it.',
      'Quarter 3 Review — Tell Time', 'Complete the Quarter 3 review independently.', 'Complete at least 7 of 8 worksheet items correctly after corrections and prepare for the cumulative online assessment.',
      'Use normal accommodations without giving the mathematical answer.', 'Create one challenge question from today''s Quarter 3 skill.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Minute hand 12, hour hand 6. Time?', null, '6:00', 'Minute 12 means exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Minute hand 6, hour hand halfway between 6 and 7. Time?', null, '6:30', 'Minute 6 means half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Which is later: 4:00 or 4:30?', null, '4:30', 'Half past 4 occurs after 4 o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Write 8 o''clock digitally.', null, '8:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Write half past 8 digitally.', null, '8:30', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Clock: minute 12, hour 11.', null, '11:00', 'Eleven o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Clock: minute 6, hour between 11 and 12.', null, '11:30', 'Half past eleven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Time: hour 2, minute 12.', null, '2:00', 'Two o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Time: hour between 2 and 3, minute 6.', null, '2:30', 'Half past two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Which comes first: 7:00 or 7:30?', null, '7:00', 'Seven o''clock comes before half past seven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Write 9:30 in words.', null, 'half past nine', 'Thirty minutes after nine.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Write five o''clock digitally.', null, '5:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'At 10:30, where is minute hand?', null, '6', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At 10:00, where is minute hand?', null, '12', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Is 3:30 an hour or half-hour time?', null, 'half-hour time', 'The minutes are 30.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id=v_course.course_version_id
      and l.code='1-MATH-W27-D5';

    insert into public.lesson_content_versions (
      organization_id, lesson_id, revision_number, status,
      objective, student_goal, materials, vocabulary,
      teacher_introduction, teacher_modeling, teacher_notes,
      student_learn, guided_practice, independent_practice, activity,
      worksheet_title, worksheet_instructions, completion_criteria,
      accommodations, enrichment, created_by, published_by, published_at
    ) values (
      v_course.organization_id, v_lesson_id, 1, 'draft',
      'The student will independently review Quarter 3 competencies 1-MATH-11 through 1-MATH-14 in preparation for the cumulative mastery check.', 'I can bring my Quarter 3 math skills together.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "equation", "definition": "a number sentence showing equal values"}, {"term": "length", "definition": "how long an object is"}, {"term": "compare", "definition": "decide how quantities or lengths relate"}, {"term": "half-hour", "definition": "30 minutes after an hour"}]'::jsonb,
      'Explain that Quarter 3 mastery week brings back equations, measurement, length comparisons, and time.', 'Model one neutral example from the day''s focus, then transition quickly to independent work.', 'The Week 27 Friday assessment is cumulative. Interpret results with each competency''s existing 85% threshold and repeated-evidence rules.',
      'Quarter 3 skills include unknown equations, equal-unit measurement, comparing/ordering lengths, and telling time to the hour and half-hour.', 'Complete three brief examples together.', 'Complete review work independently.', 'Quarter 3 Reflection: identify the skill used in each problem before solving it.',
      'Quarter 3 Mastery Readiness', 'Complete the Quarter 3 review independently.', 'Complete at least 7 of 8 worksheet items correctly after corrections and prepare for the cumulative online assessment.',
      'Use normal accommodations without giving the mathematical answer.', 'Create one challenge question from today''s Quarter 3 skill.',
      null, null, null
    ) returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Minute hand 12, hour hand 6. Time?', null, '6:00', 'Minute 12 means exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Minute hand 6, hour hand halfway between 6 and 7. Time?', null, '6:30', 'Minute 6 means half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Which is later: 4:00 or 4:30?', null, '4:30', 'Half past 4 occurs after 4 o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Write 8 o''clock digitally.', null, '8:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Write half past 8 digitally.', null, '8:30', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Clock: minute 12, hour 11.', null, '11:00', 'Eleven o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Clock: minute 6, hour between 11 and 12.', null, '11:30', 'Half past eleven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Time: hour 2, minute 12.', null, '2:00', 'Two o''clock.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Time: hour between 2 and 3, minute 6.', null, '2:30', 'Half past two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Which comes first: 7:00 or 7:30?', null, '7:00', 'Seven o''clock comes before half past seven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Write 9:30 in words.', null, 'half past nine', 'Thirty minutes after nine.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Write five o''clock digitally.', null, '5:00', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'At 10:30, where is minute hand?', null, '6', 'Half-hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'At 10:00, where is minute hand?', null, '12', 'Exact hour.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    ) values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Is 3:30 an hour or half-hour time?', null, 'half-hour time', 'The minutes are 30.', 1
    );


    update public.lesson_content_versions
    set status='published', published_at=now(), updated_at=now()
    where id=v_version_id;


    select a.id into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id=a.lesson_id
    where a.course_version_id=v_course.course_version_id
      and a.sequence=23
      and l.week_number=23
      and l.day_number=5
      and a.active is true
    limit 1;

    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    ) values
      (v_course.organization_id,v_template_id,'1-MATH-W23-Q01',1,'multiple_choice','Which is longer: 9 units or 6 units?','[{"id": "a", "label": "9 units"}, {"id": "b", "label": "6 units"}, {"id": "c", "label": "same length"}]'::jsonb,'a',1),
      (v_course.organization_id,v_template_id,'1-MATH-W23-Q02',2,'multiple_choice','Which is shorter: 5 units or 8 units?','[{"id": "a", "label": "5 units"}, {"id": "b", "label": "8 units"}, {"id": "c", "label": "same length"}]'::jsonb,'a',1),
      (v_course.organization_id,v_template_id,'1-MATH-W23-Q03',3,'multiple_choice','Two objects each measure 7 blocks. How do they compare?','[{"id": "a", "label": "first is longer"}, {"id": "b", "label": "second is longer"}, {"id": "c", "label": "same length"}]'::jsonb,'c',1),
      (v_course.organization_id,v_template_id,'1-MATH-W23-Q04',4,'short_answer','Order shortest to longest: 5, 8, 6 units.','[]'::jsonb,'5, 6, 8',1),
      (v_course.organization_id,v_template_id,'1-MATH-W23-Q05',5,'short_answer','Order longest to shortest: 9, 4, 7 units.','[]'::jsonb,'9, 7, 4',1),
      (v_course.organization_id,v_template_id,'1-MATH-W23-Q06',6,'multiple_choice','A is longer than B, and B is longer than C. Which is shortest?','[{"id": "a", "label": "A"}, {"id": "b", "label": "B"}, {"id": "c", "label": "C"}]'::jsonb,'c',1),
      (v_course.organization_id,v_template_id,'1-MATH-W23-Q07',7,'multiple_choice','D is shorter than E, and E is shorter than F. Which is longest?','[{"id": "a", "label": "D"}, {"id": "b", "label": "E"}, {"id": "c", "label": "F"}]'::jsonb,'c',1),
      (v_course.organization_id,v_template_id,'1-MATH-W23-Q08',8,'multiple_choice','A and B both match the same 8-unit reference. How do they compare?','[{"id": "a", "label": "A longer"}, {"id": "b", "label": "B longer"}, {"id": "c", "label": "same length"}]'::jsonb,'c',1),
      (v_course.organization_id,v_template_id,'1-MATH-W23-Q09',9,'short_answer','Which is middle in length: 4, 8, 6 units?','[]'::jsonb,'6',1),
      (v_course.organization_id,v_template_id,'1-MATH-W23-Q10',10,'multiple_choice','Complete: 10 units is ___ than 7 units.','[{"id": "a", "label": "longer"}, {"id": "b", "label": "shorter"}, {"id": "c", "label": "same"}]'::jsonb,'a',1);

    insert into public.student_assignment_items (
      organization_id, student_id, student_assignment_id,
      source_template_item_id, source_code, sequence, question_type,
      prompt, options, correct_answer, points
    )
    select sa.organization_id, sa.student_id, sa.id,
           ati.id, ati.code, ati.sequence, ati.question_type,
           ati.prompt, ati.options, ati.correct_answer, ati.points
    from public.student_assignments sa
    join public.assessment_template_items ati
      on ati.assignment_template_id=sa.assignment_template_id
    where sa.assignment_template_id=v_template_id
      and sa.status='assigned'
      and not exists (
        select 1 from public.student_assignment_items sai
        where sai.student_assignment_id=sa.id
          and sai.source_template_item_id=ati.id
      );


    select a.id into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id=a.lesson_id
    where a.course_version_id=v_course.course_version_id
      and a.sequence=24
      and l.week_number=24
      and l.day_number=5
      and a.active is true
    limit 1;

    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    ) values
      (v_course.organization_id,v_template_id,'1-MATH-W24-Q01',1,'short_answer','Minute hand on 12, hour hand on 3. Time?','[]'::jsonb,'3:00',1),
      (v_course.organization_id,v_template_id,'1-MATH-W24-Q02',2,'short_answer','Minute hand on 12, hour hand on 7. Time?','[]'::jsonb,'7:00',1),
      (v_course.organization_id,v_template_id,'1-MATH-W24-Q03',3,'short_answer','Write five o''clock digitally.','[]'::jsonb,'5:00',1),
      (v_course.organization_id,v_template_id,'1-MATH-W24-Q04',4,'short_answer','Write eleven o''clock digitally.','[]'::jsonb,'11:00',1),
      (v_course.organization_id,v_template_id,'1-MATH-W24-Q05',5,'multiple_choice','At an exact hour, where does the minute hand point?','[{"id": "a", "label": "6"}, {"id": "b", "label": "12"}, {"id": "c", "label": "3"}]'::jsonb,'b',1),
      (v_course.organization_id,v_template_id,'1-MATH-W24-Q06',6,'multiple_choice','Which hand shows the hour?','[{"id": "a", "label": "hour hand"}, {"id": "b", "label": "minute hand"}]'::jsonb,'a',1),
      (v_course.organization_id,v_template_id,'1-MATH-W24-Q07',7,'multiple_choice','Which description matches 4:00?','[{"id": "a", "label": "hour hand 4, minute hand 12"}, {"id": "b", "label": "hour hand 4, minute hand 6"}]'::jsonb,'a',1),
      (v_course.organization_id,v_template_id,'1-MATH-W24-Q08',8,'short_answer','Clock: hour hand 10, minute hand 12. Time?','[]'::jsonb,'10:00',1),
      (v_course.organization_id,v_template_id,'1-MATH-W24-Q09',9,'short_answer','Write 8:00 in words.','[]'::jsonb,'eight o''clock',1),
      (v_course.organization_id,v_template_id,'1-MATH-W24-Q10',10,'multiple_choice','At 6:00, what are the minutes?','[{"id": "a", "label": "00"}, {"id": "b", "label": "30"}]'::jsonb,'a',1);

    insert into public.student_assignment_items (
      organization_id, student_id, student_assignment_id,
      source_template_item_id, source_code, sequence, question_type,
      prompt, options, correct_answer, points
    )
    select sa.organization_id, sa.student_id, sa.id,
           ati.id, ati.code, ati.sequence, ati.question_type,
           ati.prompt, ati.options, ati.correct_answer, ati.points
    from public.student_assignments sa
    join public.assessment_template_items ati
      on ati.assignment_template_id=sa.assignment_template_id
    where sa.assignment_template_id=v_template_id
      and sa.status='assigned'
      and not exists (
        select 1 from public.student_assignment_items sai
        where sai.student_assignment_id=sa.id
          and sai.source_template_item_id=ati.id
      );


    select a.id into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id=a.lesson_id
    where a.course_version_id=v_course.course_version_id
      and a.sequence=25
      and l.week_number=25
      and l.day_number=5
      and a.active is true
    limit 1;

    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    ) values
      (v_course.organization_id,v_template_id,'1-MATH-W25-Q01',1,'short_answer','Minute hand on 6, hour hand halfway between 3 and 4. Time?','[]'::jsonb,'3:30',1),
      (v_course.organization_id,v_template_id,'1-MATH-W25-Q02',2,'short_answer','Minute hand on 6, hour hand halfway between 7 and 8. Time?','[]'::jsonb,'7:30',1),
      (v_course.organization_id,v_template_id,'1-MATH-W25-Q03',3,'short_answer','Write half past five digitally.','[]'::jsonb,'5:30',1),
      (v_course.organization_id,v_template_id,'1-MATH-W25-Q04',4,'short_answer','Write 11:30 in words.','[]'::jsonb,'half past eleven',1),
      (v_course.organization_id,v_template_id,'1-MATH-W25-Q05',5,'multiple_choice','At a half-hour, where does the minute hand point?','[{"id": "a", "label": "12"}, {"id": "b", "label": "6"}, {"id": "c", "label": "3"}]'::jsonb,'b',1),
      (v_course.organization_id,v_template_id,'1-MATH-W25-Q06',6,'multiple_choice','How many minutes are in a half-hour?','[{"id": "a", "label": "15"}, {"id": "b", "label": "30"}, {"id": "c", "label": "60"}]'::jsonb,'b',1),
      (v_course.organization_id,v_template_id,'1-MATH-W25-Q07',7,'multiple_choice','At 3:30, is the hour hand exactly on 3?','[{"id": "a", "label": "yes"}, {"id": "b", "label": "no"}]'::jsonb,'b',1),
      (v_course.organization_id,v_template_id,'1-MATH-W25-Q08',8,'short_answer','Hour hand halfway between 1 and 2, minute hand 6. Time?','[]'::jsonb,'1:30',1),
      (v_course.organization_id,v_template_id,'1-MATH-W25-Q09',9,'short_answer','Write half past eight digitally.','[]'::jsonb,'8:30',1),
      (v_course.organization_id,v_template_id,'1-MATH-W25-Q10',10,'multiple_choice','Is 9:30 an hour or half-hour time?','[{"id": "a", "label": "hour"}, {"id": "b", "label": "half-hour"}]'::jsonb,'b',1);

    insert into public.student_assignment_items (
      organization_id, student_id, student_assignment_id,
      source_template_item_id, source_code, sequence, question_type,
      prompt, options, correct_answer, points
    )
    select sa.organization_id, sa.student_id, sa.id,
           ati.id, ati.code, ati.sequence, ati.question_type,
           ati.prompt, ati.options, ati.correct_answer, ati.points
    from public.student_assignments sa
    join public.assessment_template_items ati
      on ati.assignment_template_id=sa.assignment_template_id
    where sa.assignment_template_id=v_template_id
      and sa.status='assigned'
      and not exists (
        select 1 from public.student_assignment_items sai
        where sai.student_assignment_id=sa.id
          and sai.source_template_item_id=ati.id
      );


    select a.id into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id=a.lesson_id
    where a.course_version_id=v_course.course_version_id
      and a.sequence=26
      and l.week_number=26
      and l.day_number=5
      and a.active is true
    limit 1;

    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    ) values
      (v_course.organization_id,v_template_id,'1-MATH-W26-Q01',1,'short_answer','Minute hand 12, hour hand 6. Time?','[]'::jsonb,'6:00',1),
      (v_course.organization_id,v_template_id,'1-MATH-W26-Q02',2,'short_answer','Minute hand 6, hour hand halfway between 6 and 7. Time?','[]'::jsonb,'6:30',1),
      (v_course.organization_id,v_template_id,'1-MATH-W26-Q03',3,'multiple_choice','Which is later: 4:00 or 4:30?','[{"id": "a", "label": "4:00"}, {"id": "b", "label": "4:30"}]'::jsonb,'b',1),
      (v_course.organization_id,v_template_id,'1-MATH-W26-Q04',4,'short_answer','Write 8 o''clock digitally.','[]'::jsonb,'8:00',1),
      (v_course.organization_id,v_template_id,'1-MATH-W26-Q05',5,'short_answer','Write half past 8 digitally.','[]'::jsonb,'8:30',1),
      (v_course.organization_id,v_template_id,'1-MATH-W26-Q06',6,'short_answer','Write 9:30 in words.','[]'::jsonb,'half past nine',1),
      (v_course.organization_id,v_template_id,'1-MATH-W26-Q07',7,'multiple_choice','At 10:30, where is the minute hand?','[{"id": "a", "label": "12"}, {"id": "b", "label": "6"}]'::jsonb,'b',1),
      (v_course.organization_id,v_template_id,'1-MATH-W26-Q08',8,'multiple_choice','At 10:00, where is the minute hand?','[{"id": "a", "label": "12"}, {"id": "b", "label": "6"}]'::jsonb,'a',1),
      (v_course.organization_id,v_template_id,'1-MATH-W26-Q09',9,'multiple_choice','Which comes first: 7:00 or 7:30?','[{"id": "a", "label": "7:00"}, {"id": "b", "label": "7:30"}]'::jsonb,'a',1),
      (v_course.organization_id,v_template_id,'1-MATH-W26-Q10',10,'short_answer','How many minutes after 5:00 is 5:30?','[]'::jsonb,'30',1);

    insert into public.student_assignment_items (
      organization_id, student_id, student_assignment_id,
      source_template_item_id, source_code, sequence, question_type,
      prompt, options, correct_answer, points
    )
    select sa.organization_id, sa.student_id, sa.id,
           ati.id, ati.code, ati.sequence, ati.question_type,
           ati.prompt, ati.options, ati.correct_answer, ati.points
    from public.student_assignments sa
    join public.assessment_template_items ati
      on ati.assignment_template_id=sa.assignment_template_id
    where sa.assignment_template_id=v_template_id
      and sa.status='assigned'
      and not exists (
        select 1 from public.student_assignment_items sai
        where sai.student_assignment_id=sa.id
          and sai.source_template_item_id=ati.id
      );


    select a.id into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id=a.lesson_id
    where a.course_version_id=v_course.course_version_id
      and a.sequence=27
      and l.week_number=27
      and l.day_number=5
      and a.active is true
    limit 1;

    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    ) values
      (v_course.organization_id,v_template_id,'1-MATH-W27-Q01',1,'short_answer','Find ?: 7 + ? = 13','[]'::jsonb,'6',1),
      (v_course.organization_id,v_template_id,'1-MATH-W27-Q02',2,'multiple_choice','True or false: 8 = 3 + 5','[{"id": "a", "label": "true"}, {"id": "b", "label": "false"}]'::jsonb,'a',1),
      (v_course.organization_id,v_template_id,'1-MATH-W27-Q03',3,'short_answer','A strip is covered by 7 equal tiles end to end. Measurement?','[]'::jsonb,'7 tiles',1),
      (v_course.organization_id,v_template_id,'1-MATH-W27-Q04',4,'multiple_choice','Are gaps allowed in repeated-unit measurement?','[{"id": "a", "label": "yes"}, {"id": "b", "label": "no"}]'::jsonb,'b',1),
      (v_course.organization_id,v_template_id,'1-MATH-W27-Q05',5,'short_answer','Order shortest to longest: 5, 8, 6 units.','[]'::jsonb,'5, 6, 8',1),
      (v_course.organization_id,v_template_id,'1-MATH-W27-Q06',6,'multiple_choice','A is longer than B and B is longer than C. Which is shortest?','[{"id": "a", "label": "A"}, {"id": "b", "label": "B"}, {"id": "c", "label": "C"}]'::jsonb,'c',1),
      (v_course.organization_id,v_template_id,'1-MATH-W27-Q07',7,'short_answer','Minute hand on 12, hour hand on 4. Time?','[]'::jsonb,'4:00',1),
      (v_course.organization_id,v_template_id,'1-MATH-W27-Q08',8,'short_answer','Minute hand on 6, hour hand halfway between 4 and 5. Time?','[]'::jsonb,'4:30',1),
      (v_course.organization_id,v_template_id,'1-MATH-W27-Q09',9,'multiple_choice','At a half-hour, where does the minute hand point?','[{"id": "a", "label": "12"}, {"id": "b", "label": "6"}]'::jsonb,'b',1),
      (v_course.organization_id,v_template_id,'1-MATH-W27-Q10',10,'short_answer','Find ?: ? − 5 = 9','[]'::jsonb,'14',1);

    insert into public.student_assignment_items (
      organization_id, student_id, student_assignment_id,
      source_template_item_id, source_code, sequence, question_type,
      prompt, options, correct_answer, points
    )
    select sa.organization_id, sa.student_id, sa.id,
           ati.id, ati.code, ati.sequence, ati.question_type,
           ati.prompt, ati.options, ati.correct_answer, ati.points
    from public.student_assignments sa
    join public.assessment_template_items ati
      on ati.assignment_template_id=sa.assignment_template_id
    where sa.assignment_template_id=v_template_id
      and sa.status='assigned'
      and not exists (
        select 1 from public.student_assignment_items sai
        where sai.student_assignment_id=sa.id
          and sai.source_template_item_id=ati.id
      );


  end loop;
end;
$seed$;

commit;
