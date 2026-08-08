-- Homeschool Tracker
-- Migration 023: Grade 1 Mathematics Weeks 28–32 production curriculum
--
-- Week 28 : Organizing and Interpreting Data (1-MATH-15)
-- Week 29 : Representing Data (1-MATH-16)
-- Week 30 : 2D and 3D Shapes (1-MATH-17)
-- Week 31 : Halves and Fourths (1-MATH-18)
-- Week 32 : Adding Within 100 I (1-MATH-19)
--
-- Installs:
-- * 25 published lesson-content revisions
-- * 375 guided/independent/worksheet items
-- * 50 auto-scored online assessment items
--
-- Historical safety:
-- * one transaction
-- * preflight of all 25 lesson skeletons and all Friday templates
-- * refuses to overwrite published/superseded lesson content
-- * refuses to rewrite frozen student lesson deliveries
-- * refuses to overwrite existing assessment question banks
--
-- Mastery policy:
-- Optional manipulatives, drawings, physical sorting, graph drawing, shape
-- building/folding, and base-ten models support instruction but do not create a
-- separate hands-on mastery evidence requirement.

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

    for v_week in 28..32 loop
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
        raise exception 'Grade 1 Math Week % already has published lesson content. Migration 023 will not overwrite curriculum history.', v_week;
      end if;

      if exists (
        select 1
        from public.student_lesson_deliveries sld
        join public.lessons l on l.id = sld.lesson_id
        where l.course_version_id = v_course.course_version_id
          and l.week_number = v_week
      ) then
        raise exception 'Grade 1 Math Week % has frozen student deliveries. Migration 023 will not rewrite delivered curriculum.', v_week;
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
        select 1 from public.assessment_template_items ati
        where ati.assignment_template_id = v_template_id
      ) then
        raise exception 'Grade 1 Math Week % already has an online question bank. Migration 023 will not overwrite assessment history.', v_week;
      end if;
    end loop;

    delete from public.lesson_content_versions lcv
    using public.lessons l
    where lcv.lesson_id = l.id
      and l.course_version_id = v_course.course_version_id
      and l.week_number between 28 and 32
      and lcv.status = 'draft';


    -- Week 28, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W28-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W28-D1 was not found.';
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
      'The student will sort data into categories, count each category, and answer total and comparison questions from organized data.', 'I can sort information into categories and count each group.',
      '["pencil", "paper", "optional category cards or counters"]'::jsonb, '[{"term": "data", "definition": "information that has been collected"}, {"term": "category", "definition": "a group of items that belong together"}, {"term": "table", "definition": "an organized way to show data in rows or columns"}, {"term": "total", "definition": "how many there are altogether"}]'::jsonb,
      'Introduce data as information we collect and organize so patterns and comparisons are easier to see.', 'Model sorting a small list into categories, counting each group, and using the counts to answer a comparison question.', 'A physical sort can be useful during instruction, but mastery remains based on repeated qualifying evidence rather than a required hands-on task.',
      'First organize the data. Then read the category counts carefully. Use addition for totals and subtraction for how many more or fewer.', 'Work through three category/table questions together.', 'Complete data interpretation independently.',
      'Optional Survey Sort: collect a few household preferences and organize them into a small tally or table.', 'Sort Data into Categories',
      'Read or organize the data, then answer each question.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately answer at least one total and one comparison question.',
      'Read the data aloud and use a simple table template when needed.', 'Create a three-category data set and write one total and one comparison question.',
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
      'Sort these pets into categories: dog, cat, dog, fish, cat. How many categories are there?', null,
      '3', 'The categories are dog, cat, and fish.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Data: red, blue, red, green, red. How many red items?', null,
      '3', 'Red appears three times.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Data: apple, banana, apple, apple, banana. How many bananas?', null,
      '2', 'Banana appears twice.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Data: cat, dog, cat, bird, dog, cat. How many cats?', null,
      '3', 'Cat appears three times.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Data: circle, square, square, triangle. How many squares?', null,
      '2', 'Square appears twice.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Data: red, red, blue, blue, blue. Which category has more?', null,
      'blue', 'Blue has 3; red has 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Data: apple, pear, pear, apple. How many total items?', null,
      '4', 'There are four data points.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Data: dog, dog, cat. How many dogs?', null,
      '2', 'Dog appears twice.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Data: red, green, red, blue. How many red?', null,
      '2', 'Red appears twice.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Data: apple, apple, banana, pear. How many categories?', null,
      '3', 'Apple, banana, pear.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Data: bus, car, car, bike, car. Which category appears most?', null,
      'car', 'Car appears three times.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Data: circle, triangle, circle, triangle. How many total?', null,
      '4', 'Four shapes were recorded.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Data: milk, water, water, juice. How many water?', null,
      '2', 'Water appears twice.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Data: cat, cat, dog, dog. Which categories are tied?', null,
      'cat and dog', 'Both have two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Data: red, blue, green, red, blue. How many different categories?', null,
      '3', 'Red, blue, green.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 28, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W28-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W28-D2 was not found.';
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
      'The student will sort data into categories, count each category, and answer total and comparison questions from organized data.', 'I can read counts from a simple data table.',
      '["pencil", "paper", "optional category cards or counters"]'::jsonb, '[{"term": "data", "definition": "information that has been collected"}, {"term": "category", "definition": "a group of items that belong together"}, {"term": "table", "definition": "an organized way to show data in rows or columns"}, {"term": "total", "definition": "how many there are altogether"}]'::jsonb,
      'Introduce data as information we collect and organize so patterns and comparisons are easier to see.', 'Model sorting a small list into categories, counting each group, and using the counts to answer a comparison question.', 'A physical sort can be useful during instruction, but mastery remains based on repeated qualifying evidence rather than a required hands-on task.',
      'First organize the data. Then read the category counts carefully. Use addition for totals and subtraction for how many more or fewer.', 'Work through three category/table questions together.', 'Complete data interpretation independently.',
      'Optional Survey Sort: collect a few household preferences and organize them into a small tally or table.', 'Read a Data Table',
      'Read or organize the data, then answer each question.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately answer at least one total and one comparison question.',
      'Read the data aloud and use a simple table template when needed.', 'Create a three-category data set and write one total and one comparison question.',
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
      'Table: Apples 4, Bananas 2, Pears 3. How many apples?', null,
      '4', 'Read the Apples row.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Table: Red 5, Blue 3, Green 2. Which has the most?', null,
      'Red', 'Five is the greatest count.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Table: Cats 2, Dogs 4, Fish 1. How many animals total?', null,
      '7', '2+4+1=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Table: Soccer 3, Basketball 5, Baseball 2. Which has the fewest?', null,
      'Baseball', 'Two is the smallest count.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Table: Apple 6, Banana 4. How many more apples than bananas?', null,
      '2', '6−4=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Table: Red 2, Blue 5. How many fewer red than blue?', null,
      '3', '5−2=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Table: Cats 3, Dogs 3, Fish 2. Which categories are tied?', null,
      'Cats and Dogs', 'Both have three.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Table: A=4, B=6. How many more B than A?', null,
      '2', '6−4=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Table: A=7, B=2. How many fewer B than A?', null,
      '5', '7−2=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Table: Red=3, Blue=4, Green=2. Total?', null,
      '9', '3+4+2=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Table: Cats=5, Dogs=1. Which has more?', null,
      'Cats', '5>1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Table: Apples=2, Pears=2. Compare counts.', null,
      'same number', 'Both counts are 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Table: Cars=6, Bikes=3. Difference?', null,
      '3', '6−3=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Table: Books=4, Games=5, Puzzles=1. Which is greatest?', null,
      'Games', '5 is greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Table: Books=4, Games=5, Puzzles=1. Which is least?', null,
      'Puzzles', '1 is least.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 28, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W28-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W28-D3 was not found.';
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
      'The student will sort data into categories, count each category, and answer total and comparison questions from organized data.', 'I can answer how many more, how many fewer, and how many total.',
      '["pencil", "paper", "optional category cards or counters"]'::jsonb, '[{"term": "data", "definition": "information that has been collected"}, {"term": "category", "definition": "a group of items that belong together"}, {"term": "table", "definition": "an organized way to show data in rows or columns"}, {"term": "total", "definition": "how many there are altogether"}]'::jsonb,
      'Introduce data as information we collect and organize so patterns and comparisons are easier to see.', 'Model sorting a small list into categories, counting each group, and using the counts to answer a comparison question.', 'A physical sort can be useful during instruction, but mastery remains based on repeated qualifying evidence rather than a required hands-on task.',
      'First organize the data. Then read the category counts carefully. Use addition for totals and subtraction for how many more or fewer.', 'Work through three category/table questions together.', 'Complete data interpretation independently.',
      'Optional Survey Sort: collect a few household preferences and organize them into a small tally or table.', 'Compare Data Categories',
      'Read or organize the data, then answer each question.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately answer at least one total and one comparison question.',
      'Read the data aloud and use a simple table template when needed.', 'Create a three-category data set and write one total and one comparison question.',
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
      'Red has 6 votes and blue has 4. How many more votes does red have?', null,
      '2', '6−4=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Cats have 3 votes and dogs have 7. How many fewer votes do cats have?', null,
      '4', '7−3=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Apples 5, Bananas 2, Pears 3. How many fruit choices total?', null,
      '10', '5+2+3=10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Soccer 8, Basketball 5. Difference?', null,
      '3', '8−5=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Red 4, Green 4. How do the counts compare?', null,
      'same number', 'Both are 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Cats 6, Dogs 2, Fish 1. Total?', null,
      '9', '6+2+1=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Books 7, Games 3. How many fewer games?', null,
      '4', '7−3=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'A=5, B=3. How many more A?', null,
      '2', '5−3=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'A=2, B=6. How many fewer A?', null,
      '4', '6−2=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'A=4, B=4. Difference?', null,
      '0', 'Equal counts differ by zero.', 1
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
      'Cats=1, Dogs=5. How many more dogs?', null,
      '4', '5−1=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Cars=7, Bikes=4. Difference?', null,
      '3', '7−4=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Apples=6, Pears=2. How many fewer pears?', null,
      '4', '6−2=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Books=3, Games=3, Puzzles=2. Total?', null,
      '8', '3+3+2=8.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 28, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W28-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W28-D4 was not found.';
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
      'The student will sort data into categories, count each category, and answer total and comparison questions from organized data.', 'I can use organized data to answer different questions.',
      '["pencil", "paper", "optional category cards or counters"]'::jsonb, '[{"term": "data", "definition": "information that has been collected"}, {"term": "category", "definition": "a group of items that belong together"}, {"term": "table", "definition": "an organized way to show data in rows or columns"}, {"term": "total", "definition": "how many there are altogether"}]'::jsonb,
      'Introduce data as information we collect and organize so patterns and comparisons are easier to see.', 'Model sorting a small list into categories, counting each group, and using the counts to answer a comparison question.', 'A physical sort can be useful during instruction, but mastery remains based on repeated qualifying evidence rather than a required hands-on task.',
      'First organize the data. Then read the category counts carefully. Use addition for totals and subtraction for how many more or fewer.', 'Work through three category/table questions together.', 'Complete data interpretation independently.',
      'Optional Survey Sort: collect a few household preferences and organize them into a small tally or table.', 'Interpret Mixed Data',
      'Read or organize the data, then answer each question.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately answer at least one total and one comparison question.',
      'Read the data aloud and use a simple table template when needed.', 'Create a three-category data set and write one total and one comparison question.',
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
      'Data: red, blue, red, green, red, blue. How many red?', null,
      '3', 'Red appears three times.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Table: Cats=4, Dogs=6. How many more dogs?', null,
      '2', '6−4=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Table: Apples=3, Bananas=2, Pears=4. Total?', null,
      '9', '3+2+4=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Data: circle, square, square, circle, triangle. Which category has the most?', null,
      'circle and square', 'Both appear twice.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Table: Red=5, Blue=2. How many fewer blue?', null,
      '3', '5−2=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Table: Books=2, Games=6, Puzzles=3. Greatest category?', null,
      'Games', '6 is greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Table: Cats=3, Dogs=3. Compare counts.', null,
      'same number', 'Both have 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Data: apple, apple, pear, banana, apple. How many apples?', null,
      '3', 'Apple appears three times.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Table: A=6, B=4. Difference?', null,
      '2', '6−4=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Table: A=2, B=5. How many more B?', null,
      '3', '5−2=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Table: Red=4, Blue=3, Green=1. Total?', null,
      '8', '4+3+1=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Data: cat, dog, fish, dog. Which appears most?', null,
      'dog', 'Dog appears twice.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Table: Cars=5, Bikes=5. Compare.', null,
      'same number', 'Both equal 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Table: Apples=7, Pears=2. How many fewer pears?', null,
      '5', '7−2=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Table: Books=4, Games=3, Puzzles=2. Total?', null,
      '9', '4+3+2=9.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 28, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W28-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W28-D5 was not found.';
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
      'The student will sort data into categories, count each category, and answer total and comparison questions from organized data.', 'I can organize and interpret data independently.',
      '["pencil", "paper", "optional category cards or counters"]'::jsonb, '[{"term": "data", "definition": "information that has been collected"}, {"term": "category", "definition": "a group of items that belong together"}, {"term": "table", "definition": "an organized way to show data in rows or columns"}, {"term": "total", "definition": "how many there are altogether"}]'::jsonb,
      'Introduce data as information we collect and organize so patterns and comparisons are easier to see.', 'Model sorting a small list into categories, counting each group, and using the counts to answer a comparison question.', 'A physical sort can be useful during instruction, but mastery remains based on repeated qualifying evidence rather than a required hands-on task.',
      'First organize the data. Then read the category counts carefully. Use addition for totals and subtraction for how many more or fewer.', 'Work through three category/table questions together.', 'Complete data interpretation independently.',
      'Optional Survey Sort: collect a few household preferences and organize them into a small tally or table.', 'Week 28 Data Readiness',
      'Read or organize the data, then answer each question.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately answer at least one total and one comparison question.',
      'Read the data aloud and use a simple table template when needed.', 'Create a three-category data set and write one total and one comparison question.',
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
      'Data: red, blue, red, green, red, blue. How many red?', null,
      '3', 'Red appears three times.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Table: Cats=4, Dogs=6. How many more dogs?', null,
      '2', '6−4=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Table: Apples=3, Bananas=2, Pears=4. Total?', null,
      '9', '3+2+4=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Data: circle, square, square, circle, triangle. Which category has the most?', null,
      'circle and square', 'Both appear twice.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Table: Red=5, Blue=2. How many fewer blue?', null,
      '3', '5−2=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Table: Books=2, Games=6, Puzzles=3. Greatest category?', null,
      'Games', '6 is greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Table: Cats=3, Dogs=3. Compare counts.', null,
      'same number', 'Both have 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Data: apple, apple, pear, banana, apple. How many apples?', null,
      '3', 'Apple appears three times.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Table: A=6, B=4. Difference?', null,
      '2', '6−4=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Table: A=2, B=5. How many more B?', null,
      '3', '5−2=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Table: Red=4, Blue=3, Green=1. Total?', null,
      '8', '4+3+1=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Data: cat, dog, fish, dog. Which appears most?', null,
      'dog', 'Dog appears twice.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Table: Cars=5, Bikes=5. Compare.', null,
      'same number', 'Both equal 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Table: Apples=7, Pears=2. How many fewer pears?', null,
      '5', '7−2=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Table: Books=4, Games=3, Puzzles=2. Total?', null,
      '9', '4+3+2=9.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 29, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W29-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W29-D1 was not found.';
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
      'The student will create or complete a picture representation, chart, or simple graph from a small data set and use it to answer questions.', 'I can represent counts with one symbol for each data item.',
      '["pencil", "paper", "optional graph template or colored squares"]'::jsonb, '[{"term": "graph", "definition": "a visual display that shows data"}, {"term": "picture graph", "definition": "a graph that uses pictures or symbols to represent data"}, {"term": "chart", "definition": "an organized display of information"}, {"term": "category", "definition": "a group represented in the data display"}]'::jsonb,
      'Connect Week 28 organized data to a new representation: the same counts can be displayed visually in a chart or graph.', 'Model a one-for-one picture graph where each symbol represents one response, then answer a question from the display.', 'The online lesson uses text-described one-for-one graphs so it remains accessible without image dependence. Drawing a graph remains a useful optional activity.',
      'A graph must match the original data. Label categories, represent each count consistently, then use the display to compare and total values.', 'Complete and interpret three simple displays together.', 'Represent or interpret data independently.',
      'Optional Graph It: choose a small three-category data set and draw one square for each item.', 'Complete a Picture Graph',
      'Represent the data or use the graph counts to answer each question.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately connect a data count to its graph representation.',
      'Provide a labeled graph template and keep one-symbol-equals-one-item examples visible during guided work.', 'Create a three-category graph and write two questions someone could answer from it.',
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
      'Data: Cats 3, Dogs 5. A picture graph uses 1 star for each pet. How many stars should Cats have?', null,
      '3', 'One symbol represents one data item.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Data: Red 4, Blue 2. How many symbols should Blue have if 1 symbol = 1 vote?', null,
      '2', 'Two votes require two symbols.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Data: Apples 5, Pears 3. Which graph row should be longer?', null,
      'Apples', 'Five is greater than three.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Data: Soccer 6, Basketball 4. How many symbols for Soccer?', null,
      '6', 'One symbol per response.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Data: Cats 2, Dogs 2. Should the rows be the same length?', null,
      'yes', 'Equal counts produce equal rows.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Data: Red 3, Blue 5, Green 1. Which row is shortest?', null,
      'Green', 'One is the smallest count.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Data: Books 4, Games 6. How many more symbols are in Games?', null,
      '2', '6−4=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'A=4 with 1 symbol per item. Symbols needed?', null,
      '4', 'One-for-one representation.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'B=7. Symbols needed?', null,
      '7', 'Seven items need seven symbols.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'C=2. Symbols needed?', null,
      '2', 'Two items need two symbols.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'If Red has 5 symbols and Blue has 3, which category has more?', null,
      'Red', '5>3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'If Cats and Dogs each have 4 symbols, compare.', null,
      'same number', 'Equal symbols show equal counts.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'A graph row has 6 symbols. What count does it show if 1 symbol=1 item?', null,
      '6', 'Each symbol counts one.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'A graph row has 3 symbols. Another has 5. Difference?', null,
      '2', '5−3=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why should every symbol represent the same amount?', null,
      'so the graph represents the data consistently', 'Consistent symbols make comparisons valid.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 29, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W29-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W29-D2 was not found.';
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
      'The student will create or complete a picture representation, chart, or simple graph from a small data set and use it to answer questions.', 'I can answer questions using a simple graph.',
      '["pencil", "paper", "optional graph template or colored squares"]'::jsonb, '[{"term": "graph", "definition": "a visual display that shows data"}, {"term": "picture graph", "definition": "a graph that uses pictures or symbols to represent data"}, {"term": "chart", "definition": "an organized display of information"}, {"term": "category", "definition": "a group represented in the data display"}]'::jsonb,
      'Connect Week 28 organized data to a new representation: the same counts can be displayed visually in a chart or graph.', 'Model a one-for-one picture graph where each symbol represents one response, then answer a question from the display.', 'The online lesson uses text-described one-for-one graphs so it remains accessible without image dependence. Drawing a graph remains a useful optional activity.',
      'A graph must match the original data. Label categories, represent each count consistently, then use the display to compare and total values.', 'Complete and interpret three simple displays together.', 'Represent or interpret data independently.',
      'Optional Graph It: choose a small three-category data set and draw one square for each item.', 'Read and Interpret a Graph',
      'Represent the data or use the graph counts to answer each question.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately connect a data count to its graph representation.',
      'Provide a labeled graph template and keep one-symbol-equals-one-item examples visible during guided work.', 'Create a three-category graph and write two questions someone could answer from it.',
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
      'Picture graph: Cats ★★★, Dogs ★★★★★. Which has more?', null,
      'Dogs', 'Dogs has five symbols; Cats has three.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Picture graph: Red ★★★★, Blue ★★. How many more Red?', null,
      '2', '4−2=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Picture graph: Apples ★★★, Pears ★★★. Compare.', null,
      'same number', 'Both have three.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Graph: A=6 symbols, B=4 symbols. Difference?', null,
      '2', '6−4=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Graph: Books=2, Games=5, Puzzles=3. Which is greatest?', null,
      'Games', 'Five is greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Graph: Cats=4, Dogs=1. How many total?', null,
      '5', '4+1=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Graph: Red=3, Blue=2, Green=4. Total?', null,
      '9', '3+2+4=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Graph counts: A=5, B=2. How many more A?', null,
      '3', '5−2=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Graph counts: A=2, B=6. How many fewer A?', null,
      '4', '6−2=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Graph counts: A=4, B=4. Difference?', null,
      '0', 'Equal categories differ by 0.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Graph counts: Red=3, Blue=1, Green=2. Total?', null,
      '6', '3+1+2=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Graph counts: Cats=5, Dogs=2. Which has more?', null,
      'Cats', '5>2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Graph counts: Books=1, Games=4, Puzzles=3. Greatest?', null,
      'Games', '4 is greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Graph counts: Cars=3, Bikes=5. Difference?', null,
      '2', '5−3=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Graph counts: Apples=4, Pears=4. Compare.', null,
      'same number', 'Both counts equal 4.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 29, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W29-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W29-D3 was not found.';
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
      'The student will create or complete a picture representation, chart, or simple graph from a small data set and use it to answer questions.', 'I can turn a small data set into a chart or graph.',
      '["pencil", "paper", "optional graph template or colored squares"]'::jsonb, '[{"term": "graph", "definition": "a visual display that shows data"}, {"term": "picture graph", "definition": "a graph that uses pictures or symbols to represent data"}, {"term": "chart", "definition": "an organized display of information"}, {"term": "category", "definition": "a group represented in the data display"}]'::jsonb,
      'Connect Week 28 organized data to a new representation: the same counts can be displayed visually in a chart or graph.', 'Model a one-for-one picture graph where each symbol represents one response, then answer a question from the display.', 'The online lesson uses text-described one-for-one graphs so it remains accessible without image dependence. Drawing a graph remains a useful optional activity.',
      'A graph must match the original data. Label categories, represent each count consistently, then use the display to compare and total values.', 'Complete and interpret three simple displays together.', 'Represent or interpret data independently.',
      'Optional Graph It: choose a small three-category data set and draw one square for each item.', 'Create a Simple Data Display',
      'Represent the data or use the graph counts to answer each question.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately connect a data count to its graph representation.',
      'Provide a labeled graph template and keep one-symbol-equals-one-item examples visible during guided work.', 'Create a three-category graph and write two questions someone could answer from it.',
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
      'Data set: Red=3, Blue=5. If you draw one box per response, how many boxes go in Blue?', null,
      '5', 'Represent the count exactly.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Data set: Cats=4, Dogs=2. Which graph row should contain 4 symbols?', null,
      'Cats', 'Cats has count 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Data: A=2, B=2. What should be true about row lengths?', null,
      'they should be equal', 'Equal counts need equal representation.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Data: Apples=6, Pears=3. How many marks for Apples?', null,
      '6', 'One mark per item.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Data: Books=2, Games=5, Puzzles=1. Which row will be shortest?', null,
      'Puzzles', 'One is least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Data: Red=4, Blue=3. After graphing, how many total symbols?', null,
      '7', '4+3=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Why label each category on a graph?', null,
      'so the reader knows what each row or group represents', 'Labels identify categories.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Create one-for-one graph count for A=3. Symbols?', null,
      '3', 'Three items need three symbols.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Create one-for-one graph count for B=5. Symbols?', null,
      '5', 'Five items need five symbols.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Create one-for-one graph count for C=1. Symbols?', null,
      '1', 'One item needs one symbol.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Which category should be tallest/longest: A=2, B=7, C=4?', null,
      'B', '7 is greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Which should be shortest: A=2, B=7, C=4?', null,
      'A', '2 is least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'If two categories each have 6, how should their graph lengths compare?', null,
      'same length', 'Equal counts require equal display lengths.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'What should 1 symbol mean in a one-for-one picture graph?', null,
      '1 data item', 'Each symbol represents one item.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why must graph data match the original counts?', null,
      'so the graph accurately represents the data', 'A graph is only useful when it preserves the data.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 29, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W29-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W29-D4 was not found.';
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
      'The student will create or complete a picture representation, chart, or simple graph from a small data set and use it to answer questions.', 'I can create, read, and compare data displays.',
      '["pencil", "paper", "optional graph template or colored squares"]'::jsonb, '[{"term": "graph", "definition": "a visual display that shows data"}, {"term": "picture graph", "definition": "a graph that uses pictures or symbols to represent data"}, {"term": "chart", "definition": "an organized display of information"}, {"term": "category", "definition": "a group represented in the data display"}]'::jsonb,
      'Connect Week 28 organized data to a new representation: the same counts can be displayed visually in a chart or graph.', 'Model a one-for-one picture graph where each symbol represents one response, then answer a question from the display.', 'The online lesson uses text-described one-for-one graphs so it remains accessible without image dependence. Drawing a graph remains a useful optional activity.',
      'A graph must match the original data. Label categories, represent each count consistently, then use the display to compare and total values.', 'Complete and interpret three simple displays together.', 'Represent or interpret data independently.',
      'Optional Graph It: choose a small three-category data set and draw one square for each item.', 'Use Graphs to Compare Data',
      'Represent the data or use the graph counts to answer each question.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately connect a data count to its graph representation.',
      'Provide a labeled graph template and keep one-symbol-equals-one-item examples visible during guided work.', 'Create a three-category graph and write two questions someone could answer from it.',
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
      'Graph counts: Cats=3, Dogs=5. Difference?', null,
      '2', '5−3=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Data: Red=4, Blue=2. How many one-for-one symbols for Red?', null,
      '4', 'One symbol per response.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Graph counts: Apples=2, Pears=3, Bananas=4. Total?', null,
      '9', '2+3+4=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Data A=6, B=1. Which graph row is longest?', null,
      'A', '6 is greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Graph Red=3, Blue=3. Compare.', null,
      'same number', 'Equal counts.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Graph Cats=5, Dogs=2. How many fewer Dogs?', null,
      '3', '5−2=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Data Books=4, Games=2. Total graph symbols?', null,
      '6', '4+2=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'A graph shows A=5, B=3. Difference?', null,
      '2', '5−3=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Data A=2, B=4. Symbols for B?', null,
      '4', 'One-for-one representation.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Graph A=1, B=6, C=3. Greatest?', null,
      'B', '6 is greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Graph A=1, B=6, C=3. Least?', null,
      'A', '1 is least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Graph Cats=4, Dogs=4. Compare.', null,
      'same number', 'Both equal 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Data Red=2, Blue=5, Green=1. Total symbols?', null,
      '8', '2+5+1=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Graph Apples=6, Pears=2. How many more Apples?', null,
      '4', '6−2=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why is a graph useful?', null,
      'it makes data easier to see and compare', 'Visual organization supports interpretation.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 29, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W29-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W29-D5 was not found.';
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
      'The student will create or complete a picture representation, chart, or simple graph from a small data set and use it to answer questions.', 'I can represent and interpret data independently.',
      '["pencil", "paper", "optional graph template or colored squares"]'::jsonb, '[{"term": "graph", "definition": "a visual display that shows data"}, {"term": "picture graph", "definition": "a graph that uses pictures or symbols to represent data"}, {"term": "chart", "definition": "an organized display of information"}, {"term": "category", "definition": "a group represented in the data display"}]'::jsonb,
      'Connect Week 28 organized data to a new representation: the same counts can be displayed visually in a chart or graph.', 'Model a one-for-one picture graph where each symbol represents one response, then answer a question from the display.', 'The online lesson uses text-described one-for-one graphs so it remains accessible without image dependence. Drawing a graph remains a useful optional activity.',
      'A graph must match the original data. Label categories, represent each count consistently, then use the display to compare and total values.', 'Complete and interpret three simple displays together.', 'Represent or interpret data independently.',
      'Optional Graph It: choose a small three-category data set and draw one square for each item.', 'Week 29 Graph Readiness',
      'Represent the data or use the graph counts to answer each question.', 'Complete at least 7 of 8 worksheet items correctly after corrections and accurately connect a data count to its graph representation.',
      'Provide a labeled graph template and keep one-symbol-equals-one-item examples visible during guided work.', 'Create a three-category graph and write two questions someone could answer from it.',
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
      'Graph counts: Cats=3, Dogs=5. Difference?', null,
      '2', '5−3=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Data: Red=4, Blue=2. How many one-for-one symbols for Red?', null,
      '4', 'One symbol per response.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Graph counts: Apples=2, Pears=3, Bananas=4. Total?', null,
      '9', '2+3+4=9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Data A=6, B=1. Which graph row is longest?', null,
      'A', '6 is greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Graph Red=3, Blue=3. Compare.', null,
      'same number', 'Equal counts.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Graph Cats=5, Dogs=2. How many fewer Dogs?', null,
      '3', '5−2=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Data Books=4, Games=2. Total graph symbols?', null,
      '6', '4+2=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'A graph shows A=5, B=3. Difference?', null,
      '2', '5−3=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Data A=2, B=4. Symbols for B?', null,
      '4', 'One-for-one representation.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Graph A=1, B=6, C=3. Greatest?', null,
      'B', '6 is greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Graph A=1, B=6, C=3. Least?', null,
      'A', '1 is least.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Graph Cats=4, Dogs=4. Compare.', null,
      'same number', 'Both equal 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Data Red=2, Blue=5, Green=1. Total symbols?', null,
      '8', '2+5+1=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Graph Apples=6, Pears=2. How many more Apples?', null,
      '4', '6−2=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why is a graph useful?', null,
      'it makes data easier to see and compare', 'Visual organization supports interpretation.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 30, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W30-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W30-D1 was not found.';
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
      'The student will identify defining attributes of common 2D and 3D shapes and reason about composing larger shapes from smaller shapes.', 'I can identify 2D shapes by their defining attributes.',
      '["pencil", "paper", "optional shape cutouts or blocks"]'::jsonb, '[{"term": "attribute", "definition": "a feature that describes a shape"}, {"term": "side", "definition": "a straight edge of a 2D shape"}, {"term": "vertex", "definition": "a corner where edges meet"}, {"term": "face", "definition": "a flat surface of a 3D shape"}, {"term": "compose", "definition": "put smaller shapes together to make a larger shape"}]'::jsonb,
      'Focus on attributes that define shapes rather than color, size, or orientation.', 'Model naming a shape from its sides/vertices/faces and show how smaller shapes can form a larger outside boundary.', 'Drawing/building shapes is useful instructionally but is not installed as a separate mastery-evidence requirement.',
      'Shapes are identified by defining attributes. For 2D shapes, look at sides and vertices. For 3D shapes, look at flat faces and curved surfaces. When composing, inspect the outside boundary.', 'Reason through three shape examples together.', 'Complete shape identification and composition reasoning independently.',
      'Optional Shape Builder: use paper shapes or blocks to compose a larger shape and describe the outside boundary.', 'Describe 2D Shapes',
      'Use defining attributes to identify or reason about each shape.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one shape using defining attributes.',
      'Use labeled shape reference diagrams during guided practice.', 'Find two different ways to compose the same larger rectangle from smaller shapes.',
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
      'Which 2D shape has 3 straight sides and 3 vertices?', null,
      'triangle', 'A triangle has three sides and three corners.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Which 2D shape has 4 equal sides and 4 vertices?', null,
      'square', 'A square has four equal sides.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Which shape has no straight sides and no vertices?', null,
      'circle', 'A circle is curved with no corners.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'How many sides does a rectangle have?', null,
      '4', 'A rectangle has four sides.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'How many vertices does a triangle have?', null,
      '3', 'A triangle has three vertices.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Does a square have straight or curved sides?', null,
      'straight', 'All square sides are straight.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Name a 2D shape with 4 sides.', null,
      'rectangle', 'Square is also acceptable because it has four sides.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Triangle: number of sides?', null,
      '3', 'Three sides.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Square: number of sides?', null,
      '4', 'Four sides.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Rectangle: number of vertices?', null,
      '4', 'Four corners.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Circle: number of vertices?', null,
      '0', 'No corners.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Which has more sides, triangle or rectangle?', null,
      'rectangle', '4>3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Which has all equal sides: square or general rectangle?', null,
      'square', 'A square has four equal sides.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Which shape is curved all the way around?', null,
      'circle', 'Circle has a curved boundary.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'What is an attribute?', null,
      'a feature that describes a shape', 'Attributes tell what a shape is like.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 30, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W30-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W30-D2 was not found.';
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
      'The student will identify defining attributes of common 2D and 3D shapes and reason about composing larger shapes from smaller shapes.', 'I can identify common 3D shapes by their faces and surfaces.',
      '["pencil", "paper", "optional shape cutouts or blocks"]'::jsonb, '[{"term": "attribute", "definition": "a feature that describes a shape"}, {"term": "side", "definition": "a straight edge of a 2D shape"}, {"term": "vertex", "definition": "a corner where edges meet"}, {"term": "face", "definition": "a flat surface of a 3D shape"}, {"term": "compose", "definition": "put smaller shapes together to make a larger shape"}]'::jsonb,
      'Focus on attributes that define shapes rather than color, size, or orientation.', 'Model naming a shape from its sides/vertices/faces and show how smaller shapes can form a larger outside boundary.', 'Drawing/building shapes is useful instructionally but is not installed as a separate mastery-evidence requirement.',
      'Shapes are identified by defining attributes. For 2D shapes, look at sides and vertices. For 3D shapes, look at flat faces and curved surfaces. When composing, inspect the outside boundary.', 'Reason through three shape examples together.', 'Complete shape identification and composition reasoning independently.',
      'Optional Shape Builder: use paper shapes or blocks to compose a larger shape and describe the outside boundary.', 'Describe 3D Shapes',
      'Use defining attributes to identify or reason about each shape.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one shape using defining attributes.',
      'Use labeled shape reference diagrams during guided practice.', 'Find two different ways to compose the same larger rectangle from smaller shapes.',
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
      'Which 3D shape has 6 square faces?', null,
      'cube', 'A cube has six square faces.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Which 3D shape is round like a ball?', null,
      'sphere', 'A sphere has a curved surface.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Which 3D shape has two circular faces and one curved surface?', null,
      'cylinder', 'A cylinder has two circular ends.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Which shape can roll easily: cube or sphere?', null,
      'sphere', 'A sphere has a curved surface.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'How many square faces does a cube have?', null,
      '6', 'Six square faces.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Which has circular faces: cylinder or cube?', null,
      'cylinder', 'A cylinder has circular ends.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Name one 3D shape with a curved surface.', null,
      'sphere', 'Cylinder also has a curved surface.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Cube: faces are what 2D shape?', null,
      'squares', 'Cube faces are squares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Sphere: flat faces?', null,
      '0', 'A sphere has no flat faces.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Cylinder: number of circular faces?', null,
      '2', 'Two circular ends.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Which resembles a can?', null,
      'cylinder', 'A can is cylinder-shaped.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Which resembles a ball?', null,
      'sphere', 'A ball is sphere-shaped.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Which resembles a die?', null,
      'cube', 'A die is cube-shaped.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Which has only flat square faces?', null,
      'cube', 'All six faces are squares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Which has one continuous curved surface and no edges like a ball?', null,
      'sphere', 'This describes a sphere.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 30, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W30-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W30-D3 was not found.';
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
      'The student will identify defining attributes of common 2D and 3D shapes and reason about composing larger shapes from smaller shapes.', 'I can put smaller shapes together and identify the larger shape.',
      '["pencil", "paper", "optional shape cutouts or blocks"]'::jsonb, '[{"term": "attribute", "definition": "a feature that describes a shape"}, {"term": "side", "definition": "a straight edge of a 2D shape"}, {"term": "vertex", "definition": "a corner where edges meet"}, {"term": "face", "definition": "a flat surface of a 3D shape"}, {"term": "compose", "definition": "put smaller shapes together to make a larger shape"}]'::jsonb,
      'Focus on attributes that define shapes rather than color, size, or orientation.', 'Model naming a shape from its sides/vertices/faces and show how smaller shapes can form a larger outside boundary.', 'Drawing/building shapes is useful instructionally but is not installed as a separate mastery-evidence requirement.',
      'Shapes are identified by defining attributes. For 2D shapes, look at sides and vertices. For 3D shapes, look at flat faces and curved surfaces. When composing, inspect the outside boundary.', 'Reason through three shape examples together.', 'Complete shape identification and composition reasoning independently.',
      'Optional Shape Builder: use paper shapes or blocks to compose a larger shape and describe the outside boundary.', 'Compose Larger Shapes',
      'Use defining attributes to identify or reason about each shape.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one shape using defining attributes.',
      'Use labeled shape reference diagrams during guided practice.', 'Find two different ways to compose the same larger rectangle from smaller shapes.',
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
      'Two congruent right triangles can be put together to make which common 4-sided shape?', null,
      'square', 'Two matching right triangles can compose a square in a suitable arrangement.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Two squares side by side make what larger common 2D shape?', null,
      'rectangle', 'The outside boundary forms a rectangle.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Four equal squares arranged 2 by 2 compose what larger shape?', null,
      'square', 'The outside boundary has four equal sides.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'If two equal rectangles are stacked evenly, can they compose a larger rectangle?', null,
      'yes', 'The outer boundary remains rectangular.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'If a square is cut diagonally corner to corner, what two shapes are made?', null,
      'triangles', 'A diagonal divides a square into two triangles.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Can smaller shapes be combined to make a larger shape?', null,
      'yes', 'That is composing shapes.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'What should you inspect after composing shapes?', null,
      'the outside boundary and its attributes', 'The outer sides/vertices identify the new shape.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Two squares side by side compose a larger ___.', null,
      'rectangle', 'The outer boundary is a rectangle.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'A square cut diagonally makes two ___.', null,
      'triangles', 'The diagonal creates two triangles.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Four equal small squares in a 2x2 arrangement make a larger ___.', null,
      'square', 'The outer sides are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'What does compose mean?', null,
      'put smaller shapes together to make a larger shape', 'Composition combines shapes.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Can a rectangle be composed from two smaller rectangles?', null,
      'yes', 'Placed appropriately, the outside shape is a rectangle.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Should we identify a composed shape by inside lines or its outside boundary?', null,
      'outside boundary', 'The outer boundary gives the overall shape.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'What attribute helps identify a triangle?', null,
      '3 sides', 'Triangles have three sides.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'What attribute helps identify a rectangle?', null,
      '4 sides and 4 vertices', 'These defining attributes describe a rectangle.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 30, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W30-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W30-D4 was not found.';
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
      'The student will identify defining attributes of common 2D and 3D shapes and reason about composing larger shapes from smaller shapes.', 'I can use attributes to explain why a shape has its name.',
      '["pencil", "paper", "optional shape cutouts or blocks"]'::jsonb, '[{"term": "attribute", "definition": "a feature that describes a shape"}, {"term": "side", "definition": "a straight edge of a 2D shape"}, {"term": "vertex", "definition": "a corner where edges meet"}, {"term": "face", "definition": "a flat surface of a 3D shape"}, {"term": "compose", "definition": "put smaller shapes together to make a larger shape"}]'::jsonb,
      'Focus on attributes that define shapes rather than color, size, or orientation.', 'Model naming a shape from its sides/vertices/faces and show how smaller shapes can form a larger outside boundary.', 'Drawing/building shapes is useful instructionally but is not installed as a separate mastery-evidence requirement.',
      'Shapes are identified by defining attributes. For 2D shapes, look at sides and vertices. For 3D shapes, look at flat faces and curved surfaces. When composing, inspect the outside boundary.', 'Reason through three shape examples together.', 'Complete shape identification and composition reasoning independently.',
      'Optional Shape Builder: use paper shapes or blocks to compose a larger shape and describe the outside boundary.', 'Reason About Shape Attributes',
      'Use defining attributes to identify or reason about each shape.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one shape using defining attributes.',
      'Use labeled shape reference diagrams during guided practice.', 'Find two different ways to compose the same larger rectangle from smaller shapes.',
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
      'A shape has 3 sides. What is it?', null,
      'triangle', 'Three sides define a triangle.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'A solid has 6 square faces. What is it?', null,
      'cube', 'A cube has six square faces.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Two small squares side by side make what larger common shape?', null,
      'rectangle', 'Their outside boundary is rectangular.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'A 2D shape has no vertices. Which common shape fits?', null,
      'circle', 'Circle has no corners.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'A 3D shape has two circular faces. Which shape?', null,
      'cylinder', 'Cylinder has two circular faces.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'A ball is closest to which 3D shape?', null,
      'sphere', 'Ball is sphere-like.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'A square cut diagonally makes which smaller shapes?', null,
      'triangles', 'The diagonal divides the square into triangles.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'How many sides does a square have?', null,
      '4', 'Four sides.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'How many vertices does a triangle have?', null,
      '3', 'Three vertices.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Which has circular faces: cube or cylinder?', null,
      'cylinder', 'Cylinder has two circular ends.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Which has no flat faces: sphere or cube?', null,
      'sphere', 'Sphere is fully curved.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Two squares side by side form a larger ___.', null,
      'rectangle', 'The outer boundary is rectangular.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'What is a shape attribute?', null,
      'a feature that describes a shape', 'Examples include sides, vertices, and faces.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Which 2D shape has four equal sides?', null,
      'square', 'Square has four equal sides.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Which 3D shape has six square faces?', null,
      'cube', 'Cube faces are squares.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 30, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W30-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W30-D5 was not found.';
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
      'The student will identify defining attributes of common 2D and 3D shapes and reason about composing larger shapes from smaller shapes.', 'I can identify, reason about, and compose shapes independently.',
      '["pencil", "paper", "optional shape cutouts or blocks"]'::jsonb, '[{"term": "attribute", "definition": "a feature that describes a shape"}, {"term": "side", "definition": "a straight edge of a 2D shape"}, {"term": "vertex", "definition": "a corner where edges meet"}, {"term": "face", "definition": "a flat surface of a 3D shape"}, {"term": "compose", "definition": "put smaller shapes together to make a larger shape"}]'::jsonb,
      'Focus on attributes that define shapes rather than color, size, or orientation.', 'Model naming a shape from its sides/vertices/faces and show how smaller shapes can form a larger outside boundary.', 'Drawing/building shapes is useful instructionally but is not installed as a separate mastery-evidence requirement.',
      'Shapes are identified by defining attributes. For 2D shapes, look at sides and vertices. For 3D shapes, look at flat faces and curved surfaces. When composing, inspect the outside boundary.', 'Reason through three shape examples together.', 'Complete shape identification and composition reasoning independently.',
      'Optional Shape Builder: use paper shapes or blocks to compose a larger shape and describe the outside boundary.', 'Week 30 Shape Readiness',
      'Use defining attributes to identify or reason about each shape.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain one shape using defining attributes.',
      'Use labeled shape reference diagrams during guided practice.', 'Find two different ways to compose the same larger rectangle from smaller shapes.',
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
      'A shape has 3 sides. What is it?', null,
      'triangle', 'Three sides define a triangle.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'A solid has 6 square faces. What is it?', null,
      'cube', 'A cube has six square faces.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Two small squares side by side make what larger common shape?', null,
      'rectangle', 'Their outside boundary is rectangular.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'A 2D shape has no vertices. Which common shape fits?', null,
      'circle', 'Circle has no corners.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'A 3D shape has two circular faces. Which shape?', null,
      'cylinder', 'Cylinder has two circular faces.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'A ball is closest to which 3D shape?', null,
      'sphere', 'Ball is sphere-like.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'A square cut diagonally makes which smaller shapes?', null,
      'triangles', 'The diagonal divides the square into triangles.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'How many sides does a square have?', null,
      '4', 'Four sides.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'How many vertices does a triangle have?', null,
      '3', 'Three vertices.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Which has circular faces: cube or cylinder?', null,
      'cylinder', 'Cylinder has two circular ends.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Which has no flat faces: sphere or cube?', null,
      'sphere', 'Sphere is fully curved.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Two squares side by side form a larger ___.', null,
      'rectangle', 'The outer boundary is rectangular.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'What is a shape attribute?', null,
      'a feature that describes a shape', 'Examples include sides, vertices, and faces.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Which 2D shape has four equal sides?', null,
      'square', 'Square has four equal sides.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Which 3D shape has six square faces?', null,
      'cube', 'Cube faces are squares.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 31, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W31-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W31-D1 was not found.';
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
      'The student will partition or interpret circles and rectangles as two or four equal shares, name halves/fourths/quarters, and explain why equal shares must be the same size.', 'I can recognize and describe two equal shares as halves.',
      '["pencil", "paper", "optional paper circles or rectangles"]'::jsonb, '[{"term": "whole", "definition": "one complete shape or object"}, {"term": "equal shares", "definition": "parts of the same whole that are the same size"}, {"term": "half", "definition": "one of two equal shares"}, {"term": "fourth", "definition": "one of four equal shares"}, {"term": "quarter", "definition": "another word for one fourth"}]'::jsonb,
      'Start with the idea of one whole and emphasize that fraction names depend on equal shares.', 'Model two equal shares as halves and four equal shares as fourths/quarters, contrasting each with unequal pieces.', 'Drawing/folding shapes is useful instruction, but repeated qualifying evidence remains sufficient for mastery without a separate hands-on requirement.',
      'Fractions describe equal shares of one whole. Two equal shares are halves. Four equal shares are fourths or quarters. Unequal pieces do not count as halves or fourths.', 'Reason about three partition examples together.', 'Complete equal-share reasoning independently.',
      'Optional Fold and Check: fold a paper rectangle into two equal shares, then another into four equal shares.', 'Partition into Halves',
      'Decide whether shares are equal and name halves or fourths correctly.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain why unequal pieces cannot be called halves/fourths.',
      'Use simple shaded/unshaded descriptions and oral explanations when drawing precision is a barrier.', 'Find two different ways to divide a rectangle into four equal shares.',
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
      'A rectangle is split into 2 equal shares. What is each share called?', null,
      'a half', 'Two equal shares are halves.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'A circle is split into two pieces, one much larger than the other. Are they halves?', null,
      'no', 'Halves must be equal in size.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'How many halves make one whole?', null,
      '2', 'Two equal halves compose the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'If a square is divided into two equal rectangles, each part is what?', null,
      'a half', 'Two equal shares are halves.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Can two unequal pieces be called halves?', null,
      'no', 'Halves must be equal shares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'One half plus one half makes what?', null,
      'one whole', 'Two halves make the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Which is required for halves: two pieces or two equal pieces?', null,
      'two equal pieces', 'Equality is essential.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'A circle has 2 equal parts. Each is a ___.', null,
      'half', 'Two equal shares are halves.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'A rectangle has 2 unequal parts. Are they halves?', null,
      'no', 'They are not equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Number of halves in a whole?', null,
      '2', 'Two halves.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Do halves of the same whole have the same size?', null,
      'yes', 'Equal shares must match in size.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'A square split straight down the middle makes two equal shares. Name them.', null,
      'halves', 'Two equal shares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'A rectangle split into a tiny piece and large piece makes halves?', null,
      'no', 'The pieces are unequal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'What does equal share mean?', null,
      'a part the same size as the other shares of that whole', 'Equal shares match in size.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Two equal halves together equal what?', null,
      'one whole', 'They reconstruct the whole.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 31, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W31-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W31-D2 was not found.';
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
      'The student will partition or interpret circles and rectangles as two or four equal shares, name halves/fourths/quarters, and explain why equal shares must be the same size.', 'I can recognize and describe four equal shares as fourths or quarters.',
      '["pencil", "paper", "optional paper circles or rectangles"]'::jsonb, '[{"term": "whole", "definition": "one complete shape or object"}, {"term": "equal shares", "definition": "parts of the same whole that are the same size"}, {"term": "half", "definition": "one of two equal shares"}, {"term": "fourth", "definition": "one of four equal shares"}, {"term": "quarter", "definition": "another word for one fourth"}]'::jsonb,
      'Start with the idea of one whole and emphasize that fraction names depend on equal shares.', 'Model two equal shares as halves and four equal shares as fourths/quarters, contrasting each with unequal pieces.', 'Drawing/folding shapes is useful instruction, but repeated qualifying evidence remains sufficient for mastery without a separate hands-on requirement.',
      'Fractions describe equal shares of one whole. Two equal shares are halves. Four equal shares are fourths or quarters. Unequal pieces do not count as halves or fourths.', 'Reason about three partition examples together.', 'Complete equal-share reasoning independently.',
      'Optional Fold and Check: fold a paper rectangle into two equal shares, then another into four equal shares.', 'Partition into Fourths',
      'Decide whether shares are equal and name halves or fourths correctly.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain why unequal pieces cannot be called halves/fourths.',
      'Use simple shaded/unshaded descriptions and oral explanations when drawing precision is a barrier.', 'Find two different ways to divide a rectangle into four equal shares.',
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
      'A rectangle is divided into 4 equal shares. What is each share called?', null,
      'a fourth', 'Four equal shares are fourths.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'What is another word for a fourth?', null,
      'quarter', 'Fourth and quarter name the same equal share.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'How many fourths make one whole?', null,
      '4', 'Four equal fourths compose the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'A circle has four equal slices. Each is what?', null,
      'a fourth', 'Each is one of four equal shares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Can four unequal pieces be called fourths?', null,
      'no', 'Fourths must be equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'How many quarters make a whole?', null,
      '4', 'Four quarters equal one whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Which is larger within the same whole: one half or one fourth?', null,
      'one half', 'Dividing into fewer equal shares makes each share larger.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Four equal shares are called ___.', null,
      'fourths', 'Four equal parts.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Another word for fourths?', null,
      'quarters', 'Quarter means fourth.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Number of fourths in one whole?', null,
      '4', 'Four.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Four unequal parts are fourths?', null,
      'no', 'They must be equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'A square divided into four equal smaller squares has what shares?', null,
      'fourths', 'Each small square is one fourth.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'One fourth means one of how many equal shares?', null,
      '4', 'One of four.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Do all fourths of the same whole have the same size?', null,
      'yes', 'They are equal shares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Four fourths together make what?', null,
      'one whole', 'All four shares reconstruct the whole.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 31, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W31-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W31-D3 was not found.';
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
      'The student will partition or interpret circles and rectangles as two or four equal shares, name halves/fourths/quarters, and explain why equal shares must be the same size.', 'I can explain how halves and fourths relate to the same whole.',
      '["pencil", "paper", "optional paper circles or rectangles"]'::jsonb, '[{"term": "whole", "definition": "one complete shape or object"}, {"term": "equal shares", "definition": "parts of the same whole that are the same size"}, {"term": "half", "definition": "one of two equal shares"}, {"term": "fourth", "definition": "one of four equal shares"}, {"term": "quarter", "definition": "another word for one fourth"}]'::jsonb,
      'Start with the idea of one whole and emphasize that fraction names depend on equal shares.', 'Model two equal shares as halves and four equal shares as fourths/quarters, contrasting each with unequal pieces.', 'Drawing/folding shapes is useful instruction, but repeated qualifying evidence remains sufficient for mastery without a separate hands-on requirement.',
      'Fractions describe equal shares of one whole. Two equal shares are halves. Four equal shares are fourths or quarters. Unequal pieces do not count as halves or fourths.', 'Reason about three partition examples together.', 'Complete equal-share reasoning independently.',
      'Optional Fold and Check: fold a paper rectangle into two equal shares, then another into four equal shares.', 'Compare Halves and Fourths',
      'Decide whether shares are equal and name halves or fourths correctly.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain why unequal pieces cannot be called halves/fourths.',
      'Use simple shaded/unshaded descriptions and oral explanations when drawing precision is a barrier.', 'Find two different ways to divide a rectangle into four equal shares.',
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
      'For the same whole, which share is larger: one half or one fourth?', null,
      'one half', 'Two equal shares are larger than four equal shares of the same whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'A shape is divided into 2 equal parts. Is each part a half or fourth?', null,
      'half', 'Two equal parts are halves.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'A shape is divided into 4 equal parts. Is each part a half or fourth?', null,
      'fourth', 'Four equal parts are fourths.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Which makes smaller equal pieces of the same whole: halves or fourths?', null,
      'fourths', 'Four shares are smaller than two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Two halves make how many wholes?', null,
      '1', 'Two halves make one whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Four fourths make how many wholes?', null,
      '1', 'Four fourths make one whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Can a half of one large rectangle be compared as the same physical size as a half of any smaller rectangle?', null,
      'not necessarily', 'Share size depends on the size of the whole.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'Same whole: larger share, half or fourth?', null,
      'half', 'Half is larger.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'Same whole: smaller share, half or fourth?', null,
      'fourth', 'Fourth is smaller.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '2 equal shares are called ___.', null,
      'halves', 'Two equal shares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '4 equal shares are called ___.', null,
      'fourths', 'Four equal shares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '4 equal shares can also be called ___.', null,
      'quarters', 'Fourth = quarter.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Do equal shares have to be the same shape?', null,
      'not always', 'They must be equal in size/area, though shapes can sometimes differ.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Do equal shares have to be the same size?', null,
      'yes', 'Equal means same size.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why is one fourth smaller than one half of the same whole?', null,
      'the whole is divided into more equal shares', 'More equal shares means each share is smaller.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 31, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W31-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W31-D4 was not found.';
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
      'The student will partition or interpret circles and rectangles as two or four equal shares, name halves/fourths/quarters, and explain why equal shares must be the same size.', 'I can tell equal shares from unequal pieces.',
      '["pencil", "paper", "optional paper circles or rectangles"]'::jsonb, '[{"term": "whole", "definition": "one complete shape or object"}, {"term": "equal shares", "definition": "parts of the same whole that are the same size"}, {"term": "half", "definition": "one of two equal shares"}, {"term": "fourth", "definition": "one of four equal shares"}, {"term": "quarter", "definition": "another word for one fourth"}]'::jsonb,
      'Start with the idea of one whole and emphasize that fraction names depend on equal shares.', 'Model two equal shares as halves and four equal shares as fourths/quarters, contrasting each with unequal pieces.', 'Drawing/folding shapes is useful instruction, but repeated qualifying evidence remains sufficient for mastery without a separate hands-on requirement.',
      'Fractions describe equal shares of one whole. Two equal shares are halves. Four equal shares are fourths or quarters. Unequal pieces do not count as halves or fourths.', 'Reason about three partition examples together.', 'Complete equal-share reasoning independently.',
      'Optional Fold and Check: fold a paper rectangle into two equal shares, then another into four equal shares.', 'Equal Shares Matter',
      'Decide whether shares are equal and name halves or fourths correctly.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain why unequal pieces cannot be called halves/fourths.',
      'Use simple shaded/unshaded descriptions and oral explanations when drawing precision is a barrier.', 'Find two different ways to divide a rectangle into four equal shares.',
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
      'Two equal pieces of one rectangle are called what?', null,
      'halves', 'Two equal shares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Four equal pieces of one circle are called what?', null,
      'fourths', 'Four equal shares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Are four pieces automatically fourths?', null,
      'no', 'They must be equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Are two equal shares quarters?', null,
      'no', 'Two equal shares are halves.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Another word for one fourth?', null,
      'one quarter', 'Fourth and quarter are equivalent terms.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Which is bigger in the same whole: half or fourth?', null,
      'half', 'Half is one of two equal shares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'How many fourths equal one whole?', null,
      '4', 'Four fourths.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'How many halves make a whole?', null,
      '2', 'Two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'How many fourths make a whole?', null,
      '4', 'Four.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Two unequal pieces are halves?', null,
      'no', 'Halves must be equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Four unequal pieces are fourths?', null,
      'no', 'Fourths must be equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'One of two equal shares is called a ___.', null,
      'half', 'Definition of half.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'One of four equal shares is called a ___.', null,
      'fourth', 'Definition of fourth.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Quarter means the same as ___.', null,
      'fourth', 'Equivalent vocabulary.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why must shares be equal?', null,
      'so each share represents the same fraction of the whole', 'Fraction names depend on equal partitioning.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 31, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W31-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W31-D5 was not found.';
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
      'The student will partition or interpret circles and rectangles as two or four equal shares, name halves/fourths/quarters, and explain why equal shares must be the same size.', 'I can reason about halves and fourths independently.',
      '["pencil", "paper", "optional paper circles or rectangles"]'::jsonb, '[{"term": "whole", "definition": "one complete shape or object"}, {"term": "equal shares", "definition": "parts of the same whole that are the same size"}, {"term": "half", "definition": "one of two equal shares"}, {"term": "fourth", "definition": "one of four equal shares"}, {"term": "quarter", "definition": "another word for one fourth"}]'::jsonb,
      'Start with the idea of one whole and emphasize that fraction names depend on equal shares.', 'Model two equal shares as halves and four equal shares as fourths/quarters, contrasting each with unequal pieces.', 'Drawing/folding shapes is useful instruction, but repeated qualifying evidence remains sufficient for mastery without a separate hands-on requirement.',
      'Fractions describe equal shares of one whole. Two equal shares are halves. Four equal shares are fourths or quarters. Unequal pieces do not count as halves or fourths.', 'Reason about three partition examples together.', 'Complete equal-share reasoning independently.',
      'Optional Fold and Check: fold a paper rectangle into two equal shares, then another into four equal shares.', 'Week 31 Halves and Fourths Readiness',
      'Decide whether shares are equal and name halves or fourths correctly.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain why unequal pieces cannot be called halves/fourths.',
      'Use simple shaded/unshaded descriptions and oral explanations when drawing precision is a barrier.', 'Find two different ways to divide a rectangle into four equal shares.',
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
      'Two equal pieces of one rectangle are called what?', null,
      'halves', 'Two equal shares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Four equal pieces of one circle are called what?', null,
      'fourths', 'Four equal shares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Are four pieces automatically fourths?', null,
      'no', 'They must be equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Are two equal shares quarters?', null,
      'no', 'Two equal shares are halves.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Another word for one fourth?', null,
      'one quarter', 'Fourth and quarter are equivalent terms.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Which is bigger in the same whole: half or fourth?', null,
      'half', 'Half is one of two equal shares.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'How many fourths equal one whole?', null,
      '4', 'Four fourths.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      'How many halves make a whole?', null,
      '2', 'Two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      'How many fourths make a whole?', null,
      '4', 'Four.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      'Two unequal pieces are halves?', null,
      'no', 'Halves must be equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      'Four unequal pieces are fourths?', null,
      'no', 'Fourths must be equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'One of two equal shares is called a ___.', null,
      'half', 'Definition of half.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'One of four equal shares is called a ___.', null,
      'fourth', 'Definition of fourth.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Quarter means the same as ___.', null,
      'fourth', 'Equivalent vocabulary.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Why must shares be equal?', null,
      'so each share represents the same fraction of the whole', 'Fraction names depend on equal partitioning.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 32, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W32-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W32-D1 was not found.';
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
      'The student will add within 100 using place-value reasoning for a two-digit number plus a one-digit number or a multiple of 10, explaining how tens and ones change.', 'I can add ones to a two-digit number using place value.',
      '["pencil", "paper", "optional base-ten drawing or chart"]'::jsonb, '[{"term": "tens", "definition": "groups of ten"}, {"term": "ones", "definition": "single units"}, {"term": "place value", "definition": "the value a digit has because of its position"}, {"term": "multiple of 10", "definition": "a number such as 10, 20, 30, or 40 made of whole tens"}]'::jsonb,
      'Connect addition within 100 to earlier tens-and-ones work. Keep tens and ones organized by place value.', 'Model one problem adding ones and one adding tens, explaining which place changes and which stays the same.', 'Week 32 is the first of two planned weeks for 1-MATH-19. Models are useful instructionally, but mastery does not require a separate hands-on evidence type.',
      'When adding a one-digit number, usually the ones place changes. When adding a multiple of 10, the tens place changes while the ones stay the same. Use place value to reason instead of treating digits as unrelated symbols.', 'Solve three place-value additions together.', 'Complete mixed addition within 100 independently.',
      'Optional Base-Ten Sketch: draw tens rods and ones dots before and after an addition problem.', 'Add a One-Digit Number to a Two-Digit Number',
      'Solve each addition problem and think about how tens and ones change.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain the place-value change in at least one problem.',
      'Use a tens/ones chart and allow base-ten drawings during guided practice.', 'Create one problem where only the ones place changes and one where only the tens place changes.',
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
      'Solve 32 + 5.', null,
      '37', 'Add 5 ones to 2 ones: 2+5=7; tens stay 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Solve 41 + 6.', null,
      '47', 'Add ones: 1+6=7; tens stay 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Solve 53 + 4.', null,
      '57', '3+4=7 ones, with 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Solve 24 + 3.', null,
      '27', 'Add 3 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve 61 + 7.', null,
      '68', '1+7=8 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 72 + 5.', null,
      '77', '2+5=7 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Solve 80 + 6.', null,
      '86', 'Add six ones to eight tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '31+4', null,
      '35', '1+4=5 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '42+5', null,
      '47', '2+5=7 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '54+3', null,
      '57', '4+3=7 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '60+8', null,
      '68', 'Add eight ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '71+6', null,
      '77', '1+6=7 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '83+4', null,
      '87', '3+4=7 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '25+2', null,
      '27', '5+2=7 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '90+7', null,
      '97', 'Add seven ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 32, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W32-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W32-D2 was not found.';
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
      'The student will add within 100 using place-value reasoning for a two-digit number plus a one-digit number or a multiple of 10, explaining how tens and ones change.', 'I can add whole tens to a two-digit number.',
      '["pencil", "paper", "optional base-ten drawing or chart"]'::jsonb, '[{"term": "tens", "definition": "groups of ten"}, {"term": "ones", "definition": "single units"}, {"term": "place value", "definition": "the value a digit has because of its position"}, {"term": "multiple of 10", "definition": "a number such as 10, 20, 30, or 40 made of whole tens"}]'::jsonb,
      'Connect addition within 100 to earlier tens-and-ones work. Keep tens and ones organized by place value.', 'Model one problem adding ones and one adding tens, explaining which place changes and which stays the same.', 'Week 32 is the first of two planned weeks for 1-MATH-19. Models are useful instructionally, but mastery does not require a separate hands-on evidence type.',
      'When adding a one-digit number, usually the ones place changes. When adding a multiple of 10, the tens place changes while the ones stay the same. Use place value to reason instead of treating digits as unrelated symbols.', 'Solve three place-value additions together.', 'Complete mixed addition within 100 independently.',
      'Optional Base-Ten Sketch: draw tens rods and ones dots before and after an addition problem.', 'Add Multiples of 10',
      'Solve each addition problem and think about how tens and ones change.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain the place-value change in at least one problem.',
      'Use a tens/ones chart and allow base-ten drawings during guided practice.', 'Create one problem where only the ones place changes and one where only the tens place changes.',
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
      'Solve 34 + 20.', null,
      '54', 'Add 2 tens to 3 tens; ones stay 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Solve 52 + 30.', null,
      '82', '5 tens + 3 tens = 8 tens; ones stay 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Solve 17 + 40.', null,
      '57', '1 ten + 4 tens = 5 tens; ones stay 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Solve 26 + 10.', null,
      '36', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve 41 + 20.', null,
      '61', 'Add two tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 33 + 50.', null,
      '83', 'Add five tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Solve 65 + 30.', null,
      '95', 'Add three tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '24+10', null,
      '34', 'Add one ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '35+20', null,
      '55', 'Add two tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '46+30', null,
      '76', 'Add three tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '12+50', null,
      '62', 'Add five tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      '63+20', null,
      '83', 'Add two tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '51+40', null,
      '91', 'Add four tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '27+60', null,
      '87', 'Add six tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '70+20', null,
      '90', 'Seven tens plus two tens.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 32, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W32-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W32-D3 was not found.';
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
      'The student will add within 100 using place-value reasoning for a two-digit number plus a one-digit number or a multiple of 10, explaining how tens and ones change.', 'I can explain which place changes when I add.',
      '["pencil", "paper", "optional base-ten drawing or chart"]'::jsonb, '[{"term": "tens", "definition": "groups of ten"}, {"term": "ones", "definition": "single units"}, {"term": "place value", "definition": "the value a digit has because of its position"}, {"term": "multiple of 10", "definition": "a number such as 10, 20, 30, or 40 made of whole tens"}]'::jsonb,
      'Connect addition within 100 to earlier tens-and-ones work. Keep tens and ones organized by place value.', 'Model one problem adding ones and one adding tens, explaining which place changes and which stays the same.', 'Week 32 is the first of two planned weeks for 1-MATH-19. Models are useful instructionally, but mastery does not require a separate hands-on evidence type.',
      'When adding a one-digit number, usually the ones place changes. When adding a multiple of 10, the tens place changes while the ones stay the same. Use place value to reason instead of treating digits as unrelated symbols.', 'Solve three place-value additions together.', 'Complete mixed addition within 100 independently.',
      'Optional Base-Ten Sketch: draw tens rods and ones dots before and after an addition problem.', 'Explain How Tens and Ones Change',
      'Solve each addition problem and think about how tens and ones change.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain the place-value change in at least one problem.',
      'Use a tens/ones chart and allow base-ten drawings during guided practice.', 'Create one problem where only the ones place changes and one where only the tens place changes.',
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
      'In 43 + 5, which place changes: tens, ones, or both?', null,
      'ones', 'Adding 5 changes the ones from 3 to 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'In 43 + 20, which place changes?', null,
      'tens', 'Adding two tens changes 4 tens to 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Solve 43 + 5.', null,
      '48', '4 tens stay; 3+5=8 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Solve 43 + 20.', null,
      '63', '4 tens + 2 tens = 6 tens; ones remain 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve 61 + 6.', null,
      '67', 'Ones change from 1 to 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 61 + 30.', null,
      '91', 'Tens change from 6 to 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'What stays the same in 52+20?', null,
      'ones digit', 'The 2 ones remain 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '32+4', null,
      '36', 'Ones change.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '32+40', null,
      '72', 'Tens change.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '51+7', null,
      '58', 'Ones change.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 4,
      '51+30', null,
      '81', 'Tens change.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 5,
      'Which digit stays same in 64+20?', null,
      'ones digit', '4 ones stay 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      'Which digit stays same in 64+3?', null,
      'tens digit', '6 tens stay 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      'Explain 27+40.', null,
      '67', '2 tens + 4 tens = 6 tens; 7 ones stay 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      'Explain 72+5.', null,
      '77', '7 tens stay; 2+5=7 ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 32, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W32-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W32-D4 was not found.';
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
      'The student will add within 100 using place-value reasoning for a two-digit number plus a one-digit number or a multiple of 10, explaining how tens and ones change.', 'I can solve mixed two-digit plus one-digit or tens problems.',
      '["pencil", "paper", "optional base-ten drawing or chart"]'::jsonb, '[{"term": "tens", "definition": "groups of ten"}, {"term": "ones", "definition": "single units"}, {"term": "place value", "definition": "the value a digit has because of its position"}, {"term": "multiple of 10", "definition": "a number such as 10, 20, 30, or 40 made of whole tens"}]'::jsonb,
      'Connect addition within 100 to earlier tens-and-ones work. Keep tens and ones organized by place value.', 'Model one problem adding ones and one adding tens, explaining which place changes and which stays the same.', 'Week 32 is the first of two planned weeks for 1-MATH-19. Models are useful instructionally, but mastery does not require a separate hands-on evidence type.',
      'When adding a one-digit number, usually the ones place changes. When adding a multiple of 10, the tens place changes while the ones stay the same. Use place value to reason instead of treating digits as unrelated symbols.', 'Solve three place-value additions together.', 'Complete mixed addition within 100 independently.',
      'Optional Base-Ten Sketch: draw tens rods and ones dots before and after an addition problem.', 'Choose the Place-Value Strategy',
      'Solve each addition problem and think about how tens and ones change.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain the place-value change in at least one problem.',
      'Use a tens/ones chart and allow base-ten drawings during guided practice.', 'Create one problem where only the ones place changes and one where only the tens place changes.',
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
      'Solve 36 + 3.', null,
      '39', 'Add three ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Solve 36 + 20.', null,
      '56', 'Add two tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Solve 71 + 8.', null,
      '79', 'Add eight ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Solve 44 + 30.', null,
      '74', 'Add three tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve 62 + 5.', null,
      '67', 'Add five ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 23 + 50.', null,
      '73', 'Add five tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Solve 81 + 6.', null,
      '87', 'Add six ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '25+4', null,
      '29', 'Add four ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '25+30', null,
      '55', 'Add three tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '42+6', null,
      '48', 'Add six ones.', 1
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
      '63+5', null,
      '68', 'Add five ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '63+20', null,
      '83', 'Add two tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '11+70', null,
      '81', 'Add seven tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '90+8', null,
      '98', 'Add eight ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 32, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W32-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W32-D5 was not found.';
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
      'The student will add within 100 using place-value reasoning for a two-digit number plus a one-digit number or a multiple of 10, explaining how tens and ones change.', 'I can add within 100 using place-value reasoning independently.',
      '["pencil", "paper", "optional base-ten drawing or chart"]'::jsonb, '[{"term": "tens", "definition": "groups of ten"}, {"term": "ones", "definition": "single units"}, {"term": "place value", "definition": "the value a digit has because of its position"}, {"term": "multiple of 10", "definition": "a number such as 10, 20, 30, or 40 made of whole tens"}]'::jsonb,
      'Connect addition within 100 to earlier tens-and-ones work. Keep tens and ones organized by place value.', 'Model one problem adding ones and one adding tens, explaining which place changes and which stays the same.', 'Week 32 is the first of two planned weeks for 1-MATH-19. Models are useful instructionally, but mastery does not require a separate hands-on evidence type.',
      'When adding a one-digit number, usually the ones place changes. When adding a multiple of 10, the tens place changes while the ones stay the same. Use place value to reason instead of treating digits as unrelated symbols.', 'Solve three place-value additions together.', 'Complete mixed addition within 100 independently.',
      'Optional Base-Ten Sketch: draw tens rods and ones dots before and after an addition problem.', 'Week 32 Addition Readiness',
      'Solve each addition problem and think about how tens and ones change.', 'Complete at least 7 of 8 worksheet items correctly after corrections and explain the place-value change in at least one problem.',
      'Use a tens/ones chart and allow base-ten drawings during guided practice.', 'Create one problem where only the ones place changes and one where only the tens place changes.',
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
      'Solve 36 + 3.', null,
      '39', 'Add three ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 2,
      'Solve 36 + 20.', null,
      '56', 'Add two tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'guided_practice', 3,
      'Solve 71 + 8.', null,
      '79', 'Add eight ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 1,
      'Solve 44 + 30.', null,
      '74', 'Add three tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 2,
      'Solve 62 + 5.', null,
      '67', 'Add five ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 3,
      'Solve 23 + 50.', null,
      '73', 'Add five tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'independent_practice', 4,
      'Solve 81 + 6.', null,
      '87', 'Add six ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 1,
      '25+4', null,
      '29', 'Add four ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 2,
      '25+30', null,
      '55', 'Add three tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 3,
      '42+6', null,
      '48', 'Add six ones.', 1
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
      '63+5', null,
      '68', 'Add five ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 6,
      '63+20', null,
      '83', 'Add two tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 7,
      '11+70', null,
      '81', 'Add seven tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id,
      'worksheet', 8,
      '90+8', null,
      '98', 'Add eight ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published',
        published_at = now(),
        updated_at = now()
    where id = v_version_id;


    -- Week 28 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 28
      and l.week_number = 28
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W28-Q01', 1, 'short_answer', 'Data: cat, dog, cat, bird, cat. How many cats?', '[]'::jsonb, '3', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W28-Q02', 2, 'multiple_choice', 'Table: Red=5, Blue=3. Which category has more?', '[{"id": "a", "label": "Red"}, {"id": "b", "label": "Blue"}, {"id": "c", "label": "same"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W28-Q03', 3, 'short_answer', 'Table: Cats=2, Dogs=4, Fish=1. How many total?', '[]'::jsonb, '7', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W28-Q04', 4, 'short_answer', 'Table: Apples=6, Bananas=4. How many more apples?', '[]'::jsonb, '2', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W28-Q05', 5, 'short_answer', 'Table: Red=2, Blue=5. How many fewer red?', '[]'::jsonb, '3', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W28-Q06', 6, 'multiple_choice', 'Table: Books=4, Games=5, Puzzles=1. Which has the fewest?', '[{"id": "a", "label": "Books"}, {"id": "b", "label": "Games"}, {"id": "c", "label": "Puzzles"}]'::jsonb, 'c', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W28-Q07', 7, 'multiple_choice', 'Data: dog, dog, cat, cat. How do dog and cat counts compare?', '[{"id": "a", "label": "dogs more"}, {"id": "b", "label": "cats more"}, {"id": "c", "label": "same"}]'::jsonb, 'c', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W28-Q08', 8, 'short_answer', 'Table: Red=3, Blue=4, Green=2. Total?', '[]'::jsonb, '9', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W28-Q09', 9, 'multiple_choice', 'Data: apple, banana, apple, pear. How many categories?', '[{"id": "a", "label": "2"}, {"id": "b", "label": "3"}, {"id": "c", "label": "4"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W28-Q10', 10, 'short_answer', 'Table: Cars=6, Bikes=3. What is the difference?', '[]'::jsonb, '3', 1);


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


    -- Week 29 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 29
      and l.week_number = 29
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W29-Q01', 1, 'short_answer', 'Data: Cats=3. If 1 symbol=1 cat, how many symbols?', '[]'::jsonb, '3', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W29-Q02', 2, 'short_answer', 'Data: Red=4, Blue=2. How many symbols for Blue?', '[]'::jsonb, '2', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W29-Q03', 3, 'multiple_choice', 'Graph counts: Cats=3, Dogs=5. Which has more?', '[{"id": "a", "label": "Cats"}, {"id": "b", "label": "Dogs"}, {"id": "c", "label": "same"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W29-Q04', 4, 'short_answer', 'Graph counts: Red=4, Blue=2. How many more Red?', '[]'::jsonb, '2', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W29-Q05', 5, 'short_answer', 'Graph counts: Apples=2, Pears=3, Bananas=4. Total?', '[]'::jsonb, '9', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W29-Q06', 6, 'multiple_choice', 'Data: A=2, B=7, C=4. Which graph row should be longest?', '[{"id": "a", "label": "A"}, {"id": "b", "label": "B"}, {"id": "c", "label": "C"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W29-Q07', 7, 'multiple_choice', 'Why should each symbol represent the same amount?', '[{"id": "a", "label": "for consistent representation"}, {"id": "b", "label": "to make every category equal"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W29-Q08', 8, 'short_answer', 'Graph counts: Books=2, Games=5, Puzzles=3. Which count is greatest?', '[]'::jsonb, '5', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W29-Q09', 9, 'multiple_choice', 'If Cats and Dogs each have 4 symbols, how do the counts compare?', '[{"id": "a", "label": "Cats more"}, {"id": "b", "label": "Dogs more"}, {"id": "c", "label": "same"}]'::jsonb, 'c', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W29-Q10', 10, 'short_answer', 'Data Red=2, Blue=5, Green=1. How many total symbols in a one-for-one graph?', '[]'::jsonb, '8', 1);


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


    -- Week 30 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 30
      and l.week_number = 30
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W30-Q01', 1, 'multiple_choice', 'Which 2D shape has 3 sides?', '[{"id": "a", "label": "triangle"}, {"id": "b", "label": "square"}, {"id": "c", "label": "circle"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W30-Q02', 2, 'multiple_choice', 'Which 2D shape has no vertices?', '[{"id": "a", "label": "triangle"}, {"id": "b", "label": "rectangle"}, {"id": "c", "label": "circle"}]'::jsonb, 'c', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W30-Q03', 3, 'short_answer', 'How many sides does a square have?', '[]'::jsonb, '4', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W30-Q04', 4, 'multiple_choice', 'Which 3D shape has 6 square faces?', '[{"id": "a", "label": "sphere"}, {"id": "b", "label": "cube"}, {"id": "c", "label": "cylinder"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W30-Q05', 5, 'multiple_choice', 'Which 3D shape is shaped most like a ball?', '[{"id": "a", "label": "sphere"}, {"id": "b", "label": "cube"}, {"id": "c", "label": "cylinder"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W30-Q06', 6, 'multiple_choice', 'Which 3D shape has two circular faces?', '[{"id": "a", "label": "cube"}, {"id": "b", "label": "cylinder"}, {"id": "c", "label": "sphere"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W30-Q07', 7, 'multiple_choice', 'Two squares side by side usually compose which larger common 2D shape?', '[{"id": "a", "label": "triangle"}, {"id": "b", "label": "rectangle"}, {"id": "c", "label": "circle"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W30-Q08', 8, 'multiple_choice', 'A square cut diagonally makes two what?', '[{"id": "a", "label": "triangles"}, {"id": "b", "label": "circles"}, {"id": "c", "label": "cubes"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W30-Q09', 9, 'multiple_choice', 'What should you inspect to name a composed 2D shape?', '[{"id": "a", "label": "outside boundary"}, {"id": "b", "label": "color"}, {"id": "c", "label": "size only"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W30-Q10', 10, 'short_answer', 'How many vertices does a triangle have?', '[]'::jsonb, '3', 1);


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


    -- Week 31 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 31
      and l.week_number = 31
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W31-Q01', 1, 'multiple_choice', 'A rectangle divided into 2 equal shares creates what?', '[{"id": "a", "label": "halves"}, {"id": "b", "label": "fourths"}, {"id": "c", "label": "unequal pieces"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W31-Q02', 2, 'multiple_choice', 'Can two unequal pieces be halves?', '[{"id": "a", "label": "yes"}, {"id": "b", "label": "no"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W31-Q03', 3, 'short_answer', 'How many halves make one whole?', '[]'::jsonb, '2', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W31-Q04', 4, 'multiple_choice', 'A circle divided into 4 equal shares creates what?', '[{"id": "a", "label": "halves"}, {"id": "b", "label": "fourths"}, {"id": "c", "label": "thirds"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W31-Q05', 5, 'multiple_choice', 'What is another word for one fourth?', '[{"id": "a", "label": "half"}, {"id": "b", "label": "quarter"}, {"id": "c", "label": "whole"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W31-Q06', 6, 'short_answer', 'How many fourths make one whole?', '[]'::jsonb, '4', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W31-Q07', 7, 'multiple_choice', 'For the same whole, which is larger?', '[{"id": "a", "label": "one half"}, {"id": "b", "label": "one fourth"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W31-Q08', 8, 'multiple_choice', 'Must fourths of the same whole be equal in size?', '[{"id": "a", "label": "yes"}, {"id": "b", "label": "no"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W31-Q09', 9, 'multiple_choice', 'Are four pieces automatically fourths?', '[{"id": "a", "label": "yes"}, {"id": "b", "label": "no"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W31-Q10', 10, 'multiple_choice', 'Why must fraction shares be equal?', '[{"id": "a", "label": "so each share represents the same part of the whole"}, {"id": "b", "label": "so every whole has the same size"}]'::jsonb, 'a', 1);


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


    -- Week 32 Friday online check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 32
      and l.week_number = 32
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W32-Q01', 1, 'short_answer', 'Solve 32 + 5.', '[]'::jsonb, '37', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W32-Q02', 2, 'short_answer', 'Solve 41 + 6.', '[]'::jsonb, '47', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W32-Q03', 3, 'short_answer', 'Solve 34 + 20.', '[]'::jsonb, '54', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W32-Q04', 4, 'short_answer', 'Solve 52 + 30.', '[]'::jsonb, '82', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W32-Q05', 5, 'multiple_choice', 'In 43 + 5, which place changes?', '[{"id": "a", "label": "tens"}, {"id": "b", "label": "ones"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W32-Q06', 6, 'multiple_choice', 'In 43 + 20, which place changes?', '[{"id": "a", "label": "tens"}, {"id": "b", "label": "ones"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W32-Q07', 7, 'short_answer', 'Solve 26 + 10.', '[]'::jsonb, '36', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W32-Q08', 8, 'short_answer', 'Solve 63 + 20.', '[]'::jsonb, '83', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W32-Q09', 9, 'short_answer', 'Solve 72 + 5.', '[]'::jsonb, '77', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W32-Q10', 10, 'multiple_choice', 'In 64 + 20, which digit stays the same?', '[{"id": "a", "label": "tens digit"}, {"id": "b", "label": "ones digit"}]'::jsonb, 'b', 1);


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
