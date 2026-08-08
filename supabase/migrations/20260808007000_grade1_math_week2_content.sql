-- Homeschool Tracker
-- Migration 017: Grade 1 Math Week 2 production curriculum + online check
--
-- Week 2 aligns to 1-MATH-02:
-- Count forward and backward from different starting numbers.
--
-- This migration refuses to overwrite previously published/delivered Week 2
-- lesson content or an existing Week 2 question bank.

begin;

do $seed$
declare
  v_course record;
  v_lesson_id uuid;
  v_version_id uuid;
  v_template_id uuid;
begin
  for v_course in
    select cv.organization_id, cv.id as course_version_id
    from public.course_versions cv
    join public.curriculum_releases cr on cr.id = cv.curriculum_release_id
    where cv.course_code = '1-MATH'
      and cr.version = '2026.1'
  loop
    if exists (
      select 1
      from public.lesson_content_versions lcv
      join public.lessons l on l.id = lcv.lesson_id
      where l.course_version_id = v_course.course_version_id
        and l.week_number = 2
        and lcv.status in ('published', 'superseded')
    ) then
      raise exception 'Week 2 Grade 1 Math already contains published lesson content. Migration 017 will not overwrite curriculum history.';
    end if;

    if exists (
      select 1
      from public.student_lesson_deliveries sld
      join public.lessons l on l.id = sld.lesson_id
      where l.course_version_id = v_course.course_version_id
        and l.week_number = 2
    ) then
      raise exception 'A Week 2 Grade 1 Math lesson has already been frozen for a student. Migration 017 will not rewrite delivered curriculum.';
    end if;

    -- Remove only unpublished temporary drafts from authoring tests.
    delete from public.lesson_content_versions lcv
    using public.lessons l
    where lcv.lesson_id = l.id
      and l.course_version_id = v_course.course_version_id
      and l.week_number = 2
      and lcv.status = 'draft';


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W02-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W02-D1 was not found.';
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
      'The student will count forward by ones from different starting numbers within 0–60, including across decade boundaries, without restarting at 0 or 1.', 'I can start at a number and keep counting forward.', '["pencil", "paper", "optional number chart 0–60", "optional number cards"]'::jsonb, '[{"term": "start number", "definition": "the number where you begin counting"}, {"term": "forward", "definition": "counting toward larger numbers"}, {"term": "next", "definition": "the number that comes immediately after another number"}, {"term": "sequence", "definition": "numbers arranged in order"}]'::jsonb,
      'Review by asking the student to count from 1 to 20. Then interrupt and say, “What if I ask you to start at 13 instead of 1?” Have the student count 13, 14, 15, 16.

Explain that strong counters do not need to begin at 1 every time. Today the student will practice jumping into the number sequence at many different starting points.', 'Write 27. Say, “27 is my start number.” Point to it and count forward: 27, 28, 29, 30, 31. Emphasize that the start number is spoken first, then each next number increases by one.

Model crossing a decade: start at 38 and count 38, 39, 40, 41, 42. Repeat with 49, 50, 51. Point out that a number ending in 9 is followed by the next group of ten.

Model a “count forward three times” direction. Start at 24. One count lands on 25, two on 26, three on 27. The landing number is 27.', 'Do not let the student restart at 1 to find an answer. If stuck, provide a nearby number chart and have the student locate the stated start number first.

Watch the transitions 29→30, 39→40, 49→50, and 59→60.',
      'You can start counting at any number.

If the start number is 27, count:
27, 28, 29, 30, 31 ...

You do not need to go back to 1.

Counting forward means the numbers get larger by 1 each time.

After a number ending in 9, a new group of ten begins:
29, 30
39, 40
49, 50
59, 60

If a direction says “Start at 24 and count forward three times,” move three steps:
24 → 25 → 26 → 27

