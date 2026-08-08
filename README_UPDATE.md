# Grade 1 Mathematics — Final Production Batch: Weeks 33–36

## Coverage

### Week 33 — `1-MATH-19` Adding Within 100 II
- mixed two-digit + one-digit
- two-digit + multiple of 10
- add ones across a new ten
- explain tens-and-ones changes
- second assessment opportunity

### Week 34 — `1-MATH-20` Ten More and Ten Less
- mentally find 10 more
- mentally find 10 less
- explain tens digit changes
- explain ones digit stays the same
- **90% mastery threshold preserved**

### Week 35 — `1-MATH-21` Subtract Multiples of 10
- subtract whole tens within 10–90
- connect to related basic facts
- explain tens-based reasoning
- 85% mastery threshold

### Week 36 — Quarter 4 + Year-End Mastery
Cumulative Quarter 4 check for:
- `1-MATH-15` organize/interpret data
- `1-MATH-16` represent data
- `1-MATH-17` 2D/3D shapes
- `1-MATH-18` halves/fourths
- `1-MATH-19` add within 100
- `1-MATH-20` 10 more/10 less
- `1-MATH-21` subtract multiples of 10

Week 36 uses each competency's existing configured threshold. `1-MATH-20`
remains 90%; the other listed Quarter 4 competencies remain 85%.

## Totals

- 20 production lessons
- 300 lesson items
- 40 online assessment items

With this migration, **all 36 instructional weeks of Grade 1 Math have
production lesson content.**

## Mastery policy

Models, manipulatives, drawings, and student explanations remain useful forms of
instruction and optional evidence. This migration does **not** introduce a
separate hands-on mastery requirement. Repeated qualifying evidence remains the
mastery-system rule.

## Safety

Migration 024:
- runs in one transaction
- preflights all 20 Week 33–36 lesson skeletons
- preflights all four Friday assignment templates
- refuses to overwrite published/superseded lesson content
- refuses to rewrite frozen student deliveries
- refuses to overwrite existing assessment banks

## Install

Checkpoint Weeks 28–32:

```bash
git add .
git commit -m "Add Grade 1 Math Weeks 28 through 32 production curriculum"
git push
```

Copy the extracted package into the project:

```bash
cp -R ~/Downloads/homeschool-tracker-grade1-math-weeks33-36-update/. .
```

Validate:

```bash
npm run check:starter
npm run typecheck
npm run lint
```

Expected static check:

```text
Migrations: 24
Batch QA: Weeks 33–36 / 20 lessons / 40 online assessment items
Coverage: addition within 100 II + 10 more/less + subtract tens + year-end mastery
Week 34 mastery threshold preserved: 90%
Grade 1 Math production curriculum coverage: Weeks 1–36 complete
Starter structure and Weeks 33–36 static checks passed.
```

Dry run:

```bash
npx supabase db push --dry-run
```

Expected pending migration:

```text
20260808014000_grade1_math_weeks33_36_content.sql
```

Push:

```bash
npx supabase db push 2>&1 | tee ~/Desktop/supabase-push-log.txt
```

Verify:

```bash
npx supabase migration list
```

Expected final row:

```text
20260808014000 | 20260808014000
```

## Instructor QA

Confirm five `Published r1` lessons in Weeks 33, 34, 35, and 36.

Spot-check:
- Week 33 Day 3 — Add Ones Across a New Ten
- Week 34 Day 4 — Explain the Place-Value Pattern
- Week 34 Day 5 — Ten More/Ten Less Mastery Readiness
- Week 35 Day 2 — Use Related Basic Facts
- Week 36 Day 5 — Grade 1 Math Year-End Mastery Readiness

For each spot-check, open:
- lesson content
- Teacher Guide
- Answer Key

Do not artificially advance the real student to Week 36 to test it.

## After this batch

Once Migration 024 is live and instructor QA is complete, the production
curriculum layer for **Grade 1 Mathematics 2026.1 is complete across all
36 instructional weeks**. The next useful step is curriculum-wide QA and then
either:
1. package/release hardening for Grade 1 Math, or
2. begin the next Grade 1 subject using the same production model.
