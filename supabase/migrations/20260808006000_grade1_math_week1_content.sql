-- Homeschool Tracker
-- Migration 016: Grade 1 Math Week 1 production curriculum
--
-- Seeds published revision 1 for the five Week 1 lessons in Grade 1 Math 2026.1.
-- If any Week 1 lesson already has published content or a frozen student delivery,
-- the migration stops rather than overwriting instructional history.

begin;

do $seed$
declare
  v_course record;
  v_lesson_id uuid;
  v_version_id uuid;
begin
  for v_course in
    select
      cv.organization_id,
      cv.id as course_version_id
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
        and l.week_number = 1
        and lcv.status in ('published', 'superseded')
    ) then
      raise exception
        'Week 1 Grade 1 Math already contains published lesson content. Migration 016 will not overwrite curriculum history.';
    end if;

    if exists (
      select 1
      from public.student_lesson_deliveries sld
      join public.lessons l on l.id = sld.lesson_id
      where l.course_version_id = v_course.course_version_id
        and l.week_number = 1
    ) then
      raise exception
        'A Week 1 Grade 1 Math lesson has already been frozen for a student. Migration 016 will not rewrite delivered curriculum.';
    end if;

    -- Remove any temporary draft content created while testing the authoring UI.
    delete from public.lesson_content_versions lcv
    using public.lessons l
    where lcv.lesson_id = l.id
      and l.course_version_id = v_course.course_version_id
      and l.week_number = 1
      and lcv.status = 'draft';


    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W01-D1';

    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W01-D1 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id,
      lesson_id,
      revision_number,
      status,
      objective,
      student_goal,
      materials,
      vocabulary,
      teacher_introduction,
      teacher_modeling,
      teacher_notes,
      student_learn,
      guided_practice,
      independent_practice,
      activity,
      worksheet_title,
      worksheet_instructions,
      completion_criteria,
      accommodations,
      enrichment,
      created_by,
      published_by,
      published_at
    )
    values (
      v_course.organization_id,
      v_lesson_id,
      1,
      'draft',
      'The student will count, read, write, and represent whole numbers from 0 through 20 by connecting spoken number names, written numerals, and quantities.',
      'I can count, read, write, and show numbers from 0 to 20.',
      '["20 small counters or household objects", "pencil", "paper", "optional number cards 0–20"]'::jsonb,
      '[{"term": "number", "definition": "an idea that tells how many or what position"}, {"term": "numeral", "definition": "a symbol we write to show a number"}, {"term": "zero", "definition": "a number that means none"}, {"term": "count", "definition": "to say number names in order while finding how many"}]'::jsonb,
      'Warm up by placing 6 small objects where the student can see them. Ask, “How can we find out how many there are?” Have the student touch or move each object once while counting aloud. Repeat with 0 objects and discuss why the answer is zero.

Tell the student that this week is about becoming very comfortable reading, writing, finding, and showing numbers all the way to 120. Today begins with numbers 0–20 so the student can use a strong pattern before the numbers get larger.',
      'Model one-to-one counting: each object gets exactly one number name. Emphasize that the last number said tells how many objects are in the group.

Write several numerals such as 4, 10, 13, and 20. Say each number name, then build that amount with counters. For teen numbers, briefly show 10 objects grouped together plus the extra ones: 13 is one group of 10 and 3 more. This is only an introduction to representing numbers; formal place-value instruction comes later.

Model writing a numeral from a spoken number. Say “seventeen,” think through the number sequence, and write 17. Then reverse the process: point to 14 and read “fourteen.”',
      'Watch for skipped objects, double-counted objects, reversed numerals, and confusion between 12/20 or 13/30. Correct counting errors by having the student physically move each object into a counted group.

Do not turn this lesson into formal place-value instruction. The goal is connecting number names, numerals, and quantities.',
      'Numbers tell us how many.

When you count objects, touch or move each object one time. Say one number for each object. The last number you say tells how many objects there are.

The numeral 7 means seven objects.
The numeral 0 means there are no objects.
The numeral 14 means fourteen.
The numeral 20 means twenty.

Numbers from 11 to 19 come after 10. You can think of them as a group of ten with some more. For example, 13 is ten and 3 more.

You can show the same number in different ways:
• say its name
• write its numeral
• count that many objects
• draw that many marks

All of those can represent the same number.',
      'Work these together. Have the student explain how they know each answer before writing it.',
      'Now let the student work without help. If an answer is incorrect, ask the student to recount or reread the number before giving the answer.',
      'Number Hunt: Choose five numbers from 0–20. For each number, have the student find or make a group with that many safe household objects, then write the numeral on paper. Include 0 as one of the choices so the student has to represent “none.”',
      'Numbers 0–20 Practice',
      'Read each problem carefully. Count, read, or write the number. Show your work when it helps.',
      'Complete the independent practice and worksheet. The student should correctly connect numerals and quantities for at least 7 of the 8 worksheet items after corrections and should be able to explain that zero means none.',
      'Use larger objects and fewer choices at one time. Let the student trace numerals before writing independently. If counting is difficult, place objects in a straight line and move each one into a second row as it is counted.',
      'Ask the student to choose a number from 11–20 and show it in three different ways: numeral, objects/drawing, and ten plus extra ones.',
      null,
      null,
      now()
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      1,
      'Count aloud from 0 to 10. What number comes after 9?',
      'Say the numbers slowly in order.',
      '10',
      'After 9 comes 10.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      2,
      'Show 8 using counters or eight drawn marks.',
      'Touch each object or mark once as you count.',
      '8 objects or marks',
      'A correct representation has exactly 8 counted objects or marks.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      3,
      'Which numeral means fifteen: 15 or 51?',
      'Say “fifteen” and think about the teen numbers.',
      '15',
      'Fifteen is written 15.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      1,
      'Write the numeral for twelve.',
      'Think of the number that comes after 11.',
      '12',
      'Twelve is written 12.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      2,
      'What number comes between 16 and 18?',
      'Count: 16, __, 18.',
      '17',
      '17 comes after 16 and before 18.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      3,
      'If there are no counters on the table, what number tells how many there are?',
      'Think about the number that means none.',
      '0',
      'Zero means none.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      4,
      'Write the number that comes right after 19.',
      'Continue the counting sequence.',
      '20',
      '20 comes after 19.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      1,
      'Write the numeral for seven.',
      null,
      '7',
      'Seven is written 7.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      2,
      'Write the numeral for fourteen.',
      null,
      '14',
      'Fourteen is written 14.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      3,
      'What number comes right before 10?',
      null,
      '9',
      '9 is immediately before 10.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      4,
      'What number comes right after 17?',
      null,
      '18',
      '18 is immediately after 17.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      5,
      'Fill in the missing number: 11, 12, __, 14.',
      null,
      '13',
      '13 comes between 12 and 14.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      6,
      'Which is greater: 6 or 16?',
      null,
      '16',
      '16 is farther along in the counting sequence.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      7,
      'Write a numeral that means no objects.',
      null,
      '0',
      '0 represents none.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      8,
      'Draw or make a group that represents 20.',
      null,
      '20 objects or marks',
      'A correct model contains exactly 20 counted objects or marks.',
      1
    );

    update public.lesson_content_versions
    set
      status = 'published',
      published_at = now(),
      updated_at = now()
    where id = v_version_id;



    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W01-D2';


    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W01-D2 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id,
      lesson_id,
      revision_number,
      status,
      objective,
      student_goal,
      materials,
      vocabulary,
      teacher_introduction,
      teacher_modeling,
      teacher_notes,
      student_learn,
      guided_practice,
      independent_practice,
      activity,
      worksheet_title,
      worksheet_instructions,
      completion_criteria,
      accommodations,
      enrichment,
      created_by,
      published_by,
      published_at
    )
    values (
      v_course.organization_id,
      v_lesson_id,
      1,
      'draft',
      'The student will read, write, count, and represent whole numbers from 21 through 60 using number-sequence patterns and groups of ten with leftover ones.',
      'I can read, write, count, and show numbers to 60.',
      '["60 counters or small objects, if available", "6 cups, bags, or rubber bands for groups of ten", "pencil", "paper", "optional number chart"]'::jsonb,
      '[{"term": "ten", "definition": "a group of 10 ones"}, {"term": "ones", "definition": "single objects that are not grouped into a ten"}, {"term": "before", "definition": "the number immediately earlier in the counting sequence"}, {"term": "after", "definition": "the number immediately later in the counting sequence"}]'::jsonb,
      'Review yesterday by asking the student to read 8, 14, and 20 and to count out one of those numbers. Then write 21, 30, 42, and 56.

Ask what patterns the student notices. Explain that the number sequence continues in predictable groups. Today the student will use those patterns to read and represent numbers through 60.',
      'Build 24 with two groups of ten objects and four single objects. Say, “Two tens make 20, and four more make 24.” Repeat with 31 and 45.

Model decade transitions carefully: 28, 29, 30; 38, 39, 40; 49, 50. Show that after a number ending in 9, the next number begins a new group of ten.

Write 52. Read it aloud, then represent it as five groups of ten and two single ones. Keep this concrete and representational; detailed tens/ones place-value reasoning will be revisited later in the course.',
      'Students may reverse digits such as 24/42 or say a number name that does not match the numeral. Always have the student point to the tens-group count and then the leftover ones.

If 60 objects are impractical, draw bundles as long sticks where each stick represents a group of ten and dots represent ones.',
      'The counting pattern keeps going after 20.

21 is twenty-one.
29 is twenty-nine.
After 29 comes 30.
After 39 comes 40.
After 49 comes 50.
After 59 comes 60.

One helpful way to show a number is to make groups of ten.

24 can be shown as:
2 groups of ten and 4 more.

42 can be shown as:
4 groups of ten and 2 more.

The digits are in a different order, so 24 and 42 are different numbers.

When you are unsure what comes before or after a number, say a few numbers in the counting sequence aloud.',
      'Build or draw the numbers together. Ask the student to say the number name before answering.',
      'The student should complete these without the teacher giving the number name first.',
      'Make-a-Number: Write the numbers 23, 35, 41, 48, and 60 on separate slips. The student chooses a slip, reads the number, then represents it using groups of ten and single objects or drawings.',
      'Numbers to 60 Practice',
      'Read, write, and represent each number. Use groups of ten if they help.',
      'Complete all independent and worksheet items. The student should read two-digit numbers in the correct digit order and correctly answer at least 7 of the 8 worksheet items after corrections.',
      'Keep a 1–60 number chart visible. Highlight each group of ten with a different alternating shade. Let the student build numbers before writing answers.',
      'Have the student choose three numbers from 21–60 and write the number immediately before and after each one, then represent one number with tens groups and ones.',
      null,
      null,
      now()
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      1,
      'Build or draw 24 as groups of ten and extra ones.',
      'Start by making two groups of 10.',
      '2 tens and 4 ones',
      '20 and 4 more make 24.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      2,
      'What number comes right after 39?',
      'Count 38, 39, __.',
      '40',
      '40 comes immediately after 39.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      3,
      'Read this numeral aloud: 52.',
      'Look at the whole numeral before saying it.',
      'fifty-two',
      '52 is read fifty-two.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      1,
      'Write the numeral for thirty-six.',
      null,
      '36',
      'Thirty-six is written 36.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      2,
      'What number comes right before 50?',
      null,
      '49',
      '49 comes immediately before 50.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      3,
      'Which number is greater: 27 or 37?',
      null,
      '37',
      '37 comes later in the counting sequence than 27.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      4,
      'How many groups of ten and extra ones can show 45?',
      null,
      '4 tens and 5 ones',
      'Four groups of ten make 40; five more make 45.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      1,
      'Write the numeral for twenty-eight.',
      null,
      '28',
      'Twenty-eight is written 28.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      2,
      'Write the numeral for fifty-four.',
      null,
      '54',
      'Fifty-four is written 54.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      3,
      'Fill in the missing number: 32, 33, __, 35.',
      null,
      '34',
      '34 comes between 33 and 35.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      4,
      'What number comes right after 59?',
      null,
      '60',
      '60 follows 59.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      5,
      'What number comes right before 41?',
      null,
      '40',
      '40 comes immediately before 41.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      6,
      'Which is greater: 46 or 42?',
      null,
      '46',
      '46 comes later than 42.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      7,
      'Show 31 as groups of ten and ones.',
      null,
      '3 tens and 1 one',
      '30 and 1 more make 31.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      8,
      'Which numeral means forty-two: 24 or 42?',
      null,
      '42',
      'Forty-two is written 42.',
      1
    );

    update public.lesson_content_versions
    set
      status = 'published',
      published_at = now(),
      updated_at = now()
    where id = v_version_id;



    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W01-D3';


    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W01-D3 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id,
      lesson_id,
      revision_number,
      status,
      objective,
      student_goal,
      materials,
      vocabulary,
      teacher_introduction,
      teacher_modeling,
      teacher_notes,
      student_learn,
      guided_practice,
      independent_practice,
      activity,
      worksheet_title,
      worksheet_instructions,
      completion_criteria,
      accommodations,
      enrichment,
      created_by,
      published_by,
      published_at
    )
    values (
      v_course.organization_id,
      v_lesson_id,
      1,
      'draft',
      'The student will independently read, write, sequence, compare, and represent whole numbers from 0 through 100.',
      'I can find, read, write, and order numbers to 100.',
      '["pencil", "paper", "optional 1–100 chart", "optional counters or drawings for groups of ten"]'::jsonb,
      '[{"term": "between", "definition": "in the middle of two numbers in a sequence"}, {"term": "least", "definition": "the smallest amount or number"}, {"term": "greatest", "definition": "the largest amount or number"}, {"term": "order", "definition": "to arrange numbers by value"}]'::jsonb,
      'Quickly review decade transitions by asking: What comes after 29? 49? 79? 99? Then write 64, 78, 80, 87, and 100.

Tell the student that today they will do more of the work independently. The goal is not just reading numbers, but putting them in order and finding numbers before, after, and between.',
      'Model how to compare 48 and 64 without formal comparison symbols. Count by tens: numbers in the 40s come before numbers in the 60s, so 48 is less and 64 is greater.

Model ordering 84, 48, 64. First identify the number in the 40s, then the 60s, then the 80s: 48, 64, 84.

Show a sequence around 100: 97, 98, 99, 100. Explain that 100 is the number after 99.',
      'Encourage independent reasoning before using a number chart. If the student needs the chart, ask them to locate each number and notice which appears earlier or later.

Avoid introducing < and > symbols unless the student already knows them; the competency can be practiced using words such as least, greatest, before, after, and ordered.',
      'Numbers can be put in order.

Least means the smallest number.
Greatest means the largest number.

To order numbers from least to greatest, start with the smallest number and move toward the largest.

Example:
48, 64, 84

48 is in the 40s.
64 is in the 60s.
84 is in the 80s.

So the order from least to greatest is:
48, 64, 84.

You can also use the counting sequence to find numbers before, after, and between other numbers.

98 comes before 99.
100 comes after 99.
72 is between 71 and 73.',
      'Do the first examples together. Ask the student to explain which number comes earlier or later in the counting sequence.',
      'The student should now solve without hints unless truly stuck.',
      'Number Line Sort: Write 45, 63, 71, 86, and 99 on slips of paper. Mix them up. Have the student place them in a line from least to greatest. Then ask which is greatest, which is least, and which two numbers are closest together.',
      'Numbers to 100 Independent Practice',
      'Work independently. Read each numeral carefully and use the number sequence to help with ordering.',
      'Complete all items. The student should correctly solve at least 7 of 8 worksheet items after corrections and independently explain how they determined the least or greatest number in one problem.',
      'Use a 1–100 chart and let the student point to numbers before writing. Reduce ordering sets to three numbers at first. Read directions aloud without reading the answer choices for the student.',
      'Ask the student to create three different sets of three numbers, then put each set in least-to-greatest order and explain the pattern used.',
      null,
      null,
      now()
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      1,
      'Put these in order from least to greatest: 35, 53, 45.',
      'Find the number in the 30s first.',
      '35, 45, 53',
      '35 is smallest, then 45, then 53.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      2,
      'Which number is greatest: 68, 86, or 80?',
      'Compare the numbers in the 60s and 80s.',
      '86',
      '86 is greater than 80 and 68.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      3,
      'What number is between 74 and 76?',
      'Count 74, __, 76.',
      '75',
      '75 lies between 74 and 76.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      1,
      'What number comes right after 89?',
      null,
      '90',
      '90 comes after 89.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      2,
      'What number comes right before 73?',
      null,
      '72',
      '72 comes before 73.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      3,
      'Put these in order from least to greatest: 84, 64, 48.',
      null,
      '48, 64, 84',
      '48 is least, then 64, then 84.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      4,
      'Which number is least: 91, 19, or 90?',
      null,
      '19',
      '19 is smaller than both numbers in the 90s.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      1,
      'Write the numeral for sixty-seven.',
      null,
      '67',
      'Sixty-seven is written 67.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      2,
      'Write the numeral for ninety-six.',
      null,
      '96',
      'Ninety-six is written 96.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      3,
      'What number comes right after 99?',
      null,
      '100',
      '100 follows 99.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      4,
      'What number comes right before 80?',
      null,
      '79',
      '79 comes before 80.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      5,
      'Fill in the missing number: 88, 89, __, 91.',
      null,
      '90',
      '90 comes between 89 and 91.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      6,
      'Which number is greatest: 78, 87, or 80?',
      null,
      '87',
      '87 is the greatest of the three.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      7,
      'Order from least to greatest: 72, 27, 70.',
      null,
      '27, 70, 72',
      '27 is smallest, then 70, then 72.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      8,
      'Show 65 as groups of ten and ones.',
      null,
      '6 tens and 5 ones',
      '60 and 5 more make 65.',
      1
    );

    update public.lesson_content_versions
    set
      status = 'published',
      published_at = now(),
      updated_at = now()
    where id = v_version_id;



    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W01-D4';


    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W01-D4 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id,
      lesson_id,
      revision_number,
      status,
      objective,
      student_goal,
      materials,
      vocabulary,
      teacher_introduction,
      teacher_modeling,
      teacher_notes,
      student_learn,
      guided_practice,
      independent_practice,
      activity,
      worksheet_title,
      worksheet_instructions,
      completion_criteria,
      accommodations,
      enrichment,
      created_by,
      published_by,
      published_at
    )
    values (
      v_course.organization_id,
      v_lesson_id,
      1,
      'draft',
      'The student will extend number reading, writing, sequencing, ordering, and representation to whole numbers from 101 through 120.',
      'I can read, write, order, and show numbers from 101 to 120.',
      '["pencil", "paper", "optional number line or chart from 100–120", "optional base-ten blocks or drawings"]'::jsonb,
      '[{"term": "hundred", "definition": "a group of 100 ones"}, {"term": "represent", "definition": "to show a number in another form"}, {"term": "sequence", "definition": "numbers arranged in a particular order"}]'::jsonb,
      'Write 98, 99, 100, 101, 102. Have the student read the sequence aloud. Ask what changed after 99 and after 100.

Explain that numbers do not stop at 100. Today the student will extend the same counting ideas through 120.',
      'Model 107 as one hundred and seven more. If using base-ten drawings, use a large square or label “100,” then seven ones.

Model 117 as one hundred, one group of ten, and seven ones. Say and write “one hundred seventeen.”

Model the transition 109, 110, 111 and the sequence 112, 113, 114, 115. Then compare 108, 114, and 120 by locating them on a 100–120 number line or by counting forward.',
      'The most common error is dropping the hundred or confusing 110 with 101. Have the student read each numeral left to right and say the full number name.

This is a representation lesson, not a full three-digit place-value unit. The goal is fluency recognizing and showing the numbers 101–120.',
      'After 100, the number sequence keeps going:

100, 101, 102, 103, 104 ...

109 is followed by 110.
110 is followed by 111.

A number such as 117 can be shown as:
1 hundred
1 group of ten
7 ones

That makes 117.

You can use the same ideas you already know:
• read the numeral
• say the number name
• find what comes before or after
• put numbers in order
• show the number with a model or drawing

The largest number we are using this week is 120.',
      'Work through the 100–120 sequence together. Have the student say the full number name for every answer.',
      'Let the student solve independently, then ask for a quick explanation on one representation problem.',
      'Build a 100–120 Number Trail: Write the numerals 100 through 120 on small slips. Shuffle a few groups of five or six slips and have the student place each group back in order. Finish by placing 109, 110, 111, 119, and 120 correctly.',
      'Numbers 101–120 Application',
      'Use what you know about the counting sequence and number models. Read each three-digit numeral carefully.',
      'Complete all application and worksheet items. The student should answer at least 7 of 8 worksheet items correctly after corrections and correctly read at least three numbers between 101 and 120 aloud.',
      'Keep a 100–120 number strip visible. Cover all but five numbers at a time if the full strip is visually overwhelming. Let the student say answers aloud before writing.',
      'Have the student write five clues for a mystery number from 101–120, such as “I come after 114 and before 116,” then have the instructor identify it.',
      null,
      null,
      now()
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      1,
      'What number comes right after 109?',
      'Count 108, 109, __.',
      '110',
      '110 follows 109.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      2,
      'Read this numeral aloud: 117.',
      'Start with the 1 hundred.',
      'one hundred seventeen',
      '117 is read one hundred seventeen.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      3,
      'Complete the sequence: 112, 113, __, 115.',
      'Count forward one number at a time.',
      '114',
      '114 comes between 113 and 115.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      1,
      'What number comes right before 106?',
      null,
      '105',
      '105 comes before 106.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      2,
      'Write the numeral for one hundred twelve.',
      null,
      '112',
      'One hundred twelve is written 112.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      3,
      'Which is greatest: 108, 118, or 110?',
      null,
      '118',
      '118 comes later in the sequence than 110 and 108.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      4,
      '1 hundred, 1 ten, and 7 ones make what number?',
      null,
      '117',
      '100 + 10 + 7 represents 117.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      1,
      'Write the numeral for one hundred five.',
      null,
      '105',
      'One hundred five is written 105.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      2,
      'What number comes right after 119?',
      null,
      '120',
      '120 follows 119.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      3,
      'What number comes right before 110?',
      null,
      '109',
      '109 comes before 110.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      4,
      'Fill in the missing number: 107, 108, __, 110.',
      null,
      '109',
      '109 comes between 108 and 110.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      5,
      'Fill in the missing number: 116, 117, __, 119.',
      null,
      '118',
      '118 comes between 117 and 119.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      6,
      'Order from least to greatest: 120, 104, 112.',
      null,
      '104, 112, 120',
      '104 is least, then 112, then 120.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      7,
      '1 hundred, 2 tens, and 0 ones make what number?',
      null,
      '120',
      '100 + 20 makes 120.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      8,
      'Which number is between 99 and 101?',
      null,
      '100',
      '100 is between 99 and 101.',
      1
    );

    update public.lesson_content_versions
    set
      status = 'published',
      published_at = now(),
      updated_at = now()
    where id = v_version_id;



    select l.id into v_lesson_id
    from public.lessons l
    where l.course_version_id = v_course.course_version_id
      and l.code = '1-MATH-W01-D5';


    if v_lesson_id is null then
      raise exception 'Expected lesson 1-MATH-W01-D5 was not found.';
    end if;

    insert into public.lesson_content_versions (
      organization_id,
      lesson_id,
      revision_number,
      status,
      objective,
      student_goal,
      materials,
      vocabulary,
      teacher_introduction,
      teacher_modeling,
      teacher_notes,
      student_learn,
      guided_practice,
      independent_practice,
      activity,
      worksheet_title,
      worksheet_instructions,
      completion_criteria,
      accommodations,
      enrichment,
      created_by,
      published_by,
      published_at
    )
    values (
      v_course.organization_id,
      v_lesson_id,
      1,
      'draft',
      'The student will review and independently demonstrate reading, writing, sequencing, ordering, and representing whole numbers from 0 through 120 before completing the Week 1 competency check.',
      'I can show what I know about numbers from 0 to 120.',
      '["pencil", "paper", "optional scratch paper", "no number chart during the final check unless an accommodation requires it"]'::jsonb,
      '[{"term": "review", "definition": "to look back at what you learned"}, {"term": "check", "definition": "a chance to show what you can do independently"}]'::jsonb,
      'Begin with a calm two-minute review of the week. Ask the student to name one thing they learned about numbers below 100 and one thing they learned about numbers above 100.

Explain that the short practice on this page is a warm-up. The online Week 1 Check should be completed independently afterward. Do not coach answers during the assessment. Normal documented accommodations may still be used.',
      'Do not reteach the entire week immediately before the check. Model only one neutral example that is not on the assessment, such as finding the number after 104 or showing 53 as five groups of ten and three ones.

Remind the student to read every numeral carefully, check digit order, and use the counting sequence when finding before/after/between numbers.',
      'The existing Week 1 online assessment contains 10 automatically scored items aligned to 1-MATH-01. A score of at least 85% is a qualifying mastery demonstration under the competency settings.

If the student does not meet threshold, treat the result as information for review and reassessment rather than as a reason to mark the course complete or advance the competency prematurely.',
      'You have practiced numbers from 0 all the way to 120.

Before the Week 1 Check, remember:

• Read every numeral carefully.
• Watch the order of the digits.
• Use the counting sequence for before, after, and between.
• When ordering numbers, find the least number first.
• A number can be represented with groups of ten and extra ones.
• Numbers from 101–120 include one hundred.

Work carefully. It is okay to use scratch paper to think.',
      'Use these as a short warm-up only. Talk through the thinking, but do not use the actual assessment questions.',
      'Complete these readiness items without help. Then move to the assigned Week 1 Check.',
      'Error Check: After the warm-up, ask the student to look back at each answer and choose one to verify a second way—for example, by counting forward, drawing tens and ones, or placing the number in a sequence.',
      'Week 1 Readiness Review',
      'Complete this short review before the online Week 1 Check. These are practice questions, not the official assessment.',
      'Complete the readiness review and then complete the assigned Week 1 online assessment independently. Review any missed skills afterward. Do not require a perfect score; use the configured competency threshold and repeated evidence rules for mastery.',
      'Read directions aloud if reading load interferes with demonstrating math knowledge. Provide scratch paper, larger print, extra time, or reduced visual clutter when those supports are part of the student''s normal instruction. Do not give the correct answer or tell the student which option to choose.',
      'Ask the student to write a three-clue mystery number for any number from 0–120 and solve one created by the instructor.',
      null,
      null,
      now()
    )
    returning id into v_version_id;


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      1,
      'What number comes right after 104?',
      'Say 103, 104, __.',
      '105',
      '105 follows 104.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      2,
      'Show 53 as groups of ten and ones.',
      'Think about 50 and 3 more.',
      '5 tens and 3 ones',
      'Five tens make 50; three more make 53.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'guided_practice',
      3,
      'Which is least: 62, 26, or 60?',
      'Find which number comes earliest in the counting sequence.',
      '26',
      '26 is less than both numbers in the 60s.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      1,
      'Write the numeral for eighty-three.',
      null,
      '83',
      'Eighty-three is written 83.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      2,
      'What number comes between 118 and 120?',
      null,
      '119',
      '119 lies between 118 and 120.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      3,
      'Order from least to greatest: 91, 19, 90.',
      null,
      '19, 90, 91',
      '19 is smallest, then 90, then 91.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'independent_practice',
      4,
      '1 hundred and 8 ones make what number?',
      null,
      '108',
      '100 and 8 more make 108.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      1,
      'Write the numeral for forty-seven.',
      null,
      '47',
      'Forty-seven is written 47.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      2,
      'What number comes right before 60?',
      null,
      '59',
      '59 comes before 60.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      3,
      'Fill in the missing number: 97, 98, __, 100.',
      null,
      '99',
      '99 comes between 98 and 100.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      4,
      'Which is greatest: 67, 76, or 70?',
      null,
      '76',
      '76 is greater than 70 and 67.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      5,
      'Show 38 as groups of ten and ones.',
      null,
      '3 tens and 8 ones',
      '30 and 8 more make 38.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      6,
      'Write the numeral for one hundred eleven.',
      null,
      '111',
      'One hundred eleven is written 111.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      7,
      'What number comes right after 114?',
      null,
      '115',
      '115 follows 114.',
      1
    );


    insert into public.lesson_content_items (
      organization_id,
      lesson_content_version_id,
      section,
      sequence,
      prompt,
      student_support,
      correct_answer,
      answer_explanation,
      points
    )
    values (
      v_course.organization_id,
      v_version_id,
      'worksheet',
      8,
      'Order from least to greatest: 116, 106, 110.',
      null,
      '106, 110, 116',
      '106 is least, then 110, then 116.',
      1
    );

    update public.lesson_content_versions
    set
      status = 'published',
      published_at = now(),
      updated_at = now()
    where id = v_version_id;

  end loop;
end;
$seed$;

commit;