You land on 27.', 'Count aloud together. Always begin with the number named in the problem instead of restarting at 1.', 'The student should solve these starting from the stated number without teacher counting.', 'Start-Number Cards: Write 12, 25, 38, 47, and 56 on separate slips. The student chooses a card and counts forward six numbers beginning with that card. Repeat until every card has been used.',
      'Counting Forward From Any Number', 'Begin at the number shown. Count forward by ones and fill in the missing numbers.', 'Complete the independent practice and worksheet. The student should answer at least 7 of 8 worksheet items correctly after corrections and demonstrate at least two forward counts without restarting at 1.',
      'Allow a number chart, but require the student to locate the start number rather than beginning at 1. Cover unrelated portions of the chart if visual clutter is distracting.', 'Give a start number and a landing number, such as 43 and 49. Ask how many forward counts are needed to get there.', null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Start at 16 and count forward four numbers. What numbers do you say after 16?', 'Move one number at a time.', '17, 18, 19, 20', 'The next four numbers after 16 are 17, 18, 19, and 20.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Start at 28. What number comes next?', 'Say 28, __.', '29', '29 comes immediately after 28.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Continue: 38, 39, __, __.', 'Notice the new group of ten after 39.', '40, 41', '40 follows 39, then 41.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Continue: 22, 23, 24, __, __.', null, '25, 26', 'Counting forward gives 25, then 26.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Start at 49 and count forward three times. Where do you land?', null, '52', '49→50→51→52.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'What number comes right after 57?', null, '58', '58 follows 57.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Continue: 58, 59, __.', null, '60', '60 follows 59.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Continue: 14, 15, __, __.', null, '16, 17', '16 and 17 come next.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Continue: 27, 28, 29, __.', null, '30', '30 follows 29.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'What number comes right after 34?', null, '35', '35 follows 34.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Start at 41 and count forward two times. Where do you land?', null, '43', '41→42→43.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Continue: 48, 49, __, __.', null, '50, 51', '50 and 51 follow 49.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Start at 53 and count forward four times. Where do you land?', null, '57', '53→54→55→56→57.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Continue: 57, 58, 59, __.', null, '60', '60 follows 59.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'What are the next three numbers after 36?', null, '37, 38, 39', '37, 38, and 39 follow 36.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W02-D2';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W02-D2 was not found.';
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
      'The student will count backward by ones from different starting numbers within 0–60, including across decade boundaries, without restarting at 0 or counting forward from 1.', 'I can start at a number and count backward.', '["pencil", "paper", "optional number chart 0–60", "optional number cards"]'::jsonb, '[{"term": "backward", "definition": "counting toward smaller numbers"}, {"term": "previous", "definition": "the number that comes immediately before another number"}, {"term": "before", "definition": "earlier in the counting sequence"}]'::jsonb,
      'Ask the student to count forward from 15 to 20. Then say, “Now let’s turn around,” and count 20, 19, 18, 17, 16, 15.

Explain that backward counting is the same number path traveled in the opposite direction.', 'Start at 32 and count backward: 32, 31, 30, 29, 28. Emphasize that each step is one less.

Model crossing a decade backward: 41, 40, 39, 38. Then 30, 29, 28. Point out that moving backward from a number ending in 0 takes you to a number ending in 9.

Model “Start at 46 and count backward three times”: 46→45→44→43. The landing number is 43.', 'Backward counting is often harder than forward counting. Give think time before prompting.

If the student reverses direction, restate “backward means one less.” Keep attention on 40→39, 30→29, and 20→19 transitions.',
      'Counting backward means moving toward smaller numbers.

Start at 32:
32, 31, 30, 29, 28 ...

Each number is one less than the number before it.

When you move backward across a group of ten:
41, 40, 39
31, 30, 29
21, 20, 19

If you start at 46 and count backward three times:
46 → 45 → 44 → 43

