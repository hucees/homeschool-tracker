# Course Completion + Independent Subject Progression

Migration 012 adds course completion and subject-level progression.

## Completion readiness

The database calculates:
- active lessons and completed lessons
- required competencies and mastered competencies
- weighted current grade and letter grade
- total recorded instructional minutes

Normal completion requires all active lessons complete and all required
competencies mastered.

An instructor can explicitly override incomplete requirements, but a reason is
required and is permanently preserved.

## Completion record

Completing a course creates one immutable completion record that freezes:
- course code/title
- course version and curriculum release
- enrollment start and completion date
- final grade
- lesson totals
- competency totals
- instructional minutes
- whether requirements were met
- whether an override was used

The source enrollment is closed as completed.

## Independent progression

After completion, the instructor may:
- Advance to the next grade-level course in the same subject
- Accelerate to a higher grade-level course
- Continue the same course in a new enrollment
- Repeat the same course
- End the subject enrollment

The new enrollment may use the current or another planned/active academic-year
placement for the student.

The student's official grade placement is never changed by course progression.

## Safe test with the current Grade 1 Math student

Do not use an override merely to test the write path on a real student.

Open:
Student → Courses & progression → Grade 1 Mathematics

Verify the page shows the real calculated counts and `In progress` /
`Requirements incomplete`.

Stop there until the course is genuinely ready for completion.

## Install

1. Commit/push the working student-reporting/UI update first if you have not.
2. Stop the dev server if desired.
3. Copy this update into the project.
4. Run:
   - `npm run check:starter`
   - `npm run typecheck`
   - `npm run lint`
5. `npx supabase db push --dry-run`
6. Confirm only `20260808002000_course_completion_progression.sql` is pending.
7. `npx supabase db push`
8. Restart `npm run dev`
