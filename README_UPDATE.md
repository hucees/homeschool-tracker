# Grade 1 Mathematics — Week 1 Production Curriculum

Migration 016 adds the first complete production curriculum week.

## Alignment

Existing course structure is preserved:

- Week 1: Numbers to 120
- Competency: `1-MATH-01`
- Day 1: Learn: Numbers to 120
- Day 2: Guided Practice: Numbers to 120
- Day 3: Independent Practice: Numbers to 120
- Day 4: Apply: Numbers to 120
- Day 5: Check: Numbers to 120

The existing lesson codes, IDs, competency mappings, and assessment template are
not replaced.

## Five-day instructional progression

Day 1:
- numbers 0–20
- number name ↔ numeral ↔ quantity
- zero
- one-to-one counting

Day 2:
- numbers 21–60
- decade transitions
- introductory groups-of-ten representation

Day 3:
- numbers through 100
- before / after / between
- least / greatest
- ordering

Day 4:
- numbers 101–120
- reading and writing three-digit numbers in the Week 1 range
- 100 + tens + ones representations
- ordering / sequencing through 120

Day 5:
- cumulative review
- readiness practice
- direct link to an assigned online Week 1 Check when one is open

## Every lesson contains

Teacher:
- measurable objective
- materials
- vocabulary
- warm-up
- explicit modeling
- teaching notes
- guided-practice answer key
- independent-practice answer key
- worksheet answer key
- accommodations
- enrichment
- completion criteria

Student:
- student-friendly goal
- materials
- vocabulary
- Learn content
- guided practice
- independent practice
- application/activity
- eight-item worksheet
- completion criteria

## Print support

Instructor:
`Curriculum → Lesson → Teacher guide`
- Print / Save Teacher Guide

Instructor:
`Curriculum → Lesson → Answer key`
- Print / Save Answer Key

Student:
`Lessons → Lesson → Open printable worksheet`
- Print / Save Worksheet

## Safety / history behavior

Migration 016 refuses to run if:
- Week 1 already has published/superseded lesson content, or
- a Week 1 content revision has already been frozen in a student lesson delivery.

This prevents a curriculum migration from rewriting instructional history.

A temporary unpublished Week 1 draft from testing the authoring interface is
removed before the production revision is seeded.

## Install

1. Commit/push the working Curriculum Engine first.
2. Stop dev server if desired.
3. Copy this update into the project.
4. Run:
   - `npm run check:starter`
   - `npm run typecheck`
   - `npm run lint`
5. Run `npx supabase db push --dry-run`.
6. Confirm only `20260808006000_grade1_math_week1_content.sql` is pending.
7. Run `npx supabase db push`.
8. Restart `npm run dev`.

## Test

Instructor:
1. Curriculum → Grade 1 Mathematics → Week 1.
2. All five lessons should show `Published r1`.
3. Open Day 1.
4. Verify the populated authoring fields.
5. Open Teacher Guide.
6. Open Answer Key.

Student:
1. Lessons → Grade 1 Mathematics.
2. Because Day 1 is already completed in the current real record, the next
   unfinished lesson should be Day 2.
3. Open it and verify the full lesson content.
4. Open printable worksheet.
5. Do not mark additional real lessons complete just for testing unless you want
   that completion recorded permanently.

Day 5:
- if an open Week 1 assessment is assigned, the lesson page shows
  `Start Week 1 Check`.