You land on 43.', 'Count backward aloud together first, then let the student fill in the written answer.', 'The student should count backward from the stated starting number without rebuilding the sequence from 1.', 'Backward Countdown: Choose five start numbers between 20 and 60. For each number, the student counts backward five steps. Include at least two start numbers ending in 0, such as 30 or 50.',
      'Counting Backward From Any Number', 'Begin at the stated number and count backward by ones.', 'Complete all items. The student should correctly solve at least 7 of 8 worksheet items after corrections and orally count backward across at least one decade boundary.',
      'Use a number chart and have the student move a finger one square backward at a time. Practice shorter three-number sequences before longer sequences.', 'Ask the student to start at 60 and count backward until reaching a teacher-selected target such as 47, then state how many counts were made.', null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Count backward: 25, 24, __, __.', 'Each number is one less.', '23, 22', '23 comes before 24, then 22.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'What number comes right before 40?', 'Count backward from 40 by one.', '39', '39 is immediately before 40.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Start at 36 and count backward three times. Where do you land?', '36→35 is one step.', '33', '36→35→34→33.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Continue backward: 52, 51, __, __.', null, '50, 49', '50 and 49 come next when counting backward.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'What number comes right before 30?', null, '29', '29 is one less than 30.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Start at 48 and count backward four times. Where do you land?', null, '44', '48→47→46→45→44.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Continue backward: 21, 20, __.', null, '19', '19 comes before 20.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Continue backward: 18, 17, __, __.', null, '16, 15', '16 and 15 follow when counting backward.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'What number comes right before 50?', null, '49', '49 is immediately before 50.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Continue backward: 43, 42, 41, __.', null, '40', '40 comes before 41.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Start at 35 and count backward two times. Where do you land?', null, '33', '35→34→33.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Continue backward: 31, 30, __, __.', null, '29, 28', '29 and 28 come next backward.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Start at 56 and count backward five times. Where do you land?', null, '51', '56→55→54→53→52→51.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'What are the three numbers immediately before 24, counting backward?', null, '23, 22, 21', 'Those are the next three numbers when counting backward from 24.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Continue backward: 12, 11, 10, __.', null, '9', '9 comes immediately before 10.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W02-D3';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W02-D3 was not found.';
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
      'The student will independently switch between forward and backward counting from different starting numbers through 100 and identify missing numbers in both directions.', 'I can tell which way to count and continue the number pattern.', '["pencil", "paper", "optional 0–100 number chart"]'::jsonb, '[{"term": "direction", "definition": "the way the numbers are moving"}, {"term": "increasing", "definition": "getting larger"}, {"term": "decreasing", "definition": "getting smaller"}]'::jsonb,
      'Write two sequences: 66, 67, 68 and 66, 65, 64. Ask what is different. Have the student label one “forward” and the other “backward.”

Explain that today the student must first decide the direction and then continue the sequence.', 'Model 77, 78, 79, __. The numbers increase, so count forward to 80.

Model 83, 82, 81, __. The numbers decrease, so count backward to 80.

Then model crossing 100: 98, 99, 100 and backward 100, 99, 98. Explain that 100 behaves like every other number in the sequence: it has a number before it and numbers after it.', 'Do not identify the direction for the student during independent work. Ask, “Are the numbers getting larger or smaller?”

This lesson intentionally mixes directions because the competency requires responding to the stated starting point and direction rather than relying on one memorized routine.',
      'Before you continue a number sequence, decide which direction it is going.

Forward:
76, 77, 78, 79

The numbers get larger by 1.

Backward:
76, 75, 74, 73

The numbers get smaller by 1.

The sequence can cross 100:
98, 99, 100

And it can go backward from 100:
100, 99, 98

