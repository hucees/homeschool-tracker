# Grade 1 Mathematics — Production Batch: Weeks 8–12

## Coverage

### Week 8 — Quarter 1 Spiral Review
Reviews:
- 1-MATH-01 Numbers to 120
- 1-MATH-02 Count forward/backward from varied starting points
- 1-MATH-03 Patterns by 2s, 5s, 10s
- 1-MATH-04 Tens and ones
- 1-MATH-05 Compare two-digit numbers

The daily sequence deliberately isolates skill families on Days 1–4 and mixes
them on Day 5 so weak areas can be identified before mastery week.

### Week 9 — Quarter 1 Mastery Check
Cumulative evidence across 1-MATH-01 through 1-MATH-05.

Days 1–4 are more independent than a normal teaching week. Day 5 is the
cumulative online mastery check. The result should be interpreted alongside
the competency evidence already accumulated during Weeks 1–8.

### Week 10 — 1-MATH-06 Addition Within 20 I
- addition as putting together
- counting on
- doubles / near doubles
- make ten
- first online addition check

### Week 11 — 1-MATH-06 Addition Within 20 II
- decompose to make ten
- choose efficient strategies
- mixed addition within 20
- explain a strategy
- second online addition check

### Week 12 — 1-MATH-07 Subtraction Within 20 I
- subtraction as take away
- count back
- count on to find a difference
- decompose/use 10 as a stopping point
- first online subtraction check

## Package totals

- 25 full production lessons
- 375 guided / independent / worksheet items
- 5 online assessments
- 50 auto-scored assessment items

## Safety

Migration 019 uses one transaction and performs a complete preflight before
writing any lesson content. It refuses to overwrite:
- published/superseded lesson revisions
- frozen student deliveries
- existing Week 8–12 question banks

The static starter check also rejects the D01–D05 lesson-code bug encountered
during the first production content install.

## Install

Checkpoint the verified Weeks 3–7 batch first:

```bash
git add .
git commit -m "Add Grade 1 Math Weeks 3 through 7 production curriculum"
git push
```

Then copy this update into the project:

```bash
cp -R ~/Downloads/homeschool-tracker-grade1-math-weeks8-12-update/. .
```

Validate:

```bash
npm run check:starter
npm run typecheck
npm run lint
```

Expected:

```text
Migrations: 19
Batch QA: Weeks 8–12 / 25 lessons / 50 online assessment items
Coverage: Q1 spiral review + Q1 mastery + addition within 20 + subtraction intro
Starter structure and Weeks 8–12 static checks passed.
```

Dry run:

```bash
npx supabase db push --dry-run
```

Expected only:

```text
20260808009000_grade1_math_weeks8_12_content.sql
```

Actual push with full logging:

```bash
npx supabase db push 2>&1 | tee ~/Desktop/supabase-push-log.txt
```

Then:

```bash
npx supabase migration list
npm run dev
```

## Instructor-side QA

Confirm five Published r1 lessons in every week from 8 through 12.

Spot-check:
- Week 8 Day 5 — mixed Quarter 1 spiral review
- Week 9 Day 5 — cumulative mastery readiness
- Week 10 Day 4 — make-ten addition
- Week 11 Day 4 — explain an addition strategy
- Week 12 Day 3 — count on to find a subtraction difference

Open Teacher Guide and Answer Key for each sample.

Do not artificially advance the real student just to reach these weeks.
