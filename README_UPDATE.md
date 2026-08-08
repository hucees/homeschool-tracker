# Grade 1 Mathematics — Production Batch: Weeks 3–7

This update scales the proven Week 1–2 curriculum model to five weeks in one
transaction-safe package.

## Curriculum coverage

### Week 3 — 1-MATH-03
Counting Patterns by 2s, 5s, and 10s

- Day 1: count by 10s
- Day 2: count by 5s
- Day 3: count by 2s
- Day 4: identify and apply mixed skip-counting rules
- Day 5: readiness + 10-question online check

### Week 4 — 1-MATH-04
Tens and Ones I

- groups of ten and leftover ones
- identify tens and ones digits
- compose numerals
- expanded form
- foundational Week 4 online check

### Week 5 — 1-MATH-04
Tens and Ones II

- digit value
- multiple equivalent place-value forms
- multiples of ten and teen numbers
- mixed place-value application
- second independent Week 5 online check

### Week 6 — 1-MATH-05
Comparing Two-Digit Numbers I

- meaning of >, <, =
- compare tens first
- compare ones when tens match
- equality and true/false comparisons
- Week 6 online check

### Week 7 — 1-MATH-05
Comparing Two-Digit Numbers II

- mixed comparisons
- ordering sets of three numbers
- explain comparisons with place-value reasoning
- application contexts
- second independent Week 7 online check

## Package totals

- 25 published lesson-content revisions
- 375 guided/independent/worksheet items
- 5 online assessments
- 50 auto-scored assessment items

## Safety behavior

Migration 018 runs all five weeks inside one transaction.

Before writing anything, it verifies:
- all 25 expected lesson skeletons exist with D1–D5 codes
- all five Friday assignment templates exist
- Weeks 3–7 do not already contain published/superseded lesson content
- Weeks 3–7 have not already been frozen to a student delivery
- Weeks 3–7 do not already have assessment question banks

If any preflight condition fails, the batch aborts instead of partially installing.

## Install order

First checkpoint the working Week 2 update:

```bash
git add .
git commit -m "Add Grade 1 Math Week 2 production curriculum"
git push
```

Copy the extracted update into the project:

```bash
cp -R ~/Downloads/homeschool-tracker-grade1-math-weeks3-7-update/. .
```

Validate:

```bash
npm run check:starter
npm run typecheck
npm run lint
```

Expected check output includes:

```text
Migrations: 18
Batch QA: Weeks 3–7 / 25 lessons / 50 online assessment items
Starter structure and Weeks 3–7 static checks passed.
```

Dry-run:

```bash
npx supabase db push --dry-run
```

The only pending migration should be:

```text
20260808008000_grade1_math_weeks3_7_content.sql
```

Actual push with full log:

```bash
npx supabase db push 2>&1 | tee ~/Desktop/supabase-push-log.txt
```

Then confirm:

```bash
npx supabase migration list
```

The final row should have `20260808008000` in both Local and Remote.

Run:

```bash
npm run dev
```

## Recommended QA after install

Instructor side only at first:

1. Grade 1 Math → Weeks 3–7 should each show five `Published r1` lessons.
2. Spot-check:
   - Week 3 Day 3 (counting by 2s)
   - Week 4 Day 4 (expanded form)
   - Week 5 Day 1 (digit value)
   - Week 6 Day 3 (same-tens comparison)
   - Week 7 Day 3 (explain comparison)
3. Open Teacher Guide and Answer Key on those samples.
4. Open each Friday Day 5 lesson and verify the readiness content.

Do not artificially advance the real student record just to test later weeks.