Start where the problem tells you to start. You do not need to begin at 1.', 'For each problem, first say “forward” or “backward,” then solve.', 'Work independently. Decide the direction before writing the missing number.', 'Direction Sort: Make ten short number sequences on slips—five forward and five backward. The student sorts them into two groups, then completes each sequence.',
      'Forward or Backward? Numbers to 100', 'Decide whether each sequence is going forward or backward, then complete it.', 'Complete all independent and worksheet problems with at least 7 of 8 worksheet items correct after corrections. The student should correctly identify direction before solving at least three mixed examples.',
      'Let the student draw an arrow pointing right for forward and left for backward before solving. Use a number chart for checking after an answer is attempted.', 'Give the student the middle number of a five-number sequence and ask them to write the full sequence forward and then backward.', null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Continue: 67, 68, 69, __.', 'Are the numbers getting larger or smaller?', '70', 'The sequence is moving forward.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Continue: 74, 73, 72, __.', 'The numbers are decreasing.', '71', 'The sequence is moving backward.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Continue: 98, 99, __.', 'Count forward across 99.', '100', '100 comes after 99.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Continue: 86, 87, 88, __.', null, '89', 'The pattern counts forward.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Continue: 93, 92, 91, __.', null, '90', 'The pattern counts backward.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Start at 76 and count forward five times. Where do you land?', null, '81', '76→77→78→79→80→81.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Start at 84 and count backward four times. Where do you land?', null, '80', '84→83→82→81→80.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Continue: 63, 64, 65, __.', null, '66', 'The sequence counts forward.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Continue: 63, 62, 61, __.', null, '60', 'The sequence counts backward.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'What number comes right after 89?', null, '90', '90 follows 89.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'What number comes right before 90?', null, '89', '89 comes before 90.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Continue: 97, 98, 99, __.', null, '100', '100 follows 99.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Continue backward: 100, 99, __, __.', null, '98, 97', '98 and 97 come next backward.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Start at 72 and count forward four times. Where do you land?', null, '76', '72→73→74→75→76.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Start at 95 and count backward three times. Where do you land?', null, '92', '95→94→93→92.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W02-D4';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W02-D4 was not found.';
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
      'The student will apply forward and backward counting from varied starting points through 120, including transitions across 99/100, 109/110, and 119/120.', 'I can count forward and backward anywhere from 0 to 120.', '["pencil", "paper", "optional 100–120 number strip", "optional full 0–120 number chart"]'::jsonb, '[{"term": "boundary", "definition": "a place where one group of numbers changes into the next group"}, {"term": "landing number", "definition": "the number reached after the stated number of counting steps"}]'::jsonb,
      'Review the forward sequence 97, 98, 99, 100, 101 and the backward sequence 103, 102, 101, 100, 99.

Explain that today the starting number may be anywhere through 120. The same one-more and one-less rules still work.', 'Model start 108, count forward four times: 108→109→110→111→112.

Model start 112, count backward five times: 112→111→110→109→108→107.

Model start 120, count backward: 120, 119, 118, 117. Ask the student what number would come before 117.', 'Listen for hesitation around 99/100 and 109/110. Those transitions are important evidence that the student is using the number sequence rather than memorizing only familiar decades.

If support is needed, use a number strip temporarily, then remove it for a second attempt.',
      'The number sequence keeps working all the way to 120.

Forward:
98, 99, 100, 101
108, 109, 110, 111
118, 119, 120

Backward:
120, 119, 118
111, 110, 109
101, 100, 99

The rule is always the same:
forward = one more
backward = one less

