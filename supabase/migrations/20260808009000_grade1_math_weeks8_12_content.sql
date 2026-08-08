-- Homeschool Tracker
-- Migration 019: Grade 1 Mathematics Weeks 8–12 production curriculum
--
-- Week 8  : Quarter 1 Spiral Review (1-MATH-01..05)
-- Week 9  : Quarter 1 Mastery Check (1-MATH-01..05)
-- Week 10 : Addition Within 20 I (1-MATH-06)
-- Week 11 : Addition Within 20 II (1-MATH-06)
-- Week 12 : Subtraction Within 20 I (1-MATH-07)
--
-- Installs 25 published lesson revisions, 375 lesson items,
-- and 50 auto-scored Friday assessment items.
--
-- Historical safety:
-- * all writes are in one transaction
-- * preflight validates every lesson skeleton and Friday template
-- * refuses to overwrite published/superseded content
-- * refuses to rewrite frozen student lesson deliveries
-- * refuses to overwrite an existing online question bank

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
    for v_week in 8..12 loop
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
        raise exception 'Grade 1 Math Week % already has published lesson content. Migration 019 will not overwrite curriculum history.', v_week;
      end if;

      if exists (
        select 1
        from public.student_lesson_deliveries sld
        join public.lessons l on l.id = sld.lesson_id
        where l.course_version_id = v_course.course_version_id
          and l.week_number = v_week
      ) then
        raise exception 'Grade 1 Math Week % has already been frozen to a student delivery. Migration 019 will not rewrite delivered curriculum.', v_week;
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
        raise exception 'Grade 1 Math Week % already has an online question bank. Migration 019 will not overwrite assessment history.', v_week;
      end if;
    end loop;

    delete from public.lesson_content_versions lcv
    using public.lessons l
    where lcv.lesson_id = l.id
      and l.course_version_id = v_course.course_version_id
      and l.week_number between 8 and 12
      and lcv.status = 'draft';


    -- Week 8, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W08-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W08-D1 was not found.';
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
      'The student will spiral-review reading, writing, ordering, and representing numbers to 120 and counting forward/backward from varied starting points.', 'I can use the number sequence anywhere from 0 to 120.', '["pencil", "paper", "scratch paper", "optional number line or 0–120 chart during instruction"]'::jsonb, '[{"term": "sequence", "definition": "numbers arranged in order"}, {"term": "forward", "definition": "moving to numbers that are one greater"}, {"term": "backward", "definition": "moving to numbers that are one less"}]'::jsonb,
      'Tell the student that Quarter 1 review is about bringing earlier skills back, not learning them for the first time. Begin with one number below 100 and one above 100.', 'Model a mixed sequence: read 108, count forward to 111, then count backward to 106. Show that the student can enter the sequence without restarting at 1.', 'Use errors diagnostically. If a previously mastered skill is shaky, note it for targeted review rather than changing the historical mastery record automatically.',
      'Quarter 1 started with numbers to 120.

Remember:
• read each numeral carefully
• count forward by one for the next number
• count backward by one for the previous number
• use the sequence to order numbers
• numbers continue through 100 to 120', 'Talk through the first three mixed review items.', 'Complete the mixed number-sequence work independently.', 'Number Route: choose a start number, give 3–6 forward or backward steps, then ask the student to state the landing number and one neighboring number.',
      'Quarter 1 Review — Numbers and Counting', 'Review numbers to 120 and forward/backward counting.', 'Complete all review items with at least 7 of 8 worksheet answers correct after corrections. Note any skill needing another short review before Week 9.',
      'Allow the same instructional supports used earlier, then remove them for one second attempt when appropriate.', 'Ask the student to create a forward/backward counting challenge that crosses 100.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Write the numeral for one hundred twelve.', 'Think 100, 10, and 2.', '112',
      'One hundred twelve is written 112.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Start at 58 and count forward four times. Where do you land?', 'Take four one-step counts.', '62',
      '58→59→60→61→62.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Start at 103 and count backward three times. Where do you land?', 'Move one less each time.', '100',
      '103→102→101→100.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'What number comes right before 90?', null, '89',
      '89 is immediately before 90.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'What number comes right after 119?', null, '120',
      '120 follows 119.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Order least to greatest: 74, 47, 70.', null, '47, 70, 74',
      '47 has 4 tens; 70 and 74 have 7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Show 106 as 100 plus extra ones.', null, '100 + 6',
      '106 is one hundred and six more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Write the numeral for ninety-eight.', null, '98',
      'Ninety-eight is written 98.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Continue forward: 97, 98, 99, __.', null, '100',
      '100 follows 99.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Continue backward: 102, 101, 100, __.', null, '99',
      '99 comes before 100.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Start at 46 and count forward five times. Where do you land?', null, '51',
      '46→47→48→49→50→51.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Start at 72 and count backward four times. Where do you land?', null, '68',
      '72→71→70→69→68.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Which is greatest: 109, 119, or 110?', null, '119',
      '119 is later in the counting sequence.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Order least to greatest: 61, 16, 60.', null, '16, 60, 61',
      '16 is least; 60 comes before 61.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'What number is between 114 and 116?', null, '115',
      '115 is between 114 and 116.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 8, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W08-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W08-D2 was not found.';
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
      'The student will spiral-review identifying, continuing, and explaining counting patterns by 2s, 5s, and 10s.', 'I can recognize and continue patterns by 2s, 5s, and 10s.', '["pencil", "paper", "scratch paper", "optional number line or 0–120 chart during instruction"]'::jsonb, '[{"term": "skip count", "definition": "count by the same amount each time"}, {"term": "rule", "definition": "the amount added each time in the pattern"}]'::jsonb,
      'Write three short patterns and ask the student to identify the rule before solving anything.', 'Review ones-digit clues: counting by 5s ends in 0 or 5; counting by 2s cycles through even endings; counting by 10s changes the tens while preserving the expected ones pattern.', 'Require rule identification before filling a blank when possible.',
      'Find the rule first:
by 2s → add 2
by 5s → add 5
by 10s → add 10

Then keep using the same jump.', 'Name each rule aloud before completing the pattern.', 'Complete the mixed skip-counting patterns independently.', 'Pattern Sort: sort 12 short sequences into by-2, by-5, and by-10 groups.',
      'Quarter 1 Review — Counting Patterns', 'Identify each skip-counting rule and complete the pattern.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain one ones-digit clue.',
      'Use a +2/+5/+10 reference card during guided review.', 'Create one pattern for each rule and remove one number for the instructor to find.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Continue by 2s: 34, 36, __, 40.', 'Add 2.', '38',
      'The pattern adds 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Continue by 5s: 45, 50, __, 60.', 'Add 5.', '55',
      'The pattern adds 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Continue by 10s: 60, 70, __, 90.', 'Add 10.', '80',
      'The pattern adds 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Which rule fits 22, 24, 26, 28?', null, 'count by 2s',
      'Each number increases by 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Which rule fits 35, 40, 45, 50?', null, 'count by 5s',
      'Each number increases by 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Which rule fits 40, 50, 60, 70?', null, 'count by 10s',
      'Each number increases by 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Continue: 92, 94, 96, __.', null, '98',
      'This pattern counts by 2s.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Continue by 2s: 58, 60, __, 64.', null, '62',
      'Add 2 each time.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Continue by 5s: 70, 75, __, 85.', null, '80',
      'Add 5 each time.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Continue by 10s: 20, 30, __, 50.', null, '40',
      'Add 10 each time.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Which rule fits 12, 14, 16, 18?', null, 'count by 2s',
      'The difference is 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Which rule fits 25, 30, 35, 40?', null, 'count by 5s',
      'The difference is 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Which rule fits 50, 60, 70, 80?', null, 'count by 10s',
      'The difference is 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Fill in: 95, 100, __, 110.', null, '105',
      'Counting by 5s gives 105.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Fill in: 106, 108, __, 112.', null, '110',
      'Counting by 2s gives 110.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 8, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W08-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W08-D3 was not found.';
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
      'The student will spiral-review tens and ones, digit value, composition, and decomposition of two-digit numbers.', 'I can show a two-digit number in different place-value forms.', '["pencil", "paper", "optional tens-and-ones chart", "optional base-ten drawings"]'::jsonb, '[{"term": "tens", "definition": "groups of ten"}, {"term": "ones", "definition": "single units"}, {"term": "expanded form", "definition": "a number written as the value of its places"}]'::jsonb,
      'Use 47 as a quick anchor: 4 tens, 7 ones, 40+7, value of 4 is 40, value of 7 is 7.', 'Model translating among numeral, tens-and-ones, and expanded form without treating them as separate tricks.', 'Watch for reversed digits and for forgetting zero ones in multiples of ten.',
      'One number can have several equivalent forms:
47
4 tens and 7 ones
40 + 7

