# Assignments + Grades + Competency Progress

Migration 008 adds the first real gradebook vertical slice.

## What this update adds

- Instructor gradebook on each student record
- Assignment of the existing versioned Grade 1 Math weekly/quarterly assessment templates
- Permanent snapshot of the competencies each assigned assessment measures
- Points, percentage, letter grade, pass/fail, and teacher feedback
- Append-only grade revisions:
  - an old grade is superseded
  - it is never silently overwritten
  - corrections require a reason
- Current competency evidence linked to the exact grade revision
- Corrected grades do not double-count competency evidence
- Competency progress:
  - Not started
  - Needs review
  - Practicing
  - Proficient
  - Mastered
- Student portal "My Grades" section

## Mastery behavior

A single strong assessment creates a Proficient evidence point.

The UI only displays Mastered after the competency has the required number of
qualifying demonstrations defined by the curriculum. Grade 1 Math currently
requires multiple demonstrations for mastery, so one good quiz does not
prematurely mark a competency mastered.

## Install

After copying this update into the existing project:

1. `npm run check:starter`
2. `npm run typecheck`
3. `npm run lint`
4. `npx supabase db push --dry-run`
5. Confirm only `20260807220000_assignments_grades_competencies.sql` is pending.
6. `npx supabase db push`
7. Restart `npm run dev`

Then open:
Instructor Dashboard → Students → student → Open gradebook