Start exactly where the problem tells you to start.', 'Practice the tricky boundaries together, especially around 100, 110, and 120.', 'The student should solve mixed forward/backward problems through 120 independently.', 'Human Number Line: Place paper labels 96–105 in a row, then 106–115. Call out a start number and direction. The student points or steps through the requested counts. If floor space is limited, do the same activity on a table.',
      'Counting Anywhere to 120', 'Count forward or backward from the stated starting number. Pay attention when the sequence crosses 100, 110, or 120.', 'Complete all items with at least 7 of 8 worksheet items correct after corrections. The student should orally demonstrate one forward and one backward count across a hundred/ten boundary without restarting.',
      'Use a 100–120 number strip for initial practice, then cover it and retry one problem from memory. Break long counts into groups of three steps.', 'Ask the student to create two counting challenges that cross 100 or 110—one forward and one backward—and solve them.', null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Continue forward: 98, 99, __, __.', 'Keep counting after 99.', '100, 101', '100 follows 99, then 101.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Continue backward: 111, 110, __, __.', 'Move one less each time.', '109, 108', '109 comes before 110, then 108.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Start at 118 and count forward two times. Where do you land?', '118→119 is one step.', '120', '118→119→120.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Continue: 107, 108, 109, __.', null, '110', '110 follows 109.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Continue backward: 102, 101, __, __.', null, '100, 99', '100 comes before 101, then 99.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Start at 113 and count forward five times. Where do you land?', null, '118', '113→114→115→116→117→118.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Start at 116 and count backward six times. Where do you land?', null, '110', '116→115→114→113→112→111→110.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Continue: 99, 100, 101, __.', null, '102', '102 follows 101.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Continue backward: 101, 100, 99, __.', null, '98', '98 comes before 99.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Continue: 108, 109, __, 111.', null, '110', '110 is between 109 and 111.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Continue backward: 112, 111, 110, __.', null, '109', '109 comes before 110.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Start at 115 and count forward four times. Where do you land?', null, '119', '115→116→117→118→119.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Start at 120 and count backward five times. Where do you land?', null, '115', '120→119→118→117→116→115.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'What are the next three numbers after 109?', null, '110, 111, 112', 'Those three numbers follow 109.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'What are the next three numbers when counting backward from 103?', null, '102, 101, 100', 'Those numbers come immediately before 103.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W02-D5';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W02-D5 was not found.';
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
      'The student will review and independently demonstrate forward and backward counting by ones from varied starting numbers through 120 before completing the Week 2 online competency check.', 'I can start anywhere and count forward or backward by ones.', '["pencil", "scratch paper", "no number chart during the final check unless normally provided as an accommodation"]'::jsonb, '[{"term": "forward", "definition": "counting toward larger numbers by one"}, {"term": "backward", "definition": "counting toward smaller numbers by one"}, {"term": "starting point", "definition": "the number where counting begins"}]'::jsonb,
      'Ask the student to explain, in their own words, the difference between counting forward and counting backward. Then ask why they do not need to start at 1.

Tell the student that the readiness problems are a short warm-up. The online Week 2 Check should be completed independently afterward.', 'Use only two neutral examples that are not on the assessment: start at 57 and count forward three times; start at 73 and count backward two times.

Remind the student to count the requested number of steps carefully. The start number is the starting point, not the first step.', 'Week 2 assessment evidence should show that the student can enter the sequence from different starting points and move in either direction, including across decade and hundred boundaries.

Do not coach answers during the online check. If the threshold is not met, review the specific error pattern and reassess later.',
      'This week you learned to start counting anywhere.

Remember:

• Forward means one more each step.
• Backward means one less each step.
• Begin with the number the problem gives you.
• Do not restart at 1.
• Watch carefully when crossing 99 and 100, or 109 and 110.
• If a problem says “count four times,” take exactly four steps.