The tens digit tells groups of ten. The ones digit tells leftover ones.', 'Translate among forms together.', 'Complete mixed place-value review independently.', 'Place-Value Triangle: choose a numeral and fill three corners—numeral, tens-and-ones, expanded form.',
      'Quarter 1 Review — Tens and Ones', 'Use place value to represent each two-digit number.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain the value of one tens digit and one ones digit.',
      'Use a three-column organizer for numeral / tens-and-ones / expanded form.', 'Create a place-value riddle with at least three clues.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Show 47 as tens and ones.', null, '4 tens and 7 ones',
      '47 has 4 groups of ten and 7 leftover ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Write 63 in expanded form.', null, '60 + 3',
      '6 tens are worth 60, plus 3 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'In 82, what is the value of the 8?', null, '80',
      'The 8 is in the tens place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'What number is 5 tens and 9 ones?', null, '59',
      '50 + 9 = 59.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'How many tens and ones are in 70?', null, '7 tens and 0 ones',
      '70 is seven tens with no leftover ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'In 36, what is the value of the 6?', null, '6',
      'The 6 is in the ones place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Give tens-and-ones form for 91.', null, '9 tens and 1 one',
      '91 is 90 + 1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Show 28 as tens and ones.', null, '2 tens and 8 ones',
      '28 has two tens and eight ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Write 54 in expanded form.', null, '50 + 4',
      '54 is five tens plus four ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'What number is 7 tens and 3 ones?', null, '73',
      '70 + 3 = 73.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'In 65, what is the value of the 6?', null, '60',
      'The 6 is in the tens place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'In 65, what is the value of the 5?', null, '5',
      'The 5 is in the ones place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'How many tens and ones are in 40?', null, '4 tens and 0 ones',
      '40 has zero leftover ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Write 18 as tens and ones.', null, '1 ten and 8 ones',
      '18 has one ten and eight ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Which expanded form shows 92?', null, '90 + 2',
      '9 tens are 90 and 2 ones are 2.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 8, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W08-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W08-D4 was not found.';
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
      'The student will spiral-review comparing two-digit numbers using >, <, and = with tens-first, ones-second reasoning.', 'I can compare two-digit numbers and explain why.', '["pencil", "paper", "scratch paper", "optional number line or 0–120 chart during instruction"]'::jsonb, '[{"term": "greater than", "definition": "larger value"}, {"term": "less than", "definition": "smaller value"}, {"term": "equal", "definition": "same value"}]'::jsonb,
      'Ask the student to state the comparison routine: tens first, then ones if needed, equality when both places match.', 'Model one different-tens pair, one same-tens pair, and one equal pair.', 'Ask for place-value reasoning rather than relying only on a symbol-shape mnemonic.',
      'Compare tens first.
