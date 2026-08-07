# Student Assessment Delivery Update

Migration 009 adds the first real student-taken curriculum assessment.

## Online assessment added

`1-MATH-W01-CHECK` — Week 1 Mathematics Check

It contains 10 automatically scored questions aligned to competency `1-MATH-01`:
Count, read, write, order, and represent numbers through 120.

The assessment intentionally represents the **written/visual** mastery evidence.
The curriculum still requires a separate oral/hands-on demonstration, so one
successful online assessment should produce Proficient evidence rather than
prematurely proving full mastery.

## Permanent record behavior

When an instructor assigns an online-ready assessment, the exact questions,
choice labels, answer key, sequence, and points are copied into a permanent
student-assignment snapshot.

Later curriculum edits therefore cannot rewrite what the student actually saw.

The student cannot directly SELECT the answer-key tables. A security-definer RPC
returns only safe question fields before submission.

## Student workflow

Instructor assigns Week 1 Mathematics Check.
Student portal shows "Assessments to complete".
Student opens the assessment and answers all 10 questions.
Submission is scored in PostgreSQL.
The exact answers are stored item by item.
A GradeRecord is created with `grading_source = automatic`.
Competency evidence is created.
The grade immediately appears in My Grades.

## Instructor workflow

The gradebook shows an Auto-scored label.
"Review student assessment answers" opens the exact frozen assessment and shows:
- each question
- student's answer
- correct answer
- correct/incorrect status
- total grade

An instructor can still correct an automatic score. Existing append-only grade
revision behavior is preserved and a correction reason is required.

## Repeating an assessment

A graded/completed curriculum assessment can now be assigned again as a separate
permanent instance. An open duplicate is still blocked.

This lets the same competency collect a second independent demonstration without
overwriting the first one.

## Install

1. Copy the update into the existing project.
2. `npm run check:starter`
3. `npm run typecheck`
4. `npm run lint`
5. `npx supabase db push --dry-run`
6. Confirm only `20260807230000_student_assessment_delivery.sql` is pending.
7. `npx supabase db push`
8. Restart `npm run dev`