Use scratch paper if it helps you keep track of your steps.', 'Use these three questions as a quick spoken warm-up.', 'Complete these readiness problems without help, then take the Week 2 online check.', 'Explain Your Route: Choose one readiness problem and have the student explain every counting step aloud. The purpose is to verify that the student starts at the given number and moves in the correct direction.',
      'Week 2 Readiness Review', 'Complete this short mixed review before the online Week 2 Check.', 'Complete the readiness review and the assigned Week 2 online assessment independently. Use the configured 85% competency threshold and repeated qualifying evidence rule rather than requiring a perfect score.',
      'Use the student''s normal testing accommodations. Directions may be read aloud, but do not supply number-sequence answers or indicate whether an answer is correct during the assessment.', 'Ask the student to create one forward and one backward counting problem with a starting number above 100, then solve both.', null, null, null
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 1,
      'Start at 57 and count forward three times. Where do you land?', '57→58 is one step.', '60', '57→58→59→60.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 2,
      'Start at 73 and count backward two times. Where do you land?', 'Move one less each step.', '71', '73→72→71.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'guided_practice', 3,
      'Continue backward: 101, 100, __.', 'Think one less than 100.', '99', '99 comes before 100.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 1,
      'Start at 68 and count forward four times. Where do you land?', null, '72', '68→69→70→71→72.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 2,
      'Start at 92 and count backward three times. Where do you land?', null, '89', '92→91→90→89.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 3,
      'Continue: 108, 109, __, 111.', null, '110', '110 lies between 109 and 111.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'independent_practice', 4,
      'Continue backward: 120, 119, __, 117.', null, '118', '118 lies between 119 and 117 when counting backward.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 1,
      'Continue forward: 44, 45, 46, __.', null, '47', '47 follows 46.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 2,
      'Continue backward: 54, 53, 52, __.', null, '51', '51 comes before 52.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 3,
      'Start at 79 and count forward three times. Where do you land?', null, '82', '79→80→81→82.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 4,
      'Start at 64 and count backward four times. Where do you land?', null, '60', '64→63→62→61→60.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 5,
      'Continue: 98, 99, __, 101.', null, '100', '100 is between 99 and 101.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 6,
      'Continue backward: 111, 110, __, 108.', null, '109', '109 is between 110 and 108 backward.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 7,
      'Start at 116 and count forward four times. Where do you land?', null, '120', '116→117→118→119→120.', 1
    );


    insert into public.lesson_content_items (
      organization_id, lesson_content_version_id, section, sequence,
      prompt, student_support, correct_answer, answer_explanation, points
    )
    values (
      v_course.organization_id, v_version_id, 'worksheet', 8,
      'Start at 104 and count backward five times. Where do you land?', null, '99', '104→103→102→101→100→99.', 1
    );


    update public.lesson_content_versions
    set status = 'published', published_at = now(), updated_at = now()
    where id = v_version_id;


    -- Locate the existing Week 2 Friday assessment template by its durable
    -- course sequence/lesson relationship rather than depending on a guessed code.
    select a.id
    into v_template_id
    from public.assignment_templates a
    join public.lessons l on l.id = a.lesson_id
    where a.course_version_id = v_course.course_version_id
      and a.sequence = 2
      and l.week_number = 2
      and l.day_number = 5
      and a.active is true
    limit 1;

    if v_template_id is null then
      raise exception 'Expected Week 2 Grade 1 Math assessment template was not found.';
    end if;

    if exists (
      select 1
      from public.assessment_template_items ati
      where ati.assignment_template_id = v_template_id
    ) then
      raise exception 'Week 2 Grade 1 Math already has an online question bank. Migration 017 will not overwrite assessment history.';
    end if;

    insert into public.assessment_template_items (
      organization_id, assignment_template_id, code, sequence,
      question_type, prompt, options, correct_answer, points
    )
    values
      (v_course.organization_id, v_template_id, '1-MATH-W02-Q01', 1, 'short_answer',
       'Continue counting forward: 46, 47, 48, __', '[]'::jsonb, '49', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W02-Q02', 2, 'short_answer',
       'Continue counting backward: 53, 52, __', '[]'::jsonb, '51', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W02-Q03', 3, 'multiple_choice',
       'Start at 78 and count forward three times. Where do you land?',
       '[{"id":"a","label":"80"},{"id":"b","label":"81"},{"id":"c","label":"82"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W02-Q04', 4, 'short_answer',
       'Continue counting backward: 102, 101, __', '[]'::jsonb, '100', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W02-Q05', 5, 'multiple_choice',
       'Start at 67 and count forward four times. Where do you land?',
       '[{"id":"a","label":"70"},{"id":"b","label":"71"},{"id":"c","label":"72"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W02-Q06', 6, 'short_answer',
       'Start at 115 and count backward three times. Where do you land?',
       '[]'::jsonb, '112', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W02-Q07', 7, 'short_answer',
       'Fill in the missing number: 98, 99, 100, __, 102', '[]'::jsonb, '101', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W02-Q08', 8, 'short_answer',
       'Fill in the missing number while counting backward: 120, 119, __, 117',
       '[]'::jsonb, '118', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W02-Q09', 9, 'multiple_choice',
       'Start at 37 and count forward four times. Where do you land?',
       '[{"id":"a","label":"40"},{"id":"b","label":"41"},{"id":"c","label":"42"}]'::jsonb, 'b', 1),
      (v_course.organization_id, v_template_id, '1-MATH-W02-Q10', 10, 'short_answer',
       'Start at 84 and count backward five times. Where do you land?',
       '[]'::jsonb, '79', 1);

    -- If a Week 2 assessment was assigned before the online items existed,
    -- freeze the new question bank onto still-open assignments.
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