If the tens match, compare ones.
If both places match, use =.', 'Say the reason before writing the symbol.', 'Complete the mixed comparisons independently.', 'Comparison Sort: sort solved cards into ''tens decided,'' ''ones decided,'' and ''equal.''',
      'Quarter 1 Review — Compare Two-Digit Numbers', 'Use >, <, or = and place-value reasoning.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain at least two comparisons.',
      'Allow a tens/ones chart during guided review.', 'Create one true example for each symbol.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Compare 47 and 52 using >, <, or =.', null, '<',
      '4 tens is less than 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Compare 68 and 63 using >, <, or =.', null, '>',
      'The tens match; 8 ones is greater than 3 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Compare 55 and 55 using >, <, or =.', null, '=',
      'Both values are the same.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Compare 29 and 31.', null, '<',
      '2 tens is less than 3 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Compare 74 and 71.', null, '>',
      'The tens match; 4 ones is greater than 1 one.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Order least to greatest: 42, 27, 35.', null, '27, 35, 42',
      'Compare tens first.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Which is greatest: 86, 68, 80?', null, '86',
      '86 has 8 tens and more ones than 80.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Choose the symbol: 38 __ 42.', null, '<',
      '3 tens is less than 4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Choose the symbol: 67 __ 61.', null, '>',
      'The tens match; 7 ones is greater than 1 one.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Choose the symbol: 50 __ 50.', null, '=',
      'Both values are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Choose the symbol: 79 __ 82.', null, '<',
      '7 tens is less than 8 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Choose the symbol: 93 __ 89.', null, '>',
      '9 tens is greater than 8 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Order least to greatest: 61, 16, 60.', null, '16, 60, 61',
      'Compare tens, then ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Order greatest to least: 73, 70, 37.', null, '73, 70, 37',
      '7 tens numbers come before 3 tens; compare ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Explain why 64 > 59.', null, '6 tens is greater than 5 tens',
      'The tens place decides the comparison.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 8, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W08-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W08-D5 was not found.';
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
      'The student will complete a mixed Quarter 1 readiness review across competencies 1-MATH-01 through 1-MATH-05 before the Week 8 spiral-review check.', 'I can bring all of my Quarter 1 number skills together.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "spiral review", "definition": "practice that brings back several earlier skills"}]'::jsonb,
      'Explain that this is mixed review: the type of problem changes from one item to the next.', 'Model how to pause and identify the skill being asked before solving.', 'Week 8 is review evidence, not the formal Quarter 1 mastery week. Use the results to target any final review before Week 9.',
      'Quarter 1 skills include:
• numbers to 120
• forward/backward counting
• patterns by 2s, 5s, 10s
• tens and ones
• comparing two-digit numbers', 'Work through one problem from several skill types.', 'Complete the readiness set independently.', 'Skill Label: after solving, label each item Number, Count, Pattern, Place Value, or Compare.',
      'Week 8 Spiral Review', 'Complete the mixed Quarter 1 review.', 'Complete the readiness review and Week 8 online check independently. Use misses to plan Week 9 preparation.',
      'Read directions aloud if needed without supplying mathematical steps.', 'Create one mixed-review problem from each Quarter 1 skill.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Write the numeral for one hundred seven.', null, '107',
      'One hundred seven is written 107.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Continue by 5s: 55, 60, __, 70.', null, '65',
      'Add 5 each time.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Show 42 as tens and ones.', null, '4 tens and 2 ones',
      '42 has four tens and two ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Start at 99 and count forward three times. Where do you land?', null, '102',
      '99→100→101→102.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Continue by 2s: 84, 86, __, 90.', null, '88',
      'Add 2 each time.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Write 76 in expanded form.', null, '70 + 6',
      '7 tens are 70 plus 6 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Compare 58 and 61.', null, '<',
      '5 tens is less than 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'What number comes right before 120?', null, '119',
      '119 comes before 120.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Continue backward: 102, 101, __.', null, '100',
      '100 comes before 101.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Continue by 10s: 50, 60, __, 80.', null, '70',
      'Add 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'What number is 6 tens and 4 ones?', null, '64',
      '60 + 4 = 64.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'In 83, what is the value of the 8?', null, '80',
      'The 8 is in the tens place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Compare 72 and 78.', null, '<',
      'The tens match; 2 ones is less than 8 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Order least to greatest: 49, 94, 44.', null, '44, 49, 94',
      'Compare tens first, then ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Which rule fits 30, 35, 40, 45?', null, 'count by 5s',
      'Each number increases by 5.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 9, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W09-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W09-D1 was not found.';
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
      'The student will independently rehearse Quarter 1 number-sequence competencies 1-MATH-01 and 1-MATH-02 in preparation for cumulative mastery evidence.', 'I can show that I still know numbers to 120 and can count from different starting points.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "mastery", "definition": "showing a skill accurately and independently over time"}]'::jsonb,
      'Explain that mastery week is not about cramming. The student is showing skills learned across the quarter.', 'Use one neutral model, then shift quickly to independent work.', 'Do not coach answers during independent portions. Record patterns of error for later instruction.',
      'Mastery means you can use a skill later, not only on the day you first learned it.', 'Complete three brief examples together.', 'Complete the rest independently.', 'Confidence Check: after each item, mark sure / unsure. Review only unsure items after scoring.',
      'Quarter 1 Mastery Prep — Numbers and Counting', 'Work independently and check the number sequence carefully.', 'Complete the review independently enough to identify true readiness for the cumulative check.',
      'Provide normal accommodations without giving number-sequence answers.', 'Create a counting challenge that crosses 100 in both directions.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Write the numeral for 118.', null, '118',
      'One hundred eighteen is 118.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Start at 96 and count forward five times.', null, '101',
      '96→97→98→99→100→101.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Start at 104 and count backward five times.', null, '99',
      '104→103→102→101→100→99.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'What number is between 109 and 111?', null, '110',
      '110 is between 109 and 111.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Order least to greatest: 117, 107, 110.', null, '107, 110, 117',
      'Compare the hundreds/tens/ones sequence.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'What number comes after 119?', null, '120',
      '120 follows 119.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'What number comes before 100?', null, '99',
      '99 comes before 100.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Write ninety-four as a numeral.', null, '94',
      'Ninety-four is 94.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Continue: 98, 99, __, 101.', null, '100',
      '100 lies between 99 and 101.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Continue backward: 112, 111, __, 109.', null, '110',
      '110 lies between 111 and 109.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Start at 87 and count forward four times.', null, '91',
      '87→88→89→90→91.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Start at 63 and count backward four times.', null, '59',
      '63→62→61→60→59.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Which is greatest: 108, 118, 111?', null, '118',
      '118 is greatest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Order least to greatest: 71, 17, 70.', null, '17, 70, 71',
      '17 is least, then 70, then 71.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Write one hundred twenty as a numeral.', null, '120',
      'One hundred twenty is 120.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 9, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W09-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W09-D2 was not found.';
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
      'The student will independently rehearse competency 1-MATH-03 by identifying and extending patterns by 2s, 5s, and 10s.', 'I can recognize skip-counting rules without being told which rule to use.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "rule", "definition": "the repeated change in a number pattern"}]'::jsonb,
      'Present one unlabeled pattern and ask the student to identify the rule.', 'Model checking the difference between neighboring numbers once, then let the student work independently.', 'Mastery evidence should show rule recognition, not only reciting memorized chants.',
      'Look at how much the numbers change. Decide +2, +5, or +10 before completing the pattern.', 'Identify the rule on three examples together.', 'Solve the remaining mixed patterns independently.', 'Rule Detective: explain what clue revealed the rule in one pattern.',
      'Quarter 1 Mastery Prep — Counting Patterns', 'Identify the rule and complete each pattern.', 'Demonstrate independent pattern recognition before Week 9 cumulative assessment.',
      'Allow a simple +2/+5/+10 reference only if it is a normal accommodation.', 'Generate a pattern that crosses 100.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Continue by 2s: 64, 66, __, 70.', null, '68',
      'Add 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Continue by 5s: 75, 80, __, 90.', null, '85',
      'Add 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Continue by 10s: 70, 80, __, 100.', null, '90',
      'Add 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Which rule fits 46, 48, 50, 52?', null, 'count by 2s',
      'Each increases by 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Which rule fits 65, 70, 75, 80?', null, 'count by 5s',
      'Each increases by 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Which rule fits 40, 50, 60, 70?', null, 'count by 10s',
      'Each increases by 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Continue: 98, 100, __, 104.', null, '102',
      'The pattern counts by 2s.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Continue by 2s: 74, 76, __, 80.', null, '78',
      'Add 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Continue by 5s: 85, 90, __, 100.', null, '95',
      'Add 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Continue by 10s: 20, 30, __, 50.', null, '40',
      'Add 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Rule for 12,14,16,18?', null, 'count by 2s',
      'Difference is 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Rule for 25,30,35,40?', null, 'count by 5s',
      'Difference is 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Rule for 30,40,50,60?', null, 'count by 10s',
      'Difference is 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Fill in: 105, 110, __, 120.', null, '115',
      'Count by 5s.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Fill in: 112, 114, __, 118.', null, '116',
      'Count by 2s.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 9, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W09-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W09-D3 was not found.';
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
      'The student will independently rehearse the full 1-MATH-04 place-value objective across representations and digit values.', 'I can show tens and ones in several forms without help.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "place value", "definition": "the value a digit has because of its position"}]'::jsonb,
      'Ask the student to show one two-digit number in three forms from memory.', 'Model a single example such as 62 = 6 tens 2 ones = 60+2.', 'Keep this preparation brief and independent.',
      'Check the tens digit, ones digit, and the value each place contributes.', 'Complete three examples together.', 'Complete mixed place-value problems independently.', 'Representation Check: prove one answer two different ways.',
      'Quarter 1 Mastery Prep — Place Value', 'Use tens and ones accurately in each form.', 'Demonstrate readiness across composition, decomposition, and digit value.',
      'Use the student''s established testing accommodations only.', 'Create a place-value riddle using digit values.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Show 58 as tens and ones.', null, '5 tens and 8 ones',
      '58 has five tens and eight ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Write 72 in expanded form.', null, '70 + 2',
      'Seven tens are 70 plus 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'In 46, what is the value of 4?', null, '40',
      '4 is in the tens place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'What number is 8 tens and 3 ones?', null, '83',
      '80+3=83.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'How many tens and ones are in 90?', null, '9 tens and 0 ones',
      '90 has nine tens, zero ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'In 27, what is the value of 7?', null, '7',
      '7 is in the ones place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Write 35 in expanded form.', null, '30 + 5',
      'Three tens plus five ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Show 61 as tens and ones.', null, '6 tens and 1 one',
      '61 is six tens and one one.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Write 84 in expanded form.', null, '80 + 4',
      '84 is 80+4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'What number is 4 tens and 9 ones?', null, '49',
      '40+9=49.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Value of 7 in 73?', null, '70',
      '7 is in the tens place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Value of 2 in 52?', null, '2',
      '2 is in the ones place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Show 30 as tens and ones.', null, '3 tens and 0 ones',
      '30 has zero leftover ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Write 19 as tens and ones.', null, '1 ten and 9 ones',
      '19 has one ten and nine ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'What number is 6 tens and 0 ones?', null, '60',
      'Six tens make 60.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 9, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W09-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W09-D4 was not found.';
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
      'The student will independently rehearse 1-MATH-05 by comparing and ordering two-digit numbers using explicit place-value reasoning.', 'I can compare numbers using tens first and ones second.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "reasoning", "definition": "the math explanation that proves an answer"}]'::jsonb,
      'Ask the student to state the comparison routine from memory.', 'Model one different-tens and one same-tens example, then stop modeling.', 'Require mathematical reasoning, not just a remembered symbol trick.',
      'Tens first. Ones second if needed. Equal when both values match.', 'Explain three examples together.', 'Solve and explain independently.', 'Proof Card: choose one comparison and write a one-sentence place-value proof.',
      'Quarter 1 Mastery Prep — Comparison', 'Use >, <, or = and explain with place value.', 'Demonstrate independent comparison reasoning before the cumulative check.',
      'Allow oral rather than written explanations if that is a normal accommodation.', 'Create a comparison where a larger ones digit belongs to the smaller overall number.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Compare 64 and 59.', null, '>',
      '6 tens is greater than 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Compare 72 and 78.', null, '<',
      'Tens match; 2 ones is less than 8 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Compare 43 and 43.', null, '=',
      'The values are equal.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Compare 81 and 76.', null, '>',
      '8 tens is greater than 7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Compare 35 and 39.', null, '<',
      'Tens match; 5 ones is less than 9 ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Order least to greatest: 66, 60, 63.', null, '60, 63, 66',
      'Same tens; compare ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Explain why 92 > 29.', null, '9 tens is greater than 2 tens',
      'The tens place decides.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Choose symbol: 48 __ 51.', null, '<',
      '4 tens is less than 5 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Choose symbol: 73 __ 70.', null, '>',
      'Same tens; 3 ones is greater.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Choose symbol: 24 __ 42.', null, '<',
      '2 tens is less than 4 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Choose symbol: 89 __ 87.', null, '>',
      'Same tens; 9 ones is greater.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Choose symbol: 31 __ 36.', null, '<',
      'Same tens; 1 one is less.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Choose symbol: 95 __ 95.', null, '=',
      'Equal values.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Order greatest to least: 77, 71, 75.', null, '77, 75, 71',
      'Same tens; compare ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Explain why 60 > 59.', null, '6 tens is greater than 5 tens',
      '60 has six tens while 59 has five tens.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 9, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W09-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W09-D5 was not found.';
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
      'The student will complete a cumulative Quarter 1 mastery readiness review across 1-MATH-01 through 1-MATH-05 and then take the Week 9 mastery check independently.', 'I can show what I remember from all of Quarter 1.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "cumulative", "definition": "including skills from several earlier weeks"}]'::jsonb,
      'Explain that the Week 9 assessment mixes skills intentionally. The student should identify what each question is asking before solving.', 'Model only one neutral mixed example. Do not rehearse exact assessment questions.', 'The Week 9 Friday template is already mapped to all five Quarter 1 competencies in the course structure. Treat the resulting score as cumulative evidence alongside prior competency evidence, not as the sole mastery decision.',
      'Read each problem carefully. Decide whether it is asking about a number, counting, a pattern, place value, or comparison.', 'Use three warm-up examples.', 'Complete the readiness set and Week 9 online mastery check independently.', 'Quarter Reflection: after the check, name one skill that feels strongest and one worth practicing again.',
      'Quarter 1 Mastery Readiness', 'Complete the mixed readiness set before the Quarter 1 Mastery Check.', 'Complete the Week 9 mastery assessment independently. Use existing competency thresholds and repeated evidence rules when interpreting mastery.',
      'Use normal accommodations, but do not supply operation, rule, place-value, or comparison answers.', 'Create one challenge question combining two Quarter 1 skills.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Write 116 as tens/hundreds form in words.', null, '1 hundred, 1 ten, and 6 ones',
      '116 decomposes to 100+10+6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Continue by 5s: 80,85,__ ,95.', null, '90',
      'Add 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Compare 67 and 76.', null, '<',
      '6 tens is less than 7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Start at 99 and count forward four times.', null, '103',
      '99→100→101→102→103.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Write 54 in expanded form.', null, '50 + 4',
      '54 is five tens and four ones.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Continue by 2s: 88,90,__ ,94.', null, '92',
      'Add 2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Compare 82 and 79.', null, '>',
      '8 tens is greater than 7 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'What number comes before 110?', null, '109',
      '109 comes before 110.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Continue by 10s: 60,70,__ ,90.', null, '80',
      'Add 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'What number is 7 tens and 2 ones?', null, '72',
      '70+2=72.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Value of 6 in 64?', null, '60',
      '6 is in the tens place.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Choose symbol: 58 __ 61.', null, '<',
      '5 tens is less than 6 tens.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Start at 104 and count backward three times.', null, '101',
      '104→103→102→101.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Rule for 45,50,55,60?', null, 'count by 5s',
      'Each increases by 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Order least to greatest: 49,94,44.', null, '44, 49, 94',
      'Compare tens then ones.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 10, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W10-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W10-D1 was not found.';
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
      'The student will model addition as joining/putting together and solve addition equations with sums through 10.', 'I can put two parts together and find the total.', '["pencil", "paper", "optional counters", "optional ten-frame"]'::jsonb, '[{"term": "add", "definition": "put amounts together to find the total"}, {"term": "sum", "definition": "the total found by addition"}, {"term": "addend", "definition": "a number being added"}]'::jsonb,
      'Make a group of 4 counters and a group of 3. Push them together and ask how many altogether. Connect the action to 4+3=7.', 'Model equation parts: 4 and 3 are addends; 7 is the sum. Show that the plus sign means combine/add.', 'Keep the conceptual joining model visible before moving to strategy work. Word-problem classification comes later; these are simple joining contexts only.',
      'Addition puts parts together.
4 + 3 = 7

The numbers being added are addends. The answer is the sum.', 'Model and solve with counters or drawings.', 'Solve simple addition within 10 independently.', 'Build the Equation: draw two small groups, combine them, and write the matching equation.',
      'Addition Means Put Together', 'Join the parts and solve each addition problem.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain what the plus sign means.',
      'Use counters or drawings and gradually fade them as the student becomes confident.', 'Create three different addition equations with sum 10.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'There are 4 red counters and 3 blue counters. How many altogether?', 'Combine both groups.', '7',
      '4 + 3 = 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 5 + 2.', 'Count all or count on.', '7',
      'Five and two more make seven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 6 + 3.', 'Combine the parts.', '9',
      'Six plus three equals nine.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 7 + 2.', null, '9',
      'Seven and two more make nine.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 4 + 5.', null, '9',
      'Four plus five equals nine.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 8 + 1.', null, '9',
      'One more than eight is nine.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 3 + 6.', null, '9',
      'Three and six make nine.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 2 + 5.', null, '7',
      '2 + 5 = 7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 6 + 4.', null, '10',
      '6 + 4 = 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 7 + 3.', null, '10',
      '7 + 3 = 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 5 + 5.', null, '10',
      '5 + 5 = 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 8 + 2.', null, '10',
      '8 + 2 = 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 9 + 1.', null, '10',
      '9 + 1 = 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 4 + 4.', null, '8',
      '4 + 4 = 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 3 + 7.', null, '10',
      '3 + 7 = 10.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 10, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W10-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W10-D2 was not found.';
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
      'The student will solve addition problems within 20 by counting on from a known starting addend rather than recounting from 1.', 'I can start at a number and count on to add.', '["pencil", "paper", "optional number line 0–20"]'::jsonb, '[{"term": "add", "definition": "put amounts together to find the total"}, {"term": "sum", "definition": "the total found by addition"}, {"term": "addend", "definition": "a number being added"}, {"term": "count on", "definition": "start with an addend and count forward the other amount"}]'::jsonb,
      'Compare solving 8+3 by recounting eight objects from 1 versus starting at 8 and saying 9,10,11.', 'Model number-line jumps and finger counts where the starting addend is held in mind.', 'Counting on is a bridge strategy. Encourage starting with the larger addend when convenient, but do not require commutativity language yet.',
      'To count on, start with one addend.
8 + 3:
Start at 8.
Count 9, 10, 11.
The sum is 11.', 'Count on together using a number line.', 'Use counting-on without rebuilding every amount from 1.', 'Number-Line Jumps: draw a start dot and the requested number of +1 jumps.',
      'Count On to Add', 'Start with the first addend and count forward the second amount.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and demonstrate counting on without restarting at 1.',
      'Use a number line or finger taps to track the number of jumps.', 'Choose whether starting with the first or second addend makes counting on easier.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 8 + 3 by counting on.', 'Start with 8 and count three more.', '11',
      'Start at 8: 9, 10, 11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 9 + 4 by counting on.', 'Take four forward steps.', '13',
      '9→10→11→12→13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 7 + 5 by counting on.', 'Take five forward steps.', '12',
      '7→8→9→10→11→12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 6 + 5.', null, '11',
      'Count on five from 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 10 + 4.', null, '14',
      'Count on four from 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 11 + 3.', null, '14',
      'Count on three from 11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 8 + 6.', null, '14',
      'Count on six from 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 5 + 6 by counting on.', null, '11',
      'Start at 5 and count forward 6 steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 9 + 5 by counting on.', null, '14',
      'Start at 9 and count forward 5 steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 10 + 7 by counting on.', null, '17',
      'Start at 10 and count forward 7 steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 12 + 4 by counting on.', null, '16',
      'Start at 12 and count forward 4 steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 7 + 6 by counting on.', null, '13',
      'Start at 7 and count forward 6 steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 11 + 5 by counting on.', null, '16',
      'Start at 11 and count forward 5 steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 8 + 7 by counting on.', null, '15',
      'Start at 8 and count forward 7 steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 13 + 3 by counting on.', null, '16',
      'Start at 13 and count forward 3 steps.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 10, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W10-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W10-D3 was not found.';
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
      'The student will use doubles and near-doubles strategies to solve addition facts within 20.', 'I can use a double I know to solve a nearby fact.', '["pencil", "paper", "optional counters in paired rows"]'::jsonb, '[{"term": "add", "definition": "put amounts together to find the total"}, {"term": "sum", "definition": "the total found by addition"}, {"term": "addend", "definition": "a number being added"}, {"term": "double", "definition": "adding the same number to itself"}, {"term": "near double", "definition": "an addition fact one away from a known double"}]'::jsonb,
      'Build 5+5 as two equal rows. Then add one counter to make 5+6. Ask what changed.', 'Model 7+7=14 and 7+8=15. Also model 9+9=18 and 9+8=17.', 'Do not require instant memorization. The objective is using structure to derive the sum.',
      'A double adds the same number twice:
7+7=14.

A near double is one more or one less:
7+8 is one more than 7+7, so it is 15.', 'Solve doubles first, then use them for near doubles.', 'Identify and use doubles/near doubles independently.', 'Double Match: pair each doubles fact card with a related near-double fact.',
      'Doubles and Near Doubles', 'Use doubles you know to solve nearby addition facts.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain one near-double strategy.',
      'Use paired counters or drawn rows to make the double visible.', 'Find two different doubles or near-double strategies that could help solve 8+9.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve the double: 4 + 4.', null, '8',
      'Double 4 is 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve the double: 7 + 7.', null, '14',
      'Double 7 is 14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Use 6 + 6 = 12 to solve 6 + 7.', 'Use the nearby double.', '13',
      '6 + 7 is one more than 6 + 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 5 + 5.', null, '10',
      'Double 5 is 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 8 + 8.', null, '16',
      'Double 8 is 16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Use 7 + 7 to solve 7 + 8.', null, '15',
      'One more than 14 is 15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Use 9 + 9 to solve 9 + 8.', null, '17',
      'One less than 18 is 17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 3 + 3.', null, '6',
      'Double 3 is 6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 6 + 6.', null, '12',
      'Double 6 is 12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 9 + 9.', null, '18',
      'Double 9 is 18.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Use 5 + 5 to solve 5 + 6.', null, '11',
      'One more than 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Use 8 + 8 to solve 8 + 9.', null, '17',
      'One more than 16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Use 7 + 7 to solve 7 + 6.', null, '13',
      'One less than 14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 10 + 10.', null, '20',
      'Double 10 is 20.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Use 4 + 4 to solve 4 + 5.', null, '9',
      'One more than 8.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 10, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W10-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W10-D4 was not found.';
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
      'The student will use a make-ten strategy to solve addition problems with sums through 20.', 'I can make 10 first to make addition easier.', '["pencil", "paper", "optional ten-frame", "optional counters"]'::jsonb, '[{"term": "add", "definition": "put amounts together to find the total"}, {"term": "sum", "definition": "the total found by addition"}, {"term": "addend", "definition": "a number being added"}, {"term": "make ten", "definition": "move part of an addend so one part becomes 10 first"}]'::jsonb,
      'Show 8+5 on a ten-frame. Ask how many more 8 needs to make 10. Move 2 from the group of 5, leaving 3.', 'Write the decomposition: 8+5 = 8+2+3 = 10+3 = 13. Repeat with 9+6.', 'Emphasize that the total does not change when one addend is broken apart.',
      'Make-ten steps:
1. Find what the first addend needs to reach 10.
2. Break that amount from the other addend.
3. Make 10.
4. Add what remains.', 'Use ten-frames or drawings to move the needed part.', 'Use make-ten independently on selected facts.', 'Make-Ten Split: write an addend on two small cards to show how it is split, such as 5→2+3 for 8+5.',
      'Make 10 to Add', 'Break apart an addend so you can make 10 first.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain the break-apart step on one problem.',
      'Use a ten-frame and physically move counters before writing equations.', 'Compare make-ten with a near-double strategy on one fact and choose the easier approach.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 8 + 5 by making 10.', 'Make 10 first.', '13',
      '8 needs 2 to make 10; split 5 into 2 and 3; 10+3=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 9 + 6 by making 10.', 'Move 1 to the 9.', '15',
      '9 needs 1; 6 becomes 1+5; 10+5=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 7 + 5 by making 10.', 'Make 10 with 7.', '12',
      '7 needs 3; split 5 into 3+2; 10+2=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 8 + 6.', null, '14',
      '8+2=10, then +4=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 9 + 4.', null, '13',
      '9+1=10, then +3=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 7 + 6.', null, '13',
      '7+3=10, then +3=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 6 + 5.', null, '11',
      '6+4=10, then +1=11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 8 + 4 by making 10.', null, '12',
      'Move enough from 4 to 8 to make 10, then add the rest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 9 + 7 by making 10.', null, '16',
      'Move enough from 7 to 9 to make 10, then add the rest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 7 + 5 by making 10.', null, '12',
      'Move enough from 5 to 7 to make 10, then add the rest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 6 + 6 by making 10.', null, '12',
      'Move enough from 6 to 6 to make 10, then add the rest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 8 + 7 by making 10.', null, '15',
      'Move enough from 7 to 8 to make 10, then add the rest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 9 + 3 by making 10.', null, '12',
      'Move enough from 3 to 9 to make 10, then add the rest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 7 + 8 by making 10.', null, '15',
      'Move enough from 8 to 7 to make 10, then add the rest.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 6 + 7 by making 10.', null, '13',
      'Move enough from 7 to 6 to make 10, then add the rest.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 10, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W10-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W10-D5 was not found.';
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
      'The student will independently demonstrate introductory addition-within-20 strategies before the Week 10 online check.', 'I can solve addition facts within 20 using a strategy.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "add", "definition": "put amounts together to find the total"}, {"term": "sum", "definition": "the total found by addition"}, {"term": "addend", "definition": "a number being added"}]'::jsonb,
      'Review the strategy names: join/model, count on, doubles/near doubles, make ten.', 'Model one neutral example and name why the chosen strategy is efficient.', 'Week 10 is the first of two evidence weeks for 1-MATH-06. Week 11 will deepen strategy choice and explanation.',
      'Choose a strategy that fits the fact. You do not have to solve every addition problem the same way.', 'Use three warm-up problems with different strategies.', 'Complete mixed readiness work and the online check independently.', 'Strategy Label: after solving, write C for count on, D for doubles, or T for make ten when one fits.',
      'Week 10 Addition Readiness', 'Solve each addition problem and use an efficient strategy.', 'Complete the Week 10 readiness review and online assessment independently under the configured 85% evidence threshold.',
      'Use normal accommodations such as scratch paper or number line if documented.', 'Find two different strategies for the same addition fact.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 8 + 7.', null, '15',
      'A make-ten or near-double strategy gives 15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 9 + 6.', null, '15',
      'Make 10: 9+1+5=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 7 + 7.', null, '14',
      'Double 7 is 14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 12 + 5.', null, '17',
      'Count on five from 12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 6 + 8.', null, '14',
      'Make ten or use near doubles.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 9 + 9.', null, '18',
      'Double 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 5 + 7.', null, '12',
      'Count on or use 6+6 related thinking.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 8 + 5.', null, '13',
      '8+5=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 9 + 7.', null, '16',
      '9+7=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 6 + 6.', null, '12',
      '6+6=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 11 + 6.', null, '17',
      '11+6=17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 7 + 9.', null, '16',
      '7+9=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 10 + 8.', null, '18',
      '10+8=18.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 5 + 8.', null, '13',
      '5+8=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 4 + 9.', null, '13',
      '4+9=13.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 11, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W11-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W11-D1 was not found.';
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
      'The student will decompose an addend to make ten and solve addition facts within 20 with a recorded strategy.', 'I can break apart a number to make 10 and add the rest.', '["pencil", "paper", "optional ten-frame"]'::jsonb, '[{"term": "add", "definition": "put amounts together to find the total"}, {"term": "sum", "definition": "the total found by addition"}, {"term": "addend", "definition": "a number being added"}, {"term": "decompose", "definition": "break a number into smaller parts without changing its total"}]'::jsonb,
      'Return to 9+8. Ask what 9 needs to make 10, then break 8 into 1 and 7.', 'Record 9+8 = 9+1+7 = 10+7 = 17. Model another example where the first addend needs 2, 3, or 4.', 'The student should understand the break-apart amount, not memorize rewritten equations mechanically.',
      'Decompose means break apart.
For 8+7, split 7 into 2+5.
8+2=10, then 10+5=15.', 'Say what the first addend needs to make 10 before splitting.', 'Record the make-ten decomposition independently.', 'Ten Partner Cards: match each number 6–9 with what it needs to make 10, then use those partners in addition facts.',
      'Decompose to Make Ten', 'Break apart one addend, make 10, then add what remains.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and accurately show one decomposition.',
      'Use a ten-frame and two-color counters to show the moved part.', 'Explain why changing 8+7 into 8+2+5 does not change the total.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 9 + 8 by making 10.', 'Break apart 8.', '17',
      'Split 8 into 1+7; 9+1=10; 10+7=17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 8 + 7 by making 10.', 'Break apart 7.', '15',
      'Split 7 into 2+5; 8+2=10; 10+5=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 6 + 8 by making 10.', 'Find what 6 needs to reach 10.', '14',
      'Split 8 into 4+4; 6+4=10; 10+4=14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 9 + 9.', null, '18',
      '9+1=10, then add remaining 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 8 + 5.', null, '13',
      '8+2=10, then +3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 7 + 9.', null, '16',
      '7+3=10, then +6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 6 + 9.', null, '15',
      '6+4=10, then +5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 9 + 5. Show a make-ten break-apart.', null, '14',
      'Decompose one addend to make 10 first.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 8 + 8. Show a make-ten break-apart.', null, '16',
      'Decompose one addend to make 10 first.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 7 + 7. Show a make-ten break-apart.', null, '14',
      'Decompose one addend to make 10 first.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 6 + 8. Show a make-ten break-apart.', null, '14',
      'Decompose one addend to make 10 first.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 9 + 6. Show a make-ten break-apart.', null, '15',
      'Decompose one addend to make 10 first.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 8 + 9. Show a make-ten break-apart.', null, '17',
      'Decompose one addend to make 10 first.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 7 + 6. Show a make-ten break-apart.', null, '13',
      'Decompose one addend to make 10 first.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 6 + 5. Show a make-ten break-apart.', null, '11',
      'Decompose one addend to make 10 first.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 11, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W11-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W11-D2 was not found.';
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
      'The student will select an efficient strategy—count on, doubles/near doubles, or make ten—to solve addition within 20.', 'I can choose a strategy that fits the addition fact.', '["pencil", "paper", "optional strategy reference card"]'::jsonb, '[{"term": "add", "definition": "put amounts together to find the total"}, {"term": "sum", "definition": "the total found by addition"}, {"term": "addend", "definition": "a number being added"}, {"term": "efficient", "definition": "a method that solves accurately without unnecessary steps"}]'::jsonb,
      'Show 6+6, 9+5, and 12+3. Ask whether one strategy is best for all three.', 'Model strategy choice: doubles for 6+6, make ten for 9+5, count on for 12+3.', 'A strategy is efficient when it uses the structure of the fact. Do not grade the strategy label rigidly if another valid strategy is explained correctly.',
      'Different facts can suggest different strategies.
6+6 → doubles
9+5 → make ten
12+3 → count on', 'Choose and explain a strategy together.', 'Solve independently and name one efficient strategy.', 'Strategy Sort: sort fact cards under Count On, Doubles/Near Doubles, or Make Ten. Discuss facts that could fit more than one.',
      'Choose an Addition Strategy', 'Solve each fact and name an efficient strategy.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and justify at least two strategy choices.',
      'Use a visual strategy menu without worked answers.', 'Find a fact that can be solved efficiently in two different ways.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 6 + 6. Which strategy is efficient: doubles or counting every object?', 'Use the structure of the fact.', '12; doubles',
      '6+6 is a known double.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 9 + 5. Which strategy is efficient: make ten or recount from 1?', 'Make ten.', '14; make ten',
      '9 needs 1 to make 10, then 4 more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 12 + 3. Which strategy is efficient: count on or rebuild 12 objects?', 'Count on.', '15; count on',
      'Start at 12 and count 13,14,15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 7 + 7 and name a strategy.', null, '14; doubles',
      '7+7 is a double.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 8 + 5 and name a strategy.', null, '13; make ten',
      '8+2=10 then +3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 11 + 4 and name a strategy.', null, '15; count on',
      'Count four more from 11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 6 + 7 and name a strategy.', null, '13; near double',
      '6+6=12, then one more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 5 + 5. Name an efficient strategy.', null, '10; doubles',
      'Use the double.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 9 + 8. Name an efficient strategy.', null, '17; make ten',
      '9+1=10, then +7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 13 + 4. Name an efficient strategy.', null, '17; count on',
      'Count four from 13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 8 + 8. Name an efficient strategy.', null, '16; doubles',
      'Use the double.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 7 + 8. Name an efficient strategy.', null, '15; near double',
      '7+7=14 then +1.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 9 + 4. Name an efficient strategy.', null, '13; make ten',
      '9+1=10 then +3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 10 + 6. Name an efficient strategy.', null, '16; count on',
      'Six more than 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 6 + 6. Name an efficient strategy.', null, '12; doubles',
      'Use the double.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 11, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W11-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W11-D3 was not found.';
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
      'The student will solve mixed addition within 20 independently and check answers using a second strategy when useful.', 'I can solve mixed addition facts and check my thinking.', '["pencil", "scratch paper", "optional number line"]'::jsonb, '[{"term": "add", "definition": "put amounts together to find the total"}, {"term": "sum", "definition": "the total found by addition"}, {"term": "addend", "definition": "a number being added"}]'::jsonb,
      'Explain that mixed practice removes the strategy label. The student chooses a method based on the numbers.', 'Model solving 8+7 with make ten and checking with near doubles.', 'Checking with a second method is for reasoning, not required for every item.',
      'When the strategy is not named, look at the numbers and choose one:
count on
use a double
make ten
or another accurate model.', 'Choose strategies together for three facts.', 'Solve mixed facts independently.', 'Two-Way Check: choose two problems and solve each in two ways.',
      'Mixed Addition Within 20', 'Solve each addition fact. Use the strategy that makes sense to you.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and check at least one answer a second way.',
      'Allow strategy drawings or number-line work in the margin.', 'Explain which strategy feels most efficient for you and when it works best.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 8 + 7.', null, '15',
      'A make-ten or near-double strategy gives 15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 9 + 6.', null, '15',
      'Make 10: 9+1+5=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 7 + 7.', null, '14',
      'Double 7 is 14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 12 + 5.', null, '17',
      'Count on five from 12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 6 + 8.', null, '14',
      'Make ten or use near doubles.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 9 + 9.', null, '18',
      'Double 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 5 + 7.', null, '12',
      'Count on or use 6+6 related thinking.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 8 + 5.', null, '13',
      '8+5=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 9 + 7.', null, '16',
      '9+7=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 6 + 6.', null, '12',
      '6+6=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 11 + 6.', null, '17',
      '11+6=17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 7 + 9.', null, '16',
      '7+9=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 10 + 8.', null, '18',
      '10+8=18.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 5 + 8.', null, '13',
      '5+8=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 4 + 9.', null, '13',
      '4+9=13.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 11, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W11-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W11-D4 was not found.';
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
      'The student will solve addition within 20 and explain at least one strategy using an equation, drawing, number line, or written/oral reasoning.', 'I can explain how my addition strategy works.', '["pencil", "paper", "optional number line or ten-frame"]'::jsonb, '[{"term": "add", "definition": "put amounts together to find the total"}, {"term": "sum", "definition": "the total found by addition"}, {"term": "addend", "definition": "a number being added"}, {"term": "explain", "definition": "show or tell the mathematical steps that support an answer"}]'::jsonb,
      'Show that a correct answer is stronger when the student can show why it works.', 'Model a short explanation for make-ten, near-double, and count-on examples.', 'Accept oral explanation, drawing, equation decomposition, or number-line proof. The competency explicitly requires explaining at least one strategy.',
      'A strategy explanation can be:
• a drawing
• number-line jumps
• a break-apart equation
• a sentence describing a double or count-on method', 'Explain three examples together.', 'Solve and explain independently.', 'Teach Back: choose one fact and teach the strategy to the instructor as if the instructor has never seen it.',
      'Explain Your Addition Strategy', 'Solve each problem and show or tell a strategy.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and provide at least one mathematically accurate strategy explanation.',
      'Allow oral dictation or drawing instead of full written sentences.', 'Explain one fact in two different ways and compare the methods.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 8 + 6 and explain one strategy.', null, '14',
      'Example: 8+2=10 and 4 more makes 14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 7 + 8 and explain one strategy.', null, '15',
      'Example: 7+7=14 and one more is 15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 12 + 4 and explain one strategy.', null, '16',
      'Example: count on 13,14,15,16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 9 + 5 and write a strategy sentence.', null, '14',
      'Make ten: 9+1=10, then 4 more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 6 + 7 and write a strategy sentence.', null, '13',
      'Near double: 6+6=12, then one more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 8 + 8 and write a strategy sentence.', null, '16',
      'Double 8 is 16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 13 + 5 and write a strategy sentence.', null, '18',
      'Count on five from 13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 7 + 6 and explain.', null, '13',
      'Any accurate strategy explanation is acceptable; e.g. 6+6=12 and one more.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 9 + 8 and explain.', null, '17',
      'E.g. make 10: 9+1+7=17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 5 + 5 and explain.', null, '10',
      'Double 5 is 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 11 + 7 and explain.', null, '18',
      'Count on seven from 11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 8 + 5 and explain.', null, '13',
      'Make 10: 8+2+3=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 6 + 9 and explain.', null, '15',
      'Make 10: 6+4+5=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 7 + 7 and explain.', null, '14',
      'Double 7 is 14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 12 + 6 and explain.', null, '18',
      'Count on six from 12.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 11, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W11-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W11-D5 was not found.';
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
      'The student will independently demonstrate the full 1-MATH-06 addition-within-20 objective across mixed facts and strategy explanation before the Week 11 online check.', 'I can solve addition within 20 and explain a strategy.', '["pencil", "scratch paper"]'::jsonb, '[{"term": "add", "definition": "put amounts together to find the total"}, {"term": "sum", "definition": "the total found by addition"}, {"term": "addend", "definition": "a number being added"}]'::jsonb,
      'Ask the student to name three strategies from the two-week addition block and give one example fact for each.', 'Model one neutral fact only, then transition to independent readiness.', 'Week 11 supplies a second addition assessment opportunity for repeated independent evidence.',
      'Use what fits the numbers. Accuracy matters, and so does understanding how you got the answer.', 'Use three mixed warm-up facts.', 'Complete readiness and online assessment independently.', 'Strategy Reflection: choose one assessment-style fact and explain the strategy you would choose before solving.',
      'Week 11 Addition Mastery Readiness', 'Solve mixed addition facts within 20 and be ready to explain a strategy.', 'Complete Week 11 readiness and online assessment independently using the existing repeated-evidence mastery rules.',
      'Normal accommodations are allowed without giving the strategy or answer.', 'Create one addition fact for each of three strategies and solve them.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 8 + 7.', null, '15',
      'A make-ten or near-double strategy gives 15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 9 + 6.', null, '15',
      'Make 10: 9+1+5=15.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 7 + 7.', null, '14',
      'Double 7 is 14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 12 + 5.', null, '17',
      'Count on five from 12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 6 + 8.', null, '14',
      'Make ten or use near doubles.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 9 + 9.', null, '18',
      'Double 9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 5 + 7.', null, '12',
      'Count on or use 6+6 related thinking.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 8 + 5.', null, '13',
      '8+5=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 9 + 7.', null, '16',
      '9+7=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 6 + 6.', null, '12',
      '6+6=12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 11 + 6.', null, '17',
      '11+6=17.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 7 + 9.', null, '16',
      '7+9=16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 10 + 8.', null, '18',
      '10+8=18.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 5 + 8.', null, '13',
      '5+8=13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 4 + 9.', null, '13',
      '4+9=13.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 12, Day 1
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W12-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W12-D1 was not found.';
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
      'The student will model subtraction as taking away/separating and solve subtraction problems within 10.', 'I can take away part of a group and find how many remain.', '["pencil", "paper", "optional counters", "optional ten-frame"]'::jsonb, '[{"term": "subtract", "definition": "find what remains or the difference between amounts"}, {"term": "difference", "definition": "the result of subtraction"}, {"term": "minus", "definition": "the subtraction symbol −"}]'::jsonb,
      'Place 8 counters, remove 3, and count what remains. Write 8−3=5 to connect the action to the equation.', 'Model the minus sign as an instruction to subtract/take away in these introductory examples. Identify the result as the difference.', 'Later lessons add other subtraction meanings and strategies. Today keep the action concrete.',
      'Subtraction can describe taking away.
8 − 3 = 5

Start with 8, remove 3, and 5 remain.', 'Use counters or drawings to model each subtraction.', 'Solve simple take-away subtraction independently.', 'Act It Out: build a starting group, physically remove the second number, then write the equation.',
      'Subtraction Means Take Away', 'Take away the second amount and find what remains.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain what the minus sign means in a take-away model.',
      'Use counters or crossed-out drawings.', 'Create three different subtraction equations that begin with 10.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'You have 8 counters and take away 3. How many remain?', 'Remove three from eight.', '5',
      '8−3=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 9 − 4.', 'Model the removal.', '5',
      'Taking 4 from 9 leaves 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 10 − 6.', 'Count what remains.', '4',
      'Ten take away six leaves four.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 7 − 2.', null, '5',
      'Seven take away two is five.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 10 − 3.', null, '7',
      'Ten take away three is seven.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 9 − 5.', null, '4',
      'Nine take away five is four.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 8 − 6.', null, '2',
      'Eight take away six is two.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 6 − 2.', null, '4',
      '6−2=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 8 − 3.', null, '5',
      '8−3=5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 10 − 4.', null, '6',
      '10−4=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 9 − 2.', null, '7',
      '9−2=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 7 − 5.', null, '2',
      '7−5=2.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 10 − 7.', null, '3',
      '10−7=3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 5 − 1.', null, '4',
      '5−1=4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 9 − 6.', null, '3',
      '9−6=3.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 12, Day 2
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W12-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W12-D2 was not found.';
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
      'The student will solve subtraction within 20 by counting backward on a number line.', 'I can start at a number and count back to subtract.', '["pencil", "paper", "optional number line 0–20"]'::jsonb, '[{"term": "subtract", "definition": "find what remains or the difference between amounts"}, {"term": "difference", "definition": "the result of subtraction"}, {"term": "minus", "definition": "the subtraction symbol −"}, {"term": "count back", "definition": "start at the first number and move backward the amount being subtracted"}]'::jsonb,
      'Connect subtraction to the backward-counting skill from Quarter 1. Start at 13 and move back four steps.', 'Model 13−4 with number-line jumps. Emphasize that the starting number is not counted as one of the steps.', 'Track the number of jumps carefully; off-by-one errors are common.',
      'To count back:
Start at the first number.
Take the number of backward steps shown after the minus sign.
The landing number is the difference.', 'Count back together on a number line.', 'Use backward jumps independently.', 'Jump Track: draw a number line and label each backward jump 1,2,3... until all steps are used.',
      'Count Back to Subtract', 'Start at the first number and move backward the subtraction amount.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and demonstrate correct step counting.',
      'Use a number line with highlighted start and landing dots.', 'Compare count-back efficiency on subtracting 2 versus subtracting 9.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 13 − 4 by counting back.', 'Take four backward steps.', '9',
      '13→12→11→10→9.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 15 − 3 by counting back.', 'Count back three.', '12',
      '15→14→13→12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 12 − 5 by counting back.', 'Count back five.', '7',
      '12→11→10→9→8→7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 14 − 4.', null, '10',
      'Count back four from 14.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 16 − 5.', null, '11',
      'Count back five from 16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 11 − 3.', null, '8',
      'Count back three from 11.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 18 − 6.', null, '12',
      'Count back six from 18.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 13 − 5 by counting back.', null, '8',
      'Start at 13 and move back 5 steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 17 − 4 by counting back.', null, '13',
      'Start at 17 and move back 4 steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 15 − 6 by counting back.', null, '9',
      'Start at 15 and move back 6 steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 12 − 4 by counting back.', null, '8',
      'Start at 12 and move back 4 steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 19 − 5 by counting back.', null, '14',
      'Start at 19 and move back 5 steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 16 − 7 by counting back.', null, '9',
      'Start at 16 and move back 7 steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 14 − 3 by counting back.', null, '11',
      'Start at 14 and move back 3 steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 18 − 8 by counting back.', null, '10',
      'Start at 18 and move back 8 steps.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 12, Day 3
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W12-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W12-D3 was not found.';
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
      'The student will solve subtraction within 20 by counting on from the smaller number to find the difference.', 'I can count up to find how far apart two numbers are.', '["pencil", "paper", "optional number line 0–20"]'::jsonb, '[{"term": "subtract", "definition": "find what remains or the difference between amounts"}, {"term": "difference", "definition": "the result of subtraction"}, {"term": "minus", "definition": "the subtraction symbol −"}, {"term": "count on to subtract", "definition": "count from the smaller number up to the larger number to find the distance"}]'::jsonb,
      'Ask which feels easier for 13−9: counting back nine steps or counting from 9 up to 13. Demonstrate both.', 'Model 13−9 by counting 9→10→11→12→13 and tracking four steps.', 'Counting on is especially useful when the numbers are close. This also prepares for addition/subtraction relationships later.',
      'Subtraction can ask how far apart two numbers are.
13 − 9:
Count from 9 up to 13.
There are 4 steps, so the difference is 4.', 'Count up together and track the number of steps.', 'Use counting-on for close-number subtraction.', 'Distance Walk: mark two numbers on a line and count the spaces between them.',
      'Count On to Find the Difference', 'Count from the smaller number up to the larger number.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain why the number of steps is the difference.',
      'Use a number line and mark each counted interval.', 'Decide whether count-back or count-on is more efficient for several subtraction facts.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 13 − 9 by counting on from 9 to 13.', 'Find how far apart the numbers are.', '4',
      '9→10→11→12→13 is four steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 15 − 12 by counting on.', 'Count from 12 up to 15.', '3',
      '12→13→14→15 is three steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 11 − 8 by counting on.', 'Count the distance.', '3',
      '8→9→10→11 is three steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 14 − 10.', null, '4',
      '10 to 14 is four steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 16 − 13.', null, '3',
      '13 to 16 is three steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 12 − 9.', null, '3',
      '9 to 12 is three steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 18 − 15.', null, '3',
      '15 to 18 is three steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 13 − 10 by counting on from 10.', null, '3',
      'Count from 10 up to 13; the number of steps is 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 17 − 14 by counting on from 14.', null, '3',
      'Count from 14 up to 17; the number of steps is 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 15 − 11 by counting on from 11.', null, '4',
      'Count from 11 up to 15; the number of steps is 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 12 − 8 by counting on from 8.', null, '4',
      'Count from 8 up to 12; the number of steps is 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 19 − 16 by counting on from 16.', null, '3',
      'Count from 16 up to 19; the number of steps is 3.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 16 − 12 by counting on from 12.', null, '4',
      'Count from 12 up to 16; the number of steps is 4.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 14 − 9 by counting on from 9.', null, '5',
      'Count from 9 up to 14; the number of steps is 5.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 18 − 13 by counting on from 13.', null, '5',
      'Count from 13 up to 18; the number of steps is 5.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 12, Day 4
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W12-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W12-D4 was not found.';
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
      'The student will decompose the amount being subtracted to use 10 as a helpful stopping point when solving subtraction within 20.', 'I can break apart the subtraction amount and use 10 to help.', '["pencil", "paper", "optional ten-frame or number line"]'::jsonb, '[{"term": "subtract", "definition": "find what remains or the difference between amounts"}, {"term": "difference", "definition": "the result of subtraction"}, {"term": "minus", "definition": "the subtraction symbol −"}, {"term": "decompose", "definition": "break a number into smaller parts"}]'::jsonb,
      'Use 14−6. Ask how many steps from 14 back to 10. Since that uses 4 of the 6, there are 2 more to subtract.', 'Record 14−6 = 14−4−2 = 10−2 = 8. Repeat with 13−5.', 'This is strategy development, not a requirement to rewrite every subtraction equation formally.',
      'Use 10 as a stopping point:
14−6
First subtract 4 to reach 10.
There are 2 more to subtract.
10−2=8.', 'Break apart the subtraction amount together.', 'Use the make-ten stopping point independently.', 'Break-Apart Cards: split the subtracted number into ''to 10'' and ''after 10'' parts.',
      'Use 10 to Subtract', 'Break apart the number being subtracted so you can stop at 10 first.', 'Complete all items with at least 7 of 8 worksheet answers correct after corrections and explain one break-apart strategy.',
      'Use a number line and color the jumps to 10 differently from the remaining jumps.', 'Compare count-back and use-10 strategies for the same subtraction fact.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 14 − 6 by going back to 10 first.', 'Split 6 into 4 and 2.', '8',
      '14−4=10, then subtract 2 more: 8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 13 − 5 by going back to 10.', 'Split 5 into 3 and 2.', '8',
      '13−3=10, then −2=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 17 − 9 by going back to 10.', 'Split 9 into 7 and 2.', '8',
      '17−7=10, then −2=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 15 − 7.', null, '8',
      '15−5=10, then −2=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 12 − 4.', null, '8',
      '12−2=10, then −2=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 16 − 9.', null, '7',
      '16−6=10, then −3=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 13 − 7.', null, '6',
      '13−3=10, then −4=6.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 14 − 5 by using 10 as a helpful stopping point.', null, '9',
      'Break 5 apart so the first subtraction lands on 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 15 − 8 by using 10 as a helpful stopping point.', null, '7',
      'Break 8 apart so the first subtraction lands on 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 12 − 5 by using 10 as a helpful stopping point.', null, '7',
      'Break 5 apart so the first subtraction lands on 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 17 − 8 by using 10 as a helpful stopping point.', null, '9',
      'Break 8 apart so the first subtraction lands on 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 13 − 6 by using 10 as a helpful stopping point.', null, '7',
      'Break 6 apart so the first subtraction lands on 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 18 − 9 by using 10 as a helpful stopping point.', null, '9',
      'Break 9 apart so the first subtraction lands on 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 16 − 7 by using 10 as a helpful stopping point.', null, '9',
      'Break 7 apart so the first subtraction lands on 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 11 − 4 by using 10 as a helpful stopping point.', null, '7',
      'Break 4 apart so the first subtraction lands on 10.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 12, Day 5
    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W12-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W12-D5 was not found.';
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
      'The student will independently demonstrate introductory subtraction-within-20 strategies before the Week 12 online check.', 'I can subtract within 20 using a strategy that makes sense.', '["pencil", "scratch paper", "optional number line if normally used"]'::jsonb, '[{"term": "subtract", "definition": "find what remains or the difference between amounts"}, {"term": "difference", "definition": "the result of subtraction"}, {"term": "minus", "definition": "the subtraction symbol −"}]'::jsonb,
      'Review the strategy names: take away/model, count back, count on to find a difference, and use 10 as a stopping point.', 'Model one neutral fact and explain why a particular strategy is efficient.', 'Week 12 is the first of two weeks on 1-MATH-07. Week 13 will deepen subtraction strategy choice and explanation.',
      'Subtraction can be solved in more than one way. Choose a strategy that helps you see the difference accurately.', 'Use three mixed warm-up items.', 'Complete readiness and the online Week 12 Check independently.', 'Strategy Label: after solving selected problems, identify Take Away, Count Back, Count On, or Use 10.',
      'Week 12 Subtraction Readiness', 'Solve each subtraction problem and use an accurate strategy.', 'Complete Week 12 readiness and online assessment independently under the configured 85% evidence threshold.',
      'Use normal accommodations without supplying a strategy or answer.', 'Find two different strategies for one subtraction fact.',
      null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Solve 12 − 4.', null, '8',
      'Count back four or use 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Solve 14 − 9.', null, '5',
      'Count on from 9 to 14 gives five steps.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Solve 15 − 7.', null, '8',
      'Use 10: 15−5=10, then −2=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Solve 13 − 5.', null, '8',
      '13−3=10, then −2=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Solve 17 − 4.', null, '13',
      'Count back four.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Solve 16 − 13.', null, '3',
      'Count on from 13 to 16.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Solve 11 − 6.', null, '5',
      'Count back or use 10.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Solve 14 − 6.', null, '8',
      '14−4=10 then −2=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Solve 18 − 5.', null, '13',
      'Count back five.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Solve 12 − 9.', null, '3',
      'Count on from 9 to 12.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Solve 15 − 8.', null, '7',
      '15−5=10 then −3=7.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Solve 10 − 7.', null, '3',
      'Take away seven from ten.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Solve 17 − 9.', null, '8',
      '17−7=10 then −2=8.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Solve 13 − 10.', null, '3',
      'Count on from 10 to 13.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Solve 16 − 6.', null, '10',
      'Subtract six to land on ten.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Week 8 online Friday check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 8
      and l.week_number = 8
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W08-Q01', 1, 'short_answer', 'What number comes right after 109?', '[]'::jsonb, '110', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W08-Q02', 2, 'short_answer', 'Start at 72 and count backward three times. Where do you land?', '[]'::jsonb, '69', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W08-Q03', 3, 'short_answer', 'Continue by 2s: 84, 86, __, 90', '[]'::jsonb, '88', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W08-Q04', 4, 'short_answer', 'Continue by 5s: 70, 75, __, 85', '[]'::jsonb, '80', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W08-Q05', 5, 'multiple_choice', 'Which shows 64 correctly?', '[{"id": "a", "label": "6 tens and 4 ones"}, {"id": "b", "label": "4 tens and 6 ones"}, {"id": "c", "label": "60 tens and 4 ones"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W08-Q06', 6, 'multiple_choice', 'In 83, what is the value of the 8?', '[{"id": "a", "label": "8"}, {"id": "b", "label": "80"}, {"id": "c", "label": "3"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W08-Q07', 7, 'multiple_choice', 'Choose the correct symbol: 58 __ 61', '[{"id": "a", "label": "<"}, {"id": "b", "label": ">"}, {"id": "c", "label": "="}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W08-Q08', 8, 'multiple_choice', 'Choose the correct symbol: 72 __ 78', '[{"id": "a", "label": "<"}, {"id": "b", "label": ">"}, {"id": "c", "label": "="}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W08-Q09', 9, 'short_answer', 'Write the numeral for one hundred seventeen.', '[]'::jsonb, '117', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W08-Q10', 10, 'short_answer', 'Continue by 10s: 50, 60, __, 80', '[]'::jsonb, '70', 1);


    -- Freeze the question bank onto still-open assignments that may have been
    -- generated before this curriculum content was installed.
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


    -- Week 9 online Friday check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 9
      and l.week_number = 9
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W09-Q01', 1, 'short_answer', 'Start at 99 and count forward three times. Where do you land?', '[]'::jsonb, '102', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W09-Q02', 2, 'short_answer', 'Write the numeral for one hundred twelve.', '[]'::jsonb, '112', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W09-Q03', 3, 'short_answer', 'Continue by 2s: 94, 96, __, 100', '[]'::jsonb, '98', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W09-Q04', 4, 'multiple_choice', 'Which rule fits 55, 60, 65, 70?', '[{"id": "a", "label": "count by 2s"}, {"id": "b", "label": "count by 5s"}, {"id": "c", "label": "count by 10s"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W09-Q05', 5, 'multiple_choice', 'Which shows 47 correctly?', '[{"id": "a", "label": "4 tens and 7 ones"}, {"id": "b", "label": "7 tens and 4 ones"}, {"id": "c", "label": "40 tens and 7 ones"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W09-Q06', 6, 'multiple_choice', 'In 62, what is the value of the 6?', '[{"id": "a", "label": "6"}, {"id": "b", "label": "60"}, {"id": "c", "label": "2"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W09-Q07', 7, 'multiple_choice', 'Choose the correct symbol: 68 __ 63', '[{"id": "a", "label": "<"}, {"id": "b", "label": ">"}, {"id": "c", "label": "="}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W09-Q08', 8, 'multiple_choice', 'Choose the correct symbol: 45 __ 45', '[{"id": "a", "label": "<"}, {"id": "b", "label": ">"}, {"id": "c", "label": "="}]'::jsonb, 'c', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W09-Q09', 9, 'short_answer', 'Write 73 in expanded form.', '[]'::jsonb, '70 + 3', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W09-Q10', 10, 'short_answer', 'Start at 104 and count backward five times. Where do you land?', '[]'::jsonb, '99', 1);


    -- Freeze the question bank onto still-open assignments that may have been
    -- generated before this curriculum content was installed.
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


    -- Week 10 online Friday check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 10
      and l.week_number = 10
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W10-Q01', 1, 'short_answer', 'Solve 7 + 5.', '[]'::jsonb, '12', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W10-Q02', 2, 'short_answer', 'Solve 9 + 4.', '[]'::jsonb, '13', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W10-Q03', 3, 'short_answer', 'Solve 6 + 6.', '[]'::jsonb, '12', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W10-Q04', 4, 'short_answer', 'Solve 8 + 8.', '[]'::jsonb, '16', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W10-Q05', 5, 'short_answer', 'Solve 8 + 5.', '[]'::jsonb, '13', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W10-Q06', 6, 'short_answer', 'Solve 9 + 7.', '[]'::jsonb, '16', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W10-Q07', 7, 'multiple_choice', 'Which is a good strategy for 7 + 7?', '[{"id": "a", "label": "doubles"}, {"id": "b", "label": "subtract 7"}, {"id": "c", "label": "count backward"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W10-Q08', 8, 'multiple_choice', 'To make 10 in 8 + 6, how many should be moved from the 6 to the 8 first?', '[{"id": "a", "label": "1"}, {"id": "b", "label": "2"}, {"id": "c", "label": "4"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W10-Q09', 9, 'short_answer', 'Solve 12 + 4.', '[]'::jsonb, '16', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W10-Q10', 10, 'short_answer', 'Solve 7 + 8.', '[]'::jsonb, '15', 1);


    -- Freeze the question bank onto still-open assignments that may have been
    -- generated before this curriculum content was installed.
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


    -- Week 11 online Friday check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 11
      and l.week_number = 11
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W11-Q01', 1, 'short_answer', 'Solve 9 + 8.', '[]'::jsonb, '17', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W11-Q02', 2, 'short_answer', 'Solve 8 + 7.', '[]'::jsonb, '15', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W11-Q03', 3, 'short_answer', 'Solve 13 + 5.', '[]'::jsonb, '18', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W11-Q04', 4, 'short_answer', 'Solve 6 + 9.', '[]'::jsonb, '15', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W11-Q05', 5, 'multiple_choice', 'Which strategy fits 8 + 8 especially well?', '[{"id": "a", "label": "doubles"}, {"id": "b", "label": "count backward"}, {"id": "c", "label": "subtraction"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W11-Q06', 6, 'multiple_choice', 'Which strategy fits 9 + 5 especially well?', '[{"id": "a", "label": "make ten"}, {"id": "b", "label": "subtract 5"}, {"id": "c", "label": "count backward"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W11-Q07', 7, 'multiple_choice', 'Which strategy fits 12 + 3 especially well?', '[{"id": "a", "label": "count on"}, {"id": "b", "label": "count backward"}, {"id": "c", "label": "take away"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W11-Q08', 8, 'short_answer', 'Solve 7 + 6.', '[]'::jsonb, '13', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W11-Q09', 9, 'short_answer', 'Solve 10 + 9.', '[]'::jsonb, '19', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W11-Q10', 10, 'short_answer', 'Solve 5 + 8.', '[]'::jsonb, '13', 1);


    -- Freeze the question bank onto still-open assignments that may have been
    -- generated before this curriculum content was installed.
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


    -- Week 12 online Friday check
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 12
      and l.week_number = 12
      and l.day_number = 5
      and a.active is true
    limit 1;


    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W12-Q01', 1, 'short_answer', 'Solve 13 − 4.', '[]'::jsonb, '9', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W12-Q02', 2, 'short_answer', 'Solve 15 − 7.', '[]'::jsonb, '8', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W12-Q03', 3, 'short_answer', 'Solve 14 − 9.', '[]'::jsonb, '5', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W12-Q04', 4, 'short_answer', 'Solve 16 − 13.', '[]'::jsonb, '3', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W12-Q05', 5, 'short_answer', 'Solve 12 − 5.', '[]'::jsonb, '7', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W12-Q06', 6, 'short_answer', 'Solve 17 − 9.', '[]'::jsonb, '8', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W12-Q07', 7, 'multiple_choice', 'For 13 − 9, which can be efficient?', '[{"id": "a", "label": "count on from 9 to 13"}, {"id": "b", "label": "add 13 and 9"}, {"id": "c", "label": "count forward from 13"}]'::jsonb, 'a', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W12-Q08', 8, 'multiple_choice', 'In 14 − 6, how many do you subtract first to land on 10?', '[{"id": "a", "label": "2"}, {"id": "b", "label": "4"}, {"id": "c", "label": "6"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W12-Q09', 9, 'short_answer', 'Solve 18 − 5.', '[]'::jsonb, '13', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W12-Q10', 10, 'short_answer', 'Solve 10 − 7.', '[]'::jsonb, '3', 1);


    -- Freeze the question bank onto still-open assignments that may have been
    -- generated before this curriculum content was installed.
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
