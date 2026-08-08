# Grade 1 Mathematics — Week 2

Week 2 is the second production curriculum package.

## Alignment

Competency:

`1-MATH-02 — Count forward and backward from different starting numbers`

Mastery target:
- start from teacher-selected numbers within 0–120
- count forward and backward by ones
- do not restart at 0 or 1
- 85% threshold
- repeated qualifying demonstrations

## Five-day sequence

Day 1 — Learn
- forward counting from different starting numbers
- decade transitions through 60
- counting a stated number of steps

Day 2 — Guided Practice
- backward counting from different starts
- decade transitions backward
- landing-number problems

Day 3 — Independent Practice
- mixed forward/backward direction
- numbers through 100
- crossing 99/100

Day 4 — Apply
- numbers through 120
- 99/100, 109/110, 119/120 transitions
- mixed forward and backward applications

Day 5 — Check
- readiness review
- online Week 2 check

## Online assessment

Migration 017 adds 10 auto-scored Week 2 questions to the existing Friday
assessment template.

The assessment checks:
- forward sequences
- backward sequences
- starting from non-1 values
- counting a stated number of steps
- crossing 99/100
- counting backward from values above 100
- counting through 120

## History protection

Migration 017 aborts if:
- Week 2 already has published/superseded lesson content
- Week 2 has already been frozen to a student delivery
- the Week 2 assessment already has a question bank

Temporary unpublished Week 2 lesson drafts may be removed so the production
revision can be installed.

## Install

Checkpoint Week 1 first:

```bash
git add .
git commit -m "Add Grade 1 Math Week 1 production curriculum"
git push
```

Copy this update into the project and run:

```bash
npm run check:starter
npm run typecheck
npm run lint
npx supabase db push --dry-run
```

Expected pending migration:

`20260808007000_grade1_math_week2_content.sql`

Then:

```bash
npx supabase db push
npm run dev
```

## Safe test

Instructor:
- Curriculum → Grade 1 Mathematics → Week 2
- all five lessons should show Published r1
- open Day 1, Teacher Guide, and Answer Key

Student:
- do not complete Week 1 Day 2 just to reach Week 2
- Week 2 can be inspected from the instructor side without altering the real
  student record
- when the student naturally reaches Week 2, the normal next-lesson flow will
  deliver the published revision
